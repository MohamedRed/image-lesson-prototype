import SwiftUI

/// A reusable view that displays an image from a URL with placeholder and loading states.
///
/// This view shows a title as a placeholder, a progress spinner while the image is loading
/// from the `URL`, and the final image once it's loaded. It also has a separate
/// `isLoading` flag to show a spinner on top of the old image while a new one is being generated.
struct ImagePlaceholderView: View {
    // MARK: - Constants
    private enum Constants {
        static let font: Font = .body
    }
    
    // MARK: - Properties
    let url: URL?
    let title: String
    let isLoading: Bool

    init(url: URL?, title: String, isLoading: Bool = false) {
        self.url = url
        self.title = title
        self.isLoading = isLoading
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius)
            .fill(Theme.mutedSurface)
            .overlay {
                // Overlay the AsyncImage. It will be clipped to the RoundedRectangle's bounds.
                if let url = url {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    Text(title)
                        .foregroundColor(.secondary)
                        .font(Constants.font)
                }
            }
            .overlay {
                // A second overlay for the loading indicator on top of everything.
                if isLoading {
                    ProgressView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

#if DEBUG
#Preview("No Image") {
    ImagePlaceholderView(url: nil, title: "Your Image")
}

#Preview("With Image") {
    ImagePlaceholderView(url: URL(string: "https://picsum.photos/400"), title: "Lesson Image")
}

#Preview("Loading") {
    ImagePlaceholderView(url: URL(string: "https://picsum.photos/400"), title: "Your Image", isLoading: true)
}
#endif 