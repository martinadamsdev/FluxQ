import SwiftUI
import SwiftData
import FluxQModels

/// 转发目标选择器
struct ForwardTargetPicker: View {
    let messageContent: String
    let onSelect: (Conversation) -> Void
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Conversation.lastMessageTimestamp, order: .reverse)
    private var conversations: [Conversation]

    var body: some View {
        NavigationStack {
            List(conversations) { conversation in
                Button {
                    onSelect(conversation)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        UserAvatarView(
                            avatarData: conversation.participants?.first?.avatarData,
                            size: 40
                        )
                        VStack(alignment: .leading) {
                            Text(conversation.displayName)
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("转发到")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
