//
//  NetworkTransport.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/14.
//

import Foundation
import Network

/// 监听器状态
public enum ListenerState: Sendable {
    case ready
    case failed(Error)
    case cancelled
}

/// 网络传输抽象协议，用于依赖注入和测试
@MainActor
public protocol NetworkTransport: AnyObject {
    /// 开始监听指定端口
    func startListening(port: UInt16) throws

    /// 停止监听
    func stopListening()

    /// 发送数据到指定地址
    func send(data: Data, to host: String, port: UInt16) async throws

    /// 发送广播数据
    func sendBroadcast(data: Data, port: UInt16) throws

    /// 收到数据的回调
    var onDataReceived: ((Data, String) -> Void)? { get set }

    /// 监听器状态变化回调
    var onListenerStateChanged: ((ListenerState) -> Void)? { get set }

    /// 新连接到达回调（诊断用）
    var onNewConnection: ((String) -> Void)? { get set }
}

// MARK: - NWNetworkTransport

/// 基于 Network.framework 的真实网络传输实现
@MainActor
public final class NWNetworkTransport: NetworkTransport {
    public var onDataReceived: ((Data, String) -> Void)?
    public var onListenerStateChanged: ((ListenerState) -> Void)?
    public var onNewConnection: ((String) -> Void)?

    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]

    public init() {}

    public func startListening(port: UInt16) throws {
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters, on: nwPort)

        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleListenerState(state)
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleNewConnection(connection)
            }
        }

        listener.start(queue: .main)
        self.listener = listener
    }

    public func stopListening() {
        listener?.cancel()
        listener = nil

        connections.values.forEach { $0.cancel() }
        connections.removeAll()
    }

    public func send(data: Data, to host: String, port: UInt16) async throws {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let connection: NWConnection
        if let existing = connections[host] {
            connection = existing
        } else {
            connection = NWConnection(host: nwHost, port: nwPort, using: .udp)
            connection.start(queue: .main)
            connections[host] = connection
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    public func sendBroadcast(data: Data, port: UInt16) throws {
        let host = NWEndpoint.Host("255.255.255.255")
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let connection = NWConnection(host: host, port: nwPort, using: .udp)

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                connection.send(
                    content: data,
                    completion: .contentProcessed { error in
                        if let error = error {
                            print("发送广播失败: \(error)")
                        }
                        connection.cancel()
                    }
                )
            }
        }

        connection.start(queue: .main)
    }

    // MARK: - Private

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            onListenerStateChanged?(.ready)
        case .failed(let error):
            onListenerStateChanged?(.failed(error))
        case .cancelled:
            onListenerStateChanged?(.cancelled)
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let endpointDesc = "\(connection.endpoint)"
        onNewConnection?(endpointDesc)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .ready = state {
                    self?.receiveMessage(from: connection)
                }
            }
        }
        connection.start(queue: .main)
    }

    private func receiveMessage(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("NWNetworkTransport: 接收消息错误 - \(error)")
                    return
                }

                if let data = data {
                    // 从连接端点提取主机地址
                    // debugDescription 可能返回带引号的 IP (如 "192.168.1.5")，需要清理
                    let host: String
                    if case let .hostPort(h, _) = connection.endpoint {
                        host = h.debugDescription.replacingOccurrences(of: "\"", with: "")
                    } else {
                        host = "unknown"
                    }
                    self.onDataReceived?(data, host)
                }

                // UDP datagrams are always "complete", so keep listening
                // for subsequent messages from the same source
                self.receiveMessage(from: connection)
            }
        }
    }
}

// MARK: - MockNetworkTransport

/// Mock 网络传输，用于单元测试
@MainActor
public final class MockNetworkTransport: NetworkTransport {
    public var onDataReceived: ((Data, String) -> Void)?
    public var onListenerStateChanged: ((ListenerState) -> Void)?
    public var onNewConnection: ((String) -> Void)?

    public private(set) var isListening = false
    public private(set) var listeningPort: UInt16?
    public private(set) var sentMessages: [(data: Data, host: String, port: UInt16)] = []
    public private(set) var broadcastMessages: [(data: Data, port: UInt16)] = []
    public var shouldFailOnSend = false
    public var shouldFailOnListen = false

    public init() {}

    public func startListening(port: UInt16) throws {
        if shouldFailOnListen {
            throw NSError(
                domain: "MockNetworkTransport", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mock listen failure"])
        }
        isListening = true
        listeningPort = port
        onListenerStateChanged?(.ready)
    }

    public func stopListening() {
        isListening = false
        listeningPort = nil
        onListenerStateChanged?(.cancelled)
    }

    public func send(data: Data, to host: String, port: UInt16) async throws {
        if shouldFailOnSend {
            throw NSError(
                domain: "MockNetworkTransport", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Mock send failure"])
        }
        sentMessages.append((data: data, host: host, port: port))
    }

    public func sendBroadcast(data: Data, port: UInt16) throws {
        if shouldFailOnSend {
            throw NSError(
                domain: "MockNetworkTransport", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Mock broadcast failure"])
        }
        broadcastMessages.append((data: data, port: port))
    }

    /// 模拟接收数据（测试用）
    public func simulateReceive(data: Data, from host: String) {
        onDataReceived?(data, host)
    }
}
