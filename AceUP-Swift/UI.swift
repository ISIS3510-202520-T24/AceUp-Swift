//
//  UI.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 19/09/25.
//

import SwiftUI

// Paleta simple sin assets/imagenes
enum UI {
    static let bg      = Color(.systemGroupedBackground)
    static let primary = Color(red: 0.20, green: 0.84, blue: 0.68)
    static let navy    = Color(red: 0.09, green: 0.18, blue: 0.33)
    static let muted   = Color(.systemGray)
}

// Botón primario
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(UI.primary)
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            )
            .shadow(color: UI.primary.opacity(0.25), radius: 8, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

// Campo de texto
struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    init(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) {
        self.placeholder = placeholder
        self._text = text
        self.keyboard = keyboard
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(UI.muted.opacity(0.35), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white)
                    )
            )
    }
}

// Campo de contraseña con icono (sin lógica)
struct StyledSecureField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        HStack {
            SecureField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Image(systemName: "eye.slash")
                .foregroundColor(UI.muted)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(UI.muted.opacity(0.35), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white)
                )
        )
    }
}

// Toggle con estilo checkbox cuadrado
struct CheckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(UI.muted.opacity(0.5), lineWidth: 1.2)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(configuration.isOn ? UI.primary : .white)
                    )
                if configuration.isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
