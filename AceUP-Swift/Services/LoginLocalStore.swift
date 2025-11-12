//
//  LoginLocalStore.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 11/11/25.
//

import Foundation

struct LoginLocalStore {
    static let shared = LoginLocalStore()
    private let d = UserDefaults.standard

    private enum K {
        static let lastEmail = "login.lastEmail"
        static let rememberMe = "login.rememberMe"
        static let enableBiometric = "login.enableBiometric"
    }

    var lastEmail: String {
        get { d.string(forKey: K.lastEmail) ?? "" }
        set { d.set(newValue, forKey: K.lastEmail) }
    }

    var rememberMe: Bool {
        get { d.object(forKey: K.rememberMe) as? Bool ?? false }
        set { d.set(newValue, forKey: K.rememberMe) }
    }

    var enableBiometric: Bool {
        get { d.object(forKey: K.enableBiometric) as? Bool ?? false }
        set { d.set(newValue, forKey: K.enableBiometric) }
    }

    func clear() {
        d.removeObject(forKey: K.lastEmail)
        d.removeObject(forKey: K.rememberMe)
        d.removeObject(forKey: K.enableBiometric)
    }
}
