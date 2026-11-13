import SwiftUI
import AppKit
import ServiceManagement
import AIControlCore

enum ControlSection: String, CaseIterable, Identifiable {
    case cloud = "Cloud"
    case local = "On-device"
    case mixed = "Mixed"
    case active = "Active"

    var id: String { rawValue }
}

@main
struct AIControlApp: App {
    @StateObject private var model = ControlModel()
    var body: some Scene {
        MenuBarExtra("AI Control", systemImage: "brain") {
            ControlView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class ControlModel: ObservableObject {
    @Published var features: [Feature] = []
    @Published var selected: Set<String> = []
    @Published var section: ControlSection = .cloud
    @Published private(set) var activeIDs: Set<String> = []
    @Published var message = "Selections are a draft until installed or deployed."
    @Published var localStatus = "Unknown"
    @Published var review = false
    @Published var error: String?
    @Published var offersDeviceManagement = false
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    @Published private(set) var changingLoginItem = false
    @Published private(set) var exporting = false
    private let defaults = UserDefaults.standard
    private let draftKey = "restrictionDraft"
    private let journalKey = "inlinePredictionOriginalValue"
    private let journalPresentKey = "inlinePredictionJournalPresent"
    private let key = "NSAutomaticInlinePredictionEnabled"
    private let domain = kCFPreferencesAnyApplication
    private let restrictionsDomain = "com.apple.applicationaccess" as CFString

    init() {
        do {
            features = try Catalog.load()
            selected = Set(defaults.stringArray(forKey: draftKey) ?? [])
        } catch { self.error = error.localizedDescription }
        refresh()
    }
    var policyIDs: Set<String> {
        Set(features.filter { selected.contains($0.id) && $0.preferenceKey == nil }.map(\.id))
    }
    var selectedNames: [String] { features.filter { selected.contains($0.id) }.map(\.title) }
    var visibleFeatures: [Feature] {
        if section == .active {
            return features.filter { activeIDs.contains($0.id) }
        }

        let group: ProcessingGroup = switch section {
        case .cloud: .cloud
        case .local: .local
        case .mixed: .mixed
        case .active: .cloud
        }
        return features.filter { $0.group == group }
    }
    func isActive(_ feature: Feature) -> Bool { activeIDs.contains(feature.id) }
    func supports(_ feature: Feature) -> Bool {
        let parts = feature.minimumOS.split(separator: ".").compactMap { Int($0) }
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: parts[0], minorVersion: parts.count > 1 ? parts[1] : 0, patchVersion: 0))
    }
    func select(_ feature: Feature, _ on: Bool) {
        if on { selected.insert(feature.id) } else { selected.remove(feature.id) }
        persist()
    }
    func cloudPreset() {
        selected.formUnion(features.filter { $0.group == .cloud && $0.isControllable && supports($0) }.map(\.id))
        persist()
        message = "Cloud restrictions selected. Private Cloud Compute is not blocked."
    }
    func clearDraft() {
        selected = []
        persist()
        message = "Draft cleared. Installed policies and local settings are unchanged."
    }
    private func persist() { defaults.set(selected.sorted(), forKey: draftKey) }

    func refresh() {
        refreshLoginStatus()
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let forced = CFPreferencesAppValueIsForced(key as CFString, domain)
        let value = CFPreferencesCopyAppValue(key as CFString, domain) as? NSNumber
        localStatus = (value.map { $0.boolValue ? "Enabled preference" : "Disabled preference" } ?? "System default")
            + (forced ? " · Managed" : "")

        CFPreferencesSynchronize(restrictionsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        activeIDs = Set(features.compactMap { feature in
            if feature.preferenceKey == key, value?.boolValue == false {
                return feature.id
            }
            guard let legacyKey = feature.legacyKey,
                  let restrictedValue = feature.restrictionValue,
                  CFPreferencesAppValueIsForced(legacyKey as CFString, restrictionsDomain),
                  let effectiveValue = CFPreferencesCopyAppValue(
                    legacyKey as CFString,
                    restrictionsDomain
                  ) as? NSNumber,
                  effectiveValue.boolValue == restrictedValue else {
                return nil
            }
            return feature.id
        })
    }
    var launchAtLogin: Bool {
        loginStatus == .enabled || loginStatus == .requiresApproval
    }

    var loginApprovalRequired: Bool { loginStatus == .requiresApproval }

    func refreshLoginStatus() {
        loginStatus = SMAppService.mainApp.status
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        guard !changingLoginItem else { return }
        changingLoginItem = true
        defer {
            refreshLoginStatus()
            changingLoginItem = false
        }
        do {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval {
                    try service.register()
                }
            } else {
                try await service.unregister()
            }
        } catch {
            offersDeviceManagement = false
            self.error = "Could not change launch at login: \(error.localizedDescription)"
        }
    }

    func openLoginSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    var hasLocalBackup: Bool { defaults.bool(forKey: journalPresentKey) }
    func disablePredictions() {
        guard !CFPreferencesAppValueIsForced(key as CFString, domain) else {
            error = "Inline predictions are managed by your organization."; return
        }
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        if !hasLocalBackup {
            let old = CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            if let old { defaults.set(old, forKey: journalKey) }
            else { defaults.removeObject(forKey: journalKey) }
            defaults.set(true, forKey: journalPresentKey)
        }
        CFPreferencesSetValue(key as CFString, false as CFBoolean, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            error = "Could not save the preference. The original value is retained for restoration."; return
        }
        refresh()
        message = "Inline prediction preference disabled. Reopen apps if needed."
    }
    func restorePredictions() {
        guard hasLocalBackup else { return }
        guard !CFPreferencesAppValueIsForced(key as CFString, domain) else {
            error = "Inline predictions are managed by your organization. The backup is retained."; return
        }
        CFPreferencesSetValue(key as CFString, defaults.object(forKey: journalKey) as CFPropertyList?, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            error = "Could not restore the preference. The backup is retained."; return
        }
        defaults.removeObject(forKey: journalKey)
        defaults.removeObject(forKey: journalPresentKey)
        refresh()
        message = "Original inline prediction preference restored. Reopen apps if needed."
    }
    func openSettings(profiles: Bool = false) {
        let target = profiles ? "x-apple.systempreferences:com.apple.Profiles-Settings.extension"
                              : "x-apple.systempreferences:com.apple.Siri-Settings.extension"
        if let url = URL(string: target) { NSWorkspace.shared.open(url) }
    }
    func export(ddm: Bool, install: Bool = false) async {
        guard !exporting else { return }
        exporting = true
        defer { exporting = false }
        var savedURL: URL?
        do {
            let data = try ddm ? Policy.declarations(ids: policyIDs, catalog: features)
                               : Policy.legacyProfile(ids: policyIDs, catalog: features)
            let filename = ddm ? "AIControl-declarations.json" : "AIControl.mobileconfig"
            let url = try availableDownloadsURL(filename: filename)
            try data.write(to: url, options: .atomic)
            savedURL = url
            review = false
            message = "\(url.lastPathComponent) saved to Downloads."

            if install {
                guard NSWorkspace.shared.open(url) else {
                    throw CocoaError(.fileReadUnknown)
                }
                try await Task.sleep(for: .milliseconds(750))
                openSettings(profiles: true)
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            let failure = savedURL.map {
                "The profile was saved to \($0.path), but could not be opened: \(error.localizedDescription)"
            } ?? "The file could not be saved to Downloads: \(error.localizedDescription)"
            message = failure
            review = false
            DispatchQueue.main.async { [weak self] in
                self?.offersDeviceManagement = false
                self?.error = failure
            }
        }
    }

    private func availableDownloadsURL(filename: String) throws -> URL {
        guard let downloads = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let requestedURL = downloads.appendingPathComponent(filename)
        var candidate = requestedURL
        var copyNumber = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let baseName = requestedURL.deletingPathExtension().lastPathComponent
            candidate = downloads.appendingPathComponent(
                "\(baseName)-\(copyNumber).\(requestedURL.pathExtension)"
            )
            copyNumber += 1
        }
        return candidate
    }

    func openDeviceManagement() {
        offersDeviceManagement = false
        error = nil
        openSettings(profiles: true)
    }


}
