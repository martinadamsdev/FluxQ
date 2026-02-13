//
//  TCPMessageService.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/14.
//

import Foundation
import IPMsgProtocol

// MARK: - SocketConnectionProtocol

/// Socket 连接协议，用于依赖注入和测试
public protocol SocketConnectionProtocol: AnyObject, Sendable {
    var isConnected: Bool { get }
    func send(_ data: Data) async throws
    func receive(maxLength: Int) async throws -> Data
    func disconnect()
}

// MARK: - SocketConnection conformance

extension SocketConnection: SocketConnectionProtocol {}

// MARK: - SocketConnectionFactory

/// Socket 连接工厂协议，用于依赖注入和测试
@MainActor
public protocol SocketConnectionFactory: AnyObject {
    func createConnection(host: String, port: Int) async throws -> any SocketConnectionProtocol
}

// MARK: - DefaultSocketConnectionFactory

/// 默认 Socket 连接工厂，创建真实的 TCP 连接
@MainActor
public final class DefaultSocketConnectionFactory: SocketConnectionFactory {
    public init() {}

    public func createConnection(host: String, port: Int) async throws -> any SocketConnectionProtocol {
        try await SocketConnection(host: host, port: port)
    }
}

// MARK: - TCPMessageServiceError

/// TCP 消息服务错误
public enum TCPMessageServiceError: Error, Equatable {
    case sendFailed(host: String, port: Int)
    case encodingFailed
    case maxRetriesExceeded(host: String, port: Int)
}

// MARK: - TCPMessageService

/// TCP 消息服务
///
/// 负责通过 TCP 发送和接收 IPMsg 协议消息，
/// 提供连接池管理和自动重试机制。
@MainActor
public final class TCPMessageService: ObservableObject {
    // MARK: - Properties

    /// 连接池
    private var connectionPool: [String: any SocketConnectionProtocol] = [:]

    /// 连接工厂
    private let connectionFactory: SocketConnectionFactory

    /// 当前数据包编号
    private var packetNumber: Int = 0

    /// 最大重试次数
    private let maxRetries: Int

    /// 基础重试延迟（秒）
    private let baseRetryDelay: TimeInterval

    /// 收到消息的回调
    public var onMessageReceived: ((IPMsgPacket) -> Void)?

    /// 当前活跃连接数
    public var activeConnections: Int {
        connectionPool.count
    }

    // MARK: - Initialization

    public init(
        connectionFactory: SocketConnectionFactory? = nil,
        maxRetries: Int = 3,
        baseRetryDelay: TimeInterval = 1.0
    ) {
        self.connectionFactory = connectionFactory ?? DefaultSocketConnectionFactory()
        self.maxRetries = maxRetries
        self.baseRetryDelay = baseRetryDelay
    }

    // MARK: - Public Methods

    /// 发送消息到指定 IP 和端口
    public func sendMessage(content: String, to ipAddress: String, port: Int) async throws {
        packetNumber += 1

        let packet = IPMsgPacket(
            version: 1,
            packetNo: packetNumber,
            sender: getDeviceName(),
            hostname: getHostname(),
            command: .SENDMSG,
            payload: content
        )

        let encoded = packet.encode()
        guard let data = encoded.data(using: .utf8) else {
            throw TCPMessageServiceError.encodingFailed
        }

        try await sendWithRetry(data: data, to: ipAddress, port: port)
    }

    /// 处理接收到的数据包
    public func handleIncomingPacket(_ packet: IPMsgPacket) {
        onMessageReceived?(packet)
    }

    /// 断开指定主机的连接
    public func disconnect(from host: String) {
        if let connection = connectionPool.removeValue(forKey: host) {
            connection.disconnect()
        }
    }

    /// 断开所有连接
    public func disconnectAll() {
        for (_, connection) in connectionPool {
            connection.disconnect()
        }
        connectionPool.removeAll()
    }

    // MARK: - Private Methods

    private func sendWithRetry(data: Data, to ipAddress: String, port: Int) async throws {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let connection = try await getOrCreateConnection(to: ipAddress, port: port)
                try await connection.send(data)
                return
            } catch {
                lastError = error
                // Remove stale connection so next attempt creates a new one
                connectionPool.removeValue(forKey: ipAddress)

                if attempt < maxRetries - 1 {
                    let delay = baseRetryDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw TCPMessageServiceError.maxRetriesExceeded(host: ipAddress, port: port)
    }

    private func getOrCreateConnection(to host: String, port: Int) async throws -> any SocketConnectionProtocol {
        if let existing = connectionPool[host], existing.isConnected {
            return existing
        }

        // Remove stale connection
        connectionPool.removeValue(forKey: host)

        let connection = try await connectionFactory.createConnection(host: host, port: port)
        connectionPool[host] = connection
        return connection
    }

    private func getDeviceName() -> String {
        #if os(macOS)
        return Host.current().localizedName ?? "Unknown"
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }

    private func getHostname() -> String {
        #if os(macOS)
        return Host.current().name ?? "Unknown"
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }
}
