// FluxQWatchTests/ComplicationDataProviderTests.swift
import Testing
import Foundation
@testable import FluxQWatch

@MainActor
@Test("Return zero unread count initially")
func testInitialUnreadCount() {
    let provider = ComplicationDataProvider()
    #expect(provider.totalUnreadCount == 0)
}

@MainActor
@Test("Update unread count for conversation")
func testUpdateUnreadCount() {
    let provider = ComplicationDataProvider()
    let convId = UUID()

    provider.updateUnreadCount(for: convId, count: 5)

    #expect(provider.totalUnreadCount == 5)
}

@MainActor
@Test("Aggregate unread counts across conversations")
func testAggregateUnreadCounts() {
    let provider = ComplicationDataProvider()
    let conv1 = UUID()
    let conv2 = UUID()

    provider.updateUnreadCount(for: conv1, count: 3)
    provider.updateUnreadCount(for: conv2, count: 2)

    #expect(provider.totalUnreadCount == 5)
}

@MainActor
@Test("Mark conversation as read resets count")
func testMarkAsRead() {
    let provider = ComplicationDataProvider()
    let convId = UUID()

    provider.updateUnreadCount(for: convId, count: 5)
    provider.markAsRead(conversationId: convId)

    #expect(provider.totalUnreadCount == 0)
}

@MainActor
@Test("Generate complication display text")
func testComplicationDisplayText() {
    let provider = ComplicationDataProvider()
    let convId = UUID()

    provider.updateUnreadCount(for: convId, count: 12)

    #expect(provider.displayText == "12")
    #expect(provider.shortDisplayText == "12")
}

@MainActor
@Test("Display text shows empty when no unread")
func testComplicationDisplayTextEmpty() {
    let provider = ComplicationDataProvider()

    #expect(provider.displayText == "")
    #expect(provider.shortDisplayText == "")
}
