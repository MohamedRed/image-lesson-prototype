import SwiftUI
import StripePaymentSheet
import AccommodationsService
import CoreLocation

struct BookingView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    
    let property: AccommodationProperty
    let roomType: RoomType
    let ratePlan: RatePlan
    
    @State private var guests: [GuestInfo] = []
    @State private var specialRequests = ""
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentResult: PaymentSheetResult?
    @State private var showingPaymentSheet = false
    @State private var currentStep: BookingStep = .guestDetails
    @State private var agreedToTerms = false
    @State private var subscribedToUpdates = false
    
    enum BookingStep {
        case guestDetails
        case paymentDetails
        case confirmation
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator
                
                ScrollView {
                    VStack(spacing: 24) {
                        bookingSummary
                        
                        switch currentStep {
                        case .guestDetails:
                            guestDetailsSection
                        case .paymentDetails:
                            paymentDetailsSection
                        case .confirmation:
                            confirmationSection
                        }
                    }
                    .padding()
                }
                
                bottomActionButton
            }
            .navigationTitle("Book Your Stay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel booking")
                    .accessibilityHint("Returns to property details without booking")
                    .accessibilityIdentifier(AccessibilityIdentifiers.Booking.cancelButton)
                }
            }
        }
        .onAppear {
            setupInitialGuests()
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 0) {
            ForEach(BookingStep.allCases.indices, id: \.self) { index in
                let step = BookingStep.allCases[index]
                let isActive = stepIndex(step) <= stepIndex(currentStep)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(isActive ? Color.accentColor : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    
                    Text(stepTitle(step))
                        .font(.caption)
                        .fontWeight(step == currentStep ? .semibold : .regular)
                        .foregroundColor(isActive ? .primary : .secondary)
                }
                
                if index < BookingStep.allCases.count - 1 {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityHelper.bookingProgressLabel(currentStep: stepIndex(currentStep) + 1, totalSteps: BookingStep.allCases.count, stepName: stepTitle(currentStep)))
        .accessibilityIdentifier(AccessibilityIdentifiers.Booking.progressIndicator)
    }
    
    // MARK: - Booking Summary
    
    private var bookingSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Booking Summary")
                .font(.headline)
            
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: property.photos.first?.url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(property.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    Text(roomType.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(ratePlan.mealPlan.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(formatDateRange())
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("2 nights") // Calculate from date range
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Price breakdown
            VStack(spacing: 8) {
                PriceRow(title: "Room rate (2 nights)", amount: 400.00, currency: "USD")
                PriceRow(title: "Taxes & fees", amount: 60.00, currency: "USD")
                
                Divider()
                
                PriceRow(
                    title: "Total",
                    amount: 460.00,
                    currency: "USD",
                    isTotal: true
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Guest Details Section
    
    private var guestDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guest Details")
                .font(.headline)
            
            ForEach(guests.indices, id: \.self) { index in
                GuestForm(guest: $guests[index], isLead: index == 0)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Special Requests")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Any special requests? (optional)", text: $specialRequests, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
        }
    }
    
    // MARK: - Payment Details Section
    
    private var paymentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Details")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Payment Method")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Button {
                    showingPaymentSheet = true
                } label: {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.accentColor)
                        
                        Text("Add Payment Method")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Agree to Terms & Conditions", isOn: $agreedToTerms)
                    .font(.subheadline)
                
                Toggle("Subscribe to booking updates", isOn: $subscribedToUpdates)
                    .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Cancellation Policy")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(ratePlan.cancellationPolicy.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Confirmation Section
    
    private var confirmationSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Booking Confirmed!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your reservation has been successfully booked")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ConfirmationRow(title: "Confirmation Code", value: "ABC123456")
                ConfirmationRow(title: "Check-in", value: formatDate(viewModel.searchRequest.dateRange.startDate))
                ConfirmationRow(title: "Check-out", value: formatDate(viewModel.searchRequest.dateRange.endDate))
                ConfirmationRow(title: "Guests", value: "\(guests.count) guest\(guests.count == 1 ? "" : "s")")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            VStack(spacing: 12) {
                Button("View Booking Details") {
                    // Navigate to booking details
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Share Booking") {
                    // Share booking details
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
    
    // MARK: - Bottom Action Button
    
    private var bottomActionButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                if currentStep != .confirmation {
                    if currentStep != .guestDetails {
                        Button("Previous") {
                            previousStep()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Go back to previous step")
                        .accessibilityHint("Returns to the previous booking step")
                        .accessibilityIdentifier(AccessibilityIdentifiers.Booking.previousButton)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == .paymentDetails ? "Complete Booking" : "Continue") {
                        nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                    .accessibilityLabel(currentStep == .paymentDetails ? "Complete your booking" : "Continue to next step")
                    .accessibilityHint(currentStep == .paymentDetails ? "Processes payment and confirms booking" : "Proceeds to the next booking step")
                    .accessibilityIdentifier(currentStep == .paymentDetails ? AccessibilityIdentifiers.Booking.completeBookingButton : AccessibilityIdentifiers.Booking.continueButton)
                } else {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Booking completed, return to property")
                    .accessibilityHint("Closes booking and returns to property details")
                    .accessibilityIdentifier(AccessibilityIdentifiers.Booking.continueButton)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialGuests() {
        let guestCount = viewModel.searchRequest.guests.adults
        guests = (0..<guestCount).map { index in
            GuestInfo(isLead: index == 0)
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .guestDetails:
            return guests.allSatisfy { $0.isValid }
        case .paymentDetails:
            return agreedToTerms && paymentResult != nil
        case .confirmation:
            return true
        }
    }
    
    private func nextStep() {
        switch currentStep {
        case .guestDetails:
            currentStep = .paymentDetails
        case .paymentDetails:
            if paymentResult != nil {
                processBooking()
            }
        case .confirmation:
            break
        }
    }
    
    private func previousStep() {
        switch currentStep {
        case .paymentDetails:
            currentStep = .guestDetails
        default:
            break
        }
    }
    
    private func processBooking() {
        let bookingGuests = guests.map { guestInfo in
            Guest(
                firstName: guestInfo.firstName,
                lastName: guestInfo.lastName,
                email: guestInfo.email,
                phone: guestInfo.phone,
                isLead: guestInfo.isLead
            )
        }
        
        viewModel.createBooking(
            roomTypeId: roomType.id,
            ratePlanId: ratePlan.id,
            guests: bookingGuests,
            paymentMethodId: "pm_test_123", // From Stripe
            specialRequests: specialRequests.isEmpty ? nil : specialRequests
        )
        
        currentStep = .confirmation
    }
    
    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            // Payment successful
            break
        case .canceled:
            // Payment canceled
            break
        case .failed(let error):
            // Handle payment error
            print("Payment failed: \(error)")
        }
    }
    
    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        let checkIn = formatter.string(from: viewModel.searchRequest.dateRange.startDate)
        let checkOut = formatter.string(from: viewModel.searchRequest.dateRange.endDate)
        
        return "\(checkIn) - \(checkOut)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func stepIndex(_ step: BookingStep) -> Int {
        BookingStep.allCases.firstIndex(of: step) ?? 0
    }
    
    private func stepTitle(_ step: BookingStep) -> String {
        switch step {
        case .guestDetails: return "Details"
        case .paymentDetails: return "Payment"
        case .confirmation: return "Confirmed"
        }
    }
}

// MARK: - Supporting Views

struct GuestForm: View {
    @Binding var guest: GuestInfo
    let isLead: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isLead ? "Lead Guest" : "Guest \(guest.id)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isLead ? .accentColor : .primary)
                .accessibleHeading(level: .h3)
            
            HStack(spacing: 12) {
                TextField("First Name", text: $guest.firstName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("First name")
                    .accessibilityHint("Enter guest's first name")
                
                TextField("Last Name", text: $guest.lastName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Last name")
                    .accessibilityHint("Enter guest's last name")
            }
            
            if isLead {
                TextField("Email", text: $guest.email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .accessibilityLabel("Email address")
                    .accessibilityHint("Enter lead guest's email address")
                
                TextField("Phone (optional)", text: $guest.phone)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.phonePad)
                    .accessibilityLabel("Phone number, optional")
                    .accessibilityHint("Enter phone number if desired")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AccessibilityHelper.guestFormLabel(guestIndex: 0, isLead: isLead))
        .accessibilityIdentifier(AccessibilityIdentifiers.Booking.guestForm(0))
    }
}

struct PriceRow: View {
    let title: String
    let amount: Double
    let currency: String
    let isTotal: Bool
    
    init(title: String, amount: Double, currency: String, isTotal: Bool = false) {
        self.title = title
        self.amount = amount
        self.currency = currency
        self.isTotal = isTotal
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(isTotal ? .headline : .subheadline)
                .fontWeight(isTotal ? .semibold : .regular)
            
            Spacer()
            
            Text("$\(amount, specifier: "%.2f")")
                .font(isTotal ? .headline : .subheadline)
                .fontWeight(isTotal ? .semibold : .regular)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityHelper.priceBreakdownLabel(title: title, amount: amount, currency: currency, isTotal: isTotal))
    }
}

struct ConfirmationRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Guest Info Model

struct GuestInfo: Identifiable {
    let id = UUID()
    var firstName = ""
    var lastName = ""
    var email = ""
    var phone = ""
    let isLead: Bool
    
    var isValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && (!isLead || !email.isEmpty)
    }
}

// MARK: - Extensions

extension BookingView.BookingStep: CaseIterable {
    static var allCases: [BookingView.BookingStep] {
        [.guestDetails, .paymentDetails, .confirmation]
    }
}

#Preview {
    BookingView(
        property: AccommodationProperty(
            id: "test-property",
            providerRefs: [],
            name: "Test Hotel",
            type: .hotel,
            rating: 4.5,
            reviewsCount: 150,
            address: Address(
                city: "San Francisco",
                country: "US",
                formattedAddress: "123 Test St, San Francisco, CA"
            ),
            coordinates: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            photos: [],
            amenities: [],
            safetyFeatures: [],
            checkInTime: "15:00",
            checkOutTime: "11:00",
            policies: PropertyPolicies(
                cancellationPolicy: CancellationPolicy(
                    type: .flexible,
                    description: "Free cancellation up to 24 hours before check-in"
                )
            )
        ),
        roomType: RoomType(
            id: "test-room",
            name: "Deluxe Room",
            capacity: RoomCapacity(adults: 2),
            beds: [BedConfiguration(type: .queen, count: 1)],
            amenities: [],
            images: []
        ),
        ratePlan: RatePlan(
            id: "test-plan",
            name: "Best Rate",
            mealPlan: .roomOnly,
            cancellationPolicy: CancellationPolicy(
                type: .flexible,
                description: "Free cancellation"
            ),
            paymentType: .payNow
        )
    )
    .environmentObject(AccommodationsViewModel())
}