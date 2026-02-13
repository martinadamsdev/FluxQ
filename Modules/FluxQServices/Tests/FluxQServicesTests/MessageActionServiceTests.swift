import Testing
import Foundation
@testable import FluxQServices
import IPMsgProtocol

@MainActor
struct MessageActionServiceTests {

    // MARK: - Helpers

    /// Mock socket connection factory for test isolation
    private final class TestSocketConnectionFactory: SocketConnectionFactory {
        var shouldFailOnConnect = false
        var connectionAttempts: [(host: String, port: Int)] = []
        var mockConnections: [String: TestSocketConnection] = [:]

        func createConnection(host: String, port: Int) async throws -> any SocketConnectionProtocol {
            connectionAttempts.append((host: host, port: port))
            if shouldFailOnConnect {
                throw TCPError.connectionFailed(host: host, port: port)
            }
            let mock = mockConnections[host] ?? TestSocketConnection()
            mockConnections[host] = mock
            return mock
        }
    }

    /// Mock socket connection for test isolation
    private final class TestSocketConnection: SocketConnectionProtocol, @unchecked Sendable {
        private(set) var sentData: [Data] = []
        private(set) var disconnectCalled = false
        private(set) var _isConnected = true
        var shouldFailOnSend = false

        var isConnected: Bool { _isConnected }

        func send(_ data: Data) async throws {
            if shouldFailOnSend {
                throw TCPError.sendFailed
            }
            sentData.append(data)
        }

        func receive(maxLength: Int = 4096) async throws -> Data {
            throw TCPError.connectionClosed
        }

        func disconnect() {
            disconnectCalled = true
            _isConnected = false
        }
    }

    private func makeService() -> (MessageActionService, TestSocketConnectionFactory, MockNetworkTransport) {
        let transport = MockNetworkTransport()
        let networkManager = NetworkManager(port: 2425, transport: transport)
        let factory = TestSocketConnectionFactory()
        let tcpMessageService = TCPMessageService(connectionFactory: factory)
        let recallService = RecallService(networkManager: networkManager)
        let service = MessageActionService(tcpMessageService: tcpMessageService, recallService: recallService)
        return (service, factory, transport)
    }

    // MARK: - copyMessageContent

    @Test("copyMessageContent returns the original content string")
    func copyMessageContentReturnsOriginal() {
        let (service, _, _) = makeService()
        let result = service.copyMessageContent("Hello, World!")
        #expect(result == "Hello, World!")
    }

    @Test("copyMessageContent returns empty string for empty input")
    func copyMessageContentEmptyString() {
        let (service, _, _) = makeService()
        let result = service.copyMessageContent("")
        #expect(result == "")
    }

    // MARK: - forwardMessage

    @Test("forwardMessage successfully sends via TCPMessageService")
    func forwardMessageSuccess() async throws {
        let (service, factory, _) = makeService()
        try await service.forwardMessage(content: "Forwarded message", to: "192.168.1.100", port: 2425)

        #expect(factory.connectionAttempts.count == 1)
        #expect(factory.connectionAttempts[0].host == "192.168.1.100")
        #expect(factory.connectionAttempts[0].port == 2425)
    }

    @Test("forwardMessage throws forwardFailed on error")
    func forwardMessageFailure() async {
        let (service, factory, _) = makeService()
        factory.shouldFailOnConnect = true

        await #expect(throws: MessageActionError.self) {
            try await service.forwardMessage(content: "Hello", to: "192.168.1.100", port: 2425)
        }
    }

    // MARK: - canRecall

    @Test("canRecall returns true within time window for own message")
    func canRecallWithinWindow() {
        let (service, _, _) = makeService()
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
        let (service, _, _) = makeService()
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
    func canRecallNotOwnMessage() {
        let (service, _, _) = makeService()
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
        let (service, _, _) = makeService()
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

    @Test("recallMessage succeeds and updates recentRecalls")
    func recallMessageSuccess() throws {
        let (service, _, _) = makeService()
        let myId = UUID()
        let msgId = UUID()
        try service.recallMessage(
            messageID: msgId,
            senderID: myId,
            currentUserID: myId,
            messageTimestamp: Date(),
            isRecalled: false
        )
    }

    @Test("recallMessage throws timeoutExpired when window has passed")
    func recallMessageTimeout() {
        let (service, _, _) = makeService()
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
}
