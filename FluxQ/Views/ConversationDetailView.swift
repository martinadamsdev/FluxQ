import SwiftUI

/// 对话详情视图 - 显示消息历史和输入框
struct ConversationDetailView: View {
    let conversationId: UUID?

    var body: some View {
        if let conversationId {
            VStack {
                // 消息历史区域
                ScrollView {
                    VStack(spacing: 12) {
                        Text("对话 ID: \(conversationId.uuidString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // TODO: 实际的消息列表
                        Text("消息历史将在这里显示")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                Divider()

                // 输入框区域
                HStack {
                    TextField("输入消息...", text: .constant(""))
                        .textFieldStyle(.roundedBorder)

                    Button(action: {
                        // TODO: 发送消息
                    }) {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("对话详情")
            #if os(macOS)
            .navigationSubtitle("macOS")
            #endif
        } else {
            // 未选中任何对话
            ContentUnavailableView(
                "选择一个对话",
                systemImage: "message.fill",
                description: Text("从左侧列表中选择一个对话以查看详情")
            )
        }
    }
}

#Preview("已选中") {
    NavigationStack {
        ConversationDetailView(conversationId: UUID())
    }
}

#Preview("未选中") {
    NavigationStack {
        ConversationDetailView(conversationId: nil)
    }
}
