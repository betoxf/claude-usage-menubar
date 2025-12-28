//
//  KeychainService.swift
//  ClaudeUsageBar
//

import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.claudeusagebar.credentials"

    // Cache credentials to avoid slow Keychain lookups on every view render
    private var cachedSessionKey: String?
    private var cachedOrganizationId: String?
    private var cacheLoaded = false

    private init() {
        loadCache()
    }

    private func loadCache() {
        cachedSessionKey = retrieveFromKeychain(key: "sessionKey")
        cachedOrganizationId = retrieveFromKeychain(key: "organizationId")
        cacheLoaded = true
    }

    // MARK: - Session Key

    var sessionKey: String? {
        get { cachedSessionKey }
        set {
            cachedSessionKey = newValue
            if let value = newValue {
                save(key: "sessionKey", value: value)
            } else {
                delete(key: "sessionKey")
            }
        }
    }

    // MARK: - Organization ID

    var organizationId: String? {
        get { cachedOrganizationId }
        set {
            cachedOrganizationId = newValue
            if let value = newValue {
                save(key: "organizationId", value: value)
            } else {
                delete(key: "organizationId")
            }
        }
    }

    // MARK: - Keychain Operations

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save error: \(status)")
        }
    }

    private func retrieveFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Validation

    var hasCredentials: Bool {
        sessionKey != nil && organizationId != nil
    }

    func clearAll() {
        cachedSessionKey = nil
        cachedOrganizationId = nil
        delete(key: "sessionKey")
        delete(key: "organizationId")
    }
}
