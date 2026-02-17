import Foundation
import UserNotifications

@MainActor
final class NotificationService {

    static let shared = NotificationService()

    private init() {}

    /// 请求通知权限
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error {
                print("NotificationService: 权限请求失败 - \(error)")
            }
        }
    }

    /// 发送本地通知
    func sendNotification(
        title: String,
        body: String,
        conversationId: UUID,
        soundName: String = "Glass"
    ) {
        let content = Self.buildNotificationContent(
            title: title, body: body, conversationId: conversationId
        )

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("NotificationService: 发送通知失败 - \(error)")
            }
        }
    }

    /// 构建通知内容（纯函数，无需 MainActor）
    nonisolated static func buildNotificationContent(
        title: String,
        body: String,
        conversationId: UUID
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["conversationId": conversationId.uuidString]
        return content
    }
}
