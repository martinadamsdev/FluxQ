import Foundation
import SwiftData

@Model
public final class User {
    @Attribute(.unique) public var id: String
    public var nickname: String
    public var hostname: String
    public var ipAddress: String
    public var port: Int
    public var group: String?
    public var status: UserStatus
    public var isOnline: Bool
    public var lastSeen: Date
    public var avatarData: Data?
    public var avatarHash: String?

    @Relationship(deleteRule: .cascade, inverse: \Conversation.participants)
    public var conversations: [Conversation]?

    public init(
        id: String,
        nickname: String,
        hostname: String,
        ipAddress: String,
        port: Int = 2425,
        group: String? = nil,
        status: UserStatus = .online,
        isOnline: Bool = true,
        lastSeen: Date = Date(),
        avatarData: Data? = nil,
        avatarHash: String? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.hostname = hostname
        self.ipAddress = ipAddress
        self.port = port
        self.group = group
        self.status = status
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.avatarData = avatarData
        self.avatarHash = avatarHash
    }
}
