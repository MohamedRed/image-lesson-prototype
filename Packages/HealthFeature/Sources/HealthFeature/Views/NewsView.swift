import SwiftUI
import HealthService
import UIKit

struct NewsView: View {
    @StateObject private var newsViewModel = NewsViewModel(healthService: HealthService.shared)
    @State private var selectedArticle: HealthNewsItem?
    @State private var selectedCategory: String = "All"
    
    private var categories: [String] {
        let allCategories = Array(newsViewModel.categorizedArticles.keys)
        return ["All"] + allCategories.sorted()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if !newsViewModel.featuredArticles.isEmpty {
                        featuredArticlesSection
                    }
                    
                    categoryFilters
                    
                    if filteredArticles.isEmpty && !newsViewModel.isLoading {
                        emptyStateView
                    } else {
                        articlesGrid
                    }
                }
                .padding()
            }
            .navigationTitle("Health News")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await newsViewModel.refreshNews()
            }
            .sheet(item: $selectedArticle) { article in
                ArticleDetailView(article: article)
            }
        }
        .task {
            await newsViewModel.loadNews()
        }
        .overlay {
            if newsViewModel.isLoading && newsViewModel.articles.isEmpty {
                ProgressView("Loading news...")
            }
        }
    }
    
    private var featuredArticlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(newsViewModel.featuredArticles, id: \.id) { article in
                        FeaturedArticleCard(article: article) {
                            selectedArticle = article
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryButton(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var filteredArticles: [HealthNewsItem] {
        if selectedCategory == "All" {
            return newsViewModel.articles
        }
        return newsViewModel.categorizedArticles[selectedCategory] ?? []
    }
    
    private var articlesGrid: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredArticles, id: \.id) { article in
                ArticleCard(article: article) {
                    selectedArticle = article
                }
            }
            
            if newsViewModel.hasMore {
                Button("Load More Articles") {
                    Task {
                        await newsViewModel.loadMoreNews()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .disabled(newsViewModel.isLoading)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Articles Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Check back later for the latest health news and insights")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }
}

struct FeaturedArticleCard: View {
    let article: HealthNewsItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: article.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.white)
                                .font(.title)
                        }
                }
                .frame(width: 280, height: 180)
                .clipped()
                
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(article.source.name)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(article.publishedAt.timeAgoDisplay)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ArticleCard: View {
    let article: HealthNewsItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: article.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.white)
                        }
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(article.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(article.source.name)
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Text(article.publishedAt.timeAgoDisplay)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if !article.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(article.tags.prefix(2), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ArticleDetailView: View {
    let article: HealthNewsItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    articleHeader
                    articleContent
                    tagsSection
                    sourceSection
                }
                .padding()
            }
            .navigationTitle("Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        shareArticle()
                    }
                }
            }
        }
    }
    
    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageUrl = article.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .overlay {
                            ProgressView()
                        }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .cornerRadius(12)
                .clipped()
            }
            
            Text(article.title)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                Text(article.source.name)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                
                Spacer()
                
                Text(article.publishedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var articleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
            
            Text(article.summary)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let content = article.content, !content.isEmpty {
                Text("Full Article")
                    .font(.headline)
                    .padding(.top)
                
                Text(content)
                    .font(.body)
            } else {
                Button("Read Full Article") {
                    if let url = URL(string: article.readMoreUrl) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
    }
    
    private var tagsSection: some View {
        Group {
            if !article.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(article.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(article.source.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Author not available in model; omitted for now
                
                Button("View Original") {
                    if let url = URL(string: article.readMoreUrl) {
                        openURL(url)
                    }
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func shareArticle() {
        let activityController = UIActivityViewController(
            activityItems: [article.title, article.readMoreUrl],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width - currentX, height: .infinity))
            
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
        
        return CGSize(width: width, height: currentY + maxHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width - (currentX - bounds.minX), height: .infinity))
            
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        NewsView()
    }
}