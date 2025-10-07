import SwiftUI
import FirebaseFirestore

struct WorkloadAnalysisView: View {
    @StateObject private var repository = OfflineWorkloadAnalysisRepository()
    @StateObject private var assignmentRepository = OfflineAssignmentRepository()
    @State private var selectedAnalysis: WorkloadAnalysis?
    @State private var isGeneratingAnalysis = false
    @State private var showingGenerateAnalysis = false
    
    var currentAnalysis: WorkloadAnalysis? {
        repository.analyses.first
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Offline Status Indicator
                if repository.isOfflineMode || repository.syncStatus != .synced {
                    OfflineStatusIndicator()
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        headerSection
                        
                        if let analysis = selectedAnalysis ?? currentAnalysis {
                            latestAnalysisCard(analysis)
                            workloadChartCard(analysis)
                            recommendationsCard(analysis)
                            analysisHistoryCard
                        } else {
                            emptyStateCard
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("Workload Analysis")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                setupView()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Smart Workload Analysis")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Button(action: { 
                    if isGeneratingAnalysis {
                        return
                    } else {
                        generateQuickAnalysis()
                    }
                }) {
                    if isGeneratingAnalysis {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: UI.primary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title2)
                            .foregroundColor(UI.primary)
                    }
                }
                .disabled(isGeneratingAnalysis)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(.white)
    }
    
    // MARK: - Latest Analysis Card
    private func latestAnalysisCard(_ analysis: WorkloadAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Workload")
                    .font(.headline)
                    .foregroundColor(UI.navy)
                
                Spacer()
                
                Text(DateFormatter.mediumDate.string(from: analysis.analysisDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Balance indicator
            HStack(spacing: 16) {
                // Balance status
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: analysis.workloadBalance.color))
                            .frame(width: 12, height: 12)
                        
                        Text(analysis.workloadBalance.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: analysis.workloadBalance.color))
                    }
                }
                
                Spacer()
                
                // Key metrics
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 12) {
                        metricPill(title: "\(analysis.totalAssignments)", subtitle: "Assignments", color: UI.primary)
                        metricPill(title: String(format: "%.1f", analysis.averageDaily), subtitle: "Avg Daily", color: .orange)
                    }
                    
                    if !analysis.overloadDays.isEmpty {
                        metricPill(title: "\(analysis.overloadDays.count)", subtitle: "Overload Days", color: .red)
                    }
                }
            }
            
            // Description
            Text(analysis.workloadBalance.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private func metricPill(title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }
    
    // MARK: - Empty State Card
    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Analysis Available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Generate your first workload analysis to understand your assignment distribution and get personalized recommendations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Generate Analysis") {
                generateQuickAnalysis()
            }
            .foregroundColor(.white)
            .font(.headline)
            .padding()
            .background(UI.primary)
            .cornerRadius(10)
        }
        .padding(.vertical, 20)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Workload Chart Card
    private func workloadChartCard(_ analysis: WorkloadAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Workload Distribution")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            if !analysis.dailyWorkload.isEmpty {
                workloadChart(analysis.dailyWorkload)
            } else {
                Text("No daily workload data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func workloadChart(_ dailyWorkload: [Date: Double]) -> some View {
        let sortedData = dailyWorkload.sorted { $0.key < $1.key }
        
        // Fallback chart for all iOS versions
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sortedData.enumerated()), id: \.offset) { index, data in
                HStack {
                    Text(DateFormatter.shortDay.string(from: data.key))
                        .font(.caption)
                        .frame(width: 40, alignment: .leading)
                    
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(workloadColor(data.value))
                                .frame(width: max(4, (data.value / 10.0) * geometry.size.width))
                                .cornerRadius(2)
                            
                            Spacer()
                        }
                    }
                    .frame(height: 16)
                    
                    Text(String(format: "%.1f", data.value))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .frame(height: 200)
    }
    
    private func workloadColor(_ value: Double) -> Color {
        switch value {
        case 0..<2:
            return .green
        case 2..<4:
            return .yellow
        case 4..<6:
            return .orange
        default:
            return .red
        }
    }
    
    // MARK: - Recommendations Card
    private func recommendationsCard(_ analysis: WorkloadAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("Recommendations")
                    .font(.headline)
                    .foregroundColor(UI.navy)
            }
            
            if analysis.recommendations.isEmpty {
                Text("No specific recommendations at this time.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, recommendation in
                        recommendationRow(recommendation, index: index)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private func recommendationRow(_ recommendation: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index + 1).")
                .font(.caption)
                .foregroundColor(UI.primary)
                .fontWeight(.semibold)
            
            Text(recommendation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
    
    // MARK: - Analysis History Card
    private var analysisHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis History")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            if repository.analyses.isEmpty {
                Text("No previous analyses available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(repository.analyses.prefix(5)) { analysis in
                        analysisHistoryRow(analysis)
                    }
                    
                    if repository.analyses.count > 5 {
                        Button("View All Analyses") {
                            // TODO: Navigate to full history
                        }
                        .foregroundColor(UI.primary)
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private func analysisHistoryRow(_ analysis: WorkloadAnalysis) -> some View {
        Button(action: {
            selectedAnalysis = analysis
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: analysis.workloadBalance.color))
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(DateFormatter.mediumDate.string(from: analysis.analysisDate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                    
                    Text("\(analysis.totalAssignments) assignments • \(analysis.workloadBalance.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        Task {
            if repository.isOfflineMode {
                repository.refreshData()
                assignmentRepository.refreshData()
            } else {
                try? await repository.syncWithFirebase()
                try? await assignmentRepository.syncWithFirebase()
            }
        }
    }
    
    private func generateQuickAnalysis() {
        isGeneratingAnalysis = true
        
        Task {
            do {
                _ = try await repository.generateAnalysis()
                
                await MainActor.run {
                    isGeneratingAnalysis = false
                }
                
            } catch {
                await MainActor.run {
                    isGeneratingAnalysis = false
                    // Handle error - show alert or toast
                }
            }
        }
    }
}

// MARK: - Extensions
extension Color {
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

extension DateFormatter {
    static let shortDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
    
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    WorkloadAnalysisView()
}