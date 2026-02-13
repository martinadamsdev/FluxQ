import SwiftUI

/// iPhone 单手操作优化包装视图
///
/// 检测设备类别并根据横竖屏状态决定是否应用单手操作优化。
/// 竖屏时应用自适应间距和单手优化 modifier，横屏时使用标准布局。
struct iPhoneOptimizedView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var deviceCategory: iPhoneCategory = .current

    /// 仅在竖屏时应用优化
    private var shouldOptimize: Bool {
        verticalSizeClass == .regular
    }

    var body: some View {
        MainTabView()
            .environment(\.deviceCategory, deviceCategory)
            .environment(\.shouldApplyOneHandedOptimization, shouldOptimize)
    }
}

// MARK: - Environment Keys

/// 设备类别 Environment Key
private struct DeviceCategoryKey: EnvironmentKey {
    static let defaultValue: iPhoneCategory = .standard
}

/// 单手优化启用状态 Environment Key
private struct OneHandedOptimizationKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var deviceCategory: iPhoneCategory {
        get { self[DeviceCategoryKey.self] }
        set { self[DeviceCategoryKey.self] = newValue }
    }

    var shouldApplyOneHandedOptimization: Bool {
        get { self[OneHandedOptimizationKey.self] }
        set { self[OneHandedOptimizationKey.self] = newValue }
    }
}

// MARK: - Previews

#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    iPhoneOptimizedView()
}

#Preview("iPhone 15", traits: .fixedLayout(width: 393, height: 852)) {
    iPhoneOptimizedView()
}

#Preview("iPhone 15 Pro Max", traits: .fixedLayout(width: 430, height: 932)) {
    iPhoneOptimizedView()
}

#Preview("横屏模式", traits: .landscapeLeft) {
    iPhoneOptimizedView()
}
