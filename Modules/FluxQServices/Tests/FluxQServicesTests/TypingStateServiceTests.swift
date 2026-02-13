import Testing
import Foundation
@testable import FluxQServices
import IPMsgProtocol

@MainActor
struct TypingStateServiceTests {

    // MARK: - Helpers

    private func makeService() -> (TypingStateService, MockNetworkTransport) {
        let transport = MockNetworkTransport()
        let networkManager = NetworkManager(port: 2425, transport: transport)
        let service = TypingStateService(networkManager: networkManager)
        return (service, transport)
    }

    // MARK: - startTyping

    @Test("startTyping sends TYPING command via broadcast")
    func startTypingSendsCommand() throws {
        let (service, transport) = makeService()

        try service.startTyping(to: "user-1")

        #expect(transport.broadcastMessages.count == 1)
        let data = transport.broadcastMessages[0].data
        let message = String(data: data, encoding: .utf8)!
        let packet = try IPMsgPacket.decode(message)
        #expect(packet.command == .TYPING)
    }

    @Test("startTyping debounces rapid calls within 1 second")
    func startTypingDebounces() throws {
        let (service, transport) = makeService()

        try service.startTyping(to: "user-1")
        try service.startTyping(to: "user-1")
        try service.startTyping(to: "user-1")

        // Only the first call should send, the rest are debounced
        #expect(transport.broadcastMessages.count == 1)
    }

    @Test("startTyping sends again after debounce period expires")
    func startTypingSendsAfterDebounce() async throws {
        let (service, transport) = makeService()

        try service.startTyping(to: "user-1")
        #expect(transport.broadcastMessages.count == 1)

        // Wait for debounce period to expire
        try await Task.sleep(for: .milliseconds(1100))

        try service.startTyping(to: "user-1")
        #expect(transport.broadcastMessages.count == 2)
    }

    @Test("startTyping to different users is not debounced")
    func startTypingDifferentUsersNotDebounced() throws {
        let (service, transport) = makeService()

        try service.startTyping(to: "user-1")
        try service.startTyping(to: "user-2")

        #expect(transport.broadcastMessages.count == 2)
    }

    // MARK: - stopTyping

    @Test("stopTyping sends STOPTYPING command via broadcast")
    func stopTypingSendsCommand() throws {
        let (service, transport) = makeService()

        try service.stopTyping(to: "user-1")

        #expect(transport.broadcastMessages.count == 1)
        let data = transport.broadcastMessages[0].data
        let message = String(data: data, encoding: .utf8)!
        let packet = try IPMsgPacket.decode(message)
        #expect(packet.command == .STOPTYPING)
    }

    // MARK: - handleTypingCommand

    @Test("handleTypingCommand adds user to typingUsers")
    func handleTypingCommandAddsUser() {
        let (service, _) = makeService()

        service.handleTypingCommand(from: "remote-user-1")

        #expect(service.isUserTyping("remote-user-1") == true)
        #expect(service.typingUsers["remote-user-1"] != nil)
    }

    @Test("handleTypingCommand updates timestamp on repeated calls")
    func handleTypingCommandUpdatesTimestamp() throws {
        let (service, _) = makeService()

        service.handleTypingCommand(from: "remote-user-1")
        let firstTimestamp = service.typingUsers["remote-user-1"]!

        // Small delay to get a different timestamp
        Thread.sleep(forTimeInterval: 0.01)

        service.handleTypingCommand(from: "remote-user-1")
        let secondTimestamp = service.typingUsers["remote-user-1"]!

        #expect(secondTimestamp >= firstTimestamp)
    }

    // MARK: - handleStopTypingCommand

    @Test("handleStopTypingCommand removes user from typingUsers")
    func handleStopTypingCommandRemovesUser() {
        let (service, _) = makeService()

        service.handleTypingCommand(from: "remote-user-1")
        #expect(service.isUserTyping("remote-user-1") == true)

        service.handleStopTypingCommand(from: "remote-user-1")
        #expect(service.isUserTyping("remote-user-1") == false)
    }

    // MARK: - isUserTyping

    @Test("isUserTyping returns false for unknown user")
    func isUserTypingUnknown() {
        let (service, _) = makeService()
        #expect(service.isUserTyping("nonexistent") == false)
    }

    // MARK: - Auto-expire

    @Test("Typing state auto-expires after timeout")
    func typingStateAutoExpires() async throws {
        let (service, _) = makeService()
        // Use a short timeout for testing
        service.typingTimeout = 0.5

        service.handleTypingCommand(from: "remote-user-1")
        #expect(service.isUserTyping("remote-user-1") == true)

        // Wait for expiry
        try await Task.sleep(for: .milliseconds(700))

        service.cleanupExpiredTypingStates()
        #expect(service.isUserTyping("remote-user-1") == false)
    }

    @Test("Typing state does not expire if refreshed")
    func typingStateRefreshed() async throws {
        let (service, _) = makeService()
        service.typingTimeout = 2.0

        service.handleTypingCommand(from: "remote-user-1")

        // Refresh before expiry
        try await Task.sleep(for: .milliseconds(800))
        service.handleTypingCommand(from: "remote-user-1")

        // Wait a bit more - would have expired from first call but not second
        try await Task.sleep(for: .milliseconds(800))
        service.cleanupExpiredTypingStates()
        #expect(service.isUserTyping("remote-user-1") == true)
    }
}
