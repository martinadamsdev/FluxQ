import SwiftUI

struct ConversationListView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "message.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                Text("暂无消息")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("开始一个新的对话")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
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
    }
}

#Preview {
    ConversationListView()
}
