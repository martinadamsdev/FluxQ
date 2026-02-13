// FluxQWatch/Services/QuickReplyService.swift
import Foundation
import Observation

/// 快速回复模板
public struct QuickReply: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let isCustom: Bool
    public let category: Category

    public enum Category: String, Sendable {
        case general    // 通用
        case greeting   // 问候
        case confirm    // 确认
        case reject     // 拒绝
        case emoji      // 表情
    }

    public init(id: UUID = UUID(), text: String, isCustom: Bool = false, category: Category = .general) {
        self.id = id
        self.text = text
        self.isCustom = isCustom
        self.category = category
    }
}

/// 快速回复服务
///
/// 管理预定义和自定义快速回复模板。
@MainActor
@Observable
public class QuickReplyService {
    // MARK: - State

    public private(set) var quickReplies: [QuickReply] = []

    // MARK: - Init

    public init() {
        quickReplies = Self.defaultReplies
    }

    // MARK: - Public Methods

    /// 添加自定义回复
    public func addCustomReply(_ text: String) {
        let reply = QuickReply(text: text, isCustom: true)
        quickReplies.append(reply)
    }

    /// 移除回复（仅自定义回复可移除）
    public func removeReply(id: UUID) {
        quickReplies.removeAll { $0.id == id && $0.isCustom }
    }

    /// 根据上下文获取相关快速回复
    public func contextualReplies(for lastMessage: String) -> [QuickReply] {
        let lower = lastMessage.lowercased()
        let isGreeting = lower.contains("好") || lower.contains("早") || lower.contains("hi") || lower.contains("hello")
        let isQuestion = lower.contains("吗") || lower.contains("？") || lower.contains("?")

        var result: [QuickReply] = []

        if isGreeting {
            result += quickReplies.filter { $0.category == .greeting }
        }
        if isQuestion {
            result += quickReplies.filter { $0.category == .confirm || $0.category == .reject }
        }

        // 始终包含通用回复
        result += quickReplies.filter { $0.category == .general }

        // 去重
        var seen = Set<UUID>()
        return result.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Default Replies

    static let defaultReplies: [QuickReply] = [
        QuickReply(text: "好的", category: .confirm),
        QuickReply(text: "收到", category: .confirm),
        QuickReply(text: "稍等", category: .general),
        QuickReply(text: "谢谢", category: .general),
        QuickReply(text: "不行", category: .reject),
        QuickReply(text: "再说吧", category: .reject),
        QuickReply(text: "早上好", category: .greeting),
        QuickReply(text: "👍", category: .emoji),
        QuickReply(text: "👌", category: .emoji),
    ]
}
