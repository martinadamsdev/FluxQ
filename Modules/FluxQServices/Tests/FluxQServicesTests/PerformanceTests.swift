//
//  PerformanceTests.swift
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
struct PerformanceTests {

    // MARK: - Helpers

    private func makeUsers(count: Int, onlineRatio: Double = 0.5, withAvatarRatio: Double = 0.3) -> [User] {
        var users: [User] = []
        users.reserveCapacity(count)
        let now = Date()
        for i in 0..<count {
            let fraction = Double(i) / Double(count)
            let group: String? = i % 3 == 0 ? "Engineering" : (i % 3 == 1 ? "Design" : nil)
            let hash: String? = fraction < withAvatarRatio ? "hash-\(i)" : nil
            let user = User(
                nickname: "User \(i)",
                hostname: "host-\(i).local",
                ipAddress: "192.168.1.\(i % 255)",
                group: group,
                isOnline: fraction < onlineRatio,
                lastSeen: now.addingTimeInterval(-Double(i % 600)),
                avatarHash: hash
            )
            users.append(user)
        }
        return users
    }

    private func measureDuration(_ block: () -> Void) -> Duration {
        let clock = ContinuousClock()
        return clock.measure { block() }
    }

    private func measureDurationThrowing(_ block: () throws -> Void) rethrows -> Duration {
        let clock = ContinuousClock()
        var result: Duration = .zero
        result = try clock.measure { try block() }
        return result
    }

    // MARK: - SearchFilterService Performance

    @Test("搜索过滤 100 用户 < 16ms (60fps)")
    func searchFilter100Users() {
        let service = SearchFilterService()
        service.searchText = "user 5"
        service.filters = [.onlineOnly]
        let users = makeUsers(count: 100)

        let duration = measureDuration {
            for _ in 0..<10 {
                _ = service.filterUsers(users)
            }
        }

        let avgMs = Double(duration.components.attoseconds) / 1e15 / 10.0
        #expect(avgMs < 16, "100 用户搜索过滤平均耗时 \(avgMs)ms，超过 16ms 阈值")
    }

    @Test("搜索过滤 1000 用户 < 50ms")
    func searchFilter1000Users() {
        let service = SearchFilterService()
        service.searchText = "engineer"
        service.filters = [.onlineOnly, .recentlyActive]
        let users = makeUsers(count: 1000)

        let duration = measureDuration {
            for _ in 0..<5 {
                _ = service.filterUsers(users)
            }
        }

        let avgMs = Double(duration.components.attoseconds) / 1e15 / 5.0
        #expect(avgMs < 50, "1000 用户搜索过滤平均耗时 \(avgMs)ms，超过 50ms 阈值")
    }

    // MARK: - AvatarService Performance

    @Test("SHA-256 哈希计算 1MB 数据 < 10ms")
    func avatarHash1MB() {
        let service = AvatarService()
        let data = Data(repeating: 0xAB, count: 1_000_000)

        let duration = measureDuration {
            for _ in 0..<10 {
                service.setMyAvatar(data)
            }
        }

        let avgMs = Double(duration.components.attoseconds) / 1e15 / 10.0
        #expect(avgMs < 10, "1MB SHA-256 哈希平均耗时 \(avgMs)ms，超过 10ms 阈值")
    }

    @Test("头像压缩 2MB 数据 < 100ms")
    func avatarCompress2MB() {
        let service = AvatarService()
        let data = Data(repeating: 0xCD, count: 2_000_000)
        let maxSize = 500_000

        let duration = measureDuration {
            for _ in 0..<10 {
                _ = service.compressAvatar(data, maxSize: maxSize)
            }
        }

        let avgMs = Double(duration.components.attoseconds) / 1e15 / 10.0
        #expect(avgMs < 100, "2MB 头像压缩平均耗时 \(avgMs)ms，超过 100ms 阈值")
    }

    @Test("缓存查找 50 条记录中检索 < 1ms")
    func avatarCacheLookup() {
        let service = AvatarService()

        // 填充 50 条缓存
        var hashes: [String] = []
        for i in 0..<50 {
            let hash = "hash-\(i)"
            hashes.append(hash)
            service.cacheAvatar(data: Data("avatar-\(i)".utf8), forHash: hash)
        }

        let duration = measureDuration {
            for _ in 0..<1000 {
                for hash in hashes {
                    _ = service.cachedAvatar(forHash: hash)
                }
            }
        }

        // 1000 * 50 = 50000 次查找的总时间，计算单次查找的平均时间
        let avgMs = Double(duration.components.attoseconds) / 1e15 / 1000.0
        #expect(avgMs < 1, "50 条缓存查找平均耗时 \(avgMs)ms，超过 1ms 阈值")
    }

    // MARK: - IPMsgPacket Performance

    @Test("IPMsgPacket 编解码 10000 次 < 100ms")
    func packetEncodeDecode10000() throws {
        let packet = IPMsgPacket(
            version: 1, packetNo: 12345, sender: "testuser",
            hostname: "test-host.local", command: .SENDMSG,
            payload: "Hello, this is a test message with some content!"
        )

        let duration = try measureDurationThrowing {
            for _ in 0..<10_000 {
                let encoded = packet.encode()
                _ = try IPMsgPacket.decode(encoded)
            }
        }

        let totalMs = Double(duration.components.attoseconds) / 1e15
        #expect(totalMs < 100, "10000 次编解码耗时 \(totalMs)ms，超过 100ms 阈值")
    }

    // MARK: - HeartbeatService Performance

    @Test("checkTimeouts 1000 在线用户 < 10ms")
    func heartbeatCheckTimeouts1000Users() {
        let service = HeartbeatService()
        let now = Date()

        // 注册 1000 个用户，一半超时一半在线
        for i in 0..<1000 {
            let time = i % 2 == 0
                ? now
                : now.addingTimeInterval(-service.timeoutInterval - 10)
            service.recordHeartbeat(userId: UUID(), at: time)
        }

        let duration = measureDuration {
            for _ in 0..<10 {
                service.checkTimeouts(currentTime: now)
            }
        }

        let avgMs = Double(duration.components.attoseconds) / 1e15 / 10.0
        #expect(avgMs < 10, "1000 用户超时检测平均耗时 \(avgMs)ms，超过 10ms 阈值")
    }
}
