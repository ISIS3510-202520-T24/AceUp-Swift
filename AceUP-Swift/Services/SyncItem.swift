//
//  SyncItem.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 16/10/25.
//

import Foundation

/// Item genérico para planificar acciones de sincronización.
/// Útil si quieres describir pasos de sync y ejecutarlos en serie.
struct SyncItem<ResultType> {
    let name: String
    let action: () async throws -> ResultType

    init(name: String, action: @escaping () async throws -> ResultType) {
        self.name = name
        self.action = action
    }
}
