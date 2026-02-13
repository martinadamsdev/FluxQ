import SwiftUI

/// macOS 主视图 - 三栏布局
struct MacMainView: View {
    @State private var selectedTab: MacNavigationItem = .messages
    @State private var selectedConversation: UUID?
    @State private var selectedContact: UUID?

    var body: some View {
        NavigationSplitView {
            // 第一栏：侧边栏导航
            MacSidebarView(selection: $selectedTab)
        } content: {
            // 第二栏：内容列表（根据选中的 tab 变化）
            contentColumn
        } detail: {
            // 第三栏：详情（根据选中的 tab 和项目变化）
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch selectedTab {
        case .messages:
            ConversationListView(selection: $selectedConversation)
        case .contacts:
            ContactsListView(selection: $selectedContact)
        case .discovery, .settings:
            // 这两个不需要中间栏
            EmptyView()
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch selectedTab {
        case .messages:
            ConversationDetailView(conversationId: selectedConversation)
        case .contacts:
            ContactDetailView(contactId: selectedContact)
        case .discovery:
            DiscoveryView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    MacMainView()
        .frame(width: 1200, height: 700)
}
