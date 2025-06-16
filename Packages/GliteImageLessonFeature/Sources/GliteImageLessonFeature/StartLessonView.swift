import SwiftUI

/// A simple view that displays a "Start a lesson" button.
///
/// This view is typically shown when the lesson is in an idle state, providing the
/// user with a clear entry point to begin the session.
struct StartLessonView: View {
    
    // MARK: - Constants
    private enum Constants {
        static let title = "Start a lesson"
        static let font: Font = .headline
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 12
    }
    
    // MARK: - Properties
    var onStart: () -> Void
    
    var body: some View {
        VStack {
            Button(action: onStart) {
                Text(Constants.title)
                    .font(Constants.font)
                    .padding(.horizontal, Constants.horizontalPadding)
                    .padding(.vertical, Constants.verticalPadding)
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.cornerRadius)
            }
        }
    }
}

#if DEBUG
#Preview {
    StartLessonView(onStart: {})
        .padding()
        .background(Color.black)
}
#endif 