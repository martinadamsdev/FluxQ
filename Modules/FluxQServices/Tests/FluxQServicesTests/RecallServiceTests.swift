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
        let result = service.canRecall(
            messageTimestamp: Date(),
            senderID: "me",
            currentUserID: "me",
            isRecalled: false
        )
        #expect(result == true)
    }

    @Test("canRecall returns false when time window has expired")
    func canRecallExpired() {
        let (service, _) = makeService(recallWindow: 120)
        let result = service.canRecall(
            messageTimestamp: Date().addingTimeInterval(-200),
            senderID: "me",
            currentUserID: "me",
            isRecalled: false
        )
        #expect(result == false)
    }

    @Test("canRecall returns false for another user's message")
    func canRecallNotAuthorized() {
        let (service, _) = makeService()
        let result = service.canRecall(
            messageTimestamp: Date(),
            senderID: "other-user",
            currentUserID: "me",
            isRecalled: false
        )
        #expect(result == false)
    }

    @Test("canRecall returns false for already recalled message")
    func canRecallAlreadyRecalled() {
        let (service, _) = makeService()
        let result = service.canRecall(
            messageTimestamp: Date(),
            senderID: "me",
            currentUserID: "me",
            isRecalled: true
        )
        #expect(result == false)
    }

    // MARK: - recallMessage

    @Test("recallMessage succeeds within time window")
    func recallMessageSuccess() throws {
        let (service, _) = makeService()
        try service.recallMessage(
            messageID: "msg-1",
            senderID: "me",
            currentUserID: "me",
            messageTimestamp: Date(),
            isRecalled: false
        )
    }

    @Test("recallMessage throws timeoutExpired when window has passed")
    func recallMessageTimeout() {
        let (service, _) = makeService(recallWindow: 120)
        #expect(throws: RecallError.timeoutExpired) {
            try service.recallMessage(
                messageID: "msg-1",
                senderID: "me",
                currentUserID: "me",
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
                messageID: "msg-1",
                senderID: "other-user",
                currentUserID: "me",
                messageTimestamp: Date(),
                isRecalled: false
            )
        }
    }

    @Test("recallMessage throws alreadyRecalled for recalled message")
    func recallMessageAlreadyRecalled() {
        let (service, _) = makeService()
        #expect(throws: RecallError.alreadyRecalled) {
            try service.recallMessage(
                messageID: "msg-1",
                senderID: "me",
                currentUserID: "me",
                messageTimestamp: Date(),
                isRecalled: true
            )
        }
    }

    @Test("recallMessage sends RECALLMSG broadcast with message ID")
    func recallMessageSendsBroadcast() throws {
        let (service, transport) = makeService()
        try service.recallMessage(
            messageID: "msg-42",
            senderID: "me",
            currentUserID: "me",
            messageTimestamp: Date(),
            isRecalled: false
        )

        #expect(transport.broadcastMessages.count == 1)
        let data = transport.broadcastMessages[0].data
        let message = String(data: data, encoding: .utf8)!
        let packet = try IPMsgPacket.decode(message)
        #expect(packet.command == .RECALLMSG)
        #expect(packet.payload == "msg-42")
    }

    @Test("recallMessage records to recentRecalls on success")
    func recallMessageRecordsRecall() throws {
        let (service, _) = makeService()
        try service.recallMessage(
            messageID: "msg-1",
            senderID: "me",
            currentUserID: "me",
            messageTimestamp: Date(),
            isRecalled: false
        )

        #expect(service.recentRecalls["msg-1"] != nil)
    }

    // MARK: - handleRecallCommand

    @Test("handleRecallCommand adds message to recentRecalls")
    func handleRecallCommandAdds() {
        let (service, _) = makeService()
        service.handleRecallCommand(messageID: "msg-99", from: "remote-user")
        #expect(service.recentRecalls["msg-99"] != nil)
    }

    // MARK: - isMessageRecalled

    @Test("isMessageRecalled returns true for recalled message")
    func isMessageRecalledTrue() {
        let (service, _) = makeService()
        service.handleRecallCommand(messageID: "msg-1", from: "remote-user")
        #expect(service.isMessageRecalled("msg-1") == true)
    }

    @Test("isMessageRecalled returns false for unknown message")
    func isMessageRecalledFalse() {
        let (service, _) = makeService()
        #expect(service.isMessageRecalled("unknown") == false)
    }

    // MARK: - cleanupExpiredRecalls

    @Test("cleanupExpiredRecalls removes records older than 24 hours")
    func cleanupExpiredRecalls() {
        let (service, _) = makeService()

        // Insert an old recall (more than 24h ago)
        service.handleRecallCommand(messageID: "old-msg", from: "user")
        // Manually override to simulate an old entry
        service.recentRecalls["old-msg"] = Date().addingTimeInterval(-90000)

        // Insert a recent recall
        service.handleRecallCommand(messageID: "new-msg", from: "user")

        service.cleanupExpiredRecalls()

        #expect(service.recentRecalls["old-msg"] == nil)
        #expect(service.recentRecalls["new-msg"] != nil)
    }
}
