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

        let (conversationId, userId) = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        // userId should match the created user

        // User should be persisted
        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
        #expect(users[0].hostname == "testhost")
        #expect(users[0].nickname == "Alice")
        #expect(users[0].id == userId)

        // Conversation should be created
        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
        #expect(conversations[0].type == .private)
        #expect(conversations[0].participantIDs.contains(userId))
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

        let (_, userId) = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice Updated",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        #expect(userId == existingUser.id)

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

        let (convId, _) = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        // Should return the existing conversation
        #expect(convId == existingConv.id)

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

        let (convId, userId) = ConversationService.findOrCreateConversation(
            hostname: "bobhost",
            senderName: "bob",
            nickname: "Bob",
            ipAddress: "192.168.1.20",
            port: 2425,
            group: nil,
            in: context
        )

        #expect(userId == existingUser.id)

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
        #expect(conversations[0].participantIDs.contains(existingUser.id))
    }

    // MARK: - Edge Cases

    @Test("Updates nickname when existing user reconnects with new name")
    func nicknameUpdateOnReuse() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let existingUser = User(
            nickname: "OldName",
            hostname: "testhost",
            ipAddress: "192.168.1.10"
        )
        context.insert(existingUser)
        try context.save()

        _ = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "NewName",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
        #expect(users[0].nickname == "NewName")
        #expect(users[0].isOnline == true)
    }

    @Test("Different IP creates separate user even with same hostname")
    func differentIPCreatesSeparateUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let user1 = User(
            nickname: "Alice",
            hostname: "shared-host",
            ipAddress: "192.168.1.10"
        )
        context.insert(user1)
        try context.save()

        _ = ConversationService.findOrCreateConversation(
            hostname: "shared-host",
            senderName: "bob",
            nickname: "Bob",
            ipAddress: "192.168.1.20",
            port: 2425,
            group: nil,
            in: context
        )

        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 2)
    }

    @Test("Group conversation is not matched for private lookup")
    func groupConversationNotMatchedForPrivate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let existingUser = User(
            nickname: "Alice",
            hostname: "testhost",
            ipAddress: "192.168.1.10"
        )
        context.insert(existingUser)

        // Insert a GROUP conversation with the same user
        let groupConv = Conversation(
            type: .group,
            participantIDs: [existingUser.id]
        )
        context.insert(groupConv)
        try context.save()

        let (convId, _) = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        // Should NOT reuse the group conversation, should create a new private one
        #expect(convId != groupConv.id)

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 2)
        let privateConvs = conversations.filter { $0.type == .private }
        #expect(privateConvs.count == 1)
        #expect(privateConvs[0].id == convId)
    }

    @Test("Preserves group field on new user")
    func groupFieldPreserved() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        _ = ConversationService.findOrCreateConversation(
            hostname: "devhost",
            senderName: "charlie",
            nickname: "Charlie",
            ipAddress: "10.0.0.5",
            port: 2425,
            group: "Engineering",
            in: context
        )

        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
        #expect(users[0].group == "Engineering")
    }

    @Test("Port is preserved on new user")
    func portPreserved() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        _ = ConversationService.findOrCreateConversation(
            hostname: "devhost",
            senderName: "charlie",
            nickname: "Charlie",
            ipAddress: "10.0.0.5",
            port: 5000,
            group: nil,
            in: context
        )

        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
        #expect(users[0].port == 5000)
    }

    @Test("Multiple users get separate conversations")
    func multipleUsersSeparateConversations() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let (convId1, _) = ConversationService.findOrCreateConversation(
            hostname: "host-a",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        let (convId2, _) = ConversationService.findOrCreateConversation(
            hostname: "host-b",
            senderName: "bob",
            nickname: "Bob",
            ipAddress: "192.168.1.20",
            port: 2425,
            group: nil,
            in: context
        )

        #expect(convId1 != convId2)

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 2)
    }

    @Test("Calling findOrCreateConversation twice for same user is idempotent")
    func idempotentForSameUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let (convId1, userId1) = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        let (convId2, userId2) = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        #expect(convId1 == convId2)
        #expect(userId1 == userId2)

        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
    }
}
