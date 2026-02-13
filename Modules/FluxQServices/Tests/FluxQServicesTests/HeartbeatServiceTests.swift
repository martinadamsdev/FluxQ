import Testing
import Foundation
@testable import FluxQServices

@MainActor
struct HeartbeatServiceTests {

    @Test("Heartbeat interval is platform-appropriate")
    func heartbeatInterval() {
        let service = HeartbeatService()
        #if os(watchOS)
        #expect(service.heartbeatInterval == 60.0)
        #expect(service.timeoutInterval == 120.0)
        #else
        #expect(service.heartbeatInterval == 30.0)
        #expect(service.timeoutInterval == 60.0)
        #endif
    }

    @Test("Record heartbeat marks user as online")
    func recordHeartbeat() {
        let service = HeartbeatService()
        let userId = UUID()
        let now = Date()

        service.recordHeartbeat(userId: userId, at: now)

        #expect(service.isUserOnline(userId, at: now) == true)
    }

    @Test("User becomes offline after timeout")
    func userTimeoutDetection() {
        let service = HeartbeatService()
        let userId = UUID()
        let now = Date()

        service.recordHeartbeat(userId: userId, at: now)
        #expect(service.isUserOnline(userId, at: now) == true)

        // Simulate timeout (past the timeout interval)
        let afterTimeout = now.addingTimeInterval(service.timeoutInterval + 1)
        #expect(service.isUserOnline(userId, at: afterTimeout) == false)
    }

    @Test("Check timeouts removes timed-out users progressively")
    func checkTimeoutsProgressive() {
        let service = HeartbeatService()
        let userId = UUID()
        let now = Date()

        service.recordHeartbeat(userId: userId, at: now)

        // First timeout check - user still tracked
        let firstTimeout = now.addingTimeInterval(service.timeoutInterval + 1)
        service.checkTimeouts(currentTime: firstTimeout)
        #expect(service.onlineUsers[userId] != nil)

        // Second timeout check
        service.checkTimeouts(currentTime: firstTimeout.addingTimeInterval(service.timeoutInterval + 1))
        #expect(service.onlineUsers[userId] != nil)

        // Third timeout check - user removed
        service.checkTimeouts(currentTime: firstTimeout.addingTimeInterval((service.timeoutInterval + 1) * 2))
        #expect(service.onlineUsers[userId] == nil)
    }

    @Test("Unknown user is not online")
    func unknownUserNotOnline() {
        let service = HeartbeatService()
        #expect(service.isUserOnline(UUID()) == false)
    }

    @Test("Re-heartbeat resets timeout")
    func reHeartbeatResetsTimeout() {
        let service = HeartbeatService()
        let userId = UUID()
        let now = Date()

        service.recordHeartbeat(userId: userId, at: now)

        // Nearly timed out
        let nearlyTimedOut = now.addingTimeInterval(service.timeoutInterval - 1)
        #expect(service.isUserOnline(userId, at: nearlyTimedOut) == true)

        // Re-heartbeat
        service.recordHeartbeat(userId: userId, at: nearlyTimedOut)

        // Would have been timed out from original heartbeat, but not from the new one
        let afterOriginalTimeout = now.addingTimeInterval(service.timeoutInterval + 1)
        #expect(service.isUserOnline(userId, at: afterOriginalTimeout) == true)
    }
}
