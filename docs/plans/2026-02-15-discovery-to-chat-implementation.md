# Discovery-to-Chat Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable tapping a discovered LAN user in DiscoveryView to create/find a conversation and navigate directly into the chat interface, across all three platforms (iPhone, iPad, macOS).

**Architecture:** ConversationService (find-or-create conversation logic) + StartChatAction (SwiftUI Environment Action for cross-tab navigation). ConversationService lives in the app layer (`FluxQ/Services/`) because it depends on SwiftData ModelContext. StartChatAction lives in `FluxQ/Navigation/`.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing

**Design doc:** `docs/plans/2026-02-15-discovery-to-chat-design.md`

---

### Task 1: Create StartChatAction Environment Action

**Files:**
- Create: `FluxQ/Navigation/StartChatAction.swift`

**Step 1: Create the file**

```swift
import SwiftUI

struct StartChatAction {
    let handler: (UUID) -> Void

    func callAsFunction(_ conversationId: UUID) {
        handler(conversationId)
    }
}

private struct StartChatActionKey: EnvironmentKey {
    static let defaultValue = StartChatAction { _ in }
}

extension EnvironmentValues {
    var startChat: StartChatAction {
        get { self[StartChatActionKey.self] }
        set { self[StartChatActionKey.self] = newValue }
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild -scheme FluxQ -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add FluxQ/Navigation/StartChatAction.swift
git commit -m "feat: add StartChatAction environment action for cross-tab navigation"
```

---

### Task 2: Create ConversationService — write failing tests

ConversationService lives in the app layer and depends on SwiftData. Since app-layer code doesn't have a separate test target, we'll add a lightweight test file under a new `FluxQTests/` directory or test inline. However, SwiftData @Model tests are tricky without a host app. Instead, we'll write the tests in `Modules/FluxQModels/Tests/` since that module already has SwiftData test infrastructure.

**Important context:**
- `discoveredUsers` in NetworkManager is `[String: DiscoveredUser]` where key = `packet.sender` (the senderName)
- `DiscoveredUser.toUser()` creates a new User preserving the same `id`
- `SearchFilterService.filterUsers()` takes `[User]` and returns `[User]`
- DiscoveryView currently does: `networkManager.discoveredUsers.values.map { $0.toUser() }` then filters
- We need the original `DiscoveredUser` in tap handler — look up by matching `user.id` against `discoveredUsers.values`

**Files:**
- Create: `FluxQ/Services/ConversationService.swift`
- Create: `Modules/FluxQModels/Tests/FluxQModelsTests/ConversationServiceTests.swift`

**Step 1: Write the failing tests**

Create `Modules/FluxQModels/Tests/FluxQModelsTests/ConversationServiceTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("ConversationService Tests")
struct ConversationServiceTests {

    /// Helper: create an in-memory ModelContainer for testing
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self,
            configurations: config
        )
    }

    @Test("Creates new User and Conversation when none exist")
    func createNewUserAndConversation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let result = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        // Should return a valid conversation ID
        #expect(result != nil)

        // User should be persisted
        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
        #expect(users[0].hostname == "testhost")
        #expect(users[0].nickname == "Alice")

        // Conversation should be created
        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
        #expect(conversations[0].type == .private)
        #expect(conversations[0].participantIDs.contains(users[0].id))
    }

    @Test("Reuses existing User when hostname + ipAddress match")
    func reuseExistingUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Pre-insert a user
        let existingUser = User(
            nickname: "Alice",
            hostname: "testhost",
            ipAddress: "192.168.1.10"
        )
        context.insert(existingUser)
        try context.save()

        let result = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice Updated",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        #expect(result != nil)

        // Should NOT create a duplicate user
        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
        #expect(users[0].id == existingUser.id)
    }

    @Test("Reuses existing Conversation with same user")
    func reuseExistingConversation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Pre-insert user and conversation
        let existingUser = User(
            nickname: "Alice",
            hostname: "testhost",
            ipAddress: "192.168.1.10"
        )
        context.insert(existingUser)

        let existingConv = Conversation(
            type: .private,
            participantIDs: [existingUser.id],
            lastMessageTimestamp: Date.distantPast
        )
        context.insert(existingConv)
        try context.save()

        let result = ConversationService.findOrCreateConversation(
            hostname: "testhost",
            senderName: "alice",
            nickname: "Alice",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            in: context
        )

        // Should return the existing conversation
        #expect(result == existingConv.id)

        // Should NOT create a new conversation
        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)

        // Should update lastMessageTimestamp to bring it to top
        #expect(conversations[0].lastMessageTimestamp > Date.distantPast)
    }

    @Test("Creates new Conversation when existing user has no private conversation")
    func createConversationForExistingUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Pre-insert user without any conversation
        let existingUser = User(
            nickname: "Bob",
            hostname: "bobhost",
            ipAddress: "192.168.1.20"
        )
        context.insert(existingUser)
        try context.save()

        let result = ConversationService.findOrCreateConversation(
            hostname: "bobhost",
            senderName: "bob",
            nickname: "Bob",
            ipAddress: "192.168.1.20",
            port: 2425,
            group: nil,
            in: context
        )

        #expect(result != nil)

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
        #expect(conversations[0].participantIDs.contains(existingUser.id))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --package-path Modules/FluxQModels 2>&1 | tail -20`
Expected: FAIL — `ConversationService` does not exist yet

**Step 3: Commit failing tests**

```bash
git add Modules/FluxQModels/Tests/FluxQModelsTests/ConversationServiceTests.swift
git commit -m "test: add failing ConversationService tests"
```

---

### Task 3: Implement ConversationService

**Files:**
- Create: `FluxQ/Services/ConversationService.swift`

**Step 1: Implement ConversationService**

```swift
import Foundation
import SwiftData
import FluxQModels

enum ConversationService {

    /// Find an existing 1:1 conversation with the user, or create a new one.
    ///
    /// Matching logic:
    /// 1. Find User by hostname + ipAddress (stable identifiers on LAN)
    /// 2. If not found, create and persist a new User
    /// 3. Find existing private Conversation whose participantIDs contains the user
    /// 4. If found, update lastMessageTimestamp (to sort it to top) and return its ID
    /// 5. If not found, create a new Conversation and return its ID
    @discardableResult
    static func findOrCreateConversation(
        hostname: String,
        senderName: String,
        nickname: String,
        ipAddress: String,
        port: Int,
        group: String?,
        in context: ModelContext
    ) -> UUID {
        // Step 1: Find or create User
        let user = findOrCreateUser(
            hostname: hostname,
            nickname: nickname,
            ipAddress: ipAddress,
            port: port,
            group: group,
            in: context
        )

        // Step 2: Find or create Conversation
        let conversationId = findOrCreatePrivateConversation(
            with: user,
            in: context
        )

        try? context.save()
        return conversationId
    }

    private static func findOrCreateUser(
        hostname: String,
        nickname: String,
        ipAddress: String,
        port: Int,
        group: String?,
        in context: ModelContext
    ) -> User {
        // Match by hostname + ipAddress
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate {
                $0.hostname == hostname && $0.ipAddress == ipAddress
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            // Update mutable fields
            existing.nickname = nickname
            existing.isOnline = true
            existing.lastSeen = Date()
            return existing
        }

        let newUser = User(
            nickname: nickname,
            hostname: hostname,
            ipAddress: ipAddress,
            port: port,
            group: group,
            status: .online,
            isOnline: true
        )
        context.insert(newUser)
        return newUser
    }

    private static func findOrCreatePrivateConversation(
        with user: User,
        in context: ModelContext
    ) -> UUID {
        let userId = user.id
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate {
                $0.type == .private && $0.participantIDs.contains(userId)
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.lastMessageTimestamp = Date()
            return existing.id
        }

        let conversation = Conversation(
            type: .private,
            participantIDs: [user.id]
        )
        context.insert(conversation)
        return conversation.id
    }
}
```

**Step 2: The tests reference `ConversationService` but it's in the app target, not the FluxQModels module. Move the tests to reference it correctly.**

Since ConversationService is in the app layer and tests are in FluxQModels, we have two options:
- Option A: Make ConversationService a standalone file that can be compiled in both targets
- Option B: Duplicate the core logic as a helper in the test

**Chosen approach:** Move ConversationService into `Modules/FluxQModels/Sources/FluxQModels/` so tests can access it directly. This is acceptable because ConversationService only depends on SwiftData + FluxQModels types. The app layer will import it through FluxQModels.

Wait — ConversationService needs `FluxQModels` types but lives conceptually in the app layer. However, since it only uses `User`, `Conversation`, `ConversationType` from FluxQModels and `SwiftData`, placing it in FluxQModels keeps things testable.

**Revised location:** `Modules/FluxQModels/Sources/FluxQModels/ConversationService.swift`

Create the file at the revised location with the code above, adding `public` access modifiers.

**Step 3: Run tests**

Run: `swift test --package-path Modules/FluxQModels 2>&1 | tail -20`
Expected: All 4 ConversationService tests PASS

**Step 4: Commit**

```bash
git add Modules/FluxQModels/Sources/FluxQModels/ConversationService.swift
git commit -m "feat: implement ConversationService for find-or-create conversation logic"
```

---

### Task 4: Wire up DiscoveryView tap handler

**Files:**
- Modify: `FluxQ/Views/DiscoveryView.swift:93-127`

**Context:**
- `networkManager.discoveredUsers` is `[String: DiscoveredUser]` (key = senderName)
- `filteredUsers` is `[User]` created via `discoveredUsers.values.map { $0.toUser() }`
- `DiscoveredUser.toUser()` preserves the same `.id`, so we can look up the original DiscoveredUser by matching `user.id`

**Step 1: Add environment properties and modify list**

Add these properties to `DiscoveryView`:

```swift
@Environment(\.modelContext) private var modelContext
@Environment(\.startChat) private var startChat
```

Change the `List` section (currently lines 94-127) from:

```swift
List(filteredUsers) { user in
    HStack(spacing: 12) {
        // ... row content
    }
    .padding(.vertical, 4)
}
.listStyle(.plain)
```

To:

```swift
List(filteredUsers) { user in
    Button {
        handleUserTap(user)
    } label: {
        HStack(spacing: 12) {
            UserAvatarView(avatarData: user.avatarData, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.nickname)
                    .font(.headline)

                HStack {
                    Text(user.hostname)
                    Text("·")
                    Text(user.ipAddress)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let group = user.group {
                    Text(group)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if user.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
}
.listStyle(.plain)
```

Add the tap handler method:

```swift
private func handleUserTap(_ user: User) {
    // Look up the original DiscoveredUser by matching id
    guard let discoveredUser = networkManager.discoveredUsers.values.first(where: { $0.id == user.id }) else {
        return
    }

    let conversationId = ConversationService.findOrCreateConversation(
        hostname: discoveredUser.hostname,
        senderName: discoveredUser.senderName,
        nickname: discoveredUser.nickname,
        ipAddress: discoveredUser.ipAddress,
        port: discoveredUser.port,
        group: discoveredUser.group,
        in: modelContext
    )

    startChat(conversationId)
}
```

Add import at top of file:

```swift
import SwiftData
```

(FluxQModels is already imported, and ConversationService is now in FluxQModels.)

**Step 2: Verify it compiles**

Run: `xcodebuild -scheme FluxQ -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add FluxQ/Views/DiscoveryView.swift
git commit -m "feat: add tap handler to DiscoveryView for starting chats"
```

---

### Task 5: Wire up MainTabView for iPhone

**Files:**
- Modify: `FluxQ/iOS/MainTabView.swift`

**Step 1: Add tab selection state, tags, and StartChatAction**

Replace the entire `MainTabView` body:

```swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppNavigationItem = .messages
    @State private var activeConversationId: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationListView(activeConversationId: $activeConversationId)
                .tabItem {
                    Label("消息", systemImage: "message.fill")
                }
                .tag(AppNavigationItem.messages)

            ContactsView()
                .tabItem {
                    Label("通讯录", systemImage: "person.2.fill")
                }
                .tag(AppNavigationItem.contacts)

            DiscoveryView()
                .tabItem {
                    Label("发现", systemImage: "globe")
                }
                .tag(AppNavigationItem.discovery)

            SettingsView()
                .tabItem {
                    Label("我", systemImage: "person.fill")
                }
                .tag(AppNavigationItem.settings)
        }
        .environment(\.startChat, StartChatAction { conversationId in
            activeConversationId = conversationId
            selectedTab = .messages
        })
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild -scheme FluxQ -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (or compile errors from ConversationListView not yet accepting `activeConversationId` — that's Task 6)

**Step 3: Commit**

```bash
git add FluxQ/iOS/MainTabView.swift
git commit -m "feat: add tab selection and StartChatAction to MainTabView"
```

---

### Task 6: Update ConversationListView for programmatic navigation

**Files:**
- Modify: `FluxQ/Views/ConversationListView.swift`

**Context:**
- Current init: `@Binding var selection: UUID?` + backward-compat `init()` that sets selection to `.constant(nil)`
- macOS/iPad use `selection:` parameter
- iPhone needs `activeConversationId:` parameter + NavigationStack(path:)
- Must keep both init paths working

**Step 1: Add activeConversationId binding and NavigationStack**

Replace the `ConversationListView` struct with:

```swift
struct ConversationListView: View {
    /// macOS/iPad: selection binding for multi-column layout
    @Binding var selection: UUID?

    /// iPhone: programmatic navigation target
    @Binding var activeConversationId: UUID?

    #if os(iOS)
    @Environment(\.deviceCategory) private var deviceCategory
    #endif

    @State private var navigationPath = NavigationPath()
    @State private var sampleConversations: [SampleConversation] = SampleConversation.examples

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List(selection: $selection) {
                if sampleConversations.isEmpty {
                    ContentUnavailableView {
                        Label("暂无消息", systemImage: "message.fill")
                    } description: {
                        Text("开始一个新的对话")
                    }
                } else {
                    ForEach(sampleConversations) { conversation in
                        #if os(iOS)
                        conversationRowWithSwipe(conversation)
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

    // ... keep all existing private methods unchanged (conversationRow, conversationRowWithSwipe, toggleRead, deleteConversation, pinConversation)
}
```

**Step 2: Update the backward-compatible inits**

Replace the existing extension with:

```swift
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
```

**Step 3: Verify it compiles**

Run: `xcodebuild -scheme FluxQ -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add FluxQ/Views/ConversationListView.swift
git commit -m "feat: add NavigationStack and activeConversationId to ConversationListView"
```

---

### Task 7: Wire up MacMainView and iPad views

**Files:**
- Modify: `FluxQ/macOS/MacMainView.swift:27-48`
- Modify: `FluxQ/iOS/iOSAdaptiveView.swift:24-47`
- Modify: `FluxQ/iOS/iPadSplitView.swift:9-20`

**Step 1: MacMainView — inject StartChatAction**

In `MacMainView`, add `.environment(\.startChat, ...)` to the Group. Replace lines 27-48:

```swift
var body: some View {
    Group {
        if needsContentColumn {
            NavigationSplitView {
                SidebarView(selection: $selectedTab)
            } content: {
                contentColumn
            } detail: {
                detailColumn
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationSplitView {
                SidebarView(selection: $selectedTab)
            } detail: {
                detailColumn
            }
            .navigationSplitViewStyle(.balanced)
        }
    }
    .focusedSceneValue(\.selectedTab, $selectedTab)
    .environment(\.startChat, StartChatAction { conversationId in
        selectedTab = .messages
        selectedConversation = conversationId
    })
}
```

**Step 2: iOSAdaptiveView — inject StartChatAction for iPad path**

In `iOSAdaptiveView`, the iPad horizontal path uses `iPadSplitView`. The state is owned by `iOSAdaptiveView`. Add StartChatAction injection.

Replace the `body` in `iOSAdaptiveView` (lines 24-47):

```swift
var body: some View {
    Group {
        if shouldUseMultiColumn {
            iPadSplitView(
                selectedTab: selectedTab,
                selectedConversation: $selectedConversation,
                selectedContact: $selectedContact
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .environment(\.startChat, StartChatAction { conversationId in
                selectedTabRawValue = AppNavigationItem.messages.rawValue
                selectedConversation = conversationId
            })
        } else {
            iPhoneOptimizedView()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        }
    }
    .animation(.easeInOut(duration: 0.35), value: shouldUseMultiColumn)
}
```

Note: iPhone path does NOT inject StartChatAction here — `MainTabView` handles it internally.

**Step 3: Verify all platforms compile**

Run: `xcodebuild -scheme FluxQ -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add FluxQ/macOS/MacMainView.swift FluxQ/iOS/iOSAdaptiveView.swift
git commit -m "feat: inject StartChatAction in MacMainView and iPad adaptive view"
```

---

### Task 8: Run all tests and verify

**Step 1: Run FluxQModels tests (includes ConversationService tests)**

Run: `swift test --package-path Modules/FluxQModels 2>&1 | tail -20`
Expected: All tests PASS

**Step 2: Run all module tests**

Run: `swift test --package-path Modules/FluxQServices 2>&1 | tail -20`
Expected: All tests PASS

**Step 3: Full build for all platforms**

Run: `xcodebuild -scheme FluxQ -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: resolve any compilation issues from integration"
```
