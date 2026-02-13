import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ConversationListView()
                .tabItem {
                    Label("消息", systemImage: "message.fill")
                }

            ContactsView()
                .tabItem {
                    Label("通讯录", systemImage: "person.2.fill")
                }

            DiscoveryView()
                .tabItem {
                    Label("发现", systemImage: "globe")
                }

            SettingsView()
                .tabItem {
                    Label("我", systemImage: "person.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
}
