import SwiftUI
import AccommodationsService

struct ImportBookingView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMethod: ImportMethod = .url
    @State private var bookingURL = ""
    @State private var provider = ""
    @State private var confirmationCode = ""
    @State private var lastName = ""
    @State private var isProcessing = false
    @State private var importResult: ImportResult?
    @State private var showingResult = false
    
    enum ImportMethod: CaseIterable {
        case url
        case confirmation
        
        var title: String {
            switch self {
            case .url: return "Import from URL"
            case .confirmation: return "Import from Confirmation"
            }
        }
        
        var icon: String {
            switch self {
            case .url: return "link"
            case .confirmation: return "doc.text"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        methodSelector
                        importForm
                        supportedProvidersSection
                    }
                    .padding()
                }
                
                bottomActionButton
            }
            .navigationTitle("Import Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Import Result", isPresented: $showingResult) {
                Button("OK") {
                    if importResult?.success == true {
                        dismiss()
                    }
                }
            } message: {
                if let result = importResult {
                    Text(result.success ? 
                         "Booking imported successfully!" : 
                         result.error ?? "Import failed")
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 4) {
                Text("Import Existing Booking")
                    .font(.headline)
                
                Text("Add your existing hotel bookings to keep track of all your travels in one place")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Method Selector
    
    private var methodSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How would you like to import?")
                .font(.headline)
            
            HStack(spacing: 16) {
                ForEach(ImportMethod.allCases, id: \.self) { method in
                    MethodCard(
                        method: method,
                        isSelected: selectedMethod == method
                    ) {
                        selectedMethod = method
                    }
                }
            }
        }
    }
    
    // MARK: - Import Form
    
    private var importForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch selectedMethod {
            case .url:
                urlImportForm
            case .confirmation:
                confirmationImportForm
            }
        }
    }
    
    private var urlImportForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste Booking URL")
                .font(.headline)
            
            Text("Copy and paste the URL from your booking confirmation email or booking website")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("https://booking.com/...", text: $bookingURL)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                HStack {
                    Button("Paste from Clipboard") {
                        if let clipboardString = UIPasteboard.general.string {
                            bookingURL = clipboardString
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    
                    Spacer()
                }
            }
            
            // Example URLs
            VStack(alignment: .leading, spacing: 8) {
                Text("Examples:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    ExampleURLRow(text: "booking.com/hotel/us/...")
                    ExampleURLRow(text: "expedia.com/Hotel-Search...")
                    ExampleURLRow(text: "airbnb.com/rooms/...")
                }
            }
        }
    }
    
    private var confirmationImportForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter Booking Details")
                .font(.headline)
            
            Text("Enter your booking confirmation details to import your reservation")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Provider *")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Menu {
                        ForEach(supportedProviders, id: \.self) { providerName in
                            Button(providerName) {
                                provider = providerName
                            }
                        }
                    } label: {
                        HStack {
                            Text(provider.isEmpty ? "Select provider" : provider)
                                .foregroundColor(provider.isEmpty ? .secondary : .primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirmation Code *")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("ABC123456", text: $confirmationCode)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Name *")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Smith", text: $lastName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                }
            }
        }
    }
    
    // MARK: - Supported Providers Section
    
    private var supportedProvidersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supported Providers")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(supportedProviders, id: \.self) { provider in
                    ProviderLogo(name: provider)
                }
            }
            
            Text("More providers coming soon!")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Bottom Action Button
    
    private var bottomActionButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button(isProcessing ? "Importing..." : "Import Booking") {
                importBooking()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canImport || isProcessing)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Properties
    
    private var canImport: Bool {
        switch selectedMethod {
        case .url:
            return !bookingURL.isEmpty && bookingURL.contains("http")
        case .confirmation:
            return !provider.isEmpty && !confirmationCode.isEmpty && !lastName.isEmpty
        }
    }
    
    private var supportedProviders: [String] {
        ["Booking.com", "Expedia", "Hotels.com", "Airbnb", "Agoda", "Kayak"]
    }
    
    // MARK: - Actions
    
    private func importBooking() {
        isProcessing = true
        
        switch selectedMethod {
        case .url:
            viewModel.importBooking(url: bookingURL)
        case .confirmation:
            viewModel.importBooking(
                provider: provider,
                confirmationCode: confirmationCode,
                lastName: lastName
            )
        }
        
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isProcessing = false
            
            // Mock result for demo
            importResult = ImportResult(
                importId: UUID().uuidString,
                success: true,
                booking: nil
            )
            showingResult = true
        }
    }
}

// MARK: - Supporting Views

struct MethodCard: View {
    let method: ImportBookingView.ImportMethod
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: method.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(method.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExampleURLRow: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "link")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct ProviderLogo: View {
    let name: String
    
    var body: some View {
        VStack(spacing: 8) {
            // Placeholder for provider logo
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                )
            
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

#Preview {
    NavigationStack {
        ImportBookingView()
            .environmentObject(AccommodationsViewModel())
    }
}