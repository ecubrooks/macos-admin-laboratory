import SwiftUI
import AppKit
import AIControlCore

struct ControlView: View {
    @ObservedObject var model: ControlModel
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "brain.filled.head.profile").font(.title).foregroundStyle(.teal)
                VStack(alignment: .leading) {
                    Text("AI Control").font(.title3.bold())
                    Text("Choose where intelligence belongs").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help("Verify effective restriction status")
            }
            Picker("Section", selection: $model.section) {
                ForEach(ControlSection.allCases) { section in Text(section.rawValue).tag(section) }
            }.pickerStyle(.segmented)
            Text(sectionDescription).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.visibleFeatures.isEmpty && model.section == .active {
                        Text("No enforced restrictions were detected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(model.visibleFeatures) { feature in
                        FeatureRow(feature: feature, model: model)
                        Divider()
                    }
                }
                .padding(.trailing, 12)
            }.frame(height: 325)
            Text(model.message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Select cloud restrictions") { model.cloudPreset() }
                Spacer()
                Button("Review (\(model.policyIDs.count))") { model.review = true }
                    .buttonStyle(.borderedProminent).tint(.teal).disabled(model.policyIDs.isEmpty)
            }
            HStack {
                Button("Siri Settings") { model.openSettings() }
                Spacer()
                Menu {
                    Button("Profiles / Undo policy…") { model.openSettings(profiles: true) }
                    Button("Clear draft") { model.clearDraft() }
                    Divider()
                    Toggle("Launch at login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { enabled in
                            Task { await model.setLaunchAtLogin(enabled) }
                        }))
                        .disabled(model.changingLoginItem)
                    if model.loginApprovalRequired {
                        Button("Approve launch at login…") { model.openLoginSettings() }
                    }
                    Divider()
                    Button("Quit AI Control") { NSApplication.shared.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).frame(width: 25)
            }.font(.caption)
        }
        .padding(18).frame(width: 470)
        .task { model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refreshLoginStatus() }
        }
        .sheet(isPresented: $model.review) { ReviewView(model: model) }
        .alert(
            "AI Control",
            isPresented: Binding(
                get: { model.error != nil },
                set: { isPresented in
                    guard !isPresented else { return }
                    DispatchQueue.main.async {
                        model.error = nil
                        model.offersDeviceManagement = false
                    }
                }
            )
        ) {
            if model.offersDeviceManagement {
                Button("Open Device Management") { model.openDeviceManagement() }
            }
            Button("OK") {
                model.error = nil
                model.offersDeviceManagement = false
            }
        } message: {
            Text(model.error ?? "")
        }
    }
    private var sectionDescription: String {
        switch model.section {
        case .cloud: return "External services and local-only policies. These controls do not provide a global Private Cloud Compute block."
        case .local: return "Features with a local model or preference. App networking remains separate from where a model runs."
        case .mixed: return "Routing can depend on the task, generation mode, and macOS version. Restricting a feature does not force it to run locally."
        case .active: return "Restrictions whose effective enforcement AI Control can currently verify."
        }
    }
}

private struct FeatureRow: View {
    let feature: Feature
    @ObservedObject var model: ControlModel
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(feature.title).font(.subheadline.bold())
                if model.isActive(feature) {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
                Spacer()
                if feature.legacyKey != nil || feature.declarationType != nil {
                    Toggle(feature.actionLabel, isOn: Binding(
                        get: { model.selected.contains(feature.id) },
                        set: { model.select(feature, $0) }))
                        .toggleStyle(.checkbox).disabled(!model.supports(feature))
                        .font(.caption)
                }
            }
            Text(feature.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if feature.preferenceKey != nil {
                HStack {
                    Text(model.localStatus).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("Disable") { model.disablePredictions() }.disabled(!model.supports(feature))
                    Button("Restore") { model.restorePredictions() }.disabled(!model.hasLocalBackup)
                }.font(.caption)
            } else {
                Text(availability).font(.caption2).foregroundStyle(feature.isControllable ? Color.teal : Color.secondary)
            }
        }
    }
    private var availability: String {
        if !feature.isControllable { return "Information / manage in the app’s settings" }
        if !model.supports(feature) { return "Requires macOS \(feature.minimumOS)+" }
        return feature.legacyKey == nil ? "MDM export only · macOS \(feature.minimumOS)+"
                                      : "Draft restriction · compatibility profile or MDM declaration"
    }
}

private struct ReviewView: View {
    @ObservedObject var model: ControlModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review selected restrictions").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.selectedNames, id: \.self) { name in Label(name, systemImage: "checkmark") }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 200)
            Text("Unchecked features are left unmanaged by this policy. Existing organizational restrictions still apply. AI Control verifies readable effective settings, but does not monitor AI traffic.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("MDM declarations use the current settings format (macOS 26.4+; some selections require 27). Compatibility profiles use keys Apple deprecated in 26.4, so validate them on your target OS. Opening a profile requires approval in System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Save MDM declarations to Downloads") { Task { await model.export(ddm: true) } }
                .disabled(model.exporting)
            Button("Save AI Control profile to Downloads") { Task { await model.export(ddm: false) } }
                .disabled(model.exporting)
            Button("Save and open AI Control profile…") {
                Task { await model.export(ddm: false, install: true) }
            }
            .disabled(model.exporting)
            HStack {
                Spacer()
                Button("Back") { model.review = false }.disabled(model.exporting)
            }
        }
        .padding(20)
        .frame(width: 450)
    }
}
