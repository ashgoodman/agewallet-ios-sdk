import Foundation

/// AgeWallet SDK for iOS applications.
///
/// Provides age verification via OIDC/PKCE flow.
///
/// Example usage:
/// ```swift
/// let ageWallet = AgeWallet(config: AgeWalletConfig(
///     clientId: "your-client-id",
///     redirectUri: "https://yourapp.com/callback"
/// ))
///
/// // Build the authorization URL and open it in Safari
/// if let url = try? ageWallet.buildVerificationURL() {
///     UIApplication.shared.open(url)
/// }
///
/// // Handle the callback URL (received via universal link / onOpenURL)
/// let verified = await ageWallet.handleCallback(url: callbackURL)
/// ```
@available(iOS 14.0, macOS 11.0, *)
public final class AgeWallet {
    private let config: AgeWalletConfig
    private let storage = Storage()

    /// Initialize AgeWallet SDK.
    /// - Parameter config: SDK configuration
    public init(config: AgeWalletConfig) {
        self.config = config
    }

    /// Check if the user is currently verified.
    /// - Returns: true if verified and not expired, false otherwise
    public func isVerified() -> Bool {
        storage.getVerification()?.isVerified ?? false
    }

    /// Build the authorization URL to open in a browser.
    ///
    /// Opens this URL in Safari (or any browser). After the user authenticates,
    /// the server redirects to your redirect URI. iOS delivers that URL to the app
    /// via universal links — pass it to `handleCallback(url:)`.
    ///
    /// - Returns: The authorization URL to open
    /// - Throws: AgeWalletError.invalidConfiguration if the config is invalid
    public func buildVerificationURL() throws -> URL {
        let verifier = Security.generateVerifier()
        let challenge = Security.generateChallenge(from: verifier)
        let state = Security.generateState()
        let nonce = Security.generateNonce()

        storage.setOidcState(OidcState(state: state, verifier: verifier, nonce: nonce))

        guard let authURL = buildAuthURL(challenge: challenge, state: state, nonce: nonce) else {
            storage.clearOidcState()
            throw AgeWalletError.invalidConfiguration
        }

        return authURL
    }

    /// Handle callback URL from authorization.
    ///
    /// Call this when the app receives the redirect URI via universal link (onOpenURL).
    ///
    /// - Parameter url: The callback URL received from the universal link
    /// - Returns: AgeWalletResult indicating the outcome
    public func handleCallback(url: URL) async -> AgeWalletResult {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = components?.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]

        let code = params["code"]
        let state = params["state"]
        let error = params["error"]
        let errorDescription = params["error_description"]

        if let error = error {
            print("[AgeWallet] Authorization error: \(error) - \(errorDescription ?? "")")
            storage.clearOidcState()
            return errorDescription == "The user denied the request" ? .denied : .failed
        }

        guard let code = code, let state = state else {
            print("[AgeWallet] Missing code or state in callback")
            storage.clearOidcState()
            return .failed
        }

        guard let storedOidc = storage.getOidcState(), storedOidc.state == state else {
            print("[AgeWallet] Invalid state or session expired")
            storage.clearOidcState()
            return .failed
        }

        do {
            let tokenResponse = try await exchangeCode(code: code, verifier: storedOidc.verifier)
            let userInfo = try await fetchUserInfo(accessToken: tokenResponse.accessToken)

            guard userInfo.ageVerified else {
                print("[AgeWallet] Age verification failed")
                storage.clearOidcState()
                return .failed
            }

            let expiresAt = Date().timeIntervalSince1970 * 1000 + Double(tokenResponse.expiresIn * 1000)
            storage.setVerification(VerificationState(
                accessToken: tokenResponse.accessToken,
                expiresAt: expiresAt,
                isVerified: true
            ))

            storage.clearOidcState()
            return .success
        } catch {
            print("[AgeWallet] Error during token exchange: \(error)")
            storage.clearOidcState()
            return .failed
        }
    }

    /// Clear all verification state (logout).
    public func clearVerification() {
        storage.clearVerification()
        storage.clearOidcState()
    }

    // MARK: - Private Methods

    private func buildAuthURL(challenge: String, state: String, nonce: String) -> URL? {
        var components = URLComponents(string: config.endpoints.auth)

        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "scope", value: "openid age"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "nonce", value: nonce)
        ]

        return components?.url
    }

    private func exchangeCode(code: String, verifier: String) async throws -> TokenResponse {
        guard let url = URL(string: config.endpoints.token) else {
            throw AgeWalletError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "client_id": config.clientId,
            "redirect_uri": config.redirectUri,
            "code": code,
            "code_verifier": verifier
        ].map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AgeWalletError.tokenExchangeFailed
        }

        let json = try JSONDecoder().decode(TokenResponseJSON.self, from: data)
        return TokenResponse(accessToken: json.access_token, expiresIn: json.expires_in ?? 3600)
    }

    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        guard let url = URL(string: config.endpoints.userinfo) else {
            throw AgeWalletError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AgeWalletError.userInfoFailed
        }

        let json = try JSONDecoder().decode(UserInfoJSON.self, from: data)
        return UserInfo(ageVerified: json.age_verified ?? false)
    }
}

// MARK: - Supporting Types

/// Result of an age verification callback.
public enum AgeWalletResult {
    /// Verification completed successfully.
    case success

    /// User denied consent on the AgeWallet screen.
    case denied

    /// Verification process failed (identity check unsuccessful).
    case failed
}

/// Errors that can occur during AgeWallet operations.
public enum AgeWalletError: Error {
    case invalidConfiguration
    case tokenExchangeFailed
    case userInfoFailed
}

private struct TokenResponse {
    let accessToken: String
    let expiresIn: Int
}

private struct TokenResponseJSON: Decodable {
    let access_token: String
    let expires_in: Int?
}

private struct UserInfo {
    let ageVerified: Bool
}

private struct UserInfoJSON: Decodable {
    let age_verified: Bool?
}
