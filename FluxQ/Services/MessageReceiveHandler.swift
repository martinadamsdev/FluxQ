import Foundation
import SwiftData
import FluxQModels
import FluxQServices

@MainActor
enum MessageReceiveHandler {

    /// 处理收到的消息，持久化到 SwiftData
    static func handleReceivedMessage(
        _ received: ReceivedMessage,
        in context: ModelContext
    ) {
        // 1. 查找或创建发送方 User 和 Conversation
        let conversationId = ConversationService.findOrCreateConversation(
            hostname: received.hostname,
            senderName: received.senderName,
            nickname: received.senderName,
            ipAddress: received.fromHost,
            port: 2425,
            group: nil,
            in: context
        )

        // 2. 查找发送方 User ID
        let senderHostname = received.hostname
        let senderIP = received.fromHost
        let senderDescriptor = FetchDescriptor<User>(
            predicate: #Predicate {
                $0.hostname == senderHostname && $0.ipAddress == senderIP
            }
        )
        let senderID = (try? context.fetch(senderDescriptor).first)?.id ?? UUID()

        // 3. 创建 Message
        let message = Message(
            conversationID: conversationId,
            senderID: senderID,
            content: received.content,
            status: .delivered
        )
        context.insert(message)

        // 4. 更新会话时间戳和未读计数
        let convDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )
        if let conversation = try? context.fetch(convDescriptor).first {
            conversation.lastMessageTimestamp = Date()
            conversation.unreadCount += 1
        }

        try? context.save()
    }
}
