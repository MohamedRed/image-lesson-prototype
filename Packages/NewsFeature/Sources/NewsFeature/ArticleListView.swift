import SwiftUI
import NewsService

struct ArticleListView: View {
    let articles: [NewsArticle]
    let eventTitle: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(articles) { article in
                ArticleRowView(article: article)
            }
            .navigationTitle("Source Articles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if articles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Articles")
                            .font(.headline)
                        Text("No source articles available for this event")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
        }
    }
}

struct ArticleRowView: View {
    let article: NewsArticle
    
    var body: some View {
        Link(destination: URL(string: article.url)!) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        HStack {
                            Text(article.sourceName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.accentColor)
                            
                            if let author = article.author {
                                Text("• \(author)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(formatDate(article.publishedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let summary = article.summary {
                            Text(summary)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                    
                    if let imageUrl = article.imageUrl {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.2))
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(6)
                    }
                }
                
                if let biasLabels = article.biasLabels, !biasLabels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(biasLabels, id: \.self) { label in
                                Text(label)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                HStack {
                    if let language = article.language {
                        Label(language.uppercased(), systemImage: "globe")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let country = article.country {
                        Label(country, systemImage: "location")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}