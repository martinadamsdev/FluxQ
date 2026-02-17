import Foundation
import SwiftData

public enum ConversationService {

    /// Find an existing 1:1 conversation with the user, or create a new one.
    ///
    /// Matching logic:
    /// 1. Find User by hostname + ipAddress (stable identifiers on LAN)
    /// 2. If not found, create and persist a new User
    /// 3. Find existing private Conversation whose participantIDs contains the user
    /// 4. If found, update lastMessageTimestamp (to sort it to top) and return its ID
    /// 5. If not found, create a new Conversation and return its ID
    @discardableResult
    public static func findOrCreateConversation(
        hostname: String,
        senderName: String,
        nickname: String,
        ipAddress: String,
        port: Int,
        group: String?,
        in context: ModelContext
    ) -> UUID {
        let user = findOrCreateUser(
            hostname: hostname,
            nickname: nickname,
            ipAddress: ipAddress,
            port: port,
            group: group,
            in: context
        )

        let conversationId = findOrCreatePrivateConversation(
            with: user,
            in: context
        )

        try? context.save()
        return conversationId
    }

    private static func findOrCreateUser(
        hostname: String,
        nickname: String,
        ipAddress: String,
        port: Int,
        group: String?,
        in context: ModelContext
    ) -> User {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate {
                $0.hostname == hostname && $0.ipAddress == ipAddress
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.nickname = nickname
            existing.isOnline = true
            existing.lastSeen = Date()
            return existing
        }

        let newUser = User(
            nickname: nickname,
            hostname: hostname,
            ipAddress: ipAddress,
            port: port,
            group: group,
            status: .online,
            isOnline: true
        )
        context.insert(newUser)
        return newUser
    }

    private static func findOrCreatePrivateConversation(
        with user: User,
        in context: ModelContext
    ) -> UUID {
        // SwiftData #Predicate has limited support for enum comparison
        // and .contains() on arrays, so we fetch all conversations and
        // filter in memory. For a LAN messenger, the data volume is small.
        let allConversations = (try? context.fetch(FetchDescriptor<Conversation>())) ?? []
        let userId = user.id

        if let existing = allConversations.first(where: {
            $0.type == .private && $0.participantIDs.contains(userId)
        }) {
            existing.lastMessageTimestamp = Date()
            return existing.id
        }

        let conversation = Conversation(
            type: .private,
            participantIDs: [user.id]
        )
        conversation.participants = [user]
        context.insert(conversation)
        return conversation.id
    }
}
