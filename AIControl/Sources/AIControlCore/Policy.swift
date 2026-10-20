import Foundation

public enum PolicyError: LocalizedError {
    case empty, unsupported(String), unknown(String)
    public var errorDescription: String? {
        switch self {
        case .empty: return "Select at least one supported restriction."
        case .unsupported(let names): return "These selections cannot be included in this format: \(names). Use the other export format or adjust your selections."
        case .unknown(let ids): return "Unknown feature identifiers: \(ids)."
        }
    }
}

public enum Policy {
    public static let identifier = "io.github.aicontrol.policy"
    private static func selected(_ ids: Set<String>, catalog: [Feature]) throws -> [Feature] {
        let unknown = ids.subtracting(Set(catalog.map(\.id)))
        guard unknown.isEmpty else { throw PolicyError.unknown(unknown.sorted().joined(separator: ", ")) }
        let features = catalog.filter { ids.contains($0.id) }
        guard !features.isEmpty else { throw PolicyError.empty }
        return features
    }
    private static func payload(_ type: String, _ suffix: String) -> [String: Any] {
        ["PayloadType": type, "PayloadVersion": 1,
         "PayloadIdentifier": identifier + "." + suffix,
         "PayloadUUID": suffix == "restrictions" ? "09381694-930D-4D3A-8B2B-697E22A87965" : "80504DC5-BDB4-4D46-A629-580D9DF29233",
         "PayloadDisplayName": "AI Control · \(suffix)"]
    }
    public static func legacyProfile(ids: Set<String>, catalog: [Feature]) throws -> Data {
        let features = try selected(ids, catalog: catalog)
        let unsupported = features.filter { $0.legacyKey == nil }
        guard unsupported.isEmpty else { throw PolicyError.unsupported(unsupported.map(\.title).joined(separator: ", ")) }
        var restrictions = payload("com.apple.applicationaccess", "restrictions")
        for feature in features { restrictions[feature.legacyKey!] = feature.restrictionValue! }
        let profile: [String: Any] = [
            "PayloadType": "Configuration", "PayloadVersion": 1,
            "PayloadIdentifier": identifier, "PayloadUUID": "BDA68D57-67CB-4B61-90F0-DDB62BD2E6CE",
            "PayloadDisplayName": "AI Control", "PayloadOrganization": "AI Control",
            "PayloadDescription": "Selected AI restrictions. Remove this profile to release these restrictions. Other management policies remain in effect.",
            "PayloadScope": "System", "PayloadRemovalDisallowed": false,
            "PayloadContent": [restrictions]
        ]
        return try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
    }
    // A transport-neutral bundle of declarations. An MDM must publish each
    // declaration and its activation using Apple's declarative management protocol.
    public static func declarations(ids: Set<String>, catalog: [Feature]) throws -> Data {
        let features = try selected(ids, catalog: catalog)
        let unsupported = features.filter { $0.declarationType == nil }
        guard unsupported.isEmpty else { throw PolicyError.unsupported(unsupported.map(\.title).joined(separator: ", ")) }
        var grouped: [String: [String: Any]] = [:]
        for feature in features {
            let type = feature.declarationType!
            var value = grouped[type] ?? [:]
            insert(feature.restrictionValue!, path: feature.declarationPath![...], into: &value)
            grouped[type] = value
        }
        let configurations: [[String: Any]] = grouped.keys.sorted().map { type in
            ["Type": type, "Identifier": identifier + "." + type,
             "ServerToken": UUID().uuidString, "Payload": grouped[type]!]
        }
        let activation: [String: Any] = [
            "Type": "com.apple.activation.simple", "Identifier": identifier + ".activation",
            "ServerToken": UUID().uuidString,
            "Payload": ["StandardConfigurations": configurations.map { $0["Identifier"] as! String }]
        ]
        let bundle: [String: Any] = [
            "format": "AIControl declaration export v1",
            "minimumMacOS": features.contains { $0.minimumOS == "27.0" } ? "27.0" : "26.4",
            "deployment": "Publish these declarations through a supporting MDM. This JSON file cannot be installed by opening it.",
            "declarations": configurations + [activation]
        ]
        return try JSONSerialization.data(withJSONObject: bundle, options: [.prettyPrinted, .sortedKeys])
    }
    private static func insert(_ value: Bool, path: ArraySlice<String>, into dictionary: inout [String: Any]) {
        guard let key = path.first else { return }
        if path.count == 1 { dictionary[key] = value; return }
        var child = dictionary[key] as? [String: Any] ?? [:]
        insert(value, path: path.dropFirst(), into: &child)
        dictionary[key] = child
    }
}
