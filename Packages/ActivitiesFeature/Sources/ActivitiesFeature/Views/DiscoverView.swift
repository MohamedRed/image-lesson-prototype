import SwiftUI
import ActivitiesService

struct DiscoverView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    @State private var showingFilters = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Search Section
                searchSection
                
                // Recommendations Section
                if !viewModel.recommendations.isEmpty {
                    recommendationsSection
                }
                
                // Activities Section
                activitiesSection
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadInitialData()
        }
        .searchable(text: $viewModel.searchText, prompt: "Search activities...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Filters") {
                    showingFilters = true
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            FiltersView(
                filters: viewModel.selectedFilters,
                onApply: { filters in
                    viewModel.updateFilters(filters)
                    showingFilters = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showingActivityDetail) {
            if let activity = viewModel.selectedActivity {
                ActivityDetailView(
                    activity: activity,
                    viewModel: viewModel
                )
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "compass")
                    .foregroundColor(.blue)
                Text("Discover Activities")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text("Find exciting activities near you")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.yellow)
                Text("Recommended for You")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.recommendations) { activity in
                        RecommendationCard(activity: activity) {
                            viewModel.selectActivity(activity)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Activities")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if viewModel.activities.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Activities Found",
                    message: viewModel.searchText.isEmpty 
                        ? "Check back later for new activities"
                        : "Try adjusting your search or filters",
                    systemImage: "magnifyingglass"
                )
                .frame(height: 200)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.activities) { activity in
                        ActivityCard(activity: activity) {
                            viewModel.selectActivity(activity)
                        }
                    }
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let activity: Activity
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Activity Image
                AsyncImage(url: activity.images.first.flatMap(URL.init)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                }
                .frame(width: 200, height: 120)
                .clipped()
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(activity.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(activity.pricePerUnit)) MAD / \(activity.unit.displayName)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .frame(width: 200, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ActivityCard: View {
    let activity: Activity
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Activity Image
                AsyncImage(url: activity.images.first.flatMap(URL.init)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                }
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(activity.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Label(activity.category.displayName, systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        // Rating omitted in this build of the model
                        Text("\(Int(activity.pricePerUnit)) MAD / \(activity.unit.displayName)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    NavigationView {
        DiscoverView(viewModel: ActivitiesViewModel())
    }
}