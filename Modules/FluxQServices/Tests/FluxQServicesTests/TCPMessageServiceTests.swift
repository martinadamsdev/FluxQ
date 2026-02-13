//
//  TCPMessageServiceTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/14.
//

import Testing
import Foundation
@testable import FluxQServices
@testable import IPMsgProtocol

// MARK: - Mock SocketConnection

final class MockSocketConnection: @unchecked Sendable {
    private(set) var sentData: [Data] = []
    private(set) var disconnectCalled = false
    private(set) var _isConnected = true
    var shouldFailOnSend = false
    var dataToReceive: Data?

    var isConnected: Bool { _isConnected }

    func send(_ data: Data) async throws {
        if shouldFailOnSend {
            throw TCPError.sendFailed
        }
        sentData.append(data)
    }

    func receive(maxLength: Int = 4096) async throws -> Data {
        guard let data = dataToReceive else {
            throw TCPError.connectionClosed
        }
        return data
    }

    func disconnect() {
        disconnectCalled = true
        _isConnected = false
    }
}

// MARK: - Mock SocketConnectionFactory

@MainActor
final class MockSocketConnectionFactory: SocketConnectionFactory {
    var mockConnections: [String: MockSocketConnection] = [:]
    var connectionAttempts: [(host: String, port: Int)] = []
    var shouldFailOnConnect = false

    func createConnection(host: String, port: Int) async throws -> any SocketConnectionProtocol {
        connectionAttempts.append((host: host, port: port))
        if shouldFailOnConnect {
            throw TCPError.connectionFailed(host: host, port: port)
        }
        let mock = mockConnections[host] ?? MockSocketConnection()
        mockConnections[host] = mock
        return mock
    }
}

// MARK: - MockSocketConnection conformance

extension MockSocketConnection: SocketConnectionProtocol {}

// MARK: - Tests

@MainActor
struct TCPMessageServiceTests {

    // MARK: - Initialization

    @Test func initialState() {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)
        #expect(service.activeConnections == 0)
    }

    // MARK: - Send Message

    @Test func sendMessageCreatesCorrectPacket() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)

        try await service.sendMessage(content: "Hello", to: "192.168.1.100", port: 2425)

        // Verify connection was created to correct host/port
        #expect(factory.connectionAttempts.count == 1)
        #expect(factory.connectionAttempts[0].host == "192.168.1.100")
        #expect(factory.connectionAttempts[0].port == 2425)

        // Verify data was sent
        let mock = factory.mockConnections["192.168.1.100"]!
        #expect(mock.sentData.count == 1)

        // Verify packet format
        let sentString = String(data: mock.sentData[0], encoding: .utf8)!
        let packet = try IPMsgPacket.decode(sentString)
        #expect(packet.command == .SENDMSG)
        #expect(packet.payload == "Hello")
        #expect(packet.version == 1)
    }

    @Test func sendMessageReusesExistingConnection() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)

        try await service.sendMessage(content: "Hello", to: "192.168.1.100", port: 2425)
        try await service.sendMessage(content: "World", to: "192.168.1.100", port: 2425)

        // Only one connection should have been created (reused)
        #expect(factory.connectionAttempts.count == 1)

        let mock = factory.mockConnections["192.168.1.100"]!
        #expect(mock.sentData.count == 2)
    }

    @Test func sendMessageToMultipleRecipients() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)

        try await service.sendMessage(content: "Hello A", to: "192.168.1.100", port: 2425)
        try await service.sendMessage(content: "Hello B", to: "192.168.1.101", port: 2425)

        #expect(factory.connectionAttempts.count == 2)
        #expect(service.activeConnections == 2)
    }

    @Test func sendMessageIncrementsPacketNumber() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)

        try await service.sendMessage(content: "First", to: "192.168.1.100", port: 2425)
        try await service.sendMessage(content: "Second", to: "192.168.1.100", port: 2425)

        let mock = factory.mockConnections["192.168.1.100"]!
        let packet1 = try IPMsgPacket.decode(String(data: mock.sentData[0], encoding: .utf8)!)
        let packet2 = try IPMsgPacket.decode(String(data: mock.sentData[1], encoding: .utf8)!)
        #expect(packet2.packetNo > packet1.packetNo)
    }

    // MARK: - Retry Logic

    @Test func sendMessageRetriesOnFailure() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory, maxRetries: 3, baseRetryDelay: 0.01)

        // First connection will fail on send, second should succeed
        let failingMock = MockSocketConnection()
        failingMock.shouldFailOnSend = true
        factory.mockConnections["192.168.1.100"] = failingMock

        // After first failure, the service reconnects; factory will create a new working connection
        // Override factory to fail first then succeed
        let retryFactory = RetryMockSocketConnectionFactory()
        retryFactory.failCount = 2
        let retryService = TCPMessageService(connectionFactory: retryFactory, maxRetries: 3, baseRetryDelay: 0.01)

        try await retryService.sendMessage(content: "Hello", to: "192.168.1.100", port: 2425)
        #expect(retryFactory.connectionAttempts.count == 3) // 2 failures + 1 success
    }

    @Test func sendMessageThrowsAfterMaxRetries() async throws {
        let factory = MockSocketConnectionFactory()
        factory.shouldFailOnConnect = true
        let service = TCPMessageService(connectionFactory: factory, maxRetries: 3, baseRetryDelay: 0.01)

        await #expect(throws: TCPMessageServiceError.self) {
            try await service.sendMessage(content: "Hello", to: "192.168.1.100", port: 2425)
        }
    }

    // MARK: - Connection Pool

    @Test func disconnectRemovesConnection() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)

        try await service.sendMessage(content: "Hello", to: "192.168.1.100", port: 2425)
        #expect(service.activeConnections == 1)

        service.disconnect(from: "192.168.1.100")
        #expect(service.activeConnections == 0)
    }

    @Test func disconnectAllClearsPool() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)

        try await service.sendMessage(content: "A", to: "192.168.1.100", port: 2425)
        try await service.sendMessage(content: "B", to: "192.168.1.101", port: 2425)
        #expect(service.activeConnections == 2)

        service.disconnectAll()
        #expect(service.activeConnections == 0)
    }

    @Test func disconnectCallsSocketDisconnect() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)

        try await service.sendMessage(content: "Hello", to: "192.168.1.100", port: 2425)
        let mock = factory.mockConnections["192.168.1.100"]!

        service.disconnect(from: "192.168.1.100")
        #expect(mock.disconnectCalled)
    }

    // MARK: - Reconnection on stale connection

    @Test func sendMessageReconnectsIfDisconnected() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)

        try await service.sendMessage(content: "Hello", to: "192.168.1.100", port: 2425)

        // Simulate the connection becoming stale
        let mock = factory.mockConnections["192.168.1.100"]!
        mock.disconnect()

        // Next send should create a new connection
        try await service.sendMessage(content: "World", to: "192.168.1.100", port: 2425)
        #expect(factory.connectionAttempts.count == 2)
    }

    // MARK: - Callback

    @Test func onMessageReceivedCallbackIsCalled() async throws {
        let factory = MockSocketConnectionFactory()
        let service = TCPMessageService(connectionFactory: factory)

        var receivedPacket: IPMsgPacket?
        service.onMessageReceived = { packet in
            receivedPacket = packet
        }

        let packet = IPMsgPacket(
            version: 1, packetNo: 1, sender: "TestUser",
            hostname: "testhost", command: .SENDMSG, payload: "Hello!"
        )
        service.handleIncomingPacket(packet)

        #expect(receivedPacket != nil)
        #expect(receivedPacket?.payload == "Hello!")
        #expect(receivedPacket?.command == .SENDMSG)
    }
}

// MARK: - RetryMockSocketConnectionFactory

/// Factory that fails the first N connection attempts
@MainActor
final class RetryMockSocketConnectionFactory: SocketConnectionFactory {
    var failCount: Int = 0
    var connectionAttempts: [(host: String, port: Int)] = []
    private var attemptCount = 0

    func createConnection(host: String, port: Int) async throws -> any SocketConnectionProtocol {
        connectionAttempts.append((host: host, port: port))
        attemptCount += 1
        if attemptCount <= failCount {
            throw TCPError.connectionFailed(host: host, port: port)
        }
        return MockSocketConnection()
    }
}
