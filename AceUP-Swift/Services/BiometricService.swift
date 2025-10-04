//
//  BiometricService.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 2/10/25.
//

import Foundation
import LocalAuthentication

enum BiometricError: Error {
    case notAvailable
    case failed
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device."
        case .failed:
            return "Biometric authentication failed."
        }
    }
}
final class BiometricService {
    func canEvaluateBiometrics() -> Bool {
        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }
    // imprime que confirme la identidad y resuelve si el usuario se auentica
    
    func authenticateUser(reason: String = "Confirm your identity with Face ID") async throws {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            throw BiometricError.notAvailable
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void,Error>) in
            ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { (success, error) in
                if success {
                    cont.resume(returning: ())
                } else {
                    cont.resume(throwing: BiometricError.failed)
                }
            }
            
        }
    }
}
