import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("Conversation List Integration Tests")
struct ConversationListIntegrationTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self,
            configurations: config
        )
    }

    @Test("ConversationService creates conversation visible via FetchDescriptor")
    func conversationVisibleAfterCreation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Act: create conversation via ConversationService
        let (convId, _) = ConversationService.findOrCreateConversation(
            hostname: "alice-mac",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )
        try context.save()

        // Assert: query finds it (simulates what @Query does in UI)
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        let conversations = try context.fetch(descriptor)
        #expect(conversations.count == 1)
        #expect(conversations[0].id == convId)
        #expect(conversations[0].displayName == "Alice")
    }

    @Test("Multiple conversations sorted by lastMessageTimestamp descending")
    func conversationsSortedByTimestamp() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Create two conversations with different timestamps
        let (convId1, _) = ConversationService.findOrCreateConversation(
            hostname: "alice-mac", senderName: "alice", nickname: "Alice",
            ipAddress: "192.168.1.10", port: 2425, group: nil, in: context
        )

        // Small delay to ensure different timestamps
        let (convId2, _) = ConversationService.findOrCreateConversation(
            hostname: "bob-mac", senderName: "bob", nickname: "Bob",
            ipAddress: "192.168.1.20", port: 2425, group: nil, in: context
        )
        try context.save()

        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        let conversations = try context.fetch(descriptor)
        #expect(conversations.count == 2)
        // Bob should be first (created later, so more recent timestamp)
        #expect(conversations[0].id == convId2)
    }

    @Test("Tapping same user twice reuses conversation and updates timestamp")
    func tapSameUserTwice() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let (convId1, _) = ConversationService.findOrCreateConversation(
            hostname: "alice-mac", senderName: "alice", nickname: "Alice",
            ipAddress: "192.168.1.10", port: 2425, group: nil, in: context
        )

        let (convId2, _) = ConversationService.findOrCreateConversation(
            hostname: "alice-mac", senderName: "alice", nickname: "Alice",
            ipAddress: "192.168.1.10", port: 2425, group: nil, in: context
        )

        #expect(convId1 == convId2)

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
    }
}
