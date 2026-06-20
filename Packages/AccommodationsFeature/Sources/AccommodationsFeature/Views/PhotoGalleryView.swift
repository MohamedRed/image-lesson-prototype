import SwiftUI
import AccommodationsService

struct PhotoGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let photos: [Photo]
    @Binding var currentIndex: Int
    
    @State private var dragOffset: CGSize = .zero
    @State private var isZoomed = false
    @State private var zoomScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if !photos.isEmpty {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                            ZoomableImageView(
                                url: URL(string: photo.url),
                                caption: photo.caption
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                if abs(value.translation.height) > 100 {
                                    dismiss()
                                } else {
                                    dragOffset = .zero
                                }
                            }
                    )
                    .offset(y: dragOffset.height)
                    .animation(.interactiveSpring(), value: dragOffset)
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                photoGalleryHeader
            }
            .overlay(alignment: .bottom) {
                if let caption = photos[safe: currentIndex]?.caption {
                    photoCaptionView(caption)
                }
            }
        }
    }
    
    private var photoGalleryHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            Spacer()
            
            Text("\(currentIndex + 1) of \(photos.count)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            
            Spacer()
            
            Button {
                shareCurrentPhoto()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.black.opacity(0.3), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    private func photoCaptionView(_ caption: String) -> some View {
        Text(caption)
            .font(.subheadline)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
    }
    
    private func shareCurrentPhoto() {
        guard let photo = photos[safe: currentIndex],
              let url = URL(string: photo.url) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

struct ZoomableImageView: View {
    let url: URL?
    let caption: String?
    
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1
                                    if scale < 1 {
                                        withAnimation(.spring()) {
                                            scale = 1
                                            offset = .zero
                                        }
                                    }
                                },
                            
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1 {
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        offset = newOffset
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    PhotoGalleryView(
        photos: [
            Photo(id: "1", url: "https://example.com/photo1.jpg", caption: "Beautiful view"),
            Photo(id: "2", url: "https://example.com/photo2.jpg", caption: "Luxury room"),
        ],
        currentIndex: .constant(0)
    )
}