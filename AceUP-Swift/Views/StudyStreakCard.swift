//
//  StudyStreakCard.swift
//  AceUP-Swift
//
//  Created by Julian David  Parra Forero on 3/12/25.
//

import SwiftUI

struct StudyStreakCard: View {
    let summary: StudyStreak
    let isLoading: Bool
    let isOnline: Bool
    let offlineStatus: OfflineStatus
    var onRefresh: (() -> Void)?
    
    private var isVerificationBlocked: Bool {
        !isOnline && offlineStatus == .noData
    }
    
    private var titleText: String {
        summary.currentStreakDays > 0 ? "Study Streak" : "Start Your Study Streak"
    }
    
    private var subtitleText: String {
        if summary.currentStreakDays > 0 {
            return "You have studied \(summary.currentStreakDays) day(s) in a row"
        } else {
            return "Complete an assignment today to begin your streak"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(UI.primary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(UI.muted)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let onRefresh = onRefresh {
                    Button(action: {
                        // Solo intentamos refrescar si no está bloqueado
                        if !isVerificationBlocked {
                            onRefresh()
                        }
                    }) {
                        Image(systemName: isVerificationBlocked ? "wifi.slash" : "arrow.clockwise")
                            .foregroundColor(isVerificationBlocked ? UI.muted : UI.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isVerificationBlocked)
                }
            }
            
            // Métricas
            HStack(spacing: 16) {
                metric(label: "Current", value: "\(summary.currentStreakDays)d")
                metric(label: "Best", value: "\(summary.longestStreakDays)d")
                metric(label: "This week", value: "\(summary.assignmentsCompletedThisWeek)")
                metric(label: "Today", value: "\(summary.assignmentsCompletedToday)")
            }
            
            // Mensaje de bloqueo por offline + sin datos
            if isVerificationBlocked {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(UI.warning)
                        .font(.caption)
                    
                    Text("We can't verify your streaks right now. You're offline and there is no cached study data. Connect to the internet to update your streak.")
                        .font(.caption)
                        .foregroundColor(UI.muted)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(UI.muted)
            Text(value)
                .font(.headline)
                .foregroundColor(UI.navy)
        }
    }
}
