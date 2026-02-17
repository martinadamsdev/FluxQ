import Testing
import Foundation
@testable import FluxQ

@Suite("NotificationHandler Tests")
struct NotificationHandlerTests {

    // MARK: - determineAction

    @Test("正在查看的对话不播放也不通知")
    func activeConversationSkipsAll() {
        let id = UUID()
        let action = NotificationHandler.determineAction(
            conversationId: id,
            activeConversationId: id,
            isSoundEnabled: true,
            isAppActive: false
        )
        #expect(action.shouldPlaySound == false)
        #expect(action.shouldSendNotification == false)
    }

    @Test("不同对话 ID 时正常播放和通知")
    func differentConversationPlaysAndNotifies() {
        let action = NotificationHandler.determineAction(
            conversationId: UUID(),
            activeConversationId: UUID(),
            isSoundEnabled: true,
            isAppActive: false
        )
        #expect(action.shouldPlaySound == true)
        #expect(action.shouldSendNotification == true)
    }

    @Test("声音关闭时不播放但仍可通知")
    func soundDisabledSkipsSound() {
        let action = NotificationHandler.determineAction(
            conversationId: UUID(),
            activeConversationId: nil,
            isSoundEnabled: false,
            isAppActive: false
        )
        #expect(action.shouldPlaySound == false)
        #expect(action.shouldSendNotification == true)
    }

    @Test("App 活跃时不发送通知但播放声音")
    func appActiveSkipsNotification() {
        let action = NotificationHandler.determineAction(
            conversationId: UUID(),
            activeConversationId: nil,
            isSoundEnabled: true,
            isAppActive: true
        )
        #expect(action.shouldPlaySound == true)
        #expect(action.shouldSendNotification == false)
    }

    @Test("conversationId 为 nil 时不发送通知")
    func nilConversationSkipsNotification() {
        let action = NotificationHandler.determineAction(
            conversationId: nil,
            activeConversationId: nil,
            isSoundEnabled: true,
            isAppActive: false
        )
        #expect(action.shouldPlaySound == true)
        #expect(action.shouldSendNotification == false)
    }

    @Test("activeConversationId 为 nil 时正常处理")
    func nilActiveConversationPlays() {
        let action = NotificationHandler.determineAction(
            conversationId: UUID(),
            activeConversationId: nil,
            isSoundEnabled: true,
            isAppActive: false
        )
        #expect(action.shouldPlaySound == true)
        #expect(action.shouldSendNotification == true)
    }

    // MARK: - isSoundEnabled

    @Test("未设置时默认为 true")
    func soundEnabledDefaultTrue() {
        let defaults = UserDefaults(suiteName: "test-soundEnabled-default")!
        defaults.removeObject(forKey: "notification.soundEnabled")
        let result = NotificationHandler.isSoundEnabled(from: defaults)
        #expect(result == true)
        defaults.removeSuite(named: "test-soundEnabled-default")
    }

    @Test("设置为 false 时返回 false")
    func soundEnabledSetFalse() {
        let defaults = UserDefaults(suiteName: "test-soundEnabled-false")!
        defaults.set(false, forKey: "notification.soundEnabled")
        let result = NotificationHandler.isSoundEnabled(from: defaults)
        #expect(result == false)
        defaults.removeSuite(named: "test-soundEnabled-false")
    }

    @Test("设置为 true 时返回 true")
    func soundEnabledSetTrue() {
        let defaults = UserDefaults(suiteName: "test-soundEnabled-true")!
        defaults.set(true, forKey: "notification.soundEnabled")
        let result = NotificationHandler.isSoundEnabled(from: defaults)
        #expect(result == true)
        defaults.removeSuite(named: "test-soundEnabled-true")
    }

    // MARK: - soundName

    @Test("未设置时默认为 Glass")
    func soundNameDefault() {
        let defaults = UserDefaults(suiteName: "test-soundName-default")!
        defaults.removeObject(forKey: "notification.soundName")
        let result = NotificationHandler.soundName(from: defaults)
        #expect(result == "Glass")
        defaults.removeSuite(named: "test-soundName-default")
    }

    @Test("设置自定义音效名")
    func soundNameCustom() {
        let defaults = UserDefaults(suiteName: "test-soundName-custom")!
        defaults.set("Ping", forKey: "notification.soundName")
        let result = NotificationHandler.soundName(from: defaults)
        #expect(result == "Ping")
        defaults.removeSuite(named: "test-soundName-custom")
    }
}
