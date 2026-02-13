import Foundation

@MainActor
public final class HeartbeatService: ObservableObject {
    // MARK: - Platform-specific intervals

    public var heartbeatInterval: TimeInterval {
        #if os(watchOS)
        return 60.0
        #else
        return 30.0
        #endif
    }

    public var timeoutInterval: TimeInterval {
        heartbeatInterval * 2
    }

    // MARK: - State

    /// Tracks last heartbeat time for each user ID
    public private(set) var onlineUsers: [UUID: Date] = [:]

    /// Tracks missed heartbeat count per user for progressive removal
    private var missedHeartbeats: [UUID: Int] = [:]

    private var heartbeatTask: Task<Void, Never>?
    private var timeoutMonitorTask: Task<Void, Never>?

    // MARK: - Initialization

    public init() {}

    deinit {
        heartbeatTask?.cancel()
        timeoutMonitorTask?.cancel()
    }

    // MARK: - Public Methods

    /// Record a heartbeat from a user
    public func recordHeartbeat(userId: UUID, at date: Date = Date()) {
        onlineUsers[userId] = date
        missedHeartbeats[userId] = 0
    }

    /// Check if a user is currently online
    public func isUserOnline(_ userId: UUID, at currentTime: Date = Date()) -> Bool {
        guard let lastSeen = onlineUsers[userId] else {
            return false
        }
        return currentTime.timeIntervalSince(lastSeen) <= timeoutInterval
    }

    /// Check for timed-out users and handle progressive removal
    public func checkTimeouts(currentTime: Date = Date()) {
        for (userId, lastSeen) in onlineUsers {
            if currentTime.timeIntervalSince(lastSeen) > timeoutInterval {
                missedHeartbeats[userId, default: 0] += 1

                if missedHeartbeats[userId, default: 0] >= 3 {
                    onlineUsers.removeValue(forKey: userId)
                    missedHeartbeats.removeValue(forKey: userId)
                }
            }
        }
    }

    /// Start periodic heartbeat broadcasting and timeout monitoring
    public func start(sendBroadcast: @escaping () async throws -> Void) {
        stop()

        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await sendBroadcast()
                try? await Task.sleep(for: .seconds(self.heartbeatInterval))
            }
        }

        timeoutMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.checkTimeouts()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    /// Stop heartbeat broadcasting and timeout monitoring
    public func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        timeoutMonitorTask?.cancel()
        timeoutMonitorTask = nil
    }
}
