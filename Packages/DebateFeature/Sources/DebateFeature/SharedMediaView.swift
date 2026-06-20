import SwiftUI
import DebateService

struct SharedMediaView: View {
    @StateObject private var viewModel: SharedMediaViewModel
    @State private var showUploadSheet = false
    @State private var selectedMedia: SharedMedia?
    @Environment(\.dismiss) private var dismiss
    
    init(debateId: String, isDebater: Bool, service: DebateServicing) {
        _viewModel = StateObject(wrappedValue: SharedMediaViewModel(
            debateId: debateId,
            isDebater: isDebater,
            service: service
        ))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sharedMedia.isEmpty {
                    EmptyMediaView(canUpload: viewModel.isDebater) {
                        showUploadSheet = true
                    }
                } else {
                    MediaGridView(
                        media: viewModel.sharedMedia,
                        onMediaSelected: { media in
                            selectedMedia = media
                        }
                    )
                }
            }
            .navigationTitle("Shared Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                if viewModel.isDebater {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showUploadSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                MediaUploadView { mediaInput in
                    await viewModel.uploadMedia(mediaInput)
                    showUploadSheet = false
                }
            }
            .sheet(item: $selectedMedia) { media in
                MediaDetailView(media: media)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .task {
            await viewModel.loadSharedMedia()
        }
    }
}

struct MediaGridView: View {
    let media: [SharedMedia]
    let onMediaSelected: (SharedMedia) -> Void
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(media) { item in
                    MediaThumbnailCard(media: item)
                        .onTapGesture {
                            onMediaSelected(item)
                        }
                }
            }
            .padding()
        }
    }
}

struct MediaThumbnailCard: View {
    let media: SharedMedia
    
    var iconName: String {
        switch media.type {
        case .document: return "doc.text.fill"
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .link: return "link"
        case .screenShare: return "rectangle.on.rectangle"
        }
    }
    
    var iconColor: Color {
        switch media.type {
        case .document: return .blue
        case .image: return .green
        case .video: return .purple
        case .link: return .orange
        case .screenShare: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Thumbnail or icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.1))
                    .aspectRatio(1, contentMode: .fit)
                
                if let thumbnailUrl = media.thumbnailUrl {
                    // AsyncImage for thumbnail
                    AsyncImage(url: URL(string: thumbnailUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: iconName)
                        .font(.largeTitle)
                        .foregroundColor(iconColor)
                }
            }
            
            // Media info
            VStack(alignment: .leading, spacing: 4) {
                Text(media.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text(media.uploaderName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(media.uploadedAt.formatted(.relative(presentation: .abbreviated)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct EmptyMediaView: View {
    let canUpload: Bool
    let onUpload: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Shared Media")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(canUpload ? "Share documents, images, or links to support your arguments" : "No media has been shared yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if canUpload {
                Button(action: onUpload) {
                    Label("Share Media", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct MediaUploadView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var mediaType: SharedMediaType = .document
    @State private var url = ""
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @Environment(\.dismiss) private var dismiss
    
    let onUpload: (SharedMediaInput) async -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Media Information") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Media Type") {
                    Picker("Type", selection: $mediaType) {
                        Text("Document").tag(SharedMediaType.document)
                        Text("Image").tag(SharedMediaType.image)
                        Text("Link").tag(SharedMediaType.link)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if mediaType == .link {
                        TextField("URL", text: $url)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                    } else {
                        Button(action: {
                            if mediaType == .document {
                                showDocumentPicker = true
                            } else if mediaType == .image {
                                showImagePicker = true
                            }
                        }) {
                            Label("Select \(mediaType == .document ? "Document" : "Image")", 
                                  systemImage: mediaType == .document ? "doc.badge.plus" : "photo.badge.plus")
                        }
                    }
                }
            }
            .navigationTitle("Share Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        Task {
                            let input = SharedMediaInput(
                                title: title,
                                description: description,
                                type: mediaType,
                                url: mediaType == .link ? url : nil,
                                data: nil // Would be set from document/image picker
                            )
                            await onUpload(input)
                        }
                    }
                    .disabled(title.isEmpty || (mediaType == .link && url.isEmpty))
                }
            }
        }
    }
}

struct MediaDetailView: View {
    let media: SharedMedia
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Media preview
                    if let contentUrl = media.contentUrl {
                        MediaPreviewView(url: contentUrl, type: media.type)
                            .frame(maxHeight: 400)
                    }
                    
                    // Media info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(media.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if !media.description.isEmpty {
                            Text(media.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        HStack {
                            Label(media.uploaderName, systemImage: "person.circle")
                            Spacer()
                            Text(media.uploadedAt.formatted())
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle("Media Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MediaPreviewView: View {
    let url: String
    let type: SharedMediaType
    
    var body: some View {
        switch type {
        case .image:
            AsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
        case .document, .link:
            VStack {
                Image(systemName: type == .document ? "doc.text" : "link")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Tap to open")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let url = URL(string: url) {
                    Link("Open", destination: url)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6))
            
        default:
            EmptyView()
        }
    }
}

// MARK: - View Model

@MainActor
class SharedMediaViewModel: ObservableObject {
    @Published var sharedMedia: [SharedMedia] = []
    @Published var showError = false
    @Published var errorMessage = ""
    
    let debateId: String
    let isDebater: Bool
    private let service: DebateServicing
    
    init(debateId: String, isDebater: Bool, service: DebateServicing) {
        self.debateId = debateId
        self.isDebater = isDebater
        self.service = service
    }
    
    func loadSharedMedia() async {
        // In a real implementation, this would fetch from Firestore
        // For now, using mock data
        sharedMedia = [
            SharedMedia(
                id: "1",
                debateId: debateId,
                title: "Climate Data Report 2023",
                description: "Latest findings on global temperature trends",
                type: .document,
                contentUrl: "https://example.com/climate-report.pdf",
                thumbnailUrl: nil,
                uploaderId: "user1",
                uploaderName: "Dr. Sarah Green",
                uploadedAt: Date().addingTimeInterval(-3600)
            ),
            SharedMedia(
                id: "2",
                debateId: debateId,
                title: "Historical Temperature Chart",
                description: "Temperature anomalies from 1880-2023",
                type: .image,
                contentUrl: "https://example.com/temp-chart.png",
                thumbnailUrl: "https://example.com/temp-chart-thumb.png",
                uploaderId: "user2",
                uploaderName: "Prof. John Smith",
                uploadedAt: Date().addingTimeInterval(-1800)
            )
        ]
    }
    
    func uploadMedia(_ input: SharedMediaInput) async {
        // In a real implementation, this would upload to Firebase Storage
        // and create a Firestore document
        let newMedia = SharedMedia(
            id: UUID().uuidString,
            debateId: debateId,
            title: input.title,
            description: input.description,
            type: input.type,
            contentUrl: input.url ?? "https://example.com/uploaded-file",
            thumbnailUrl: nil,
            uploaderId: "current-user",
            uploaderName: "You",
            uploadedAt: Date()
        )
        sharedMedia.append(newMedia)
    }
}

// MARK: - Data Models

struct SharedMedia: Identifiable, Equatable {
    let id: String
    let debateId: String
    let title: String
    let description: String
    let type: SharedMediaType
    let contentUrl: String?
    let thumbnailUrl: String?
    let uploaderId: String
    let uploaderName: String
    let uploadedAt: Date
}

enum SharedMediaType: String, CaseIterable {
    case document
    case image
    case video
    case link
    case screenShare
}

struct SharedMediaInput {
    let title: String
    let description: String
    let type: SharedMediaType
    let url: String?
    let data: Data?
}