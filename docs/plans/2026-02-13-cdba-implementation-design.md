# FluxQ C→D→B→A 任务实施设计

> **日期**: 2026-02-13
> **版本**: v0.1.0 后续任务
> **状态**: 已批准

## 概述

本设计涵盖 v0.1.0 完成后的四个关键任务阶段，按照 C→D→B→A 顺序执行：

- **C**: 完善文档（README + BUILD + USER_GUIDE）
- **D**: 其他需求（MIT LICENSE + 图标 + CI/CD）
- **B**: 运行应用（编译 + 截图 + 文档更新）
- **A**: 开发 v0.2.0（IPMsg 协议网络层）

## 目标

1. **文档完整性**: 提供清晰的用户指南和构建文档
2. **项目专业性**: 标准的 LICENSE、CI/CD、应用图标
3. **可视化展示**: 各平台应用截图
4. **功能可用性**: v0.2.0 实现基础的网络通信能力

## 实施方案

### 选择：方案 2 - 部分并行执行

**理由**: 在效率与稳定性之间取得平衡

**执行流程**:
```
第 1 波（并行，~20 分钟）
├─ doc-writer: 任务 C（文档更新）
└─ project-configurator: 任务 D（项目配置）

第 2 波（~15 分钟）
└─ app-tester: 任务 B（运行与截图）

第 3 波（并行，~40 分钟）
├─ protocol-developer: IPMsgProtocol Package
├─ service-developer: FluxQServices Package
└─ network-tester: 集成测试
```

---

## 第 1 波：文档与配置（并行）

### 任务 C：完善文档

**Agent**: doc-writer
**估时**: 20 分钟

#### 更新 README.md

**变更内容**:
1. **功能部分**: 更新为 v0.1.0 实际完成状态
   - ✅ SwiftData 数据模型（User, Message, Conversation）
   - ✅ 主界面 TabView 导航（4 个 tabs）
   - ✅ 主题系统（浅色/深色/系统）
   - ✅ watchOS 基础界面

2. **安装部分**: 反映当前可运行状态
   - 移除"发布版本将在 v1.0.0 后提供"的占位符
   - 添加"当前状态：v0.1.0 开发版可运行"

3. **截图部分**: 添加占位符（待任务 B 补充）
   ```markdown
   ## 界面预览

   ### macOS
   ![macOS 主界面](docs/images/macos-main.png)

   ### iOS
   ![iOS TabView](docs/images/ios-tabs.png)
   ![主题切换](docs/images/ios-theme.png)

   ### watchOS
   ![消息列表](docs/images/watch-messages.png)
   ```

4. **许可证**: 更新为 MIT
   ```markdown
   ## 许可证

   FluxQ 采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。
   ```

#### 更新 docs/BUILD.md

**补充内容**:
1. **验证过的构建命令**（基于 v0.1.0 测试）
   ```bash
   # macOS
   xcodebuild -project FluxQ.xcodeproj \
              -scheme FluxQ \
              -destination 'platform=macOS' \
              build

   # iOS
   xcodebuild -project FluxQ.xcodeproj \
              -scheme FluxQ \
              -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
              build

   # watchOS
   xcodebuild -project FluxQ.xcodeproj \
              -scheme FluxQWatch \
              -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
              build
   ```

2. **平台特定注意事项**
   - macOS: 需要 macOS 14 (Sonoma) 或更高
   - iOS: 推荐使用 iPhone 17 系列模拟器
   - watchOS: 需要配对 iOS 模拟器

3. **常见问题**
   - 如何选择模拟器
   - 如何清理构建缓存
   - 依赖问题排查

#### 创建 docs/USER_GUIDE.md

**结构**:
```markdown
# FluxQ 用户指南

## 快速开始

### 安装应用
[安装步骤]

### 首次使用
1. 启动应用
2. 查看主界面（4 个 tabs）
3. 进入"我"标签设置主题

## 功能说明

### 主题切换
1. 点击"我"标签
2. 选择"外观"部分
3. 选择浅色/深色/系统主题

### 各平台特性

#### macOS
- 完整的 4 tab 导航
- 原生 macOS 窗口控件

#### iOS/iPadOS
- 底部 TabBar 导航
- 支持深色模式
- 自适应布局

#### watchOS
- 简洁的消息列表
- 针对小屏幕优化

## 常见问题

### 如何更改主题？
[答案]

### 为什么没有消息？
v0.1.0 仅包含 UI 框架，v0.2.0 将实现网络通信功能。

## 版本历史

### v0.1.0 (当前)
- ✅ SwiftData 数据模型
- ✅ 主界面框架
- ✅ 主题系统
- ✅ watchOS 支持

### v0.2.0 (计划中)
- 🚧 IPMsg 协议网络层
- 🚧 用户发现
- 🚧 消息收发
```

---

### 任务 D：项目配置

**Agent**: project-configurator
**估时**: 20 分钟

#### 创建 LICENSE

**内容**: MIT 许可证全文
```
MIT License

Copyright (c) 2026 Martin Adams

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

[MIT 许可证完整文本]
```

#### 更新 .gitignore

**新增规则**:
```gitignore
# macOS
.DS_Store
.AppleDouble
.LSOverride

# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
*.xcworkspace/*
!*.xcworkspace/contents.xcworkspacedata
DerivedData/
.build/
*.build/

# Swift Package Manager
.swiftpm/
Packages/
Package.resolved

# Screenshots (可选)
# docs/images/*.png
```

#### 生成应用图标

**方法**: 使用 ImageMagick 或 sips 生成

**设计**: 简洁的"F"字母 + FluxQ 绿色背景

**尺寸要求**:
- **macOS**: 16, 32, 64, 128, 256, 512, 1024 (所有 @1x 和 @2x)
- **iOS**: 20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024
- **watchOS**: 48, 55, 58, 87, 80, 88, 100, 172, 196, 216, 1024

**生成脚本** (示例):
```bash
#!/bin/bash
# 生成基础 1024x1024 图标
convert -size 1024x1024 xc:"#00C733" \
        -gravity center \
        -pointsize 600 -fill white \
        -annotate +0+0 "F" \
        icon-1024.png

# 生成各尺寸
for size in 16 32 64 128 256 512; do
  convert icon-1024.png -resize ${size}x${size} icon-${size}.png
done
```

#### 创建 .github/workflows/build.yml

**CI/CD 配置**:
```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build-macos:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build macOS
        run: |
          xcodebuild -project FluxQ.xcodeproj \
                     -scheme FluxQ \
                     -destination 'platform=macOS' \
                     build

  build-ios:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build iOS
        run: |
          xcodebuild -project FluxQ.xcodeproj \
                     -scheme FluxQ \
                     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
                     build

  build-watchos:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build watchOS
        run: |
          xcodebuild -project FluxQ.xcodeproj \
                     -scheme FluxQWatch \
                     -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
                     build

  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Run Tests
        run: |
          swift test --package-path Modules/FluxQModels
```

---

## 第 2 波：运行与截图

### 任务 B：应用测试与截图

**Agent**: app-tester
**估时**: 15 分钟
**依赖**: 任务 D 完成（需要新图标）

#### 执行步骤

**1. 编译所有平台**
```bash
# macOS
xcodebuild -project FluxQ.xcodeproj \
           -scheme FluxQ \
           -destination 'platform=macOS' \
           build

# iOS
xcodebuild -project FluxQ.xcodeproj \
           -scheme FluxQ \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           build

# watchOS
xcodebuild -project FluxQ.xcodeproj \
           -scheme FluxQWatch \
           -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
           build
```

**2. 启动应用并截图**

**macOS**:
```bash
# 启动应用
open -a FluxQ

# 等待启动
sleep 3

# 截图
screencapture -x -o docs/images/macos-main.png
```

**iOS**:
```bash
# 获取模拟器 UUID
DEVICE_UUID=$(xcrun simctl list devices | grep "iPhone 17 Pro" | grep -oE '[0-9A-F-]{36}' | head -1)

# 启动应用
xcrun simctl boot $DEVICE_UUID
xcrun simctl launch $DEVICE_UUID com.martinadams.FluxQ

# 截图 TabView
xcrun simctl io $DEVICE_UUID screenshot docs/images/ios-tabs.png

# 导航到设置并截图主题切换
# (需要使用 UI 测试或手动操作)
xcrun simctl io $DEVICE_UUID screenshot docs/images/ios-theme.png
```

**watchOS**:
```bash
# 获取 Watch 模拟器 UUID
WATCH_UUID=$(xcrun simctl list devices | grep "Apple Watch Series 11" | grep -oE '[0-9A-F-]{36}' | head -1)

# 启动应用
xcrun simctl boot $WATCH_UUID
xcrun simctl launch $WATCH_UUID com.martinadams.FluxQWatch

# 截图
xcrun simctl io $WATCH_UUID screenshot docs/images/watch-messages.png
```

**3. 创建图片目录**
```bash
mkdir -p docs/images
```

**4. 更新 README.md**
- 补充截图链接（移除占位符注释）
- 验证图片路径正确

---

## 第 3 波：v0.2.0 开发（并行）

### 概述

v0.2.0 实现 IPMsg 协议的基础网络层，支持用户发现和消息收发。

**团队配置**: 3 agents 并行
- protocol-developer
- service-developer
- network-tester

### 任务 A1：IPMsgProtocol Package

**Agent**: protocol-developer
**估时**: 15 分钟

#### 创建 Package

```bash
mkdir -p Modules/IPMsgProtocol
cd Modules/IPMsgProtocol
swift package init --type library
```

#### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IPMsgProtocol",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "IPMsgProtocol",
            targets: ["IPMsgProtocol"]
        ),
    ],
    targets: [
        .target(
            name: "IPMsgProtocol",
            dependencies: []
        ),
        .testTarget(
            name: "IPMsgProtocolTests",
            dependencies: ["IPMsgProtocol"]
        ),
    ]
)
```

#### 协议实现

**Sources/IPMsgProtocol/IPMsgPacket.swift**:
```swift
import Foundation

/// IPMsg 协议包
public struct IPMsgPacket {
    public let version: Int
    public let packetNo: Int
    public let sender: String
    public let hostname: String
    public let command: IPMsgCommand
    public let payload: String

    /// 协议格式: "version:packetNo:sender:hostname:command:payload"
    public func encode() -> String {
        "\(version):\(packetNo):\(sender):\(hostname):\(command.rawValue):\(payload)"
    }

    public static func decode(_ message: String) throws -> IPMsgPacket {
        let parts = message.split(separator: ":", maxSplits: 5)
        guard parts.count == 6 else {
            throw IPMsgError.invalidFormat
        }

        guard let version = Int(parts[0]),
              let packetNo = Int(parts[1]),
              let commandValue = Int(parts[4]),
              let command = IPMsgCommand(rawValue: commandValue) else {
            throw IPMsgError.invalidFormat
        }

        return IPMsgPacket(
            version: version,
            packetNo: packetNo,
            sender: String(parts[2]),
            hostname: String(parts[3]),
            command: command,
            payload: String(parts[5])
        )
    }
}
```

**Sources/IPMsgProtocol/IPMsgCommand.swift**:
```swift
public enum IPMsgCommand: Int {
    // 用户状态
    case BR_ENTRY = 0x01        // 上线广播
    case BR_EXIT = 0x02         // 下线广播
    case ANSENTRY = 0x03        // 响应上线
    case BR_ABSENCE = 0x04      // 离开状态

    // 消息
    case SENDMSG = 0x20         // 发送消息
    case RECVMSG = 0x21         // 接收确认

    // 文件传输
    case GETFILEDATA = 0x60     // 获取文件数据
    case RELEASEFILES = 0x61    // 释放文件
    case GETDIRFILES = 0x62     // 获取目录文件
}
```

**Sources/IPMsgProtocol/IPMsgError.swift**:
```swift
public enum IPMsgError: Error {
    case invalidFormat
    case networkError(String)
    case timeout
}
```

#### 单元测试

**Tests/IPMsgProtocolTests/IPMsgPacketTests.swift**:
```swift
import XCTest
@testable import IPMsgProtocol

final class IPMsgPacketTests: XCTestCase {
    func testEncodeDecode() throws {
        let packet = IPMsgPacket(
            version: 1,
            packetNo: 100,
            sender: "user1",
            hostname: "MacBook",
            command: .BR_ENTRY,
            payload: "Hello"
        )

        let encoded = packet.encode()
        XCTAssertEqual(encoded, "1:100:user1:MacBook:1:Hello")

        let decoded = try IPMsgPacket.decode(encoded)
        XCTAssertEqual(decoded.version, packet.version)
        XCTAssertEqual(decoded.packetNo, packet.packetNo)
        XCTAssertEqual(decoded.sender, packet.sender)
        XCTAssertEqual(decoded.command, packet.command)
    }

    func testInvalidFormat() {
        XCTAssertThrowsError(try IPMsgPacket.decode("invalid"))
    }
}
```

---

### 任务 A2：FluxQServices Package

**Agent**: service-developer
**估时**: 20 分钟

#### 创建 Package

```bash
mkdir -p Modules/FluxQServices
cd Modules/FluxQServices
swift package init --type library
```

#### Package.swift

```swift
let package = Package(
    name: "FluxQServices",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "FluxQServices",
            targets: ["FluxQServices"]
        ),
    ],
    dependencies: [
        .package(path: "../IPMsgProtocol"),
        .package(path: "../FluxQModels"),
    ],
    targets: [
        .target(
            name: "FluxQServices",
            dependencies: [
                "IPMsgProtocol",
                "FluxQModels"
            ]
        ),
        .testTarget(
            name: "FluxQServicesTests",
            dependencies: ["FluxQServices"]
        ),
    ]
)
```

#### NetworkManager

**Sources/FluxQServices/NetworkManager.swift**:
```swift
import Foundation
import Network
import IPMsgProtocol
import Observation

@Observable
public final class NetworkManager {
    public static let shared = NetworkManager()

    public private(set) var isRunning = false
    public private(set) var discoveredUsers: [DiscoveredUser] = []

    private var udpListener: NWListener?
    private var udpConnection: NWConnection?

    private init() {}

    public func start() async throws {
        guard !isRunning else { return }

        // 启动 UDP 监听器（端口 2425）
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        udpListener = try NWListener(using: parameters, on: 2425)
        udpListener?.stateUpdateHandler = { [weak self] state in
            if state == .ready {
                self?.isRunning = true
            }
        }

        udpListener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        udpListener?.start(queue: .global())

        // 发送上线广播
        try await sendBroadcast(.BR_ENTRY)
    }

    public func stop() async {
        // 发送下线广播
        try? await sendBroadcast(.BR_EXIT)

        udpListener?.cancel()
        udpConnection?.cancel()

        isRunning = false
        discoveredUsers.removeAll()
    }

    private func sendBroadcast(_ command: IPMsgCommand) async throws {
        let packet = IPMsgPacket(
            version: 1,
            packetNo: Int.random(in: 1...999999),
            sender: "FluxQ",
            hostname: Host.current().localizedName ?? "Unknown",
            command: command,
            payload: ""
        )

        let message = packet.encode()
        let data = message.data(using: .utf8)!

        // 发送到广播地址
        let endpoint = NWEndpoint.hostPort(
            host: .ipv4(.broadcast),
            port: 2425
        )

        udpConnection = NWConnection(
            to: endpoint,
            using: .udp
        )

        udpConnection?.start(queue: .global())

        try await withCheckedThrowingContinuation { continuation in
            udpConnection?.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                self.handleMessage(message)
            }
        }
    }

    private func handleMessage(_ message: String) {
        do {
            let packet = try IPMsgPacket.decode(message)

            switch packet.command {
            case .BR_ENTRY, .ANSENTRY:
                // 发现新用户
                let user = DiscoveredUser(
                    name: packet.sender,
                    hostname: packet.hostname
                )

                Task { @MainActor in
                    if !discoveredUsers.contains(where: { $0.name == user.name }) {
                        discoveredUsers.append(user)
                    }
                }

            case .BR_EXIT:
                // 用户下线
                Task { @MainActor in
                    discoveredUsers.removeAll { $0.name == packet.sender }
                }

            default:
                break
            }
        } catch {
            print("Failed to parse message: \(error)")
        }
    }
}

public struct DiscoveredUser: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let hostname: String
}
```

---

### 任务 A3：集成测试

**Agent**: network-tester
**估时**: 10 分钟

#### 测试场景

**Tests/FluxQServicesTests/NetworkManagerTests.swift**:
```swift
import XCTest
@testable import FluxQServices

final class NetworkManagerTests: XCTestCase {
    func testStartStop() async throws {
        let manager = NetworkManager.shared

        XCTAssertFalse(manager.isRunning)

        try await manager.start()
        XCTAssertTrue(manager.isRunning)

        await manager.stop()
        XCTAssertFalse(manager.isRunning)
    }

    func testUserDiscovery() async throws {
        // 启动第一个实例
        let manager1 = NetworkManager.shared
        try await manager1.start()

        // 等待广播
        try await Task.sleep(for: .seconds(1))

        // 验证用户列表
        // (需要模拟第二个实例或使用实际网络测试)

        await manager1.stop()
    }
}
```

---

## 错误处理

### Agent 通信

**第 1 波（doc-writer + project-configurator）**:
- doc-writer 等待 project-configurator 确认 LICENSE 类型（MIT）
- project-configurator 广播 LICENSE 决策：
  ```
  SendMessage(type: "broadcast", content: "LICENSE 已设置为 MIT")
  ```

### 失败场景

**截图失败**:
- 记录错误日志
- 使用占位符文本："[截图待补充]"
- 继续后续任务

**CI 配置错误**:
- 验证 YAML 语法
- 使用 `act` 本地测试（可选）
- 首次 push 后观察 GitHub Actions 结果

**网络测试失败**:
- 检查防火墙设置
- 验证端口 2425 可用
- 记录详细错误日志

---

## 成功标准

### 任务 C（文档）
- ✅ README.md 更新完成，反映 v0.1.0 + v0.2.0 状态
- ✅ BUILD.md 包含验证过的构建命令
- ✅ USER_GUIDE.md 创建完成
- ✅ 所有 Markdown 格式正确

### 任务 D（配置）
- ✅ LICENSE 文件存在（MIT）
- ✅ .gitignore 完善
- ✅ 应用图标生成（至少基础版本）
- ✅ CI/CD workflow 创建并语法正确

### 任务 B（截图）
- ✅ 所有平台编译成功
- ✅ 至少 3 张截图（macOS/iOS/watchOS）
- ✅ 截图文件路径正确

### 任务 A（v0.2.0）
- ✅ IPMsgProtocol Package 编译通过
- ✅ FluxQServices Package 编译通过
- ✅ 单元测试覆盖率 > 80%
- ✅ 可以发送和接收 UDP 广播

### 整体验收
- ✅ 所有代码提交到 main 分支
- ✅ CI/CD 首次运行通过（或至少语法正确）
- ✅ 无明显的编译错误或警告

---

## 时间预期

| 阶段 | 估时 | 备注 |
|------|------|------|
| 第 1 波（C+D 并行） | 20-25 分钟 | 文档更新 + 项目配置 |
| 第 2 波（B） | 10-15 分钟 | 编译 + 截图 |
| 第 3 波（A 并行） | 35-45 分钟 | IPMsg 协议 + 服务层 + 测试 |
| **总计** | **70-90 分钟** | 约 1.5 小时 |

---

## 后续步骤

设计批准后，将调用 **writing-plans** skill 创建详细的实施计划（分步骤的 Task 列表）。

---

**设计状态**: ✅ 已批准
**下一步**: 调用 writing-plans skill
