import SwiftUI

#if os(macOS)

/// macOS 导航 tab 的 FocusedValue key
struct SelectedTabKey: FocusedValueKey {
    typealias Value = Binding<AppNavigationItem>
}

extension FocusedValues {
    var selectedTab: Binding<AppNavigationItem>? {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

/// macOS 主视图 - 三栏布局
struct MacMainView: View {
    @State private var selectedTab: AppNavigationItem = .messages
    @State private var selectedConversation: UUID?
    @State private var selectedContact: UUID?

    private var needsContentColumn: Bool {
        selectedTab == .messages || selectedTab == .contacts
    }

    var body: some View {
        Group {
            if needsContentColumn {
                NavigationSplitView {
                    SidebarView(selection: $selectedTab)
                } content: {
                    contentColumn
                } detail: {
                    detailColumn
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationSplitView {
                    SidebarView(selection: $selectedTab)
                } detail: {
                    detailColumn
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .focusedSceneValue(\.selectedTab, $selectedTab)
        .environment(\.startChat, StartChatAction { conversationId in
            selectedTab = .messages
            selectedConversation = conversationId
        })
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

/// macOS 键盘快捷键命令
struct NavigationCommands: Commands {
    @FocusedBinding(\.selectedTab) private var selectedTab

    var body: some Commands {
        CommandGroup(replacing: .sidebar) {
            Button("消息") {
                selectedTab = .messages
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("通讯录") {
                selectedTab = .contacts
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("发现") {
                selectedTab = .discovery
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("我") {
                selectedTab = .settings
            }
            .keyboardShortcut("4", modifiers: .command)
        }
    }
}

#Preview {
    MacMainView()
        .frame(width: 1200, height: 700)
}

#endif
