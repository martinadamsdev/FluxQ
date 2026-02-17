import Foundation
import SwiftData

@Model
public final class FileTransfer {
    @Attribute(.unique) public var id: UUID
    public var conversationID: UUID
    public var messageID: UUID?
    public var senderID: UUID
    public var fileName: String
    public var fileSize: Int64
    public var transferredBytes: Int64
    public var status: TransferStatus
    public var direction: TransferDirection
    public var localPath: String?
    public var timestamp: Date
    public var completedAt: Date?
    public var lastOffset: Int64

    /// 传输进度 (0.0 - 1.0)
    public var progress: Double {
        guard fileSize > 0 else { return 0 }
        return Double(transferredBytes) / Double(fileSize)
    }

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        messageID: UUID? = nil,
        senderID: UUID,
        fileName: String,
        fileSize: Int64,
        transferredBytes: Int64 = 0,
        status: TransferStatus = .pending,
        direction: TransferDirection,
        localPath: String? = nil,
        timestamp: Date = Date(),
        completedAt: Date? = nil,
        lastOffset: Int64 = 0
    ) {
        self.id = id
        self.conversationID = conversationID
        self.messageID = messageID
        self.senderID = senderID
        self.fileName = fileName
        self.fileSize = fileSize
        self.transferredBytes = transferredBytes
        self.status = status
        self.direction = direction
        self.localPath = localPath
        self.timestamp = timestamp
        self.completedAt = completedAt
        self.lastOffset = lastOffset
    }
}
