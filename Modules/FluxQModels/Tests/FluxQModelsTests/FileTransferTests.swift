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

    @Test("FileTransfer with zero fileSize has progress 0.0")
    func zeroFileSizeProgress() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "empty.txt",
            fileSize: 0,
            direction: .outgoing
        )
        context.insert(transfer)
        try context.save()

        #expect(transfer.progress == 0.0)
    }

    @Test("FileTransfer status transitions pending to completed")
    func statusTransitionPendingToCompleted() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "doc.pdf",
            fileSize: 5000,
            direction: .incoming
        )
        context.insert(transfer)

        #expect(transfer.status == .pending)

        transfer.status = .transferring
        transfer.transferredBytes = 2500
        #expect(transfer.status == .transferring)
        #expect(transfer.progress == 0.5)

        transfer.status = .completed
        transfer.transferredBytes = 5000
        transfer.completedAt = Date()
        #expect(transfer.status == .completed)
        #expect(transfer.progress == 1.0)
        #expect(transfer.completedAt != nil)
    }

    @Test("FileTransfer status transitions pending to failed")
    func statusTransitionPendingToFailed() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "data.bin",
            fileSize: 10000,
            direction: .incoming
        )
        context.insert(transfer)

        #expect(transfer.status == .pending)

        transfer.status = .transferring
        transfer.transferredBytes = 3000
        #expect(transfer.status == .transferring)

        transfer.status = .failed
        #expect(transfer.status == .failed)
        #expect(transfer.transferredBytes == 3000)
    }

    @Test("FileTransfer cancelled status")
    func cancelledStatus() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "video.mp4",
            fileSize: 50_000_000,
            direction: .outgoing
        )
        context.insert(transfer)

        transfer.status = .transferring
        transfer.transferredBytes = 10_000_000

        transfer.status = .cancelled
        #expect(transfer.status == .cancelled)
        #expect(transfer.transferredBytes == 10_000_000)
    }

    @Test("FileTransfer localPath set after completion")
    func localPathAfterCompletion() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "photo.jpg",
            fileSize: 2048,
            direction: .incoming
        )
        context.insert(transfer)

        transfer.status = .transferring
        transfer.transferredBytes = 2048
        transfer.status = .completed
        transfer.completedAt = Date()
        transfer.localPath = "/Documents/Downloads/photo.jpg"
        try context.save()

        let descriptor = FetchDescriptor<FileTransfer>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched[0].localPath == "/Documents/Downloads/photo.jpg")
        #expect(fetched[0].status == .completed)
    }

    @Test("Query messages by messageType file")
    func queryMessagesByFileType() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let convID = UUID()
        let senderID = UUID()

        let textMsg = Message(
            conversationID: convID,
            senderID: senderID,
            content: "Hello",
            status: .sent,
            messageType: .text
        )
        let fileMsg = Message(
            conversationID: convID,
            senderID: senderID,
            content: "report.pdf",
            status: .sent,
            messageType: .file,
            fileAttachmentID: UUID()
        )
        let textMsg2 = Message(
            conversationID: convID,
            senderID: senderID,
            content: "World",
            status: .sent,
            messageType: .text
        )
        context.insert(textMsg)
        context.insert(fileMsg)
        context.insert(textMsg2)
        try context.save()

        let allDescriptor = FetchDescriptor<Message>()
        let allMessages = try context.fetch(allDescriptor)
        let fileMessages = allMessages.filter { $0.messageType == .file }
        #expect(fileMessages.count == 1)
        #expect(fileMessages[0].content == "report.pdf")
        #expect(fileMessages[0].fileAttachmentID != nil)
    }

    @Test("FileTransfer lastOffset tracks resume position")
    func lastOffsetTracksResumePosition() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "large.zip",
            fileSize: 100_000_000,
            direction: .incoming
        )
        context.insert(transfer)

        #expect(transfer.lastOffset == 0)

        transfer.status = .transferring
        transfer.transferredBytes = 25_000_000
        transfer.lastOffset = 25_000_000

        #expect(transfer.lastOffset == 25_000_000)

        transfer.status = .failed
        try context.save()

        let descriptor = FetchDescriptor<FileTransfer>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched[0].lastOffset == 25_000_000)
        #expect(fetched[0].status == .failed)
    }
}
