import SwiftUI

/// A view that displays a prominent error message to the user.
///
/// It overlays the screen with a standard error icon, a title, a detailed description
/// from the `Error` object, and a dismiss button.
struct ErrorView: View {
    
    // MARK: - Constants
    private enum Constants {
        static let iconName = "exclamationmark.triangle.fill"
        static let iconSize: CGFloat = 40
        static let titleText = "An Error Occurred"
        static let titleFont: Font = .headline
        static let descriptionFont: Font = .subheadline
        static let dismissButtonText = "Dismiss"
        static let dismissButtonHorizontalPadding: CGFloat = 20
        static let dismissButtonVerticalPadding: CGFloat = 10
        static let containerPadding: CGFloat = 30
        static let containerCornerRadius: CGFloat = 20
    }
    
    // MARK: - Properties
    let error: Error
    var onDismiss: () -> Void
    
    init(error: Error, onDismiss: @escaping () -> Void) {
        self.error = error
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: Theme.mainSpacing) {
                Image(systemName: Constants.iconName)
                    .font(.system(size: Constants.iconSize))
                    .foregroundColor(Theme.destructive)
                
                Text(Constants.titleText)
                    .font(Constants.titleFont)
                
                Text(error.localizedDescription)
                    .font(Constants.descriptionFont)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(Constants.dismissButtonText) {
                    onDismiss()
                }
                .padding(.horizontal, Constants.dismissButtonHorizontalPadding)
                .padding(.vertical, Constants.dismissButtonVerticalPadding)
                .background(Theme.secondarySurface)
                .cornerRadius(Theme.cornerRadius)
            }
            .padding(Constants.containerPadding)
            .background(.thinMaterial)
            .cornerRadius(Constants.containerCornerRadius)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.overlay)
        .edgesIgnoringSafeArea(.all)
    }
}

#if DEBUG
#Preview {
    struct SampleError: LocalizedError {
        var errorDescription: String? = "Could not connect to the server. Please check your internet connection and try again."
    }
    
    return ErrorView(error: SampleError(), onDismiss: {})
}
#endif 