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

/// ProfileSnapshotCache now delegates to UnifiedHybridDataProviders for centralized caching
@MainActor
final class ProfileSnapshotCache {
    static let shared = ProfileSnapshotCache()
    private init() {}

    // Get - delegates to unified cache
    func get(email: String) -> ProfileSnapshot? {
        return UnifiedHybridDataProviders.shared.getCachedProfileSnapshot(email: email)
    }

    // Set - delegates to unified cache
    func set(_ snap: ProfileSnapshot) {
        guard !snap.email.isEmpty else { return }
        UnifiedHybridDataProviders.shared.cacheProfileSnapshot(
            email: snap.email,
            nick: snap.nick,
            avatarPNG: snap.avatarPNG
        )
    }

    // Convenience: set from UI pieces
    func set(email: String, nick: String?, avatarPNG: Data?) {
        UnifiedHybridDataProviders.shared.cacheProfileSnapshot(
            email: email,
            nick: nick,
            avatarPNG: avatarPNG
        )
    }
}
