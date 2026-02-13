import Testing
import Foundation
@testable import FluxQWatch

@MainActor
@Test("Start service initializes UDP discovery")
func testNetworkServiceStart() async throws {
    let service = WatchNetworkService(testMode: true)
    try await service.start()

    #expect(service.isRunning == true)
    #expect(service.discoveredUsers.isEmpty)
}

@MainActor
@Test("Stop service cleans up resources")
func testNetworkServiceStop() async throws {
    let service = WatchNetworkService(testMode: true)
    try await service.start()
    service.stop()

    #expect(service.isRunning == false)
}

@MainActor
@Test("Send message in standalone mode")
func testNetworkServiceSendMessage() async throws {
    let service = WatchNetworkService(testMode: true)
    try await service.start()

    service.mockDiscoverUser(id: "user1", name: "张三", ip: "192.168.1.100")

    try await service.sendDirectMessage(to: "user1", content: "你好")

    #expect(service.mockSentMessages.count == 1)
    #expect(service.mockSentMessages.first?.content == "你好")
}

@MainActor
@Test("Send message fails when user not found")
func testNetworkServiceSendMessageUserNotFound() async {
    let service = WatchNetworkService(testMode: true)

    await #expect(throws: WatchNetworkError.userNotFound) {
        try await service.sendDirectMessage(to: "unknown", content: "你好")
    }
}
