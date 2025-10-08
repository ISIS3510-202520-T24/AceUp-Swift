//
//  HolidayService.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import Foundation

final class HolidayService {
    enum ServiceError: Error, LocalizedError {
        case badURL, badStatus(Int), decoding, noData, networkError(Error)
        var errorDescription: String? {
            switch self {
            case .badURL: return "URL inválida para la API de días festivos."
            case .badStatus(let c): return "La API de días festivos respondió con código \(c). Verifica tu conexión a internet."
            case .decoding: return "No se pudo interpretar la respuesta de la API."
            case .noData: return "No se recibieron datos de la API."
            case .networkError(let error): return "Error de red: \(error.localizedDescription)"
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
        req.timeoutInterval = 10.0 // 10 second timeout

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { 
                throw ServiceError.badStatus(-1) 
            }
            guard (200..<300).contains(http.statusCode) else { 
                throw ServiceError.badStatus(http.statusCode) 
            }
            
            guard !data.isEmpty else {
                throw ServiceError.noData
            }

            do { 
                return try JSONDecoder().decode([Holiday].self, from: data) 
            } catch { 
                print("Decoding error: \(error)")
                print("Raw data: \(String(data: data, encoding: .utf8) ?? "invalid UTF8")")
                throw ServiceError.decoding 
            }
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.networkError(error)
        }
    }

    func getCountries() async throws -> [Country] {
        guard let url = URL(string: "\(baseURL)/AvailableCountries") else {
            throw ServiceError.badURL
        }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10.0 // 10 second timeout
        
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw ServiceError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
            }
            
            guard !data.isEmpty else {
                throw ServiceError.noData
            }
            
            return try JSONDecoder().decode([Country].self, from: data)
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.networkError(error)
        }
    }
}
