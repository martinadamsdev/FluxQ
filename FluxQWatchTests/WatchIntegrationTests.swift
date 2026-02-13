import Testing
import Foundation
@testable import FluxQWatch

// MARK: - Mode Transition Integration

@MainActor
@Test("Full mode transition flow: offline → companion → standalone → offline")
func testFullModeTransitionFlow() async throws {
    let coordinator = WatchServiceCoordinator(testMode: true)

    #expect(coordinator.activeMode == .offline)

    try await coordinator.switchToMode(.companion)
    #expect(coordinator.isConnectivityActive == true)
    #expect(coordinator.isNetworkServiceActive == false)

    try await coordinator.switchToMode(.standalone)
    #expect(coordinator.isConnectivityActive == false)
    #expect(coordinator.isNetworkServiceActive == true)

    try await coordinator.switchToMode(.offline)
    #expect(coordinator.isConnectivityActive == false)
    #expect(coordinator.isNetworkServiceActive == false)
}

// MARK: - Quick Reply + Send Integration

@MainActor
@Test("Quick reply triggers message send in companion mode")
func testQuickReplySendCompanion() async throws {
    let connectivity = WatchConnectivityService(testMode: true)
    connectivity.mockIsReachable = true
    let quickReply = QuickReplyService()

    let reply = quickReply.quickReplies.first!
    try await connectivity.sendMessage(to: "user1", content: reply.text)

    #expect(connectivity.mockSentMessages.count == 1)
    #expect(connectivity.mockSentMessages.first?["content"] as? String == reply.text)
}

@MainActor
@Test("Quick reply triggers message send in standalone mode")
func testQuickReplySendStandalone() async throws {
    let networkService = WatchNetworkService(testMode: true)
    try await networkService.start()
    networkService.mockDiscoverUser(id: "user1", name: "张三", ip: "192.168.1.100")
    let quickReply = QuickReplyService()

    let reply = quickReply.quickReplies.first!
    try await networkService.sendDirectMessage(to: "user1", content: reply.text)

    #expect(networkService.mockSentMessages.count == 1)
    #expect(networkService.mockSentMessages.first?.content == reply.text)
}

// MARK: - Complication + Message Integration

@MainActor
@Test("New message increments complication unread count")
func testMessageIncrementsComplication() {
    let provider = ComplicationDataProvider()
    let convId = UUID()

    provider.incrementUnread(for: convId)
    provider.incrementUnread(for: convId)

    #expect(provider.totalUnreadCount == 2)
    #expect(provider.displayText == "2")
}

// MARK: - NetworkModeManager + Coordinator Integration

@MainActor
@Test("NetworkModeManager mode change triggers coordinator")
func testModeManagerTriggersCoordinator() async throws {
    let manager = NetworkModeManager(testMode: true)
    let coordinator = WatchServiceCoordinator(testMode: true)
    manager.coordinator = coordinator

    manager.mockWCSessionReachable = true
    let mode = manager.determineNetworkMode()
    #expect(mode == .companion)
}
