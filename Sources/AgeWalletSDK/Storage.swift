import Foundation
import Security

/// Secure storage using iOS Keychain.
final class Storage {
    private let verificationKey = "io.agewallet.sdk.verification"
    private let oidcStateKey = "io.agewallet.sdk.oidc"

    // MARK: - Verification State

    func getVerification() -> VerificationState? {
        guard let data = readFromKeychain(key: verificationKey) else {
            return nil
        }

        do {
            let state = try JSONDecoder().decode(VerificationState.self, from: data)

            // Check if expired
            if state.expiresAt < Date().timeIntervalSince1970 * 1000 {
                clearVerification()
                return nil
            }

            return state
        } catch {
            print("[AgeWallet] Failed to decode verification state: \(error)")
            return nil
        }
    }

    func setVerification(_ state: VerificationState) {
        do {
            let data = try JSONEncoder().encode(state)
            saveToKeychain(key: verificationKey, data: data)
        } catch {
            print("[AgeWallet] Failed to encode verification state: \(error)")
        }
    }

    func clearVerification() {
        deleteFromKeychain(key: verificationKey)
    }

    // MARK: - OIDC State

    func getOidcState() -> OidcState? {
        guard let data = readFromKeychain(key: oidcStateKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(OidcState.self, from: data)
        } catch {
            print("[AgeWallet] Failed to decode OIDC state: \(error)")
            return nil
        }
    }

    func setOidcState(_ state: OidcState) {
        do {
            let data = try JSONEncoder().encode(state)
            saveToKeychain(key: oidcStateKey, data: data)
        } catch {
            print("[AgeWallet] Failed to encode OIDC state: \(error)")
        }
    }

    func clearOidcState() {
        deleteFromKeychain(key: oidcStateKey)
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(key: String, data: Data) {
        // Delete existing item first
        deleteFromKeychain(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[AgeWallet] Keychain save failed: \(status)")
        }
    }

    private func readFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }

        return nil
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
