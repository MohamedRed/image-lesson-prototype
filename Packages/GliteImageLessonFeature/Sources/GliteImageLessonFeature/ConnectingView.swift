import SwiftUI

/// A simple view that displays a loading spinner and a text message,
/// used to indicate that the application is connecting to the lesson service.
struct ConnectingView: View {
    // MARK: - Constants
    private enum Constants {
        static let spinnerScale: CGFloat = 1.5
        static let titleFont: Font = .title2
        static let titleText = "Preparing your lesson..."
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Theme.overlay.edgesIgnoringSafeArea(.all)
            VStack(spacing: Theme.mainSpacing) {
                ProgressView()
                    .scaleEffect(Constants.spinnerScale)
                Text(Constants.titleText)
                    .font(Constants.titleFont)
                    .foregroundColor(.white)
            }
        }
    }
}

#if DEBUG
#Preview {
    ConnectingView()
}
#endif 