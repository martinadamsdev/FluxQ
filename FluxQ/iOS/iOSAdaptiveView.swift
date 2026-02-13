import SwiftUI

/// iOS/iPadOS 自适应视图
struct iOSAdaptiveView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // 状态保持：切换布局时保留选中项
    @State private var selectedTab: MacNavigationItem = .messages
    @State private var selectedConversation: UUID?
    @State private var selectedContact: UUID?

    /// 是否应该使用多栏布局
    private var shouldUseMultiColumn: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if shouldUseMultiColumn {
                // iPad 横屏 - 多栏布局
                iPadSplitView(
                    selectedTab: $selectedTab,
                    selectedConversation: $selectedConversation,
                    selectedContact: $selectedContact
                )
            } else {
                // iPad 竖屏或 iPhone - 标签栏
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldUseMultiColumn)
    }
}

#Preview("iPad 横屏") {
    iOSAdaptiveView()
        .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("iPad 竖屏") {
    iOSAdaptiveView()
        .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        .previewInterfaceOrientation(.portrait)
}

#Preview("iPhone") {
    iOSAdaptiveView()
        .previewDevice("iPhone 15 Pro")
}
