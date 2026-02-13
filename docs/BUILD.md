# FluxQ 构建指南

## 环境要求

- **Xcode**: 15.0 或更高
- **macOS**: 14.0 (Sonoma) 或更高
- **Swift**: 5.9 或更高

## 系统版本要求

| 平台 | 最低版本 |
|------|---------|
| macOS | 14 (Sonoma) |
| iOS | 17 |
| iPadOS | 17 |
| watchOS | 10 |

## 克隆项目

```bash
git clone git@github.com:martinadamsdev/FluxQ.git
cd FluxQ
```

## 打开项目

```bash
open FluxQ.xcworkspace
```

或直接在 Xcode 中打开 `FluxQ.xcworkspace`。

## 项目结构

```
FluxQ/
├── FluxQ.xcworkspace          # 主工作空间
├── App/
│   ├── FluxQ/                 # macOS/iOS/iPadOS 应用
│   └── FluxQWatch/            # watchOS 应用
├── Modules/                    # 本地 Swift Packages
│   ├── IPMsgProtocol/
│   ├── FluxQModels/
│   ├── FluxQServices/
│   └── FluxQUI/
└── Tests/
```

## 调试构建

### macOS

```bash
# 命令行构建
xcodebuild -workspace FluxQ.xcworkspace \
           -scheme FluxQ \
           -destination 'platform=macOS' \
           build

# 或在 Xcode 中
# 1. 选择 FluxQ scheme
# 2. 选择 My Mac 目标
# 3. Product > Run (⌘R)
```

### iOS / iPadOS

```bash
# 命令行构建(模拟器)
xcodebuild -workspace FluxQ.xcworkspace \
           -scheme FluxQ \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
           build

# 或在 Xcode 中
# 1. 选择 FluxQ scheme
# 2. 选择模拟器或真机
# 3. Product > Run (⌘R)
```

### watchOS

watchOS 应用通过配对的 iOS 应用自动安装。

```bash
# 在 Xcode 中
# 1. 选择 FluxQWatch scheme
# 2. 选择 Watch 模拟器
# 3. Product > Run (⌘R)
```

## 运行测试

```bash
# 运行所有测试
swift test

# 或使用 xcodebuild
xcodebuild -workspace FluxQ.xcworkspace \
           -scheme FluxQ \
           -destination 'platform=macOS' \
           test

# 在 Xcode 中: Product > Test (⌘U)
```

## 发布构建

### macOS

```bash
xcodebuild -workspace FluxQ.xcworkspace \
           -scheme FluxQ \
           -configuration Release \
           -derivedDataPath build \
           -destination 'platform=macOS' \
           build

# 产物位于: build/Build/Products/Release/FluxQ.app
```

创建 DMG:
```bash
# 需要安装 create-dmg
brew install create-dmg

create-dmg \
  --volname "FluxQ" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "FluxQ.app" 200 190 \
  --hide-extension "FluxQ.app" \
  --app-drop-link 600 185 \
  "FluxQ-v1.0.0-macos.dmg" \
  "build/Build/Products/Release/FluxQ.app"
```

### iOS / iPadOS

```bash
xcodebuild -workspace FluxQ.xcworkspace \
           -scheme FluxQ \
           -configuration Release \
           -archivePath build/FluxQ.xcarchive \
           -destination 'generic/platform=iOS' \
           archive

# 导出 IPA
xcodebuild -exportArchive \
           -archivePath build/FluxQ.xcarchive \
           -exportPath build/ \
           -exportOptionsPlist ExportOptions.plist
```

## 代码签名

### macOS

1. 在 Xcode 中打开项目
2. 选择 FluxQ target
3. Signing & Capabilities 标签
4. 选择你的 Team
5. Xcode 会自动管理签名

### iOS / iPadOS

需要 Apple Developer 账号:
1. 在 Xcode 中打开项目
2. 选择 FluxQ target
3. Signing & Capabilities 标签
4. 选择你的 Team
5. 配置 Bundle Identifier

## 代码分析

```bash
# Swift 代码分析
swift build --static-swift-stdlib

# 或使用 SwiftLint
brew install swiftlint
swiftlint lint
```

## 依赖管理

项目使用 Swift Package Manager:

- **本地 Packages**: 位于 `Modules/` 目录
- **第三方依赖**: 通过 Xcode > File > Add Packages 添加

## 常见问题

### Q: 编译失败,提示找不到模块

A: 清理构建缓存:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

然后重新构建。

### Q: SwiftData 模型迁移错误

A: 删除应用数据:
```bash
# macOS
rm -rf ~/Library/Containers/com.martinadams.FluxQ/

# iOS 模拟器
xcrun simctl --set simulators erase all
```

### Q: 网络权限被拒绝

A: 在 Xcode 中:
1. 选择 target
2. Signing & Capabilities
3. 添加 "Incoming Connections (Server)" 权限

## 调试技巧

### 网络调试

使用 `os_log` 查看网络日志:
```swift
import os

let logger = Logger(subsystem: "com.martinadams.FluxQ", category: "network")
logger.debug("UDP broadcast sent to \(ipAddress)")
```

在 Console.app 中过滤: `subsystem:com.martinadams.FluxQ`

### 数据库调试

查看 SwiftData 数据库:
```bash
# macOS
open ~/Library/Containers/com.martinadams.FluxQ/Data/Library/Application\ Support/
```

使用 DB Browser for SQLite 打开 `.sqlite` 文件。

## 性能分析

在 Xcode 中:
1. Product > Profile (⌘I)
2. 选择 Instruments 模板:
   - Time Profiler: CPU 使用
   - Allocations: 内存分配
   - Leaks: 内存泄漏
   - Network: 网络活动

## 贡献

请阅读 CONTRIBUTING.md 了解如何贡献代码。

## 许可证

见 LICENSE 文件。
