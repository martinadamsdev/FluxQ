import Foundation
import SwiftData

@Model
public final class Message {
    @Attribute(.unique) public var id: UUID
    public var conversationID: UUID
    public var senderID: UUID
    public var content: String
    public var timestamp: Date
    public var status: MessageStatus
    public var isEncrypted: Bool
    public var isRecalled: Bool
    public var recalledAt: Date?

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        senderID: UUID,
        content: String,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        isEncrypted: Bool = false,
        isRecalled: Bool = false,
        recalledAt: Date? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.content = content
        self.timestamp = timestamp
        self.status = status
        self.isEncrypted = isEncrypted
        self.isRecalled = isRecalled
        self.recalledAt = recalledAt
    }
}
