import SwiftUI

#if os(iOS)
/// 底部快捷操作栏 - 为消息详情页提供快捷操作
struct QuickActionBar: View {
    let actions: [QuickAction]
    let category: iPhoneCategory

    var body: some View {
        HStack(spacing: 0) {
            ForEach(actions.indices, id: \.self) { index in
                actionButton(actions[index])
                if index < actions.count - 1 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AdaptiveSpacing.horizontalPadding(for: category))
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func actionButton(_ action: QuickAction) -> some View {
        Button(action: action.action) {
            switch category {
            case .compact:
                // Compact 设备 - 仅图标
                VStack(spacing: 4) {
                    Image(systemName: action.icon)
                        .font(.system(size: 24))
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())

            case .standard, .large:
                // Standard/Large 设备 - 图标+文字
                VStack(spacing: 4) {
                    Image(systemName: action.icon)
                        .font(.system(size: 22))
                    Text(action.label)
                        .font(.caption2)
                }
                .frame(width: 60, height: 50)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
}

/// 快捷操作定义
struct QuickAction {
    let icon: String
    let label: String
    let action: () -> Void

    init(icon: String, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }
}

// MARK: - Previews

private let previewActions: [QuickAction] = [
    .init(icon: "photo", label: "相册") { },
    .init(icon: "camera", label: "拍照") { },
    .init(icon: "folder", label: "文件") { },
    .init(icon: "location", label: "位置") { }
]

#Preview("Compact 设备") {
    VStack {
        Spacer()
        QuickActionBar(
            actions: previewActions,
            category: .compact
        )
    }
    .frame(width: 375, height: 667)
}

#Preview("Standard 设备") {
    VStack {
        Spacer()
        QuickActionBar(
            actions: previewActions,
            category: .standard
        )
    }
    .frame(width: 393, height: 852)
}

#Preview("Large 设备") {
    VStack {
        Spacer()
        QuickActionBar(
            actions: previewActions,
            category: .large
        )
    }
    .frame(width: 430, height: 932)
}
#endif
