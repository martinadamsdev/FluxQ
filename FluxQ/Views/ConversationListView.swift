import SwiftUI

struct ConversationListView: View {
    /// 可选的选中状态（macOS/iPad 多栏布局需要）
    @Binding var selection: UUID?

    var body: some View {
        List(selection: $selection) {
            // TODO: 替换为实际的对话数据
            ContentUnavailableView {
                Label("暂无消息", systemImage: "message.fill")
            } description: {
                Text("开始一个新的对话")
            }
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

// 向后兼容：不需要 selection 的初始化器
extension ConversationListView {
    init() {
        self._selection = .constant(nil)
    }
}

#Preview {
    NavigationStack {
        ConversationListView()
    }
}
