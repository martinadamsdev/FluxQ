import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("Message Persistence Tests")
struct MessagePersistenceTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self, FileTransfer.self,
            configurations: config
        )
    }

    @Test("Message persisted to conversation is fetchable")
    func messagePersisted() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Create user and conversation
        let convId = ConversationService.findOrCreateConversation(
            hostname: "alice-mac", senderName: "alice", nickname: "Alice",
            ipAddress: "192.168.1.10", port: 2425, group: nil, in: context
        )

        // Create message
        let message = Message(
            conversationID: convId,
            senderID: UUID(),
            content: "Hello!",
            status: .delivered
        )
        context.insert(message)
        try context.save()

        // Fetch messages for conversation
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.conversationID == convId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let messages = try context.fetch(descriptor)
        #expect(messages.count == 1)
        #expect(messages[0].content == "Hello!")
        #expect(messages[0].status == .delivered)
    }

    @Test("Sent message has correct initial status")
    func sentMessageStatus() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let message = Message(
            conversationID: UUID(),
            senderID: UUID(),
            content: "Test",
            status: .sending
        )
        context.insert(message)

        #expect(message.status == .sending)

        // Simulate send success
        message.status = .sent
        #expect(message.status == .sent)

        // Simulate send failure
        message.status = .failed
        #expect(message.status == .failed)
    }

    @Test("Multiple messages in conversation sorted by timestamp")
    func messagesOrderedByTimestamp() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let convId = UUID()
        let msg1 = Message(
            conversationID: convId, senderID: UUID(),
            content: "First", timestamp: Date().addingTimeInterval(-60)
        )
        let msg2 = Message(
            conversationID: convId, senderID: UUID(),
            content: "Second", timestamp: Date()
        )
        context.insert(msg1)
        context.insert(msg2)
        try context.save()

        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.conversationID == convId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let messages = try context.fetch(descriptor)
        #expect(messages.count == 2)
        #expect(messages[0].content == "First")
        #expect(messages[1].content == "Second")
    }
}
