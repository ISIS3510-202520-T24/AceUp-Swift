//
//  FirebaseCourseDataProvider.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 16/10/25.
//

import Foundation
import FirebaseFirestore

final class FirebaseHolidayDataProvider: ObservableObject {
    
    private let db = Firestore.firestore()
    
    // Todos los festivos
    func fetchAllHolidays() async throws -> [Holiday] {
        let snapshot = try await db.collection("holidays")
            .order(by: "date")
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            try? self.documentToHoliday(doc)
        }
    }
    
    // Festivos por país/año
    func fetchHolidays(for country: String, year: Int) async throws -> [Holiday] {
        let snapshot = try await db.collection("holidays")
            .whereField("country", isEqualTo: country)
            .whereField("year", isEqualTo: year)
            .order(by: "date")
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            try? self.documentToHoliday(doc)
        }
    }
    
    // Mapping
    private func documentToHoliday(_ document: QueryDocumentSnapshot) throws -> Holiday {
        let data = document.data()
        
        guard let name = data["name"] as? String,
              let date = data["date"] as? String,
              let countryCode = data["countryCode"] as? String
        else { throw FirebaseError.invalidData }
        
        let localName = data["localName"] as? String ?? name
        let fixed = data["fixed"] as? Bool
        let global = data["global"] as? Bool
        let counties = data["counties"] as? [String]
        let launchYear = data["launchYear"] as? Int
        let types = data["types"] as? [String]
        
        return Holiday(
            date: date,
            localName: localName,
            name: name,
            countryCode: countryCode,
            fixed: fixed,
            global: global,
            counties: counties,
            launchYear: launchYear,
            types: types
        )
    }
}
