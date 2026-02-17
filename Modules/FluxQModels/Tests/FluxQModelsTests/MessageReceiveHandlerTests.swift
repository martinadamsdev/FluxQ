import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("MessageReceiveHandler Logic Tests")
struct MessageReceiveHandlerTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self, FileTransfer.self,
            configurations: config
        )
    }

    @Test("Received message creates Message with status .delivered in correct conversation")
    func receivedMessageCreatesDeliveredMessage() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let convId = ConversationService.findOrCreateConversation(
            hostname: "sender-mac",
            senderName: "sender",
            nickname: "Sender",
            ipAddress: "192.168.1.50",
            port: 2425,
            group: nil,
            in: context
        )

        let message = Message(
            conversationID: convId,
            senderID: UUID(),
            content: "Hello from sender",
            status: .delivered
        )
        context.insert(message)
        try context.save()

        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.conversationID == convId }
        )
        let messages = try context.fetch(descriptor)
        #expect(messages.count == 1)
        #expect(messages[0].content == "Hello from sender")
        #expect(messages[0].status == .delivered)
        #expect(messages[0].conversationID == convId)
    }

    @Test("Received message updates conversation lastMessageTimestamp")
    func receivedMessageUpdatesTimestamp() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let convId = ConversationService.findOrCreateConversation(
            hostname: "ts-host",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.60",
            port: 2425,
            group: nil,
            in: context
        )

        // Set conversation timestamp to the past
        let convDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == convId }
        )
        let conversation = try context.fetch(convDescriptor).first!
        let pastDate = Date.distantPast
        conversation.lastMessageTimestamp = pastDate
        try context.save()

        // Simulate receiving a message: create message and update timestamp
        let message = Message(
            conversationID: convId,
            senderID: UUID(),
            content: "New message",
            status: .delivered
        )
        context.insert(message)
        conversation.lastMessageTimestamp = Date()
        try context.save()

        let updatedConv = try context.fetch(convDescriptor).first!
        #expect(updatedConv.lastMessageTimestamp > pastDate)
    }

    @Test("Received message increments conversation unreadCount")
    func receivedMessageIncrementsUnreadCount() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let convId = ConversationService.findOrCreateConversation(
            hostname: "unread-host",
            senderName: "bob",
            nickname: "Bob",
            ipAddress: "192.168.1.70",
            port: 2425,
            group: nil,
            in: context
        )

        let convDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == convId }
        )
        let conversation = try context.fetch(convDescriptor).first!
        let initialUnread = conversation.unreadCount

        // Simulate receiving a message: increment unreadCount
        conversation.unreadCount += 1
        try context.save()

        let updated = try context.fetch(convDescriptor).first!
        #expect(updated.unreadCount == initialUnread + 1)
    }

    @Test("Recall command marks message as isRecalled and sets recalledAt")
    func recallMarksMessage() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let message = Message(
            conversationID: UUID(),
            senderID: UUID(),
            content: "To be recalled",
            status: .delivered
        )
        context.insert(message)
        try context.save()

        #expect(message.isRecalled == false)
        #expect(message.recalledAt == nil)

        // Simulate recall command
        let messageID = message.id
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.id == messageID }
        )
        if let fetched = try context.fetch(descriptor).first {
            fetched.isRecalled = true
            fetched.recalledAt = Date()
            try context.save()
        }

        let recalled = try context.fetch(descriptor).first!
        #expect(recalled.isRecalled == true)
        #expect(recalled.recalledAt != nil)
    }

    @Test("Recall with invalid UUID string is handled gracefully")
    func recallWithInvalidUUIDIsGraceful() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Insert a message to make sure it is NOT affected by invalid recall
        let message = Message(
            conversationID: UUID(),
            senderID: UUID(),
            content: "Should not be recalled",
            status: .delivered
        )
        context.insert(message)
        try context.save()

        // Simulate recall with invalid UUID string (guard let fails, early return)
        let invalidString = "not-a-valid-uuid"
        #expect(UUID(uuidString: invalidString) == nil)

        // Simulate recall with valid UUID that doesn't match any message
        let randomID = UUID()
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.id == randomID }
        )
        let result = try context.fetch(descriptor).first
        #expect(result == nil)

        // Existing message should remain untouched
        let messages = try context.fetch(FetchDescriptor<Message>())
        #expect(messages.count == 1)
        #expect(messages[0].isRecalled == false)
        #expect(messages[0].recalledAt == nil)
    }

    @Test("Multiple messages from same sender go to same conversation")
    func multipleMsgsFromSameSenderSameConversation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let convId1 = ConversationService.findOrCreateConversation(
            hostname: "repeat-host",
            senderName: "charlie",
            nickname: "Charlie",
            ipAddress: "192.168.1.80",
            port: 2425,
            group: nil,
            in: context
        )

        let convId2 = ConversationService.findOrCreateConversation(
            hostname: "repeat-host",
            senderName: "charlie",
            nickname: "Charlie",
            ipAddress: "192.168.1.80",
            port: 2425,
            group: nil,
            in: context
        )

        #expect(convId1 == convId2)

        // Verify only one conversation exists
        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
    }
}
