import Foundation

/// 通知处理的纯决策逻辑 — 无系统框架依赖，可单元测试
enum NotificationHandler {

    struct Action: Equatable {
        let shouldPlaySound: Bool
        let shouldSendNotification: Bool
    }

    /// 根据当前状态决定是否播放提示音和发送通知
    static func determineAction(
        conversationId: UUID?,
        activeConversationId: UUID?,
        isSoundEnabled: Bool,
        isAppActive: Bool
    ) -> Action {
        // 用户正在查看该对话，跳过一切
        if let conversationId,
           activeConversationId == conversationId {
            return Action(shouldPlaySound: false, shouldSendNotification: false)
        }

        return Action(
            shouldPlaySound: isSoundEnabled,
            shouldSendNotification: !isAppActive && conversationId != nil
        )
    }

    /// 从 UserDefaults 读取声音启用设置（默认 true）
    static func isSoundEnabled(from defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: "notification.soundEnabled") == nil {
            return true
        }
        return defaults.bool(forKey: "notification.soundEnabled")
    }

    /// 从 UserDefaults 读取声音名称（默认 "Glass"）
    static func soundName(from defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: "notification.soundName") ?? "Glass"
    }
}
