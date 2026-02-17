//
//  MessageSendIntegrationTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/17.
//

import Testing
import Foundation
@testable import FluxQServices
@testable import IPMsgProtocol

@Suite("Message Send Integration Tests")
@MainActor
struct MessageSendIntegrationTests {

    // MARK: - Helpers

    private func makeManager(port: UInt16 = 2425) -> (NetworkManager, MockNetworkTransport) {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: port, transport: transport)
        return (manager, transport)
    }

    private func cleanPayload(_ payload: String) -> String {
        String(payload.split(separator: "\0", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    // MARK: - Send Tests

    @Test("sendMessage sends SENDMSG packet to correct host")
    func sendMessageToUser() async throws {
        let (manager, transport) = makeManager()
        try manager.start()

        let user = DiscoveredUser(
            senderName: "alice",
            nickname: "Alice",
            hostname: "alice-mac",
            ipAddress: "192.168.1.10",
            port: 2425
        )

        try await manager.sendMessage(to: user, message: "Hello!")

        #expect(transport.sentMessages.count == 1)
        let sent = transport.sentMessages[0]
        #expect(sent.host == "192.168.1.10")
        #expect(sent.port == 2425)

        // Decode the sent packet and verify content
        let packetStr = String(data: sent.data, encoding: .utf8)!
        let packet = try IPMsgPacket.decode(packetStr)
        #expect(packet.command == .SENDMSG)
        #expect(cleanPayload(packet.payload) == "Hello!")
    }

    // MARK: - Receive Tests

    @Test("Received SENDMSG updates receivedMessages array")
    func receiveMessageUpdatesArray() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        // Simulate receiving a SENDMSG packet
        let packet = IPMsgPacket(
            version: 1, packetNo: 100,
            sender: "bob", hostname: "bob-mac",
            command: .SENDMSG, payload: "Hi there!"
        )
        let data = packet.encode().data(using: .utf8)!
        transport.simulateReceive(data: data, from: "192.168.1.20")

        #expect(manager.receivedMessages.count == 1)
        #expect(manager.receivedMessages[0].content == "Hi there!")
        #expect(manager.receivedMessages[0].senderName == "bob")
        #expect(manager.receivedMessages[0].hostname == "bob-mac")
        #expect(manager.receivedMessages[0].fromHost == "192.168.1.20")
        #expect(manager.receivedMessages[0].packetNo == 100)
    }

    @Test("Received SENDMSG triggers RECVMSG confirmation")
    func receiveMessageSendsConfirmation() async throws {
        let (manager, transport) = makeManager()
        try manager.start()
        let initialSent = transport.sentMessages.count

        let packet = IPMsgPacket(
            version: 1, packetNo: 200,
            sender: "bob", hostname: "bob-mac",
            command: .SENDMSG, payload: "Test"
        )
        let data = packet.encode().data(using: .utf8)!
        transport.simulateReceive(data: data, from: "192.168.1.20")

        // Give async Task time to execute
        try await Task.sleep(nanoseconds: 100_000_000)

        // Should have sent RECVMSG confirmation
        let confirmations = transport.sentMessages[initialSent...].filter { msg in
            guard let str = String(data: msg.data, encoding: .utf8),
                  let pkt = try? IPMsgPacket.decode(str) else { return false }
            return pkt.command == .RECVMSG
        }
        #expect(confirmations.count == 1)

        // Verify RECVMSG references the original packetNo
        let confirmData = confirmations[0].data
        let confirmPacket = try IPMsgPacket.decode(String(data: confirmData, encoding: .utf8)!)
        #expect(cleanPayload(confirmPacket.payload) == "200")

        // Verify sent to correct host
        #expect(confirmations[0].host == "192.168.1.20")
    }

    @Test("Multiple messages received in sequence all tracked")
    func multipleMessagesReceived() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        for i in 0..<5 {
            let packet = IPMsgPacket(
                version: 1, packetNo: 500 + i,
                sender: "user\(i)", hostname: "host\(i)",
                command: .SENDMSG, payload: "Message \(i)"
            )
            let data = packet.encode().data(using: .utf8)!
            transport.simulateReceive(data: data, from: "192.168.1.\(10 + i)")
        }

        #expect(manager.receivedMessages.count == 5)
        for i in 0..<5 {
            #expect(manager.receivedMessages[i].content == "Message \(i)")
            #expect(manager.receivedMessages[i].senderName == "user\(i)")
            #expect(manager.receivedMessages[i].fromHost == "192.168.1.\(10 + i)")
        }
    }

    @Test("Send and receive round-trip: send message then receive reply")
    func sendReceiveRoundTrip() async throws {
        let (manager, transport) = makeManager()
        try manager.start()

        // Step 1: Send message to alice
        let alice = DiscoveredUser(
            senderName: "alice", nickname: "Alice",
            hostname: "alice-mac", ipAddress: "192.168.1.10", port: 2425
        )
        try await manager.sendMessage(to: alice, message: "Hello Alice!")

        // Step 2: Alice replies
        let replyPacket = IPMsgPacket(
            version: 1, packetNo: 999,
            sender: "alice", hostname: "alice-mac",
            command: .SENDMSG, payload: "Hello back!"
        )
        let replyData = replyPacket.encode().data(using: .utf8)!
        transport.simulateReceive(data: replyData, from: "192.168.1.10")

        // Verify outgoing
        #expect(transport.sentMessages.count >= 1)
        let sentPacket = try IPMsgPacket.decode(
            String(data: transport.sentMessages[0].data, encoding: .utf8)!)
        #expect(sentPacket.command == .SENDMSG)
        #expect(cleanPayload(sentPacket.payload) == "Hello Alice!")

        // Verify incoming
        #expect(manager.receivedMessages.count == 1)
        #expect(manager.receivedMessages[0].content == "Hello back!")
        #expect(manager.receivedMessages[0].senderName == "alice")
    }
}
