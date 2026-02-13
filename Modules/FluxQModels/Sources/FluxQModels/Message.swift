import Foundation
import SwiftData

@Model
public final class Message {
    @Attribute(.unique) public var id: String
    public var conversationID: String
    public var senderID: String
    public var content: String
    public var timestamp: Date
    public var status: MessageStatus
    public var isEncrypted: Bool
    public var isRecalled: Bool
    public var recalledAt: Date?

    public init(
        id: String = UUID().uuidString,
        conversationID: String,
        senderID: String,
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
