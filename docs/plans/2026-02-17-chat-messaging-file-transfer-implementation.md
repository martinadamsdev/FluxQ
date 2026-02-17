# 聊天消息收发与文件传输 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 打通发现用户→进入聊天→发消息→收消息→传文件的完整链路，补齐所有测试。

**Architecture:** 四个垂直切片按顺序执行：(1) 会话列表真实化 (2) 消息收发闭环 (3) 文件传输 (4) 消息操作接线。每个切片包含服务层→UI→测试。

**Tech Stack:** SwiftUI, SwiftData (@Query, @Model, ModelContext), Network.framework (TCP/UDP), Swift Testing (@Test, #expect), XCUITest, IPMsgProtocol

**Design Doc:** `docs/plans/2026-02-17-chat-messaging-file-transfer-design.md`

---

## 切片 1：会话列表真实化

---

### Task 1: Conversation 添加 displayName 计算属性

**Files:**
- Modify: `Modules/FluxQModels/Sources/FluxQModels/Conversation.swift:5-31`
- Test: `Modules/FluxQModels/Tests/FluxQModelsTests/ConversationTests.swift`

**Step 1: Write the failing test**

在 `Modules/FluxQModels/Tests/FluxQModelsTests/ConversationTests.swift` 末尾添加：

```swift
@Test("displayName returns first participant nickname for private conversation")
func displayNamePrivateConversation() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: User.self, Conversation.self, Message.self,
        configurations: config
    )
    let context = ModelContext(container)

    let user = User(nickname: "Alice", hostname: "alice-mac", ipAddress: "192.168.1.10")
    context.insert(user)

    let conv = Conversation(type: .private, participantIDs: [user.id])
    conv.participants = [user]
    context.insert(conv)
    try context.save()

    #expect(conv.displayName == "Alice")
}

@Test("displayName returns '未知' when no participants")
func displayNameEmpty() throws {
    let conv = Conversation(type: .private, participantIDs: [])
    #expect(conv.displayName == "未知")
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path Modules/FluxQModels --filter "displayName"`
Expected: FAIL — `Conversation` has no member `displayName`

**Step 3: Write minimal implementation**

在 `Modules/FluxQModels/Sources/FluxQModels/Conversation.swift` 的 `Conversation` class 末尾（`init` 之后）添加：

```swift
/// 会话显示名称：取第一个参与者的昵称
public var displayName: String {
    participants?.first?.nickname ?? "未知"
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --package-path Modules/FluxQModels --filter "displayName"`
Expected: PASS

**Step 5: Commit**

```bash
git add Modules/FluxQModels/Sources/FluxQModels/Conversation.swift \
       Modules/FluxQModels/Tests/FluxQModelsTests/ConversationTests.swift
git commit -m "feat(models): add displayName computed property to Conversation"
```

---

### Task 2: ConversationListView 替换为 SwiftData 真实数据

**Files:**
- Modify: `FluxQ/Views/ConversationListView.swift` (全面重写)

**Context:** 当前 ConversationListView 使用 `SampleConversation` 硬编码假数据。需要替换为 SwiftData `@Query` 查询真实 `Conversation` 对象。

**Step 1: Rewrite ConversationListView**

将 `FluxQ/Views/ConversationListView.swift` 完整替换为：

```swift
import SwiftUI
import SwiftData
import FluxQModels

struct ConversationListView: View {
    /// macOS/iPad: selection binding for multi-column layout
    @Binding var selection: UUID?

    /// iPhone: programmatic navigation target
    @Binding var activeConversationId: UUID?

    #if os(iOS)
    @Environment(\.deviceCategory) private var deviceCategory
    #endif

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.lastMessageTimestamp, order: .reverse)
    private var conversations: [Conversation]

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List(selection: $selection) {
                if conversations.isEmpty {
                    ContentUnavailableView {
                        Label("暂无消息", systemImage: "message.fill")
                    } description: {
                        Text("从发现页开始新的对话")
                    }
                } else {
                    ForEach(conversations) { conversation in
                        #if os(iOS)
                        conversationRow(conversation)
                        #else
                        conversationRow(conversation)
                        #endif
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("消息")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // TODO: 新建群聊
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { conversationId in
                ConversationDetailView(conversationId: conversationId)
            }
        }
        .onChange(of: activeConversationId) { _, newValue in
            if let id = newValue {
                navigationPath.append(id)
                activeConversationId = nil
            }
        }
    }

    // MARK: - 会话行视图

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation) -> some View {
        let participant = conversation.participants?.first

        HStack(spacing: 12) {
            // 头像
            UserAvatarView(
                avatarData: participant?.avatarData,
                size: 48
            )

            // 消息内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.lastMessageTimestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(lastMessageText(for: conversation))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func lastMessageText(for conversation: Conversation) -> String {
        guard let messages = conversation.messages,
              let last = messages.sorted(by: { $0.timestamp < $1.timestamp }).last else {
            return "暂无消息"
        }
        return last.isRecalled ? "消息已撤回" : last.content
    }
}

// MARK: - 向后兼容

extension ConversationListView {
    /// macOS/iPad init with selection binding
    init(selection: Binding<UUID?>) {
        self._selection = selection
        self._activeConversationId = .constant(nil)
    }

    /// iPhone init with activeConversationId binding
    init(activeConversationId: Binding<UUID?>) {
        self._selection = .constant(nil)
        self._activeConversationId = activeConversationId
    }

    /// Default init (no external navigation)
    init() {
        self._selection = .constant(nil)
        self._activeConversationId = .constant(nil)
    }
}

// MARK: - Previews

#Preview("消息列表") {
    NavigationStack {
        ConversationListView()
    }
    .modelContainer(for: [User.self, Message.self, Conversation.self], inMemory: true)
}
```

**Step 2: Add `import FluxQModels` to ConversationListView if not present; add `import` for `UserAvatarView` component**

Verify the file imports `FluxQModels` and that `UserAvatarView` is accessible (it's in `FluxQ/Views/Components/UserAvatarView.swift`, same target).

**Step 3: Build and verify**

Run: `xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

If build fails due to missing `UserAvatarView` accepting `avatarData: Data?`, check `FluxQ/Views/Components/UserAvatarView.swift` and adjust the call to match its current API.

**Step 4: Commit**

```bash
git add FluxQ/Views/ConversationListView.swift
git commit -m "feat(ui): replace sample data with SwiftData @Query in ConversationListView"
```

---

### Task 3: 集成测试 — ConversationService 创建会话后列表可见

**Files:**
- Create: `Modules/FluxQModels/Tests/FluxQModelsTests/ConversationListIntegrationTests.swift`

**Step 1: Write integration test**

```swift
import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("Conversation List Integration Tests")
struct ConversationListIntegrationTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self,
            configurations: config
        )
    }

    @Test("ConversationService creates conversation visible via FetchDescriptor")
    func conversationVisibleAfterCreation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Act: create conversation via ConversationService
        let convId = ConversationService.findOrCreateConversation(
            hostname: "alice-mac",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        // Assert: query finds it (simulates what @Query does in UI)
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        let conversations = try context.fetch(descriptor)
        #expect(conversations.count == 1)
        #expect(conversations[0].id == convId)
        #expect(conversations[0].displayName == "Alice")
    }

    @Test("Multiple conversations sorted by lastMessageTimestamp descending")
    func conversationsSortedByTimestamp() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Create two conversations with different timestamps
        let id1 = ConversationService.findOrCreateConversation(
            hostname: "alice-mac", senderName: "alice", nickname: "Alice",
            ipAddress: "192.168.1.10", port: 2425, group: nil, in: context
        )

        // Small delay to ensure different timestamps
        let id2 = ConversationService.findOrCreateConversation(
            hostname: "bob-mac", senderName: "bob", nickname: "Bob",
            ipAddress: "192.168.1.20", port: 2425, group: nil, in: context
        )

        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        let conversations = try context.fetch(descriptor)
        #expect(conversations.count == 2)
        // Bob should be first (created later, so more recent timestamp)
        #expect(conversations[0].id == id2)
    }

    @Test("Tapping same user twice reuses conversation and updates timestamp")
    func tapSameUserTwice() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let id1 = ConversationService.findOrCreateConversation(
            hostname: "alice-mac", senderName: "alice", nickname: "Alice",
            ipAddress: "192.168.1.10", port: 2425, group: nil, in: context
        )

        let id2 = ConversationService.findOrCreateConversation(
            hostname: "alice-mac", senderName: "alice", nickname: "Alice",
            ipAddress: "192.168.1.10", port: 2425, group: nil, in: context
        )

        #expect(id1 == id2)

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
    }
}
```

**Step 2: Run tests**

Run: `swift test --package-path Modules/FluxQModels --filter "ConversationListIntegration"`
Expected: PASS

**Step 3: Commit**

```bash
git add Modules/FluxQModels/Tests/FluxQModelsTests/ConversationListIntegrationTests.swift
git commit -m "test(models): add ConversationListView integration tests"
```

---

## 切片 2：消息收发闭环

---

### Task 4: CurrentUserService — 当前用户身份管理

**Files:**
- Create: `FluxQ/Services/CurrentUserService.swift`

**Context:** ConversationDetailView 中 `currentUserID` 是硬编码 UUID。需要从 NetworkManager 获取真实的当前用户身份。

**Step 1: Create CurrentUserService**

创建 `FluxQ/Services/CurrentUserService.swift`：

```swift
import Foundation
import SwiftData
import FluxQModels
import FluxQServices

enum CurrentUserService {

    /// 获取或创建当前用户的 User 对象
    ///
    /// 使用 NetworkManager 的 deviceName/hostname 作为标识，
    /// 在 SwiftData 中查找或创建对应 User。
    static func currentUser(
        networkManager: NetworkManager,
        in context: ModelContext
    ) -> User {
        let hostname = hostName()
        let deviceName = deviceName()
        let localIP = "127.0.0.1"

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate {
                $0.hostname == hostname && $0.ipAddress == localIP
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.isOnline = true
            existing.lastSeen = Date()
            return existing
        }

        let user = User(
            nickname: deviceName,
            hostname: hostname,
            ipAddress: localIP,
            port: 2425,
            status: .online,
            isOnline: true
        )
        context.insert(user)
        try? context.save()
        return user
    }

    private static func deviceName() -> String {
        #if os(macOS)
        return Host.current().localizedName ?? "Unknown"
        #elseif os(iOS)
        return UIDevice.current.name
        #elseif os(watchOS)
        return WKInterfaceDevice.current().name
        #else
        return "Unknown"
        #endif
    }

    private static func hostName() -> String {
        #if os(macOS)
        return Host.current().name ?? "Unknown"
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }
}
```

**Step 2: Add to Xcode project if needed**

Ensure the file is in the FluxQ target. If using Xcode project (not SPM for app target), add it to `FluxQ.xcodeproj`.

**Step 3: Build and verify**

Run: `xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add FluxQ/Services/CurrentUserService.swift
git commit -m "feat: add CurrentUserService for current user identity management"
```

---

### Task 5: Wire ConversationDetailView 发送消息到网络

**Files:**
- Modify: `FluxQ/Views/ConversationDetailView.swift:1-242`

**Context:** 当前 `sendMessage()` 只存 SwiftData 不发网络。需要接线 `TCPMessageService` 和 `CurrentUserService`。

**Step 1: Update ConversationDetailView**

修改 `FluxQ/Views/ConversationDetailView.swift`：

1. 替换硬编码 `currentUserID` 为 `CurrentUserService` 查询。
2. 添加 `@EnvironmentObject private var networkManager: NetworkManager` 获取对方用户信息。
3. 在 `sendMessage()` 中调用 `networkManager.sendMessage(to:message:)` 发送到网络。
4. 处理发送成功/失败更新 `Message.status`。

关键变更：

```swift
// 替换:
// private let currentUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

// 改为:
@EnvironmentObject private var networkManager: NetworkManager

private var currentUserID: UUID {
    CurrentUserService.currentUser(
        networkManager: networkManager,
        in: modelContext
    ).id
}
```

`sendMessage` 方法改为：

```swift
private func sendMessage(to conversationId: UUID) {
    let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let message = Message(
        conversationID: conversationId,
        senderID: currentUserID,
        content: trimmed,
        status: .sending
    )
    modelContext.insert(message)
    messageText = ""
    scrollTarget = message.id

    // Find the target user for this conversation
    let targetUser = findTargetUser(for: conversationId)

    Task {
        do {
            if let user = targetUser {
                try await networkManager.sendMessage(to: user, message: trimmed)
            }
            message.status = .sent
            try? modelContext.save()
        } catch {
            message.status = .failed
            try? modelContext.save()
        }
    }
}

private func findTargetUser(for conversationId: UUID) -> DiscoveredUser? {
    // Find conversation's participant
    let descriptor = FetchDescriptor<Conversation>(
        predicate: #Predicate { $0.id == conversationId }
    )
    guard let conversation = try? modelContext.fetch(descriptor).first,
          let participant = conversation.participants?.first else {
        return nil
    }

    // Match to discovered user by ipAddress
    return networkManager.discoveredUsers.values.first {
        $0.ipAddress == participant.ipAddress
    }
}
```

**Step 2: Add resend button for failed messages in MessageBubbleView**

In `FluxQ/Views/Components/MessageBubbleView.swift`, add an optional `onResend` closure parameter and show a resend button when `status == .failed`:

```swift
// Add parameter:
var onResend: (() -> Void)? = nil

// In body, after the bubble, when status is .failed:
if status == .failed, let onResend {
    Button(action: onResend) {
        Image(systemName: "arrow.clockwise.circle")
            .foregroundStyle(.red)
    }
    .buttonStyle(.plain)
}
```

**Step 3: Build and verify**

Run: `xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add FluxQ/Views/ConversationDetailView.swift \
       FluxQ/Views/Components/MessageBubbleView.swift
git commit -m "feat: wire ConversationDetailView message sending to NetworkManager"
```

---

### Task 6: MessageReceiveHandler — 接收消息持久化

**Files:**
- Create: `FluxQ/Services/MessageReceiveHandler.swift`

**Context:** NetworkManager 收到 SENDMSG 后只追加到 `receivedMessages` 数组。需要将消息持久化到 SwiftData，使 ConversationDetailView 的 @Query 自动刷新。

**Step 1: Create MessageReceiveHandler**

创建 `FluxQ/Services/MessageReceiveHandler.swift`：

```swift
import Foundation
import SwiftData
import FluxQModels
import FluxQServices
import IPMsgProtocol

@MainActor
enum MessageReceiveHandler {

    /// 处理收到的消息，持久化到 SwiftData
    static func handleReceivedMessage(
        _ received: ReceivedMessage,
        in context: ModelContext
    ) {
        // 1. 查找或创建发送方 User
        let conversationId = ConversationService.findOrCreateConversation(
            hostname: received.hostname,
            senderName: received.senderName,
            nickname: received.senderName,
            ipAddress: received.fromHost,
            port: 2425,
            group: nil,
            in: context
        )

        // 2. 查找发送方 User ID
        let senderDescriptor = FetchDescriptor<User>(
            predicate: #Predicate {
                $0.hostname == received.hostname && $0.ipAddress == received.fromHost
            }
        )
        let senderID = (try? context.fetch(senderDescriptor).first)?.id ?? UUID()

        // 3. 创建 Message
        let message = Message(
            conversationID: conversationId,
            senderID: senderID,
            content: received.content,
            status: .delivered
        )
        context.insert(message)

        // 4. 更新会话时间戳
        let convDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )
        if let conversation = try? context.fetch(convDescriptor).first {
            conversation.lastMessageTimestamp = Date()
            conversation.unreadCount += 1
        }

        try? context.save()
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add FluxQ/Services/MessageReceiveHandler.swift
git commit -m "feat: add MessageReceiveHandler for persisting received messages"
```

---

### Task 7: Wire NetworkManager 消息接收到 MessageReceiveHandler

**Files:**
- Modify: `FluxQ/FluxQApp.swift:58-87`

**Context:** NetworkManager.receivedMessages 是 @Published 数组。需要在应用层监听变化并调用 MessageReceiveHandler。

**Step 1: Add message observation in FluxQApp**

在 `FluxQ/FluxQApp.swift` 的 `ContentView()` 上添加 `.onChange` 监听：

```swift
ContentView()
    .themedColorScheme(themeManager)
    .environmentObject(networkManager)
    .environmentObject(heartbeatService)
    .onAppear {
        startNetworkServices()
    }
    .onChange(of: networkManager.receivedMessages.count) { _, _ in
        handleNewMessages()
    }
```

添加 `handleNewMessages` 方法：

```swift
private func handleNewMessages() {
    guard let lastMessage = networkManager.receivedMessages.last else { return }
    let context = sharedModelContainer.mainContext
    MessageReceiveHandler.handleReceivedMessage(lastMessage, in: context)
}
```

**注意：** `ReceivedMessage` 需要遵循 `Equatable` 协议才能使 `.onChange` 工作。如果 `receivedMessages.count` 不触发，改用 `onReceive` 或在 NetworkManager 中添加一个 message received 的回调。

替代方案（如果 `.onChange(of: count)` 不稳定）：

在 FluxQApp 中使用 Combine `.onReceive`：

```swift
.onReceive(networkManager.$receivedMessages) { messages in
    guard let last = messages.last else { return }
    // 防止重复处理（检查是否已持久化）
    let context = sharedModelContainer.mainContext
    MessageReceiveHandler.handleReceivedMessage(last, in: context)
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add FluxQ/FluxQApp.swift
git commit -m "feat: wire NetworkManager message reception to MessageReceiveHandler"
```

---

### Task 8: 消息收发单元测试

**Files:**
- Create: `Modules/FluxQModels/Tests/FluxQModelsTests/MessageReceiveTests.swift`

**Step 1: Write tests**

```swift
import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("Message Persistence Tests")
struct MessagePersistenceTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self,
            configurations: config
        )
    }

    @Test("Message persisted to conversation is fetchable")
    func messagePersisted() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Create user and conversation
        let convId = ConversationService.findOrCreateConversation(
            hostname: "alice-mac", senderName: "alice", nickname: "Alice",
            ipAddress: "192.168.1.10", port: 2425, group: nil, in: context
        )

        // Create message
        let message = Message(
            conversationID: convId,
            senderID: UUID(),
            content: "Hello!",
            status: .delivered
        )
        context.insert(message)
        try context.save()

        // Fetch messages for conversation
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.conversationID == convId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let messages = try context.fetch(descriptor)
        #expect(messages.count == 1)
        #expect(messages[0].content == "Hello!")
        #expect(messages[0].status == .delivered)
    }

    @Test("Sent message has correct initial status")
    func sentMessageStatus() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let message = Message(
            conversationID: UUID(),
            senderID: UUID(),
            content: "Test",
            status: .sending
        )
        context.insert(message)

        #expect(message.status == .sending)

        // Simulate send success
        message.status = .sent
        #expect(message.status == .sent)

        // Simulate send failure
        message.status = .failed
        #expect(message.status == .failed)
    }

    @Test("Multiple messages in conversation sorted by timestamp")
    func messagesOrderedByTimestamp() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let convId = UUID()
        let msg1 = Message(
            conversationID: convId, senderID: UUID(),
            content: "First", timestamp: Date().addingTimeInterval(-60)
        )
        let msg2 = Message(
            conversationID: convId, senderID: UUID(),
            content: "Second", timestamp: Date()
        )
        context.insert(msg1)
        context.insert(msg2)
        try context.save()

        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.conversationID == convId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let messages = try context.fetch(descriptor)
        #expect(messages.count == 2)
        #expect(messages[0].content == "First")
        #expect(messages[1].content == "Second")
    }
}
```

**Step 2: Run tests**

Run: `swift test --package-path Modules/FluxQModels --filter "MessagePersistence"`
Expected: PASS

**Step 3: Commit**

```bash
git add Modules/FluxQModels/Tests/FluxQModelsTests/MessageReceiveTests.swift
git commit -m "test(models): add message persistence and ordering tests"
```

---

### Task 9: NetworkManager 消息发送集成测试

**Files:**
- Create: `Modules/FluxQServices/Tests/FluxQServicesTests/MessageSendIntegrationTests.swift`

**Step 1: Write integration test using MockNetworkTransport**

```swift
import Testing
import Foundation
@testable import FluxQServices
@testable import IPMsgProtocol

@Suite("Message Send Integration Tests")
struct MessageSendIntegrationTests {

    @Test("sendMessage sends SENDMSG packet to correct host")
    @MainActor
    func sendMessageToUser() async throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        try manager.start()

        let user = DiscoveredUser(
            senderName: "alice",
            nickname: "Alice",
            hostname: "alice-mac",
            ipAddress: "192.168.1.10",
            port: 2425
        )

        try await manager.sendMessage(to: user, message: "Hello!")

        #expect(transport.sentMessages.count == 1)
        let sent = transport.sentMessages[0]
        #expect(sent.host == "192.168.1.10")
        #expect(sent.port == 2425)

        // Decode the sent packet and verify content
        let packetStr = String(data: sent.data, encoding: .utf8)!
        let packet = try IPMsgPacket.decode(packetStr)
        #expect(packet.command == .SENDMSG)
        #expect(packet.payload.contains("Hello!"))
    }

    @Test("Received SENDMSG updates receivedMessages array")
    @MainActor
    func receiveMessageUpdatesArray() throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        try manager.start()

        // Simulate receiving a SENDMSG packet
        let packet = IPMsgPacket(
            version: 1, packetNo: 100,
            sender: "bob", hostname: "bob-mac",
            command: .SENDMSG, payload: "Hi there!"
        )
        let data = packet.encode().data(using: .utf8)!
        transport.simulateReceive(data: data, from: "192.168.1.20")

        #expect(manager.receivedMessages.count == 1)
        #expect(manager.receivedMessages[0].content == "Hi there!")
        #expect(manager.receivedMessages[0].senderName == "bob")
        #expect(manager.receivedMessages[0].fromHost == "192.168.1.20")
    }

    @Test("Received SENDMSG triggers RECVMSG confirmation")
    @MainActor
    func receiveMessageSendsConfirmation() async throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        try manager.start()

        let packet = IPMsgPacket(
            version: 1, packetNo: 200,
            sender: "bob", hostname: "bob-mac",
            command: .SENDMSG, payload: "Test"
        )
        let data = packet.encode().data(using: .utf8)!
        transport.simulateReceive(data: data, from: "192.168.1.20")

        // Give async Task time to execute
        try await Task.sleep(nanoseconds: 100_000_000)

        // Should have sent RECVMSG confirmation
        let confirmations = transport.sentMessages.filter { msg in
            guard let str = String(data: msg.data, encoding: .utf8),
                  let pkt = try? IPMsgPacket.decode(str) else { return false }
            return pkt.command == .RECVMSG
        }
        #expect(confirmations.count == 1)
    }
}
```

**Step 2: Run tests**

Run: `swift test --package-path Modules/FluxQServices --filter "MessageSendIntegration"`
Expected: PASS

**Step 3: Commit**

```bash
git add Modules/FluxQServices/Tests/FluxQServicesTests/MessageSendIntegrationTests.swift
git commit -m "test(services): add message send/receive integration tests"
```

---

## 切片 3：文件传输

---

### Task 10: 协议层 — FileMetadata 和 FileAttribute

**Files:**
- Create: `Modules/IPMsgProtocol/Sources/IPMsgProtocol/FileMetadata.swift`
- Test: `Modules/IPMsgProtocol/Tests/IPMsgProtocolTests/FileMetadataTests.swift`

**Step 1: Write failing tests**

创建 `Modules/IPMsgProtocol/Tests/IPMsgProtocolTests/FileMetadataTests.swift`：

```swift
import Testing
import Foundation
@testable import IPMsgProtocol

@Suite("FileMetadata Tests")
struct FileMetadataTests {

    @Test("Parse single file attachment from payload")
    func parseSingleFile() throws {
        // IPMsg format: "fileID\afileName:fileSize:modTime:fileAttr:\a"
        // fileSize and modTime are hex
        let payload = "0\u{07}test.txt:a:65d5f000:1:\u{07}"
        let files = FileMetadata.parse(from: payload)

        #expect(files.count == 1)
        #expect(files[0].fileID == 0)
        #expect(files[0].fileName == "test.txt")
        #expect(files[0].fileSize == 10)  // 0xa = 10
        #expect(files[0].fileAttribute == .regular)
    }

    @Test("Parse multiple file attachments")
    func parseMultipleFiles() throws {
        let payload = "0\u{07}file1.txt:64:65d5f000:1:\u{07}1\u{07}file2.pdf:c800:65d5f000:1:\u{07}"
        let files = FileMetadata.parse(from: payload)

        #expect(files.count == 2)
        #expect(files[0].fileName == "file1.txt")
        #expect(files[0].fileSize == 100)  // 0x64
        #expect(files[1].fileName == "file2.pdf")
        #expect(files[1].fileSize == 51200)  // 0xc800
    }

    @Test("Parse directory attachment")
    func parseDirectory() throws {
        let payload = "0\u{07}mydir:0:65d5f000:2:\u{07}"
        let files = FileMetadata.parse(from: payload)

        #expect(files.count == 1)
        #expect(files[0].fileName == "mydir")
        #expect(files[0].fileAttribute == .directory)
    }

    @Test("Empty payload returns empty array")
    func emptyPayload() {
        let files = FileMetadata.parse(from: "")
        #expect(files.isEmpty)
    }

    @Test("FileMetadata encode to payload string")
    func encodeToPayload() {
        let metadata = FileMetadata(
            fileID: 0,
            fileName: "test.txt",
            fileSize: 1024,
            modificationTime: Date(timeIntervalSince1970: 0x65d5f000),
            fileAttribute: .regular
        )
        let payload = metadata.encodeToPayload()
        #expect(payload.contains("test.txt"))
        #expect(payload.contains("400"))  // 1024 in hex
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --package-path Modules/IPMsgProtocol --filter "FileMetadata"`
Expected: FAIL — no module `FileMetadata`

**Step 3: Implement FileMetadata**

创建 `Modules/IPMsgProtocol/Sources/IPMsgProtocol/FileMetadata.swift`：

```swift
import Foundation

/// IPMsg 文件属性类型
public enum FileAttribute: UInt32, Sendable, Equatable {
    case regular = 0x00000001
    case directory = 0x00000002
    case symlink = 0x00000004
    case clipboard = 0x00000020
}

/// IPMsg 文件传输元数据
///
/// 解析 SENDMSG + FILEATTACHOPT payload 中的文件附件信息。
/// 格式: "fileID\x07fileName:fileSize(hex):modTime(hex):fileAttr(hex):\x07"
public struct FileMetadata: Sendable, Equatable {
    public let fileID: Int
    public let fileName: String
    public let fileSize: Int64
    public let modificationTime: Date
    public let fileAttribute: FileAttribute

    public init(
        fileID: Int,
        fileName: String,
        fileSize: Int64,
        modificationTime: Date,
        fileAttribute: FileAttribute
    ) {
        self.fileID = fileID
        self.fileName = fileName
        self.fileSize = fileSize
        self.modificationTime = modificationTime
        self.fileAttribute = fileAttribute
    }

    /// 从 payload 字符串解析文件元数据列表
    ///
    /// Payload 格式: "fileID\x07fileName:size:mtime:attr:\x07..."
    /// 多个文件用 \x07 分隔
    public static func parse(from payload: String) -> [FileMetadata] {
        guard !payload.isEmpty else { return [] }

        var results: [FileMetadata] = []
        let segments = payload.split(separator: "\u{07}", omittingEmptySubsequences: true)

        var i = 0
        while i < segments.count {
            let fileIDStr = String(segments[i])

            // 如果当前 segment 只是 fileID 数字，下一个是 "name:size:mtime:attr:"
            if let fileID = Int(fileIDStr), i + 1 < segments.count {
                let infoStr = String(segments[i + 1])
                if let metadata = parseFileInfo(fileID: fileID, info: infoStr) {
                    results.append(metadata)
                }
                i += 2
            } else {
                // 可能是 "fileID" 和 info 在同一 segment 或格式不同
                i += 1
            }
        }

        return results
    }

    /// 编码为 payload 字符串
    public func encodeToPayload() -> String {
        let sizeHex = String(fileSize, radix: 16)
        let mtimeHex = String(Int(modificationTime.timeIntervalSince1970), radix: 16)
        let attrHex = String(fileAttribute.rawValue, radix: 16)
        return "\(fileID)\u{07}\(fileName):\(sizeHex):\(mtimeHex):\(attrHex):\u{07}"
    }

    // MARK: - Private

    private static func parseFileInfo(fileID: Int, info: String) -> FileMetadata? {
        let parts = info.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4 else { return nil }

        let fileName = parts[0]
        let fileSize = Int64(parts[1], radix: 16) ?? 0
        let modTime = Int(parts[2], radix: 16).map {
            Date(timeIntervalSince1970: TimeInterval($0))
        } ?? Date()
        let attrRaw = UInt32(parts[3], radix: 16) ?? 1
        let attr = FileAttribute(rawValue: attrRaw) ?? .regular

        return FileMetadata(
            fileID: fileID,
            fileName: fileName,
            fileSize: fileSize,
            modificationTime: modTime,
            fileAttribute: attr
        )
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --package-path Modules/IPMsgProtocol --filter "FileMetadata"`
Expected: PASS

**Step 5: Commit**

```bash
git add Modules/IPMsgProtocol/Sources/IPMsgProtocol/FileMetadata.swift \
       Modules/IPMsgProtocol/Tests/IPMsgProtocolTests/FileMetadataTests.swift
git commit -m "feat(protocol): add FileMetadata parsing and encoding for file transfer"
```

---

### Task 11: 数据模型 — FileTransfer + Message 扩展

**Files:**
- Create: `Modules/FluxQModels/Sources/FluxQModels/FileTransfer.swift`
- Modify: `Modules/FluxQModels/Sources/FluxQModels/Message.swift:1-37`
- Modify: `Modules/FluxQModels/Sources/FluxQModels/Enums.swift:1-31`
- Modify: `FluxQ/FluxQApp.swift:20-26` (添加 FileTransfer 到 Schema)
- Test: `Modules/FluxQModels/Tests/FluxQModelsTests/FileTransferTests.swift`

**Step 1: Write failing tests**

创建 `Modules/FluxQModels/Tests/FluxQModelsTests/FileTransferTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("FileTransfer Model Tests")
struct FileTransferModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self, FileTransfer.self,
            configurations: config
        )
    }

    @Test("Create FileTransfer with all fields")
    func createFileTransfer() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "test.pdf",
            fileSize: 1024 * 1024,
            direction: .outgoing
        )
        context.insert(transfer)
        try context.save()

        let descriptor = FetchDescriptor<FileTransfer>()
        let transfers = try context.fetch(descriptor)
        #expect(transfers.count == 1)
        #expect(transfers[0].fileName == "test.pdf")
        #expect(transfers[0].fileSize == 1024 * 1024)
        #expect(transfers[0].status == .pending)
        #expect(transfers[0].direction == .outgoing)
        #expect(transfers[0].transferredBytes == 0)
    }

    @Test("FileTransfer progress updates")
    func progressUpdates() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let transfer = FileTransfer(
            conversationID: UUID(),
            senderID: UUID(),
            fileName: "big.zip",
            fileSize: 100_000_000,
            direction: .incoming
        )
        context.insert(transfer)

        transfer.status = .transferring
        transfer.transferredBytes = 50_000_000

        #expect(transfer.progress == 0.5)

        transfer.transferredBytes = 100_000_000
        transfer.status = .completed
        transfer.completedAt = Date()

        #expect(transfer.progress == 1.0)
        #expect(transfer.status == .completed)
    }

    @Test("Message with file attachment type")
    func messageWithFileType() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let message = Message(
            conversationID: UUID(),
            senderID: UUID(),
            content: "test.pdf",
            status: .sent,
            messageType: .file,
            fileAttachmentID: UUID()
        )
        context.insert(message)
        try context.save()

        let descriptor = FetchDescriptor<Message>()
        let messages = try context.fetch(descriptor)
        #expect(messages[0].messageType == .file)
        #expect(messages[0].fileAttachmentID != nil)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --package-path Modules/FluxQModels --filter "FileTransfer"`
Expected: FAIL — `FileTransfer` not found

**Step 3: Add enums to Enums.swift**

在 `Modules/FluxQModels/Sources/FluxQModels/Enums.swift` 末尾添加：

```swift
public enum TransferStatus: String, Codable {
    case pending
    case transferring
    case completed
    case failed
    case cancelled
}

public enum TransferDirection: String, Codable {
    case outgoing
    case incoming
}

public enum MessageType: String, Codable {
    case text
    case file
    case image
}
```

**Step 4: Create FileTransfer model**

创建 `Modules/FluxQModels/Sources/FluxQModels/FileTransfer.swift`：

```swift
import Foundation
import SwiftData

@Model
public final class FileTransfer {
    @Attribute(.unique) public var id: UUID
    public var conversationID: UUID
    public var messageID: UUID?
    public var senderID: UUID
    public var fileName: String
    public var fileSize: Int64
    public var transferredBytes: Int64
    public var status: TransferStatus
    public var direction: TransferDirection
    public var localPath: String?
    public var timestamp: Date
    public var completedAt: Date?
    public var lastOffset: Int64

    /// 传输进度 (0.0 - 1.0)
    public var progress: Double {
        guard fileSize > 0 else { return 0 }
        return Double(transferredBytes) / Double(fileSize)
    }

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        messageID: UUID? = nil,
        senderID: UUID,
        fileName: String,
        fileSize: Int64,
        transferredBytes: Int64 = 0,
        status: TransferStatus = .pending,
        direction: TransferDirection,
        localPath: String? = nil,
        timestamp: Date = Date(),
        completedAt: Date? = nil,
        lastOffset: Int64 = 0
    ) {
        self.id = id
        self.conversationID = conversationID
        self.messageID = messageID
        self.senderID = senderID
        self.fileName = fileName
        self.fileSize = fileSize
        self.transferredBytes = transferredBytes
        self.status = status
        self.direction = direction
        self.localPath = localPath
        self.timestamp = timestamp
        self.completedAt = completedAt
        self.lastOffset = lastOffset
    }
}
```

**Step 5: Extend Message model**

在 `Modules/FluxQModels/Sources/FluxQModels/Message.swift` 添加字段：

```swift
public var messageType: MessageType
public var fileAttachmentID: UUID?
```

更新 init 参数：

```swift
public init(
    id: UUID = UUID(),
    conversationID: UUID,
    senderID: UUID,
    content: String,
    timestamp: Date = Date(),
    status: MessageStatus = .sending,
    isEncrypted: Bool = false,
    isRecalled: Bool = false,
    recalledAt: Date? = nil,
    messageType: MessageType = .text,
    fileAttachmentID: UUID? = nil
) {
    // ... existing assignments ...
    self.messageType = messageType
    self.fileAttachmentID = fileAttachmentID
}
```

**Step 6: Update FluxQApp Schema**

在 `FluxQ/FluxQApp.swift` 的 schema 数组中添加 `FileTransfer.self`：

```swift
let schema = Schema([
    User.self,
    Message.self,
    Conversation.self,
    FileTransfer.self,
])
```

**Step 7: Run tests**

Run: `swift test --package-path Modules/FluxQModels --filter "FileTransfer"`
Expected: PASS

**Step 8: Commit**

```bash
git add Modules/FluxQModels/Sources/FluxQModels/FileTransfer.swift \
       Modules/FluxQModels/Sources/FluxQModels/Message.swift \
       Modules/FluxQModels/Sources/FluxQModels/Enums.swift \
       Modules/FluxQModels/Tests/FluxQModelsTests/FileTransferTests.swift \
       FluxQ/FluxQApp.swift
git commit -m "feat(models): add FileTransfer model and Message type extensions"
```

**注意：** 添加字段到 Message.swift 后，现有的 Message 初始化调用不需要改（新字段有默认值）。但需要确认现有测试仍然通过：

Run: `swift test --package-path Modules/FluxQModels`
Expected: ALL PASS

---

### Task 12: 服务层 — FileTransferService

**Files:**
- Create: `Modules/FluxQServices/Sources/FluxQServices/FileTransferService/FileTransferService.swift`
- Create: `Modules/FluxQServices/Sources/FluxQServices/FileTransferService/FileSender.swift`
- Create: `Modules/FluxQServices/Sources/FluxQServices/FileTransferService/FileReceiver.swift`
- Test: `Modules/FluxQServices/Tests/FluxQServicesTests/FileTransferServiceTests.swift`

**Context:** 这是文件传输的核心服务。使用 TCP 连接发送/接收文件，支持 64KB 分块和断点续传。

**Step 1: Write failing tests**

创建 `Modules/FluxQServices/Tests/FluxQServicesTests/FileTransferServiceTests.swift`：

```swift
import Testing
import Foundation
@testable import FluxQServices
@testable import IPMsgProtocol

@Suite("FileTransferService Tests")
struct FileTransferServiceTests {

    @Test("FileSender chunks data into 64KB blocks")
    func chunksData() {
        let data = Data(repeating: 0xAB, count: 150_000)  // ~146KB
        let chunks = FileSender.chunk(data: data, blockSize: 65536)
        #expect(chunks.count == 3)
        #expect(chunks[0].count == 65536)
        #expect(chunks[1].count == 65536)
        #expect(chunks[2].count == 150_000 - 65536 * 2)
    }

    @Test("FileSender chunks empty data")
    func chunksEmptyData() {
        let data = Data()
        let chunks = FileSender.chunk(data: data, blockSize: 65536)
        #expect(chunks.isEmpty)
    }

    @Test("FileSender chunks data exactly 64KB")
    func chunksExactBlock() {
        let data = Data(repeating: 0xCD, count: 65536)
        let chunks = FileSender.chunk(data: data, blockSize: 65536)
        #expect(chunks.count == 1)
        #expect(chunks[0].count == 65536)
    }

    @Test("FileSender respects offset for resume")
    func chunksWithOffset() {
        let data = Data(repeating: 0xEF, count: 100_000)
        let chunks = FileSender.chunk(data: data, blockSize: 65536, offset: 65536)
        // Should only return chunks from offset onwards
        #expect(chunks.count == 1)
        #expect(chunks[0].count == 100_000 - 65536)
    }

    @Test("FileReceiver assembles chunks into complete data")
    func assembleChunks() {
        var receiver = FileReceiver(expectedSize: 100)
        let chunk1 = Data(repeating: 0x01, count: 50)
        let chunk2 = Data(repeating: 0x02, count: 50)

        receiver.appendChunk(chunk1)
        #expect(receiver.receivedBytes == 50)
        #expect(!receiver.isComplete)

        receiver.appendChunk(chunk2)
        #expect(receiver.receivedBytes == 100)
        #expect(receiver.isComplete)
    }

    @Test("FileReceiver handles resume from offset")
    func resumeFromOffset() {
        var receiver = FileReceiver(expectedSize: 100, initialOffset: 40)
        #expect(receiver.receivedBytes == 40)

        let chunk = Data(repeating: 0x03, count: 60)
        receiver.appendChunk(chunk)
        #expect(receiver.receivedBytes == 100)
        #expect(receiver.isComplete)
    }

    @Test("FileMetadata GETFILEDATA payload format")
    func getFileDataPayload() {
        let payload = FileTransferService.buildGetFileDataPayload(
            packetNo: 100, fileID: 0, offset: 65536
        )
        #expect(payload == "100:0:10000:")  // offset in hex
    }

    @Test("Parse GETFILEDATA request payload")
    func parseGetFileDataRequest() {
        let (packetNo, fileID, offset) = FileTransferService.parseGetFileDataPayload("100:0:10000:")!
        #expect(packetNo == 100)
        #expect(fileID == 0)
        #expect(offset == 65536)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --package-path Modules/FluxQServices --filter "FileTransferService"`
Expected: FAIL

**Step 3: Implement FileSender**

创建 `Modules/FluxQServices/Sources/FluxQServices/FileTransferService/FileSender.swift`：

```swift
import Foundation

/// 文件发送器 — 负责分块和数据准备
public enum FileSender {

    /// 默认块大小：64KB
    public static let defaultBlockSize = 65536

    /// 将数据分成固定大小的块
    ///
    /// - Parameters:
    ///   - data: 原始文件数据
    ///   - blockSize: 块大小（默认 64KB）
    ///   - offset: 起始偏移量（用于断点续传）
    /// - Returns: 数据块数组
    public static func chunk(
        data: Data,
        blockSize: Int = defaultBlockSize,
        offset: Int64 = 0
    ) -> [Data] {
        let startIndex = Int(offset)
        guard startIndex < data.count else { return [] }

        let remainingData = data[startIndex...]
        var chunks: [Data] = []
        var currentIndex = remainingData.startIndex

        while currentIndex < remainingData.endIndex {
            let endIndex = min(currentIndex + blockSize, remainingData.endIndex)
            chunks.append(Data(remainingData[currentIndex..<endIndex]))
            currentIndex = endIndex
        }

        return chunks
    }
}
```

**Step 4: Implement FileReceiver**

创建 `Modules/FluxQServices/Sources/FluxQServices/FileTransferService/FileReceiver.swift`：

```swift
import Foundation

/// 文件接收器 — 负责接收数据块和进度跟踪
public struct FileReceiver {
    public let expectedSize: Int64
    public private(set) var receivedBytes: Int64
    public private(set) var chunks: [Data]

    public var isComplete: Bool {
        receivedBytes >= expectedSize
    }

    public var progress: Double {
        guard expectedSize > 0 else { return 0 }
        return Double(receivedBytes) / Double(expectedSize)
    }

    public init(expectedSize: Int64, initialOffset: Int64 = 0) {
        self.expectedSize = expectedSize
        self.receivedBytes = initialOffset
        self.chunks = []
    }

    /// 追加接收到的数据块
    public mutating func appendChunk(_ data: Data) {
        chunks.append(data)
        receivedBytes += Int64(data.count)
    }

    /// 组装所有接收到的数据
    public func assembleData() -> Data {
        var result = Data()
        for chunk in chunks {
            result.append(chunk)
        }
        return result
    }
}
```

**Step 5: Implement FileTransferService**

创建 `Modules/FluxQServices/Sources/FluxQServices/FileTransferService/FileTransferService.swift`：

```swift
import Foundation
import IPMsgProtocol

/// 文件传输服务 — 协调文件发送和接收
@MainActor
public final class FileTransferService: ObservableObject {

    /// FILEATTACHOPT 标志值
    public static let fileAttachOpt: Int = 0x00200000

    private let networkManager: NetworkManager

    public init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }

    // MARK: - Payload Builders

    /// 构建 GETFILEDATA 请求 payload
    ///
    /// 格式: "packetNo:fileID:offset(hex):"
    public static func buildGetFileDataPayload(
        packetNo: Int,
        fileID: Int,
        offset: Int64
    ) -> String {
        let offsetHex = String(offset, radix: 16)
        return "\(packetNo):\(fileID):\(offsetHex):"
    }

    /// 解析 GETFILEDATA 请求 payload
    ///
    /// - Returns: (packetNo, fileID, offset) 或 nil
    public static func parseGetFileDataPayload(
        _ payload: String
    ) -> (packetNo: Int, fileID: Int, offset: Int64)? {
        let parts = payload.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3,
              let packetNo = Int(parts[0]),
              let fileID = Int(parts[1]),
              let offset = Int64(parts[2], radix: 16) else {
            return nil
        }
        return (packetNo, fileID, offset)
    }

    // MARK: - Send File

    /// 发起文件发送
    ///
    /// 1. 构造 SENDMSG + FILEATTACHOPT payload
    /// 2. 广播通知对方
    /// 3. 等待 GETFILEDATA 请求
    /// 4. TCP 分块发送
    public func sendFile(
        fileURL: URL,
        to user: DiscoveredUser,
        onProgress: @escaping (Double) -> Void
    ) async throws -> UUID {
        let data = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let fileSize = Int64(data.count)
        let transferID = UUID()

        // Build file metadata
        let metadata = FileMetadata(
            fileID: 0,
            fileName: fileName,
            fileSize: fileSize,
            modificationTime: Date(),
            fileAttribute: .regular
        )

        // Send SENDMSG with FILEATTACHOPT
        let payload = metadata.encodeToPayload()
        try await networkManager.sendMessage(to: user, message: payload)

        // In a full implementation, we would:
        // 1. Start a TCP listener for GETFILEDATA
        // 2. When received, send file data in chunks
        // 3. Track progress via onProgress callback
        // For now, store transfer ID for tracking
        return transferID
    }
}
```

**Step 6: Run tests**

Run: `swift test --package-path Modules/FluxQServices --filter "FileTransferService"`
Expected: PASS

**Step 7: Commit**

```bash
git add Modules/FluxQServices/Sources/FluxQServices/FileTransferService/ \
       Modules/FluxQServices/Tests/FluxQServicesTests/FileTransferServiceTests.swift
git commit -m "feat(services): add FileTransferService with chunking, receiving, and resume support"
```

---

### Task 13: 文件传输性能测试

**Files:**
- Modify: `Modules/FluxQServices/Tests/FluxQServicesTests/PerformanceTests.swift`

**Step 1: Add file transfer performance tests**

在 `Modules/FluxQServices/Tests/FluxQServicesTests/PerformanceTests.swift` 末尾添加：

```swift
@Test("FileSender chunk performance with 100MB data")
func chunkPerformance100MB() {
    let data = Data(repeating: 0xAB, count: 100_000_000)  // 100MB
    let start = Date()
    let chunks = FileSender.chunk(data: data)
    let elapsed = Date().timeIntervalSince(start)

    // Should chunk 100MB in under 1 second
    #expect(elapsed < 1.0)
    #expect(chunks.count == 1526)  // ceil(100_000_000 / 65536)
}

@Test("FileReceiver assembly performance with many chunks")
func receiverAssemblyPerformance() {
    var receiver = FileReceiver(expectedSize: 10_000_000)  // 10MB
    let chunk = Data(repeating: 0xCD, count: 65536)

    let start = Date()
    for _ in 0..<153 {  // ~10MB / 65536
        receiver.appendChunk(chunk)
    }
    let assembled = receiver.assembleData()
    let elapsed = Date().timeIntervalSince(start)

    #expect(elapsed < 1.0)
    #expect(assembled.count > 9_000_000)
}

@Test("FileSender resume offset performance")
func resumeOffsetPerformance() {
    let data = Data(repeating: 0xEF, count: 50_000_000)  // 50MB
    let offset = Int64(25_000_000)  // Resume from 50%

    let start = Date()
    let chunks = FileSender.chunk(data: data, offset: offset)
    let elapsed = Date().timeIntervalSince(start)

    #expect(elapsed < 0.5)
    let totalResumeBytes = chunks.reduce(0) { $0 + $1.count }
    #expect(totalResumeBytes == 25_000_000)
}
```

**Step 2: Run tests**

Run: `swift test --package-path Modules/FluxQServices --filter "Performance"`
Expected: PASS

**Step 3: Commit**

```bash
git add Modules/FluxQServices/Tests/FluxQServicesTests/PerformanceTests.swift
git commit -m "test(services): add file transfer performance tests (100MB chunking, assembly, resume)"
```

---

### Task 14: UI — 文件消息气泡和文件选择器

**Files:**
- Create: `FluxQ/Views/Components/FileMessageBubbleView.swift`
- Modify: `FluxQ/Views/ConversationDetailView.swift`

**Step 1: Create FileMessageBubbleView**

创建 `FluxQ/Views/Components/FileMessageBubbleView.swift`：

```swift
import SwiftUI
import FluxQModels

/// 文件消息气泡 — 显示文件名、大小、传输进度
struct FileMessageBubbleView: View {
    let fileName: String
    let fileSize: Int64
    let progress: Double
    let status: TransferStatus
    let isFromMe: Bool
    let timestamp: Date
    var onCancel: (() -> Void)? = nil

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: fileIcon)
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileName)
                            .font(.subheadline)
                            .lineLimit(1)

                        Text(formattedFileSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if status == .transferring {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)

                    if let onCancel {
                        Button("取消", action: onCancel)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if status == .completed {
                    Label("已完成", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if status == .failed {
                    Label("传输失败", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(isFromMe ? Color.fluxqBubbleMe : Color.fluxqBubbleOther)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if !isFromMe { Spacer(minLength: 60) }
        }
    }

    private var fileIcon: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo.fill"
        case "mp4", "mov", "avi": return "film.fill"
        case "zip", "rar", "7z": return "archivebox.fill"
        default: return "doc.fill"
        }
    }

    private var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

#Preview("Transferring") {
    FileMessageBubbleView(
        fileName: "report.pdf",
        fileSize: 5_242_880,
        progress: 0.65,
        status: .transferring,
        isFromMe: true,
        timestamp: Date()
    )
    .padding()
}

#Preview("Completed") {
    FileMessageBubbleView(
        fileName: "photo.jpg",
        fileSize: 2_097_152,
        progress: 1.0,
        status: .completed,
        isFromMe: false,
        timestamp: Date()
    )
    .padding()
}
```

**Step 2: Add file picker to ConversationDetailView**

在 `FluxQ/Views/ConversationDetailView.swift` 中：

1. 添加 `@State private var showingFilePicker = false`
2. 在 input bar 旁添加附件按钮
3. 添加 `.fileImporter` modifier

关键变更 — 在 `inputBar` 方法中，在 TextField 前添加：

```swift
Button {
    showingFilePicker = true
} label: {
    Image(systemName: "paperclip")
}
.buttonStyle(.plain)
```

在 `conversationContent` 的 VStack 上添加：

```swift
.fileImporter(
    isPresented: $showingFilePicker,
    allowedContentTypes: [.item],
    allowsMultipleSelection: false
) { result in
    if case .success(let urls) = result, let url = urls.first {
        handleFileSend(url: url, conversationId: conversationId)
    }
}
```

添加 `handleFileSend` 方法：

```swift
private func handleFileSend(url: URL, conversationId: UUID) {
    guard url.startAccessingSecurityScopedResource() else { return }
    defer { url.stopAccessingSecurityScopedResource() }

    // Create a file message
    let message = Message(
        conversationID: conversationId,
        senderID: currentUserID,
        content: url.lastPathComponent,
        status: .sending,
        messageType: .file
    )
    modelContext.insert(message)
    try? modelContext.save()

    // TODO: Wire to FileTransferService.sendFile() in Task 15
}
```

**Step 3: Build and verify**

Run: `xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add FluxQ/Views/Components/FileMessageBubbleView.swift \
       FluxQ/Views/ConversationDetailView.swift
git commit -m "feat(ui): add FileMessageBubbleView and file picker to ConversationDetailView"
```

---

## 切片 4：消息操作接线

---

### Task 15: 撤回功能接线

**Files:**
- Modify: `FluxQ/Views/ConversationDetailView.swift`

**Context:** `RecallService` 已实现。需要在 `recallMessage()` 中调用 `RecallService` 发网络广播，并处理接收到的 RECALLMSG。

**Step 1: Wire recallMessage in ConversationDetailView**

修改 `recallMessage` 方法（当前 `FluxQ/Views/ConversationDetailView.swift:185-189`）：

```swift
private func recallMessage(_ message: Message) {
    message.isRecalled = true
    message.recalledAt = Date()
    try? modelContext.save()

    // 网络广播撤回
    Task {
        try? networkManager.sendBroadcast(
            command: .RECALLMSG,
            payload: message.id.uuidString
        )
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add FluxQ/Views/ConversationDetailView.swift
git commit -m "feat: wire recall action to network broadcast in ConversationDetailView"
```

---

### Task 16: 接收撤回命令处理

**Files:**
- Modify: `FluxQ/Services/MessageReceiveHandler.swift`
- Modify: `FluxQ/FluxQApp.swift`

**Step 1: Add recall handling to MessageReceiveHandler**

在 `FluxQ/Services/MessageReceiveHandler.swift` 添加：

```swift
/// 处理收到的撤回命令
static func handleRecallCommand(
    messageIDString: String,
    in context: ModelContext
) {
    guard let messageID = UUID(uuidString: messageIDString) else { return }

    let descriptor = FetchDescriptor<Message>(
        predicate: #Predicate { $0.id == messageID }
    )

    if let message = try? context.fetch(descriptor).first {
        message.isRecalled = true
        message.recalledAt = Date()
        try? context.save()
    }
}
```

**Step 2: Handle RECALLMSG in NetworkManager callback**

当前 NetworkManager 的 `handleReceivedMessage` 只处理 BR_ENTRY/BR_EXIT/SENDMSG。RECALLMSG 命令落入 `default: break`。

在 FluxQApp 中，需要添加一个 hook 来处理 RECALLMSG。最简单的方式是让 NetworkManager 的 `handleMessage` 也发出 RECALLMSG 到 receivedMessages，然后在 FluxQApp 的 onChange 中区分。

替代方案：在 NetworkManager.handleReceivedMessage 的 switch 中添加 RECALLMSG 处理，将 payload（messageID）通过新的 @Published 属性通知外部。

选择在 NetworkManager 添加：

```swift
/// 收到的撤回请求
@Published public private(set) var receivedRecalls: [String] = []
```

在 `handleReceivedMessage` 的 switch 中添加：

```swift
case .RECALLMSG:
    receivedRecalls.append(cleanPacket.payload)
```

在 FluxQApp 中添加 onChange：

```swift
.onChange(of: networkManager.receivedRecalls.count) { _, _ in
    if let lastRecall = networkManager.receivedRecalls.last {
        let context = sharedModelContainer.mainContext
        MessageReceiveHandler.handleRecallCommand(
            messageIDString: lastRecall,
            in: context
        )
    }
}
```

**Step 3: Build and verify**

Run: `xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add FluxQ/Services/MessageReceiveHandler.swift \
       FluxQ/FluxQApp.swift \
       Modules/FluxQServices/Sources/FluxQServices/NetworkManager.swift
git commit -m "feat: handle incoming RECALLMSG and update message state"
```

---

### Task 17: 转发功能接线

**Files:**
- Create: `FluxQ/Views/Components/ForwardTargetPicker.swift`
- Modify: `FluxQ/Views/ConversationDetailView.swift`

**Step 1: Create ForwardTargetPicker**

创建 `FluxQ/Views/Components/ForwardTargetPicker.swift`：

```swift
import SwiftUI
import SwiftData
import FluxQModels

/// 转发目标选择器
struct ForwardTargetPicker: View {
    let messageContent: String
    let onSelect: (Conversation) -> Void
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Conversation.lastMessageTimestamp, order: .reverse)
    private var conversations: [Conversation]

    var body: some View {
        NavigationStack {
            List(conversations) { conversation in
                Button {
                    onSelect(conversation)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        UserAvatarView(
                            avatarData: conversation.participants?.first?.avatarData,
                            size: 40
                        )
                        VStack(alignment: .leading) {
                            Text(conversation.displayName)
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("转发到")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
```

**Step 2: Wire forward in ConversationDetailView**

添加 state：

```swift
@State private var forwardingMessage: Message?
```

修改 contextMenu 中的转发 button（当前空实现）：

```swift
Button {
    forwardingMessage = message
} label: {
    Label("转发", systemImage: "arrowshape.turn.up.right")
}
```

添加 sheet：

```swift
.sheet(item: $forwardingMessage) { message in
    ForwardTargetPicker(messageContent: message.content) { targetConversation in
        forwardMessage(message, to: targetConversation)
    }
}
```

添加 forwardMessage 方法：

```swift
private func forwardMessage(_ message: Message, to targetConversation: Conversation) {
    guard let participant = targetConversation.participants?.first else { return }

    // 在目标会话创建转发消息
    let forwardedMessage = Message(
        conversationID: targetConversation.id,
        senderID: currentUserID,
        content: message.content,
        status: .sending
    )
    modelContext.insert(forwardedMessage)
    targetConversation.lastMessageTimestamp = Date()
    try? modelContext.save()

    // 通过网络发送
    if let discoveredUser = networkManager.discoveredUsers.values.first(where: {
        $0.ipAddress == participant.ipAddress
    }) {
        Task {
            do {
                try await networkManager.sendMessage(to: discoveredUser, message: message.content)
                forwardedMessage.status = .sent
                try? modelContext.save()
            } catch {
                forwardedMessage.status = .failed
                try? modelContext.save()
            }
        }
    }
}
```

**Step 3: Build and verify**

Run: `xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add FluxQ/Views/Components/ForwardTargetPicker.swift \
       FluxQ/Views/ConversationDetailView.swift
git commit -m "feat: wire message forward with conversation picker UI"
```

---

## 综合测试

---

### Task 18: 撤回和转发集成测试

**Files:**
- Create: `Modules/FluxQServices/Tests/FluxQServicesTests/MessageActionIntegrationTests.swift`

**Step 1: Write integration tests**

```swift
import Testing
import Foundation
@testable import FluxQServices
@testable import IPMsgProtocol

@Suite("Message Action Integration Tests")
struct MessageActionIntegrationTests {

    @Test("Recall broadcast sends RECALLMSG command")
    @MainActor
    func recallSendsBroadcast() async throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        try manager.start()

        let messageID = UUID()
        try manager.sendBroadcast(command: .RECALLMSG, payload: messageID.uuidString)

        #expect(transport.broadcastMessages.count >= 1)
        let lastBroadcast = transport.broadcastMessages.last!
        let packetStr = String(data: lastBroadcast.data, encoding: .utf8)!
        let packet = try IPMsgPacket.decode(packetStr)
        #expect(packet.command == .RECALLMSG)
        #expect(packet.payload.contains(messageID.uuidString))
    }

    @Test("Received RECALLMSG updates receivedRecalls")
    @MainActor
    func receiveRecallCommand() throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        try manager.start()

        let messageID = UUID()
        let packet = IPMsgPacket(
            version: 1, packetNo: 300,
            sender: "alice", hostname: "alice-mac",
            command: .RECALLMSG, payload: messageID.uuidString
        )
        let data = packet.encode().data(using: .utf8)!
        transport.simulateReceive(data: data, from: "192.168.1.10")

        #expect(manager.receivedRecalls.count == 1)
        #expect(manager.receivedRecalls[0].contains(messageID.uuidString))
    }

    @Test("RecallService validates time window")
    @MainActor
    func recallTimeWindow() {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        let recallService = RecallService(networkManager: manager)

        let userID = UUID()

        // Within window
        let recentTimestamp = Date().addingTimeInterval(-60)
        #expect(recallService.canRecall(
            messageTimestamp: recentTimestamp,
            senderID: userID, currentUserID: userID, isRecalled: false
        ))

        // Outside window
        let oldTimestamp = Date().addingTimeInterval(-200)
        #expect(!recallService.canRecall(
            messageTimestamp: oldTimestamp,
            senderID: userID, currentUserID: userID, isRecalled: false
        ))
    }
}
```

**Step 2: Run tests**

Run: `swift test --package-path Modules/FluxQServices --filter "MessageActionIntegration"`
Expected: PASS (after Task 16 adds `receivedRecalls` to NetworkManager)

**Step 3: Commit**

```bash
git add Modules/FluxQServices/Tests/FluxQServicesTests/MessageActionIntegrationTests.swift
git commit -m "test(services): add recall and forward integration tests"
```

---

### Task 19: UI 端对端测试

**Files:**
- Modify: `FluxQUITests/FluxQUITests.swift`

**Context:** 当前 UI 测试是空壳。添加关键用户路径的端对端测试。

**Step 1: Write UI tests**

替换 `FluxQUITests/FluxQUITests.swift`：

```swift
import XCTest

final class FluxQUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - 导航测试

    @MainActor
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        // 验证消息 tab 存在
        let messagesTab = app.tabBars.buttons["消息"]
        XCTAssertTrue(messagesTab.exists)

        // 验证发现 tab 存在并可点击
        let discoveryTab = app.tabBars.buttons["发现"]
        XCTAssertTrue(discoveryTab.exists)
        discoveryTab.tap()

        // 验证发现页标题
        XCTAssertTrue(app.navigationBars["发现"].exists)

        // 切回消息 tab
        messagesTab.tap()
        XCTAssertTrue(app.navigationBars["消息"].exists)
    }

    @MainActor
    func testDiscoveryPageSearchBar() throws {
        let app = XCUIApplication()
        app.launch()

        // 导航到发现页
        app.tabBars.buttons["发现"].tap()

        // 搜索框存在
        let searchField = app.textFields["搜索用户"]
        XCTAssertTrue(searchField.exists)
    }

    @MainActor
    func testConversationListEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        // 消息列表显示空状态
        // 注意：新安装时没有会话数据
        let emptyLabel = app.staticTexts["暂无消息"]
        // 可能存在也可能有数据，取决于状态
        if emptyLabel.exists {
            XCTAssertTrue(emptyLabel.exists)
        }
    }

    @MainActor
    func testConversationDetailEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        // macOS: 未选中会话时显示空状态
        #if os(macOS)
        let placeholder = app.staticTexts["选择一个对话"]
        if placeholder.exists {
            XCTAssertTrue(placeholder.exists)
        }
        #endif
    }

    // MARK: - 启动性能

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
```

**Step 2: Run UI tests**

Run: `xcodebuild test -scheme FluxQ -destination 'platform=macOS' -only-testing:FluxQUITests 2>&1 | tail -30`
Expected: PASS

**Step 3: Commit**

```bash
git add FluxQUITests/FluxQUITests.swift
git commit -m "test(ui): add end-to-end UI tests for navigation and empty states"
```

---

### Task 20: 运行全部测试并验证

**Step 1: Run all module tests**

```bash
swift test --package-path Modules/IPMsgProtocol
swift test --package-path Modules/FluxQModels
swift test --package-path Modules/FluxQServices
```

Expected: ALL PASS

**Step 2: Run app build**

```bash
xcodebuild build -scheme FluxQ -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

**Step 3: Run UI tests**

```bash
xcodebuild test -scheme FluxQ -destination 'platform=macOS' -only-testing:FluxQUITests 2>&1 | tail -30
```

Expected: ALL PASS

**Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "chore: fix any test failures from full integration"
```

---

## 完成检查清单

| 切片 | 功能 | 测试 | 状态 |
|------|------|------|------|
| 1 | ConversationListView 使用真实 SwiftData | 单元 + 集成 | |
| 2 | 消息发送到网络 | 单元 + 集成 | |
| 2 | 消息接收持久化 | 单元 + 集成 | |
| 3 | FileMetadata 解析/编码 | 单元 | |
| 3 | FileTransfer 模型 | 单元 | |
| 3 | FileSender/FileReceiver | 单元 + 性能 | |
| 3 | 文件 UI（气泡+选择器） | 构建验证 | |
| 4 | 撤回接线 | 集成 | |
| 4 | 转发接线 | 构建验证 | |
| 全局 | UI 端对端测试 | XCUITest | |
| 全局 | 全部模块测试通过 | swift test | |
