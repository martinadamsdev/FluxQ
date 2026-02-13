# FluxQ 多平台 UI 适配设计

**日期**: 2026-02-14
**状态**: 已批准
**版本**: 1.0

## 概述

### 目标

为 FluxQ 的所有目标平台（macOS、iPad、iPhone、watchOS）设计并实现最佳的原生用户体验，使每个平台都遵循其独特的设计习惯和交互模式。

### 背景

当前 FluxQ 使用统一的 `TabView` 作为所有平台的导航方式。这在 iOS 上表现良好（底部标签栏），但在 macOS 上显示为顶部水平标签，不符合 macOS 应用的设计习惯。iPad 和 watchOS 也未得到针对性优化。

### 核心原则

1. **平台优先**：每个平台都应使用其原生的导航和布局模式
2. **自适应设计**：iPad 根据横竖屏动态切换布局，iPhone 根据屏幕尺寸优化显示
3. **代码复用**：最大化业务逻辑和 UI 组件的跨平台复用
4. **渐进增强**：分阶段实施，每个阶段都可以独立交付和验证

---

## 平台设计决策

### macOS

**导航模式**: 侧边栏导航
**布局**: NavigationSplitView 三栏布局

- **第一栏**: 导航侧边栏（消息、通讯录、发现、我）
- **第二栏**: 内容列表（对话列表、联系人列表等）
- **第三栏**: 详情（对话详情、联系人详情、设置内容等）

**设计理由**: 这是 macOS 应用的标准布局，符合 Finder、Mail、Messages 等系统应用的设计语言。三栏布局充分利用宽屏空间，提供更高效的信息密度。

### iPad

**导航模式**: 自适应布局

- **横屏（Regular Horizontal Size Class）**: 类似 macOS 的多栏布局
- **竖屏（Compact Horizontal Size Class）**: 类似 iPhone 的底部标签栏

**设计理由**: iPad 的独特之处在于其横竖屏的显著差异。横屏时更接近桌面体验，竖屏时更接近手机体验。自适应布局充分发挥 iPad 的灵活性。

### iPhone

**导航模式**: 底部标签栏（保持不变）
**优化重点**: 针对不同屏幕尺寸优化

- **紧凑设备（SE, mini, ≤375pt）**: 减小间距、字体和控件尺寸
- **标准设备（375-390pt）**: 使用默认尺寸
- **大屏设备（Plus, Pro Max, >390pt）**: 显示更多信息，优化横屏体验

**设计理由**: 底部标签栏已经是 iOS 的标准导航模式。优化的重点是确保在极小和极大屏幕上都有良好体验。

### watchOS

**导航模式**: 列表式导航（NavigationStack）
**核心功能**:

- 查看消息列表（最近 10 条对话）
- 快速回复（预设回复、语音、涂鸦）
- 在线状态切换
- 新消息通知

**设计理由**: watchOS 屏幕极小，必须聚焦核心功能。列表式导航是 watchOS 的标准模式，快速回复和通知是手表的核心价值。

---

## 架构设计

### 整体视图层次

```
FluxQ/
├── ContentView.swift
│   └── AdaptiveRootView()
│
├── AdaptiveRootView.swift (新建)
│   ├── #if os(macOS) → MacMainView()
│   ├── #elseif os(iOS) → iOSAdaptiveView()
│   └── #elseif os(watchOS) → WatchMainView()
│
├── macOS/
│   ├── MacMainView.swift (新建)
│   └── MacSidebarView.swift (新建)
│
├── iOS/
│   ├── iOSAdaptiveView.swift (新建)
│   ├── iPadSplitView.swift (新建)
│   └── MainTabView.swift (现有)
│
├── watchOS/
│   ├── WatchMainView.swift (新建)
│   ├── WatchConversationListView.swift (新建)
│   └── WatchQuickReplyView.swift (新建)
│
└── Shared/
    ├── Views/
    │   ├── ConversationListView.swift (改造)
    │   ├── ConversationDetailView.swift (新建)
    │   ├── ContactsListView.swift (提取自 ContactsView)
    │   ├── ContactDetailView.swift (新建)
    │   ├── DiscoveryView.swift (现有)
    │   └── SettingsView.swift (现有)
    └── Components/
        ├── ConversationRow.swift
        ├── ContactRow.swift
        ├── MessageBubble.swift
        └── UserAvatar.swift
```

### 平台隔离策略

#### 编译时隔离
使用 `#if os()` 编译条件在不同平台之间完全分离代码：

```swift
struct AdaptiveRootView: View {
    var body: some View {
        #if os(macOS)
            MacMainView()
        #elseif os(iOS)
            iOSAdaptiveView()
        #elseif os(watchOS)
            WatchMainView()
        #endif
    }
}
```

**优点**: 零运行时开销，代码清晰，易于维护

#### 运行时自适应
使用 SwiftUI 环境变量进行运行时判断（主要用于 iPad）：

```swift
struct iOSAdaptiveView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.userInterfaceIdiom) private var idiom

    var body: some View {
        if idiom == .pad && horizontalSizeClass == .regular {
            iPadSplitView()  // iPad 横屏
        } else {
            MainTabView()    // iPad 竖屏或 iPhone
        }
    }
}
```

**优点**: 动态响应设备变化（如旋转），无缝切换布局

---

## 组件设计

### macOS 专用组件

#### MacMainView
- **职责**: macOS 主视图，实现三栏布局
- **实现**: 使用 `NavigationSplitView`
- **状态管理**:
  ```swift
  @State private var selectedTab: NavigationItem = .messages
  @State private var selectedConversation: Conversation?
  @State private var selectedContact: Contact?
  ```

#### MacSidebarView
- **职责**: 侧边栏导航
- **样式**: List + Label，符合 macOS 设计语言
- **特性**: 支持键盘快捷键（Cmd+1/2/3/4）

### iOS/iPadOS 专用组件

#### iOSAdaptiveView
- **职责**: iOS/iPadOS 自适应容器
- **判断逻辑**: 基于 `horizontalSizeClass` 和 `userInterfaceIdiom`

#### iPadSplitView
- **职责**: iPad 横屏多栏布局
- **特性**: 可折叠侧边栏，支持手势，适配分屏模式

#### 设备尺寸适配
```swift
enum DeviceSize {
    case compact   // iPhone SE, mini (≤375pt)
    case standard  // iPhone 标准版 (375-390pt)
    case large     // iPhone Plus, Pro Max (>390pt)
}
```

### watchOS 专用组件

#### WatchMainView
- **布局**: NavigationStack + List
- **导航项**: 消息、状态

#### WatchConversationListView
- **限制**: 仅显示最近 10 条对话
- **优化**: 极简设计，适配小屏

#### WatchQuickReplyView
- **选项**: 预设回复、语音输入、涂鸦

### 跨平台共享组件

#### ConversationListView（改造）
```swift
struct ConversationListView: View {
    @Binding var selection: Conversation?  // macOS/iPad 需要
    var isCompact: Bool = false            // iPhone 小屏优化
}
```

#### ConversationDetailView（新建）
- 对话详情视图
- 跨平台复用，通过 `#if os()` 调整输入框样式

#### ContactsListView（提取）
- 从现有 `ContactsView` 提取列表部分
- 支持选中状态和搜索

#### ContactDetailView（新建）
- 联系人详情
- 显示头像、昵称、部门、状态、操作按钮

### 组件复用策略

```
Level 1 - 完全共享: MessageBubble, UserAvatar, StatusIndicator
Level 2 - 有条件共享: ConversationListView, ContactsListView (通过参数适配)
Level 3 - 平台特定: MacSidebarView, WatchQuickReplyView
```

---

## 自适应逻辑详解

### iPad 横竖屏切换

#### 核心机制
```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

private var shouldUseMultiColumn: Bool {
    idiom == .pad && horizontalSizeClass == .regular
}
```

#### 状态同步
- **选中的 Tab**: 通过 `@Binding` 在多栏和标签栏之间共享
- **选中的对话/联系人**: 横屏时保留，竖屏时仅保留 Tab
- **滚动位置**: 使用 `ScrollViewReader` 保持

#### 过渡动画
```swift
.animation(.easeInOut(duration: 0.3), value: shouldUseMultiColumn)
.transition(.asymmetric(
    insertion: .move(edge: .trailing).combined(with: .opacity),
    removal: .move(edge: .leading).combined(with: .opacity)
))
```

### iPhone 尺寸适配

#### 紧凑布局（SE, mini）
- 消息行高度: 56pt → 48pt
- 头像尺寸: 48pt → 40pt
- 字体: .body → .callout
- 内边距: 16pt → 12pt

#### 大屏优化（Plus, Pro Max）
- 增加消息预览长度
- 调整字体和间距
- （可选）横屏双栏布局

### 边界情况

#### iPad 分屏模式
- Split View 或 Slide Over 时，`horizontalSizeClass` 变为 `.compact`
- 自动降级为标签栏布局

#### 动态字体
```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

private var useCompactLayout: Bool {
    dynamicTypeSize >= .accessibility1
}
```

### 性能优化

#### 避免频繁重建
```swift
// 使用 Group 包装，减少重建
Group {
    if horizontalSizeClass == .regular {
        iPadSplitView()
    } else {
        MainTabView()
    }
}
.id(horizontalSizeClass)  // 仅在真正需要时重建
```

#### 延迟加载
- 对话详情按需加载
- 使用 LazyVStack/LazyHStack
- 长列表使用 LazyVGrid

---

## 分阶段实施计划

### 阶段 1: macOS + iPad 适配

**目标**: 实现 macOS 侧边栏三栏布局，以及 iPad 自适应布局

**主要任务**:
1. 创建 `AdaptiveRootView` 和基础架构
2. 实现 macOS 的 `MacMainView` 和 `MacSidebarView`
3. 提取和创建共享组件（列表、详情视图）
4. 实现 iPad 的 `iOSAdaptiveView` 和 `iPadSplitView`
5. 测试横竖屏切换和状态保持

**交付物**:
- macOS 应用使用侧边栏 + 三栏布局
- iPad 横屏使用多栏，竖屏使用标签栏
- 所有现有功能正常工作

**预估时间**: 4-6 天

---

### 阶段 2: iPhone 尺寸优化

**目标**: 针对 iPhone 不同屏幕尺寸优化布局

**主要任务**:
1. 创建 `DeviceSize` 检测逻辑
2. 实现紧凑布局（SE, mini）
3. 实现大屏优化（Plus, Pro Max）
4. 支持动态字体和无障碍功能
5. 测试各种 iPhone 尺寸

**交付物**:
- iPhone 各尺寸都有最佳体验
- 支持动态字体
- 性能流畅

**预估时间**: 3-4 天

---

### 阶段 3: watchOS 完整功能

**目标**: 实现 watchOS 核心功能

**主要任务**:
1. 创建 `WatchMainView` 列表式导航
2. 实现消息列表和详情
3. 实现快速回复（预设、语音、涂鸦）
4. 实现状态管理
5. 配置通知和 Complications
6. 优化电池消耗

**交付物**:
- watchOS 应用具备完整核心功能
- 通知及时可靠
- 与 iPhone/iPad 数据同步

**预估时间**: 6-7 天

---

### 总时间估算

| 阶段 | 内容 | 时间 | 累计 |
|------|------|------|------|
| 阶段 1 | macOS + iPad | 4-6 天 | 4-6 天 |
| 阶段 2 | iPhone 优化 | 3-4 天 | 7-10 天 |
| 阶段 3 | watchOS 功能 | 6-7 天 | 13-17 天 |

---

## 技术考虑

### SwiftUI 特性使用

- **NavigationSplitView**: macOS 和 iPad 横屏的核心组件
- **Environment Values**: `horizontalSizeClass`, `userInterfaceIdiom`, `dynamicTypeSize`
- **Binding**: 跨视图状态同步
- **Animation**: 平滑的布局切换

### 状态管理

- 使用 `@State` 管理本地 UI 状态
- 使用 `@Binding` 在父子视图间传递状态
- 使用 `@Environment` 读取系统环境
- （后续）可能需要引入 ObservableObject 管理全局状态

### 测试策略

- **单元测试**: 测试设备检测逻辑、状态管理
- **UI 测试**: 测试各平台的导航和交互
- **真机测试**: 在各种设备上测试实际体验
- **性能测试**: 监控内存、CPU、电池消耗

---

## 风险和缓解

### 风险 1: 代码重复

**缓解**: 通过三层复用策略（完全共享、条件共享、平台特定）最小化重复

### 风险 2: 状态同步复杂性

**缓解**: 使用 SwiftUI 的 `@Binding` 和单向数据流，保持状态管理简单

### 风险 3: 测试覆盖不足

**缓解**: 每个阶段都进行充分的真机测试，重点测试边界情况

### 风险 4: 性能问题

**缓解**: 使用 Lazy 容器、按需加载、避免频繁重建视图

---

## 成功标准

### 用户体验

- [ ] macOS 用户感觉这是一个"原生"的 macOS 应用
- [ ] iPad 用户在横竖屏间切换流畅自然
- [ ] iPhone 用户在各种尺寸设备上都有良好体验
- [ ] watchOS 用户可以快速查看和回复消息

### 技术指标

- [ ] 代码复用率 > 60%（共享组件和业务逻辑）
- [ ] 各平台启动时间 < 1 秒
- [ ] 布局切换动画流畅（60 FPS）
- [ ] 内存占用合理（iOS < 100MB, macOS < 150MB, watchOS < 30MB）

### 可维护性

- [ ] 平台代码清晰隔离，易于独立修改
- [ ] 新增功能可以轻松适配所有平台
- [ ] 代码结构清晰，新成员可以快速上手

---

## 总结

本设计方案通过**自适应视图容器 + 编译条件**的架构，为 FluxQ 的所有目标平台提供最佳的原生体验。通过分三个阶段逐步实施，既保证了每个阶段都可以独立交付和验证，又最大化了代码复用和可维护性。

关键创新点：
1. **智能自适应**: iPad 根据横竖屏自动切换布局模式
2. **平台优先**: 每个平台都使用其原生的设计语言和交互模式
3. **渐进增强**: 分阶段实施，降低风险，快速交付价值
4. **高度复用**: 三层复用策略，平衡了复用性和平台特异性

预期在 13-17 天内完成全平台适配，显著提升用户体验和应用质量。
