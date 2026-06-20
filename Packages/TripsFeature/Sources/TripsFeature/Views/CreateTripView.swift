import SwiftUI
import TripsService

struct CreateTripView: View {
    @EnvironmentObject private var viewModel: TripsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var scope: TripScope = .international
    @State private var isFixedDates = true
    @State private var startDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1 week from now
    @State private var endDate = Date().addingTimeInterval(14 * 24 * 60 * 60) // 2 weeks from now
    @State private var flexibleDays = 3
    @State private var days = 7
    @State private var nights = 6
    @State private var budget = ""
    @State private var budgetCurrency = "USD"
    @State private var mustInclude: [String] = []
    @State private var newDestination = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Trip Details") {
                    TextField("Trip title", text: $title)
                    
                    Picker("Trip scope", selection: $scope) {
                        Text("Local").tag(TripScope.local)
                        Text("Domestic").tag(TripScope.domestic)
                        Text("International").tag(TripScope.international)
                        Text("Intercontinental").tag(TripScope.intercontinental)
                    }
                }
                
                Section("Duration") {
                    Toggle("Fixed dates", isOn: $isFixedDates)
                    
                    if isFixedDates {
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End date", selection: $endDate, displayedComponents: .date)
                    } else {
                        Stepper("Days: \(days)", value: $days, in: 1...60)
                        Stepper("Nights: \(nights)", value: $nights, in: 0...59)
                        Stepper("Flexible by \(flexibleDays) days", value: $flexibleDays, in: 1...14)
                    }
                }
                
                Section("Budget") {
                    HStack {
                        TextField("Budget", text: $budget)
                            .keyboardType(.decimalPad)
                        
                        Picker("Currency", selection: $budgetCurrency) {
                            Text("USD").tag("USD")
                            Text("EUR").tag("EUR")
                            Text("GBP").tag("GBP")
                            Text("JPY").tag("JPY")
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Must include") {
                    HStack {
                        TextField("Add destination", text: $newDestination)
                        Button("Add") {
                            if !newDestination.isEmpty {
                                mustInclude.append(newDestination)
                                newDestination = ""
                            }
                        }
                        .disabled(newDestination.isEmpty)
                    }
                    
                    ForEach(mustInclude, id: \.self) { destination in
                        HStack {
                            Text(destination)
                            Spacer()
                            Button("Remove") {
                                mustInclude.removeAll { $0 == destination }
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Create Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTrip()
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        if isFixedDates { return !title.isEmpty && startDate < endDate && (budget.isEmpty || Double(budget) != nil) }
        return !title.isEmpty && days > 0 && (budget.isEmpty || Double(budget) != nil)
    }
    
    private func createTrip() {
        isCreating = true
        
        let duration = TripDuration(days: days, nights: nights, isFlexible: !isFixedDates)
        let startWindow: DateInterval? = isFixedDates ? DateInterval(start: startDate, end: endDate) : nil
        
        let budgetConstraint: BudgetConstraint? = {
            if let amount = Double(budget), amount > 0 {
                return BudgetConstraint(total: Money(amount: amount, currency: budgetCurrency))
            }
            return nil
        }()
        
        let constraints = TripConstraints(
            budget: budgetConstraint,
            seasons: [],
            visaRequirements: [],
            accessibility: AccessibilityNeeds(),
            dietary: [],
            mobility: .normal,
            familyFriendly: false,
            petFriendly: false,
            mustInclude: mustInclude,
            mustAvoid: []
        )
        
        Task {
            await viewModel.createTrip(
                title: title,
                scope: scope,
                duration: duration,
                constraints: constraints
            )
            
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

#Preview {
    CreateTripView()
        .environmentObject(TripsViewModel(service: MockTripsService()))
}