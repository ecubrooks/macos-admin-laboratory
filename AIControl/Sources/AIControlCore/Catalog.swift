import Foundation

public enum ProcessingGroup: String, Codable, CaseIterable, Identifiable {
    case cloud = "Cloud"
    case local = "On-device"
    case mixed = "Mixed / Apple-managed"
    public var id: String { rawValue }
}

public struct Feature: Codable, Identifiable {
    public let id: String
    public let title: String
    public let group: ProcessingGroup
    public let detail: String
    public let actionLabel: String
    public let minimumOS: String
    public let legacyKey: String?
    public let declarationType: String?
    public let declarationPath: [String]?
    public let restrictionValue: Bool?
    public let preferenceKey: String?
    public var isControllable: Bool { legacyKey != nil || declarationType != nil || preferenceKey != nil }
}

public enum Catalog {
    public static func load() throws -> [Feature] {
        guard let url = Bundle.main.url(forResource: "features", withExtension: "json")
            ?? Bundle.module.url(forResource: "features", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Feature].self, from: Data(contentsOf: url))
    }
}
