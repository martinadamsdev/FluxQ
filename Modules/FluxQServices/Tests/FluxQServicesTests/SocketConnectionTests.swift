//
//  SocketConnectionTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/14.
//

import Testing
import Foundation
@testable import FluxQServices

@Suite(.serialized)
struct SocketConnectionTests {

    // MARK: - Connection Tests

    @Test func connectToServer() async throws {
        let server = MockTCPServer(port: 12345)
        try await server.start()

        let acceptTask = Task {
            try await server.acceptConnection()
        }

        let connection = try await SocketConnection(host: "127.0.0.1", port: 12345)
        #expect(connection.isConnected)

        try await acceptTask.value

        connection.disconnect()
        await server.stop()
    }

    @Test func connectToInvalidPort() async {
        // 连接到本地一个没有监听的端口，应该立即被拒绝
        do {
            _ = try await SocketConnection(host: "127.0.0.1", port: 19999)
            Issue.record("Should have thrown connectionFailed")
        } catch let error as TCPError {
            guard case .connectionFailed = error else {
                Issue.record("Expected connectionFailed, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected TCPError, got \(error)")
        }
    }

    // MARK: - Send Tests

    @Test func sendData() async throws {
        let server = MockTCPServer(port: 12345)
        try await server.start()

        let acceptTask = Task {
            try await server.acceptConnection()
        }

        let connection = try await SocketConnection(host: "127.0.0.1", port: 12345)
        try await acceptTask.value

        let message = "Hello, TCP!"
        let data = Data(message.utf8)
        try await connection.send(data)

        let received = try await server.readData()
        #expect(received == data)

        connection.disconnect()
        await server.stop()
    }

    @Test func sendStringData() async throws {
        let server = MockTCPServer(port: 12345)
        try await server.start()

        let acceptTask = Task {
            try await server.acceptConnection()
        }

        let connection = try await SocketConnection(host: "127.0.0.1", port: 12345)
        try await acceptTask.value

        let testMessage = "1:100:user:host:32:Hello World"
        try await connection.send(Data(testMessage.utf8))

        let received = try await server.readData()
        let receivedString = String(data: received, encoding: .utf8)
        #expect(receivedString == testMessage)

        connection.disconnect()
        await server.stop()
    }

    // MARK: - Receive Tests

    @Test func receiveData() async throws {
        let server = MockTCPServer(port: 12345)
        try await server.start()

        let acceptTask = Task {
            try await server.acceptConnection()
        }

        let connection = try await SocketConnection(host: "127.0.0.1", port: 12345)
        try await acceptTask.value

        let message = "Response from server"
        let sendTask = Task {
            try await Task.sleep(for: .milliseconds(50))
            try await server.sendData(Data(message.utf8))
        }

        let received = try await connection.receive(maxLength: 4096)
        try await sendTask.value

        let receivedString = String(data: received, encoding: .utf8)
        #expect(receivedString == message)

        connection.disconnect()
        await server.stop()
    }

    // MARK: - Disconnect Tests

    @Test func disconnectSetsIsConnectedFalse() async throws {
        let server = MockTCPServer(port: 12345)
        try await server.start()

        let acceptTask = Task {
            try await server.acceptConnection()
        }

        let connection = try await SocketConnection(host: "127.0.0.1", port: 12345)
        try await acceptTask.value

        #expect(connection.isConnected)

        connection.disconnect()
        #expect(!connection.isConnected)

        await server.stop()
    }

    @Test func sendAfterDisconnectThrows() async throws {
        let server = MockTCPServer(port: 12345)
        try await server.start()

        let acceptTask = Task {
            try await server.acceptConnection()
        }

        let connection = try await SocketConnection(host: "127.0.0.1", port: 12345)
        try await acceptTask.value

        connection.disconnect()

        do {
            try await connection.send(Data("test".utf8))
            Issue.record("Should have thrown connectionClosed")
        } catch let error as TCPError {
            #expect(error == .connectionClosed)
        }

        await server.stop()
    }

    // MARK: - TCPError Tests

    @Test func tcpErrorEquality() {
        #expect(TCPError.socketCreationFailed == TCPError.socketCreationFailed)
        #expect(TCPError.connectionClosed == TCPError.connectionClosed)
        #expect(TCPError.sendFailed == TCPError.sendFailed)
        #expect(TCPError.receiveFailed == TCPError.receiveFailed)
        #expect(
            TCPError.connectionFailed(host: "a", port: 1)
            == TCPError.connectionFailed(host: "a", port: 1)
        )
        #expect(
            TCPError.connectionFailed(host: "a", port: 1)
            != TCPError.connectionFailed(host: "b", port: 2)
        )
    }
}
