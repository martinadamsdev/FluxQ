// FluxQWatchTests/QuickReplyServiceTests.swift
import Testing
import Foundation
@testable import FluxQWatch

@MainActor
@Test("Provide default quick replies")
func testDefaultQuickReplies() {
    let service = QuickReplyService()
    let replies = service.quickReplies

    #expect(!replies.isEmpty)
    #expect(replies.contains(where: { $0.text == "好的" }))
    #expect(replies.contains(where: { $0.text == "收到" }))
}

@MainActor
@Test("Add custom quick reply")
func testAddCustomReply() {
    let service = QuickReplyService()
    let initialCount = service.quickReplies.count

    service.addCustomReply("马上到")

    #expect(service.quickReplies.count == initialCount + 1)
    #expect(service.quickReplies.last?.text == "马上到")
    #expect(service.quickReplies.last?.isCustom == true)
}

@MainActor
@Test("Remove custom quick reply")
func testRemoveCustomReply() {
    let service = QuickReplyService()
    service.addCustomReply("测试回复")

    let reply = service.quickReplies.first(where: { $0.text == "测试回复" })!
    service.removeReply(id: reply.id)

    #expect(!service.quickReplies.contains(where: { $0.text == "测试回复" }))
}

@MainActor
@Test("Cannot remove default quick reply")
func testCannotRemoveDefaultReply() {
    let service = QuickReplyService()
    let defaultReply = service.quickReplies.first(where: { !$0.isCustom })!
    let countBefore = service.quickReplies.count

    service.removeReply(id: defaultReply.id)

    #expect(service.quickReplies.count == countBefore)
}

@MainActor
@Test("Get contextual replies for greeting")
func testContextualRepliesGreeting() {
    let service = QuickReplyService()
    let replies = service.contextualReplies(for: "早上好！")

    // 应包含问候相关的回复
    #expect(!replies.isEmpty)
}
