import Foundation
import Testing
@testable import FluxQServices

@Suite("SoundThrottle Tests")
struct SoundThrottleTests {

    @Test("首次调用应该允许播放")
    func firstCallShouldAllow() {
        var throttle = SoundThrottle(interval: 3.0)
        let result = throttle.shouldAllow()
        #expect(result)
    }

    @Test("间隔内第二次调用应该被阻止")
    func secondCallWithinIntervalShouldBlock() {
        var throttle = SoundThrottle(interval: 3.0)
        _ = throttle.shouldAllow()
        let result = throttle.shouldAllow()
        #expect(!result)
    }

    @Test("超过间隔后应该允许")
    func callAfterIntervalShouldAllow() {
        var throttle = SoundThrottle(interval: 3.0)
        _ = throttle.shouldAllow()
        throttle.lastAllowedAt = Date().addingTimeInterval(-4.0)
        let result = throttle.shouldAllow()
        #expect(result)
    }
}
