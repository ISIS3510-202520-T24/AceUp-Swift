//
//  Country.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 4/10/25.
//

import Foundation

struct Country: Codable, Identifiable, Hashable {
    let countryCode: String
    let name: String
    var id: String { countryCode }
}
