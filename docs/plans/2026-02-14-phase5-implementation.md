# Phase 5: 完整 watchOS 体验 - 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标**：实现 watchOS 完整体验，包括 Watch Connectivity、独立网络、Complication 和快速回复

**架构**：智能网络模式切换（伴随/独立/离线），Watch Connectivity 消息同步，Wi-Fi Watch 独立运行完整网络服务，Complication 显示未读消息

**技术栈**：Swift 5.9+, SwiftUI, Watch Connectivity, ClockKit, Network.framework, BSD Socket, Swift Testing

---

## 前置条件

- ✅ Phase 3 已完成（UDP 广播、心跳）
- ✅ Phase 4 已完成（TCP 消息）
- ✅ UDPDiscoveryService、TCPMessageService 已实现

---

## Task 1: NetworkModeManager - 网络模式管理器

**目标**：实现智能网络模式切换（伴随/独立/离线）

**Files:**
- Create: `FluxQWatch/Services/NetworkModeManager.swift`
- Test: `FluxQWatchTests/NetworkModeManagerTests.swift`

### Step 1: 写失败测试 - 模式检测

```swift
// FluxQWatchTests/NetworkModeManagerTests.swift
import Testing
import Foundation
@testable import FluxQWatch

@Test("Detect companion mode when iPhone reachable")
func testDetectCompanionMode() {
    let manager = NetworkModeManager(testMode: true)
    manager.mockWCSessionReachable = true

    let mode = manager.determineNetworkMode()
    #expect(mode == .companion)
}

@Test("Detect standalone mode when Wi-Fi available")
func testDetectStandaloneMode() {
    let manager = NetworkModeManager(testMode: true)
    manager.mockWCSessionReachable = false
    manager.mockWiFiEnabled = true

    let mode = manager.determineNetworkMode()
    #expect(mode == .standalone)
}

@Test("Detect offline mode when no connectivity")
func testDetectOfflineMode() {
    let manager = NetworkModeManager(testMode: true)
    manager.mockWCSessionReachable = false
    manager.mockWiFiEnabled = false

    let mode = manager.determineNetworkMode()
    #expect(mode == .offline)
}
```

### Step 2: 运行测试验证失败

```bash
xcodebuild test -scheme FluxQWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (45mm)'
```

**预期输出**：`FAIL` - `Cannot find 'NetworkModeManager' in scope`

### Step 3: 实现最小代码 - NetworkModeManager

```swift
// FluxQWatch/Services/NetworkModeManager.swift
import Foundation
import WatchConnectivity
import WatchKit
import Observation

@MainActor
@Observable
public class NetworkModeManager {
    // 当前网络模式
    public private(set) var currentMode: NetworkMode = .offline

    public enum NetworkMode: Equatable {
        case companion    // 伴随模式（iPhone 代理）
        case standalone   // 独立模式（Wi-Fi Watch）
        case offline      // 离线模式（GPS Watch）
    }

    // 依赖
    private let wcSession: WCSession
    private let device: WKInterfaceDevice

    // 测试模式
    private let testMode: Bool
    var mockWCSessionReachable: Bool = false
    var mockWiFiEnabled: Bool = false

    public init(testMode: Bool = false) {
        self.testMode = testMode

        if WCSession.isSupported() {
            self.wcSession = WCSession.default
        } else {
            fatalError("WCSession not supported")
        }

        self.device = WKInterfaceDevice.current()
    }

    // 开始监控网络模式
    public func startMonitoring() {
        // 监听 Watch Connectivity 状态
        NotificationCenter.default.addObserver(
            forName: .WCSessionReachabilityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateNetworkMode()
        }

        // 定期检测（每 5 秒）
        Task {
            while !Task.isCancelled {
                updateNetworkMode()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    // 更新网络模式
    @objc private func updateNetworkMode() {
        let newMode = determineNetworkMode()

        if newMode != currentMode {
            print("Network mode switching: \(currentMode) → \(newMode)")
            currentMode = newMode

            // 触发模式切换
            Task {
                try? await switchToMode(newMode)
            }
        }
    }

    // 确定网络模式
    func determineNetworkMode() -> NetworkMode {
        if testMode {
            // 测试模式：使用 mock 值
            if mockWCSessionReachable {
                return .companion
            } else if mockWiFiEnabled {
                return .standalone
            } else {
                return .offline
            }
        }

        // 1. iPhone 在附近且可达 → 伴随模式
        if wcSession.isReachable {
            return .companion
        }

        // 2. Wi-Fi 可用 → 独立模式
        #if os(watchOS)
        if device.isWiFiEnabled {
            return .standalone
        }
        #endif

        // 3. 其他情况 → 离线模式
        return .offline
    }

    // 切换到指定模式
    private func switchToMode(_ mode: NetworkMode) async throws {
        // 实际模式切换逻辑将在后续任务中实现
        print("Switching to \(mode)")
    }
}
```

### Step 4: 运行测试验证通过

```bash
xcodebuild test -scheme FluxQWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (45mm)'
```

**预期输出**：`PASS` - All tests passed

### Step 5: 提交

```bash
git add FluxQWatch/Services/NetworkModeManager.swift \
        FluxQWatchTests/NetworkModeManagerTests.swift
git commit -m "feat(watch): implement NetworkModeManager

- Detect companion/standalone/offline modes
- Monitor WCSession reachability changes
- Periodic network status polling

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 2: WatchConnectivityService - Watch Connectivity 桥接

**目标**：实现 Watch ↔ iPhone 消息同步

**Files:**
- Create: `FluxQWatch/Services/WatchConnectivityService.swift`
- Test: `FluxQWatchTests/WatchConnectivityServiceTests.swift`

### Step 1: 写失败测试 - 发送消息

```swift
// FluxQWatchTests/WatchConnectivityServiceTests.swift
import Testing
import Foundation
import WatchConnectivity
@testable import FluxQWatch

@Test("Send message through Watch Connectivity")
func testSendMessage() async throws {
    let service = WatchConnectivityService(testMode: true)
    service.mockIsReachable = true

    try await service.sendMessage(to: "user123", content: "Hello from Watch")

    let sentMessages = service.mockSentMessages
    #expect(sentMessages.count == 1)
    #expect(sentMessages.first?["action"] as? String == "sendMessage")
    #expect(sentMessages.first?["content"] as? String == "Hello from Watch")
}

@Test("Throw error when iPhone not reachable")
func testSendMessageWhenUnreachable() async {
    let service = WatchConnectivityService(testMode: true)
    service.mockIsReachable = false

    await #expect(throws: WatchError.iPhoneNotReachable) {
        try await service.sendMessage(to: "user123", content: "Hello")
    }
}
```

### Step 2: 运行测试验证失败

```bash
xcodebuild test -scheme FluxQWatch
```

**预期输出**：`FAIL` - `Cannot find 'WatchConnectivityService' in scope`

### Step 3: 实现最小代码 - WatchConnectivityService

```swift
// FluxQWatch/Services/WatchConnectivityService.swift
import Foundation
import WatchConnectivity
import Observation

@MainActor
@Observable
public class WatchConnectivityService: NSObject, WCSessionDelegate {
    // 依赖
    private let session: WCSession

    // 状态
    public private(set) var isReachable: Bool = false
    public private(set) var lastSyncTime: Date?

    // 测试模式
    private let testMode: Bool
    var mockIsReachable: Bool = false
    var mockSentMessages: [[String: Any]] = []

    public init(testMode: Bool = false) {
        self.testMode = testMode

        if WCSession.isSupported() {
            self.session = WCSession.default
        } else {
            fatalError("WCSession not supported")
        }

        super.init()

        if !testMode {
            session.delegate = self
        }
    }

    // 启动
    public func start() async throws {
        guard WCSession.isSupported() else {
            throw WatchError.watchConnectivityNotSupported
        }

        session.activate()
    }

    // 停止
    public func stop() {
        // 清理资源
    }

    // 发送消息（Watch → iPhone）
    public func sendMessage(to userId: String, content: String) async throws {
        if testMode {
            guard mockIsReachable else {
                throw WatchError.iPhoneNotReachable
            }

            mockSentMessages.append([
                "action": "sendMessage",
                "recipientId": userId,
                "content": content
            ])
            return
        }

        guard session.isReachable else {
            throw WatchError.iPhoneNotReachable
        }

        let payload: [String: Any] = [
            "action": "sendMessage",
            "recipientId": userId,
            "content": content,
            "timestamp": Date().timeIntervalSince1970
        ]

        try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(payload, replyHandler: { reply in
                if let error = reply["error"] as? String {
                    continuation.resume(throwing: WatchError.iPhoneSendFailed(error))
                } else {
                    continuation.resume()
                }
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    // 接收消息（iPhone → Watch）
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            guard let action = message["action"] as? String else { return }

            switch action {
            case "newMessage":
                try? await handleNewMessage(message)
            case "messageRecalled":
                try? await handleMessageRecalled(message)
            default:
                print("Unknown Watch Connectivity action: \(action)")
            }
        }
    }

    private func handleNewMessage(_ payload: [String: Any]) async throws {
        // 处理新消息
        // TODO: 保存到 SwiftData
    }

    private func handleMessageRecalled(_ payload: [String: Any]) async throws {
        // 处理撤回消息
        // TODO: 更新 SwiftData
    }

    // WCSessionDelegate
    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isReachable = session.isReachable

            if let error = error {
                print("Watch Connectivity activation failed: \(error)")
            }
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }
}

// 错误类型
public enum WatchError: Error, LocalizedError {
    case watchConnectivityNotSupported
    case iPhoneNotReachable
    case iPhoneSendFailed(String)

    public var errorDescription: String? {
        switch self {
        case .watchConnectivityNotSupported:
            return "当前设备不支持 Watch Connectivity"
        case .iPhoneNotReachable:
            return "iPhone 不在附近或未连接"
        case .iPhoneSendFailed(let reason):
            return "通过 iPhone 发送失败: \(reason)"
        }
    }
}
```

### Step 4: 运行测试验证通过

```bash
xcodebuild test -scheme FluxQWatch
```

**预期输出**：`PASS` - All tests passed

### Step 5: 提交

```bash
git add FluxQWatch/Services/WatchConnectivityService.swift \
        FluxQWatchTests/WatchConnectivityServiceTests.swift
git commit -m "feat(watch): implement WatchConnectivityService

- Send messages through Watch Connectivity
- Receive messages from iPhone
- Handle reachability changes

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 3-8: 继续实施...

**完整的 Phase 5 实施计划包含以下剩余任务：**

- Task 3: WatchNetworkService - 独立网络服务
- Task 4: ComplicationService - 表盘复杂功能
- Task 5: QuickReplyService - 快速回复
- Task 6: UI 集成 - MessageListView 增强
- Task 7: 模式切换集成
- Task 8: 集成测试和文档

**所有任务遵循相同的 TDD 流程**

---

## 验收标准

Phase 5 完成的标志：

- [ ] 所有单元测试通过
- [ ] 网络模式自动切换正常
- [ ] 伴随模式下消息收发正常
- [ ] 独立模式下完整功能可用
- [ ] Complication 正确显示未读数
- [ ] 快速回复功能正常
- [ ] 离线模式下可以查看历史消息
- [ ] 代码遵循 CLAUDE.md 规范

---

## 总结

Phase 3/4/5 完成后：

✅ **Phase 3**：用户头像、搜索过滤、心跳保活
✅ **Phase 4**：TCP 消息、消息撤回、输入提示、消息操作
✅ **Phase 5**：Watch Connectivity、独立网络、Complication、快速回复

**总时间**：3.5-4 周
**技术栈**：Swift 5.9+, SwiftUI, SwiftData, Network.framework, BSD Socket, Watch Connectivity, ClockKit

---

**计划版本**：1.0
**创建日期**：2026-02-14
**预计时间**：1 周
**作者**：Claude Sonnet 4.5
