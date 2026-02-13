import Foundation
import IPMsgProtocol

@MainActor
public final class TypingStateService: ObservableObject {
    // MARK: - Configuration

    /// How long before a typing state expires (seconds)
    public var typingTimeout: TimeInterval = 5.0

    /// Minimum interval between sending TYPING commands to the same user (seconds)
    public var debounceInterval: TimeInterval = 1.0

    // MARK: - State

    /// Maps remote user ID to the last time they were seen typing
    @Published public private(set) var typingUsers: [UUID: Date] = [:]

    /// Tracks last time we sent TYPING to each user (for debouncing)
    private var lastSentTyping: [UUID: Date] = [:]

    private let networkManager: NetworkManager
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(networkManager: NetworkManager) {
        self.networkManager = networkManager
        startCleanupTimer()
    }

    deinit {
        cleanupTask?.cancel()
    }

    // MARK: - Outgoing Commands

    /// Send a TYPING indicator to a specific user via UDP broadcast
    public func startTyping(to userId: UUID) throws {
        let now = Date()

        // Debounce: skip if we sent TYPING to this user within the debounce interval
        if let lastSent = lastSentTyping[userId],
           now.timeIntervalSince(lastSent) < debounceInterval {
            return
        }

        try networkManager.sendBroadcast(command: .TYPING, payload: userId.uuidString)
        lastSentTyping[userId] = now
    }

    /// Send a STOPTYPING indicator to a specific user via UDP broadcast
    public func stopTyping(to userId: UUID) throws {
        lastSentTyping.removeValue(forKey: userId)
        try networkManager.sendBroadcast(command: .STOPTYPING, payload: userId.uuidString)
    }

    // MARK: - Incoming Commands

    /// Handle an incoming TYPING command from a remote user
    public func handleTypingCommand(from senderId: UUID) {
        typingUsers[senderId] = Date()
    }

    /// Handle an incoming STOPTYPING command from a remote user
    public func handleStopTypingCommand(from senderId: UUID) {
        typingUsers.removeValue(forKey: senderId)
    }

    // MARK: - Query

    /// Check if a remote user is currently typing
    public func isUserTyping(_ userId: UUID) -> Bool {
        guard let lastTyping = typingUsers[userId] else {
            return false
        }
        return Date().timeIntervalSince(lastTyping) <= typingTimeout
    }

    // MARK: - Cleanup

    /// Remove expired typing states. Exposed for testing.
    public func cleanupExpiredTypingStates() {
        let now = Date()
        typingUsers = typingUsers.filter { _, lastTyping in
            now.timeIntervalSince(lastTyping) <= typingTimeout
        }
    }

    private func startCleanupTimer() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.cleanupExpiredTypingStates()
            }
        }
    }
}
