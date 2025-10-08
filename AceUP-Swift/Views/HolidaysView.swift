//
//  HolidaysView.swift
//  AceUp-Swift
//
//  Created by Ana M. Sánchez on 19/09/25.
//

import SwiftUI

struct HolidaysView: View {
    let onMenuTapped: () -> Void
    @StateObject private var viewModel = HolidayViewModel()

    init(onMenuTapped: @escaping () -> Void = {}) { self.onMenuTapped = onMenuTapped }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            VStack {
                HStack {
                    Button(action: onMenuTapped) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(UI.navy)
                            .font(.body)
                    }
                    Spacer()
                    Text("Holidays")
                        .font(.headline).fontWeight(.semibold)
                        .foregroundColor(UI.navy)
                    Spacer()

                    // Country menu
                    Menu {
                        ForEach(viewModel.countries) { country in
                            Button(country.name) {
                                viewModel.selectedCountry = country.countryCode
                                Task { await viewModel.loadHolidays() }
                            }
                        }
                    } label: {
                        Image(systemName: "globe")
                            .foregroundColor(UI.navy)
                            .font(.body)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)
            .background(Color(hex: "#B8C8DB"))

            // Body
            if viewModel.isLoading {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: UI.blueDark))
                        .scaleEffect(1.5)
                    
                    Text("Cargando días festivos...")
                        .foregroundColor(UI.navy)
                        .font(.body)
                }
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.system(size: 48))
                    
                    Text("Error al cargar los días festivos")
                        .font(.headline)
                        .foregroundColor(UI.navy)
                    
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Reintentar") {
                        Task { await viewModel.loadHolidays() }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(UI.blueDark)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.holidays.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .foregroundColor(UI.muted)
                                    .font(.system(size: 48))
                                
                                Text("No hay días festivos")
                                    .font(.headline)
                                    .foregroundColor(UI.navy)
                                
                                Text("No se encontraron días festivos para \(viewModel.selectedCountry) en \(viewModel.year)")
                                    .foregroundColor(UI.muted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Actualizar") {
                                    Task { await viewModel.loadHolidays() }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(UI.blueDark)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(viewModel.holidays) { holiday in
                                HolidayRow(
                                    name: holiday.localName,
                                    dateRange: formatDate(holiday.date),
                                    onEdit: { /* TODO: acción editar */ }
                                )
                                if holiday.id != viewModel.holidays.last?.id {
                                    Divider().padding(.horizontal, 20)
                                }
                            }
                        }
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 10)
                }
                .refreshable {
                    await viewModel.loadHolidays()
                }
            }
        }
        .background(UI.neutralLight)
        .task {
            await viewModel.loadCountries()
            await viewModel.loadHolidays()
        }
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Año", selection: $viewModel.year) {
                        ForEach((viewModel.year-3)...(viewModel.year+3), id: \.self) { y in
                            Text("\(y)").tag(y)
                        }
                    }
                    Button("Actualizar") {
                        Task { await viewModel.loadHolidays() }
                    }
                } label: {
                    Image(systemName: "calendar")
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: dateString) {
            f.dateStyle = .medium
            return f.string(from: d)
        }
        return dateString
    }
}

struct HolidayRow: View {
    let name: String
    let dateRange: String
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.body).fontWeight(.medium).foregroundColor(UI.navy)
                Text(dateRange).font(.caption).foregroundColor(UI.muted)
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil").font(.body).foregroundColor(UI.muted)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}
