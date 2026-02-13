# Phase 2 实施计划：iPhone UI 单手操作优化

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 iPhone 用户提供卓越的单手操作体验，通过设备分类、滑动操作和自适应间距优化 UI

**Architecture:** 渐进式替换策略 - 在现有 iOSAdaptiveView 基础上添加 iPhoneOptimizedView 包装器，使用 TDD 方法实现设备分类系统、可滑动列表项、快捷操作栏和自适应间距系统，保持 iPad/macOS 功能完全不变

**Tech Stack:** SwiftUI, Swift Concurrency, Swift Testing, UIKit (设备检测)

---

## Task 1: 设备分类基础 - iPhoneCategory 枚举

**Files:**
- Create: `FluxQ/iOS/Models/iPhoneCategory.swift`
- Create: `FluxQTests/iOS/iPhoneCategoryTests.swift`

**Step 1: 写失败的设备分类测试**

创建测试文件：

```swift
// FluxQTests/iOS/iPhoneCategoryTests.swift
import Testing
@testable import FluxQ

@Suite("iPhone 设备分类测试")
struct iPhoneCategoryTests {

    @Test("Compact 设备检测 - iPhone SE")
    func testCompactDevice() {
        let height: CGFloat = 650
        #expect(iPhoneCategory.from(screenHeight: height) == .compact)
    }

    @Test("Compact 边界测试 - 699")
    func testCompactBoundary() {
        let height: CGFloat = 699
        #expect(iPhoneCategory.from(screenHeight: height) == .compact)
    }

    @Test("Standard 设备检测 - iPhone 15")
    func testStandardDevice() {
        let height: CGFloat = 850
        #expect(iPhoneCategory.from(screenHeight: height) == .standard)
    }

    @Test("Standard 下边界测试 - 700")
    func testStandardLowerBoundary() {
        let height: CGFloat = 700
        #expect(iPhoneCategory.from(screenHeight: height) == .standard)
    }

    @Test("Standard 上边界测试 - 899")
    func testStandardUpperBoundary() {
        let height: CGFloat = 899
        #expect(iPhoneCategory.from(screenHeight: height) == .standard)
    }

    @Test("Large 设备检测 - iPhone Pro Max")
    func testLargeDevice() {
        let height: CGFloat = 950
        #expect(iPhoneCategory.from(screenHeight: height) == .large)
    }

    @Test("Large 边界测试 - 900")
    func testLargeBoundary() {
        let height: CGFloat = 900
        #expect(iPhoneCategory.from(screenHeight: height) == .large)
    }
}
```

**Step 2: 运行测试验证失败**

Run: `swift test --filter iPhoneCategoryTests`
Expected: 编译失败 - "Cannot find type 'iPhoneCategory' in scope"

**Step 3: 实现最小的 iPhoneCategory 枚举**

创建实现文件：

```swift
// FluxQ/iOS/Models/iPhoneCategory.swift
import Foundation

/// iPhone 设备尺寸分类
enum iPhoneCategory {
    case compact    // iPhone SE, mini (4.7-5.4寸)
    case standard   // iPhone 14/15 (6.1寸)
    case large      // Plus, Pro Max (6.7-6.9寸)

    /// 根据屏幕高度判断设备类别
    /// - Parameter screenHeight: 屏幕高度（points）
    /// - Returns: 设备类别
    static func from(screenHeight: CGFloat) -> iPhoneCategory {
        switch screenHeight {
        case ..<700:
            return .compact
        case 700..<900:
            return .standard
        default:
            return .large
        }
    }
}
```

**Step 4: 运行测试验证通过**

Run: `swift test --filter iPhoneCategoryTests`
Expected:
```
Test Suite 'iPhoneCategoryTests' passed
    ✓ testCompactDevice() passed (0.001 seconds)
    ✓ testCompactBoundary() passed (0.001 seconds)
    ✓ testStandardDevice() passed (0.001 seconds)
    ✓ testStandardLowerBoundary() passed (0.001 seconds)
    ✓ testStandardUpperBoundary() passed (0.001 seconds)
    ✓ testLargeDevice() passed (0.001 seconds)
    ✓ testLargeBoundary() passed (0.001 seconds)

7 tests passed
```

**Step 5: 提交**

```bash
git add FluxQ/iOS/Models/iPhoneCategory.swift FluxQTests/iOS/iPhoneCategoryTests.swift
git commit -m "test: add iPhoneCategory device classification

Add device classification enum with screen height detection:
- Compact: < 700pt (iPhone SE, mini)
- Standard: 700-900pt (iPhone 14/15)
- Large: >= 900pt (Plus, Pro Max)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: 自适应间距系统 - AdaptiveSpacing

**Files:**
- Create: `FluxQ/iOS/Components/AdaptiveSpacing.swift`
- Create: `FluxQTests/iOS/AdaptiveSpacingTests.swift`

**Step 1: 写失败的间距系统测试**

创建测试文件：

```swift
// FluxQTests/iOS/AdaptiveSpacingTests.swift
import Testing
@testable import FluxQ

@Suite("自适应间距系统测试")
struct AdaptiveSpacingTests {

    @Test("列表项高度 - Compact")
    func testListItemHeightCompact() {
        #expect(AdaptiveSpacing.listItemHeight(for: .compact) == 60)
    }

    @Test("列表项高度 - Standard")
    func testListItemHeightStandard() {
        #expect(AdaptiveSpacing.listItemHeight(for: .standard) == 70)
    }

    @Test("列表项高度 - Large")
    func testListItemHeightLarge() {
        #expect(AdaptiveSpacing.listItemHeight(for: .large) == 80)
    }

    @Test("区域间距 - Compact")
    func testSectionSpacingCompact() {
        #expect(AdaptiveSpacing.sectionSpacing(for: .compact) == 12)
    }

    @Test("区域间距 - Standard")
    func testSectionSpacingStandard() {
        #expect(AdaptiveSpacing.sectionSpacing(for: .standard) == 16)
    }

    @Test("区域间距 - Large")
    func testSectionSpacingLarge() {
        #expect(AdaptiveSpacing.sectionSpacing(for: .large) == 20)
    }

    @Test("水平内边距 - Compact")
    func testHorizontalPaddingCompact() {
        #expect(AdaptiveSpacing.horizontalPadding(for: .compact) == 12)
    }

    @Test("水平内边距 - Standard")
    func testHorizontalPaddingStandard() {
        #expect(AdaptiveSpacing.horizontalPadding(for: .standard) == 16)
    }

    @Test("水平内边距 - Large")
    func testHorizontalPaddingLarge() {
        #expect(AdaptiveSpacing.horizontalPadding(for: .large) == 20)
    }

    @Test("圆角半径 - Compact")
    func testCornerRadiusCompact() {
        #expect(AdaptiveSpacing.cornerRadius(for: .compact) == 8)
    }

    @Test("圆角半径 - Standard")
    func testCornerRadiusStandard() {
        #expect(AdaptiveSpacing.cornerRadius(for: .standard) == 10)
    }

    @Test("圆角半径 - Large")
    func testCornerRadiusLarge() {
        #expect(AdaptiveSpacing.cornerRadius(for: .large) == 12)
    }
}
```

**Step 2: 运行测试验证失败**

Run: `swift test --filter AdaptiveSpacingTests`
Expected: 编译失败 - "Cannot find type 'AdaptiveSpacing' in scope"

**Step 3: 实现 AdaptiveSpacing 结构体**

创建实现文件：

```swift
// FluxQ/iOS/Components/AdaptiveSpacing.swift
import CoreGraphics

/// 自适应间距系统 - 根据设备类别提供统一的间距标准
struct AdaptiveSpacing {

    /// 列表项高度
    /// - Parameter category: 设备类别
    /// - Returns: 列表项高度（points）
    static func listItemHeight(for category: iPhoneCategory) -> CGFloat {
        switch category {
        case .compact:
            return 60
        case .standard:
            return 70
        case .large:
            return 80
        }
    }

    /// 区域间距
    /// - Parameter category: 设备类别
    /// - Returns: 区域间距（points）
    static func sectionSpacing(for category: iPhoneCategory) -> CGFloat {
        switch category {
        case .compact:
            return 12
        case .standard:
            return 16
        case .large:
            return 20
        }
    }

    /// 水平内边距
    /// - Parameter category: 设备类别
    /// - Returns: 水平内边距（points）
    static func horizontalPadding(for category: iPhoneCategory) -> CGFloat {
        switch category {
        case .compact:
            return 12
        case .standard:
            return 16
        case .large:
            return 20
        }
    }

    /// 圆角半径
    /// - Parameter category: 设备类别
    /// - Returns: 圆角半径（points）
    static func cornerRadius(for category: iPhoneCategory) -> CGFloat {
        switch category {
        case .compact:
            return 8
        case .standard:
            return 10
        case .large:
            return 12
        }
    }
}
```

**Step 4: 运行测试验证通过**

Run: `swift test --filter AdaptiveSpacingTests`
Expected:
```
Test Suite 'AdaptiveSpacingTests' passed
    ✓ testListItemHeightCompact() passed (0.001 seconds)
    ✓ testListItemHeightStandard() passed (0.001 seconds)
    ✓ testListItemHeightLarge() passed (0.001 seconds)
    ✓ testSectionSpacingCompact() passed (0.001 seconds)
    ✓ testSectionSpacingStandard() passed (0.001 seconds)
    ✓ testSectionSpacingLarge() passed (0.001 seconds)
    ✓ testHorizontalPaddingCompact() passed (0.001 seconds)
    ✓ testHorizontalPaddingStandard() passed (0.001 seconds)
    ✓ testHorizontalPaddingLarge() passed (0.001 seconds)
    ✓ testCornerRadiusCompact() passed (0.001 seconds)
    ✓ testCornerRadiusStandard() passed (0.001 seconds)
    ✓ testCornerRadiusLarge() passed (0.001 seconds)

12 tests passed
```

**Step 5: 提交**

```bash
git add FluxQ/iOS/Components/AdaptiveSpacing.swift FluxQTests/iOS/AdaptiveSpacingTests.swift
git commit -m "feat: add adaptive spacing system

Implement device-specific spacing standards:
- List item height: 60/70/80pt
- Section spacing: 12/16/20pt
- Horizontal padding: 12/16/20pt
- Corner radius: 8/10/12pt

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: 可滑动列表项 - SwipeableListItem

**Files:**
- Create: `FluxQ/iOS/Components/SwipeableListItem.swift`

**Step 1: 创建 SwipeableListItem 组件**

创建文件：

```swift
// FluxQ/iOS/Components/SwipeableListItem.swift
import SwiftUI

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
                    DragGesture()
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
                        .onEnded { value in
                            isDragging = false

                            // 判断是否触发操作
                            if abs(offset) > actionThreshold {
                                // 触发触感反馈
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
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
```

**Step 2: 添加 Preview 测试**

在文件末尾添加 Preview：

```swift
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
```

**Step 3: 手动测试**

在 Xcode 中打开 Preview：
1. 右滑 "测试消息" → 显示蓝色"标记已读"按钮
2. 左滑 "测试消息" → 显示红色"删除"和橙色"置顶"按钮
3. 滑动超过 60pt → 触感反馈 + 保持展开
4. 滑动不足 60pt → 自动回弹

**Step 4: 提交**

```bash
git add FluxQ/iOS/Components/SwipeableListItem.swift
git commit -m "feat: add swipeable list item component

Implement swipeable list item with:
- Leading/trailing swipe actions
- 60pt threshold for action trigger
- Haptic feedback on trigger
- Auto-bounce animation
- 0.25s easeOut timing

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: 快捷操作栏 - QuickActionBar

**Files:**
- Create: `FluxQ/iOS/Components/QuickActionBar.swift`

**Step 1: 创建 QuickActionBar 组件**

创建文件：

```swift
// FluxQ/iOS/Components/QuickActionBar.swift
import SwiftUI

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
```

**Step 2: 添加 Preview 测试**

在文件末尾添加 Preview：

```swift
#Preview("Compact 设备") {
    VStack {
        Spacer()
        QuickActionBar(
            actions: [
                .init(icon: "photo", label: "相册") { print("相册") },
                .init(icon: "camera", label: "拍照") { print("拍照") },
                .init(icon: "folder", label: "文件") { print("文件") },
                .init(icon: "location", label: "位置") { print("位置") }
            ],
            category: .compact
        )
    }
    .frame(width: 375, height: 667)
}

#Preview("Standard 设备") {
    VStack {
        Spacer()
        QuickActionBar(
            actions: [
                .init(icon: "photo", label: "相册") { print("相册") },
                .init(icon: "camera", label: "拍照") { print("拍照") },
                .init(icon: "folder", label: "文件") { print("文件") },
                .init(icon: "location", label: "位置") { print("位置") }
            ],
            category: .standard
        )
    }
    .frame(width: 393, height: 852)
}

#Preview("Large 设备") {
    VStack {
        Spacer()
        QuickActionBar(
            actions: [
                .init(icon: "photo", label: "相册") { print("相册") },
                .init(icon: "camera", label: "拍照") { print("拍照") },
                .init(icon: "folder", label: "文件") { print("文件") },
                .init(icon: "location", label: "位置") { print("位置") }
            ],
            category: .large
        )
    }
    .frame(width: 430, height: 932)
}
```

**Step 3: 验证 Preview**

在 Xcode 中验证三个 Preview：
1. Compact - 仅显示图标，44×44pt 按钮
2. Standard - 图标+文字，60×50pt 按钮
3. Large - 图标+文字，60×50pt 按钮，间距更大

**Step 4: 提交**

```bash
git add FluxQ/iOS/Components/QuickActionBar.swift
git commit -m "feat: add quick action bar component

Implement bottom quick action bar with:
- Device-specific layout (compact/standard/large)
- Icon-only for compact devices (44x44pt)
- Icon+label for standard/large (60x50pt)
- Ultra-thin material background
- Adaptive spacing

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: 单手优化视图 - iPhoneOptimizedView

**Files:**
- Create: `FluxQ/iOS/iPhoneOptimizedView.swift`

**Step 1: 创建 iPhoneOptimizedView**

创建文件：

```swift
// FluxQ/iOS/iPhoneOptimizedView.swift
import SwiftUI

/// iPhone 单手优化视图 - 包装 MainTabView 并应用单手优化
struct iPhoneOptimizedView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var deviceCategory: iPhoneCategory = .standard

    /// 是否应用单手优化（仅竖屏）
    private var shouldOptimize: Bool {
        verticalSizeClass == .regular
    }

    var body: some View {
        Group {
            if shouldOptimize {
                // 竖屏 - 应用单手优化
                MainTabView()
                    .environment(\.deviceCategory, deviceCategory)
            } else {
                // 横屏 - 标准布局
                MainTabView()
            }
        }
        .onAppear {
            detectDeviceCategory()
        }
    }

    /// 检测设备类别
    private func detectDeviceCategory() {
        let screenHeight = UIScreen.main.bounds.height
        deviceCategory = iPhoneCategory.from(screenHeight: screenHeight)
    }
}
```

**Step 2: 添加 Environment Key**

在 iPhoneCategory.swift 文件末尾添加：

```swift
// FluxQ/iOS/Models/iPhoneCategory.swift

// 添加到文件末尾

/// Environment Key for device category
struct DeviceCategoryKey: EnvironmentKey {
    static let defaultValue: iPhoneCategory = .standard
}

extension EnvironmentValues {
    var deviceCategory: iPhoneCategory {
        get { self[DeviceCategoryKey.self] }
        set { self[DeviceCategoryKey.self] = newValue }
    }
}
```

**Step 3: 添加 Preview**

在 iPhoneOptimizedView.swift 末尾添加：

```swift
#Preview("iPhone SE") {
    iPhoneOptimizedView()
        .frame(width: 375, height: 667)
}

#Preview("iPhone 15") {
    iPhoneOptimizedView()
        .frame(width: 393, height: 852)
}

#Preview("iPhone 15 Pro Max") {
    iPhoneOptimizedView()
        .frame(width: 430, height: 932)
}

#Preview("横屏模式", traits: .landscapeLeft) {
    iPhoneOptimizedView()
        .frame(width: 852, height: 393)
}
```

**Step 4: 验证 Preview**

在 Xcode 中验证 Preview 正常显示

**Step 5: 提交**

```bash
git add FluxQ/iOS/iPhoneOptimizedView.swift FluxQ/iOS/Models/iPhoneCategory.swift
git commit -m "feat: add iPhone optimized view wrapper

Implement one-handed optimization wrapper:
- Device category detection on appear
- Environment injection for child views
- Portrait-only optimization (landscape uses standard layout)
- Preview support for all iPhone sizes

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: 集成到 iOSAdaptiveView

**Files:**
- Modify: `FluxQ/iOS/iOSAdaptiveView.swift`

**Step 1: 读取现有代码**

Run: `cat FluxQ/iOS/iOSAdaptiveView.swift`

Expected: 查看现有的 iOSAdaptiveView 实现

**Step 2: 修改 iOSAdaptiveView 集成新视图**

修改文件：

```swift
// FluxQ/iOS/iOSAdaptiveView.swift
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

    /// 是否应该使用多栏布局（iPad 横屏）
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
                // iPhone/iPad 竖屏 - 使用 iPhone 优化视图
                iPhoneOptimizedView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: shouldUseMultiColumn)
    }
}

#Preview("iPad 横屏", traits: .landscapeLeft) {
    iOSAdaptiveView()
}

#Preview("iPad 竖屏", traits: .portrait) {
    iOSAdaptiveView()
}

#Preview("iPhone") {
    iOSAdaptiveView()
}
```

**Step 3: 构建验证**

Run: `xcodebuild -scheme FluxQ -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build`

Expected: BUILD SUCCEEDED

**Step 4: 手动测试**

在 iOS 模拟器中测试：
1. 启动 iPhone 15 模拟器
2. 验证应用正常启动
3. 验证 Tab 切换正常
4. 验证横竖屏切换正常

**Step 5: 提交**

```bash
git add FluxQ/iOS/iOSAdaptiveView.swift
git commit -m "feat: integrate iPhoneOptimizedView into iOSAdaptiveView

Replace MainTabView with iPhoneOptimizedView for iPhone/iPad portrait:
- iPad landscape continues using iPadSplitView (no change)
- iPhone/iPad portrait now uses iPhoneOptimizedView
- Maintains existing state management and transitions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: iPad 兼容性验证

**Files:**
- Test: iPad 模拟器手动测试

**Step 1: 构建 iPad 目标**

Run: `xcodebuild -scheme FluxQ -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build`

Expected: BUILD SUCCEEDED

**Step 2: 启动 iPad 模拟器测试**

测试场景：
1. iPad 横屏 → 验证多栏布局正常
2. iPad 竖屏 → 验证 TabView 正常
3. 横竖屏切换 → 验证状态保持
4. Tab 切换 → 验证导航正常

Expected: 所有场景通过，iPad 行为与 Phase 1 完全一致

**Step 3: 记录测试结果**

创建测试报告（如果发现问题则修复）

---

## Task 8: 应用滑动操作到消息列表

**Files:**
- Modify: `FluxQ/Views/ConversationListView.swift`

**Step 1: 读取现有代码**

Run: `cat FluxQ/Views/ConversationListView.swift`

Expected: 查看现有的 ConversationListView 实现

**Step 2: 为列表项添加滑动操作**

修改文件（示例修改，实际需要根据现有代码调整）：

```swift
// FluxQ/Views/ConversationListView.swift

// 在 List 中的 ForEach 部分修改为：

ForEach(conversations) { conversation in
    SwipeableListItem(
        content: {
            ConversationRow(conversation: conversation)
        },
        leadingActions: [
            .init(icon: "checkmark.circle", color: .blue) {
                // 标记已读
                markAsRead(conversation)
            }
        ],
        trailingActions: [
            .init(icon: "trash", color: .red) {
                // 删除会话
                deleteConversation(conversation)
            },
            .init(icon: "pin.fill", color: .orange) {
                // 置顶会话
                pinConversation(conversation)
            }
        ]
    )
}
```

**Step 3: 添加操作方法（占位实现）**

在 ConversationListView 中添加：

```swift
private func markAsRead(_ conversation: Conversation) {
    // TODO: 实现标记已读逻辑
    print("标记已读: \(conversation.id)")
}

private func deleteConversation(_ conversation: Conversation) {
    // TODO: 实现删除逻辑
    print("删除会话: \(conversation.id)")
}

private func pinConversation(_ conversation: Conversation) {
    // TODO: 实现置顶逻辑
    print("置顶会话: \(conversation.id)")
}
```

**Step 4: 构建验证**

Run: `xcodebuild -scheme FluxQ -sdk iphonesimulator build`

Expected: BUILD SUCCEEDED

**Step 5: 手动测试滑动操作**

在 iOS 模拟器中测试：
1. 右滑消息 → 显示"标记已读"按钮
2. 左滑消息 → 显示"删除"和"置顶"按钮
3. 点击按钮 → 打印日志正常
4. 触感反馈 → 模拟器显示触感标识

**Step 6: 提交**

```bash
git add FluxQ/Views/ConversationListView.swift
git commit -m "feat: add swipe actions to conversation list

Implement swipeable conversation items with:
- Right swipe: mark as read (blue)
- Left swipe: delete (red) and pin (orange)
- Placeholder action handlers (TODO: implement logic)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: 应用快捷操作栏到消息详情

**Files:**
- Modify: `FluxQ/Views/ConversationDetailView.swift`

**Step 1: 读取现有代码**

Run: `cat FluxQ/Views/ConversationDetailView.swift`

Expected: 查看现有的 ConversationDetailView 实现

**Step 2: 添加快捷操作栏**

修改文件（示例修改，实际需要根据现有代码调整）：

```swift
// FluxQ/Views/ConversationDetailView.swift

// 在视图底部添加 QuickActionBar

var body: some View {
    VStack(spacing: 0) {
        // 现有的消息列表和输入框
        // ...

        // 底部快捷操作栏
        if let category = environment.deviceCategory {
            QuickActionBar(
                actions: [
                    .init(icon: "photo", label: "相册") {
                        selectPhoto()
                    },
                    .init(icon: "camera", label: "拍照") {
                        takePhoto()
                    },
                    .init(icon: "folder", label: "文件") {
                        selectFile()
                    },
                    .init(icon: "location", label: "位置") {
                        shareLocation()
                    }
                ],
                category: category
            )
        }
    }
}
```

**Step 3: 从 Environment 读取设备类别**

在 ConversationDetailView 顶部添加：

```swift
@Environment(\.deviceCategory) private var deviceCategory
```

**Step 4: 添加操作方法（占位实现）**

在 ConversationDetailView 中添加：

```swift
private func selectPhoto() {
    // TODO: 实现选择相册逻辑
    print("选择相册")
}

private func takePhoto() {
    // TODO: 实现拍照逻辑
    print("拍照")
}

private func selectFile() {
    // TODO: 实现选择文件逻辑
    print("选择文件")
}

private func shareLocation() {
    // TODO: 实现分享位置逻辑
    print("分享位置")
}
```

**Step 5: 构建验证**

Run: `xcodebuild -scheme FluxQ -sdk iphonesimulator build`

Expected: BUILD SUCCEEDED

**Step 6: 手动测试快捷操作栏**

在 iOS 模拟器中测试：
1. iPhone SE → 仅显示图标
2. iPhone 15 → 显示图标+文字
3. 点击按钮 → 打印日志正常
4. 底部安全区域 → 正确适配

**Step 7: 提交**

```bash
git add FluxQ/Views/ConversationDetailView.swift
git commit -m "feat: add quick action bar to conversation detail

Implement bottom quick action bar with:
- Photo, camera, file, location actions
- Device-specific layout (icon-only vs icon+label)
- Placeholder action handlers (TODO: implement logic)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 10: 运行所有测试

**Step 1: 运行模块测试**

Run: `swift test`

Expected: 所有现有测试通过 + 新增测试通过

**Step 2: 运行 FluxQ 测试**

Run: `xcodebuild test -scheme FluxQ -destination 'platform=iOS Simulator,name=iPhone 15'`

Expected: Test Succeeded

**Step 3: 记录测试结果**

如果有测试失败，修复后重新测试

---

## Task 11: 性能验证

**Step 1: 使用 Instruments 测试滚动性能**

1. 在 Xcode 中选择 Product > Profile
2. 选择 "Time Profiler" 模板
3. 启动应用并滚动消息列表
4. 记录 CPU 使用率和帧率

Expected:
- 滚动帧率 ≥ 60 FPS
- CPU 使用率 < 30%

**Step 2: 测试内存占用**

1. 使用 "Allocations" 模板
2. 启动应用并浏览各个页面
3. 记录内存增长

Expected:
- 内存增长 < 5MB

**Step 3: 记录性能指标**

创建性能报告（如果发现性能问题则优化）

---

## Task 12: 创建 Phase 2 完成报告

**Files:**
- Create: `docs/plans/2026-02-14-phase2-completion-report.md`

**Step 1: 收集统计数据**

Run:
```bash
git log --oneline --since="今天" --author="Claude"
git diff --stat main..HEAD
```

**Step 2: 编写完成报告**

创建报告文件，包含：
- 完成的功能列表
- 提交统计
- 测试结果
- 性能指标
- 下一步计划（Phase 3 或后续优化）

**Step 3: 提交报告**

```bash
git add docs/plans/2026-02-14-phase2-completion-report.md
git commit -m "docs: add Phase 2 completion report

Complete report for iPhone UI optimization:
- Device classification and adaptive spacing
- Swipeable list items with actions
- Quick action bar for detail views
- Performance and compatibility validation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## 总结

Phase 2 实施计划包含 12 个任务：

1. ✅ iPhoneCategory 枚举和测试
2. ✅ AdaptiveSpacing 系统和测试
3. ✅ SwipeableListItem 组件
4. ✅ QuickActionBar 组件
5. ✅ iPhoneOptimizedView 包装器
6. ✅ 集成到 iOSAdaptiveView
7. ✅ iPad 兼容性验证
8. ✅ 应用滑动操作到消息列表
9. ✅ 应用快捷操作栏到消息详情
10. ✅ 运行所有测试
11. ✅ 性能验证
12. ✅ 创建完成报告

**预估总时间**：5-8 小时

**关键原则**：
- TDD - 先写测试，后写实现
- DRY - 复用 AdaptiveSpacing 系统
- YAGNI - 只实现必需功能
- 频繁提交 - 每个任务提交一次

---

**实施计划编写日期**：2026-02-14
**计划编写者**：Claude Sonnet 4.5（使用 superpowers:writing-plans skill）
**下一步**：使用 superpowers:executing-plans 或 superpowers:subagent-driven-development 执行计划
