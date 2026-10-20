import XCTest
@testable import AIControlCore

final class PolicyTests: XCTestCase {
    func catalog() throws -> [Feature] { try Catalog.load() }
    func profile(_ ids: Set<String>) throws -> [String: Any] {
        let bytes = try Policy.legacyProfile(ids: ids, catalog: catalog())
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any])
    }
    func testCloudPolicyDoesNotDisableLocalOrMixedFeatures() throws {
        let root = try profile(["external-ai", "dictation-local"])
        let payloads = try XCTUnwrap(root["PayloadContent"] as? [[String: Any]])
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0]["allowExternalIntelligenceIntegrations"] as? Bool, false)
        XCTAssertEqual(payloads[0]["forceOnDeviceOnlyDictation"] as? Bool, true)
        XCTAssertNil(payloads[0]["allowWritingTools"])
        XCTAssertNil(payloads[0]["allowAssistant"])
        XCTAssertNil(payloads[0]["allowCloudDocumentSync"])
        XCTAssertFalse(String(decoding: try Policy.legacyProfile(ids: ["external-ai"], catalog: catalog()), as: UTF8.self).contains("MobileAsset"))
    }
    func testProfileIdentityStableAcrossSelections() throws {
        let first = try profile(["external-ai"])
        let next = try profile(["writing-tools"])
        XCTAssertEqual(first["PayloadUUID"] as? String, next["PayloadUUID"] as? String)
        XCTAssertEqual(first["PayloadIdentifier"] as? String, next["PayloadIdentifier"] as? String)
    }
    func testUnsupportedSelectionIsNotSilentlyDropped() throws {
        XCTAssertThrowsError(try Policy.legacyProfile(ids: ["external-ai", "siri-ai"], catalog: catalog()))
        XCTAssertThrowsError(try Policy.declarations(ids: ["inline-predictions"], catalog: catalog()))
        XCTAssertThrowsError(try Policy.legacyProfile(ids: ["nonexistent"], catalog: catalog()))
        XCTAssertThrowsError(try Policy.legacyProfile(ids: [], catalog: catalog()))
    }
    func testSiriAIExportLeavesBasicSiriAlone() throws {
        let data = try Policy.declarations(ids: ["siri-ai", "mail-summary", "mail-replies"], catalog: catalog())
        let bundle = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(bundle["minimumMacOS"] as? String, "27.0")
        let declarations = try XCTUnwrap(bundle["declarations"] as? [[String: Any]])
        let siri = try XCTUnwrap(declarations.first { ($0["Type"] as? String) == "com.apple.configuration.siri.settings" })
        let siriPayload = try XCTUnwrap(siri["Payload"] as? [String: Any])
        XCTAssertEqual(siriPayload["AllowSiriAI"] as? Bool, false)
        XCTAssertNil(siriPayload["Enabled"])
        let intel = try XCTUnwrap(declarations.first { ($0["Type"] as? String) == "com.apple.configuration.intelligence.settings" })
        let intelPayload = try XCTUnwrap(intel["Payload"] as? [String: Any])
        let apps = try XCTUnwrap(intelPayload["Apps"] as? [String: Any])
        let mail = try XCTUnwrap(apps["Mail"] as? [String: Bool])
        XCTAssertEqual(mail, ["AllowSummary": false, "AllowSmartReplies": false])
        let activation = try XCTUnwrap(declarations.first { ($0["Type"] as? String) == "com.apple.activation.simple" })
        let activationPayload = try XCTUnwrap(activation["Payload"] as? [String: Any])
        let identifiers = try XCTUnwrap(activationPayload["StandardConfigurations"] as? [String])
        XCTAssertEqual(Set(identifiers), Set(declarations.filter { ($0["Type"] as? String) != "com.apple.activation.simple" }.compactMap { $0["Identifier"] as? String }))
    }
}
