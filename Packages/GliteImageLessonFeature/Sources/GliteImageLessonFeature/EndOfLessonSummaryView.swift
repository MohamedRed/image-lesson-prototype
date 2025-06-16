import SwiftUI
import GliteImageLessonService

/// A view that displays a summary of the completed lesson, including the original image,
/// the user's best image, the final score, and the original image description.
struct EndOfLessonSummaryView: View {
    
    // MARK: - Constants
    private enum Constants {
        static let titleText = "Lesson Complete!"
        static let titleFont: Font = .largeTitle
        static let descriptionLabelFont: Font = .body.weight(.medium)
        static let descriptionFont: Font = .body
        static let imageCaptionFont: Font = .caption
        static let scoreFont: Font = .title2
        static let imageMaxHeight: CGFloat = 250
        static let containerPadding: CGFloat = 30
        
        static let originalImageDescriptionLabel = "Original Description:"
        static let originalImageCaption = "Original Image"
        static let userImageCaption = "Your Best Image"
        static let scoreLabel = "Your Best Score: "
        static let leaveButtonText = "Leave"
    }
    
    let summary: EndLessonSummary
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.mainSpacing) {
            Text(Constants.titleText)
                .font(Constants.titleFont)
            
            Text(Constants.originalImageDescriptionLabel)
                .font(Constants.descriptionLabelFont)
            Text(summary.originalImageDescription)
                .font(Constants.descriptionFont)
                .italic()
            
            HStack(spacing: Theme.mainSpacing) {
                VStack(spacing: Theme.controlButtonSpacing) {
                    ImagePlaceholderView(url: summary.originalImageUrl, title: "Original")
                    Text(Constants.originalImageCaption)
                        .font(Constants.imageCaptionFont)
                        .foregroundColor(.secondary)
                }
                VStack(spacing: Theme.controlButtonSpacing) {
                    ImagePlaceholderView(url: summary.bestUserImageUrl, title: "Your Best")
                    Text(Constants.userImageCaption)
                        .font(Constants.imageCaptionFont)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxHeight: Constants.imageMaxHeight)
            
            if let bestScore = summary.bestUserScore {
                Text("\(Constants.scoreLabel)\(Int(bestScore * 100))%")
                    .font(Constants.scoreFont)
                    .foregroundColor(.green)
            }
            
            Button(Constants.leaveButtonText) {
                onDismiss()
            }
            .padding()
        }
        .padding(Constants.containerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview {
    let summary = EndLessonSummary(
        originalImageUrl: URL(string: "https://picsum.photos/seed/lesson/400"),
        originalImageDescription: "A beautiful landscape with mountains and a lake.",
        bestUserImageUrl: URL(string: "https://picsum.photos/seed/user/400"),
        bestUserScore: 0.88
    )
    
    return EndOfLessonSummaryView(summary: summary, onDismiss: {})
}
#endif 