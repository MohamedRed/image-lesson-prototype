import Foundation
import Combine

/// Offline storage service for Events feature data persistence
public final class EventsOfflineStorageService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var cachedEvents: [Event] = []
    @Published public private(set) var cachedGroups: [AttendanceGroup] = []
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let cacheDirectory: URL
    private let maxCacheAge: TimeInterval = 86400 // 24 hours
    private var syncTimer: Timer?
    
    // Cache keys
    private enum CacheKeys: String, CaseIterable {
        case events = "events_cache"
        case groups = "groups_cache"
        case orders = "orders_cache"
        case friends = "friends_cache"
        case lastSyncDate = "last_sync_date"
        case offlineActions = "offline_actions"
    }
    
    // MARK: - Initialization
    
    public init() {
        // Setup cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("EventsCache", isDirectory: true)
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Load cached data
        loadCachedData()
        
        // Setup sync timer
        setupPeriodicSync()
    }
    
    // MARK: - Public Methods
    
    /// Cache events data
    public func cacheEvents(_ events: [Event]) {
        cachedEvents = events
        saveToDisk(events, key: .events)
        updateLastSyncDate()
    }
    
    /// Cache groups data
    public func cacheGroups(_ groups: [AttendanceGroup]) {
        cachedGroups = groups
        saveToDisk(groups, key: .groups)
    }
    
    /// Cache ticket orders
    public func cacheOrders(_ orders: [TicketOrder]) {
        saveToDisk(orders, key: .orders)
    }
    
    /// Cache friends data
    public func cacheFriends(_ friends: [EventsFriend]) {
        saveToDisk(friends, key: .friends)
    }
    
    /// Get cached events
    public func getCachedEvents() -> [Event] {
        if cachedEvents.isEmpty {
            cachedEvents = loadFromDisk(key: .events) ?? []
        }
        return filterValidCache(cachedEvents)
    }
    
    /// Get cached groups
    public func getCachedGroups() -> [AttendanceGroup] {
        if cachedGroups.isEmpty {
            cachedGroups = loadFromDisk(key: .groups) ?? []
        }
        return filterValidCache(cachedGroups)
    }
    
    /// Get cached orders
    public func getCachedOrders() -> [TicketOrder] {
        let cached: [TicketOrder] = loadFromDisk(key: .orders) ?? []
        return filterValidCache(cached)
    }
    
    /// Get cached friends
    public func getCachedFriends() -> [EventsFriend] {
        let cached: [EventsFriend] = loadFromDisk(key: .friends) ?? []
        return filterValidCache(cached)
    }
    
    /// Queue offline action for later sync
    public func queueOfflineAction(_ action: OfflineAction) {
        var actions: [OfflineAction] = loadFromDisk(key: .offlineActions) ?? []
        actions.append(action)
        saveToDisk(actions, key: .offlineActions)
        
        // Try to sync immediately if online
        Task {
            await attemptSync()
        }
    }
    
    /// Get queued offline actions
    public func getQueuedActions() -> [OfflineAction] {
        return loadFromDisk(key: .offlineActions) ?? []
    }
    
    /// Clear completed offline action
    public func clearOfflineAction(id: String) {
        var actions: [OfflineAction] = loadFromDisk(key: .offlineActions) ?? []
        actions.removeAll { $0.id == id }
        saveToDisk(actions, key: .offlineActions)
    }
    
    /// Clear all cached data
    public func clearAllCache() {
        cachedEvents.removeAll()
        cachedGroups.removeAll()
        
        for key in CacheKeys.allCases {
            let url = cacheDirectory.appendingPathComponent("\(key.rawValue).json")
            try? fileManager.removeItem(at: url)
        }
        
        userDefaults.removeObject(forKey: CacheKeys.lastSyncDate.rawValue)
        lastSyncDate = nil
    }
    
    /// Check if cache is stale
    public func isCacheStale() -> Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > maxCacheAge
    }
    
    /// Force sync with server
    public func forceSync() async {
        await performSync()
    }
    
    // MARK: - Private Methods
    
    private func loadCachedData() {
        cachedEvents = loadFromDisk(key: .events) ?? []
        cachedGroups = loadFromDisk(key: .groups) ?? []
        lastSyncDate = userDefaults.object(forKey: CacheKeys.lastSyncDate.rawValue) as? Date
    }
    
    private func saveToDisk<T: Codable>(_ data: T, key: CacheKeys) {
        let url = cacheDirectory.appendingPathComponent("\(key.rawValue).json")
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            try jsonData.write(to: url)
        } catch {
            print("Failed to save \(key.rawValue) to disk: \(error)")
        }
    }
    
    private func loadFromDisk<T: Codable>(key: CacheKeys, type: T.Type = T.self) -> T? {
        let url = cacheDirectory.appendingPathComponent("\(key.rawValue).json")
        
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Failed to load \(key.rawValue) from disk: \(error)")
            return nil
        }
    }
    
    private func filterValidCache<T: Cacheable>(_ items: [T]) -> [T] {
        let now = Date()
        return items.filter { item in
            guard let cacheDate = item.cacheTimestamp else { return true }
            return now.timeIntervalSince(cacheDate) < maxCacheAge
        }
    }
    
    private func updateLastSyncDate() {
        lastSyncDate = Date()
        userDefaults.set(lastSyncDate, forKey: CacheKeys.lastSyncDate.rawValue)
    }
    
    private func setupPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.attemptSync()
            }
        }
    }
    
    private func attemptSync() async {
        // Only sync if we have network connectivity
        // This would integrate with NetworkConnectivityMonitor
        await performSync()
    }
    
    private func performSync() async {
        await MainActor.run {
            syncStatus = .syncing
        }
        
        do {
            // Process queued offline actions
            let queuedActions = getQueuedActions()
            
            for action in queuedActions {
                do {
                    try await processOfflineAction(action)
                    clearOfflineAction(id: action.id)
                } catch {
                    print("Failed to sync action \(action.id): \(error)")
                    // Keep action in queue for later retry
                }
            }
            
            await MainActor.run {
                syncStatus = .completed
                updateLastSyncDate()
            }
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error)
            }
        }
    }
    
    private func processOfflineAction(_ action: OfflineAction) async throws {
        switch action.type {
        case .createGroup:
            // Re-attempt group creation
            if let data = action.data as? [String: Any] {
                // Would call EventsService to create group
                print("Syncing create group: \(data)")
            }
            
        case .updateRSVP:
            // Re-attempt RSVP update
            if let data = action.data as? [String: Any] {
                print("Syncing RSVP update: \(data)")
            }
            
        case .createOrder:
            // Re-attempt order creation
            if let data = action.data as? [String: Any] {
                print("Syncing create order: \(data)")
            }
            
        case .sendMessage:
            // Re-attempt message sending
            if let data = action.data as? [String: Any] {
                print("Syncing send message: \(data)")
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}

// MARK: - Supporting Types

public enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

public struct OfflineAction: Codable, Identifiable {
    public let id: String
    public let type: OfflineActionType
    public let data: [String: AnyCodable]
    public let timestamp: Date
    public let retryCount: Int
    
    public init(
        id: String = UUID().uuidString,
        type: OfflineActionType,
        data: [String: Any],
        timestamp: Date = Date(),
        retryCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.data = data.mapValues { AnyCodable($0) }
        self.timestamp = timestamp
        self.retryCount = retryCount
    }
}

public enum OfflineActionType: String, Codable {
    case createGroup
    case updateRSVP
    case createOrder
    case sendMessage
}

/// Protocol for cacheable items
public protocol Cacheable {
    var cacheTimestamp: Date? { get }
}

// Extend existing models to support caching
extension Event: Cacheable {
    public var cacheTimestamp: Date? {
        return updatedAt
    }
}

extension AttendanceGroup: Cacheable {
    public var cacheTimestamp: Date? {
        return updatedAt
    }
}

extension TicketOrder: Cacheable {
    public var cacheTimestamp: Date? {
        return updatedAt
    }
}

extension EventsFriend: Cacheable {
    public var cacheTimestamp: Date? {
        return lastSeen
    }
}

// Helper for encoding Any values
public struct AnyCodable: Codable {
    private let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }
}