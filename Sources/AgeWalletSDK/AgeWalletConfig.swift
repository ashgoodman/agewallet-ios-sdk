import Foundation

/// Configuration for AgeWallet SDK.
public struct AgeWalletConfig {
    /// Your AgeWallet client ID.
    public let clientId: String

    /// The redirect URI registered with AgeWallet.
    public let redirectUri: String

    /// Custom endpoint configuration (optional).
    public let endpoints: AgeWalletEndpoints

    /// Initialize AgeWallet configuration.
    /// - Parameters:
    ///   - clientId: Your AgeWallet client ID
    ///   - redirectUri: The redirect URI registered with AgeWallet
    ///   - endpoints: Custom endpoints (optional, uses defaults if not provided)
    public init(
        clientId: String,
        redirectUri: String,
        endpoints: AgeWalletEndpoints = AgeWalletEndpoints()
    ) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.endpoints = endpoints
    }
}

/// AgeWallet API endpoints.
public struct AgeWalletEndpoints {
    public let auth: String
    public let token: String
    public let userinfo: String

    public init(
        auth: String = "https://app.agewallet.io/user/authorize",
        token: String = "https://app.agewallet.io/user/token",
        userinfo: String = "https://app.agewallet.io/user/userinfo"
    ) {
        self.auth = auth
        self.token = token
        self.userinfo = userinfo
    }
}

/// Stored verification state.
struct VerificationState: Codable {
    let accessToken: String
    let expiresAt: TimeInterval
    let isVerified: Bool
}

/// OIDC state for callback validation.
struct OidcState: Codable {
    let state: String
    let verifier: String
    let nonce: String
}
