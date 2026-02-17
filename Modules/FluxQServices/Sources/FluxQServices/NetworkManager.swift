//
//  NetworkManager.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/13.
//

import Foundation
import Network
import IPMsgProtocol

#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// 收到的消息
public struct ReceivedMessage: Identifiable, Sendable {
    public let id = UUID()
    public let senderName: String
    public let hostname: String
    public let fromHost: String
    public let content: String
    public let packetNo: Int
    public let receivedAt: Date
}

/// 网络管理器
///
/// 负责 UDP 广播用户发现和消息收发
@MainActor
public final class NetworkManager: ObservableObject {
    // MARK: - Properties

    /// 发现的用户
    @Published public private(set) var discoveredUsers: [String: DiscoveredUser] = [:]

    /// 收到的消息列表
    @Published public private(set) var receivedMessages: [ReceivedMessage] = []

    /// 收到的撤回请求
    @Published public private(set) var receivedRecalls: [String] = []

    /// 网络状态（用于 UI 调试）
    @Published public private(set) var networkStatus: String = "未启动"

    private let portNumber: UInt16
    private let transport: NetworkTransport
    private var packetNumber: Int = Int(Date().timeIntervalSince1970)
    /// 本实例的唯一标识，用于过滤自身广播回环
    private let instanceId = UUID()
    private var receivedPacketCount: Int = 0
    private var filteredSelfCount: Int = 0
    private var broadcastSentCount: Int = 0
    private var listenerReady: Bool = false
    private var newConnectionCount: Int = 0

    // MARK: - Initialization

    public init(port: UInt16 = 2425, transport: NetworkTransport? = nil) {
        self.portNumber = port
        self.transport = transport ?? NWNetworkTransport()
        setupTransportCallbacks()
    }

    private func setupTransportCallbacks() {
        transport.onDataReceived = { [weak self] data, host in
            guard let self = self else { return }
            if let message = String(data: data, encoding: .utf8) {
                self.handleReceivedMessage(message, fromHost: host)
            }
        }

        transport.onListenerStateChanged = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.listenerReady = true
                self.networkStatus = "监听就绪 (端口 \(self.portNumber)), 已广播\(self.broadcastSentCount)次, 等待数据..."
            case .failed(let error):
                self.listenerReady = false
                self.networkStatus = "监听器失败: \(error)"
            case .cancelled:
                self.listenerReady = false
                self.networkStatus = "监听器已取消"
            }
        }

        transport.onNewConnection = { [weak self] endpoint in
            guard let self else { return }
            self.newConnectionCount += 1
            if self.receivedPacketCount == 0 {
                self.networkStatus = "新连接#\(self.newConnectionCount) from \(endpoint), 等待数据..."
            }
        }
    }

    // MARK: - Public Methods

    /// 启动网络服务
    public func start() throws {
        networkStatus = "正在启动监听..."
        do {
            try transport.startListening(port: portNumber)
        } catch {
            networkStatus = "监听失败: \(error.localizedDescription)"
            throw error
        }

        // 发送上线广播
        try sendBroadcast(command: .BR_ENTRY)
        networkStatus = "已广播, 等待监听器就绪... (端口 \(portNumber))"
    }

    /// 重新广播发现请求
    public func refreshDiscovery() throws {
        try sendBroadcast(command: .BR_ENTRY)
    }

    /// 停止网络服务
    public func stop() {
        // 发送下线广播
        try? sendBroadcast(command: .BR_EXIT)

        // 停止监听器
        transport.stopListening()

        // 清空发现的用户
        discoveredUsers.removeAll()
    }

    /// 发送广播
    public func sendBroadcast(command: IPMsgCommand, payload: String = "") throws {
        let packet = createPacket(command: command, payload: payload)
        let data = packet.encode().data(using: .utf8)!

        try transport.sendBroadcast(data: data, port: portNumber)
        broadcastSentCount += 1

        // 如果监听器已就绪但还没收到数据，更新状态显示广播次数
        if listenerReady && receivedPacketCount == 0 {
            networkStatus = "监听就绪 (端口 \(portNumber)), 已广播\(broadcastSentCount)次, 收到0包"
        }
    }

    /// 发送单播到指定主机
    public func sendToHost(_ host: String, command: IPMsgCommand, payload: String = "") async {
        let packet = createPacket(command: command, payload: payload)
        guard let data = packet.encode().data(using: .utf8) else { return }
        try? await transport.send(data: data, to: host, port: portNumber)
    }

    /// 发送消息给指定用户
    public func sendMessage(to user: DiscoveredUser, message: String) async throws {
        let packet = createPacket(command: .SENDMSG, payload: message)
        let data = packet.encode().data(using: .utf8)!

        try await transport.send(data: data, to: user.ipAddress, port: UInt16(user.port))
    }

    // MARK: - Private Methods

    private func handleReceivedMessage(_ message: String, fromHost host: String) {
        receivedPacketCount += 1
        do {
            let packet = try IPMsgPacket.decode(message)

            // 从 payload 中提取发送者实例 UUID，过滤自身广播回环
            let (cleanPayload, senderInstanceId) = parsePayload(packet.payload)
            if senderInstanceId == instanceId.uuidString {
                filteredSelfCount += 1
                networkStatus = "收到\(receivedPacketCount)包(自身\(filteredSelfCount)) 广播\(broadcastSentCount)次 用户\(discoveredUsers.count)"
                return
            }

            // 用清理后的 payload 构建干净的 packet
            let cleanPacket = IPMsgPacket(
                version: packet.version,
                packetNo: packet.packetNo,
                sender: packet.sender,
                hostname: packet.hostname,
                command: packet.command,
                payload: cleanPayload
            )

            switch cleanPacket.command {
            case .BR_ENTRY, .ANSENTRY:
                handleUserEntry(cleanPacket, fromHost: host)
            case .BR_EXIT:
                handleUserExit(cleanPacket)
            case .SENDMSG:
                handleMessage(cleanPacket, fromHost: host)
            case .RECALLMSG:
                receivedRecalls.append(cleanPacket.payload)
            default:
                break
            }
            networkStatus = "收到\(receivedPacketCount)包(自身\(filteredSelfCount)) 广播\(broadcastSentCount)次 用户\(discoveredUsers.count)"
        } catch {
            networkStatus = "解析失败(收到\(receivedPacketCount)包): \(error)"
        }
    }

    private func handleUserEntry(_ packet: IPMsgPacket, fromHost host: String) {
        let existingId = discoveredUsers[packet.sender]?.id
        let user = DiscoveredUser(
            id: existingId ?? UUID(),
            senderName: packet.sender,
            nickname: packet.sender,
            hostname: packet.hostname,
            ipAddress: host
        )

        discoveredUsers[packet.sender] = user

        // 如果是 BR_ENTRY，单播 ANSENTRY 回复发送者
        if packet.command == .BR_ENTRY {
            Task {
                await sendToHost(host, command: .ANSENTRY)
            }
        }
    }

    private func handleUserExit(_ packet: IPMsgPacket) {
        discoveredUsers.removeValue(forKey: packet.sender)
    }

    private func handleMessage(_ packet: IPMsgPacket, fromHost host: String) {
        print("NetworkManager: 收到来自 \(packet.sender) 的消息 - \(packet.payload)")

        // 通知 UI 层收到新消息
        let receivedMsg = ReceivedMessage(
            senderName: packet.sender,
            hostname: packet.hostname,
            fromHost: host,
            content: packet.payload,
            packetNo: packet.packetNo,
            receivedAt: Date()
        )
        receivedMessages.append(receivedMsg)

        // 单播发送接收确认
        Task {
            await sendToHost(host, command: .RECVMSG, payload: "\(packet.packetNo)")
        }
    }

    private func createPacket(command: IPMsgCommand, payload: String) -> IPMsgPacket {
        packetNumber += 1

        // 将实例 UUID 附加在 payload 的 \0 之后（IP Messenger 扩展数据标准格式）
        let extendedPayload = payload + "\0" + instanceId.uuidString

        return IPMsgPacket(
            version: 1,
            packetNo: packetNumber,
            sender: getDeviceName(),
            hostname: getHostname(),
            command: command,
            payload: extendedPayload
        )
    }

    /// 从 payload 中分离出原始内容和发送者实例 UUID
    private func parsePayload(_ payload: String) -> (content: String, senderInstanceId: String?) {
        let parts = payload.split(separator: "\0", maxSplits: 1, omittingEmptySubsequences: false)
        let content = String(parts.first ?? "")
        let senderId = parts.count > 1 ? String(parts[1]) : nil
        return (content, senderId)
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
