//
//  ConcurrencyTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/14.
//

import Foundation
import Testing
@testable import FluxQServices
import FluxQModels

@MainActor
struct ConcurrencyTests {

    // MARK: - HeartbeatService 并发 recordHeartbeat

    @Test("并发 recordHeartbeat 不崩溃且数据一致")
    func concurrentRecordHeartbeat() async {
        let service = HeartbeatService()
        let userCount = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<userCount {
                group.addTask { @MainActor in
                    service.recordHeartbeat(userId: "user-\(i)")
                }
            }
        }

        #expect(service.onlineUsers.count == userCount)
        for i in 0..<userCount {
            #expect(service.isUserOnline("user-\(i)"))
        }
    }

    @Test("并发对同一用户 recordHeartbeat 保持数据一致")
    func concurrentRecordHeartbeatSameUser() async {
        let service = HeartbeatService()
        let iterations = 50

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask { @MainActor in
                    service.recordHeartbeat(userId: "shared-user")
                }
            }
        }

        #expect(service.onlineUsers.count == 1)
        #expect(service.isUserOnline("shared-user"))
    }

    // MARK: - HeartbeatService 并发 checkTimeouts

    @Test("并发读写 onlineUsers 不崩溃")
    func concurrentHeartbeatReadWrite() async {
        let service = HeartbeatService()
        let now = Date()

        // 先添加一些用户，部分已超时
        for i in 0..<20 {
            let time = i < 10 ? now : now.addingTimeInterval(-(service.timeoutInterval + 10))
            service.recordHeartbeat(userId: "user-\(i)", at: time)
        }

        await withTaskGroup(of: Void.self) { group in
            // 并发执行 checkTimeouts
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    service.checkTimeouts(currentTime: now)
                }
            }

            // 同时并发添加新用户
            for i in 20..<40 {
                group.addTask { @MainActor in
                    service.recordHeartbeat(userId: "user-\(i)", at: now)
                }
            }
        }

        // 前 10 个用户应仍在线（未超时）
        for i in 0..<10 {
            #expect(service.onlineUsers["user-\(i)"] != nil)
        }

        // 新添加的用户应在线
        for i in 20..<40 {
            #expect(service.onlineUsers["user-\(i)"] != nil)
        }
    }

    @Test("并发 isUserOnline 查询不崩溃")
    func concurrentIsUserOnlineQueries() async {
        let service = HeartbeatService()
        let now = Date()

        for i in 0..<50 {
            service.recordHeartbeat(userId: "user-\(i)", at: now)
        }

        await withTaskGroup(of: Void.self) { group in
            // 并发查询
            for i in 0..<50 {
                group.addTask { @MainActor in
                    _ = service.isUserOnline("user-\(i)", at: now)
                }
            }

            // 同时执行 checkTimeouts
            group.addTask { @MainActor in
                service.checkTimeouts(currentTime: now)
            }
        }

        // 所有用户应仍在线（未超时）
        #expect(service.onlineUsers.count == 50)
    }

    // MARK: - SearchFilterService 并发读写

    @Test("并发修改 searchText 和调用 filterUsers 不崩溃")
    func concurrentSearchFilterReadWrite() async {
        let service = SearchFilterService()
        let users = (0..<20).map { i in
            User(
                id: "user-\(i)",
                nickname: "User\(i)",
                hostname: "host-\(i)",
                ipAddress: "192.168.1.\(i)"
            )
        }

        await withTaskGroup(of: Void.self) { group in
            // 并发修改 searchText
            for i in 0..<20 {
                group.addTask { @MainActor in
                    service.searchText = "User\(i)"
                }
            }

            // 同时并发调用 filterUsers
            for _ in 0..<20 {
                group.addTask { @MainActor in
                    _ = service.filterUsers(users)
                }
            }
        }

        // 最终 filterUsers 应能正常返回结果
        let results = service.filterUsers(users)
        #expect(results.count >= 0)
    }

    @Test("并发修改 filters 和调用 filterUsers 不崩溃")
    func concurrentFiltersModification() async {
        let service = SearchFilterService()
        let now = Date()
        let users = (0..<10).map { i in
            User(
                id: "user-\(i)",
                nickname: "User\(i)",
                hostname: "host-\(i)",
                ipAddress: "192.168.1.\(i)",
                isOnline: i % 2 == 0,
                lastSeen: now,
                avatarHash: i % 3 == 0 ? "hash-\(i)" : nil
            )
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                service.filters = [.onlineOnly]
            }
            group.addTask { @MainActor in
                service.filters = [.withAvatar]
            }
            group.addTask { @MainActor in
                service.filters = [.recentlyActive]
            }
            group.addTask { @MainActor in
                service.filters = [.onlineOnly, .withAvatar]
            }

            for _ in 0..<10 {
                group.addTask { @MainActor in
                    _ = service.filterUsers(users)
                }
            }
        }

        // 应能正常返回结果
        let results = service.filterUsers(users)
        #expect(results.count >= 0)
    }

    // MARK: - AvatarService 并发操作

    @Test("并发 setMyAvatar 和 cachedAvatar 读取不崩溃")
    func concurrentAvatarSetAndRead() async {
        let service = AvatarService()

        await withTaskGroup(of: Void.self) { group in
            // 并发设置头像
            for i in 0..<20 {
                group.addTask { @MainActor in
                    let data = Data("avatar-\(i)".utf8)
                    service.setMyAvatar(data)
                }
            }

            // 同时并发读取缓存
            for i in 0..<20 {
                group.addTask { @MainActor in
                    _ = service.cachedAvatar(forHash: "hash-\(i)")
                }
            }
        }

        // myAvatarData 应有值（最后一次 setMyAvatar 的结果）
        #expect(service.myAvatarData != nil)
        #expect(service.myAvatarHash != nil)
    }

    @Test("并发 cacheAvatar 操作保持缓存一致性")
    func concurrentCacheAvatar() async {
        let service = AvatarService(maxCacheEntries: 10)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<30 {
                group.addTask { @MainActor in
                    let data = Data("cached-\(i)".utf8)
                    service.cacheAvatar(data: data, forHash: "hash-\(i)")
                }
            }
        }

        // 缓存条目不应超过上限
        #expect(service.cacheCount <= 10)
        #expect(service.cacheCount > 0)
    }

    @Test("并发 setMyAvatar 和 clearMyAvatar 不崩溃")
    func concurrentSetAndClearAvatar() async {
        let service = AvatarService()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                if i % 2 == 0 {
                    group.addTask { @MainActor in
                        service.setMyAvatar(Data("avatar-\(i)".utf8))
                    }
                } else {
                    group.addTask { @MainActor in
                        service.clearMyAvatar()
                    }
                }
            }
        }

        // 不崩溃即可，最终状态取决于执行顺序
        #expect(Bool(true))
    }

    // MARK: - NetworkManager 并发 sendMessage

    @Test("并发发送多条消息全部成功")
    func concurrentSendMessages() async throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        let user = DiscoveredUser(
            id: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20"
        )

        let messageCount = 20

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<messageCount {
                group.addTask { @MainActor in
                    try await manager.sendMessage(to: user, message: "Message \(i)")
                }
            }
            try await group.waitForAll()
        }

        #expect(transport.sentMessages.count == messageCount)
    }

    @Test("并发发送消息到不同用户不崩溃")
    func concurrentSendToDifferentUsers() async throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)

        let users = (0..<10).map { i in
            DiscoveredUser(
                id: "user-\(i)", nickname: "User\(i)", hostname: "host-\(i)",
                ipAddress: "192.168.1.\(10 + i)"
            )
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, user) in users.enumerated() {
                group.addTask { @MainActor in
                    try await manager.sendMessage(to: user, message: "Hello User\(index)")
                }
            }
            try await group.waitForAll()
        }

        #expect(transport.sentMessages.count == 10)
    }

    @Test("并发 sendBroadcast 不崩溃")
    func concurrentSendBroadcast() async {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)

        let broadcastCount = 20

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<broadcastCount {
                group.addTask { @MainActor in
                    try? manager.sendBroadcast(command: .BR_ENTRY)
                }
            }
        }

        #expect(transport.broadcastMessages.count == broadcastCount)
    }

    // MARK: - @MainActor 隔离验证

    @Test("HeartbeatService 在 MainActor 上下文中正常工作")
    func heartbeatServiceMainActorIsolation() async {
        let service = HeartbeatService()

        // 从 Task 中访问 @MainActor 隔离的属性和方法
        await Task { @MainActor in
            service.recordHeartbeat(userId: "test")
            #expect(service.isUserOnline("test"))
            #expect(service.onlineUsers.count == 1)
        }.value
    }

    @Test("SearchFilterService 在 MainActor 上下文中正常工作")
    func searchFilterServiceMainActorIsolation() async {
        let service = SearchFilterService()

        await Task { @MainActor in
            service.searchText = "test"
            #expect(service.searchText == "test")

            service.filters = [.onlineOnly]
            #expect(service.filters.contains(.onlineOnly))
        }.value
    }

    @Test("AvatarService 在 MainActor 上下文中正常工作")
    func avatarServiceMainActorIsolation() async {
        let service = AvatarService()

        await Task { @MainActor in
            let data = Data("test-avatar".utf8)
            service.setMyAvatar(data)

            #expect(service.myAvatarData == data)
            #expect(service.myAvatarHash != nil)

            let hash = service.myAvatarHash!
            #expect(service.cachedAvatar(forHash: hash) == data)
        }.value
    }

    @Test("NetworkManager 在 MainActor 上下文中正常工作")
    func networkManagerMainActorIsolation() async throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)

        try await Task { @MainActor in
            try manager.start()
            #expect(transport.isListening)
            #expect(manager.discoveredUsers.isEmpty)
            manager.stop()
            #expect(!transport.isListening)
        }.value
    }

    @Test("多个 @MainActor 服务可以在同一上下文中交互")
    func multipleServicesInteraction() async {
        let heartbeat = HeartbeatService()
        let avatar = AvatarService()
        let search = SearchFilterService()

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                heartbeat.recordHeartbeat(userId: "user-1")
                heartbeat.recordHeartbeat(userId: "user-2")
            }

            group.addTask { @MainActor in
                avatar.setMyAvatar(Data("avatar".utf8))
            }

            group.addTask { @MainActor in
                search.searchText = "user"
            }
        }

        #expect(heartbeat.onlineUsers.count == 2)
        #expect(avatar.myAvatarData != nil)
        #expect(search.searchText == "user")
    }
}
