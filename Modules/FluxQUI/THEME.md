# FluxQ 主题系统

FluxQ 使用统一的主题系统，自动支持浅色和深色模式。

## 颜色系统

### Asset Catalog 颜色

所有主题颜色都定义在 Asset Catalog 中，自动适配浅色/深色模式：

| 颜色名称 | 用途 | 浅色模式 | 深色模式 |
|---------|------|---------|---------|
| `AccentColor` | 系统强调色 | #00C733 | #00E640 |
| `FluxQGreen` | 品牌主色 | #00C733 | #00E640 |
| `BubbleBackground` | 聊天气泡背景 | #F2F2F2 | #3C3C3C |

### Swift 颜色扩展

在 `FluxQUI` 模块中定义的颜色：

```swift
import FluxQUI

// 主题色
.foregroundColor(.fluxqGreen)
.tint(.fluxqGreen)

// 聊天气泡
.backgroundColor(.fluxqBubbleMe)      // 自己的消息（绿色）
.backgroundColor(.fluxqBubbleOther)   // 对方的消息（灰色）

// 状态指示器
.foregroundColor(.fluxqOnline)   // 在线（绿色）
.foregroundColor(.fluxqAway)     // 离开（橙色）
.foregroundColor(.fluxqBusy)     // 忙碌（红色）
.foregroundColor(.fluxqOffline)  // 离线（灰色）

// 语义化颜色（自动适配主题）
.foregroundColor(.fluxqTextPrimary)        // 主要文本
.foregroundColor(.fluxqTextSecondary)      // 次要文本
.backgroundColor(.fluxqBackground)          // 主背景
.backgroundColor(.fluxqBackgroundSecondary) // 次背景
```

## 使用示例

### 1. 基础视图

```swift
import SwiftUI
import FluxQUI

struct MyView: View {
    var body: some View {
        VStack {
            Text("Hello")
                .foregroundColor(.fluxqTextPrimary)

            Button("Action") {
                // action
            }
            .tint(.fluxqGreen)
        }
        .background(Color.fluxqBackground)
    }
}
```

### 2. 聊天气泡

```swift
struct MessageBubble: View {
    let text: String
    let isMe: Bool

    var body: some View {
        Text(text)
            .padding()
            .background(isMe ? Color.fluxqBubbleMe : Color.fluxqBubbleOther)
            .foregroundColor(isMe ? .white : .fluxqTextPrimary)
            .cornerRadius(16)
    }
}
```

### 3. 状态指示器

```swift
struct UserStatus: View {
    let status: Status

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    var statusColor: Color {
        switch status {
        case .online: return .fluxqOnline
        case .away: return .fluxqAway
        case .busy: return .fluxqBusy
        case .offline: return .fluxqOffline
        }
    }
}
```

### 4. 主题管理

```swift
import FluxQUI

struct ContentView: View {
    @State private var themeManager = ThemeManager.shared

    var body: some View {
        VStack {
            // 内容
        }
        .themedColorScheme(themeManager)
    }
}
```

### 5. 手动切换主题

```swift
// 切换到深色模式
ThemeManager.shared.setColorScheme(.dark)

// 切换到浅色模式
ThemeManager.shared.setColorScheme(.light)

// 跟随系统
ThemeManager.shared.setColorScheme(nil)
```

## 添加新颜色

### 1. 在 Asset Catalog 中添加

1. 打开 `FluxQ/Assets.xcassets` 或 `FluxQWatch/Assets.xcassets`
2. 右键 -> New Color Set
3. 命名颜色（如 `MyColor`）
4. 设置 Universal 颜色（浅色模式）
5. 点击 + -> Appearance -> Dark Appearance
6. 设置深色模式颜色

### 2. 在代码中使用

```swift
// 直接使用
Color("MyColor")

// 或添加到 Colors.swift 扩展
extension Color {
    public static let myColor = Color("MyColor")
}
```

## 颜色值参考

### FluxQ 品牌绿色

- **浅色模式**: `#00C733` / `rgb(0, 199, 51)`
- **深色模式**: `#00E640` / `rgb(0, 230, 64)`

深色模式使用更亮的绿色以保证在深色背景上的可读性。

### 系统颜色映射

| 平台 | 背景色 | 次要背景 | 控件背景 |
|------|-------|---------|---------|
| iOS | `.systemBackground` | `.secondarySystemBackground` | `.systemGray5` |
| macOS | `.windowBackgroundColor` | `.controlBackgroundColor` | `.controlBackgroundColor` |
| watchOS | `.black` | `.gray.opacity(0.2)` | `.gray.opacity(0.2)` |

## 最佳实践

1. ✅ **优先使用语义化颜色**：使用 `.fluxqTextPrimary` 而不是 `.black`
2. ✅ **避免硬编码颜色**：使用 Asset Catalog 定义颜色
3. ✅ **测试两种主题**：确保在浅色和深色模式下都可读
4. ✅ **使用系统颜色**：iOS/macOS 的系统颜色会自动适配主题
5. ❌ **不要硬编码 RGB 值**：使用 `Color(red:green:blue:)` 不会自动适配主题

## 调试技巧

### 预览两种主题

```swift
#Preview("Light") {
    MyView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    MyView()
        .preferredColorScheme(.dark)
}
```

### 强制使用特定主题

```swift
// 仅用于调试
MyView()
    .preferredColorScheme(.dark)
```
