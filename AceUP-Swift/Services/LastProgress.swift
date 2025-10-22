//
//  LastProgress.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 13/10/25.
//

import Foundation

/// Guarda el último timestamp de progreso (nota registrada o tarea completada)
final class LastProgress {
    static let shared = LastProgress()
    private let key = "lastProgressTimestamp"

    /// Marca "hubo progreso" ahora
    func update() {
        UserDefaults.standard.set(Date(), forKey: key)
    }

    /// Días transcurridos desde el último progreso; nil si nunca hubo
    func daysSinceLast() -> Int? {
        guard let d = UserDefaults.standard.object(forKey: key) as? Date else { return nil }
        let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
        return max(days, 0)
    }
}
