//
//  JoinGroupView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import SwiftUI

struct JoinGroupView: View {
    @StateObject private var sharedCalendarService = SharedCalendarService()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var groupCode = ""
    @State private var showingQRScanner = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var alertMessage = ""
    
    let onGroupJoined: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 15) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(UI.primary)
                    
                    Text("Unirse a un Grupo")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(UI.navy)
                    
                    Text("Escanea un código QR o introduce el código del grupo")
                        .font(.body)
                        .foregroundColor(UI.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 20) {
                    
                    Button(action: {
                        showingQRScanner = true
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                                .foregroundColor(UI.primary)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Escanear Código QR")
                                    .font(.headline)
                                    .foregroundColor(UI.navy)
                                
                                Text("Usa la cámara para escanear")
                                    .font(.caption)
                                    .foregroundColor(UI.muted)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(UI.muted)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        )
                    }
                    
                    
                    HStack {
                        Rectangle()
                            .fill(UI.muted.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("O")
                            .font(.subheadline)
                            .foregroundColor(UI.muted)
                            .padding(.horizontal, 15)
                        
                        Rectangle()
                            .fill(UI.muted.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Código del Grupo")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        TextField("Ej: ABC123", text: $groupCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                            .autocorrectionDisabled()
                            .font(.headline)
                    }
                    
                    Button(action: joinGroupWithCode) {
                        HStack {
                            if sharedCalendarService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            
                            Text(sharedCalendarService.isLoading ? "Uniéndose..." : "Unirse al Grupo")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(groupCode.isEmpty ? UI.muted : UI.primary)
                        .cornerRadius(10)
                    }
                    .disabled(groupCode.isEmpty || sharedCalendarService.isLoading)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(20)
            .background(UI.neutralLight)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView(isPresented: $showingQRScanner) { scannedCode in
                handleScannedCode(scannedCode)
            }
        }
        .alert("¡Éxito!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                onGroupJoined()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: sharedCalendarService.errorMessage) { _, errorMessage in
            if let error = errorMessage {
                alertMessage = error
                showingErrorAlert = true
            }
        }
    }
    
    private func handleScannedCode(_ scannedCode: String) {
        let code: String
        if scannedCode.hasPrefix("aceup://join/") {
            code = String(scannedCode.dropFirst("aceup://join/".count))
        } else {
            code = scannedCode
        }
        
        groupCode = code.uppercased()
        joinGroupWithCode()
    }
    
    private func joinGroupWithCode() {
        let trimmedCode = groupCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard !trimmedCode.isEmpty else {
            alertMessage = "Por favor introduce un código válido"
            showingErrorAlert = true
            return
        }
        
        Task {
            await sharedCalendarService.joinGroupByCode(trimmedCode)
            
            await MainActor.run {
                if sharedCalendarService.errorMessage == nil {
                    alertMessage = "Te has unido al grupo exitosamente"
                    showingSuccessAlert = true
                }
            }
        }
    }
}

#Preview {
    JoinGroupView(onGroupJoined: {})
}