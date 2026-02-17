# 消息通知与提示音 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** MacBook Pro 收到来自局域网其他设备的消息时，播放提示音并显示本地通知。支持系统/自定义音效切换，3 秒节流防打扰。

**Architecture:**
新增 3 个服务类放在 `FluxQ/Services/` 目录：
- `ActiveConversationTracker` — 跟踪当前正在查看的对话 ID，用于判断是否需要提示
- `SoundManager` — 平台特定的声音播放 + 3 秒节流
- `NotificationService` — UNUserNotificationCenter 封装，权限请求 + 本地通知发送

通知偏好通过 `@AppStorage` 持久化。在 `FluxQApp.swift` 的 `.onChange(of: receivedMessages.count)` 中协调调用。

**Tech Stack:** UserNotifications, NSSound (macOS), @AppStorage, Swift Testing

---

### Task 1: ActiveConversationTracker — 跟踪当前对话

追踪用户当前正在查看的对话 ID。如果用户正在该对话中，则不播放提示音。

**Files:**
- Create: `FluxQ/Services/ActiveConversationTracker.swift`
- Modify: `FluxQ/FluxQApp.swift` (注入环境对象)
- Modify: `FluxQ/Views/ConversationDetailView.swift` (更新 tracker)

**Step 1: 创建 ActiveConversationTracker**

创建文件 `FluxQ/Services/ActiveConversationTracker.swift`：

```swift
import Foundation

@MainActor
final class ActiveConversationTracker: ObservableObject {
    @Published var activeConversationId: UUID?
}
```

**Step 2: 在 FluxQApp 中注入**

修改 `FluxQ/FluxQApp.swift`：

在属性区域添加：
```swift
@StateObject private var conversationTracker = ActiveConversationTracker()
```

在 `ContentView()` 后链式添加：
```swift
.environmentObject(conversationTracker)
```

完整的 body 中 ContentView 部分应该是：
```swift
ContentView()
    .themedColorScheme(themeManager)
    .environmentObject(networkManager)
    .environmentObject(heartbeatService)
    .environmentObject(conversationTracker)  // <-- 新增
    // ... 其余 .onAppear 和 .onChange 保持不变
```

**Step 3: 在 ConversationDetailView 中更新 tracker**

修改 `FluxQ/Views/ConversationDetailView.swift`：

添加属性：
```swift
@EnvironmentObject private var conversationTracker: ActiveConversationTracker
```

在 `conversationContent(conversationId:)` 方法返回的 VStack 后追加修饰符：
```swift
.onAppear {
    conversationTracker.activeConversationId = conversationId
}
.onDisappear {
    if conversationTracker.activeConversationId == conversationId {
        conversationTracker.activeConversationId = nil
    }
}
```

具体位置：在 `.sheet(item: $forwardingMessage)` 之后添加。

**Step 4: 构建验证**

Run: `cd /Users/martinadamsdev/workspace/FluxQ && xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add FluxQ/Services/ActiveConversationTracker.swift FluxQ/FluxQApp.swift FluxQ/Views/ConversationDetailView.swift
git commit -m "feat: add ActiveConversationTracker for tracking viewed conversation"
```

---

### Task 2: SoundManager — 声音播放与节流

负责播放提示音，内含 3 秒节流逻辑。macOS 使用 NSSound，iOS 使用 AudioToolbox。

**Files:**
- Create: `FluxQ/Services/SoundManager.swift`
- Test: `Modules/FluxQServices/Tests/FluxQServicesTests/SoundThrottleTests.swift`

**Step 1: 写节流逻辑的失败测试**

创建 `Modules/FluxQServices/Tests/FluxQServicesTests/SoundThrottleTests.swift`：

```swift
import Testing
@testable import FluxQServices

@Suite("SoundThrottle Tests")
struct SoundThrottleTests {

    @Test("首次调用应该允许播放")
    func firstCallShouldAllow() {
        var throttle = SoundThrottle(interval: 3.0)
        #expect(throttle.shouldAllow())
    }

    @Test("间隔内第二次调用应该被阻止")
    func secondCallWithinIntervalShouldBlock() {
        var throttle = SoundThrottle(interval: 3.0)
        _ = throttle.shouldAllow() // 第一次
        #expect(!throttle.shouldAllow()) // 第二次立即调用
    }

    @Test("超过间隔后应该允许")
    func callAfterIntervalShouldAllow() {
        var throttle = SoundThrottle(interval: 3.0)
        _ = throttle.shouldAllow()
        // 模拟 4 秒后
        throttle.lastAllowedAt = Date().addingTimeInterval(-4.0)
        #expect(throttle.shouldAllow())
    }
}
```

**Step 2: 运行测试确认失败**

Run: `swift test --package-path Modules/FluxQServices --filter SoundThrottleTests 2>&1 | tail -10`
Expected: FAIL — SoundThrottle 未定义

**Step 3: 在 FluxQServices 中实现 SoundThrottle**

在 `Modules/FluxQServices/Sources/FluxQServices/SoundThrottle.swift` 创建：

```swift
import Foundation

/// 声音播放节流器 — 在指定间隔内只允许触发一次
public struct SoundThrottle: Sendable {
    public let interval: TimeInterval
    public var lastAllowedAt: Date?

    public init(interval: TimeInterval = 3.0) {
        self.interval = interval
    }

    /// 判断当前是否应该播放，若允许则同时记录时间戳
    public mutating func shouldAllow() -> Bool {
        let now = Date()
        guard let last = lastAllowedAt else {
            lastAllowedAt = now
            return true
        }
        if now.timeIntervalSince(last) >= interval {
            lastAllowedAt = now
            return true
        }
        return false
    }
}
```

**Step 4: 运行测试确认通过**

Run: `swift test --package-path Modules/FluxQServices --filter SoundThrottleTests 2>&1 | tail -10`
Expected: 3 tests PASSED

**Step 5: 创建 SoundManager（App 层）**

创建 `FluxQ/Services/SoundManager.swift`：

```swift
import Foundation
import FluxQServices

#if os(macOS)
import AppKit
#elseif os(iOS)
import AudioToolbox
#endif

@MainActor
final class SoundManager: ObservableObject {

    static let shared = SoundManager()

    /// 可选的系统声音名称列表（macOS）
    static let availableSystemSounds: [String] = [
        "Glass", "Ping", "Pop", "Purr", "Tink",
        "Blow", "Bottle", "Frog", "Funk", "Hero",
        "Morse", "Sosumi", "Submarine", "Basso"
    ]

    private var throttle: SoundThrottle

    private init(throttleInterval: TimeInterval = 3.0) {
        self.throttle = SoundThrottle(interval: throttleInterval)
    }

    /// 播放提示音（带节流）
    /// - Parameters:
    ///   - soundName: 系统声音名，如 "Glass"、"Ping"
    ///   - force: 为 true 时忽略节流
    func play(soundName: String = "Glass", force: Bool = false) {
        guard force || throttle.shouldAllow() else { return }

        #if os(macOS)
        NSSound(named: NSSound.Name(soundName))?.play()
        #elseif os(iOS)
        AudioServicesPlaySystemSound(1007)
        #endif
    }
}
```

**Step 6: 构建验证**

Run: `cd /Users/martinadamsdev/workspace/FluxQ && xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add Modules/FluxQServices/Sources/FluxQServices/SoundThrottle.swift \
       Modules/FluxQServices/Tests/FluxQServicesTests/SoundThrottleTests.swift \
       FluxQ/Services/SoundManager.swift
git commit -m "feat: add SoundManager with 3s throttle for message notification sound"
```

---

### Task 3: NotificationService — 本地通知

封装 UNUserNotificationCenter，负责请求权限和发送本地通知。

**Files:**
- Create: `FluxQ/Services/NotificationService.swift`
- Modify: `FluxQ/FluxQApp.swift` (启动时请求通知权限)

**Step 1: 创建 NotificationService**

创建 `FluxQ/Services/NotificationService.swift`：

```swift
import Foundation
import UserNotifications

@MainActor
final class NotificationService {

    static let shared = NotificationService()

    private init() {}

    /// 请求通知权限
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error {
                print("NotificationService: 权限请求失败 - \(error)")
            }
        }
    }

    /// 发送本地通知
    /// - Parameters:
    ///   - title: 通知标题（发送者名称）
    ///   - body: 通知正文（消息内容预览）
    ///   - conversationId: 关联的对话 ID（用于点击跳转）
    ///   - soundName: 通知音效名称
    func sendNotification(
        title: String,
        body: String,
        conversationId: UUID,
        soundName: String = "Glass"
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["conversationId": conversationId.uuidString]

        // 立即触发
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("NotificationService: 发送通知失败 - \(error)")
            }
        }
    }
}
```

**Step 2: 在 FluxQApp 启动时请求权限**

修改 `FluxQ/FluxQApp.swift`，在 `startNetworkServices()` 方法末尾添加：

```swift
NotificationService.shared.requestPermission()
```

**Step 3: 构建验证**

Run: `cd /Users/martinadamsdev/workspace/FluxQ && xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add FluxQ/Services/NotificationService.swift FluxQ/FluxQApp.swift
git commit -m "feat: add NotificationService for local push notifications"
```

---

### Task 4: 通知设置 UI — SettingsView

在设置页面添加通知偏好管理：提示音开关、音效类型选择。

**Files:**
- Modify: `FluxQ/Views/SettingsView.swift`

**Step 1: 添加通知设置 Section**

修改 `FluxQ/Views/SettingsView.swift`，添加 `@AppStorage` 属性和通知设置 Section。

完整替换后的文件内容：

```swift
import SwiftUI
import FluxQUI

struct SettingsView: View {
    @State private var selectedTheme: String = "系统"

    // 通知设置
    @AppStorage("notification.soundEnabled") private var soundEnabled = true
    @AppStorage("notification.soundName") private var soundName = "Glass"

    var body: some View {
        NavigationStack {
            Form {
                Section("个人信息") {
                    HStack {
                        Text("昵称")
                        Spacer()
                        Text("未设置")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("部门")
                        Spacer()
                        Text("未设置")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("状态") {
                    Picker("当前状态", selection: .constant("在线")) {
                        Text("在线").tag("在线")
                        Text("离开").tag("离开")
                        Text("忙碌").tag("忙碌")
                    }
                }

                Section("通知") {
                    Toggle("消息提示音", isOn: $soundEnabled)

                    if soundEnabled {
                        Picker("提示音", selection: $soundName) {
                            ForEach(SoundManager.availableSystemSounds, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .onChange(of: soundName) { _, newValue in
                            SoundManager.shared.play(soundName: newValue, force: true)
                        }
                    }
                }

                Section("外观") {
                    Picker("主题", selection: $selectedTheme) {
                        Text("浅色").tag("浅色")
                        Text("深色").tag("深色")
                        Text("系统").tag("系统")
                    }
                    .onChange(of: selectedTheme) { _, newValue in
                        switch newValue {
                        case "浅色":
                            ThemeManager.shared.setColorScheme(.light)
                        case "深色":
                            ThemeManager.shared.setColorScheme(.dark)
                        default:
                            ThemeManager.shared.setColorScheme(nil)
                        }
                    }
                }
            }
            .navigationTitle("我")
        }
    }
}

#Preview {
    SettingsView()
}
```

**Step 2: 构建验证**

Run: `cd /Users/martinadamsdev/workspace/FluxQ && xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add FluxQ/Views/SettingsView.swift
git commit -m "feat: add notification sound settings to SettingsView"
```

---

### Task 5: 清除未读计数

用户打开对话时将 `unreadCount` 重置为 0。

**Files:**
- Modify: `FluxQ/Views/ConversationDetailView.swift`

**Step 1: 写失败测试**

在 `Modules/FluxQModels/Tests/FluxQModelsTests/ConversationTests.swift` 末尾追加测试（如果文件存在则追加，否则创建）：

```swift
@Test("unreadCount 可以重置为 0")
func resetUnreadCount() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Conversation.self, User.self, Message.self, FileTransfer.self, configurations: config)
    let context = container.mainContext

    let conversation = Conversation(type: .private, participantIDs: [UUID()], unreadCount: 5)
    context.insert(conversation)
    try context.save()

    #expect(conversation.unreadCount == 5)

    conversation.unreadCount = 0
    try context.save()

    #expect(conversation.unreadCount == 0)
}
```

**Step 2: 运行测试确认通过**

Run: `swift test --package-path Modules/FluxQModels --filter "resetUnreadCount" 2>&1 | tail -10`
Expected: PASS（模型本身已支持，这是验证性测试）

**Step 3: 在 ConversationDetailView 中清除未读计数**

修改 `FluxQ/Views/ConversationDetailView.swift`，在 Task 1 添加的 `.onAppear` 块中追加未读清除逻辑。

将 `.onAppear` 修改为：

```swift
.onAppear {
    conversationTracker.activeConversationId = conversationId
    clearUnreadCount(for: conversationId)
}
```

在 `// MARK: - Actions` 区域添加方法：

```swift
private func clearUnreadCount(for conversationId: UUID) {
    let descriptor = FetchDescriptor<Conversation>(
        predicate: #Predicate { $0.id == conversationId }
    )
    if let conversation = try? modelContext.fetch(descriptor).first,
       conversation.unreadCount > 0 {
        conversation.unreadCount = 0
        try? modelContext.save()
    }
}
```

**Step 4: 构建验证**

Run: `cd /Users/martinadamsdev/workspace/FluxQ && xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add FluxQ/Views/ConversationDetailView.swift \
       Modules/FluxQModels/Tests/FluxQModelsTests/ConversationTests.swift
git commit -m "feat: clear unread count when opening conversation"
```

---

### Task 6: 串联所有服务 — FluxQApp 消息处理 + 通知点击跳转

在消息接收流程中接入 SoundManager 和 NotificationService。处理通知点击跳转到对应对话。

**Files:**
- Modify: `FluxQ/FluxQApp.swift`

**Step 1: 添加通知委托类**

在 `FluxQ/FluxQApp.swift` 文件底部（`FluxQApp` struct 外面）添加通知委托：

```swift
// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onNotificationTapped: ((UUID) -> Void)?

    /// App 在前台时收到通知 — 仍然显示横幅
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// 用户点击通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let idString = userInfo["conversationId"] as? String,
           let conversationId = UUID(uuidString: idString) {
            Task { @MainActor in
                onNotificationTapped?(conversationId)
            }
        }
        completionHandler()
    }
}
```

**Step 2: 修改 FluxQApp 添加通知处理逻辑**

在 `FluxQApp` struct 中添加属性：

```swift
@StateObject private var conversationTracker = ActiveConversationTracker()
private let notificationDelegate = NotificationDelegate()
```

注意：如果 Task 1 已经添加了 `conversationTracker`，不要重复添加。

修改 `.onChange(of: networkManager.receivedMessages.count)` 闭包，在 `MessageReceiveHandler.handleReceivedMessage()` 调用之后，追加通知和声音逻辑：

```swift
.onChange(of: networkManager.receivedMessages.count) { _, newCount in
    guard newCount > lastProcessedMessageCount else { return }
    let context = sharedModelContainer.mainContext
    for i in lastProcessedMessageCount..<newCount {
        let received = networkManager.receivedMessages[i]
        MessageReceiveHandler.handleReceivedMessage(received, in: context)

        // 通知和提示音
        handleNotification(for: received)
    }
    lastProcessedMessageCount = newCount
}
```

添加新方法：

```swift
private func handleNotification(for received: ReceivedMessage) {
    // 读取设置
    let soundEnabled = UserDefaults.standard.bool(forKey: "notification.soundEnabled")
    // @AppStorage 默认值为 true，但 UserDefaults.bool 对未设置的 key 返回 false
    // 所以需要检查是否已设置过
    let isSoundEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "notification.soundEnabled") == nil {
            return true // 默认开启
        }
        return UserDefaults.standard.bool(forKey: "notification.soundEnabled")
    }()
    let soundName = UserDefaults.standard.string(forKey: "notification.soundName") ?? "Glass"

    // 查找该消息对应的对话 ID
    let hostname = received.hostname
    let ipAddress = received.fromHost
    let context = sharedModelContainer.mainContext
    let userDescriptor = FetchDescriptor<User>(
        predicate: #Predicate { $0.hostname == hostname && $0.ipAddress == ipAddress }
    )
    guard let sender = try? context.fetch(userDescriptor).first else { return }
    let senderID = sender.id
    let convDescriptor = FetchDescriptor<Conversation>(
        predicate: #Predicate { $0.participantIDs.contains(senderID) }
    )
    let conversationId = (try? context.fetch(convDescriptor).first)?.id

    // 如果用户正在查看该对话，不播放提示音
    if let conversationId,
       conversationTracker.activeConversationId == conversationId {
        return
    }

    // 播放提示音（带节流）
    if isSoundEnabled {
        SoundManager.shared.play(soundName: soundName)
    }

    // App 非活跃时发送本地通知
    #if os(macOS)
    let isAppActive = NSApplication.shared.isActive
    #else
    let isAppActive = true // iOS 前台由 willPresent delegate 处理
    #endif

    if !isAppActive, let conversationId {
        NotificationService.shared.sendNotification(
            title: received.senderName,
            body: received.content,
            conversationId: conversationId,
            soundName: soundName
        )
    }
}
```

**Step 3: 设置通知委托和点击跳转**

在 `startNetworkServices()` 方法中添加通知委托设置：

```swift
private func startNetworkServices() {
    // 设置通知委托
    UNUserNotificationCenter.current().delegate = notificationDelegate
    notificationDelegate.onNotificationTapped = { conversationId in
        // 通过发送 StartChatAction 类似的机制跳转
        // 由于 FluxQApp 无法直接访问 MacMainView 的 state，
        // 使用 NotificationCenter post
        NotificationCenter.default.post(
            name: .navigateToConversation,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }

    // 请求通知权限
    NotificationService.shared.requestPermission()

    do {
        try networkManager.start()
        let nm = networkManager
        heartbeatService.start {
            try await nm.refreshDiscovery()
        }
    } catch {
        print("FluxQApp: 启动网络服务失败 - \(error)")
    }
}
```

需要在文件顶部（或者底部）添加 Notification.Name 扩展：

```swift
extension Notification.Name {
    static let navigateToConversation = Notification.Name("navigateToConversation")
}
```

并在文件顶部添加 import：

```swift
import UserNotifications
```

**Step 4: 在 MacMainView 中监听跳转通知**

修改 `FluxQ/macOS/MacMainView.swift`，在 `MacMainView` 的 body 末尾（`.focusedSceneValue` 和 `.environment` 之后）添加：

```swift
.onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
    if let conversationId = notification.userInfo?["conversationId"] as? UUID {
        selectedTab = .messages
        selectedConversation = conversationId
    }
}
```

在文件顶部确保有 `import Foundation`（如果还没有的话）。

**Step 5: 在 MainTabView 中也监听跳转通知（iOS）**

修改 `FluxQ/iOS/MainTabView.swift`，在 body 的 `.environment(\.startChat, ...)` 之后添加：

```swift
.onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
    if let conversationId = notification.userInfo?["conversationId"] as? UUID {
        activeConversationId = conversationId
        selectedTab = .messages
    }
}
```

在文件顶部添加 `import Foundation`（如果还没有）。

**Step 6: 构建验证**

Run: `cd /Users/martinadamsdev/workspace/FluxQ && xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 7: 运行全部模块测试确认无回归**

Run: `swift test --package-path Modules/FluxQServices 2>&1 | tail -5`
Run: `swift test --package-path Modules/FluxQModels 2>&1 | tail -5`
Run: `swift test --package-path Modules/IPMsgProtocol 2>&1 | tail -5`
Expected: ALL PASSED

**Step 8: Commit**

```bash
git add FluxQ/FluxQApp.swift FluxQ/macOS/MacMainView.swift FluxQ/iOS/MainTabView.swift
git commit -m "feat: wire notification and sound into message receive flow with tap navigation"
```

---

## 手动验证清单

完成所有 Task 后，在两台 Mac 上进行端到端验证：

1. **Mac A 启动 FluxQ** → 在 Mac B 启动 FluxQ
2. **Mac A 发送消息** → Mac B 应播放 "Glass" 提示音
3. **Mac B 连续快速收到 3 条** → 只播放 1 次提示音（3 秒节流）
4. **Mac B 打开该对话** → 未读数归零，后续消息不再播放提示音
5. **Mac B 切换到其他页面** → 再收到消息应播放提示音
6. **Mac B 最小化/切到后台** → 收到消息弹出系统通知横幅
7. **点击通知横幅** → 跳转到对应对话
8. **设置页切换提示音** → 预览播放切换后的声音
9. **关闭提示音** → 收到消息不再播放声音

---

## 文件变更总览

| 操作 | 文件路径 |
|------|----------|
| **新建** | `FluxQ/Services/ActiveConversationTracker.swift` |
| **新建** | `FluxQ/Services/SoundManager.swift` |
| **新建** | `FluxQ/Services/NotificationService.swift` |
| **新建** | `Modules/FluxQServices/Sources/FluxQServices/SoundThrottle.swift` |
| **新建** | `Modules/FluxQServices/Tests/FluxQServicesTests/SoundThrottleTests.swift` |
| 修改 | `FluxQ/FluxQApp.swift` |
| 修改 | `FluxQ/Views/ConversationDetailView.swift` |
| 修改 | `FluxQ/Views/SettingsView.swift` |
| 修改 | `FluxQ/macOS/MacMainView.swift` |
| 修改 | `FluxQ/iOS/MainTabView.swift` |
| 修改 | `Modules/FluxQModels/Tests/FluxQModelsTests/ConversationTests.swift` |
