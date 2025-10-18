//
//  BiometricKeychain.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//


import Foundation
import LocalAuthentication
import Security

struct BioCredentials: Codable {
    let email: String
    let password: String // En producción usa refreshToken
}

private enum KCConst {
    // ÚNICA pareja de llaves
    static let serviceSecure = "AceUP.credentials.secure"
    static let servicePlain  = "AceUP.credentials.plain"
    static let account       = "AceUP.auth"
}

final class BiometricKeychain {

    // MARK: - SAVE (seguro con fallback a plain)

    func saveCredentials(_ creds: BioCredentials) throws {
        let data = try JSONEncoder().encode(creds)

        // 1) Intento SEGURO (Face ID + presencia)
        let secureStatus = saveSecure(data: data)
        print("KC save (secure) status:", secureStatus)

        if secureStatus == errSecSuccess {
            // Borra cualquier plain viejo
            _ = delete(service: KCConst.servicePlain)
            return
        }

        // 2) Fallback: guardado PLAIN (sin biometría) para no bloquear UX
        let plainStatus = savePlain(data: data)
        print("KC save (plain) status:", plainStatus)
        guard plainStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(plainStatus),
                          userInfo: [NSLocalizedDescriptionKey: "No se pudo guardar credenciales (status \(plainStatus))."])
        }
    }

    // MARK: - LOAD (intenta seguro → plain)

    func loadCredentials(context: LAContext?) throws -> BioCredentials? {
        if let creds = try loadSecure(context: context) {
            return creds
        }
        // Si no hay seguro, intenta plain
        if let creds = try loadPlain() {
            return creds
        }
        return nil
    }

    // MARK: - DEBUG

    func debugCountItems() {
        let countSecure = countItems(service: KCConst.serviceSecure)
        let countPlain  = countItems(service: KCConst.servicePlain)
        print("KC debug: secure(\(countSecure)) plain(\(countPlain)) item(s)")
    }

    func deleteCredentials() {
        _ = delete(service: KCConst.serviceSecure)
        _ = delete(service: KCConst.servicePlain)
    }

    // ============================================================
    // MARK: - Internals
    // ============================================================

    // Guardado SEGURO (Face ID + presencia)
    private func saveSecure(data: Data) -> OSStatus {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KCConst.serviceSecure,
            kSecAttrAccount as String: KCConst.account
        ]
        SecItemDelete(base as CFDictionary)

        var accessErr: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            // Más tolerante; si prefieres aún más seguridad usa kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            kSecAttrAccessibleWhenUnlocked,
            [.biometryAny, .userPresence],
            &accessErr
        ) else {
            // Si falla la creación del AccessControl, no intentamos insertar (devolvemos error sintético)
            return errSecParam
        }

        var add = base
        add[kSecAttrAccessControl as String] = access
        add[kSecValueData as String] = data
        // Evitamos kSecUseDataProtectionKeychain para máxima compatibilidad
        return SecItemAdd(add as CFDictionary, nil)
    }

    // Guardado PLAIN (sin biometría) — fallback
    private func savePlain(data: Data) -> OSStatus {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KCConst.servicePlain,
            kSecAttrAccount as String: KCConst.account
        ]
        SecItemDelete(base as CFDictionary)

        var add = base
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        add[kSecValueData as String] = data
        return SecItemAdd(add as CFDictionary, nil)
    }

    // Lectura SEGURO
    private func loadSecure(context: LAContext?) throws -> BioCredentials? {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KCConst.serviceSecure,
            kSecAttrAccount as String: KCConst.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let ctx = context {
            q[kSecUseAuthenticationContext as String] = ctx
        } else {
            q[kSecUseOperationPrompt as String] = "Autentícate para usar tus credenciales"
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        print("Keychain load (secure) status:", status) // -25300 = not found
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return try JSONDecoder().decode(BioCredentials.self, from: data)
    }

    // Lectura PLAIN
    private func loadPlain() throws -> BioCredentials? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KCConst.servicePlain,
            kSecAttrAccount as String: KCConst.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        print("Keychain load (plain) status:", status)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return try JSONDecoder().decode(BioCredentials.self, from: data)
    }

    // Helpers
    private func countItems(service: String) -> Int {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var res: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &res)
        if status == errSecSuccess, let arr = res as? [[String: Any]] {
            return arr.count
        }
        return 0
    }

    @discardableResult
    private func delete(service: String) -> OSStatus {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: KCConst.account
        ]
        return SecItemDelete(q as CFDictionary)
    }
}
