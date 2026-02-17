import Testing
import Foundation
import UserNotifications
@testable import FluxQ

@Suite("NotificationService Content Tests")
struct NotificationServiceTests {

    @Test("buildNotificationContent 设置正确的标题和正文")
    func contentTitleAndBody() {
        let content = NotificationService.buildNotificationContent(
            title: "Alice", body: "你好", conversationId: UUID()
        )
        #expect(content.title == "Alice")
        #expect(content.body == "你好")
    }

    @Test("buildNotificationContent 设置默认声音")
    func contentHasDefaultSound() {
        let content = NotificationService.buildNotificationContent(
            title: "Test", body: "msg", conversationId: UUID()
        )
        #expect(content.sound == .default)
    }

    @Test("buildNotificationContent 在 userInfo 中编码 conversationId")
    func contentEncodesConversationId() {
        let id = UUID()
        let content = NotificationService.buildNotificationContent(
            title: "Test", body: "msg", conversationId: id
        )
        let stored = content.userInfo["conversationId"] as? String
        #expect(stored == id.uuidString)
    }

    @Test("conversationId 可从 userInfo 往返解析")
    func conversationIdRoundTrip() {
        let id = UUID()
        let content = NotificationService.buildNotificationContent(
            title: "T", body: "B", conversationId: id
        )
        let parsed = NotificationDelegate.parseConversationId(from: content.userInfo)
        #expect(parsed == id)
    }
}
