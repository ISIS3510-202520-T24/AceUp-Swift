import Foundation

enum AppConfigProvider {

    // Lee y parsea Config.plist
    private static func loadConfigPlist() -> [String: Any]? {
        // OJO: si tu archivo se llama distinto, cámbialo aquí.
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist") else {
            print("❌ AppConfigProvider: NO pude encontrar Config.plist en el bundle")
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            print("❌ AppConfigProvider: no pude leer data de Config.plist")
            return nil
        }

        guard
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ),
            let dict = plist as? [String: Any]
        else {
            print("❌ AppConfigProvider: no pude parsear Config.plist como diccionario")
            return nil
        }

        print("✅ AppConfigProvider: cargué Config.plist con keys:", dict.keys)
        return dict
    }

    // URL base de Straico
    static func straicoBaseURL() -> URL? {
        let dict = loadConfigPlist()
        let raw = dict?["STRAICO_API_BASE"] as? String

        // limpiar espacios / saltos / tabs
        let cleaned = raw?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // además quita slashes extra al inicio/final
        let normalized = cleaned?
            .trimmingCharacters(in: CharacterSet(charactersIn: " /"))

        let url = normalized.flatMap { URL(string: $0) }

        print("""
        🔎 straicoBaseURL
           raw        = '\(raw ?? "nil")'
           normalized = '\(normalized ?? "nil")'
           finalURL   = \(String(describing: url))
        """)

        return url
    }

    // API key de Straico
    static func straicoAPIKey() -> String? {
        let dict = loadConfigPlist()
        let key = dict?["STRAICO_API_KEY"] as? String

        if let key {
            print("🔎 straicoAPIKey -> tengo key de longitud \(key.count)")
        } else {
            print("❌ straicoAPIKey -> NO hay STRAICO_API_KEY en el plist")
        }

        return key
    }

    // Flag que decide mock vs real
    // En tu Info del target, agrega una Custom iOS Target Property:
    // AI_API_USE_MOCK = "true" o "false" (String)
    static func useMock() -> Bool {
        let raw = Bundle.main.object(forInfoDictionaryKey: "AI_API_USE_MOCK") as? String
        let flag = raw?.lowercased() == "true"
        print("🔎 AppConfigProvider.useMock -> raw='\(raw ?? "nil")' => \(flag)")
        return flag
    }
}
