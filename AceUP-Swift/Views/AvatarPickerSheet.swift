//  AvatarPickerSheet.swift
//  AceUp-Swift

import SwiftUI

struct AvatarPickerSheet: View {
    let email: String
    let currentNick: String?

    @State private var selected: AvatarKey
    @Environment(\.dismiss) private var dismiss

    // Inicialización con valor predeterminado y lectura del guardado
    init(email: String, currentNick: String?, preselected: AvatarKey? = nil) {
        self.email = email
        self.currentNick = currentNick
        let initial = preselected ?? AvatarStore.shared.get(for: email) ?? .a1
        _selected = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Avatar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancelar") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Guardar") {
                            AvatarStore.shared.set(for: email, key: selected, currentNick: currentNick)
                            dismiss()
                        }
                    }
                }
        }
    }

    // MARK: - Subvistas (separadas para aliviar el type-checker)

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Elige tu avatar")
                .font(.headline)

            grid

            Spacer()
        }
        .padding()
    }

    private var grid: some View {
        let cols: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 16) {
            ForEach(AvatarKey.allCases, id: \.self) { key in
                avatarButton(for: key)
            }
        }
    }

    private func avatarButton(for key: AvatarKey) -> some View {
        Button(action: { selected = key }) {
            VStack(spacing: 8) {
                key.image()
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(selected == key ? Color.primary : Color.clear, lineWidth: 2)
                    )

                Text(key.assetName.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected == key ? Color.primary.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
