//
//  IntegrationTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/14.
//

import Testing
import Foundation
@testable import FluxQServices
@testable import FluxQModels
@testable import IPMsgProtocol

@MainActor
struct IntegrationTests {

    // MARK: - Helpers

    private func makeManager(port: UInt16 = 2425) -> (NetworkManager, MockNetworkTransport) {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: port, transport: transport)
        return (manager, transport)
    }

    private func makePacketData(
        sender: String, hostname: String, command: IPMsgCommand,
        payload: String = "", packetNo: Int = 1
    ) -> Data {
        let packet = IPMsgPacket(
            version: 1, packetNo: packetNo, sender: sender,
            hostname: hostname, command: command, payload: payload
        )
        return packet.encode().data(using: .utf8)!
    }

    // MARK: - 1. 用户发现流程集成测试

    @Test("BR_ENTRY -> DiscoveredUser -> User 模型完整链路")
    func userDiscoveryToModelConversion() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        let entryData = makePacketData(
            sender: "alice", hostname: "alice-macbook", command: .BR_ENTRY
        )
        transport.simulateReceive(data: entryData, from: "192.168.1.100")

        // 验证 DiscoveredUser 创建正确
        let discovered = manager.discoveredUsers["alice"]
        #expect(discovered != nil)
        #expect(discovered?.nickname == "alice")
        #expect(discovered?.hostname == "alice-macbook")
        #expect(discovered?.ipAddress == "192.168.1.100")

        // 验证 toUser() 转换字段正确映射
        let user = discovered!.toUser()
        #expect(user.id == "alice")
        #expect(user.nickname == "alice")
        #expect(user.hostname == "alice-macbook")
        #expect(user.ipAddress == "192.168.1.100")
        #expect(user.port == 2425)
        #expect(user.status == .online)
        #expect(user.isOnline == true)
    }

    @Test("多用户发现后转换为 User 模型数组")
    func multipleUsersDiscoveredAndConverted() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        transport.simulateReceive(
            data: makePacketData(sender: "alice", hostname: "alice-mac", command: .BR_ENTRY),
            from: "192.168.1.10"
        )
        transport.simulateReceive(
            data: makePacketData(sender: "bob", hostname: "bob-mac", command: .ANSENTRY),
            from: "192.168.1.20"
        )

        let users = manager.discoveredUsers.values.map { $0.toUser() }
        #expect(users.count == 2)

        let ids = Set(users.map { $0.id })
        #expect(ids.contains("alice"))
        #expect(ids.contains("bob"))
    }

    // MARK: - 2. 心跳 -> 在线状态 -> 搜索过滤链路

    @Test("HeartbeatService 记录心跳后 SearchFilter 可过滤在线用户")
    func heartbeatToSearchFilterOnline() {
        let heartbeat = HeartbeatService()
        let searchFilter = SearchFilterService()
        searchFilter.filters = [.onlineOnly]

        let onlineUser = User(
            id: "alice", nickname: "Alice", hostname: "alice-mac",
            ipAddress: "192.168.1.10", isOnline: true
        )
        let offlineUser = User(
            id: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20", isOnline: false
        )

        heartbeat.recordHeartbeat(userId: "alice")
        #expect(heartbeat.isUserOnline("alice"))

        let filtered = searchFilter.filterUsers([onlineUser, offlineUser])
        #expect(filtered.count == 1)
        #expect(filtered[0].id == "alice")
    }

    @Test("HeartbeatService 超时后用户不再匹配在线过滤")
    func heartbeatTimeoutAffectsSearchFilter() {
        let heartbeat = HeartbeatService()
        let searchFilter = SearchFilterService()
        searchFilter.filters = [.onlineOnly]

        // 记录一个很久以前的心跳
        let longAgo = Date().addingTimeInterval(-heartbeat.timeoutInterval - 1)
        heartbeat.recordHeartbeat(userId: "alice", at: longAgo)
        #expect(!heartbeat.isUserOnline("alice"))

        // 对应的 User 模型 isOnline 设为 false
        let user = User(
            id: "alice", nickname: "Alice", hostname: "alice-mac",
            ipAddress: "192.168.1.10", isOnline: false
        )

        let filtered = searchFilter.filterUsers([user])
        #expect(filtered.isEmpty)
    }

    // MARK: - 3. 头像服务 -> 搜索过滤集成

    @Test("设置头像后 SearchFilter withAvatar 过滤正确工作")
    func avatarServiceToSearchFilter() {
        let avatarService = AvatarService()
        let searchFilter = SearchFilterService()
        searchFilter.filters = [.withAvatar]

        avatarService.setMyAvatar(Data("avatar-data".utf8))
        let hash = avatarService.myAvatarHash

        let userWithAvatar = User(
            id: "me", nickname: "Me", hostname: "my-mac",
            ipAddress: "127.0.0.1", avatarHash: hash
        )
        let userWithout = User(
            id: "other", nickname: "Other", hostname: "other-mac",
            ipAddress: "192.168.1.20"
        )

        let filtered = searchFilter.filterUsers([userWithAvatar, userWithout])
        #expect(filtered.count == 1)
        #expect(filtered[0].id == "me")
    }

    @Test("AvatarService 缓存的头像可以按 hash 检索")
    func avatarCacheIntegration() {
        let avatarService = AvatarService()
        let data = Data("profile-picture".utf8)

        avatarService.setMyAvatar(data)
        let hash = avatarService.myAvatarHash!

        // 通过 hash 检索缓存
        let cached = avatarService.cachedAvatar(forHash: hash)
        #expect(cached == data)
    }

    // MARK: - 4. IPMsgPacket 编解码端到端

    @Test("IPMsgPacket 各命令类型编解码往返一致")
    func packetEncodeDecodeRoundTrip() throws {
        let commands: [(IPMsgCommand, String)] = [
            (.BR_ENTRY, ""),
            (.BR_EXIT, ""),
            (.ANSENTRY, ""),
            (.SENDMSG, "Hello World!"),
            (.RECVMSG, "12345"),
            (.BR_ABSENCE, "away message"),
        ]

        for (command, payload) in commands {
            let original = IPMsgPacket(
                version: 1, packetNo: 42, sender: "testuser",
                hostname: "test-host", command: command, payload: payload
            )

            let encoded = original.encode()
            let decoded = try IPMsgPacket.decode(encoded)

            #expect(decoded == original, "Roundtrip failed for \(command.name)")
        }
    }

    @Test("包含冒号的 payload 编解码正确")
    func packetWithColonInPayload() throws {
        let original = IPMsgPacket(
            version: 1, packetNo: 1, sender: "user",
            hostname: "host", command: .SENDMSG,
            payload: "key:value:extra"
        )

        let decoded = try IPMsgPacket.decode(original.encode())
        #expect(decoded.payload == "key:value:extra")
    }

    // MARK: - 5. NetworkManager + 心跳集成

    @Test("NetworkManager 发现用户后 HeartbeatService 可追踪其在线状态")
    func networkDiscoveryToHeartbeat() throws {
        let (manager, transport) = makeManager()
        let heartbeat = HeartbeatService()
        try manager.start()

        // 用户通过网络被发现
        transport.simulateReceive(
            data: makePacketData(sender: "alice", hostname: "alice-mac", command: .BR_ENTRY),
            from: "192.168.1.10"
        )

        // 为发现的用户记录心跳
        let discovered = manager.discoveredUsers["alice"]!
        heartbeat.recordHeartbeat(userId: discovered.id)

        #expect(heartbeat.isUserOnline("alice"))
    }

    // MARK: - 6. 完整消息流 (发送 + 确认)

    @Test("发送消息后对方发送 RECVMSG 确认的完整流程")
    func sendAndReceiveAck() async throws {
        let (manager, transport) = makeManager()
        try manager.start()

        // 发现对方
        transport.simulateReceive(
            data: makePacketData(sender: "bob", hostname: "bob-mac", command: .BR_ENTRY),
            from: "192.168.1.20"
        )
        let bob = manager.discoveredUsers["bob"]!

        // 发送消息
        try await manager.sendMessage(to: bob, message: "Hi Bob!")

        #expect(transport.sentMessages.count == 1)
        let sentPacket = try IPMsgPacket.decode(
            String(data: transport.sentMessages[0].data, encoding: .utf8)!)
        #expect(sentPacket.command == .SENDMSG)
        #expect(sentPacket.payload == "Hi Bob!")

        // 模拟对方发送确认
        let ackData = makePacketData(
            sender: "bob", hostname: "bob-mac", command: .RECVMSG,
            payload: "\(sentPacket.packetNo)"
        )
        transport.simulateReceive(data: ackData, from: "192.168.1.20")

        // 确认不崩溃即可（当前 RECVMSG 走 default 分支）
        #expect(manager.discoveredUsers["bob"] != nil)
    }
}
