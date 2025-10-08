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
    private let dataProvider: HybridHolidayDataProvider
    private let preferencesManager = UserPreferencesManager.shared

    init(service: HolidayService = HolidayService(), 
         dataProvider: HybridHolidayDataProvider? = nil) {
        self.service = service
        self.dataProvider = dataProvider ?? DataSynchronizationManager.shared.getHolidayProvider()
        
        // Load user's preferred country with validation
        let preferredCountry = preferencesManager.selectedCountry
        // Validate that the preferred country is reasonable, fallback to US if needed
        if preferredCountry.count == 2 && preferredCountry.allSatisfy({ $0.isLetter }) {
            selectedCountry = preferredCountry.uppercased()
        } else {
            selectedCountry = "US" // Default fallback
            preferencesManager.selectedCountry = "US"
        }
        
        // Debug: Test API connectivity
        #if DEBUG
        Task {
            print("🧪 Testing Holiday API connectivity...")
            do {
                let testService = HolidayService()
                let testCountries = try await testService.getCountries()
                print("✅ API test successful: \(testCountries.count) countries available")
            } catch {
                print("❌ API test failed: \(error)")
            }
        }
        #endif
    }

    func loadCountries() async {
        print("Loading countries list...")
        do {
            let holidayService = HolidayService()
            countries = try await holidayService.getCountries()
            print("Successfully loaded \(countries.count) countries")
        } catch {
            print("Failed to load countries: \(error)")
            // Fallback to hardcoded countries
            countries = [
                Country(countryCode: "US", name: "United States"),
                Country(countryCode: "CO", name: "Colombia"),
                Country(countryCode: "GB", name: "United Kingdom"),
                Country(countryCode: "CA", name: "Canada"),
                Country(countryCode: "MX", name: "Mexico"),
                Country(countryCode: "ES", name: "Spain"),
                Country(countryCode: "FR", name: "France"),
                Country(countryCode: "DE", name: "Germany"),
                Country(countryCode: "IT", name: "Italy"),
                Country(countryCode: "JP", name: "Japan"),
                Country(countryCode: "AU", name: "Australia"),
                Country(countryCode: "BR", name: "Brazil"),
                Country(countryCode: "AR", name: "Argentina"),
                Country(countryCode: "CL", name: "Chile")
            ]
            print("Using fallback countries list")
        }
    }

    func loadHolidays() async {
        isLoading = true
        errorMessage = nil
        
        print("Loading holidays for country: \(selectedCountry), year: \(year)")
        
        do {
            // First try the external API directly
            let holidayService = HolidayService()
            
            print("Fetching holidays from external API...")
            var items = try await holidayService.fetchHolidays(countryCode: selectedCountry, year: year)
            
            print("Successfully fetched \(items.count) holidays from API")
            items.sort { $0.date < $1.date }
            holidays = items
            
            // Save to local storage in background
            Task {
                do {
                    let localProvider = CoreDataHolidayDataProvider()
                    try await localProvider.saveHolidays(items)
                    print("Successfully saved holidays to local storage")
                } catch {
                    print("Failed to save holidays locally: \(error)")
                }
            }
            
            // Update user preferences
            preferencesManager.selectedCountry = selectedCountry
            
        } catch let apiError {
            print("External API failed with error: \(apiError)")
            
            // If direct API fails, try hybrid provider as fallback
            do {
                print("Trying hybrid provider as fallback...")
                var items = try await dataProvider.fetchHolidays(for: selectedCountry, year: year)
                print("Hybrid provider returned \(items.count) holidays")
                
                items.sort { $0.date < $1.date }
                holidays = items
                
                // Update user preferences
                preferencesManager.selectedCountry = selectedCountry
                
            } catch let fallbackError {
                print("Fallback also failed with error: \(fallbackError)")
                
                let serviceError = apiError as? HolidayService.ServiceError
                let errorMsg = serviceError?.errorDescription ?? "No se pudieron cargar los días festivos. Revisa tu conexión a internet."
                errorMessage = errorMsg
                holidays = []
            }
        }
        
        isLoading = false
        print("Finished loading holidays. Final count: \(holidays.count)")
    }
}
