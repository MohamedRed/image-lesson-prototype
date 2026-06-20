import SwiftUI
import HealthService

struct AddHealthDataView: View {
    @EnvironmentObject private var healthViewModel: HealthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDataType: HealthDataType = .weight
    @State private var numericValue: Double = 0
    @State private var textValue: String = ""
    @State private var dateValue: Date = Date()
    @State private var selectedMoodValue: MoodValue = .neutral
    @State private var selectedUnit: String = "kg"
    
    enum HealthDataType: String, CaseIterable {
        case weight = "Weight"
        case bloodPressure = "Blood Pressure"
        case heartRate = "Heart Rate"
        case bloodSugar = "Blood Sugar"
        case mood = "Mood"
        case sleep = "Sleep Hours"
        case water = "Water Intake"
        case steps = "Steps"
        
        var icon: String {
            switch self {
            case .weight: return "scalemass.fill"
            case .bloodPressure: return "heart.circle"
            case .heartRate: return "heart.fill"
            case .bloodSugar: return "drop.fill"
            case .mood: return "face.smiling.fill"
            case .sleep: return "bed.double.fill"
            case .water: return "drop.circle"
            case .steps: return "figure.walk"
            }
        }
        
        var units: [String] {
            switch self {
            case .weight: return ["kg", "lbs"]
            case .bloodPressure: return ["mmHg"]
            case .heartRate: return ["bpm"]
            case .bloodSugar: return ["mg/dL", "mmol/L"]
            case .mood: return []
            case .sleep: return ["hours"]
            case .water: return ["L", "ml", "cups", "oz"]
            case .steps: return ["steps"]
            }
        }
        
        var isNumeric: Bool {
            self != .mood
        }
        
        var defaultValue: Double {
            switch self {
            case .weight: return 70.0
            case .bloodPressure: return 120.0
            case .heartRate: return 70.0
            case .bloodSugar: return 100.0
            case .mood: return 0.0
            case .sleep: return 8.0
            case .water: return 2.0
            case .steps: return 10000.0
            }
        }
    }
    
    enum MoodValue: String, CaseIterable {
        case veryBad = "Very Bad"
        case bad = "Bad"
        case neutral = "Neutral"
        case good = "Good"
        case veryGood = "Very Good"
        
        var emoji: String {
            switch self {
            case .veryBad: return "😞"
            case .bad: return "😕"
            case .neutral: return "😐"
            case .good: return "😊"
            case .veryGood: return "😄"
            }
        }
        
        var numericValue: Double {
            switch self {
            case .veryBad: return 1.0
            case .bad: return 2.0
            case .neutral: return 3.0
            case .good: return 4.0
            case .veryGood: return 5.0
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                dataTypeSection
                valueInputSection
                dateSection
                notesSection
            }
            .navigationTitle("Add Health Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveHealthData()
                    }
                    .disabled(!isValidInput)
                }
            }
        }
        .onAppear {
            setupDefaultValues()
        }
    }
    
    private var dataTypeSection: some View {
        Section("Data Type") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HealthDataType.allCases, id: \.self) { dataType in
                        DataTypeChip(
                            dataType: dataType,
                            isSelected: selectedDataType == dataType
                        ) {
                            selectedDataType = dataType
                            setupDefaultValues()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var valueInputSection: some View {
        Section("Value") {
            if selectedDataType.isNumeric {
                if selectedDataType == .bloodPressure {
                    bloodPressureInput
                } else {
                    numericInput
                }
            } else {
                moodInput
            }
        }
    }
    
    private var numericInput: some View {
        HStack {
            Image(systemName: selectedDataType.icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            TextField("Enter value", value: $numericValue, format: .number)
                .keyboardType(.decimalPad)
            
            if !selectedDataType.units.isEmpty {
                Picker("Unit", selection: $selectedUnit) {
                    ForEach(selectedDataType.units, id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    private var bloodPressureInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: selectedDataType.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                Text("Blood Pressure")
                    .font(.subheadline)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Systolic")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("120", value: $numericValue, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Text("/")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading) {
                    Text("Diastolic")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("80", value: Binding(
                        get: { numericValue * 0.67 }, // Rough diastolic approximation
                        set: { _ in }
                    ), format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Text("mmHg")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var moodInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: selectedDataType.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                Text("How are you feeling?")
                    .font(.subheadline)
            }
            
            HStack(spacing: 16) {
                ForEach(MoodValue.allCases, id: \.self) { mood in
                    Button {
                        selectedMoodValue = mood
                    } label: {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.title)
                            
                            Text(mood.rawValue)
                                .font(.caption2)
                                .foregroundColor(selectedMoodValue == mood ? .accentColor : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedMoodValue == mood ? 
                            Color.accentColor.opacity(0.1) : 
                            Color.clear
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var dateSection: some View {
        Section("Date & Time") {
            DatePicker("When", selection: $dateValue, displayedComponents: [.date, .hourAndMinute])
        }
    }
    
    private var notesSection: some View {
        Section("Notes (Optional)") {
            TextField("Add any notes", text: $textValue, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private var isValidInput: Bool {
        if selectedDataType.isNumeric {
            return numericValue > 0
        } else {
            return true // Mood is always valid
        }
    }
    
    private func setupDefaultValues() {
        numericValue = selectedDataType.defaultValue
        if !selectedDataType.units.isEmpty {
            selectedUnit = selectedDataType.units.first ?? ""
        }
    }
    
    private func saveHealthData() {
        let observationType: HealthObservation.ObservationType
        let value: HealthObservation.ObservationValue
        
        switch selectedDataType {
        case .weight:
            observationType = .weight
            value = .numeric(numericValue, selectedUnit)
            
        case .bloodPressure:
            observationType = .bloodPressure
            let diastolic = numericValue * 0.67
            value = .range(numericValue, diastolic, selectedUnit)
            
        case .heartRate:
            observationType = .heartRate
            value = .numeric(numericValue, selectedUnit)
            
        case .bloodSugar:
            observationType = .bloodGlucose
            value = .numeric(numericValue, selectedUnit)
            
        case .mood:
            observationType = .mood
            value = .text(selectedMoodValue.rawValue)
            
        case .sleep:
            observationType = .sleep
            value = .numeric(numericValue, selectedUnit)
            
        case .water:
            observationType = .hydration
            value = .numeric(numericValue, selectedUnit)
            
        case .steps:
            observationType = .steps
            value = .numeric(numericValue, selectedUnit)
        }
        
        let observation = HealthObservation(
            userId: healthViewModel.profile?.userId ?? "unknown",
            type: observationType,
            value: value,
            date: dateValue,
            source: .manual,
            metadata: textValue.isEmpty ? [:] : ["notes": textValue]
        )
        
        Task {
            await healthViewModel.saveObservation(observation)
            
            // For weight, also save to HealthKit
            if selectedDataType == .weight {
                await healthViewModel.saveWeight(numericValue)
            }
            
            dismiss()
        }
    }
}

struct DataTypeChip: View {
    let dataType: AddHealthDataView.HealthDataType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: dataType.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                Text(dataType.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80, height: 70)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    AddHealthDataView()
}