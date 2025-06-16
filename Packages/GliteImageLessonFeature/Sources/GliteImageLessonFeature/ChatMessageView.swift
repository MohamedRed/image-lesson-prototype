import SwiftUI

struct ChatMessageView: View {
    // MARK: - Constants
    private enum Constants {
        static let padding: CGFloat = 12
        static let cornerRadius: CGFloat = 16
        static let userMessageBackgroundColor: Color = .accentColor
        static let agentMessageBackgroundColor: Color = Color(uiColor: .systemGray5)
    }
    
    // MARK: - Properties
    let message: ChatMessage

    // MARK: - Body
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            Text(message.text)
                .padding(Constants.padding)
                .background(message.role == .user ? Constants.userMessageBackgroundColor : Constants.agentMessageBackgroundColor)
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(Constants.cornerRadius)
            
            if message.role == .agent {
                Spacer()
            }
        }
    }
} 