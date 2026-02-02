import Foundation
import AuthenticationServices

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
/// if !ageWallet.isVerified() {
///     try await ageWallet.startVerification(from: window)
/// }
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

    /// Start the verification flow.
    ///
    /// Opens a secure browser session to the AgeWallet authorization page.
    /// The callback is handled automatically.
    ///
    /// - Parameter anchor: The window to present the authentication session from
    /// - Returns: true if verification succeeded, false otherwise
    /// - Throws: AgeWalletError if authentication fails
    @MainActor
    public func startVerification(from anchor: ASPresentationAnchor) async throws -> Bool {
        // Generate PKCE parameters
        let verifier = Security.generateVerifier()
        let challenge = Security.generateChallenge(from: verifier)
        let state = Security.generateState()
        let nonce = Security.generateNonce()

        // Store OIDC state for callback validation
        storage.setOidcState(OidcState(state: state, verifier: verifier, nonce: nonce))

        // Build authorization URL
        guard let authURL = buildAuthURL(challenge: challenge, state: state, nonce: nonce) else {
            storage.clearOidcState()
            throw AgeWalletError.invalidConfiguration
        }

        // Get callback URL scheme
        guard let redirectURL = URL(string: config.redirectUri),
              let scheme = redirectURL.scheme else {
            storage.clearOidcState()
            throw AgeWalletError.invalidConfiguration
        }

        // Start authentication session
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: AgeWalletError.cancelled)
                }
            }

            session.presentationContextProvider = PresentationContextProvider(anchor: anchor)
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: AgeWalletError.sessionFailed)
            }
        }

        // Handle the callback
        return await handleCallback(url: callbackURL)
    }

    /// Handle callback URL from authorization.
    /// - Parameter url: The callback URL
    /// - Returns: true if verification succeeded, false otherwise
    public func handleCallback(url: URL) async -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = components?.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]

        let code = params["code"]
        let state = params["state"]
        let error = params["error"]
        let errorDescription = params["error_description"]

        // Handle error response
        if let error = error {
            print("[AgeWallet] Authorization error: \(error) - \(errorDescription ?? "")")
            storage.clearOidcState()
            return false
        }

        // Validate required parameters
        guard let code = code, let state = state else {
            print("[AgeWallet] Missing code or state in callback")
            storage.clearOidcState()
            return false
        }

        // Validate state matches stored state
        guard let storedOidc = storage.getOidcState(), storedOidc.state == state else {
            print("[AgeWallet] Invalid state or session expired")
            storage.clearOidcState()
            return false
        }

        do {
            // Exchange code for tokens
            let tokenResponse = try await exchangeCode(code: code, verifier: storedOidc.verifier)

            // Fetch user info to verify age claim
            let userInfo = try await fetchUserInfo(accessToken: tokenResponse.accessToken)

            guard userInfo.ageVerified else {
                print("[AgeWallet] Age verification failed")
                storage.clearOidcState()
                return false
            }

            // Store verification state
            let expiresAt = Date().timeIntervalSince1970 * 1000 + Double(tokenResponse.expiresIn * 1000)
            storage.setVerification(VerificationState(
                accessToken: tokenResponse.accessToken,
                expiresAt: expiresAt,
                isVerified: true
            ))

            storage.clearOidcState()
            return true
        } catch {
            print("[AgeWallet] Error during token exchange: \(error)")
            storage.clearOidcState()
            return false
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

/// Errors that can occur during AgeWallet operations.
public enum AgeWalletError: Error {
    case invalidConfiguration
    case cancelled
    case sessionFailed
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

// MARK: - Presentation Context Provider

@available(iOS 14.0, macOS 11.0, *)
private class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
