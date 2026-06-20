import Foundation
import FirebaseFirestore

// MARK: - Core Models

public struct FriendProfile: Codable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let photoURL: String?
    public let handle: String?
    public let city: String?
    public let hashedPhone: String?
    
    public init(
        id: String,
        displayName: String,
        photoURL: String? = nil,
        handle: String? = nil,
        city: String? = nil,
        hashedPhone: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.photoURL = photoURL
        self.handle = handle
        self.city = city
        self.hashedPhone = hashedPhone
    }
}

public struct Friendship: Codable, Identifiable {
    public let id: String
    public let users: [String]
    public let status: Status
    public let requestedBy: String
    public let createdAt: Date
    public let updatedAt: Date
    public let blockedBy: String?
    
    public enum Status: String, Codable, CaseIterable {
        case pending = "pending"
        case accepted = "accepted"
        case declined = "declined"
        case blocked = "blocked"
        case cancelled = "cancelled"
    }
    
    public init(
        id: String,
        users: [String],
        status: Status,
        requestedBy: String,
        createdAt: Date,
        updatedAt: Date,
        blockedBy: String? = nil
    ) {
        self.id = id
        self.users = users
        self.status = status
        self.requestedBy = requestedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.blockedBy = blockedBy
    }
}

public struct Conversation: Codable, Identifiable {
    public let id: String
    public let type: ConversationType
    public let participants: [String]
    public let admins: [String]
    public let title: String?
    public let lastMessageAt: Date?
    public let unreadCount: [String: Int]
    public let linkedFeature: LinkedFeature?
    public let createdAt: Date
    public let updatedAt: Date
    
    public enum ConversationType: String, Codable, CaseIterable {
        case direct = "direct"
        case group = "group"
        case party = "party"
    }
    
    public struct LinkedFeature: Codable {
        public let kind: String
        public let id: String
        public let meta: [String: AnyCodable]?
        
        public init(kind: String, id: String, meta: [String: AnyCodable]? = nil) {
            self.kind = kind
            self.id = id
            self.meta = meta
        }
    }
    
    public init(
        id: String,
        type: ConversationType,
        participants: [String],
        admins: [String],
        title: String? = nil,
        lastMessageAt: Date? = nil,
        unreadCount: [String: Int] = [:],
        linkedFeature: LinkedFeature? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.type = type
        self.participants = participants
        self.admins = admins
        self.title = title
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.linkedFeature = linkedFeature
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct Message: Codable, Identifiable {
    public let id: String
    public let senderId: String
    public let type: MessageType
    public let content: String
    public let attachments: [Attachment]
    public let action: ActionCard?
    public let createdAt: Date
    public let editedAt: Date?
    public let deletedAt: Date?
    
    public enum MessageType: String, Codable, CaseIterable {
        case text = "text"
        case image = "image"
        case voice = "voice"
        case location = "location"
        case action = "action"
        case system = "system"
    }
    
    public struct Attachment: Codable {
        public let url: String
        public let thumbURL: String?
        public let kind: AttachmentKind
        
        public enum AttachmentKind: String, Codable, CaseIterable {
            case image = "image"
            case video = "video"
            case audio = "audio"
            case document = "document"
        }
        
        public init(url: String, thumbURL: String? = nil, kind: AttachmentKind) {
            self.url = url
            self.thumbURL = thumbURL
            self.kind = kind
        }
    }
    
    public struct ActionCard: Codable {
        public let kind: String
        public let refId: String
        public let refKind: String
        public let meta: [String: AnyCodable]
        
        public init(kind: String, refId: String, refKind: String, meta: [String: AnyCodable]) {
            self.kind = kind
            self.refId = refId
            self.refKind = refKind
            self.meta = meta
        }
    }
    
    public init(
        id: String,
        senderId: String,
        type: MessageType,
        content: String,
        attachments: [Attachment] = [],
        action: ActionCard? = nil,
        createdAt: Date,
        editedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.senderId = senderId
        self.type = type
        self.content = content
        self.attachments = attachments
        self.action = action
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.deletedAt = deletedAt
    }
}

public struct PresenceStatus: Codable {
    public let userId: String
    public let status: Status
    public let lastActiveAt: Date
    
    public enum Status: String, Codable, CaseIterable {
        case online = "online"
        case away = "away"
        case dnd = "dnd"
        case offline = "offline"
    }
    
    public init(userId: String, status: Status, lastActiveAt: Date) {
        self.userId = userId
        self.status = status
        self.lastActiveAt = lastActiveAt
    }
}

public struct InviteInfo: Codable {
    public let code: String
    public let url: String
    public let expiresAt: Date
    public let maxUses: Int
    public let usageCount: Int
    public let context: InviteContext?
    
    public init(
        code: String,
        url: String,
        expiresAt: Date,
        maxUses: Int,
        usageCount: Int = 0,
        context: InviteContext? = nil
    ) {
        self.code = code
        self.url = url
        self.expiresAt = expiresAt
        self.maxUses = maxUses
        self.usageCount = usageCount
        self.context = context
    }
}

public struct InviteContext: Codable {
    public let source: String
    public let featureId: String?
    public let metadata: [String: AnyCodable]?
    
    public init(source: String, featureId: String? = nil, metadata: [String: AnyCodable]? = nil) {
        self.source = source
        self.featureId = featureId
        self.metadata = metadata
    }
}

public struct MatchedContact: Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let photoURL: String?
    public let hashedPhone: String
    public let friendshipStatus: Friendship.Status?
    
    public init(
        id: String,
        displayName: String,
        photoURL: String? = nil,
        hashedPhone: String,
        friendshipStatus: Friendship.Status? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.photoURL = photoURL
        self.hashedPhone = hashedPhone
        self.friendshipStatus = friendshipStatus
    }
}

// MARK: - Event Models

public enum FriendEvent {
    case requestReceived(Friendship)
    case requestAccepted(Friendship)
    case requestDeclined(Friendship)
    case friendAdded(FriendProfile)
    case friendRemoved(String)
    case userBlocked(String)
    case userUnblocked(String)
}

public enum ConversationEvent {
    case created(Conversation)
    case updated(Conversation)
    case participantAdded(conversationId: String, userId: String)
    case participantRemoved(conversationId: String, userId: String)
    case titleChanged(conversationId: String, newTitle: String)
}

// MARK: - Draft Models

public struct MessageDraft {
    public let type: Message.MessageType
    public let content: String
    public let attachments: [Message.Attachment]
    public let action: Message.ActionCard?
    
    public init(
        type: Message.MessageType = .text,
        content: String,
        attachments: [Message.Attachment] = [],
        action: Message.ActionCard? = nil
    ) {
        self.type = type
        self.content = content
        self.attachments = attachments
        self.action = action
    }
}

public struct ActionCardPayload: Codable {
    public let kind: String
    public let refId: String
    public let meta: [String: AnyCodable]
    
    public init(kind: String, refId: String, meta: [String: AnyCodable]) {
        self.kind = kind
        self.refId = refId
        self.meta = meta
    }
}

// MARK: - Helper Types

public struct AnyCodable: Codable {
    public let value: Any
    
    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

extension AnyCodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.init(())
        } else if let bool = try? container.decode(Bool.self) {
            self.init(bool)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let double = try? container.decode(Double.self) {
            self.init(double)
        } else if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.init(array.map { $0.value })
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.init(dictionary.mapValues { $0.value })
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, 
                                    debugDescription: "AnyCodable value cannot be decoded")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: encoder.codingPath,
                                              debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

extension AnyCodable: Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (Void, Void):
            return true
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        case let (lhs as [String: Any], rhs as [String: Any]):
            return NSDictionary(dictionary: lhs).isEqual(to: rhs)
        case let (lhs as [Any], rhs as [Any]):
            return NSArray(array: lhs).isEqual(to: rhs)
        default:
            return false
        }
    }
}

extension AnyCodable: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch value {
        case let bool as Bool:
            hasher.combine(bool)
        case let int as Int:
            hasher.combine(int)
        case let double as Double:
            hasher.combine(double)
        case let string as String:
            hasher.combine(string)
        default:
            hasher.combine(0)
        }
    }
}