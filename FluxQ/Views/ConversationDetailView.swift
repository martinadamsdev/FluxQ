import SwiftUI

/// 对话详情视图 - 显示消息历史和输入框
struct ConversationDetailView: View {
    let conversationId: UUID?

    #if os(iOS)
    @Environment(\.deviceCategory) private var deviceCategory
    @Environment(\.shouldApplyOneHandedOptimization) private var shouldOptimize
    #endif

    var body: some View {
        if let conversationId {
            VStack(spacing: 0) {
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

                #if os(iOS)
                // iPhone 快捷操作栏（仅竖屏优化时显示）
                if shouldOptimize {
                    QuickActionBar(
                        actions: Self.quickActions,
                        category: deviceCategory
                    )
                }
                #endif

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
}

#Preview("未选中") {
    NavigationStack {
        ConversationDetailView(conversationId: nil)
    }
}
