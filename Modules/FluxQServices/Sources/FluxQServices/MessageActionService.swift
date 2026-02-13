import Foundation
import IPMsgProtocol

public enum MessageActionError: Error, Equatable {
    case emptyContent
    case forwardFailed(host: String)
}

@MainActor
public final class MessageActionService: ObservableObject {
    private let tcpMessageService: TCPMessageService
    private let recallService: RecallService

    public init(tcpMessageService: TCPMessageService, recallService: RecallService) {
        self.tcpMessageService = tcpMessageService
        self.recallService = recallService
    }

    /// Copy message content (returns the text for the caller to place on the clipboard)
    public func copyMessageContent(_ content: String) -> String {
        content
    }

    /// Forward a message to a specified user via TCP
    public func forwardMessage(content: String, to ipAddress: String, port: Int) async throws {
        do {
            try await tcpMessageService.sendMessage(content: content, to: ipAddress, port: port)
        } catch {
            throw MessageActionError.forwardFailed(host: ipAddress)
        }
    }

    /// Recall a message (delegates to RecallService)
    public func recallMessage(
        messageID: UUID,
        senderID: UUID,
        currentUserID: UUID,
        messageTimestamp: Date,
        isRecalled: Bool
    ) throws {
        try recallService.recallMessage(
            messageID: messageID,
            senderID: senderID,
            currentUserID: currentUserID,
            messageTimestamp: messageTimestamp,
            isRecalled: isRecalled
        )
    }

    /// Check whether a message can be recalled (delegates to RecallService)
    public func canRecall(
        messageTimestamp: Date,
        senderID: UUID,
        currentUserID: UUID,
        isRecalled: Bool
    ) -> Bool {
        recallService.canRecall(
            messageTimestamp: messageTimestamp,
            senderID: senderID,
            currentUserID: currentUserID,
            isRecalled: isRecalled
        )
    }
}
