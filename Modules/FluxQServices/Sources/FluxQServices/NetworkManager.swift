//
//  NetworkManager.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/13.
//

import Foundation
import Network
import IPMsgProtocol

/// 网络管理器
///
/// 负责 UDP 广播用户发现和消息收发
@MainActor
public final class NetworkManager: ObservableObject {
    // MARK: - Properties

    /// 发现的用户
    @Published public private(set) var discoveredUsers: [String: DiscoveredUser] = [:]

    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]
    private var packetNumber: Int = 0

    // MARK: - Initialization

    public init(port: UInt16 = 2425) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    // MARK: - Public Methods

    /// 启动网络服务
    public func start() throws {
        // 创建 UDP 监听器
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters, on: port)

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

        // 发送上线广播
        try sendBroadcast(command: .BR_ENTRY)
    }

    /// 停止网络服务
    public func stop() {
        // 发送下线广播
        try? sendBroadcast(command: .BR_EXIT)

        // 停止监听器
        listener?.cancel()
        listener = nil

        // 关闭所有连接
        connections.values.forEach { $0.cancel() }
        connections.removeAll()

        // 清空发现的用户
        discoveredUsers.removeAll()
    }

    /// 发送广播
    public func sendBroadcast(command: IPMsgCommand, payload: String = "") throws {
        let packet = createPacket(command: command, payload: payload)
        let message = packet.encode().data(using: .utf8)!

        // 创建广播连接
        let host = NWEndpoint.Host("255.255.255.255")
        let connection = NWConnection(
            host: host,
            port: port,
            using: .udp
        )

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                connection.send(
                    content: message,
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

    /// 发送消息给指定用户
    public func sendMessage(to user: DiscoveredUser, message: String) async throws {
        let packet = createPacket(command: .SENDMSG, payload: message)
        let data = packet.encode().data(using: .utf8)!

        let connection = getOrCreateConnection(to: user)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: IPMsgError.networkError(error.localizedDescription))
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    // MARK: - Private Methods

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("NetworkManager: 监听器已就绪，端口 \(port)")
        case .failed(let error):
            print("NetworkManager: 监听器失败 - \(error)")
        case .cancelled:
            print("NetworkManager: 监听器已取消")
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
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
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("NetworkManager: 接收消息错误 - \(error)")
                    return
                }

                if let data = data, let message = String(data: data, encoding: .utf8) {
                    self.handleReceivedMessage(message, from: connection)
                }

                // 继续接收下一条消息
                if !isComplete {
                    self.receiveMessage(from: connection)
                }
            }
        }
    }

    private func handleReceivedMessage(_ message: String, from connection: NWConnection) {
        do {
            let packet = try IPMsgPacket.decode(message)

            // 处理不同类型的命令
            switch packet.command {
            case .BR_ENTRY, .ANSENTRY:
                handleUserEntry(packet, from: connection)
            case .BR_EXIT:
                handleUserExit(packet)
            case .SENDMSG:
                handleMessage(packet)
            default:
                break
            }
        } catch {
            print("NetworkManager: 解析消息失败 - \(error)")
        }
    }

    private func handleUserEntry(_ packet: IPMsgPacket, from connection: NWConnection) {
        // 从连接中获取 IP 地址
        guard case let .hostPort(host, _) = connection.endpoint else { return }

        let user = DiscoveredUser(
            id: packet.sender,
            nickname: packet.sender,
            hostname: packet.hostname,
            ipAddress: host.debugDescription
        )

        discoveredUsers[user.id] = user

        // 如果是 BR_ENTRY，回应 ANSENTRY
        if packet.command == .BR_ENTRY {
            try? sendBroadcast(command: .ANSENTRY)
        }
    }

    private func handleUserExit(_ packet: IPMsgPacket) {
        discoveredUsers.removeValue(forKey: packet.sender)
    }

    private func handleMessage(_ packet: IPMsgPacket) {
        // TODO: 处理接收到的消息
        print("NetworkManager: 收到消息 - \(packet.payload)")

        // 发送接收确认
        try? sendBroadcast(command: .RECVMSG, payload: "\(packet.packetNo)")
    }

    private func createPacket(command: IPMsgCommand, payload: String) -> IPMsgPacket {
        packetNumber += 1

        return IPMsgPacket(
            version: 1,
            packetNo: packetNumber,
            sender: getDeviceName(),
            hostname: getHostname(),
            command: command,
            payload: payload
        )
    }

    private func getOrCreateConnection(to user: DiscoveredUser) -> NWConnection {
        if let existing = connections[user.id] {
            return existing
        }

        let host = NWEndpoint.Host(user.ipAddress)
        let connection = NWConnection(
            host: host,
            port: NWEndpoint.Port(rawValue: UInt16(user.port))!,
            using: .udp
        )

        connection.start(queue: .main)
        connections[user.id] = connection

        return connection
    }

    private func getDeviceName() -> String {
        #if os(macOS)
        return Host.current().localizedName ?? "Unknown"
        #elseif os(iOS)
        return UIDevice.current.name
        #elseif os(watchOS)
        return WKInterfaceDevice.current().name
        #else
        return "Unknown"
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
