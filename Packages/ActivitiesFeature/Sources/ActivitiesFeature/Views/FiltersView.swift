import SwiftUI
import ActivitiesService

struct FiltersView: View {
    let filters: ActivityFilters
    let onApply: (ActivityFilters) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategories: Set<ActivityCategory>
    @State private var selectedSkillLevels: Set<SkillLevel>
    @State private var priceRange: ClosedRange<Double>
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var locationRadius: Double
    @State private var enableDateFilter = false
    @State private var enablePriceFilter = false
    @State private var enableLocationFilter = false
    
    init(filters: ActivityFilters, onApply: @escaping (ActivityFilters) -> Void) {
        self.filters = filters
        self.onApply = onApply
        
        _selectedCategories = State(initialValue: Set(filters.categories ?? []))
        _selectedSkillLevels = State(initialValue: Set(filters.skillLevels ?? []))
        _priceRange = State(initialValue: 
            (filters.priceRange != nil ? (filters.priceRange!.min...filters.priceRange!.max) : (0...1000))
        )
        _startDate = State(initialValue: filters.dateRange?.from ?? Date())
        _endDate = State(initialValue: filters.dateRange?.to ?? Date().addingTimeInterval(86400 * 7))
        _locationRadius = State(initialValue: filters.location?.radiusKm ?? 10)
        _enableDateFilter = State(initialValue: filters.dateRange != nil)
        _enablePriceFilter = State(initialValue: filters.priceRange != nil)
        _enableLocationFilter = State(initialValue: filters.location != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                categoriesSection
                skillLevelsSection
                priceSection
                dateSection
                locationSection
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                    }
                }
            }
        }
    }
    
    private var categoriesSection: some View {
        Section("Activity Categories") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(ActivityCategory.allCases, id: \.self) { category in
                    CategoryFilterButton(
                        category: category,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }
        }
    }
    
    private var skillLevelsSection: some View {
        Section("Skill Levels") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    SkillLevelFilterButton(
                        level: level,
                        isSelected: selectedSkillLevels.contains(level)
                    ) {
                        if selectedSkillLevels.contains(level) {
                            selectedSkillLevels.remove(level)
                        } else {
                            selectedSkillLevels.insert(level)
                        }
                    }
                }
            }
        }
    }
    
    private var priceSection: some View {
        Section("Price Range") {
            Toggle("Enable Price Filter", isOn: $enablePriceFilter)
            
            if enablePriceFilter {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Price: \(Int(priceRange.lowerBound)) - \(Int(priceRange.upperBound)) MAD")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // Custom range slider would be better, but using steppers for now
                    HStack {
                        Text("Min")
                        Stepper("", value: Binding(
                            get: { priceRange.lowerBound },
                            set: { newValue in
                                let maxValue = max(newValue, priceRange.upperBound)
                                priceRange = newValue...maxValue
                            }
                        ), in: 0...2000, step: 50)
                    }
                    
                    HStack {
                        Text("Max")
                        Stepper("", value: Binding(
                            get: { priceRange.upperBound },
                            set: { newValue in
                                let minValue = min(priceRange.lowerBound, newValue)
                                priceRange = minValue...newValue
                            }
                        ), in: 0...2000, step: 50)
                    }
                }
            }
        }
    }
    
    private var dateSection: some View {
        Section("Date Range") {
            Toggle("Enable Date Filter", isOn: $enableDateFilter)
            
            if enableDateFilter {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
            }
        }
    }
    
    private var locationSection: some View {
        Section("Location") {
            Toggle("Enable Location Filter", isOn: $enableLocationFilter)
            
            if enableLocationFilter {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Radius: \(Int(locationRadius)) km")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Slider(value: $locationRadius, in: 1...50, step: 1)
                    
                    Text("Filter activities within \(Int(locationRadius)) km of your location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func resetFilters() {
        selectedCategories.removeAll()
        selectedSkillLevels.removeAll()
        priceRange = 0...1000
        startDate = Date()
        endDate = Date().addingTimeInterval(86400 * 7)
        locationRadius = 10
        enableDateFilter = false
        enablePriceFilter = false
        enableLocationFilter = false
    }
    
    private func applyFilters() {
        let newFilters = ActivityFilters(
            categories: selectedCategories.isEmpty ? nil : Array(selectedCategories),
            priceRange: enablePriceFilter ? PriceRange(min: priceRange.lowerBound, max: priceRange.upperBound) : nil,
            skillLevels: selectedSkillLevels.isEmpty ? nil : Array(selectedSkillLevels),
            dateRange: enableDateFilter ? DateRange(from: startDate, to: endDate) : nil,
            location: enableLocationFilter ? LocationFilter(
                centerLatitude: 33.5731, // TODO: Get user location
                centerLongitude: -7.5898,
                radiusKm: locationRadius
            ) : nil
        )
        
        onApply(newFilters)
        dismiss()
    }
}

struct CategoryFilterButton: View {
    let category: ActivityCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: categoryIcon(for: category))
                    .font(.title3)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.vertical, 8)
            .background(
                isSelected ? .blue : .gray.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    private func categoryIcon(for category: ActivityCategory) -> String {
        switch category {
        case .sport: return "sportscourt"
        case .fitness: return "dumbbell"
        case .workshop: return "hammer"
        case .culture: return "paintbrush"
        case .food: return "fork.knife"
        case .game: return "tv"
        case .education: return "book"
        case .outdoor: return "leaf"
        case .other: return "star"
        }
    }
}

struct SkillLevelFilterButton: View {
    let level: SkillLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(level.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(1...4, id: \.self) { index in
                        Circle()
                            .fill(index <= level.numericValue ? .orange : .gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ? .blue.opacity(0.1) : .clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .blue : .gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension SkillLevel {
    var numericValue: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .any: return 4
        }
    }
}

#Preview {
    FiltersView(filters: ActivityFilters()) { _ in }
}