import Testing
import Foundation
import SwiftData
@testable import FluxQ
import FluxQModels
@testable import FluxQServices

@MainActor
struct MessageReceiveHandlerDirectTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([User.self, Message.self, Conversation.self, FileTransfer.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    @Test("handleReceivedMessage creates message and conversation")
    func handleReceivedMessageCreatesMessageAndConversation() throws {
        let received = ReceivedMessage(
            senderName: "TestUser",
            hostname: "test-host",
            fromHost: "192.168.1.100",
            content: "Hello!",
            packetNo: 1,
            receivedAt: Date()
        )

        MessageReceiveHandler.handleReceivedMessage(received, in: context)

        // Verify message was created
        let messages = try context.fetch(FetchDescriptor<Message>())
        #expect(messages.count == 1)
        #expect(messages.first?.content == "Hello!")
        #expect(messages.first?.status == .delivered)

        // Verify conversation was created
        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
        #expect(conversations.first?.unreadCount == 1)
    }

    @Test("handleReceivedMessage increments unread count")
    func handleReceivedMessageIncrementsUnreadCount() throws {
        let received1 = ReceivedMessage(
            senderName: "TestUser", hostname: "test-host",
            fromHost: "192.168.1.100", content: "Message 1",
            packetNo: 1, receivedAt: Date()
        )
        let received2 = ReceivedMessage(
            senderName: "TestUser", hostname: "test-host",
            fromHost: "192.168.1.100", content: "Message 2",
            packetNo: 2, receivedAt: Date()
        )

        MessageReceiveHandler.handleReceivedMessage(received1, in: context)
        MessageReceiveHandler.handleReceivedMessage(received2, in: context)

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.first?.unreadCount == 2)
    }

    @Test("handleRecallCommand marks message as recalled")
    func handleRecallCommandMarksMessageRecalled() throws {
        let messageId = UUID()
        let message = Message(
            id: messageId,
            conversationID: UUID(),
            senderID: UUID(),
            content: "To be recalled",
            status: .delivered
        )
        context.insert(message)
        try context.save()

        MessageReceiveHandler.handleRecallCommand(
            messageIDString: messageId.uuidString,
            in: context
        )

        let fetched = try context.fetch(FetchDescriptor<Message>())
        #expect(fetched.first?.isRecalled == true)
        #expect(fetched.first?.recalledAt != nil)
    }

    @Test("handleRecallCommand with invalid UUID does nothing")
    func handleRecallCommandWithInvalidUUIDDoesNothing() throws {
        MessageReceiveHandler.handleRecallCommand(
            messageIDString: "not-a-uuid",
            in: context
        )
        // Should not crash, no messages affected
        let messages = try context.fetch(FetchDescriptor<Message>())
        #expect(messages.isEmpty)
    }
}
