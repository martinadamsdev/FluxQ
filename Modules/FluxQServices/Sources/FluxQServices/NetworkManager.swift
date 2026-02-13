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

/// 网络管理器
///
/// 负责 UDP 广播用户发现和消息收发
@MainActor
public final class NetworkManager: ObservableObject {
    // MARK: - Properties

    /// 发现的用户
    @Published public private(set) var discoveredUsers: [String: DiscoveredUser] = [:]

    private let portNumber: UInt16
    private let transport: NetworkTransport
    private var packetNumber: Int = 0

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
            _ = self
            switch state {
            case .ready:
                print("NetworkManager: 监听器已就绪")
            case .failed(let error):
                print("NetworkManager: 监听器失败 - \(error)")
            case .cancelled:
                print("NetworkManager: 监听器已取消")
            }
        }
    }

    // MARK: - Public Methods

    /// 启动网络服务
    public func start() throws {
        try transport.startListening(port: portNumber)

        // 发送上线广播
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
    }

    /// 发送消息给指定用户
    public func sendMessage(to user: DiscoveredUser, message: String) async throws {
        let packet = createPacket(command: .SENDMSG, payload: message)
        let data = packet.encode().data(using: .utf8)!

        try await transport.send(data: data, to: user.ipAddress, port: UInt16(user.port))
    }

    // MARK: - Private Methods

    private func handleReceivedMessage(_ message: String, fromHost host: String) {
        do {
            let packet = try IPMsgPacket.decode(message)

            switch packet.command {
            case .BR_ENTRY, .ANSENTRY:
                handleUserEntry(packet, fromHost: host)
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
