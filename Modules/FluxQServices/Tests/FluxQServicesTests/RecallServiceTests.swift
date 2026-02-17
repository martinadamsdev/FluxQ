import Testing
import Foundation
@testable import FluxQServices
import IPMsgProtocol

@MainActor
struct RecallServiceTests {

    // MARK: - Helpers

    private func makeService(recallWindow: TimeInterval = 120) -> (RecallService, MockNetworkTransport) {
        let transport = MockNetworkTransport()
        let networkManager = NetworkManager(port: 2425, transport: transport)
        let service = RecallService(networkManager: networkManager)
        service.recallWindow = recallWindow
        return (service, transport)
    }

    // MARK: - canRecall

    @Test("canRecall returns true within time window for own message")
    func canRecallWithinWindow() {
        let (service, _) = makeService()
        let myId = UUID()
        let result = service.canRecall(
            messageTimestamp: Date(),
            senderID: myId,
            currentUserID: myId,
            isRecalled: false
        )
        #expect(result == true)
    }

    @Test("canRecall returns false when time window has expired")
    func canRecallExpired() {
        let (service, _) = makeService(recallWindow: 120)
        let myId = UUID()
        let result = service.canRecall(
            messageTimestamp: Date().addingTimeInterval(-200),
            senderID: myId,
            currentUserID: myId,
            isRecalled: false
        )
        #expect(result == false)
    }

    @Test("canRecall returns false for another user's message")
    func canRecallNotAuthorized() {
        let (service, _) = makeService()
        let result = service.canRecall(
            messageTimestamp: Date(),
            senderID: UUID(),
            currentUserID: UUID(),
            isRecalled: false
        )
        #expect(result == false)
    }

    @Test("canRecall returns false for already recalled message")
    func canRecallAlreadyRecalled() {
        let (service, _) = makeService()
        let myId = UUID()
        let result = service.canRecall(
            messageTimestamp: Date(),
            senderID: myId,
            currentUserID: myId,
            isRecalled: true
        )
        #expect(result == false)
    }

    // MARK: - recallMessage

    @Test("recallMessage succeeds within time window")
    func recallMessageSuccess() throws {
        let (service, _) = makeService()
        let myId = UUID()
        try service.recallMessage(
            messageID: UUID(),
            senderID: myId,
            currentUserID: myId,
            messageTimestamp: Date(),
            isRecalled: false
        )
    }

    @Test("recallMessage throws timeoutExpired when window has passed")
    func recallMessageTimeout() {
        let (service, _) = makeService(recallWindow: 120)
        let myId = UUID()
        #expect(throws: RecallError.timeoutExpired) {
            try service.recallMessage(
                messageID: UUID(),
                senderID: myId,
                currentUserID: myId,
                messageTimestamp: Date().addingTimeInterval(-200),
                isRecalled: false
            )
        }
    }

    @Test("recallMessage throws notAuthorized for another user's message")
    func recallMessageNotAuthorized() {
        let (service, _) = makeService()
        #expect(throws: RecallError.notAuthorized) {
            try service.recallMessage(
                messageID: UUID(),
                senderID: UUID(),
                currentUserID: UUID(),
                messageTimestamp: Date(),
                isRecalled: false
            )
        }
    }

    @Test("recallMessage throws alreadyRecalled for recalled message")
    func recallMessageAlreadyRecalled() {
        let (service, _) = makeService()
        let myId = UUID()
        #expect(throws: RecallError.alreadyRecalled) {
            try service.recallMessage(
                messageID: UUID(),
                senderID: myId,
                currentUserID: myId,
                messageTimestamp: Date(),
                isRecalled: true
            )
        }
    }

    @Test("recallMessage sends RECALLMSG broadcast with message ID")
    func recallMessageSendsBroadcast() throws {
        let (service, transport) = makeService()
        let myId = UUID()
        let msgId = UUID()
        try service.recallMessage(
            messageID: msgId,
            senderID: myId,
            currentUserID: myId,
            messageTimestamp: Date(),
            isRecalled: false
        )

        #expect(transport.broadcastMessages.count == 1)
        let data = transport.broadcastMessages[0].data
        let message = String(data: data, encoding: .utf8)!
        let packet = try IPMsgPacket.decode(message)
        #expect(packet.command == .RECALLMSG)
        let cleanPayload = String(packet.payload.split(separator: "\0", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        #expect(cleanPayload == msgId.uuidString)
    }

    @Test("recallMessage records to recentRecalls on success")
    func recallMessageRecordsRecall() throws {
        let (service, _) = makeService()
        let myId = UUID()
        let msgId = UUID()
        try service.recallMessage(
            messageID: msgId,
            senderID: myId,
            currentUserID: myId,
            messageTimestamp: Date(),
            isRecalled: false
        )

        #expect(service.recentRecalls[msgId] != nil)
    }

    // MARK: - handleRecallCommand

    @Test("handleRecallCommand adds message to recentRecalls")
    func handleRecallCommandAdds() {
        let (service, _) = makeService()
        let msgId = UUID()
        service.handleRecallCommand(messageID: msgId, from: UUID())
        #expect(service.recentRecalls[msgId] != nil)
    }

    // MARK: - isMessageRecalled

    @Test("isMessageRecalled returns true for recalled message")
    func isMessageRecalledTrue() {
        let (service, _) = makeService()
        let msgId = UUID()
        service.handleRecallCommand(messageID: msgId, from: UUID())
        #expect(service.isMessageRecalled(msgId) == true)
    }

    @Test("isMessageRecalled returns false for unknown message")
    func isMessageRecalledFalse() {
        let (service, _) = makeService()
        #expect(service.isMessageRecalled(UUID()) == false)
    }

    // MARK: - cleanupExpiredRecalls

    @Test("cleanupExpiredRecalls removes records older than 24 hours")
    func cleanupExpiredRecalls() {
        let (service, _) = makeService()
        let oldMsgId = UUID()
        let newMsgId = UUID()

        // Insert an old recall (more than 24h ago)
        service.handleRecallCommand(messageID: oldMsgId, from: UUID())
        // Manually override to simulate an old entry
        service.recentRecalls[oldMsgId] = Date().addingTimeInterval(-90000)

        // Insert a recent recall
        service.handleRecallCommand(messageID: newMsgId, from: UUID())

        service.cleanupExpiredRecalls()

        #expect(service.recentRecalls[oldMsgId] == nil)
        #expect(service.recentRecalls[newMsgId] != nil)
    }
}
