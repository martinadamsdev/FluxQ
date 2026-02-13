# FluxQ 项目文档

FluxQ 是一个基于 IP Messenger 协议的现代即时通讯应用，支持 iOS、macOS 和 watchOS 平台。

## 项目架构

### 模块化设计

项目采用 Swift Package Manager 进行模块化管理：

```
FluxQ/
├── FluxQ/                    # iOS/macOS 主应用
├── FluxQWatch/              # watchOS 应用
├── Modules/
│   ├── IPMsgProtocol/       # IP Messenger 协议实现
│   ├── FluxQServices/       # 网络服务层
│   ├── FluxQModels/         # 数据模型
│   └── FluxQUI/             # UI 主题系统
└── scripts/                 # 构建脚本
```

### 核心模块说明

#### IPMsgProtocol
- **职责**：IP Messenger 协议的 Swift 实现
- **核心类型**：
  - `IPMsgPacket`：协议数据包（格式：`version:packetNo:sender:hostname:command:payload`）
  - `IPMsgCommand`：协议命令定义
  - `IPMsgError`：协议错误类型
- **测试**：`Tests/IPMsgProtocolTests/`

#### FluxQServices
- **职责**：网络通信和用户发现
- **核心类型**：
  - `NetworkManager`：UDP 广播和消息收发（端口 2425）
  - `DiscoveredUser`：发现的用户信息
- **并发模型**：使用 `@MainActor` 确保线程安全

#### FluxQModels
- **职责**：核心数据模型
- **核心类型**：
  - `User`：用户模型
  - `Message`：消息模型
  - `Conversation`：会话模型

#### FluxQUI
- **职责**：UI 主题和样式系统
- **核心类型**：
  - `ThemeManager`：主题管理器
  - `Colors`：颜色定义

## 技术栈

- **语言**：Swift 5.9+
- **最低平台版本**：
  - macOS 14.0+
  - iOS 17.0+
  - watchOS 10.0+
- **并发**：Swift Concurrency（async/await、actors、Sendable）
- **网络**：Network.framework（UDP 广播）
- **测试框架**：Swift Testing（使用 `@Test` 和 `#expect`）

## 开发规范

### 代码风格

1. **并发安全**
   - UI 相关类使用 `@MainActor`
   - 数据模型遵循 `Sendable` 协议
   - 避免数据竞争

2. **错误处理**
   - 使用类型化错误（遵循 `Error` 协议）
   - 避免使用 `try!` 和 `force unwrap`
   - 为网络操作提供清晰的错误信息

3. **命名规范**
   - 类型使用 `PascalCase`
   - 变量和函数使用 `camelCase`
   - 私有属性使用 `private` 或 `private(set)`

4. **测试**
   - 使用 Swift Testing 框架
   - 测试文件命名：`*Tests.swift`
   - 每个公共 API 都应有对应测试

### 模块依赖规则

```
FluxQ/FluxQWatch → FluxQServices → IPMsgProtocol
                 → FluxQModels
                 → FluxQUI
```

- **禁止循环依赖**
- IPMsgProtocol 不依赖其他模块（纯协议实现）
- FluxQServices 只依赖 IPMsgProtocol
- FluxQModels 独立存在
- 应用层可以依赖所有模块

### 敏感文件

以下文件包含重要配置，修改前请仔细确认：

- `**/*.entitlements`：应用权限配置
- `**/Info.plist`：应用元数据
- `**/*.xcodeproj/**`：Xcode 项目配置
- `scripts/generate-icons.sh`：图标生成脚本

## 构建和测试

### 运行测试

```bash
# 运行所有测试
swift test

# 运行特定模块测试
swift test --package-path Modules/IPMsgProtocol
swift test --package-path Modules/FluxQServices
swift test --package-path Modules/FluxQModels
```

### 生成图标

```bash
./scripts/generate-icons.sh
```

需要依赖：
- ImageMagick
- Python 3 + Pillow

脚本会自动生成所有平台所需的图标尺寸。

## IP Messenger 协议

### 数据包格式

```
version:packetNo:sender:hostname:command:payload
```

### 默认端口

- UDP：2425

### 用户发现

使用 UDP 广播进行局域网内用户发现和消息传递。

## Git 工作流

- **主分支**：`main`
- **功能分支**：`feature/*`
- **提交规范**：使用清晰的提交信息，说明修改的原因（why）而非内容（what）

## 相关资源

- IP Messenger 协议：http://ipmsg.org/
- Swift Concurrency：https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- Swift Testing：https://developer.apple.com/documentation/testing
