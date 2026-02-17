import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("FileTransfer Model Tests")
struct FileTransferModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self, FileTransfer.self,
            configurations: config
        )
    }

    @Test("Create FileTransfer with all fields")
    func createFileTransfer() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "test.pdf",
            fileSize: 1024 * 1024,
            direction: .outgoing
        )
        context.insert(transfer)
        try context.save()

        let descriptor = FetchDescriptor<FileTransfer>()
        let transfers = try context.fetch(descriptor)
        #expect(transfers.count == 1)
        #expect(transfers[0].fileName == "test.pdf")
        #expect(transfers[0].fileSize == 1024 * 1024)
        #expect(transfers[0].status == .pending)
        #expect(transfers[0].direction == .outgoing)
        #expect(transfers[0].transferredBytes == 0)
    }

    @Test("FileTransfer progress updates")
    func progressUpdates() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "big.zip",
            fileSize: 100_000_000,
            direction: .incoming
        )
        context.insert(transfer)

        transfer.status = .transferring
        transfer.transferredBytes = 50_000_000

        #expect(transfer.progress == 0.5)

        transfer.transferredBytes = 100_000_000
        transfer.status = .completed
        transfer.completedAt = Date()

        #expect(transfer.progress == 1.0)
        #expect(transfer.status == .completed)
    }

    @Test("Message with file attachment type")
    func messageWithFileType() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let message = Message(
            conversationID: UUID(),
            senderID: UUID(),
            content: "test.pdf",
            status: .sent,
            messageType: .file,
            fileAttachmentID: UUID()
        )
        context.insert(message)
        try context.save()

        let descriptor = FetchDescriptor<Message>()
        let messages = try context.fetch(descriptor)
        #expect(messages[0].messageType == .file)
        #expect(messages[0].fileAttachmentID != nil)
    }
}
