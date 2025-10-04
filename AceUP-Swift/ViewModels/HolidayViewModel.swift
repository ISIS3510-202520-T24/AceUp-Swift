//
//  HolidayViewModel.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import Foundation
import SwiftUI

@MainActor
final class HolidayViewModel: ObservableObject {
    @Published var holidays: [Holiday] = []
    @Published var countries: [Country] = []
    @Published var selectedCountry: String = "US"
    @Published var year: Int = Calendar.current.component(.year, from: Date())
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: HolidayService

    init(service: HolidayService = HolidayService()) {
        self.service = service
    }

    func loadCountries() async {
        do {
            countries = try await service.getCountries()
            // Si el país seleccionado no está en la lista, lo dejamos igual (fallback).
        } catch {
            // Fallback mínimo para no romper la UI
            countries = [
                Country(countryCode: "US", name: "United States"),
                Country(countryCode: "CO", name: "Colombia"),
                Country(countryCode: "GB", name: "United Kingdom"),
                Country(countryCode: "CA", name: "Canada"),
                Country(countryCode: "MX", name: "Mexico"),
                Country(countryCode: "ES", name: "Spain")
            ]
        }
    }

    func loadHolidays() async {
        isLoading = true
        errorMessage = nil
        do {
            var items = try await service.fetchHolidays(countryCode: selectedCountry, year: year)
            items.sort { $0.dateValue < $1.dateValue }
            holidays = items
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load holidays"
            holidays = []
        }
        isLoading = false
    }
}
