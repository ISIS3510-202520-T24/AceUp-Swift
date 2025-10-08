//
//  GroupQRCodeView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct GroupQRCodeView: View {
    let group: CalendarGroup
    @Environment(\.presentationMode) var presentationMode
    @State private var qrCodeImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 15) {
                    Text("Código QR del Grupo")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(UI.navy)
                    
                    Text(group.name)
                        .font(.headline)
                        .foregroundColor(UI.muted)
                }
                
                VStack(spacing: 20) {
                    if let qrImage = qrCodeImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .background(Color.white)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 250, height: 250)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.5)
                            )
                    }
                    
                    VStack(spacing: 10) {
                        Text("Invitation Code")
                            .font(.subheadline)
                            .foregroundColor(UI.muted)
                        
                        if let inviteCode = group.inviteCode {
                            HStack {
                                Text(inviteCode)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(UI.navy)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(UI.neutralLight)
                                    )
                                
                                Button(action: {
                                    UIPasteboard.general.string = inviteCode
                                   
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(UI.primary)
                                        .font(.title3)
                                }
                                
                                Button(action: shareInviteCode) {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(UI.primary)
                                        .font(.title3)
                                }
                            }
                        }
                    }
                }
                
                VStack(spacing: 15) {
                    Text("Share this code")
                        .font(.headline)
                        .foregroundColor(UI.navy)
                    
                    Text("Users can scan this QR code or enter the code manually to join the group")
                        .font(.body)
                        .foregroundColor(UI.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                Button(action: shareQRCode) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(UI.primary)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                }
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            generateQRCode()
        }
    }
    
    private func generateQRCode() {
        guard let inviteCode = group.inviteCode else { 
            print("No invite code available for group: \(group.name)")
            return 
        }
        
        let qrString = "aceup://join/\(inviteCode)"
        print("Generating QR code for: \(qrString)")
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        let data = Data(qrString.utf8)
        filter.message = data
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code for better quality
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
                print("QR code generated successfully")
            } else {
                print("Failed to create CGImage from CIImage")
            }
        } else {
            print("Failed to generate QR code output image")
        }
    }
    
    private func shareQRCode() {
        SharingService.shared.shareGroupInvitationEnhancedFromSwiftUI(group: group)
    }
    
    private func shareInviteCode() {
        SharingService.shared.shareInvitationCodeFromSwiftUI(group: group)
    }
}

#Preview {
    GroupQRCodeView(
        group: CalendarGroup(
            id: "1",
            name: "Mobile Dev Team",
            description: "iOS Development Project Group",
            members: [],
            createdAt: Date(),
            createdBy: "user1",
            color: "#4ECDC4",
            inviteCode: "ABC123"
        )
    )
}