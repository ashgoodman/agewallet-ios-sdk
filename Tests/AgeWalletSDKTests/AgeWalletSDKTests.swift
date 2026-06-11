import XCTest
@testable import AgeWalletSDK

final class AgeWalletSDKTests: XCTestCase {
    func testSecurityGeneratesVerifier() {
        let verifier = Security.generateVerifier()
        XCTAssertFalse(verifier.isEmpty)
        XCTAssertTrue(verifier.count > 40) // Base64-URL encoded 32 bytes
    }

    func testSecurityGeneratesChallenge() {
        let verifier = "test-verifier-string"
        let challenge = Security.generateChallenge(from: verifier)
        XCTAssertFalse(challenge.isEmpty)
        // Challenge should be Base64-URL encoded SHA256 hash
        XCTAssertFalse(challenge.contains("+"))
        XCTAssertFalse(challenge.contains("/"))
        XCTAssertFalse(challenge.contains("="))
    }

    func testSecurityGeneratesState() {
        let state = Security.generateState()
        XCTAssertEqual(state.count, 32) // 16 bytes as hex = 32 chars
    }

    func testConfigInitialization() {
        let config = AgeWalletConfig(
            clientId: "test-client",
            redirectUri: "https://example.com/callback"
        )

        XCTAssertEqual(config.clientId, "test-client")
        XCTAssertEqual(config.redirectUri, "https://example.com/callback")
        XCTAssertEqual(config.endpoints.auth, "https://app.agewallet.io/user/authorize")
        XCTAssertNil(config.metadata)
    }

    // MARK: - Metadata

    @available(iOS 14.0, macOS 11.0, *)
    func testBuildVerificationURLAppendsMetadataFromConfig() throws {
        let config = AgeWalletConfig(
            clientId: "test-client",
            redirectUri: "https://example.com/callback",
            metadata: "tenant-abc"
        )
        let sdk = AgeWallet(config: config)
        let url = try sdk.buildVerificationURL()
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "metadata" })?.value, "tenant-abc")
    }

    @available(iOS 14.0, macOS 11.0, *)
    func testBuildVerificationURLOmitsMetadataWhenUnset() throws {
        let config = AgeWalletConfig(
            clientId: "test-client",
            redirectUri: "https://example.com/callback"
        )
        let sdk = AgeWallet(config: config)
        let url = try sdk.buildVerificationURL()
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNil(items.first(where: { $0.name == "metadata" }))
    }

    @available(iOS 14.0, macOS 11.0, *)
    func testBuildVerificationURLPerCallOverrideWins() throws {
        let config = AgeWalletConfig(
            clientId: "test-client",
            redirectUri: "https://example.com/callback",
            metadata: "instance-default"
        )
        let sdk = AgeWallet(config: config)
        let url = try sdk.buildVerificationURL(metadata: "per-call-value")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "metadata" })?.value, "per-call-value")
    }

    @available(iOS 14.0, macOS 11.0, *)
    func testSetMetadataMutatesDefault() throws {
        let config = AgeWalletConfig(
            clientId: "test-client",
            redirectUri: "https://example.com/callback"
        )
        let sdk = AgeWallet(config: config)
        try sdk.setMetadata("new-value")
        let url = try sdk.buildVerificationURL()
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "metadata" })?.value, "new-value")
    }

    @available(iOS 14.0, macOS 11.0, *)
    func testSetMetadataRejectsOversized() {
        let config = AgeWalletConfig(
            clientId: "test-client",
            redirectUri: "https://example.com/callback"
        )
        let sdk = AgeWallet(config: config)
        let oversized = String(repeating: "a", count: AgeWallet.metadataMaxBytes + 1)
        XCTAssertThrowsError(try sdk.setMetadata(oversized)) { error in
            guard case AgeWalletError.invalidMetadata = error else {
                XCTFail("Expected invalidMetadata error, got \(error)")
                return
            }
        }
    }

    @available(iOS 14.0, macOS 11.0, *)
    func testBuildVerificationURLRejectsOversizedOverride() {
        let config = AgeWalletConfig(
            clientId: "test-client",
            redirectUri: "https://example.com/callback"
        )
        let sdk = AgeWallet(config: config)
        let oversized = String(repeating: "a", count: AgeWallet.metadataMaxBytes + 1)
        XCTAssertThrowsError(try sdk.buildVerificationURL(metadata: oversized))
    }
}
