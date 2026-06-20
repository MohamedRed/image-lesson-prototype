import SwiftUI
import HomeServicesService

/// Main view for Home Services feature
public struct HomeServicesMainView: View {
    @StateObject private var viewModel: HomeServicesViewModel
    @State private var selectedTab = 0
    @State private var showingPostRFQ = false
    @State private var showingProSignup = false
    
    public init(service: HomeServicesServicing? = nil) {
        let mockService = MockHomeServicesService()
        _viewModel = StateObject(wrappedValue: HomeServicesViewModel(service: service ?? mockService))
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Mode", selection: $selectedTab) {
                    Text("Customer").tag(0)
                    Text("Professional").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                if selectedTab == 0 {
                    CustomerHomeView(viewModel: viewModel)
                } else {
                    ProHomeView(viewModel: viewModel)
                }
            }
            .navigationTitle("Home Services")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if selectedTab == 0 {
                            showingPostRFQ = true
                        } else {
                            showingProSignup = true
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: selectedTab == 0 ? "plus.circle.fill" : "person.badge.plus")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showingPostRFQ) {
                PostRFQWizardView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingProSignup) {
                ProSignupView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Customer Home View
struct CustomerHomeView: View {
    @ObservedObject var viewModel: HomeServicesViewModel
    @State private var selectedCategory: ServiceCategory?
    @State private var isScrolling = false
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollTime = Date()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Coordinate space marker for scroll detection
                Color.clear.frame(height: 0)
                    .coordinateSpace(name: "scroll")
                // Show loading state
                if viewModel.isLoading && viewModel.categories.isEmpty {
                    ProgressView("Loading services...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                
                // Show error if any
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Categories Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("What do you need help with?")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if viewModel.categories.isEmpty && !viewModel.isLoading {
                        Text("No categories available")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.categories) { category in
                                    CategoryCard(category: category) {
                                        if !isScrolling { selectedCategory = category }
                                    }
                                    .buttonStyle(ScrollSafeButtonStyle(isScrolling: $isScrolling))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Active RFQs
                if !viewModel.myRFQs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Requests")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.myRFQs) { rfq in
                            NavigationLink(destination: RFQDetailView(rfq: rfq, viewModel: viewModel)) {
                                RFQCard(rfq: rfq)
                            }
                            .buttonStyle(ScrollSafeButtonStyle(isScrolling: $isScrolling))
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Recent Contracts
                if !viewModel.myContracts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Jobs")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.myContracts) { contract in
                            NavigationLink(destination: ContractDetailView(contract: contract, viewModel: viewModel)) {
                                ContractCard(contract: contract)
                            }
                            .buttonStyle(ScrollSafeButtonStyle(isScrolling: $isScrolling))
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    isScrolling = true
                    lastScrollTime = Date()
                }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                        isScrolling = false
                    }
                }
        )
        .task {
            await viewModel.loadCustomerData()
        }
        .sheet(item: $selectedCategory) { category in
            PostRFQWizardView(viewModel: viewModel, preselectedCategory: category)
        }
    }
}

// MARK: - Pro Home View
struct ProHomeView: View {
    @ObservedObject var viewModel: HomeServicesViewModel
    @State private var selectedRFQ: RFQ?
    @State private var isScrolling = false
    @State private var lastScrollTime = Date()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Coordinate space marker for scroll detection
                Color.clear.frame(height: 0)
                    .coordinateSpace(name: "scroll")
                // Stats Dashboard
                ProStatsCard(viewModel: viewModel)
                    .padding(.horizontal)
                
                // Available Jobs
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Jobs")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if viewModel.availableRFQs.isEmpty {
                        EmptyStateView(
                            icon: "briefcase",
                            title: "No jobs available",
                            subtitle: "Check back later for new opportunities"
                        )
                        .padding()
                    } else {
                        ForEach(viewModel.availableRFQs) { rfq in
                            Button(action: { 
                                if !isScrolling {
                                    selectedRFQ = rfq
                                }
                            }) {
                                RFQCard(rfq: rfq, showBidButton: true)
                            }
                            .buttonStyle(ScrollSafeButtonStyle(isScrolling: $isScrolling))
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Active Contracts
                if !viewModel.proContracts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Active Jobs")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.proContracts) { contract in
                            NavigationLink(destination: ContractDetailView(contract: contract, viewModel: viewModel, isPro: true)) {
                                ContractCard(contract: contract)
                            }
                            .buttonStyle(ScrollSafeButtonStyle(isScrolling: $isScrolling))
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    isScrolling = true
                    lastScrollTime = Date()
                }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                        isScrolling = false
                    }
                }
        )
        .task {
            await viewModel.loadProData()
        }
        .sheet(item: $selectedRFQ) { rfq in
            BidSubmissionView(rfq: rfq, viewModel: viewModel)
        }
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: ServiceCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                Text(category.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .frame(width: 70)
            }
        }
    }
}

// MARK: - RFQ Card
struct RFQCard: View {
    let rfq: RFQ
    var showBidButton: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rfq.scope.title)
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text("\(rfq.location.city)")
                            .font(.caption)
                        
                        Spacer()
                        
                        if let budget = rfq.budgetRange {
                            Text("\(Int(budget.min))-\(Int(budget.max)) MAD")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: rfq.status)
            }
            
            Text(rfq.scope.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if showBidButton {
                Button("Submit Bid") {
                    // Action handled by parent
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Contract Card
struct ContractCard: View {
    let contract: Contract
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(contract.agreedScope.title)
                        .font(.headline)
                    
                    Text("\(Int(contract.priceMAD)) MAD")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                StatusBadge(contractStatus: contract.status)
            }
            
            if let startDate = contract.startAt {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(startDate, style: .date)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Progress indicator for milestones
            if !contract.milestones.isEmpty {
                ProgressView(value: completedMilestonesRatio(contract))
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func completedMilestonesRatio(_ contract: Contract) -> Double {
        let completed = contract.milestones.filter { $0.status == .completed || $0.status == .approved }.count
        return Double(completed) / Double(contract.milestones.count)
    }
}

// MARK: - Pro Stats Card
struct ProStatsCard: View {
    @ObservedObject var viewModel: HomeServicesViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Performance")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatItem(title: "Rating", value: String(format: "%.1f", viewModel.proProfile?.rating ?? 0.0), icon: "star.fill")
                StatItem(title: "Jobs", value: "\(viewModel.proProfile?.jobsCount ?? 0)", icon: "briefcase.fill")
                StatItem(title: "Active", value: "\(viewModel.proContracts.count)", icon: "hammer.fill")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    var status: RFQ.RFQStatus? = nil
    var contractStatus: Contract.ContractStatus? = nil
    
    var displayText: String {
        if let status = status {
            return status.rawValue.capitalized
        } else if let contractStatus = contractStatus {
            return contractStatus.rawValue.capitalized
        }
        return ""
    }
    
    var color: Color {
        if let status = status {
            switch status {
            case .open: return .green
            case .draft: return .gray
            case .awarded: return .blue
            case .cancelled: return .red
            }
        } else if let contractStatus = contractStatus {
            switch contractStatus {
            case .pending: return .orange
            case .active: return .green
            case .completed: return .blue
            case .cancelled: return .red
            }
        }
        return .gray
    }
    
    var body: some View {
        Text(displayText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Scroll-Safe Button Style
struct ScrollSafeButtonStyle: ButtonStyle {
    @Binding var isScrolling: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !isScrolling ? 0.98 : 1.0)
            .opacity(configuration.isPressed && !isScrolling ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .allowsHitTesting(!isScrolling)
    }
}

// Scroll offset detection using GeometryReader and PreferenceKey

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    HomeServicesMainView()
}