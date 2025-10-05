//
//  WorkloadAnalysisView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import SwiftUI

struct WorkloadAnalysisView: View {
    let analysis: WorkloadAnalysis?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let analysis = analysis {
                        // Overview Cards
                        overviewSection(analysis)
                        
                        // Weekly Distribution Chart
                        weeklyDistributionSection(analysis)
                        
                        // Recommendations
                        recommendationsSection(analysis)
                        
                        // Workload Balance
                        workloadBalanceSection(analysis)
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .navigationTitle("Workload Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Overview Section
    
    private func overviewSection(_ analysis: WorkloadAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(UI.primary)
                Text("Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                OverviewCard(
                    title: "Total Assignments",
                    value: "\(analysis.totalAssignments)",
                    icon: "doc.text",
                    color: UI.primary
                )
                
                OverviewCard(
                    title: "Daily Average",
                    value: String(format: "%.1f", analysis.averageDaily),
                    icon: "calendar",
                    color: UI.secondary
                )
                
                OverviewCard(
                    title: "Overload Days",
                    value: "\(analysis.overloadDays.count)",
                    icon: "exclamationmark.triangle",
                    color: analysis.hasOverload ? Color.orange : UI.success
                )
                
                OverviewCard(
                    title: "Balance Score",
                    value: analysis.workloadBalance.displayName,
                    icon: analysis.workloadBalance.icon,
                    color: Color(hex: analysis.workloadBalance.color)
                )
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Weekly Distribution
    
    private func weeklyDistributionSection(_ analysis: WorkloadAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(UI.primary)
                Text("Weekly Distribution")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                Spacer()
            }
            
            WeeklyDistributionChart(dailyWorkload: analysis.dailyWorkload)
        }
    }
    
    // MARK: - Recommendations
    
    private func recommendationsSection(_ analysis: WorkloadAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(UI.primary)
                Text("Smart Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                Spacer()
            }
            
            if analysis.recommendations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundColor(UI.success)
                    
                    Text("Great workload distribution!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                    
                    Text("Your assignments are well balanced across the week.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(UI.success.opacity(0.1))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, recommendation in
                        RecommendationCard(
                            recommendation: recommendation,
                            index: index + 1
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Workload Balance
    
    private func workloadBalanceSection(_ analysis: WorkloadAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "scale.3d")
                    .foregroundColor(UI.primary)
                Text("Workload Balance")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                Spacer()
            }
            
            WorkloadBalanceCard(balance: analysis.workloadBalance)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Analysis Available")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text("Add some assignments to see your workload analysis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 100)
    }
}

// MARK: - Supporting Views

struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct WeeklyDistributionChart: View {
    let dailyWorkload: [Date: [Assignment]]
    
    var body: some View {
        VStack(spacing: 12) {
            // Chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(sortedDays, id: \.self) { day in
                    let count = dailyWorkload[day]?.count ?? 0
                    let maxCount = dailyWorkload.values.map { $0.count }.max() ?? 1
                    let height = count == 0 ? 8.0 : max(8.0, CGFloat(count) / CGFloat(maxCount) * 100)
                    
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(for: count))
                            .frame(width: 30, height: height)
                            .animation(.easeInOut(duration: 0.3), value: height)
                        
                        // Count label
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(UI.navy)
                        
                        // Day label
                        Text(dayLabel(for: day))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 140)
            
            // Legend
            HStack(spacing: 16) {
                LegendItem(color: UI.success, label: "Light (0-1)")
                LegendItem(color: UI.primary, label: "Normal (2)")
                LegendItem(color: .orange, label: "Heavy (3+)")
            }
            .font(.caption2)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var sortedDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: today)
        }
    }
    
    private func barColor(for count: Int) -> Color {
        if count == 0 || count == 1 { return UI.success }
        if count == 2 { return UI.primary }
        return .orange
    }
    
    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

struct RecommendationCard: View {
    let recommendation: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Number badge
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(UI.primary)
                .clipShape(Circle())
            
            // Recommendation text
            Text(recommendation)
                .font(.subheadline)
                .foregroundColor(UI.navy)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct WorkloadBalanceCard: View {
    let balance: WorkloadBalance
    
    var body: some View {
        HStack(spacing: 16) {
            // Balance icon
            Image(systemName: balance.icon)
                .font(.title)
                .foregroundColor(Color(hex: balance.color))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Balance: \(balance.displayName)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(UI.navy)
                
                Text(balanceDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var balanceDescription: String {
        switch balance {
        case .excellent:
            return "Perfect distribution with no overload days"
        case .good:
            return "Well balanced with minimal conflicts"
        case .fair:
            return "Some heavy days that could be redistributed"
        case .poor:
            return "Multiple overload days - consider redistributing work"
        }
    }
}

#Preview {
    WorkloadAnalysisView(analysis: nil)
}