//
//  WebScrapingHelper.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 2/12/25.
//
//  Este archivo contiene helpers para mejorar el web scraping de eventos.
//  Por ahora, el servicio usa datos mock. Para implementar scraping real:
//  1. Considera usar una librería como SwiftSoup
//  2. O implementa un backend proxy que haga el scraping
//  3. O usa la API de Eventtia si está disponible

import Foundation

// MARK: - HTML Parsing Helpers

struct HTMLParser {
    
    /// Extrae eventos de HTML usando regex básico
    /// NOTA: Esto es muy frágil. Considera usar SwiftSoup o similar.
    static func extractEvents(from html: String) -> [ParsedEvent] {
        var events: [ParsedEvent] = []
        
        // Patrón para encontrar bloques de eventos
        // Esto necesita ajustarse según la estructura real de la página
        let eventBlockPattern = #"<article[^>]*class="[^"]*event[^"]*"[^>]*>(.*?)</article>"#
        
        guard let regex = try? NSRegularExpression(pattern: eventBlockPattern, options: [.dotMatchesLineSeparators]) else {
            return events
        }
        
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            let eventBlock = nsString.substring(with: match.range)
            if let event = parseEventBlock(eventBlock) {
                events.append(event)
            }
        }
        
        return events
    }
    
    /// Parsea un bloque individual de evento
    private static func parseEventBlock(_ html: String) -> ParsedEvent? {
        // Extraer título
        guard let title = extractText(from: html, pattern: #"<h[0-9][^>]*>(.*?)</h[0-9]>"#) else {
            return nil
        }
        
        // Extraer categoría
        let category = extractText(from: html, pattern: #"class="category[^"]*">([^<]+)<"#) ?? "OTRO"
        
        // Extraer fecha
        let startDate = extractText(from: html, pattern: #"Fecha Inicio: ([0-9]{4}-[0-9]{2}-[0-9]{2})"#)
        
        // Extraer hora
        let startTime = extractText(from: html, pattern: #"Hora Inicio: ([0-9]{1,2}:[0-9]{2} [ap]m)"#)
        
        // Extraer URL
        let url = extractText(from: html, pattern: #"href="(https://evento\.uniandes\.edu\.co/[^"]+)""#)
        
        return ParsedEvent(
            title: title,
            category: category,
            startDate: startDate,
            startTime: startTime,
            url: url ?? ""
        )
    }
    
    /// Helper para extraer texto usando regex
    private static func extractText(from html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        
        let nsString = html as NSString
        guard let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }
        
        guard match.numberOfRanges > 1 else {
            return nil
        }
        
        let captureRange = match.range(at: 1)
        let text = nsString.substring(with: captureRange)
        
        // Limpiar HTML entities
        return text.htmlDecoded
    }
}

// MARK: - Parsed Event Model

struct ParsedEvent {
    let title: String
    let category: String
    let startDate: String?
    let startTime: String?
    let url: String
}

// MARK: - String HTML Decoding

extension String {
    /// Decodifica entidades HTML básicas
    var htmlDecoded: String {
        guard let data = self.data(using: .utf8) else { return self }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return self
        }
        
        return attributedString.string
    }
}

// MARK: - Alternative: Backend Proxy Approach

/// Si el scraping en el cliente es muy complejo, considera crear un backend
/// que haga el scraping y exponga una API REST simple.
///
/// Ejemplo de arquitectura:
///
/// 1. Backend (Node.js/Python):
///    - Hace scraping de eventos.uniandes.edu.co
///    - Parsea HTML usando Cheerio/BeautifulSoup
///    - Caché en Redis/Firebase
///    - Expone API REST
///
/// 2. App iOS:
///    - Consume API REST del backend
///    - Mucho más simple y confiable
///    - Mejor manejo de errores
///
/// Endpoints sugeridos:
/// GET /api/events              -> Lista de eventos
/// GET /api/events/:id          -> Detalle de evento
/// GET /api/events?category=X   -> Filtrar por categoría
/// GET /api/events?upcoming=true -> Solo próximos

// MARK: - Alternative: Eventtia API

/// Eventtia (la plataforma que usa Uniandes) puede tener una API pública.
/// Verifica si existe documentación en:
/// - https://www.eventtia.com/developers
/// - https://api.eventtia.com/docs
///
/// Si existe API oficial, es MUCHO mejor que hacer scraping.

// MARK: - Example: Improved Service with Backend

class ImprovedUniandesEventsService {
    private let baseURL = "https://tu-backend.com/api"
    
    func fetchEvents() async throws -> [UniandesEvent] {
        guard let url = URL(string: "\(baseURL)/events") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let events = try decoder.decode([UniandesEvent].self, from: data)
        return events
    }
    
    func fetchEventDetail(id: String) async throws -> UniandesEvent {
        guard let url = URL(string: "\(baseURL)/events/\(id)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let event = try decoder.decode(UniandesEvent.self, from: data)
        return event
    }
}

// MARK: - Development Notes

/*
 NOTAS IMPORTANTES PARA IMPLEMENTAR SCRAPING REAL:
 
 1. **Inspecciona la página web**:
    - Abre https://eventos.uniandes.edu.co/
    - Inspecciona el HTML (Safari Developer Tools)
    - Identifica los selectores CSS/XPath de los eventos
    - Verifica si usa JavaScript para cargar contenido
 
 2. **Estrategias posibles**:
    a) Web Scraping directo (complejo si usa JS):
       - Usa SwiftSoup o similar
       - Requiere actualizar cuando cambie la estructura HTML
    
    b) Backend proxy (RECOMENDADO):
       - Crea un servidor simple (Node.js/Python/Go)
       - Expone API REST
       - Más confiable y mantenible
    
    c) API oficial de Eventtia:
       - Investiga si existe
       - Contacta a Eventtia o a Uniandes IT
       - La mejor opción si está disponible
 
 3. **Consideraciones legales**:
    - Verifica términos de servicio de eventos.uniandes.edu.co
    - El scraping debe respetar robots.txt
    - Considera rate limiting
    - No sobrecargues el servidor
 
 4. **Testing**:
    - Crea tests con HTML de ejemplo
    - Mock responses para desarrollo
    - Monitorea cambios en la estructura HTML
 
 5. **Caché**:
    - Implementa caché agresivo (1-6 horas)
    - Reduce carga en el servidor
    - Mejora experiencia offline
 */
