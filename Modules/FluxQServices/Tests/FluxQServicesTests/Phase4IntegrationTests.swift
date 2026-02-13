//
//  Phase4IntegrationTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/14.
//

import Testing
import Foundation
@testable import FluxQServices
@testable import IPMsgProtocol

// MARK: - Integration Test Mocks

final class IntegrationTestSocketConnection: @unchecked Sendable {
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

extension IntegrationTestSocketConnection: SocketConnectionProtocol {}

@MainActor
final class IntegrationTestSocketFactory: SocketConnectionFactory {
    var mockConnections: [String: IntegrationTestSocketConnection] = [:]
    var connectionAttempts: [(host: String, port: Int)] = []
    var shouldFailOnConnect = false

    func createConnection(host: String, port: Int) async throws -> any SocketConnectionProtocol {
        connectionAttempts.append((host: host, port: port))
        if shouldFailOnConnect {
            throw TCPError.connectionFailed(host: host, port: port)
        }
        let mock = mockConnections[host] ?? IntegrationTestSocketConnection()
        mockConnections[host] = mock
        return mock
    }
}

// MARK: - Phase4IntegrationTests

@MainActor
struct Phase4IntegrationTests {

    // MARK: - Helpers

    private func makeServices() -> (
        tcpMessageService: TCPMessageService,
        recallService: RecallService,
        typingStateService: TypingStateService,
        messageActionService: MessageActionService,
        transport: MockNetworkTransport,
        socketFactory: IntegrationTestSocketFactory
    ) {
        let transport = MockNetworkTransport()
        let networkManager = NetworkManager(port: 2425, transport: transport)
        let socketFactory = IntegrationTestSocketFactory()
        let tcpService = TCPMessageService(connectionFactory: socketFactory, maxRetries: 1, baseRetryDelay: 0.01)
        let recallService = RecallService(networkManager: networkManager)
        let typingService = TypingStateService(networkManager: networkManager)
        let actionService = MessageActionService(tcpMessageService: tcpService, recallService: recallService)
        return (tcpService, recallService, typingService, actionService, transport, socketFactory)
    }

    // MARK: - 1. MessageActionService + RecallService Integration

    @Test("MessageActionService.recallMessage updates RecallService.recentRecalls")
    func messageActionRecallUpdatesRecallService() throws {
        let (_, recallService, _, actionService, _, _) = makeServices()

        let messageID = UUID()
        let userID = UUID()
        let timestamp = Date()

        try actionService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: timestamp,
            isRecalled: false
        )

        #expect(recallService.recentRecalls[messageID] != nil)
        #expect(recallService.isMessageRecalled(messageID))
    }

    @Test("MessageActionService.canRecall matches RecallService.canRecall")
    func messageActionCanRecallConsistentWithRecallService() {
        let (_, recallService, _, actionService, _, _) = makeServices()

        let userID = UUID()
        let timestamp = Date()

        let actionResult = actionService.canRecall(
            messageTimestamp: timestamp,
            senderID: userID,
            currentUserID: userID,
            isRecalled: false
        )
        let recallResult = recallService.canRecall(
            messageTimestamp: timestamp,
            senderID: userID,
            currentUserID: userID,
            isRecalled: false
        )

        #expect(actionResult == recallResult)
        #expect(actionResult == true)
    }

    @Test("MessageActionService.canRecall returns false for already recalled messages")
    func canRecallReturnsFalseForRecalled() {
        let (_, _, _, actionService, _, _) = makeServices()

        let userID = UUID()
        let result = actionService.canRecall(
            messageTimestamp: Date(),
            senderID: userID,
            currentUserID: userID,
            isRecalled: true
        )

        #expect(result == false)
    }

    // MARK: - 2. Multiple Services Sharing NetworkManager

    @Test("RecallService and TypingStateService share NetworkManager and both record broadcasts")
    func sharedNetworkManagerBroadcasts() throws {
        let (_, recallService, typingService, _, transport, _) = makeServices()

        let messageID = UUID()
        let userID = UUID()

        // RecallService sends a RECALLMSG broadcast
        try recallService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: Date(),
            isRecalled: false
        )
        let afterRecall = transport.broadcastMessages.count
        #expect(afterRecall >= 1)

        // TypingStateService sends a TYPING broadcast
        let targetUser = UUID()
        try typingService.startTyping(to: targetUser)
        let afterTyping = transport.broadcastMessages.count
        #expect(afterTyping > afterRecall)

        // Verify both broadcasts were captured on the same transport
        #expect(transport.broadcastMessages.count >= 2)
    }

    @Test("Both services broadcasts contain correct IPMsg packets")
    func sharedNetworkManagerPacketContent() throws {
        let (_, recallService, typingService, _, transport, _) = makeServices()

        let messageID = UUID()
        let userID = UUID()

        try recallService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: Date(),
            isRecalled: false
        )

        let targetUser = UUID()
        try typingService.startTyping(to: targetUser)

        // Parse broadcast packets to verify command types
        var foundRecall = false
        var foundTyping = false
        for msg in transport.broadcastMessages {
            if let str = String(data: msg.data, encoding: .utf8),
               let packet = try? IPMsgPacket.decode(str) {
                if packet.command == .RECALLMSG { foundRecall = true }
                if packet.command == .TYPING { foundTyping = true }
            }
        }

        #expect(foundRecall)
        #expect(foundTyping)
    }

    // MARK: - 3. TypingStateService Full Lifecycle

    @Test("Remote user typing lifecycle: start -> isTyping true -> stop -> isTyping false")
    func typingStateFullLifecycle() {
        let (_, _, typingService, _, _, _) = makeServices()

        let remoteUser = UUID()

        // Initially not typing
        #expect(typingService.isUserTyping(remoteUser) == false)

        // Remote user starts typing
        typingService.handleTypingCommand(from: remoteUser)
        #expect(typingService.isUserTyping(remoteUser) == true)
        #expect(typingService.typingUsers[remoteUser] != nil)

        // Remote user stops typing
        typingService.handleStopTypingCommand(from: remoteUser)
        #expect(typingService.isUserTyping(remoteUser) == false)
        #expect(typingService.typingUsers[remoteUser] == nil)
    }

    @Test("Expired typing states are cleaned up after timeout")
    func typingStateExpiryCleanup() async throws {
        let transport = MockNetworkTransport()
        let networkManager = NetworkManager(port: 2425, transport: transport)
        let typingService = TypingStateService(networkManager: networkManager)
        // Use a very short timeout so we can actually wait for expiry
        typingService.typingTimeout = 0.05

        let remoteUser = UUID()

        typingService.handleTypingCommand(from: remoteUser)
        #expect(typingService.isUserTyping(remoteUser) == true)

        // Wait for the typing timeout to expire
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s > 0.05s timeout

        // isUserTyping should return false for expired entry
        #expect(typingService.isUserTyping(remoteUser) == false)

        // Cleanup should remove the entry from the dictionary
        typingService.cleanupExpiredTypingStates()
        #expect(typingService.typingUsers[remoteUser] == nil)
    }

    @Test("Multiple remote users typing simultaneously")
    func multipleUsersTyping() {
        let (_, _, typingService, _, _, _) = makeServices()

        let user1 = UUID()
        let user2 = UUID()
        let user3 = UUID()

        typingService.handleTypingCommand(from: user1)
        typingService.handleTypingCommand(from: user2)
        typingService.handleTypingCommand(from: user3)

        #expect(typingService.isUserTyping(user1) == true)
        #expect(typingService.isUserTyping(user2) == true)
        #expect(typingService.isUserTyping(user3) == true)

        // Only user2 stops
        typingService.handleStopTypingCommand(from: user2)
        #expect(typingService.isUserTyping(user1) == true)
        #expect(typingService.isUserTyping(user2) == false)
        #expect(typingService.isUserTyping(user3) == true)
    }

    // MARK: - 4. RecallService Full Lifecycle

    @Test("Recall flow: recall -> isRecalled true -> cleanup expired")
    func recallFullLifecycle() throws {
        let (_, recallService, _, _, _, _) = makeServices()

        let messageID = UUID()
        let userID = UUID()

        try recallService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: Date(),
            isRecalled: false
        )

        #expect(recallService.isMessageRecalled(messageID))

        // Simulate expired record (set recall date to 25 hours ago)
        recallService.recentRecalls[messageID] = Date().addingTimeInterval(-90000)
        recallService.cleanupExpiredRecalls()

        #expect(recallService.isMessageRecalled(messageID) == false)
        #expect(recallService.recentRecalls.isEmpty)
    }

    @Test("Recall timeout throws timeoutExpired")
    func recallTimeoutThrowsError() {
        let (_, recallService, _, _, _, _) = makeServices()

        let messageID = UUID()
        let userID = UUID()
        let oldTimestamp = Date().addingTimeInterval(-(recallService.recallWindow + 1))

        #expect(throws: RecallError.timeoutExpired) {
            try recallService.recallMessage(
                messageID: messageID,
                senderID: userID,
                currentUserID: userID,
                messageTimestamp: oldTimestamp,
                isRecalled: false
            )
        }
    }

    @Test("Remote recall command marks message as recalled")
    func remoteRecallCommandHandling() {
        let (_, recallService, _, _, _, _) = makeServices()

        let messageID = UUID()
        let senderID = UUID()

        #expect(recallService.isMessageRecalled(messageID) == false)

        recallService.handleRecallCommand(messageID: messageID, from: senderID)

        #expect(recallService.isMessageRecalled(messageID) == true)
        #expect(recallService.recentRecalls[messageID] != nil)
    }

    @Test("Recall not authorized for different user throws notAuthorized")
    func recallNotAuthorizedThrows() {
        let (_, recallService, _, _, _, _) = makeServices()

        let messageID = UUID()
        let senderID = UUID()
        let differentUser = UUID()

        #expect(throws: RecallError.notAuthorized) {
            try recallService.recallMessage(
                messageID: messageID,
                senderID: senderID,
                currentUserID: differentUser,
                messageTimestamp: Date(),
                isRecalled: false
            )
        }
    }

    @Test("Already recalled message throws alreadyRecalled")
    func alreadyRecalledThrows() {
        let (_, recallService, _, _, _, _) = makeServices()

        let messageID = UUID()
        let userID = UUID()

        #expect(throws: RecallError.alreadyRecalled) {
            try recallService.recallMessage(
                messageID: messageID,
                senderID: userID,
                currentUserID: userID,
                messageTimestamp: Date(),
                isRecalled: true
            )
        }
    }

    // MARK: - 5. MessageActionService Forward Flow

    @Test("forwardMessage sends to the specified address via TCP")
    func forwardMessageSuccess() async throws {
        let (_, _, _, actionService, _, socketFactory) = makeServices()

        try await actionService.forwardMessage(content: "Forwarded msg", to: "192.168.1.50", port: 2425)

        #expect(socketFactory.connectionAttempts.count == 1)
        #expect(socketFactory.connectionAttempts[0].host == "192.168.1.50")
        #expect(socketFactory.connectionAttempts[0].port == 2425)

        let mock = socketFactory.mockConnections["192.168.1.50"]!
        #expect(mock.sentData.count == 1)

        let sentString = String(data: mock.sentData[0], encoding: .utf8)!
        let packet = try IPMsgPacket.decode(sentString)
        #expect(packet.command == .SENDMSG)
        #expect(packet.payload == "Forwarded msg")
    }

    @Test("forwardMessage throws forwardFailed when connection fails")
    func forwardMessageFailure() async {
        let (_, _, _, actionService, _, socketFactory) = makeServices()
        socketFactory.shouldFailOnConnect = true

        await #expect(throws: MessageActionError.self) {
            try await actionService.forwardMessage(content: "Test", to: "192.168.1.99", port: 2425)
        }
    }

    // MARK: - 6. Copy + Recall Combination

    @Test("Copy returns content and does not affect recall state")
    func copyDoesNotAffectRecall() throws {
        let (_, recallService, _, actionService, _, _) = makeServices()

        let messageID = UUID()
        let userID = UUID()

        let copied = actionService.copyMessageContent("Hello World")
        #expect(copied == "Hello World")

        // Recall state is unaffected by copy
        #expect(recallService.isMessageRecalled(messageID) == false)

        // Recall still works after copy
        try actionService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: Date(),
            isRecalled: false
        )
        #expect(recallService.isMessageRecalled(messageID) == true)
    }

    @Test("After recall, canRecall returns false for isRecalled=true")
    func canRecallFalseAfterRecall() throws {
        let (_, _, _, actionService, _, _) = makeServices()

        let messageID = UUID()
        let userID = UUID()
        let timestamp = Date()

        // Before recall
        #expect(actionService.canRecall(messageTimestamp: timestamp, senderID: userID, currentUserID: userID, isRecalled: false) == true)

        // Perform recall
        try actionService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: timestamp,
            isRecalled: false
        )

        // After recall (isRecalled flag is now true)
        #expect(actionService.canRecall(messageTimestamp: timestamp, senderID: userID, currentUserID: userID, isRecalled: true) == false)
    }

    // MARK: - 7. TCPMessageService Connection Pool + RecallService

    @Test("TCP send creates connection; recall uses UDP broadcast not TCP")
    func tcpConnectionPoolAndUdpRecall() async throws {
        let (tcpService, recallService, _, _, transport, socketFactory) = makeServices()

        // Send via TCP
        try await tcpService.sendMessage(content: "Hello", to: "192.168.1.100", port: 2425)
        #expect(tcpService.activeConnections == 1)
        #expect(socketFactory.connectionAttempts.count == 1)

        let broadcastCountBefore = transport.broadcastMessages.count

        // Recall via UDP (through RecallService)
        let messageID = UUID()
        let userID = UUID()
        try recallService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: Date(),
            isRecalled: false
        )

        // Recall used broadcast (UDP), not TCP
        #expect(transport.broadcastMessages.count == broadcastCountBefore + 1)
        // TCP connection count unchanged (recall doesn't create TCP connections)
        #expect(socketFactory.connectionAttempts.count == 1)
    }

    @Test("Multiple TCP sends reuse connection; recall is independent")
    func tcpReuseAndRecallIndependence() async throws {
        let (tcpService, recallService, _, _, transport, socketFactory) = makeServices()

        // Multiple TCP sends to same host
        try await tcpService.sendMessage(content: "Msg 1", to: "192.168.1.100", port: 2425)
        try await tcpService.sendMessage(content: "Msg 2", to: "192.168.1.100", port: 2425)
        #expect(socketFactory.connectionAttempts.count == 1) // Reused
        #expect(tcpService.activeConnections == 1)

        let mock = socketFactory.mockConnections["192.168.1.100"]!
        #expect(mock.sentData.count == 2)

        // Recall is completely separate from TCP
        let messageID = UUID()
        let userID = UUID()
        try recallService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: Date(),
            isRecalled: false
        )

        // TCP state unchanged
        #expect(tcpService.activeConnections == 1)
        #expect(mock.sentData.count == 2) // No additional TCP data

        // Recall went through UDP broadcast
        let lastBroadcast = transport.broadcastMessages.last!
        let packetStr = String(data: lastBroadcast.data, encoding: .utf8)!
        let packet = try IPMsgPacket.decode(packetStr)
        #expect(packet.command == .RECALLMSG)
        #expect(packet.payload == messageID.uuidString)
    }

    // MARK: - 8. Typing Debounce with Shared NetworkManager

    @Test("Typing debounce prevents duplicate broadcasts within interval")
    func typingDebounce() throws {
        let (_, _, typingService, _, transport, _) = makeServices()

        let targetUser = UUID()

        // First call sends broadcast
        try typingService.startTyping(to: targetUser)
        let countAfterFirst = transport.broadcastMessages.count

        // Second call within debounce interval should be skipped
        try typingService.startTyping(to: targetUser)
        let countAfterSecond = transport.broadcastMessages.count

        #expect(countAfterSecond == countAfterFirst)
    }

    @Test("Stop typing then start typing sends new broadcast")
    func stopThenStartTypingSendsBroadcast() throws {
        let (_, _, typingService, _, transport, _) = makeServices()

        let targetUser = UUID()

        try typingService.startTyping(to: targetUser)
        let countAfterStart = transport.broadcastMessages.count

        try typingService.stopTyping(to: targetUser)
        let countAfterStop = transport.broadcastMessages.count
        #expect(countAfterStop == countAfterStart + 1) // STOPTYPING broadcast

        // After stopTyping clears debounce state, startTyping should send again
        try typingService.startTyping(to: targetUser)
        let countAfterRestart = transport.broadcastMessages.count
        #expect(countAfterRestart == countAfterStop + 1) // New TYPING broadcast
    }
}
