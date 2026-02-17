import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("ConversationService Tests")
struct ConversationServiceTests {

    /// Helper: create an in-memory ModelContainer for testing
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self,
            configurations: config
        )
    }

    @Test("Creates new User and Conversation when none exist")
    func createNewUserAndConversation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let result = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        // Should return a valid conversation ID
        #expect(result != nil)

        // User should be persisted
        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
        #expect(users[0].hostname == "testhost")
        #expect(users[0].nickname == "Alice")

        // Conversation should be created
        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
        #expect(conversations[0].type == .private)
        #expect(conversations[0].participantIDs.contains(users[0].id))
    }

    @Test("Reuses existing User when hostname + ipAddress match")
    func reuseExistingUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Pre-insert a user
        let existingUser = User(
            nickname: "Alice",
            hostname: "testhost",
            ipAddress: "192.168.1.10"
        )
        context.insert(existingUser)
        try context.save()

        let result = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice Updated",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        #expect(result != nil)

        // Should NOT create a duplicate user
        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
        #expect(users[0].id == existingUser.id)
    }

    @Test("Reuses existing Conversation with same user")
    func reuseExistingConversation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Pre-insert user and conversation
        let existingUser = User(
            nickname: "Alice",
            hostname: "testhost",
            ipAddress: "192.168.1.10"
        )
        context.insert(existingUser)

        let existingConv = Conversation(
            type: .private,
            participantIDs: [existingUser.id],
            lastMessageTimestamp: Date.distantPast
        )
        context.insert(existingConv)
        try context.save()

        let result = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        // Should return the existing conversation
        #expect(result == existingConv.id)

        // Should NOT create a new conversation
        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)

        // Should update lastMessageTimestamp to bring it to top
        #expect(conversations[0].lastMessageTimestamp > Date.distantPast)
    }

    @Test("Creates new Conversation when existing user has no private conversation")
    func createConversationForExistingUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Pre-insert user without any conversation
        let existingUser = User(
            nickname: "Bob",
            hostname: "bobhost",
            ipAddress: "192.168.1.20"
        )
        context.insert(existingUser)
        try context.save()

        let result = ConversationService.findOrCreateConversation(
            hostname: "bobhost",
            senderName: "bob",
            nickname: "Bob",
            ipAddress: "192.168.1.20",
            port: 2425,
            group: nil,
            in: context
        )

        #expect(result != nil)

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
        #expect(conversations[0].participantIDs.contains(existingUser.id))
    }
}
