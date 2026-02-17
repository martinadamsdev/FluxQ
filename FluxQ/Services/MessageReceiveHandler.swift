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
        // 1. 查找或创建发送方 User 和 Conversation（同时获取 userId）
        let (conversationId, senderID) = ConversationService.findOrCreateConversation(
            hostname: received.hostname,
            senderName: received.senderName,
            nickname: received.senderName,
            ipAddress: received.fromHost,
            port: 2425,
            group: nil,
            in: context
        )

        // 2. 创建 Message
        let message = Message(
            conversationID: conversationId,
            senderID: senderID,
            content: received.content,
            status: .delivered
        )
        context.insert(message)

        // 3. 更新会话时间戳和未读计数
        let convDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )
        if let conversation = try? context.fetch(convDescriptor).first {
            conversation.lastMessageTimestamp = Date()
            conversation.unreadCount += 1
        }

        try? context.save()
    }

    /// 处理收到的撤回命令
    static func handleRecallCommand(
        messageIDString: String,
        in context: ModelContext
    ) {
        guard let messageID = UUID(uuidString: messageIDString) else { return }

        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.id == messageID }
        )

        if let message = try? context.fetch(descriptor).first {
            message.isRecalled = true
            message.recalledAt = Date()
            try? context.save()
        }
    }
}
