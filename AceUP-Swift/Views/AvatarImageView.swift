//
//  AvatarImageView.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 11/11/25.
//

import SwiftUI

struct AvatarImageView: View {
    let email: String
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 14

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
        .onAppear(perform: load)
        .onChange(of: email) { load() } // si cambia el email, recarga
    }

    private func load() {
        if let key = AvatarStore.shared.get(for: email), let img = key.uiImage() {
            self.uiImage = img
            return
        }
        if let snap = ProfileSnapshotCache.shared.get(email: email),
           let data = snap.avatarPNG,
           let img = UIImage(data: data) {
            self.uiImage = img
            return
        }
        self.uiImage = nil
    }
}
