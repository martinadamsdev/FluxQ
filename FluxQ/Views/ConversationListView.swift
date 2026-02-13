import SwiftUI

struct ConversationListView: View {
    /// 可选的选中状态（macOS/iPad 多栏布局需要）
    @Binding var selection: UUID?

    #if os(iOS)
    @Environment(\.deviceCategory) private var deviceCategory
    #endif

    /// 示例对话数据 - TODO: 替换为实际的对话数据源
    @State private var sampleConversations: [SampleConversation] = SampleConversation.examples

    var body: some View {
        List(selection: $selection) {
            if sampleConversations.isEmpty {
                ContentUnavailableView {
                    Label("暂无消息", systemImage: "message.fill")
                } description: {
                    Text("开始一个新的对话")
                }
            } else {
                ForEach(sampleConversations) { conversation in
                    #if os(iOS)
                    conversationRowWithSwipe(conversation)
                    #else
                    conversationRow(conversation)
                    #endif
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
    private func conversationRow(_ conversation: SampleConversation) -> some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(conversation.avatarColor)
                .frame(width: 48, height: 48)
                .overlay {
                    Text(conversation.avatarInitial)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }

            // 消息内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(conversation.lastMessage)
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

    #if os(iOS)
    @ViewBuilder
    private func conversationRowWithSwipe(_ conversation: SampleConversation) -> some View {
        SwipeableListItem(
            content: {
                conversationRow(conversation)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(Color(.systemBackground))
            },
            leadingActions: [
                SwipeAction(
                    icon: conversation.isRead ? "envelope.badge" : "checkmark.circle",
                    color: .blue
                ) {
                    toggleRead(conversation)
                }
            ],
            trailingActions: [
                SwipeAction(icon: "pin.fill", color: .orange) {
                    pinConversation(conversation)
                },
                SwipeAction(icon: "trash", color: .red) {
                    deleteConversation(conversation)
                }
            ]
        )
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }
    #endif

    // MARK: - 操作方法

    private func toggleRead(_ conversation: SampleConversation) {
        // TODO: 实现标记已读/未读逻辑
        if let index = sampleConversations.firstIndex(where: { $0.id == conversation.id }) {
            sampleConversations[index].isRead.toggle()
        }
    }

    private func deleteConversation(_ conversation: SampleConversation) {
        // TODO: 实现删除逻辑，添加确认弹窗
        withAnimation {
            sampleConversations.removeAll { $0.id == conversation.id }
        }
    }

    private func pinConversation(_ conversation: SampleConversation) {
        // TODO: 实现置顶逻辑
        if let index = sampleConversations.firstIndex(where: { $0.id == conversation.id }) {
            sampleConversations[index].isPinned.toggle()
        }
    }
}

// MARK: - 示例数据模型

/// 示例对话数据 - TODO: 替换为 FluxQModels 中的 Conversation 模型
private struct SampleConversation: Identifiable {
    let id: UUID
    let name: String
    let lastMessage: String
    let timeString: String
    let avatarColor: Color
    let unreadCount: Int
    var isRead: Bool
    var isPinned: Bool

    var avatarInitial: String {
        String(name.prefix(1))
    }

    static let examples: [SampleConversation] = [
        SampleConversation(
            id: UUID(), name: "张三", lastMessage: "明天一起吃午饭吗？",
            timeString: "12:30", avatarColor: .blue, unreadCount: 2,
            isRead: false, isPinned: false
        ),
        SampleConversation(
            id: UUID(), name: "产品组", lastMessage: "[李四] 新版设计稿已更新",
            timeString: "11:15", avatarColor: .green, unreadCount: 5,
            isRead: false, isPinned: true
        ),
        SampleConversation(
            id: UUID(), name: "王五", lastMessage: "收到，谢谢！",
            timeString: "昨天", avatarColor: .orange, unreadCount: 0,
            isRead: true, isPinned: false
        ),
        SampleConversation(
            id: UUID(), name: "赵六", lastMessage: "文件已发送，请查收",
            timeString: "昨天", avatarColor: .purple, unreadCount: 0,
            isRead: true, isPinned: false
        ),
        SampleConversation(
            id: UUID(), name: "技术部", lastMessage: "[孙七] 版本已部署到测试环境",
            timeString: "周一", avatarColor: .red, unreadCount: 0,
            isRead: true, isPinned: false
        ),
    ]
}

// MARK: - 向后兼容

extension ConversationListView {
    init() {
        self._selection = .constant(nil)
    }
}

// MARK: - Previews

#Preview("消息列表") {
    NavigationStack {
        ConversationListView()
    }
}

#Preview("空列表") {
    NavigationStack {
        ConversationListView()
    }
}
