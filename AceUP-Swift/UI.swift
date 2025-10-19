//
//  UI.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 19/09/25.
//

import SwiftUI

extension Color {
    /// Create a Color from a hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


enum UI {
    static let primary = Color(hex: "#50E3C2")     
    static let navy    = Color(hex: "#122C4A")    
    

    static let blueLight   = Color(hex: "#2A4A6B")
    static let blueMedium  = Color(hex: "#1E3A5F") 
    static let blueDark    = Color(hex: "#0F1F35")
    static let blueDeep    = Color(hex: "#081220") 
    

    static let primaryDark = Color(hex: "#60F3D2") 
   
    static let neutralLight = Color(hex: "#F8F6F0") 
    static let neutralMedium = Color(hex: "#E8E6E0") 
    static let neutralDark = Color(hex: "#2A2520")   
    
    static let bg = neutralLight
    
    static let accent = Color(hex: "#FF6B6B")      
    static let success = Color(hex: "#4ECDC4")     
    static let warning = Color(hex: "#FFE66D")    
    static let secondary = Color(hex: "#6C757D")   // Added for assignment views

    static let muted = Color(hex: "#8B8680")      
}

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


struct StyledSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isSecured: Bool = true
    @State private var maskedText: String = ""

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        HStack {
            
            TextField(placeholder, text: isSecured ? $maskedText : $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.none) 
                .disableAutocorrection(true)
                .keyboardType(.asciiCapable) 
                .submitLabel(.done)
                .font(.body)
                .onChange(of: maskedText) { oldValue, newValue in
                    if isSecured {
                        
                        if newValue.count > oldValue.count {
                            let newChar = String(newValue.suffix(1))
                            text.append(newChar)
                        }
                        
                        else if newValue.count < oldValue.count {
                            if !text.isEmpty {
                                text.removeLast()
                            }
                        }
                        
                        maskedText = String(repeating: "●", count: text.count)
                    }
                }
                .onChange(of: text) { oldValue, newValue in
                    if isSecured {
                        maskedText = String(repeating: "●", count: newValue.count)
                    }
                }
                .onAppear {
                    if isSecured {
                        maskedText = String(repeating: "●", count: text.count)
                    }
                }

            Button(action: {
                isSecured.toggle()
                if isSecured {
                    maskedText = String(repeating: "●", count: text.count)
                } else {
                    maskedText = text
                }
            }) {
                Image(systemName: isSecured ? "eye.slash" : "eye")
                    .foregroundColor(UI.muted)
            }
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
