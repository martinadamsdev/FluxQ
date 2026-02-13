// FluxQWatch/Services/ComplicationDataProvider.swift
import Foundation
import Observation

/// 表盘 Complication 数据提供器
///
/// 追踪各会话未读消息数，为 WidgetKit Complication 提供展示数据。
@MainActor
@Observable
public class ComplicationDataProvider {
    // MARK: - State

    /// 各会话未读消息数
    private var unreadCounts: [UUID: Int] = [:]

    /// 总未读数
    public var totalUnreadCount: Int {
        unreadCounts.values.reduce(0, +)
    }

    /// Complication 展示文本
    public var displayText: String {
        totalUnreadCount > 0 ? "\(totalUnreadCount)" : ""
    }

    /// 短展示文本（小尺寸 Complication 用）
    public var shortDisplayText: String {
        if totalUnreadCount > 99 {
            return "99+"
        }
        return totalUnreadCount > 0 ? "\(totalUnreadCount)" : ""
    }

    // MARK: - Init

    public init() {}

    // MARK: - Public Methods

    /// 更新指定会话的未读数
    public func updateUnreadCount(for conversationId: UUID, count: Int) {
        unreadCounts[conversationId] = count
    }

    /// 标记指定会话为已读
    public func markAsRead(conversationId: UUID) {
        unreadCounts.removeValue(forKey: conversationId)
    }

    /// 标记所有会话为已读
    public func markAllAsRead() {
        unreadCounts.removeAll()
    }

    /// 增加指定会话的未读数
    public func incrementUnread(for conversationId: UUID) {
        unreadCounts[conversationId, default: 0] += 1
    }
}
