//
//  Avatar.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 11/11/25.
//

import SwiftUI

enum AvatarKey: String, CaseIterable, Identifiable, Codable {
    case a1 = "avatar1"
    case a2 = "avatar2"
    case a3 = "avatar3"
    case a4 = "avatar4"

    var id: String { rawValue }
    var assetName: String { rawValue }

    func image() -> Image {
        Image(assetName) // requiere las imágenes en Assets
    }

    func uiImage() -> UIImage? {
        UIImage(named: assetName)
    }

    func pngData() -> Data? {
        uiImage()?.pngData()
    }
}
