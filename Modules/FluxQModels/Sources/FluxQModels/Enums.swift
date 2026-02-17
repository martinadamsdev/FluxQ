import Foundation

public enum UserStatus: String, Codable, CaseIterable {
    case online
    case away
    case busy
    case offline

    public var displayName: String {
        switch self {
        case .online: return "在线"
        case .away: return "离开"
        case .busy: return "忙碌"
        case .offline: return "离线"
        }
    }
}

public enum MessageStatus: String, Codable {
    case pending
    case sending
    case sent
    case delivered
    case read
    case failed
}

public enum ConversationType: String, Codable {
    case `private`
    case group
}

public enum TransferStatus: String, Codable {
    case pending
    case transferring
    case completed
    case failed
    case cancelled
}

public enum TransferDirection: String, Codable {
    case outgoing
    case incoming
}

public enum MessageType: String, Codable {
    case text
    case file
    case image
}
