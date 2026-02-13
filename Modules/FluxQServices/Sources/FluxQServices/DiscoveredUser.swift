//
//  DiscoveredUser.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/13.
//

import Foundation
import FluxQModels

/// 通过网络发现的用户
///
/// 这是一个轻量级模型，用于表示通过 UDP 广播发现的用户。
/// 可以转换为持久化的 User 模型。
public struct DiscoveredUser: Sendable, Identifiable, Equatable {
    public let id: String
    public let nickname: String
    public let hostname: String
    public let ipAddress: String
    public let port: Int
    public let group: String?
    public let discoveredAt: Date

    public init(
        id: String,
        nickname: String,
        hostname: String,
        ipAddress: String,
        port: Int = 2425,
        group: String? = nil,
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.nickname = nickname
        self.hostname = hostname
        self.ipAddress = ipAddress
        self.port = port
        self.group = group
        self.discoveredAt = discoveredAt
    }

    /// 转换为持久化的 User 模型
    public func toUser() -> User {
        User(
            id: id,
            nickname: nickname,
            hostname: hostname,
            ipAddress: ipAddress,
            port: port,
            group: group,
            status: .online,
            isOnline: true,
            lastSeen: discoveredAt
        )
    }
}
