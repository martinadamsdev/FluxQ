import Testing
import Foundation
@testable import FluxQWatch

@MainActor
@Test("Send message through Watch Connectivity")
func testSendMessage() async throws {
    let service = WatchConnectivityService(testMode: true)
    service.mockIsReachable = true

    try await service.sendMessage(to: "user123", content: "Hello from Watch")

    let sentMessages = service.mockSentMessages
    #expect(sentMessages.count == 1)
    #expect(sentMessages.first?["action"] as? String == "sendMessage")
    #expect(sentMessages.first?["content"] as? String == "Hello from Watch")
}

@MainActor
@Test("Throw error when iPhone not reachable")
func testSendMessageWhenUnreachable() async {
    let service = WatchConnectivityService(testMode: true)
    service.mockIsReachable = false

    await #expect(throws: WatchError.iPhoneNotReachable) {
        try await service.sendMessage(to: "user123", content: "Hello")
    }
}
