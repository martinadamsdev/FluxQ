import Testing
import Foundation
@testable import FluxQ

@Suite("NotificationDelegate Tests")
struct NotificationDelegateTests {

    @Test("有效 UUID 字符串解析成功")
    func parsesValidUUID() {
        let id = UUID()
        let userInfo: [AnyHashable: Any] = ["conversationId": id.uuidString]
        let result = NotificationDelegate.parseConversationId(from: userInfo)
        #expect(result == id)
    }

    @Test("无效 UUID 字符串返回 nil")
    func invalidUUIDReturnsNil() {
        let userInfo: [AnyHashable: Any] = ["conversationId": "not-a-uuid"]
        let result = NotificationDelegate.parseConversationId(from: userInfo)
        #expect(result == nil)
    }

    @Test("缺少 conversationId key 返回 nil")
    func missingKeyReturnsNil() {
        let userInfo: [AnyHashable: Any] = ["otherKey": "value"]
        let result = NotificationDelegate.parseConversationId(from: userInfo)
        #expect(result == nil)
    }

    @Test("空 userInfo 返回 nil")
    func emptyUserInfoReturnsNil() {
        let userInfo: [AnyHashable: Any] = [:]
        let result = NotificationDelegate.parseConversationId(from: userInfo)
        #expect(result == nil)
    }

    @Test("非字符串类型的 conversationId 返回 nil")
    func nonStringValueReturnsNil() {
        let userInfo: [AnyHashable: Any] = ["conversationId": 12345]
        let result = NotificationDelegate.parseConversationId(from: userInfo)
        #expect(result == nil)
    }
}
