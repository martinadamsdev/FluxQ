import SwiftUI

/// iPad 横屏多栏视图
struct iPadSplitView: View {
    @Binding var selectedTab: AppNavigationItem
    @Binding var selectedConversation: UUID?
    @Binding var selectedContact: UUID?

    var body: some View {
        NavigationSplitView {
            // 第一栏：侧边栏
            SidebarView(selection: $selectedTab)
        } content: {
            // 第二栏：内容列表
            contentColumn
        } detail: {
            // 第三栏：详情
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
    iPadSplitView(
        selectedTab: .constant(.messages),
        selectedConversation: .constant(nil),
        selectedContact: .constant(nil)
    )
    .previewDevice("iPad Pro (12.9-inch) (6th generation)")
    .previewInterfaceOrientation(.landscapeLeft)
}
