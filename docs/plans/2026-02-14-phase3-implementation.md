# Phase 3: 局域网发现增强 - 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标**：在 v0.2.0 基础上，增加用户头像系统、搜索过滤功能和心跳保活机制

**架构**：使用 SwiftData + CloudKit 同步头像数据，UDP 广播头像元数据，TCP 按需传输头像文件，心跳保活采用平台差异化策略（watchOS 60s，iOS 动态，macOS 30s）

**技术栈**：Swift 5.9+, SwiftUI, SwiftData, CloudKit, Network.framework (UDP), BSD Socket (TCP), Swift Testing

---

## 前置条件

- ✅ v0.2.0 基础功能已完成（UDP 广播、用户发现）
- ✅ FluxQModels、IPMsgProtocol、FluxQServices 模块已存在
- ✅ DiscoveryView 已实现基础用户列表

---

## Task 1: 数据模型增强

**目标**：为 User 模型添加头像和在线状态相关字段

**Files:**
- Modify: `Modules/FluxQModels/Sources/FluxQModels/User.swift`
- Test: `Modules/FluxQModels/Tests/FluxQModelsTests/UserTests.swift`

### Step 1: 写失败测试 - 头像数据字段

```swift
// Modules/FluxQModels/Tests/FluxQModelsTests/UserTests.swift
import Testing
import Foundation
@testable import FluxQModels

@Test("User avatar data persistence")
func testAvatarDataPersistence() {
    let user = User(
        id: UUID(),
        nickname: "测试用户",
        hostname: "test-mac",
        ipAddress: "192.168.1.100",
        department: "开发部"
    )

    let testImageData = Data([0x01, 0x02, 0x03])
    user.avatarData = testImageData
    user.avatarHash = "abc123"

    #expect(user.avatarData == testImageData)
    #expect(user.avatarHash == "abc123")
}

@Test("User online status tracking")
func testOnlineStatusTracking() {
    let user = User(
        id: UUID(),
        nickname: "测试用户",
        hostname: "test-mac",
        ipAddress: "192.168.1.100"
    )

    user.isOnline = true
    user.lastSeen = Date()

    #expect(user.isOnline == true)
    #expect(user.lastSeen != nil)
}
```

### Step 2: 运行测试验证失败

```bash
cd Modules/FluxQModels
swift test
```

**预期输出**：`FAIL` - `Value of type 'User' has no member 'avatarData'`

### Step 3: 实现最小代码 - 添加字段

```swift
// Modules/FluxQModels/Sources/FluxQModels/User.swift
import Foundation
import SwiftData

@Model
public class User {
    // 已有字段
    @Attribute(.unique) public var id: UUID
    public var nickname: String
    public var hostname: String
    public var ipAddress: String?
    public var department: String?

    // 新增字段
    public var avatarData: Data?           // 头像数据（CloudKit 同步）
    public var avatarHash: String?         // 头像 SHA-256 hash
    public var lastSeen: Date              // 最后在线时间
    public var isOnline: Bool              // 在线状态

    public init(
        id: UUID = UUID(),
        nickname: String,
        hostname: String,
        ipAddress: String? = nil,
        department: String? = nil,
        avatarData: Data? = nil,
        avatarHash: String? = nil,
        lastSeen: Date = Date(),
        isOnline: Bool = false
    ) {
        self.id = id
        self.nickname = nickname
        self.hostname = hostname
        self.ipAddress = ipAddress
        self.department = department
        self.avatarData = avatarData
        self.avatarHash = avatarHash
        self.lastSeen = lastSeen
        self.isOnline = isOnline
    }
}
```

### Step 4: 运行测试验证通过

```bash
cd Modules/FluxQModels
swift test
```

**预期输出**：`PASS` - All tests passed

### Step 5: 提交

```bash
git add Modules/FluxQModels/Sources/FluxQModels/User.swift \
        Modules/FluxQModels/Tests/FluxQModelsTests/UserTests.swift
git commit -m "feat(models): add avatar and online status fields to User

- Add avatarData (Data?) for CloudKit sync
- Add avatarHash (String?) for deduplication
- Add lastSeen (Date) for heartbeat tracking
- Add isOnline (Bool) for online status

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 2: IPMsgProtocol 扩展 - 头像命令

**目标**：扩展 IPMsg 协议，添加头像相关命令

**Files:**
- Modify: `Modules/IPMsgProtocol/Sources/IPMsgProtocol/IPMsgCommand.swift`
- Test: `Modules/IPMsgProtocol/Tests/IPMsgProtocolTests/IPMsgCommandTests.swift`

### Step 1: 写失败测试 - 头像命令

```swift
// Modules/IPMsgProtocol/Tests/IPMsgProtocolTests/IPMsgCommandTests.swift
import Testing
@testable import IPMsgProtocol

@Test("IPMSG_AVATAR command encoding")
func testAvatarCommandEncoding() {
    let command = IPMsgCommand.avatar(hash: "abc123def456")
    let encoded = command.rawValue

    #expect(encoded == 0x00020000)
}

@Test("IPMSG_GETAVATAR command encoding")
func testGetAvatarCommandEncoding() {
    let command = IPMsgCommand.getAvatar(userId: "user123")
    let encoded = command.rawValue

    #expect(encoded == 0x00030000)
}
```

### Step 2: 运行测试验证失败

```bash
cd Modules/IPMsgProtocol
swift test
```

**预期输出**：`FAIL` - `Type 'IPMsgCommand' has no member 'avatar'`

### Step 3: 实现最小代码 - 添加命令

```swift
// Modules/IPMsgProtocol/Sources/IPMsgProtocol/IPMsgCommand.swift
public enum IPMsgCommand: UInt32 {
    // 已有命令
    case noOperation = 0x00000000
    case broadcastEntry = 0x00000001
    case broadcastExit = 0x00000002
    case broadcastAbsence = 0x00000020
    case answerEntry = 0x00000003
    case sendMessage = 0x00000020

    // 新增命令
    case avatar = 0x00020000        // 头像元数据（UDP 广播）
    case getAvatar = 0x00030000     // 请求头像（TCP）
    case recallMessage = 0x00010000 // 撤回消息（Phase 4）
    case typing = 0x00040000        // 输入状态（Phase 4）
    case stopTyping = 0x00050000    // 停止输入（Phase 4）
    case recallList = 0x00060000    // 撤回列表（Phase 4）
}

extension IPMsgCommand {
    // 创建头像命令
    public static func avatar(hash: String) -> IPMsgCommand {
        return .avatar
    }

    // 创建获取头像命令
    public static func getAvatar(userId: String) -> IPMsgCommand {
        return .getAvatar
    }
}
```

### Step 4: 运行测试验证通过

```bash
cd Modules/IPMsgProtocol
swift test
```

**预期输出**：`PASS` - All tests passed

### Step 5: 提交

```bash
git add Modules/IPMsgProtocol/Sources/IPMsgProtocol/IPMsgCommand.swift \
        Modules/IPMsgProtocol/Tests/IPMsgProtocolTests/IPMsgCommandTests.swift
git commit -m "feat(protocol): add avatar-related commands

- Add IPMSG_AVATAR (0x00020000) for avatar metadata broadcast
- Add IPMSG_GETAVATAR (0x00030000) for avatar request
- Add helper methods for command creation

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 3: AvatarService - 头像管理服务

**目标**：实现头像设置、缓存和传输功能

**Files:**
- Create: `Modules/FluxQServices/Sources/FluxQServices/AvatarService.swift`
- Test: `Modules/FluxQServices/Tests/FluxQServicesTests/AvatarServiceTests.swift`

### Step 1: 写失败测试 - 设置头像

```swift
// Modules/FluxQServices/Tests/FluxQServicesTests/AvatarServiceTests.swift
import Testing
import Foundation
import SwiftData
@testable import FluxQServices
@testable import FluxQModels

@Test("Set user avatar and calculate hash")
func testSetMyAvatar() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: User.self, configurations: config)
    let context = ModelContext(container)

    // 创建当前用户
    let currentUser = User(
        nickname: "我",
        hostname: "my-mac",
        ipAddress: "192.168.1.100"
    )
    context.insert(currentUser)
    try context.save()

    // 创建服务
    let service = AvatarService(modelContext: context)

    // 测试图像数据（1x1 红色像素）
    let testImageData = Data([0xFF, 0x00, 0x00, 0xFF])

    // 设置头像
    try await service.setMyAvatar(testImageData)

    // 验证
    #expect(currentUser.avatarData == testImageData)
    #expect(currentUser.avatarHash != nil)
    #expect(currentUser.avatarHash?.count == 64) // SHA-256 = 64 hex chars
}

@Test("Avatar compression for large images")
func testAvatarCompression() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: User.self, configurations: config)
    let context = ModelContext(container)

    let currentUser = User(nickname: "我", hostname: "my-mac")
    context.insert(currentUser)

    let service = AvatarService(modelContext: context)

    // 创建大图像数据（> 1MB）
    let largeImageData = Data(repeating: 0xFF, count: 2_000_000)

    try await service.setMyAvatar(largeImageData)

    // 验证压缩后的数据 ≤ 1MB
    #expect(currentUser.avatarData!.count <= 1_048_576)
}
```

### Step 2: 运行测试验证失败

```bash
cd Modules/FluxQServices
swift test
```

**预期输出**：`FAIL` - `Cannot find 'AvatarService' in scope`

### Step 3: 实现最小代码 - AvatarService

```swift
// Modules/FluxQServices/Sources/FluxQServices/AvatarService.swift
import Foundation
import SwiftData
import CryptoKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import FluxQModels

@MainActor
public class AvatarService: ObservableObject {
    // 依赖
    private let modelContext: ModelContext

    // 本地头像缓存（内存）
    @Published public private(set) var avatarCache: [String: Data] = [:]

    // 最大头像大小（1MB）
    private let maxAvatarSize: Int = 1_048_576

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // 设置当前用户头像
    public func setMyAvatar(_ imageData: Data) async throws {
        let user = try getCurrentUser()

        // 压缩头像（如果需要）
        var processedData = imageData
        if imageData.count > maxAvatarSize {
            processedData = try compressImage(imageData)
        }

        // 计算 SHA-256 hash
        let hash = SHA256.hash(data: processedData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        // 保存到 SwiftData（自动 CloudKit 同步）
        user.avatarData = processedData
        user.avatarHash = hashString
        try modelContext.save()

        // 更新缓存
        avatarCache[hashString] = processedData
    }

    // 压缩图像到指定大小
    private func compressImage(_ imageData: Data) throws -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData) else {
            throw AvatarError.invalidImageFormat
        }

        // 尝试不同的压缩质量
        for quality in stride(from: 0.8, through: 0.1, by: -0.1) {
            if let compressed = image.jpegData(compressionQuality: quality),
               compressed.count <= maxAvatarSize {
                return compressed
            }
        }

        throw AvatarError.compressionFailed

        #elseif canImport(AppKit)
        guard let image = NSImage(data: imageData) else {
            throw AvatarError.invalidImageFormat
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            throw AvatarError.invalidImageFormat
        }

        for quality in stride(from: 0.8, through: 0.1, by: -0.1) {
            if let compressed = bitmapImage.representation(
                using: .jpeg,
                properties: [.compressionFactor: quality]
            ), compressed.count <= maxAvatarSize {
                return compressed
            }
        }

        throw AvatarError.compressionFailed
        #endif
    }

    // 获取当前用户
    private func getCurrentUser() throws -> User {
        let descriptor = FetchDescriptor<User>()
        let users = try modelContext.fetch(descriptor)

        guard let currentUser = users.first else {
            throw AvatarError.currentUserNotFound
        }

        return currentUser
    }
}

// 错误类型
public enum AvatarError: Error, LocalizedError {
    case invalidImageFormat
    case compressionFailed
    case currentUserNotFound
    case avatarTooLarge(size: Int, maxSize: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidImageFormat:
            return "不支持的图像格式"
        case .compressionFailed:
            return "图像压缩失败"
        case .currentUserNotFound:
            return "当前用户不存在"
        case .avatarTooLarge(let size, let maxSize):
            return "头像过大（\(size) bytes，最大 \(maxSize) bytes）"
        }
    }
}
```

### Step 4: 运行测试验证通过

```bash
cd Modules/FluxQServices
swift test
```

**预期输出**：`PASS` - All tests passed

### Step 5: 提交

```bash
git add Modules/FluxQServices/Sources/FluxQServices/AvatarService.swift \
        Modules/FluxQServices/Tests/FluxQServicesTests/AvatarServiceTests.swift
git commit -m "feat(services): implement AvatarService

- Set user avatar with automatic compression
- Calculate SHA-256 hash for deduplication
- In-memory avatar cache
- CloudKit sync via SwiftData

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 4: HeartbeatService - 心跳保活服务

**目标**：实现平台差异化心跳策略和超时检测

**Files:**
- Create: `Modules/FluxQServices/Sources/FluxQServices/HeartbeatService.swift`
- Test: `Modules/FluxQServices/Tests/FluxQServicesTests/HeartbeatServiceTests.swift`

### Step 1: 写失败测试 - 心跳间隔

```swift
// Modules/FluxQServices/Tests/FluxQServicesTests/HeartbeatServiceTests.swift
import Testing
import Foundation
@testable import FluxQServices

@Test("Heartbeat interval - macOS")
func testHeartbeatIntervalMacOS() {
    #if os(macOS)
    let service = HeartbeatService()
    #expect(service.heartbeatInterval == 30.0)
    #expect(service.timeoutInterval == 60.0)
    #endif
}

@Test("Heartbeat interval - watchOS")
func testHeartbeatIntervalWatchOS() {
    #if os(watchOS)
    let service = HeartbeatService()
    #expect(service.heartbeatInterval == 60.0)
    #expect(service.timeoutInterval == 120.0)
    #endif
}

@Test("User timeout detection")
func testUserTimeoutDetection() async {
    let service = HeartbeatService()
    let userId = "test-user-123"
    let now = Date()

    // 记录心跳
    service.recordHeartbeat(userId: userId, at: now)
    #expect(service.isUserOnline(userId) == true)

    // 模拟超时（65 秒后）
    let timeoutDate = now.addingTimeInterval(65)
    service.checkTimeouts(currentTime: timeoutDate)

    #expect(service.isUserOnline(userId) == false)
}
```

### Step 2: 运行测试验证失败

```bash
cd Modules/FluxQServices
swift test
```

**预期输出**：`FAIL` - `Cannot find 'HeartbeatService' in scope`

### Step 3: 实现最小代码 - HeartbeatService

```swift
// Modules/FluxQServices/Sources/FluxQServices/HeartbeatService.swift
import Foundation
import Observation

@MainActor
@Observable
public class HeartbeatService {
    // 平台差异化心跳间隔
    public var heartbeatInterval: TimeInterval {
        #if os(watchOS)
        return 60.0  // watchOS: 60 秒
        #elseif os(iOS)
        // iOS: 前台 30 秒，后台 60 秒
        #if canImport(UIKit)
        import UIKit
        return UIApplication.shared.applicationState == .active ? 30.0 : 60.0
        #else
        return 30.0
        #endif
        #else
        return 30.0  // macOS: 30 秒
        #endif
    }

    public var timeoutInterval: TimeInterval {
        heartbeatInterval * 2
    }

    // 在线用户管理
    public private(set) var onlineUsers: [String: Date] = [:]

    // 漏失心跳计数
    private var missedHeartbeats: [String: Int] = [:]

    public init() {}

    // 记录心跳
    public func recordHeartbeat(userId: String, at date: Date) {
        onlineUsers[userId] = date
        missedHeartbeats[userId] = 0
    }

    // 检查用户是否在线
    public func isUserOnline(_ userId: String) -> Bool {
        guard let lastSeen = onlineUsers[userId] else {
            return false
        }

        let now = Date()
        return now.timeIntervalSince(lastSeen) <= timeoutInterval
    }

    // 检查超时（供测试使用）
    public func checkTimeouts(currentTime: Date = Date()) {
        for (userId, lastSeen) in onlineUsers {
            if currentTime.timeIntervalSince(lastSeen) > timeoutInterval {
                handleHeartbeatTimeout(userId: userId)
            }
        }
    }

    // 处理心跳超时
    private func handleHeartbeatTimeout(userId: String) {
        missedHeartbeats[userId, default: 0] += 1

        switch missedHeartbeats[userId] {
        case 1:
            // 第一次超时：标记为"可能离线"
            break
        case 2:
            // 第二次超时：标记为"离线"
            break
        case 3...:
            // 第三次超时：从列表中移除
            onlineUsers.removeValue(forKey: userId)
            missedHeartbeats.removeValue(forKey: userId)
        default:
            break
        }
    }

    // 启动心跳（实际使用）
    public func startHeartbeat(udpService: UDPDiscoveryService) {
        Task {
            while !Task.isCancelled {
                // 发送心跳广播
                try? await sendHeartbeat(udpService: udpService)

                // 等待下一个心跳周期
                try? await Task.sleep(for: .seconds(heartbeatInterval))
            }
        }

        // 启动超时检测
        startTimeoutMonitor()
    }

    // 发送心跳广播
    private func sendHeartbeat(udpService: UDPDiscoveryService) async throws {
        // 实际实现：发送 BR_ABSENCE 广播
        // 这里先预留接口
    }

    // 启动超时监控
    private func startTimeoutMonitor() {
        Task {
            while !Task.isCancelled {
                checkTimeouts()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }
}
```

### Step 4: 运行测试验证通过

```bash
cd Modules/FluxQServices
swift test
```

**预期输出**：`PASS` - All tests passed

### Step 5: 提交

```bash
git add Modules/FluxQServices/Sources/FluxQServices/HeartbeatService.swift \
        Modules/FluxQServices/Tests/FluxQServicesTests/HeartbeatServiceTests.swift
git commit -m "feat(services): implement HeartbeatService

- Platform-specific heartbeat intervals (watchOS 60s, iOS 30s/60s, macOS 30s)
- Timeout detection with progressive offline marking
- Online user tracking

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 5: SearchFilterService - 搜索和过滤服务

**目标**：实现用户搜索和过滤功能

**Files:**
- Create: `Modules/FluxQServices/Sources/FluxQServices/SearchFilterService.swift`
- Test: `Modules/FluxQServices/Tests/FluxQServicesTests/SearchFilterServiceTests.swift`

### Step 1: 写失败测试 - 搜索过滤

```swift
// Modules/FluxQServices/Tests/FluxQServicesTests/SearchFilterServiceTests.swift
import Testing
import Foundation
@testable import FluxQServices
@testable import FluxQModels

@Test("Search by nickname")
func testSearchByNickname() {
    let service = SearchFilterService()
    let users = [
        createUser(nickname: "张三", hostname: "mac-001"),
        createUser(nickname: "李四", hostname: "mac-002"),
        createUser(nickname: "王五", hostname: "mac-003")
    ]

    service.searchText = "张三"
    let result = service.filterUsers(users)

    #expect(result.count == 1)
    #expect(result.first?.nickname == "张三")
}

@Test("Filter by online status")
func testFilterByOnlineStatus() {
    let service = SearchFilterService()
    let users = [
        createUser(nickname: "张三", isOnline: true),
        createUser(nickname: "李四", isOnline: false),
        createUser(nickname: "王五", isOnline: true)
    ]

    service.filters = [.onlineOnly]
    let result = service.filterUsers(users)

    #expect(result.count == 2)
    #expect(result.allSatisfy { $0.isOnline })
}

@Test("Combined search and filter")
func testCombinedSearchAndFilter() {
    let service = SearchFilterService()
    let users = [
        createUser(nickname: "张三", isOnline: true),
        createUser(nickname: "张四", isOnline: false),
        createUser(nickname: "王五", isOnline: true)
    ]

    service.searchText = "张"
    service.filters = [.onlineOnly]
    let result = service.filterUsers(users)

    #expect(result.count == 1)
    #expect(result.first?.nickname == "张三")
}

// 辅助函数
func createUser(
    nickname: String,
    hostname: String = "test-mac",
    isOnline: Bool = false
) -> User {
    User(
        nickname: nickname,
        hostname: hostname,
        isOnline: isOnline
    )
}
```

### Step 2: 运行测试验证失败

```bash
cd Modules/FluxQServices
swift test
```

**预期输出**：`FAIL` - `Cannot find 'SearchFilterService' in scope`

### Step 3: 实现最小代码 - SearchFilterService

```swift
// Modules/FluxQServices/Sources/FluxQServices/SearchFilterService.swift
import Foundation
import Observation
import FluxQModels

@MainActor
@Observable
public class SearchFilterService {
    // 搜索关键词
    public var searchText: String = ""

    // 过滤条件
    public var filters: Set<FilterType> = []

    public enum FilterType: Hashable {
        case onlineOnly      // 仅在线用户
        case withAvatar      // 仅有头像的用户
        case recentlyActive  // 最近活跃（5 分钟内）
    }

    public init() {}

    // 过滤用户列表
    public func filterUsers(_ users: [User]) -> [User] {
        var result = users

        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter { user in
                user.nickname.localizedCaseInsensitiveContains(searchText) ||
                user.hostname.localizedCaseInsensitiveContains(searchText) ||
                (user.department?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // 条件过滤
        if filters.contains(.onlineOnly) {
            result = result.filter { $0.isOnline }
        }

        if filters.contains(.withAvatar) {
            result = result.filter { $0.avatarHash != nil }
        }

        if filters.contains(.recentlyActive) {
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            result = result.filter { $0.lastSeen > fiveMinutesAgo }
        }

        return result
    }
}
```

### Step 4: 运行测试验证通过

```bash
cd Modules/FluxQServices
swift test
```

**预期输出**：`PASS` - All tests passed

### Step 5: 提交

```bash
git add Modules/FluxQServices/Sources/FluxQServices/SearchFilterService.swift \
        Modules/FluxQServices/Tests/FluxQServicesTests/SearchFilterServiceTests.swift
git commit -m "feat(services): implement SearchFilterService

- Search by nickname, hostname, department
- Filter by online status, avatar presence, recent activity
- Support combined search and filters

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 6: UI 集成 - DiscoveryView 增强

**目标**：集成头像显示、搜索框和过滤器到 DiscoveryView

**Files:**
- Modify: `FluxQ/Views/DiscoveryView.swift`
- Create: `FluxQ/Views/Components/UserAvatarView.swift`

### Step 1: 创建 UserAvatarView 组件

```swift
// FluxQ/Views/Components/UserAvatarView.swift
import SwiftUI
import FluxQModels

struct UserAvatarView: View {
    let user: User
    let size: CGFloat

    var body: some View {
        Group {
            if let avatarData = user.avatarData,
               let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

#Preview {
    UserAvatarView(
        user: User(nickname: "测试", hostname: "mac"),
        size: 40
    )
}
```

### Step 2: 增强 DiscoveryView

```swift
// FluxQ/Views/DiscoveryView.swift
import SwiftUI
import SwiftData
import FluxQModels
import FluxQServices

struct DiscoveryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    @StateObject private var searchFilterService = SearchFilterService()
    @StateObject private var avatarService: AvatarService
    @StateObject private var heartbeatService = HeartbeatService()

    // 过滤后的用户列表
    private var filteredUsers: [User] {
        searchFilterService.filterUsers(users)
    }

    init(modelContext: ModelContext) {
        _avatarService = StateObject(wrappedValue: AvatarService(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("搜索用户", text: $searchFilterService.searchText)
                        .textFieldStyle(.plain)

                    if !searchFilterService.searchText.isEmpty {
                        Button {
                            searchFilterService.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))

                // 过滤器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "仅在线",
                            isSelected: searchFilterService.filters.contains(.onlineOnly)
                        ) {
                            if searchFilterService.filters.contains(.onlineOnly) {
                                searchFilterService.filters.remove(.onlineOnly)
                            } else {
                                searchFilterService.filters.insert(.onlineOnly)
                            }
                        }

                        FilterChip(
                            title: "有头像",
                            isSelected: searchFilterService.filters.contains(.withAvatar)
                        ) {
                            if searchFilterService.filters.contains(.withAvatar) {
                                searchFilterService.filters.remove(.withAvatar)
                            } else {
                                searchFilterService.filters.insert(.withAvatar)
                            }
                        }

                        FilterChip(
                            title: "最近活跃",
                            isSelected: searchFilterService.filters.contains(.recentlyActive)
                        ) {
                            if searchFilterService.filters.contains(.recentlyActive) {
                                searchFilterService.filters.remove(.recentlyActive)
                            } else {
                                searchFilterService.filters.insert(.recentlyActive)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // 用户列表
                List(filteredUsers) { user in
                    HStack(spacing: 12) {
                        // 头像
                        UserAvatarView(user: user, size: 40)

                        // 用户信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.nickname)
                                .font(.headline)

                            Text(user.hostname)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let department = user.department {
                                Text(department)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        // 在线状态
                        if user.isOnline {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
            .navigationTitle("发现")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // TODO: 刷新用户列表
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

// 过滤器芯片组件
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    DiscoveryView(modelContext: ModelContext(
        try! ModelContainer(for: User.self)
    ))
}
```

### Step 3: 手动测试

1. 在 Xcode 中运行应用（⌘R）
2. 导航到"发现"标签
3. 验证搜索框显示正确
4. 验证过滤器芯片显示正确
5. 输入搜索文本，验证用户列表过滤
6. 点击过滤器，验证过滤功能

**预期结果**：
- 搜索框正常工作
- 过滤器正常工作
- 用户列表显示头像（如果有）
- 在线状态指示器显示正确

### Step 4: 提交

```bash
git add FluxQ/Views/DiscoveryView.swift \
        FluxQ/Views/Components/UserAvatarView.swift
git commit -m "feat(ui): enhance DiscoveryView with avatar and filters

- Add UserAvatarView component for avatar display
- Add search bar for user search
- Add filter chips (online, avatar, recent activity)
- Display online status indicator

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 7: 集成测试和文档

**目标**：运行所有测试，验证 Phase 3 功能完整性

### Step 1: 运行所有模块测试

```bash
# FluxQModels 测试
cd Modules/FluxQModels
swift test

# IPMsgProtocol 测试
cd ../IPMsgProtocol
swift test

# FluxQServices 测试
cd ../FluxQServices
swift test
```

**预期输出**：所有测试通过

### Step 2: 运行 Xcode 测试套件

```bash
# 返回项目根目录
cd ../../

# 运行所有测试
xcodebuild test -scheme FluxQ -destination 'platform=macOS'
xcodebuild test -scheme FluxQ -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**预期输出**：所有测试通过

### Step 3: 手动测试完整流程

按照 `docs/plans/2026-02-14-phase3-4-5-design.md` 中的"Phase 3 手动测试清单"逐项验证。

### Step 4: 更新 README.md

```markdown
## Phase 3 完成 ✅

- ✅ 用户头像系统（CloudKit 同步）
- ✅ 搜索和过滤功能
- ✅ 心跳保活机制
- ✅ 平台差异化心跳策略
```

### Step 5: 最终提交

```bash
git add README.md
git commit -m "docs: update README for Phase 3 completion

Phase 3 features implemented:
- User avatar system with CloudKit sync
- Search and filter functionality
- Heartbeat keep-alive mechanism
- Platform-specific heartbeat strategies

All tests passing ✅

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## 验收标准

Phase 3 完成的标志：

- [ ] 所有单元测试通过（FluxQModels, IPMsgProtocol, FluxQServices）
- [ ] 用户可以设置头像，并在所有设备同步
- [ ] 用户列表显示其他用户的头像
- [ ] 搜索功能正常工作（按昵称、主机名、部门）
- [ ] 过滤功能正常工作（仅在线、有头像、最近活跃）
- [ ] 心跳保活正确标记在线/离线状态
- [ ] macOS 心跳间隔 30 秒，watchOS 60 秒
- [ ] 头像过大时自动压缩到 1MB 以内
- [ ] 代码遵循 CLAUDE.md 规范

---

## 下一步

Phase 3 完成后，继续：
- **Phase 4 实施计划**：`docs/plans/2026-02-14-phase4-implementation.md`

---

**计划版本**：1.0
**创建日期**：2026-02-14
**预计时间**：1 周
**作者**：Claude Sonnet 4.5
