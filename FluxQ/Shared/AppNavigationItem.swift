import SwiftUI

/// 应用导航项 - 跨平台共享
enum AppNavigationItem: String, Identifiable, CaseIterable {
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
