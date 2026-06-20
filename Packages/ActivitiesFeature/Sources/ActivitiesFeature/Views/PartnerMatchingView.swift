import SwiftUI
import ActivitiesService

struct PartnerMatchingView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    @State private var selectedTab: PartnerTab = .browse
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Partner Tab", selection: $selectedTab) {
                ForEach(PartnerTab.allCases, id: \.self) { tab in
                    Text(tab.displayName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            switch selectedTab {
            case .browse:
                BrowsePartnersView(viewModel: viewModel)
            case .myRequests:
                MyRequestsView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showingCreatePartnerRequest) {
            CreatePartnerRequestView(viewModel: viewModel)
        }
    }
}

enum PartnerTab: CaseIterable {
    case browse, myRequests
    
    var displayName: String {
        switch self {
        case .browse: return "Browse"
        case .myRequests: return "My Requests"
        }
    }
}

struct BrowsePartnersView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    @State private var selectedCategory: ActivityCategory?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header
                headerSection
                
                // Category Filter
                categoryFilterSection
                
                // Partner Requests List
                if viewModel.partnerRequests.isEmpty {
                    EmptyStateView(
                        title: "No Partner Requests",
                        message: "Be the first to create a partner request for this category",
                        systemImage: "person.2"
                    )
                    .frame(height: 300)
                } else {
                    partnerRequestsList
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadPartnerRequests()
        }
        .onAppear {
            Task {
                await viewModel.loadPartnerRequests()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                Text("Find Activity Partners")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                
                Button {
                    viewModel.showingCreatePartnerRequest = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            Text("Connect with people who share your interests")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var categoryFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryFilterChip(
                        title: "All",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }
                    
                    ForEach(ActivityCategory.allCases.prefix(8), id: \.self) { category in
                        CategoryFilterChip(
                            title: category.displayName,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var partnerRequestsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredRequests) { request in
                PartnerRequestCard(request: request) {
                    Task {
                        await viewModel.expressInterest(in: request.id)
                    }
                }
            }
        }
    }
    
    private var filteredRequests: [PartnerRequest] {
        if let selectedCategory = selectedCategory {
            return viewModel.partnerRequests.filter { $0.activityCategory == selectedCategory }
        }
        return viewModel.partnerRequests
    }
}

struct MyRequestsView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header
                headerSection
                
                // Create Request Button
                createRequestButton
                
                // My Requests List - TODO: Filter user's own requests
                Text("My Partner Requests")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // TODO: Show user's own requests with management options
                EmptyStateView(
                    title: "No Requests Created",
                    message: "Create your first partner request to find activity buddies",
                    systemImage: "person.crop.circle.badge.plus"
                )
                .frame(height: 200)
            }
            .padding()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.bullet.circle.fill")
                    .foregroundColor(.blue)
                Text("My Partner Requests")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text("Manage your partner requests and responses")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var createRequestButton: some View {
        Button {
            viewModel.showingCreatePartnerRequest = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Create Partner Request")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding()
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
    }
}

struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? .blue : .gray.opacity(0.2),
                    in: Capsule()
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct PartnerRequestCard: View {
    let request: PartnerRequest
    let onExpressInterest: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.activityCategory.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let skillLevel = request.skillLevel {
                        Text("\(skillLevel.capitalized) Level")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("👥 \(request.interestedUserIds.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text("interested")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Message
            Text(request.message)
                .font(.subheadline)
                .lineLimit(3)
                .padding()
                .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                if let neighborhood = request.neighborhood {
                    DetailRow(
                        icon: "location",
                        text: neighborhood
                    )
                }
                
                DetailRow(
                    icon: "calendar",
                    text: formatTimeWindow(request.desiredWindow)
                )
                
                DetailRow(
                    icon: "repeat",
                    text: request.frequency.displayName
                )
                
                if let preferredDays = request.preferredDays, !preferredDays.isEmpty {
                    DetailRow(
                        icon: "clock",
                        text: preferredDays.joined(separator: ", ")
                    )
                }
            }
            
            // Action Button
            Button(action: onExpressInterest) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("Express Interest")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatTimeWindow(_ window: DateWindow) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: window.from)) - \(formatter.string(from: window.to))"
    }
}

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

struct CreatePartnerRequestView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: ActivityCategory = .sport
    @State private var skillLevel: SkillLevel?
    @State private var message = ""
    @State private var neighborhood = ""
    @State private var desiredStartDate = Date()
    @State private var desiredEndDate = Date().addingTimeInterval(86400 * 7) // 1 week later
    @State private var selectedDays: Set<Weekday> = []
    @State private var frequency: Frequency?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Activity Details") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ActivityCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    
                    Picker("Skill Level", selection: $skillLevel) {
                        Text("Any Level").tag(Optional<SkillLevel>(nil))
                        ForEach(SkillLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(Optional(level))
                        }
                    }
                }
                
                Section("Message") {
                    TextEditor(text: $message)
                        .frame(minHeight: 80)
                }
                
                Section("Location (Optional)") {
                    TextField("Neighborhood", text: $neighborhood)
                }
                
                Section("Desired Time Window") {
                    DatePicker("Start Date", selection: $desiredStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $desiredEndDate, displayedComponents: .date)
                }
                
                Section("Preferred Days (Optional)") {
                    MultipleWeekdayPicker(selectedDays: $selectedDays)
                }
                
                Section("Frequency (Optional)") {
                    Picker("How Often", selection: $frequency) {
                        Text("Not Specified").tag(Frequency?.none)
                        ForEach([Frequency.oneOff, Frequency.recurring], id: \.self) { freq in
                            Text(freq.displayName).tag(Frequency?.some(freq))
                        }
                    }
                }
            }
            .navigationTitle("Create Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            let request = PartnerRequestDraft(
                                activityCategory: selectedCategory,
                                cityId: "casablanca", // TODO: Get from user location
                                neighborhood: neighborhood.isEmpty ? nil : neighborhood,
                                skillLevel: skillLevel?.rawValue,
                                message: message,
                                desiredWindow: DateWindow(from: desiredStartDate, to: desiredEndDate),
                                preferredDays: selectedDays.isEmpty ? nil : Array(selectedDays.map { $0.rawValue }),
                                frequency: frequency ?? .oneOff
                            )
                            
                            await viewModel.createPartnerRequest(request)
                        }
                    }
                    .disabled(message.isEmpty)
                }
            }
        }
    }
}

struct MultipleWeekdayPicker: View {
    @Binding var selectedDays: Set<Weekday>
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { day in
                Button {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                } label: {
                    Text(day.shortName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            selectedDays.contains(day) ? .blue : .gray.opacity(0.2),
                            in: Capsule()
                        )
                        .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Extensions
extension Frequency {
    var displayName: String {
        switch self {
        case .oneOff: return "One Time"
        case .recurring: return "Recurring"
        }
    }
}

extension Weekday {
    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
    
    static var allCases: [Weekday] {
        return [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
}

#Preview {
    NavigationView {
        PartnerMatchingView(viewModel: ActivitiesViewModel())
    }
}