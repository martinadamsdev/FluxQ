import Foundation
import SwiftData

@Model
public final class Conversation {
    @Attribute(.unique) public var id: UUID
    public var type: ConversationType
    public var participantIDs: [UUID]
    public var lastMessageTimestamp: Date
    public var unreadCount: Int

    @Relationship(deleteRule: .nullify)
    public var participants: [User]?

    @Relationship(deleteRule: .cascade)
    public var messages: [Message]?

    public init(
        id: UUID = UUID(),
        type: ConversationType,
        participantIDs: [UUID],
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
