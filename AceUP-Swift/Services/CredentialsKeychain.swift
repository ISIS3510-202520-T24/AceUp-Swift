//
//  CredentialsKeychain.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 17/10/25.
//

import Foundation
import LocalAuthentication
import Security

struct StoredCredentials: Codable {
    let email: String
    let secret: String  // usa contraseña temporal o, mejor, refreshToken
}

enum KCKeys {
    static let account = "AceUP.auth"      
    static let service = "AceUP.credentials"
}

enum KeychainErr: Error {
    case osStatus(OSStatus)
    case data
}

final class CredentialsKeychain {
    static let shared = CredentialsKeychain()
    private init() {}

    // Guarda SIEMPRE tras login normal
    func save(_ creds: StoredCredentials) throws {
        let data = try JSONEncoder().encode(creds)

        // Borrar un ítem previo (si existe)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KCKeys.service,
            kSecAttrAccount as String: KCKeys.account
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var accessErr: Unmanaged<CFError>?
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlocked,
            [.biometryAny, .userPresence], // robusto ante cambios menores en Face ID
            &accessErr
        )!

        var addQuery = baseQuery
        addQuery[kSecAttrAccessControl as String] = access
        addQuery[kSecValueData as String] = data
        addQuery[kSecUseDataProtectionKeychain as String] = true

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainErr.osStatus(status) }
    }

    // Lee después de Face ID (pedirá Face ID aquí)
    func load(prompt: String = "Autentícate para iniciar sesión") throws -> StoredCredentials {
        let ctx = LAContext()
        ctx.localizedReason = prompt

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KCKeys.service,
            kSecAttrAccount as String: KCKeys.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: ctx,
            kSecUseOperationPrompt as String: prompt
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainErr.osStatus(status)
        }
        guard let creds = try? JSONDecoder().decode(StoredCredentials.self, from: data) else {
            throw KeychainErr.data
        }
        return creds
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KCKeys.service,
            kSecAttrAccount as String: KCKeys.account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
