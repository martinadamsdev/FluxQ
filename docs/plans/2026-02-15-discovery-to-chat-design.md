# 发现页点击用户发起聊天 — 设计文档

日期：2026-02-15

## 问题

DiscoveryView 中发现的局域网用户点击后无任何响应，缺失从发现用户到发起聊天的完整链路。

## 设计目标

点击发现的用户 → 创建/查找会话 → 切换到消息 tab → 进入聊天界面。三平台体验一致。

## 架构方案：ConversationService + StartChatAction

采用集中式协调层 `ConversationService` 处理会话查找/创建，`StartChatAction` Environment Action 桥接跨 tab 导航。

### 数据流

```
DiscoveryView
  ├─ @Environment(\.modelContext)
  ├─ @Environment(\.startChat)
  └─ tap user
       → ConversationService.findOrCreateConversation(with:in:)
           ├─ 匹配/创建 User（SwiftData）
           ├─ 查找/创建 Conversation（SwiftData）
           └─ return conversationId
       → startChat(conversationId)
           ├─ iPhone: selectedTab = .messages + navigationPath push
           └─ macOS/iPad: selectedTab = .messages + selectedConversation = id
```

## 新增文件

### 1. `FluxQ/Services/ConversationService.swift`

职责：会话查找/创建逻辑。

```swift
struct ConversationService {
    static func findOrCreateConversation(
        with discoveredUser: DiscoveredUser,
        in context: ModelContext
    ) -> UUID
}
```

逻辑：
1. 按 hostname + senderName 在 SwiftData 中匹配已有 User，没有则通过 `discoveredUser.toUser()` 持久化
2. 查找与该 User 的已有 1:1 Conversation（type == .private，participantIDs 包含该用户）
3. 如果存在，更新 `lastMessageTimestamp` 确保排序置顶，返回其 UUID
4. 如果不存在，创建新 Conversation，返回其 UUID

### 2. `FluxQ/Navigation/StartChatAction.swift`

职责：跨 tab 导航的 Environment Action。

```swift
struct StartChatAction {
    let handler: (UUID) -> Void
    func callAsFunction(_ conversationId: UUID) { handler(conversationId) }
}

struct StartChatActionKey: EnvironmentKey {
    static let defaultValue = StartChatAction { _ in }
}

extension EnvironmentValues {
    var startChat: StartChatAction {
        get { self[StartChatActionKey.self] }
        set { self[StartChatActionKey.self] = newValue }
    }
}
```

## 修改文件

### 3. `FluxQ/Views/DiscoveryView.swift`

- 列表行改为 Button，点击时调用 ConversationService + StartChatAction
- 添加 `@Environment(\.startChat)` 和 `@Environment(\.modelContext)`

```swift
List(filteredUsers) { user in
    Button {
        let id = ConversationService.findOrCreateConversation(with: user, in: modelContext)
        startChat(id)
    } label: {
        // 现有 HStack 行内容不变
    }
}
```

注意：filteredUsers 当前是 `[User]`（由 `discoveredUser.toUser()` 转换），但 ConversationService 需要原始 `DiscoveredUser`。需要调整为传递 DiscoveredUser 或在 ConversationService 中接受 User 参数。

### 4. `FluxQ/iOS/MainTabView.swift`

- 添加 `@State private var selectedTab: AppNavigationItem = .messages`
- 添加 `@State private var activeConversationId: UUID?`
- 改为 `TabView(selection: $selectedTab)`
- 每个 tab 加 `.tag(AppNavigationItem.xxx)`
- 将 `activeConversationId` 传给 `ConversationListView`
- 注入 `StartChatAction`

```swift
@State private var selectedTab: AppNavigationItem = .messages
@State private var activeConversationId: UUID?

TabView(selection: $selectedTab) {
    ConversationListView(activeConversationId: $activeConversationId)
        .tabItem { Label("消息", systemImage: "message.fill") }
        .tag(AppNavigationItem.messages)

    ContactsView()
        .tabItem { Label("通讯录", systemImage: "person.2.fill") }
        .tag(AppNavigationItem.contacts)

    DiscoveryView()
        .tabItem { Label("发现", systemImage: "globe") }
        .tag(AppNavigationItem.discovery)

    SettingsView()
        .tabItem { Label("我", systemImage: "person.fill") }
        .tag(AppNavigationItem.settings)
}
.environment(\.startChat, StartChatAction { conversationId in
    activeConversationId = conversationId
    selectedTab = .messages
})
```

### 5. `FluxQ/Views/ConversationListView.swift`

- 添加可选的 `activeConversationId` binding 参数（iPhone 使用）
- 使用 `NavigationStack(path:)` 支持程序化导航
- 响应 `activeConversationId` 变化自动 push

```swift
@Binding var activeConversationId: UUID?
@State private var navigationPath = NavigationPath()

NavigationStack(path: $navigationPath) {
    List { ... }
    .navigationDestination(for: UUID.self) { id in
        ConversationDetailView(conversationId: id)
    }
}
.onChange(of: activeConversationId) { _, newValue in
    if let id = newValue {
        navigationPath.append(id)
        activeConversationId = nil
    }
}
```

需保持与 macOS/iPad 的 `selection: Binding<UUID?>` 参数兼容（两种 init）。

### 6. `FluxQ/macOS/MacMainView.swift`

- 注入 `StartChatAction`

```swift
.environment(\.startChat, StartChatAction { conversationId in
    selectedTab = .messages
    selectedConversation = conversationId
})
```

### 7. `FluxQ/iOS/iOSAdaptiveView.swift`

- iPad 横屏路径注入 `StartChatAction`（同 macOS 逻辑）

## 三平台行为

| 平台 | 点击发现用户 | 导航方式 |
|------|-------------|---------|
| iPhone | 创建会话 → 切 tab → NavigationStack push 进聊天 | StartChatAction 设 selectedTab + activeConversationId |
| iPad 横屏 | 创建会话 → 切 tab → detail 栏显示聊天 | StartChatAction 设 selectedTab + selectedConversation |
| macOS | 创建会话 → 切 tab → detail 栏显示聊天 | StartChatAction 设 selectedTab + selectedConversation |

## 模块依赖

- `ConversationService` 位于应用层（`FluxQ/Services/`），依赖 SwiftData + FluxQModels + FluxQServices
- `StartChatAction` 位于应用层（`FluxQ/Navigation/`），纯 SwiftUI，无外部依赖
- 不修改 FluxQServices 模块（保持只依赖 IPMsgProtocol 的规则）

## 复用性

ConversationService 和 StartChatAction 可被通讯录页面、消息转发等场景复用。
