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

    /// Strip the \0instanceId suffix appended by createPacket
    private func cleanPayload(_ payload: String) -> String {
        String(payload.split(separator: "\0", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
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
        #expect(discovered?.senderName == "alice")

        // 验证 toUser() 转换字段正确映射
        let user = discovered!.toUser()
        #expect(user.id == discovered?.id)
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

        let nicknames = Set(users.map { $0.nickname })
        #expect(nicknames.contains("alice"))
        #expect(nicknames.contains("bob"))
    }

    @Test("带 group 的 DiscoveredUser 转换 User 后 group 字段保留")
    func discoveredUserWithGroupConvertsCorrectly() {
        let discovered = DiscoveredUser(
            senderName: "charlie", nickname: "Charlie", hostname: "charlie-mac",
            ipAddress: "192.168.1.30", port: 3000, group: "Engineering"
        )

        let user = discovered.toUser()
        #expect(user.group == "Engineering")
        #expect(user.port == 3000)
    }

    @Test("用户上线再下线后 discoveredUsers 正确更新")
    func userEntryThenExitFlow() throws {
        let (manager, transport) = makeManager()
        try manager.start()

        // 上线
        transport.simulateReceive(
            data: makePacketData(sender: "alice", hostname: "alice-mac", command: .BR_ENTRY),
            from: "192.168.1.10"
        )
        #expect(manager.discoveredUsers.count == 1)
        let user = manager.discoveredUsers["alice"]!.toUser()
        #expect(user.isOnline == true)

        // 下线
        transport.simulateReceive(
            data: makePacketData(sender: "alice", hostname: "alice-mac", command: .BR_EXIT),
            from: "192.168.1.10"
        )
        #expect(manager.discoveredUsers.isEmpty)
    }

    // MARK: - 2. 心跳 -> 在线状态 -> 搜索过滤链路

    @Test("HeartbeatService 记录心跳后 SearchFilter 可过滤在线用户")
    func heartbeatToSearchFilterOnline() {
        let heartbeat = HeartbeatService()
        let searchFilter = SearchFilterService()
        searchFilter.filters = [.onlineOnly]

        let aliceId = UUID()
        let onlineUser = User(
            id: aliceId, nickname: "Alice", hostname: "alice-mac",
            ipAddress: "192.168.1.10", isOnline: true
        )
        let offlineUser = User(
            nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20", isOnline: false
        )

        heartbeat.recordHeartbeat(userId: aliceId)
        #expect(heartbeat.isUserOnline(aliceId))

        let filtered = searchFilter.filterUsers([onlineUser, offlineUser])
        #expect(filtered.count == 1)
        #expect(filtered[0].id == aliceId)
    }

    @Test("HeartbeatService 超时后用户不再匹配在线过滤")
    func heartbeatTimeoutAffectsSearchFilter() {
        let heartbeat = HeartbeatService()
        let searchFilter = SearchFilterService()
        searchFilter.filters = [.onlineOnly]

        let aliceId = UUID()
        // 记录一个很久以前的心跳
        let longAgo = Date().addingTimeInterval(-heartbeat.timeoutInterval - 1)
        heartbeat.recordHeartbeat(userId: aliceId, at: longAgo)
        #expect(!heartbeat.isUserOnline(aliceId))

        // 对应的 User 模型 isOnline 设为 false
        let user = User(
            id: aliceId, nickname: "Alice", hostname: "alice-mac",
            ipAddress: "192.168.1.10", isOnline: false
        )

        let filtered = searchFilter.filterUsers([user])
        #expect(filtered.isEmpty)
    }

    @Test("心跳从在线到超时的连续状态变化影响搜索过滤")
    func heartbeatOnlineToTimeoutFilterTransition() {
        let heartbeat = HeartbeatService()
        let searchFilter = SearchFilterService()
        searchFilter.filters = [.onlineOnly]

        let aliceId = UUID()
        let now = Date()
        heartbeat.recordHeartbeat(userId: aliceId, at: now)

        // 阶段 1: 在线 -> 过滤结果包含该用户
        #expect(heartbeat.isUserOnline(aliceId, at: now))
        let onlineUser = User(
            id: aliceId, nickname: "Alice", hostname: "alice-mac",
            ipAddress: "192.168.1.10", isOnline: true
        )
        #expect(searchFilter.filterUsers([onlineUser]).count == 1)

        // 阶段 2: 超时 -> 过滤结果不含该用户
        let afterTimeout = now.addingTimeInterval(heartbeat.timeoutInterval + 1)
        #expect(!heartbeat.isUserOnline(aliceId, at: afterTimeout))
        let offlineUser = User(
            id: aliceId, nickname: "Alice", hostname: "alice-mac",
            ipAddress: "192.168.1.10", isOnline: false
        )
        #expect(searchFilter.filterUsers([offlineUser]).isEmpty)

        // 阶段 3: 重新心跳 -> 再次出现
        heartbeat.recordHeartbeat(userId: aliceId, at: afterTimeout)
        #expect(heartbeat.isUserOnline(aliceId, at: afterTimeout))
        let backOnlineUser = User(
            id: aliceId, nickname: "Alice", hostname: "alice-mac",
            ipAddress: "192.168.1.10", isOnline: true
        )
        #expect(searchFilter.filterUsers([backOnlineUser]).count == 1)
    }

    @Test("渐进式超时移除 - 三次 checkTimeouts 后用户从 onlineUsers 移除")
    func progressiveTimeoutRemoval() {
        let heartbeat = HeartbeatService()
        let aliceId = UUID()
        let now = Date()

        heartbeat.recordHeartbeat(userId: aliceId, at: now)

        let timeoutBase = now.addingTimeInterval(heartbeat.timeoutInterval + 1)

        // 第 1 次超时检查 - 仍在列表中
        heartbeat.checkTimeouts(currentTime: timeoutBase)
        #expect(heartbeat.onlineUsers[aliceId] != nil)

        // 第 2 次超时检查
        heartbeat.checkTimeouts(currentTime: timeoutBase.addingTimeInterval(heartbeat.timeoutInterval + 1))
        #expect(heartbeat.onlineUsers[aliceId] != nil)

        // 第 3 次超时检查 - 移除
        heartbeat.checkTimeouts(currentTime: timeoutBase.addingTimeInterval((heartbeat.timeoutInterval + 1) * 2))
        #expect(heartbeat.onlineUsers[aliceId] == nil)
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
            nickname: "Me", hostname: "my-mac",
            ipAddress: "127.0.0.1", avatarHash: hash
        )
        let userWithout = User(
            nickname: "Other", hostname: "other-mac",
            ipAddress: "192.168.1.20"
        )

        let filtered = searchFilter.filterUsers([userWithAvatar, userWithout])
        #expect(filtered.count == 1)
        #expect(filtered[0].avatarHash == hash)
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

    @Test("清除头像后 SearchFilter withAvatar 不再匹配")
    func clearAvatarAffectsSearchFilter() {
        let avatarService = AvatarService()
        let searchFilter = SearchFilterService()
        searchFilter.filters = [.withAvatar]

        avatarService.setMyAvatar(Data("avatar".utf8))
        let hash = avatarService.myAvatarHash

        let userWithAvatar = User(
            nickname: "Me", hostname: "my-mac",
            ipAddress: "127.0.0.1", avatarHash: hash
        )
        #expect(searchFilter.filterUsers([userWithAvatar]).count == 1)

        // 清除头像后，用新的 User (无 avatarHash) 检查过滤
        avatarService.clearMyAvatar()
        let userNoAvatar = User(
            nickname: "Me", hostname: "my-mac",
            ipAddress: "127.0.0.1", avatarHash: nil
        )
        #expect(searchFilter.filterUsers([userNoAvatar]).isEmpty)
    }

    @Test("不同头像数据产生不同 hash 影响搜索匹配")
    func differentAvatarHashesAreDistinct() {
        let avatarService = AvatarService()

        avatarService.setMyAvatar(Data("avatar-1".utf8))
        let hash1 = avatarService.myAvatarHash!

        avatarService.setMyAvatar(Data("avatar-2".utf8))
        let hash2 = avatarService.myAvatarHash!

        #expect(hash1 != hash2)

        // 两个 hash 对应的缓存都应存在
        #expect(avatarService.cachedAvatar(forHash: hash1) != nil)
        #expect(avatarService.cachedAvatar(forHash: hash2) != nil)
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

    @Test("扩展命令编解码往返一致")
    func extendedCommandsRoundTrip() throws {
        let extendedCommands: [(IPMsgCommand, String)] = [
            (.RECALLMSG, "msg-id-123"),
            (.AVATAR, "sha256hash"),
            (.GETAVATAR, "sha256hash"),
            (.TYPING, ""),
            (.STOPTYPING, ""),
        ]

        for (command, payload) in extendedCommands {
            let original = IPMsgPacket(
                version: 1, packetNo: 99, sender: "testuser",
                hostname: "test-host", command: command, payload: payload
            )

            let encoded = original.encode()
            let decoded = try IPMsgPacket.decode(encoded)

            #expect(decoded == original, "Roundtrip failed for extended command \(command.name)")
        }
    }

    @Test("文件传输命令编解码往返一致")
    func fileTransferCommandsRoundTrip() throws {
        let fileCommands: [(IPMsgCommand, String)] = [
            (.GETFILEDATA, "fileId:offset:size"),
            (.RELEASEFILES, "fileId"),
            (.GETDIRFILES, "dirPath"),
        ]

        for (command, payload) in fileCommands {
            let original = IPMsgPacket(
                version: 1, packetNo: 77, sender: "sender",
                hostname: "hostname", command: command, payload: payload
            )

            let encoded = original.encode()
            let decoded = try IPMsgPacket.decode(encoded)

            #expect(decoded == original, "Roundtrip failed for file command \(command.name)")
        }
    }

    @Test("空 payload 编解码正确")
    func emptyPayloadRoundTrip() throws {
        let original = IPMsgPacket(
            version: 1, packetNo: 1, sender: "user",
            hostname: "host", command: .BR_ENTRY, payload: ""
        )

        let decoded = try IPMsgPacket.decode(original.encode())
        #expect(decoded.payload == "")
        #expect(decoded == original)
    }

    @Test("格式异常的消息抛出正确错误")
    func malformedPacketThrowsError() {
        #expect(throws: IPMsgError.self) {
            _ = try IPMsgPacket.decode("too:few:parts")
        }

        #expect(throws: IPMsgError.self) {
            _ = try IPMsgPacket.decode("notanumber:1:user:host:1:payload")
        }

        #expect(throws: IPMsgError.self) {
            _ = try IPMsgPacket.decode("1:1:user:host:999999:payload")
        }
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

        #expect(heartbeat.isUserOnline(discovered.id))
    }

    @Test("NetworkManager 发现 -> 转换 User -> SearchFilter 搜索全链路")
    func discoveryToSearchFullPipeline() throws {
        let (manager, transport) = makeManager()
        let searchFilter = SearchFilterService()
        try manager.start()

        // 发现多个用户
        transport.simulateReceive(
            data: makePacketData(sender: "alice", hostname: "alice-mac", command: .BR_ENTRY),
            from: "192.168.1.10"
        )
        transport.simulateReceive(
            data: makePacketData(sender: "bob", hostname: "bob-pro", command: .ANSENTRY),
            from: "192.168.1.20"
        )

        // 转换为 User 模型
        let users = manager.discoveredUsers.values.map { $0.toUser() }
        #expect(users.count == 2)

        // 搜索过滤
        searchFilter.searchText = "alice"
        let filtered = searchFilter.filterUsers(users)
        #expect(filtered.count == 1)
        #expect(filtered[0].nickname == "alice")
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
        #expect(cleanPayload(sentPacket.payload) == "Hi Bob!")

        // 模拟对方发送确认
        let ackData = makePacketData(
            sender: "bob", hostname: "bob-mac", command: .RECVMSG,
            payload: "\(sentPacket.packetNo)"
        )
        transport.simulateReceive(data: ackData, from: "192.168.1.20")

        // 确认不崩溃即可（当前 RECVMSG 走 default 分支）
        #expect(manager.discoveredUsers["bob"] != nil)
    }

    @Test("收到 SENDMSG 后自动单播回复 RECVMSG 并正确引用 packetNo")
    func receiveMsgTriggersAckWithCorrectPacketNo() async throws {
        let (manager, transport) = makeManager()
        try manager.start()
        let initialSent = transport.sentMessages.count

        let incomingPacketNo = 567
        let msgData = makePacketData(
            sender: "charlie", hostname: "charlie-mac", command: .SENDMSG,
            payload: "Hello!", packetNo: incomingPacketNo
        )
        transport.simulateReceive(data: msgData, from: "192.168.1.30")

        // Wait for the async Task to complete
        try await Task.sleep(nanoseconds: 50_000_000)

        // RECVMSG is now sent via unicast (sendToHost), not broadcast
        #expect(transport.sentMessages.count == initialSent + 1)
        let ackPacket = try IPMsgPacket.decode(
            String(data: transport.sentMessages.last!.data, encoding: .utf8)!)
        #expect(ackPacket.command == .RECVMSG)
        #expect(cleanPayload(ackPacket.payload) == "\(incomingPacketNo)")
    }

    // MARK: - 7. 组合过滤集成

    @Test("在线 + 有头像的组合过滤从发现用户中筛选")
    func combinedOnlineAndAvatarFilter() throws {
        let searchFilter = SearchFilterService()
        searchFilter.filters = [.onlineOnly, .withAvatar]

        let users = [
            User(nickname: "Alice", hostname: "h1",
                 ipAddress: "192.168.1.1", isOnline: true, avatarHash: "abc"),
            User(nickname: "Bob", hostname: "h2",
                 ipAddress: "192.168.1.2", isOnline: true, avatarHash: nil),
            User(nickname: "Charlie", hostname: "h3",
                 ipAddress: "192.168.1.3", isOnline: false, avatarHash: "def"),
        ]

        let filtered = searchFilter.filterUsers(users)
        #expect(filtered.count == 1)
        #expect(filtered[0].nickname == "Alice")
    }
}
