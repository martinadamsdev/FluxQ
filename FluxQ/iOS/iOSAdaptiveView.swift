import SwiftUI

/// iOS/iPadOS 自适应视图
struct iOSAdaptiveView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // 状态保持：使用 @SceneStorage 确保旋转和布局切换时保留选中项
    @SceneStorage("selectedTab") private var selectedTabRawValue: String = AppNavigationItem.messages.rawValue
    @State private var selectedConversation: UUID?
    @State private var selectedContact: UUID?

    private var selectedTab: Binding<AppNavigationItem> {
        Binding(
            get: { AppNavigationItem(rawValue: selectedTabRawValue) ?? .messages },
            set: { selectedTabRawValue = $0.rawValue }
        )
    }

    /// 是否应该使用多栏布局
    private var shouldUseMultiColumn: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if shouldUseMultiColumn {
                // iPad 横屏 - 多栏布局
                iPadSplitView(
                    selectedTab: selectedTab,
                    selectedConversation: $selectedConversation,
                    selectedContact: $selectedContact
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                // iPad 竖屏或 iPhone - 标签栏
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: shouldUseMultiColumn)
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
