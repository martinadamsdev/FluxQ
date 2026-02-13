import Testing
import Foundation
@testable import FluxQWatch

@MainActor
@Test("Quick reply view model loads replies")
func testLoadReplies() {
    let service = QuickReplyService()
    let viewModel = QuickReplyViewModel(service: service)

    #expect(!viewModel.replies.isEmpty)
}

@MainActor
@Test("Quick reply view model filters by context")
func testContextualFilter() {
    let service = QuickReplyService()
    let viewModel = QuickReplyViewModel(service: service, lastMessage: "你好吗？")

    #expect(!viewModel.replies.isEmpty)
}
