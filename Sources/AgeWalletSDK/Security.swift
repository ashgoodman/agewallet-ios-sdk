import Foundation
import CryptoKit

/// Security utilities for PKCE and state generation.
enum Security {
    /// Generate a random PKCE code verifier.
    /// - Returns: A 64-character Base64-URL encoded random string
    static func generateVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    /// Generate PKCE code challenge from verifier using S256 method.
    /// - Parameter verifier: The code verifier
    /// - Returns: Base64-URL encoded SHA256 hash of the verifier
    static func generateChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    /// Generate a random state parameter.
    /// - Returns: A 32-character hex string
    static func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Generate a random nonce.
    /// - Returns: A 32-character hex string
    static func generateNonce() -> String {
        generateState()
    }
}

// MARK: - Base64-URL Encoding Extension

extension Data {
    /// Encode data as Base64-URL (RFC 4648).
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
