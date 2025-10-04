//
//  BiometricKeychain.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//

import Foundation
import LocalAuthentication
import Security

final class BiometricKeychain {
    struct Credentials: Codable { let email: String; let password: String }

    private let service = "com.aceup.biometric-login"
    private let account = "credentials"

    func saveCredentials(_ creds: Credentials) throws {
        // Borrar previas
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(del as CFDictionary)

        var accessErr: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.biometryCurrentSet],
            &accessErr
        ) else {
            throw accessErr!.takeRetainedValue() as Error
        }

        let data = try JSONEncoder().encode(creds)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain,
                          code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Keychain add error \(status)"])
        }
    }

    func loadCredentials(context: LAContext) throws -> Credentials? {
        var item: CFTypeRef?
        let get: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        let status = SecItemCopyMatching(get as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain,
                          code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Keychain read error \(status)"])
        }
        return try JSONDecoder().decode(Credentials.self, from: data)
    }
}
