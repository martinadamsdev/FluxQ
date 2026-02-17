//
//  MessageActionIntegrationTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/17.
//

import Testing
import Foundation
@testable import FluxQServices
@testable import IPMsgProtocol

@Suite("Message Action Integration Tests")
@MainActor
struct MessageActionIntegrationTests {

    // MARK: - Helpers

    private func makeManager() -> (NetworkManager, MockNetworkTransport) {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        return (manager, transport)
    }

    private func cleanPayload(_ payload: String) -> String {
        String(payload.split(separator: "\0", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    // MARK: - Recall Broadcast Tests

    @Test("Recall broadcast sends RECALLMSG command")
    func recallSendsBroadcast() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        let messageID = UUID()
        try manager.sendBroadcast(command: .RECALLMSG, payload: messageID.uuidString)

        // BR_ENTRY from start() + RECALLMSG = 2 broadcasts
        #expect(transport.broadcastMessages.count == 2)
        let lastBroadcast = transport.broadcastMessages.last!
        let packetStr = String(data: lastBroadcast.data, encoding: .utf8)!
        let packet = try IPMsgPacket.decode(packetStr)
        #expect(packet.command == .RECALLMSG)
        #expect(cleanPayload(packet.payload) == messageID.uuidString)
    }

    // MARK: - Receive Recall Tests

    @Test("Received RECALLMSG updates receivedRecalls")
    func receiveRecallCommand() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        let messageID = UUID()
        let packet = IPMsgPacket(
            version: 1, packetNo: 300,
            sender: "alice", hostname: "alice-mac",
            command: .RECALLMSG, payload: messageID.uuidString
        )
        let data = packet.encode().data(using: .utf8)!
        transport.simulateReceive(data: data, from: "192.168.1.10")

        #expect(manager.receivedRecalls.count == 1)
        #expect(manager.receivedRecalls[0] == messageID.uuidString)
    }

    @Test("Multiple RECALLMSG commands all tracked")
    func receiveMultipleRecalls() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        for i in 0..<3 {
            let msgID = UUID()
            let packet = IPMsgPacket(
                version: 1, packetNo: 400 + i,
                sender: "alice", hostname: "alice-mac",
                command: .RECALLMSG, payload: msgID.uuidString
            )
            let data = packet.encode().data(using: .utf8)!
            transport.simulateReceive(data: data, from: "192.168.1.10")
        }

        #expect(manager.receivedRecalls.count == 3)
    }

    // MARK: - RecallService Time Window Tests

    @Test("RecallService validates time window - within window")
    func recallTimeWindowWithin() {
        let (manager, _) = makeManager()
        let recallService = RecallService(networkManager: manager)

        let userID = UUID()
        let recentTimestamp = Date().addingTimeInterval(-60)

        #expect(recallService.canRecall(
            messageTimestamp: recentTimestamp,
            senderID: userID, currentUserID: userID, isRecalled: false
        ))
    }

    @Test("RecallService validates time window - outside window")
    func recallTimeWindowOutside() {
        let (manager, _) = makeManager()
        let recallService = RecallService(networkManager: manager)

        let userID = UUID()
        let oldTimestamp = Date().addingTimeInterval(-200)

        #expect(!recallService.canRecall(
            messageTimestamp: oldTimestamp,
            senderID: userID, currentUserID: userID, isRecalled: false
        ))
    }

    // MARK: - End-to-End Recall Flow

    @Test("RecallService.recallMessage sends broadcast and NetworkManager receives it")
    func recallEndToEnd() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        let recallService = RecallService(networkManager: manager)
        let userID = UUID()
        let messageID = UUID()

        // Send recall
        try recallService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: Date(),
            isRecalled: false
        )

        // Verify broadcast was sent
        let recallBroadcasts = try transport.broadcastMessages.filter { msg in
            let str = String(data: msg.data, encoding: .utf8)!
            let pkt = try IPMsgPacket.decode(str)
            return pkt.command == .RECALLMSG
        }
        #expect(recallBroadcasts.count == 1)

        // Verify RecallService tracked it
        #expect(recallService.isMessageRecalled(messageID))
    }

    @Test("Recall then receive same recall from remote - both tracked")
    func recallLocalAndRemote() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        let recallService = RecallService(networkManager: manager)
        let userID = UUID()
        let messageID = UUID()

        // Local recall
        try recallService.recallMessage(
            messageID: messageID,
            senderID: userID,
            currentUserID: userID,
            messageTimestamp: Date(),
            isRecalled: false
        )

        // Simulate remote recall of same message
        let packet = IPMsgPacket(
            version: 1, packetNo: 500,
            sender: "bob", hostname: "bob-mac",
            command: .RECALLMSG, payload: messageID.uuidString
        )
        let data = packet.encode().data(using: .utf8)!
        transport.simulateReceive(data: data, from: "192.168.1.20")

        // NetworkManager should have received the remote recall
        #expect(manager.receivedRecalls.count == 1)
        // RecallService should still track it
        #expect(recallService.isMessageRecalled(messageID))
    }
}
