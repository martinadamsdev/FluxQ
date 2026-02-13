//
//  NetworkManagerFullTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/14.
//

import Testing
import Foundation
@testable import FluxQServices
@testable import IPMsgProtocol

@MainActor
struct NetworkManagerFullTests {

    // MARK: - Helpers

    private func makeManager(port: UInt16 = 2425) -> (NetworkManager, MockNetworkTransport) {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: port, transport: transport)
        return (manager, transport)
    }

    private func makeBREntryData(sender: String = "alice", hostname: String = "alice-mac") -> Data {
        let packet = IPMsgPacket(
            version: 1, packetNo: 100, sender: sender,
            hostname: hostname, command: .BR_ENTRY, payload: ""
        )
        return packet.encode().data(using: .utf8)!
    }

    private func makeANSEntryData(sender: String = "bob", hostname: String = "bob-mac") -> Data {
        let packet = IPMsgPacket(
            version: 1, packetNo: 200, sender: sender,
            hostname: hostname, command: .ANSENTRY, payload: ""
        )
        return packet.encode().data(using: .utf8)!
    }

    private func makeBRExitData(sender: String = "alice", hostname: String = "alice-mac") -> Data {
        let packet = IPMsgPacket(
            version: 1, packetNo: 300, sender: sender,
            hostname: hostname, command: .BR_EXIT, payload: ""
        )
        return packet.encode().data(using: .utf8)!
    }

    private func makeSendMsgData(sender: String = "charlie", payload: String = "Hello!") -> Data {
        let packet = IPMsgPacket(
            version: 1, packetNo: 400, sender: sender,
            hostname: "charlie-mac", command: .SENDMSG, payload: payload
        )
        return packet.encode().data(using: .utf8)!
    }

    // MARK: - Lifecycle Tests

    @Test("start() 启动监听器并发送 BR_ENTRY 广播")
    func startListensAndBroadcasts() throws {
        let (manager, transport) = makeManager()

        try manager.start()

        #expect(transport.isListening)
        #expect(transport.listeningPort == 2425)
        #expect(transport.broadcastMessages.count == 1)

        // 验证发送的是 BR_ENTRY 命令
        let sentData = transport.broadcastMessages[0].data
        let decoded = try IPMsgPacket.decode(String(data: sentData, encoding: .utf8)!)
        #expect(decoded.command == .BR_ENTRY)
    }

    @Test("start() 使用自定义端口")
    func startWithCustomPort() throws {
        let (manager, transport) = makeManager(port: 3000)

        try manager.start()

        #expect(transport.listeningPort == 3000)
        #expect(transport.broadcastMessages[0].port == 3000)
    }

    @Test("stop() 发送 BR_EXIT 并停止监听器")
    func stopSendsExitAndStopsListening() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        manager.stop()

        #expect(!transport.isListening)
        // 应该有 2 条广播: BR_ENTRY + BR_EXIT
        #expect(transport.broadcastMessages.count == 2)

        let exitData = transport.broadcastMessages[1].data
        let decoded = try IPMsgPacket.decode(String(data: exitData, encoding: .utf8)!)
        #expect(decoded.command == .BR_EXIT)
    }

    @Test("stop() 清空 discoveredUsers")
    func stopClearsDiscoveredUsers() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        // 模拟发现一个用户
        transport.simulateReceive(data: makeBREntryData(), from: "192.168.1.10")
        #expect(!manager.discoveredUsers.isEmpty)

        manager.stop()

        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test("start() -> stop() -> start() 生命周期正常")
    func restartLifecycle() throws {
        let (manager, transport) = makeManager()

        try manager.start()
        #expect(transport.isListening)

        manager.stop()
        #expect(!transport.isListening)

        try manager.start()
        #expect(transport.isListening)
        // BR_ENTRY, BR_EXIT, BR_ENTRY = 3 条广播
        #expect(transport.broadcastMessages.count == 3)
    }

    @Test("未 start() 就 stop() 不崩溃")
    func stopWithoutStart() {
        let (manager, _) = makeManager()
        manager.stop()
        #expect(manager.discoveredUsers.isEmpty)
    }

    // MARK: - Broadcast Tests

    @Test("sendBroadcast 编码并发送指定命令")
    func sendBroadcastEncodesPacket() throws {
        let (manager, transport) = makeManager()

        try manager.sendBroadcast(command: .BR_ABSENCE, payload: "away")

        #expect(transport.broadcastMessages.count == 1)
        let decoded = try IPMsgPacket.decode(
            String(data: transport.broadcastMessages[0].data, encoding: .utf8)!)
        #expect(decoded.command == .BR_ABSENCE)
        #expect(decoded.payload == "away")
    }

    @Test("sendBroadcast 使用配置的端口")
    func sendBroadcastUsesConfiguredPort() throws {
        let (manager, transport) = makeManager(port: 5000)

        try manager.sendBroadcast(command: .BR_ENTRY)

        #expect(transport.broadcastMessages[0].port == 5000)
    }

    // MARK: - Send Message Tests

    @Test("sendMessage 成功发送消息给用户")
    func sendMessageSuccess() async throws {
        let (manager, transport) = makeManager()
        let user = DiscoveredUser(
            senderName: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20", port: 2425
        )

        try await manager.sendMessage(to: user, message: "Hello Bob!")

        #expect(transport.sentMessages.count == 1)
        #expect(transport.sentMessages[0].host == "192.168.1.20")
        #expect(transport.sentMessages[0].port == 2425)

        let decoded = try IPMsgPacket.decode(
            String(data: transport.sentMessages[0].data, encoding: .utf8)!)
        #expect(decoded.command == .SENDMSG)
        #expect(decoded.payload == "Hello Bob!")
    }

    @Test("sendMessage 发送失败时抛出错误")
    func sendMessageFailure() async throws {
        let (manager, transport) = makeManager()
        transport.shouldFailOnSend = true
        let user = DiscoveredUser(
            senderName: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20"
        )

        await #expect(throws: Error.self) {
            try await manager.sendMessage(to: user, message: "Hello!")
        }
    }

    @Test("sendMessage 使用用户配置的端口")
    func sendMessageUsesUserPort() async throws {
        let (manager, transport) = makeManager()
        let user = DiscoveredUser(
            senderName: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20", port: 3000
        )

        try await manager.sendMessage(to: user, message: "test")

        #expect(transport.sentMessages[0].port == 3000)
    }

    // MARK: - Receive: User Discovery Tests

    @Test("收到 BR_ENTRY 时添加用户到 discoveredUsers")
    func receiveEntryAddsUser() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        transport.simulateReceive(data: makeBREntryData(sender: "alice"), from: "192.168.1.10")

        #expect(manager.discoveredUsers.count == 1)
        #expect(manager.discoveredUsers["alice"]?.nickname == "alice")
        #expect(manager.discoveredUsers["alice"]?.hostname == "alice-mac")
        #expect(manager.discoveredUsers["alice"]?.ipAddress == "192.168.1.10")
    }

    @Test("收到 BR_ENTRY 后自动回应 ANSENTRY")
    func receiveEntryRespondsWithAnsentry() throws {
        let (manager, transport) = makeManager()
        try manager.start()
        let initialBroadcasts = transport.broadcastMessages.count

        transport.simulateReceive(data: makeBREntryData(), from: "192.168.1.10")

        // 应有新增一条 ANSENTRY 广播
        #expect(transport.broadcastMessages.count == initialBroadcasts + 1)
        let lastBroadcast = transport.broadcastMessages.last!
        let decoded = try IPMsgPacket.decode(
            String(data: lastBroadcast.data, encoding: .utf8)!)
        #expect(decoded.command == .ANSENTRY)
    }

    @Test("收到 ANSENTRY 时添加用户但不回应")
    func receiveAnsEntryAddsUserNoReply() throws {
        let (manager, transport) = makeManager()
        try manager.start()
        let initialBroadcasts = transport.broadcastMessages.count

        transport.simulateReceive(data: makeANSEntryData(sender: "bob"), from: "192.168.1.20")

        #expect(manager.discoveredUsers.count == 1)
        #expect(manager.discoveredUsers["bob"] != nil)
        // ANSENTRY 不应触发额外广播
        #expect(transport.broadcastMessages.count == initialBroadcasts)
    }

    @Test("收到 BR_EXIT 时移除用户")
    func receiveExitRemovesUser() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        // 先添加用户
        transport.simulateReceive(data: makeBREntryData(sender: "alice"), from: "192.168.1.10")
        #expect(manager.discoveredUsers.count == 1)

        // 然后移除
        transport.simulateReceive(data: makeBRExitData(sender: "alice"), from: "192.168.1.10")
        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test("收到未知用户的 BR_EXIT 不崩溃")
    func receiveExitForUnknownUser() {
        let (manager, transport) = makeManager()

        transport.simulateReceive(data: makeBRExitData(sender: "unknown"), from: "192.168.1.99")

        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test("多个用户同时在线")
    func multipleUsersDiscovered() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        transport.simulateReceive(data: makeBREntryData(sender: "alice"), from: "192.168.1.10")
        transport.simulateReceive(data: makeANSEntryData(sender: "bob"), from: "192.168.1.20")

        #expect(manager.discoveredUsers.count == 2)
        #expect(manager.discoveredUsers["alice"] != nil)
        #expect(manager.discoveredUsers["bob"] != nil)
    }

    @Test("同一用户重新上线时更新信息")
    func userReentryUpdatesInfo() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        transport.simulateReceive(data: makeBREntryData(sender: "alice", hostname: "old-mac"), from: "192.168.1.10")
        let firstId = manager.discoveredUsers["alice"]?.id
        #expect(manager.discoveredUsers["alice"]?.hostname == "old-mac")

        transport.simulateReceive(data: makeBREntryData(sender: "alice", hostname: "new-mac"), from: "192.168.1.11")
        #expect(manager.discoveredUsers.count == 1)
        #expect(manager.discoveredUsers["alice"]?.hostname == "new-mac")
        #expect(manager.discoveredUsers["alice"]?.ipAddress == "192.168.1.11")
        // UUID should be preserved on re-entry
        #expect(manager.discoveredUsers["alice"]?.id == firstId)
    }

    // MARK: - Receive: Message Tests

    @Test("收到 SENDMSG 时处理消息并发送 RECVMSG 确认")
    func receiveSendMsgTriggersRecvAck() throws {
        let (manager, transport) = makeManager()
        try manager.start()
        let initialBroadcasts = transport.broadcastMessages.count

        transport.simulateReceive(data: makeSendMsgData(payload: "Hi there"), from: "192.168.1.30")

        // 应有一条 RECVMSG 确认广播
        #expect(transport.broadcastMessages.count == initialBroadcasts + 1)
        let ack = transport.broadcastMessages.last!
        let decoded = try IPMsgPacket.decode(String(data: ack.data, encoding: .utf8)!)
        #expect(decoded.command == .RECVMSG)
        #expect(decoded.payload == "400")  // 原始包 packetNo
    }

    // MARK: - Error Handling Tests

    @Test("收到畸形数据包时不崩溃")
    func receiveMalformedDataDoesNotCrash() {
        let (manager, transport) = makeManager()

        let badData = "not:a:valid:packet".data(using: .utf8)!
        transport.simulateReceive(data: badData, from: "192.168.1.99")

        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test("收到空数据时不崩溃")
    func receiveEmptyDataDoesNotCrash() {
        let (manager, transport) = makeManager()

        transport.simulateReceive(data: Data(), from: "192.168.1.99")

        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test("收到非 UTF-8 数据时不崩溃")
    func receiveNonUtf8DataDoesNotCrash() {
        let (manager, transport) = makeManager()

        let invalidUtf8 = Data([0xFF, 0xFE, 0x00, 0x01])
        transport.simulateReceive(data: invalidUtf8, from: "192.168.1.99")

        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test("start() 监听失败时抛出错误")
    func startListenFailure() {
        let (manager, transport) = makeManager()
        transport.shouldFailOnListen = true

        #expect(throws: Error.self) {
            try manager.start()
        }
    }

    // MARK: - Packet Number Tests

    @Test("packetNumber 每次发送自增")
    func packetNumberIncrements() throws {
        let (manager, transport) = makeManager()

        try manager.sendBroadcast(command: .BR_ENTRY)
        try manager.sendBroadcast(command: .BR_ENTRY)
        try manager.sendBroadcast(command: .BR_ENTRY)

        let packets = try transport.broadcastMessages.map {
            try IPMsgPacket.decode(String(data: $0.data, encoding: .utf8)!)
        }

        #expect(packets[0].packetNo == 1)
        #expect(packets[1].packetNo == 2)
        #expect(packets[2].packetNo == 3)
    }

    // MARK: - Concurrent Send Tests

    @Test("并发发送多条消息不崩溃")
    func concurrentSendMessages() async throws {
        let (manager, transport) = makeManager()
        let user = DiscoveredUser(
            senderName: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20"
        )

        // 并发发送 5 条消息
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask { @MainActor in
                    try await manager.sendMessage(to: user, message: "Message \(i)")
                }
            }
            try await group.waitForAll()
        }

        #expect(transport.sentMessages.count == 5)
    }
}
