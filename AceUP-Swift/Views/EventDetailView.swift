//
//  EventDetailView.swift
//  AceUP-Swift
//
//  Created by Ana M. Sánchez on 2/12/25.
//

import SwiftUI
import SafariServices

struct EventDetailView: View {
    let event: UniandesEvent
    let onFavoriteToggle: () -> Void
    let onSaveToggle: () -> Void
    let onAddToCalendar: () -> Void
    let onRegister: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showShareSheet = false
    @State private var showRegistrationConfirmation = false
    @State private var showCalendarConfirmation = false
    @State private var showSafariView = false
    @State private var showRegistrationSafari = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero Section
                    heroSection
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Category and Status
                        categoryAndStatusSection
                        
                        // Title
                        titleSection
                        
                        // Date and Time
                        dateTimeSection
                        
                        // Location
                        if event.location != nil {
                            locationSection
                        }
                        
                        // Description
                        if event.description != nil {
                            descriptionSection
                        }
                        
                        // Organizer
                        if event.organizer != nil {
                            organizerSection
                        }
                        
                        // Capacity
                        if event.capacity != nil {
                            capacitySection
                        }
                        
                        // Tags
                        if !event.tags.isEmpty {
                            tagsSection
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Quick Actions
                        quickActionsSection
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Main Actions
                        mainActionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .background(UI.neutralLight)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(UI.muted)
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(UI.navy)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: event.detailURL) {
                ShareSheet(items: [url, event.title])
            }
        }
        .sheet(isPresented: $showSafariView) {
            if let url = URL(string: event.detailURL) {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showRegistrationSafari) {
            if let registrationURL = event.registrationURL,
               let url = URL(string: registrationURL) {
                SafariView(url: url)
            }
        }
        .alert("Agregar al calendario", isPresented: $showCalendarConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Agregar") {
                onAddToCalendar()
            }
        } message: {
            Text("¿Deseas agregar este evento a tu calendario?")
        }
        .alert("Inscribirse al evento", isPresented: $showRegistrationConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Inscribirse") {
                onRegister()
                if event.registrationURL != nil {
                    showRegistrationSafari = true
                }
            }
        } message: {
            Text("Se abrirá la página de inscripción donde podrás completar el registro.")
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Image with fallback to gradient
            CachedAsyncImage(url: event.imageURL) {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: event.category.color),
                        Color(hex: event.category.color).opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(height: 200)
            .clipped()
            
            // Gradient overlay for better text readability
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            
            // Category icon overlay (only shown if no image)
            if event.imageURL == nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: event.category.icon)
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.2))
                            .padding(30)
                    }
                }
                .frame(height: 200)
            }
        }
    }
    
    // MARK: - Category and Status
    
    private var categoryAndStatusSection: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: event.category.icon)
                    .font(.caption)
                Text(event.category.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: event.category.color))
            .cornerRadius(12)
            
            if event.isRegistered {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Inscrito")
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .cornerRadius(12)
            }
            
            if event.isToday {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                    Text("Hoy")
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange)
                .cornerRadius(12)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Title
    
    private var titleSection: some View {
        Text(event.title)
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(UI.navy)
    }
    
    // MARK: - Date and Time
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EventInfoRow(
                icon: "calendar",
                title: "Fecha",
                value: event.dateRange,
                color: "#50E3C2"
            )
            
            EventInfoRow(
                icon: "clock",
                title: "Hora",
                value: event.timeRange,
                color: "#50E3C2"
            )
            
            if event.daysUntil > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .foregroundColor(.orange)
                    Text("En \(event.daysUntil) día\(event.daysUntil == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                .padding(.leading, 4)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - Location
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ubicación", systemImage: "mappin.circle.fill")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Text(event.location ?? "")
                .font(.body)
                .foregroundColor(UI.muted)
            
            // Add map button here if needed
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - Description
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Descripción", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            Text(event.description ?? "")
                .font(.body)
                .foregroundColor(UI.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - Organizer
    
    private var organizerSection: some View {
        EventInfoRow(
            icon: "person.circle.fill",
            title: "Organizador",
            value: event.organizer ?? "",
            color: "#122C4A"
        )
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - Capacity
    
    private var capacitySection: some View {
        EventInfoRow(
            icon: "person.3.fill",
            title: "Capacidad",
            value: "\(event.capacity ?? 0) personas",
            color: "#122C4A"
        )
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - Tags
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Etiquetas", systemImage: "tag.fill")
                .font(.headline)
                .foregroundColor(UI.navy)
            
            FlowLayout(spacing: 8) {
                ForEach(event.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(UI.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(UI.primary.opacity(0.1))
                        .cornerRadius(16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            QuickActionButton(
                icon: event.isFavorite ? "star.fill" : "star",
                title: event.isFavorite ? "Favorito" : "Marcar",
                color: event.isFavorite ? .yellow : UI.muted,
                action: onFavoriteToggle
            )
            
            QuickActionButton(
                icon: event.savedForLater ? "bookmark.fill" : "bookmark",
                title: event.savedForLater ? "Guardado" : "Guardar",
                color: event.savedForLater ? UI.primary : UI.muted,
                action: onSaveToggle
            )
            
            QuickActionButton(
                icon: "calendar.badge.plus",
                title: "Calendario",
                color: UI.primary,
                action: {
                    showCalendarConfirmation = true
                }
            )
            
            QuickActionButton(
                icon: "square.and.arrow.up",
                title: "Compartir",
                color: UI.primary,
                action: {
                    showShareSheet = true
                }
            )
        }
    }
    
    // MARK: - Main Actions
    
    private var mainActionsSection: some View {
        VStack(spacing: 12) {
            if event.isRegistrationRequired && !event.isRegistered {
                Button(action: {
                    showRegistrationConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Inscribirse al evento")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(UI.primary)
                    .cornerRadius(12)
                }
            }
            
            Button(action: {
                showSafariView = true
            }) {
                HStack {
                    Image(systemName: "safari")
                    Text("Ver en navegador")
                        .fontWeight(.semibold)
                }
                .foregroundColor(UI.navy)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(UI.navy, lineWidth: 2)
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct EventInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(hex: color))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(UI.muted)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(UI.navy)
            }
            
            Spacer()
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(UI.navy)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    EventDetailView(
        event: UniandesEvent(
            id: "1",
            title: "I-MAT International Conference",
            description: "Conferencia internacional sobre matemáticas aplicadas y tecnología. Este evento reunirá a expertos de todo el mundo para discutir los últimos avances en el campo.",
            category: .institutional,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            startTime: "7:50 am",
            endTime: "2:00 pm",
            location: "Edificio ML, Auditorio Principal",
            imageURL: nil,
            detailURL: "https://evento.uniandes.edu.co/en/i-matinternationalconference2025",
            isRegistrationRequired: true,
            registrationURL: "https://connect.eventtia.com/users/sso/uniandes",
            organizer: "Departamento de Matemáticas",
            capacity: 200,
            tags: ["matemáticas", "internacional", "investigación"],
            isFavorite: false,
            isRegistered: false,
            savedForLater: false
        ),
        onFavoriteToggle: {},
        onSaveToggle: {},
        onAddToCalendar: {},
        onRegister: {}
    )
}
