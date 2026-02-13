//
//  IPMsgPacket.swift
//  IPMsgProtocol
//
//  Created by martinadamsdev on 2026/2/13.
//

import Foundation

/// IPMsg 协议数据包
///
/// 格式: "version:packetNo:sender:hostname:command:payload"
public struct IPMsgPacket: Sendable {
    public let version: Int
    public let packetNo: Int
    public let sender: String
    public let hostname: String
    public let command: IPMsgCommand
    public let payload: String

    public init(
        version: Int,
        packetNo: Int,
        sender: String,
        hostname: String,
        command: IPMsgCommand,
        payload: String
    ) {
        self.version = version
        self.packetNo = packetNo
        self.sender = sender
        self.hostname = hostname
        self.command = command
        self.payload = payload
    }

    /// 编码为字符串
    public func encode() -> String {
        "\(version):\(packetNo):\(sender):\(hostname):\(command.rawValue):\(payload)"
    }

    /// 从字符串解码
    public static func decode(_ message: String) throws -> IPMsgPacket {
        let parts = message.split(separator: ":", maxSplits: 5).map(String.init)

        guard parts.count == 6 else {
            throw IPMsgError.invalidFormat("Expected 6 parts, got \(parts.count)")
        }

        guard let version = Int(parts[0]) else {
            throw IPMsgError.invalidFormat("Invalid version: \(parts[0])")
        }

        guard let packetNo = Int(parts[1]) else {
            throw IPMsgError.invalidFormat("Invalid packetNo: \(parts[1])")
        }

        guard let commandValue = Int(parts[4]) else {
            throw IPMsgError.invalidFormat("Invalid command: \(parts[4])")
        }

        guard let command = IPMsgCommand(rawValue: commandValue) else {
            throw IPMsgError.invalidCommand(commandValue)
        }

        return IPMsgPacket(
            version: version,
            packetNo: packetNo,
            sender: parts[2],
            hostname: parts[3],
            command: command,
            payload: parts[5]
        )
    }
}

// MARK: - Equatable
extension IPMsgPacket: Equatable {
    public static func == (lhs: IPMsgPacket, rhs: IPMsgPacket) -> Bool {
        lhs.version == rhs.version &&
        lhs.packetNo == rhs.packetNo &&
        lhs.sender == rhs.sender &&
        lhs.hostname == rhs.hostname &&
        lhs.command == rhs.command &&
        lhs.payload == rhs.payload
    }
}
