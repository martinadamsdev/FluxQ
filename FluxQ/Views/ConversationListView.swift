import SwiftUI
import SwiftData
import FluxQModels

struct ConversationListView: View {
    /// macOS/iPad: selection binding for multi-column layout
    @Binding var selection: UUID?

    /// iPhone: programmatic navigation target
    @Binding var activeConversationId: UUID?

    #if os(iOS)
    @Environment(\.deviceCategory) private var deviceCategory
    #endif

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.lastMessageTimestamp, order: .reverse)
    private var conversations: [Conversation]

    @State private var navigationPath = NavigationPath()

    /// Whether this view manages its own NavigationStack (iPhone mode)
    private let usesOwnNavigationStack: Bool

    var body: some View {
        if usesOwnNavigationStack {
            NavigationStack(path: $navigationPath) {
                listContent
                    .navigationDestination(for: UUID.self) { conversationId in
                        ConversationDetailView(conversationId: conversationId)
                    }
            }
            .onChange(of: activeConversationId) { _, newValue in
                if let id = newValue {
                    navigationPath.append(id)
                    activeConversationId = nil
                }
            }
        } else {
            listContent
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List(selection: $selection) {
            if conversations.isEmpty {
                ContentUnavailableView {
                    Label("暂无消息", systemImage: "message.fill")
                } description: {
                    Text("从发现页开始新的对话")
                }
            } else {
                ForEach(conversations) { conversation in
                    conversationRow(conversation)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("消息")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // TODO: 新建群聊
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - 会话行视图

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation) -> some View {
        let participant = conversation.participants?.first

        HStack(spacing: 12) {
            // 头像
            UserAvatarView(
                avatarData: participant?.avatarData,
                size: 48
            )

            // 消息内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.lastMessageTimestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(lastMessageText(for: conversation))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func lastMessageText(for conversation: Conversation) -> String {
        guard let messages = conversation.messages,
              let last = messages.max(by: { $0.timestamp < $1.timestamp }) else {
            return "暂无消息"
        }
        return last.isRecalled ? "消息已撤回" : last.content
    }
}

// MARK: - 向后兼容

extension ConversationListView {
    /// macOS/iPad: selection binding, no own NavigationStack
    init(selection: Binding<UUID?>) {
        self._selection = selection
        self._activeConversationId = .constant(nil)
        self.usesOwnNavigationStack = false
    }

    /// iPhone: activeConversationId binding, uses own NavigationStack
    init(activeConversationId: Binding<UUID?>) {
        self._selection = .constant(nil)
        self._activeConversationId = activeConversationId
        self.usesOwnNavigationStack = true
    }

    /// Default init (preview only)
    init() {
        self._selection = .constant(nil)
        self._activeConversationId = .constant(nil)
        self.usesOwnNavigationStack = true
    }
}

// MARK: - Previews

#Preview("消息列表") {
    NavigationStack {
        ConversationListView()
    }
    .modelContainer(for: [User.self, Message.self, Conversation.self], inMemory: true)
}
