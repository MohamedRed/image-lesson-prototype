import SwiftUI
import HealthService

struct ProfessionalsView: View {
    @StateObject private var professionalsViewModel = ProfessionalsViewModel(healthService: HealthService.shared)
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var selectedProfessional: HealthProfessional?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if !professionalsViewModel.upcomingAppointments.isEmpty {
                            upcomingAppointmentsSection
                        }
                        
                        if professionalsViewModel.professionals.isEmpty && !professionalsViewModel.isLoading {
                            emptyStateView
                        } else {
                            professionalsGrid
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Professionals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filters") {
                        showingFilters = true
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                ProfessionalsFiltersView()
                    .environmentObject(professionalsViewModel)
            }
            .sheet(item: $selectedProfessional) { professional in
                ProfessionalDetailView(professional: professional)
                    .environmentObject(professionalsViewModel)
            }
        }
        .task {
            await professionalsViewModel.searchProfessionals()
            await professionalsViewModel.loadAppointments()
        }
        .overlay {
            if professionalsViewModel.isLoading {
                ProgressView("Searching professionals...")
            }
        }
        .searchable(text: $searchText, prompt: "Search professionals...")
        .onSubmit(of: .search) {
            professionalsViewModel.searchFilters.specialty = searchText.isEmpty ? nil : searchText
            Task {
                await professionalsViewModel.searchProfessionals()
            }
        }
    }
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HealthProfessional.ProfessionalType.allCases, id: \.self) { type in
                        ProfessionalTypeChip(
                            type: type,
                            isSelected: professionalsViewModel.searchFilters.type == type
                        ) {
                            professionalsViewModel.searchFilters.type = 
                                professionalsViewModel.searchFilters.type == type ? nil : type
                            Task {
                                await professionalsViewModel.searchProfessionals()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var upcomingAppointmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Appointments")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink("View All") {
                    AppointmentsListView()
                        .environmentObject(professionalsViewModel)
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(professionalsViewModel.upcomingAppointments.prefix(3), id: \.id) { appointment in
                        AppointmentCard(appointment: appointment, isCompact: true)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var professionalsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(professionalsViewModel.professionals, id: \.id) { professional in
                ProfessionalCard(professional: professional) {
                    selectedProfessional = professional
                    Task {
                        await professionalsViewModel.getProfessionalDetails(professional.id)
                    }
                }
            }
            
            if professionalsViewModel.searchResults?.hasMore == true {
                Button("Load More") {
                    Task {
                        await professionalsViewModel.loadMoreProfessionals()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "stethoscope")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Professionals Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search criteria or location")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Clear Filters") {
                professionalsViewModel.searchFilters = ProfessionalsViewModel.SearchFilters()
                Task {
                    await professionalsViewModel.searchProfessionals()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 80)
    }
}

struct ProfessionalTypeChip: View {
    let type: HealthProfessional.ProfessionalType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct ProfessionalCard: View {
    let professional: HealthProfessional
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                AsyncImage(url: URL(string: professional.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray4))
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                VStack(spacing: 4) {
                    Text(professional.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(professional.specialties.first ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                        
                        Text("\(professional.rating ?? 0, specifier: "%.1f")")
                            .font(.caption2)
                            .fontWeight(.medium)
                        
                        Text("(\(professional.reviewsCount))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if professional.availability.nextAvailable != nil {
                        Text("Available")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AppointmentCard: View {
    let appointment: HealthAppointment
    let isCompact: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appointment.professionalName)
                        .font(isCompact ? .caption : .subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    if !isCompact {
                        Text(appointment.service)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                appointmentStatusBadge
            }
            
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(appointment.dateTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: appointment.type == .telehealth ? "video" : "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(appointment.type == .telehealth ? "Virtual" : "In-person")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(isCompact ? 8 : 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .frame(width: isCompact ? 180 : nil)
    }
    
    private var appointmentStatusBadge: some View {
        Text(appointment.status.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(3)
    }
    
    private var statusColor: Color {
        switch appointment.status {
        case .confirmed: return .green
        case .pending: return .orange
        case .cancelled: return .red
        case .completed: return .blue
        case .noShow: return .gray
        }
    }
}

struct ProfessionalsFiltersView: View {
    @EnvironmentObject private var professionalsViewModel: ProfessionalsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Professional Type") {
                    Picker("Type", selection: Binding(
                        get: { professionalsViewModel.searchFilters.type },
                        set: { professionalsViewModel.searchFilters.type = $0 }
                    )) {
                        Text("All Types").tag(Optional<HealthProfessional.ProfessionalType>.none)
                        ForEach(HealthProfessional.ProfessionalType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(Optional(type))
                        }
                    }
                }
                
                Section("Specialty") {
                    TextField("Specialty", text: Binding(
                        get: { professionalsViewModel.searchFilters.specialty ?? "" },
                        set: { professionalsViewModel.searchFilters.specialty = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section("Location") {
                    TextField("Location", text: Binding(
                        get: { professionalsViewModel.searchFilters.location ?? "" },
                        set: { professionalsViewModel.searchFilters.location = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section("Options") {
                    Toggle("Telehealth Only", isOn: $professionalsViewModel.searchFilters.telehealthOnly)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        professionalsViewModel.searchFilters = ProfessionalsViewModel.SearchFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        Task {
                            await professionalsViewModel.searchProfessionals()
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProfessionalDetailView: View {
    let professional: HealthProfessional
    @EnvironmentObject private var professionalsViewModel: ProfessionalsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingBooking = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    professionalHeader
                    aboutSection
                    servicesSection
                    reviewsPreview
                    availabilitySection
                }
                .padding()
            }
            .navigationTitle(professional.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Book") {
                        showingBooking = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(professional.availability.nextAvailable == nil)
                }
            }
            .sheet(isPresented: $showingBooking) {
                BookAppointmentView(professional: professional)
                    .environmentObject(professionalsViewModel)
            }
        }
    }
    
    private var professionalHeader: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: professional.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                            .font(.title)
                    }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(professional.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(professional.credentials.map { $0.type }.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(professional.specialties.first ?? "")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                
                HStack {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(professional.rating ?? 0) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    
                    Text("\(professional.rating ?? 0, specifier: "%.1f") (\(professional.reviewsCount) reviews)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
            
            Text(professional.bio)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Services")
                .font(.headline)
            
            ForEach(professional.services, id: \.name) { service in
                ServiceRow(service: service)
            }
        }
    }
    
    private var reviewsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reviews")
                .font(.headline)
            
            Text("Recent patient feedback and ratings will be displayed here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Availability")
                .font(.headline)
            
            if professional.availability.nextAvailable != nil {
                Text("Available for appointments")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("Currently unavailable")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
    }
}

struct ServiceRow: View {
    let service: HealthProfessional.ServiceOffering
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(service.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(service.price?.amount ?? 0, specifier: "%.0f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(Int(service.duration/60)) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct BookAppointmentView: View {
    let professional: HealthProfessional
    @EnvironmentObject private var professionalsViewModel: ProfessionalsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedService: HealthProfessional.ServiceOffering?
    @State private var selectedDate = Date()
    @State private var selectedType: HealthAppointment.AppointmentType = .inPerson
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Service") {
                    ForEach(professional.services, id: \.name) { service in
                        ServiceSelectionRow(
                            service: service,
                            isSelected: selectedService?.name == service.name
                        ) {
                            selectedService = service
                        }
                    }
                }
                
                Section("Appointment Details") {
                    DatePicker("Date & Time", selection: $selectedDate, in: Date()...)
                    
                    Picker("Type", selection: $selectedType) {
                        Text("In-Person").tag(HealthAppointment.AppointmentType.inPerson)
                        Text("Telehealth").tag(HealthAppointment.AppointmentType.telehealth)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Notes (Optional)") {
                    TextField("Add any notes or concerns", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Book Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Book") {
                        bookAppointment()
                    }
                    .disabled(selectedService == nil || professionalsViewModel.isBookingAppointment)
                }
            }
        }
    }
    
    private func bookAppointment() {
        guard let service = selectedService else { return }
        
        Task {
            let response = await professionalsViewModel.bookAppointment(
                professionalId: professional.id,
                serviceId: service.name,
                dateTime: selectedDate,
                type: selectedType,
                notes: notes.isEmpty ? nil : notes
            )
            
            if response != nil {
                dismiss()
            }
        }
    }
}

struct ServiceSelectionRow: View {
    let service: HealthProfessional.ServiceOffering
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(service.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("$\(service.price?.amount ?? 0, specifier: "%.0f") • \(Int(service.duration/60)) min")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AppointmentsListView: View {
    @EnvironmentObject private var professionalsViewModel: ProfessionalsViewModel
    
    var body: some View {
        List {
            if !professionalsViewModel.upcomingAppointments.isEmpty {
                Section("Upcoming") {
                    ForEach(professionalsViewModel.upcomingAppointments, id: \.id) { appointment in
                        AppointmentListRow(appointment: appointment)
                    }
                }
            }
            
            if !professionalsViewModel.pastAppointments.isEmpty {
                Section("Past") {
                    ForEach(professionalsViewModel.pastAppointments, id: \.id) { appointment in
                        AppointmentListRow(appointment: appointment)
                    }
                }
            }
        }
        .navigationTitle("Appointments")
    }
}

struct AppointmentListRow: View {
    let appointment: HealthAppointment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(appointment.professionalName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(appointment.status.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            Text(appointment.service)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(appointment.dateTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(appointment.type == .telehealth ? "Virtual" : "In-person")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statusColor: Color {
        switch appointment.status {
        case .confirmed: return .green
        case .pending: return .orange
        case .cancelled: return .red
        case .completed: return .blue
        case .noShow: return .gray
        }
    }
}

extension HealthProfessional.ProfessionalType {
    var icon: String {
        switch self {
        case .doctor: return "stethoscope"
        case .nurse: return "cross.fill"
        case .dietician: return "leaf"
        case .nutritionist: return "leaf.fill"
        case .personalTrainer: return "figure.run"
        case .physicalTherapist: return "figure.walk"
        case .mentalHealthCounselor: return "heart.text.square"
        case .healthCoach: return "person.fill.badge.plus"
        case .specialist: return "staroflife"
        }
    }
    
    var displayName: String {
        switch self {
        case .doctor: return "Doctor"
        case .nurse: return "Nurse"
        case .dietician: return "Dietician"
        case .nutritionist: return "Nutritionist"
        case .personalTrainer: return "Trainer"
        case .physicalTherapist: return "Phys. Therapist"
        case .mentalHealthCounselor: return "Counselor"
        case .healthCoach: return "Health Coach"
        case .specialist: return "Specialist"
        }
    }
    
    static var allCases: [HealthProfessional.ProfessionalType] {
        [.doctor, .nurse, .dietician, .nutritionist, .personalTrainer, .physicalTherapist, .mentalHealthCounselor, .healthCoach, .specialist]
    }
}

#Preview {
    NavigationStack {
        ProfessionalsView()
    }
}