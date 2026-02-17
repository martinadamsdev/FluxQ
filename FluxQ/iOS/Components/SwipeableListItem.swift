import SwiftUI

#if os(iOS)
/// 可滑动列表项 - 支持左滑/右滑快捷操作
struct SwipeableListItem<Content: View>: View {
    let content: Content
    let leadingActions: [SwipeAction]   // 右滑显示（左侧操作）
    let trailingActions: [SwipeAction]  // 左滑显示（右侧操作）

    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    private let actionThreshold: CGFloat = 60
    private let actionWidth: CGFloat = 70

    init(
        @ViewBuilder content: () -> Content,
        leadingActions: [SwipeAction] = [],
        trailingActions: [SwipeAction] = []
    ) {
        self.content = content()
        self.leadingActions = leadingActions
        self.trailingActions = trailingActions
    }

    var body: some View {
        ZStack {
            // 底层操作按钮
            HStack {
                if !leadingActions.isEmpty && offset > 0 {
                    HStack(spacing: 0) {
                        ForEach(leadingActions.indices, id: \.self) { index in
                            actionButton(leadingActions[index])
                        }
                    }
                }

                Spacer()

                if !trailingActions.isEmpty && offset < 0 {
                    HStack(spacing: 0) {
                        ForEach(trailingActions.indices, id: \.self) { index in
                            actionButton(trailingActions[index])
                        }
                    }
                }
            }

            // 顶层内容
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            isDragging = true
                            let translation = value.translation.width

                            // 限制滑动范围
                            if !leadingActions.isEmpty && translation > 0 {
                                offset = min(translation, CGFloat(leadingActions.count) * actionWidth)
                            } else if !trailingActions.isEmpty && translation < 0 {
                                offset = max(translation, -CGFloat(trailingActions.count) * actionWidth)
                            }
                        }
                        .onEnded { _ in
                            isDragging = false

                            // 判断是否触发操作
                            if abs(offset) > actionThreshold {
                                // 触发触感反馈
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()

                                // 保持展开状态
                                withAnimation(.easeOut(duration: 0.25)) {
                                    if offset > 0 {
                                        offset = CGFloat(leadingActions.count) * actionWidth
                                    } else {
                                        offset = -CGFloat(trailingActions.count) * actionWidth
                                    }
                                }
                            } else {
                                // 回弹
                                withAnimation(.easeOut(duration: 0.25)) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }

    @ViewBuilder
    private func actionButton(_ action: SwipeAction) -> some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.25)) {
                offset = 0
            }
            action.action()
        }) {
            VStack {
                Image(systemName: action.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .frame(width: actionWidth)
            .frame(maxHeight: .infinity)
            .background(action.color)
        }
    }
}

/// 滑动操作定义
struct SwipeAction {
    let icon: String
    let color: Color
    let action: () -> Void

    init(icon: String, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.action = action
    }
}

#Preview("基础滑动") {
    List {
        SwipeableListItem(
            content: {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("测试消息")
                            .font(.headline)
                        Text("这是一条测试消息内容")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
            },
            leadingActions: [
                .init(icon: "checkmark.circle", color: .blue) {
                    print("标记已读")
                }
            ],
            trailingActions: [
                .init(icon: "trash", color: .red) {
                    print("删除")
                },
                .init(icon: "pin.fill", color: .orange) {
                    print("置顶")
                }
            ]
        )
    }
    .listStyle(.plain)
}

#Preview("仅左滑") {
    List {
        SwipeableListItem(
            content: {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.green)
                    Text("联系人")
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
            },
            trailingActions: [
                .init(icon: "trash", color: .red) {
                    print("删除")
                }
            ]
        )
    }
    .listStyle(.plain)
}
#endif
