import SwiftUI
import Foundation

struct MainTabView: View {
    @State private var selectedTab: AppNavigationItem = .messages
    @State private var activeConversationId: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationListView(activeConversationId: $activeConversationId)
                .tabItem {
                    Label("消息", systemImage: "message.fill")
                }
                .tag(AppNavigationItem.messages)

            ContactsView()
                .tabItem {
                    Label("通讯录", systemImage: "person.2.fill")
                }
                .tag(AppNavigationItem.contacts)

            NavigationStack {
                DiscoveryView()
            }
                .tabItem {
                    Label("发现", systemImage: "globe")
                }
                .tag(AppNavigationItem.discovery)

            NavigationStack {
                SettingsView()
            }
                .tabItem {
                    Label("我", systemImage: "person.fill")
                }
                .tag(AppNavigationItem.settings)
        }
        .environment(\.startChat, StartChatAction { conversationId in
            activeConversationId = conversationId
            selectedTab = .messages
        })
        .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
            if let conversationId = notification.userInfo?["conversationId"] as? UUID {
                activeConversationId = conversationId
                selectedTab = .messages
            }
        }
    }
}

#Preview {
    MainTabView()
}
