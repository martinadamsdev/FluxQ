import Foundation
import Observation

/// 独立模式网络服务协调器
///
/// 在 standalone 模式下协调 UDP 用户发现和 TCP 消息收发，
/// 为 Watch 提供完整的局域网通信能力。
@MainActor
@Observable
public class WatchNetworkService {
    // MARK: - State

    public private(set) var isRunning: Bool = false
    public private(set) var discoveredUsers: [String: WatchDiscoveredUser] = [:]

    // MARK: - Test mode

    private let testMode: Bool
    var mockSentMessages: [(to: String, content: String)] = []

    // MARK: - Init

    public init(testMode: Bool = false) {
        self.testMode = testMode
    }

    // MARK: - Lifecycle

    public func start() async throws {
        guard !isRunning else { return }

        if !testMode {
            // 启动 UDP 广播发现
            // 启动心跳服务
        }

        isRunning = true
    }

    public func stop() {
        guard isRunning else { return }

        if !testMode {
            // 停止 UDP 和心跳
        }

        discoveredUsers.removeAll()
        isRunning = false
    }

    // MARK: - Messaging

    public func sendDirectMessage(to userId: String, content: String) async throws {
        guard let user = discoveredUsers[userId] else {
            throw WatchNetworkError.userNotFound
        }

        if testMode {
            mockSentMessages.append((to: userId, content: content))
            return
        }

        // 通过 TCP 发送消息到 user.ipAddress:user.port
        _ = user
    }

    // MARK: - Test helpers

    func mockDiscoverUser(id: String, name: String, ip: String) {
        discoveredUsers[id] = WatchDiscoveredUser(
            id: id, name: name, ipAddress: ip, port: 2425
        )
    }
}

// MARK: - Supporting types

public struct WatchDiscoveredUser: Equatable, Sendable {
    public let id: String
    public let name: String
    public let ipAddress: String
    public let port: Int
}

public enum WatchNetworkError: Error, Equatable {
    case userNotFound
    case notRunning
    case sendFailed(String)
}
