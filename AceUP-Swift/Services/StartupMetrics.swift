import Foundation
import FirebaseAnalytics
import FirebaseFirestore
import FirebaseAuth

final class StartupMetrics {
    static let shared = StartupMetrics()
    private var t0: TimeInterval?

    // Marca inicio de medición
    func markStart() {
        t0 = CFAbsoluteTimeGetCurrent()
    }

    // Fin de medición + envío
    func markFirstFrame(startupType: String) {
        guard let start = t0 else { return }
        let end = CFAbsoluteTimeGetCurrent()
        let ms = Int((end - start) * 1000.0)

        // 1) GA4
        Analytics.logEvent("app_load_time", parameters: [
            "time_ms": ms,
            "startup_type": startupType,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        ])

        // 2) (Opcional) guardar en Firestore por sesión/usuario
        let db = Firestore.firestore()
        let uid = Auth.auth().currentUser?.uid ?? "anon"
        db.collection("metrics").document(uid).collection("sessions").addDocument(data: [
            "metric": "app_load_time",
            "time_ms": ms,
            "startup_type": startupType,
            "platform": "iOS",
            "created_at": FieldValue.serverTimestamp()
        ])
    }

    // Compatibilidad con tu llamada existente:
    static func markFirstFrameLoaded() {
        StartupMetrics.shared.markFirstFrame(startupType: "cold")
    }
}