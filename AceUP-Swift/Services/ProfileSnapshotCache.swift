//
//  ProfileSnapshotCache.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 11/11/25.
//

import Foundation
import UIKit


struct ProfileSnapshot: Codable {
    var email: String
    var nick: String?
    var avatarPNG: Data? // tiny PNG (e.g., 40–60px) for instant header paint
}


final class ProfileSnapshotCache {
    static let shared = ProfileSnapshotCache()
    private init() {}


    private let udKey = "profile.snapshot.by.email"
    private var mem = NSCache<NSString, NSData>()


    // Get
    func get(email: String) -> ProfileSnapshot? {
        guard !email.isEmpty else { return nil }
        if let data = mem.object(forKey: email as NSString) as Data? {
            return try? JSONDecoder().decode(ProfileSnapshot.self, from: data)
        }
        guard let dict = UserDefaults.standard.dictionary(forKey: udKey) as? [String: Data],
              let raw = dict[email],
              let snap = try? JSONDecoder().decode(ProfileSnapshot.self, from: raw) else { return nil }
        mem.setObject(raw as NSData, forKey: email as NSString)
        return snap
    }


    // Set + persist
    func set(_ snap: ProfileSnapshot) {
        guard !snap.email.isEmpty else { return }
        let raw = (try? JSONEncoder().encode(snap)) ?? Data()
        mem.setObject(raw as NSData, forKey: snap.email as NSString)
        var dict = (UserDefaults.standard.dictionary(forKey: udKey) as? [String: Data]) ?? [:]
        dict[snap.email] = raw
        UserDefaults.standard.set(dict, forKey: udKey)
    }


    // Convenience: set from UI pieces
    func set(email: String, nick: String?, avatarPNG: Data?) {
        set(ProfileSnapshot(email: email, nick: nick, avatarPNG: avatarPNG))
    }
}
