import Testing
import Foundation
import Combine
@testable import FluxQ

@MainActor
struct ActiveConversationTrackerTests {

    @Test("Initial value is nil")
    func initialValueIsNil() {
        let tracker = ActiveConversationTracker()
        #expect(tracker.activeConversationId == nil)
    }

    @Test("Setting conversation ID updates value")
    func settingConversationId() {
        let tracker = ActiveConversationTracker()
        let testId = UUID()
        tracker.activeConversationId = testId
        #expect(tracker.activeConversationId == testId)
    }

    @Test("Clearing conversation ID sets it back to nil")
    func clearingConversationId() {
        let tracker = ActiveConversationTracker()
        tracker.activeConversationId = UUID()
        tracker.activeConversationId = nil
        #expect(tracker.activeConversationId == nil)
    }

    @Test("Publisher fires on change")
    func publisherFiresOnChange() async throws {
        let tracker = ActiveConversationTracker()
        let testId = UUID()

        var receivedValues: [UUID?] = []
        let cancellable = tracker.$activeConversationId
            .dropFirst()  // skip initial value
            .sink { receivedValues.append($0) }

        tracker.activeConversationId = testId
        tracker.activeConversationId = nil

        // Give Combine time to deliver
        try await Task.sleep(for: .milliseconds(100))

        #expect(receivedValues.count >= 2)
        #expect(receivedValues.first == testId)
        _ = cancellable  // keep alive
    }
}
