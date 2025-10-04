//
//  HolidayModel.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import Foundation

struct Holiday: Codable, Identifiable, Hashable {
    let date: String            // "yyyy-MM-dd" (Nager.Date)
    let localName: String
    let name: String
    let countryCode: String
    let fixed: Bool?
    let global: Bool?
    let counties: [String]?
    let launchYear: Int?
    let types: [String]?

    // id estable
    var id: String { "\(countryCode)-\(date)-\(localName)" }

    var dateValue: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: date) ?? Date()
    }
}

