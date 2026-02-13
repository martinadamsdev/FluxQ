import SwiftUI

/// macOS 导航项
enum MacNavigationItem: String, Identifiable, CaseIterable {
    case messages = "消息"
    case contacts = "通讯录"
    case discovery = "发现"
    case settings = "我"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .messages: return "message.fill"
        case .contacts: return "person.2.fill"
        case .discovery: return "globe"
        case .settings: return "person.fill"
        }
    }
}

/// macOS 侧边栏视图
struct MacSidebarView: View {
    @Binding var selection: MacNavigationItem

    var body: some View {
        List(MacNavigationItem.allCases, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.systemImage)
                .tag(item)
        }
        .navigationTitle("FluxQ")
        .frame(minWidth: 180)
    }
}

#Preview {
    NavigationSplitView {
        MacSidebarView(selection: .constant(.messages))
    } detail: {
        Text("详情")
    }
    .frame(width: 900, height: 600)
}
