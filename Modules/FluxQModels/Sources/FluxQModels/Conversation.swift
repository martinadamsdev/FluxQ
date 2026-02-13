import Foundation
import SwiftData

@Model
public final class Conversation {
    @Attribute(.unique) public var id: String
    public var type: ConversationType
    public var participantIDs: [String]
    public var lastMessageTimestamp: Date
    public var unreadCount: Int

    @Relationship(deleteRule: .nullify)
    public var participants: [User]?

    @Relationship(deleteRule: .cascade)
    public var messages: [Message]?

    public init(
        id: String = UUID().uuidString,
        type: ConversationType,
        participantIDs: [String],
        lastMessageTimestamp: Date = Date(),
        unreadCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.participantIDs = participantIDs
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
    }
}
