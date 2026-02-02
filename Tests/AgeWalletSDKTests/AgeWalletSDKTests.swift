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
    }
}
