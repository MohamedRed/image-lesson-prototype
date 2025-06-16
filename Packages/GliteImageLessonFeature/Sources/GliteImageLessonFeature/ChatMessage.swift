import Foundation

public struct ChatMessage: Identifiable, Equatable {
    public enum Role: Equatable {
        case agent
        case user
    }

    public let id = UUID()
    public let role: Role
    public let text: String
} 