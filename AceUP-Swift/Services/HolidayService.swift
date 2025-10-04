//
//  HolidayService.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import Foundation

final class HolidayService {
    enum ServiceError: Error, LocalizedError {
        case badURL, badStatus(Int), decoding
        var errorDescription: String? {
            switch self {
            case .badURL: return "URL inválida."
            case .badStatus(let c): return "La API respondió con código \(c)."
            case .decoding: return "No se pudo interpretar la respuesta."
            }
        }
    }

    private let baseURL = "https://date.nager.at/api/v3"
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func fetchHolidays(countryCode: String, year: Int) async throws -> [Holiday] {
        guard let url = URL(string: "\(baseURL)/PublicHolidays/\(year)/\(countryCode)") else {
            throw ServiceError.badURL
        }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ServiceError.badStatus(-1) }
        guard (200..<300).contains(http.statusCode) else { throw ServiceError.badStatus(http.statusCode) }

        do { return try JSONDecoder().decode([Holiday].self, from: data) }
        catch { throw ServiceError.decoding }
    }

    func getCountries() async throws -> [Country] {
        guard let url = URL(string: "\(baseURL)/AvailableCountries") else {
            throw ServiceError.badURL
        }
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode([Country].self, from: data)
    }
}
