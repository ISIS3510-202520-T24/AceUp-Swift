//
//  CommonTypes.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 2024
//

import Foundation

// MARK: - Common Error Types

struct TimeoutError: Error {
    var localizedDescription: String {
        return "Operation timed out"
    }
}

// MARK: - Common Extensions

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}