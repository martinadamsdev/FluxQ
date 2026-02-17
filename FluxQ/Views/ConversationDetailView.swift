import SwiftUI
import SwiftData
import FluxQModels
import FluxQServices
import IPMsgProtocol
import FluxQUI

/// 对话详情视图 - 显示消息历史和输入框
struct ConversationDetailView: View {
    let conversationId: UUID?

    @Environment(\.modelContext) private var modelContext
    @State private var messageText = ""
    @State private var scrollTarget: UUID?

    @EnvironmentObject private var networkManager: NetworkManager
    @State private var typingUsername: String?

    private var currentUserID: UUID {
        CurrentUserService.currentUser(
            networkManager: networkManager,
            in: modelContext
        ).id
    }

    #if os(iOS)
    @Environment(\.deviceCategory) private var deviceCategory
    @Environment(\.shouldApplyOneHandedOptimization) private var shouldOptimize
    #endif

    var body: some View {
        if let conversationId {
            conversationContent(conversationId: conversationId)
                .navigationTitle("对话详情")
                #if os(macOS)
                .navigationSubtitle("macOS")
                #endif
        } else {
            ContentUnavailableView(
                "选择一个对话",
                systemImage: "message.fill",
                description: Text("从左侧列表中选择一个对话以查看详情")
            )
        }
    }

    // MARK: - Conversation Content

    @ViewBuilder
    private func conversationContent(conversationId: UUID) -> some View {
        VStack(spacing: 0) {
            messageList(conversationId: conversationId)

            Divider()

            // Typing indicator
            if let username = typingUsername {
                TypingIndicatorView(username: username)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            #if os(iOS)
            if shouldOptimize {
                QuickActionBar(
                    actions: Self.quickActions,
                    category: deviceCategory
                )
            }
            #endif

            inputBar(conversationId: conversationId)
        }
    }

    // MARK: - Message List

    @ViewBuilder
    private func messageList(conversationId: UUID) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    let messages = fetchMessages(for: conversationId)
                    if messages.isEmpty {
                        ContentUnavailableView(
                            "暂无消息",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("发送第一条消息开始对话")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(messages, id: \.id) { message in
                            let isFromMe = message.senderID == currentUserID
                            MessageBubbleView(
                                content: message.content,
                                isFromMe: isFromMe,
                                timestamp: message.timestamp,
                                status: message.status,
                                isRecalled: message.isRecalled,
                                onResend: message.status == .failed ? {
                                    resendMessage(message, to: conversationId)
                                } : nil
                            )
                            .id(message.id)
                            .contextMenu {
                                messageContextMenu(for: message, isFromMe: isFromMe)
                            }
                        }
                    }
                }
                .padding()
            }
            .onChange(of: scrollTarget) { _, newValue in
                if let target = newValue {
                    withAnimation {
                        proxy.scrollTo(target, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func messageContextMenu(for message: Message, isFromMe: Bool) -> some View {
        if !message.isRecalled {
            Button {
                copyToClipboard(message.content)
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }

            Button {
                // TODO: Wire up forward with MessageActionService
            } label: {
                Label("转发", systemImage: "arrowshape.turn.up.right")
            }

            if isFromMe {
                let canRecall = Date().timeIntervalSince(message.timestamp) <= 120
                if canRecall {
                    Button(role: .destructive) {
                        recallMessage(message)
                    } label: {
                        Label("撤回", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    @ViewBuilder
    private func inputBar(conversationId: UUID) -> some View {
        HStack {
            TextField("输入消息...", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    sendMessage(to: conversationId)
                }

            Button(action: {
                sendMessage(to: conversationId)
            }) {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    // MARK: - Actions

    private func sendMessage(to conversationId: UUID) {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let message = Message(
            conversationID: conversationId,
            senderID: currentUserID,
            content: trimmed,
            status: .sending
        )
        modelContext.insert(message)
        messageText = ""
        scrollTarget = message.id

        let targetUser = findTargetUser(for: conversationId)

        Task {
            do {
                if let user = targetUser {
                    try await networkManager.sendMessage(to: user, message: trimmed)
                }
                message.status = .sent
                try? modelContext.save()
            } catch {
                message.status = .failed
                try? modelContext.save()
            }
        }
    }

    private func resendMessage(_ message: Message, to conversationId: UUID) {
        message.status = .sending
        let content = message.content
        let targetUser = findTargetUser(for: conversationId)

        Task {
            do {
                if let user = targetUser {
                    try await networkManager.sendMessage(to: user, message: content)
                }
                message.status = .sent
                try? modelContext.save()
            } catch {
                message.status = .failed
                try? modelContext.save()
            }
        }
    }

    private func findTargetUser(for conversationId: UUID) -> DiscoveredUser? {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )
        guard let conversation = try? modelContext.fetch(descriptor).first,
              let participant = conversation.participants?.first else {
            return nil
        }

        return networkManager.discoveredUsers.values.first {
            $0.ipAddress == participant.ipAddress
        }
    }

    private func recallMessage(_ message: Message) {
        message.isRecalled = true
        message.recalledAt = Date()
        try? modelContext.save()

        Task {
            try? networkManager.sendBroadcast(
                command: .RECALLMSG,
                payload: message.id.uuidString
            )
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }

    private func fetchMessages(for conversationId: UUID) -> [Message] {
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.conversationID == conversationId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Quick Actions

#if os(iOS)
extension ConversationDetailView {
    static let quickActions: [QuickAction] = [
        .init(icon: "photo", label: "相册") {
            // TODO: 选择照片
        },
        .init(icon: "camera", label: "拍照") {
            // TODO: 打开相机
        },
        .init(icon: "folder", label: "文件") {
            // TODO: 选择文件
        },
        .init(icon: "location", label: "位置") {
            // TODO: 分享位置
        }
    ]
}
#endif

#Preview("已选中") {
    NavigationStack {
        ConversationDetailView(conversationId: UUID())
    }
    .modelContainer(for: Message.self, inMemory: true)
}

#Preview("未选中") {
    NavigationStack {
        ConversationDetailView(conversationId: nil)
    }
}
