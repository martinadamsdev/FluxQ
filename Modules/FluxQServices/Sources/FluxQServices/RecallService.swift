import Foundation
import IPMsgProtocol

public enum RecallError: Error, Equatable {
    case timeoutExpired
    case notAuthorized
    case alreadyRecalled
}

@MainActor
public final class RecallService: ObservableObject {
    // MARK: - Configuration

    /// Time window (in seconds) during which a message can be recalled
    public var recallWindow: TimeInterval = 120

    // MARK: - State

    /// Maps recalled message IDs to the time they were recalled
    @Published public internal(set) var recentRecalls: [UUID: Date] = [:]

    private let networkManager: NetworkManager

    // MARK: - Initialization

    public init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }

    // MARK: - Public Methods

    /// Check whether a message can be recalled
    public func canRecall(messageTimestamp: Date, senderID: UUID, currentUserID: UUID, isRecalled: Bool) -> Bool {
        guard !isRecalled else { return false }
        guard senderID == currentUserID else { return false }
        return Date().timeIntervalSince(messageTimestamp) <= recallWindow
    }

    /// Recall a message: validate rules, send RECALLMSG broadcast, and track locally
    public func recallMessage(
        messageID: UUID,
        senderID: UUID,
        currentUserID: UUID,
        messageTimestamp: Date,
        isRecalled: Bool
    ) throws {
        guard Date().timeIntervalSince(messageTimestamp) <= recallWindow else {
            throw RecallError.timeoutExpired
        }
        guard senderID == currentUserID else {
            throw RecallError.notAuthorized
        }
        guard !isRecalled else {
            throw RecallError.alreadyRecalled
        }

        try networkManager.sendBroadcast(command: .RECALLMSG, payload: messageID.uuidString)
        recentRecalls[messageID] = Date()
    }

    /// Handle an incoming RECALLMSG command from a remote user
    public func handleRecallCommand(messageID: UUID, from senderID: UUID) {
        recentRecalls[messageID] = Date()
    }

    /// Check if a message has been remotely recalled
    public func isMessageRecalled(_ messageID: UUID) -> Bool {
        recentRecalls[messageID] != nil
    }

    /// Remove recall records older than 24 hours
    public func cleanupExpiredRecalls() {
        let cutoff = Date().addingTimeInterval(-86400)
        recentRecalls = recentRecalls.filter { $0.value > cutoff }
    }
}
