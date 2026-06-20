import SwiftUI
import HomeServicesService

struct ProSignupView: View {
    @ObservedObject var viewModel: HomeServicesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var businessName = ""
    @State private var selectedSkills: Set<String> = []
    @State private var experience = 1
    @State private var address = ""
    @State private var city = ""
    @State private var phoneNumber = ""
    @State private var emergencyAvailable = false
    @State private var isSubmitting = false
    @State private var currentStep = 1
    
    private let totalSteps = 3
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Header
                VStack(spacing: 16) {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        
                        Spacer()
                        
                        Text("Step \(currentStep) of \(totalSteps)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    ProgressView(value: Double(currentStep), total: Double(totalSteps))
                        .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case 1:
                            businessInfoStep
                        case 2:
                            skillsStep
                        case 3:
                            contactStep
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
                
                // Bottom Navigation
                HStack {
                    if currentStep > 1 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Button(currentStep == totalSteps ? "Create Profile" : "Continue") {
                        if currentStep == totalSteps {
                            submitProfile()
                        } else {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSubmitting || !isCurrentStepValid)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Professional Signup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
    
    private var businessInfoStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tell us about your business")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Help customers find and trust your services")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Name")
                        .font(.headline)
                    
                    TextField("e.g., Ahmed's Plumbing Services", text: $businessName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Years of Experience")
                        .font(.headline)
                    
                    HStack {
                        Stepper("\(experience) year\(experience == 1 ? "" : "s")", value: $experience, in: 1...50)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.headline)
                    
                    TextField("+212 6XX XXX XXX", text: $phoneNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad)
                }
            }
        }
    }
    
    private var skillsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What services do you offer?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Select all that apply")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.categories) { category in
                    SkillCard(
                        category: category,
                        isSelected: selectedSkills.contains(category.id!)
                    ) {
                        if selectedSkills.contains(category.id!) {
                            selectedSkills.remove(category.id!)
                        } else {
                            selectedSkills.insert(category.id!)
                        }
                    }
                }
            }
        }
    }
    
    private var contactStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Where do you work?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This helps us match you with nearby customers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("City")
                        .font(.headline)
                    
                    TextField("e.g., Casablanca", text: $city)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Address")
                        .font(.headline)
                    
                    TextField("Your business address", text: $address)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Available for emergency calls", isOn: $emergencyAvailable)
                        .font(.headline)
                    
                    Text("Emergency jobs typically pay 30-50% more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 1:
            return !businessName.isEmpty && !phoneNumber.isEmpty
        case 2:
            return !selectedSkills.isEmpty
        case 3:
            return !city.isEmpty && !address.isEmpty
        default:
            return false
        }
    }
    
    private func submitProfile() {
        isSubmitting = true
        
        let profileDict: [String: Any] = [
            "userId": "current-user-id",
            "name": businessName,
            "skills": Array(selectedSkills),
            "serviceArea": [
                "city": city,
                "address": address
            ],
            "verificationTier": "unverified",
            "rating": 0.0,
            "jobsCount": 0,
            "badges": [],
            "availability": [
                "daysOfWeek": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                "workingHours": [
                    "monday": ["start": "08:00", "end": "18:00"],
                    "tuesday": ["start": "08:00", "end": "18:00"],
                    "wednesday": ["start": "08:00", "end": "18:00"],
                    "thursday": ["start": "08:00", "end": "18:00"],
                    "friday": ["start": "08:00", "end": "18:00"],
                    "saturday": ["start": "09:00", "end": "15:00"]
                ],
                "emergencyAvailable": emergencyAvailable
            ],
            "languages": [],
            "phoneNumber": phoneNumber,
            "experienceYears": experience,
            "emergencyAvailable": emergencyAvailable,
            "businessName": businessName,
            "experience": experience,
            "portfolio": []
        ]
        
        let profile: ProProfile
        do {
            let data = try JSONSerialization.data(withJSONObject: profileDict)
            profile = try JSONDecoder().decode(ProProfile.self, from: data)
        } catch {
            isSubmitting = false
            return
        }
        
        Task {
            await viewModel.updateProProfile(profile)
            
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }
}

struct SkillCard: View {
    let category: ServiceCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : .blue)
                }
                
                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(minWidth: 120)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(minWidth: 120)
            .background(Color.clear)
            .foregroundColor(.blue)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ProSignupView(viewModel: HomeServicesViewModel(service: MockHomeServicesService()))
}