# 聊天消息收发与文件传输 — 设计文档

日期：2026-02-17

## 问题

发现页到聊天的导航已实现，但存在三个断裂环节：
1. ConversationListView 使用硬编码假数据（SampleConversation），不显示 SwiftData 中的真实会话
2. ConversationDetailView 的消息发送只存本地，不经网络发送；消息接收链路不存在
3. 文件传输功能完全缺失（0%）
4. 消息操作（撤回/转发）服务层已实现但 UI 未接线

## 设计目标

采用垂直切片方案，每个切片从服务层到 UI 到测试一次性贯通（TDD 风格）。

## 方案：垂直切片 × TDD

四个切片按依赖顺序执行：

```
切片 1 → 切片 2 → 切片 3
                 → 切片 4（可与切片 3 并行）
```

---

## 切片 1：会话列表真实化

### 问题

ConversationListView 使用 `SampleConversation` 静态数据，ConversationService 创建的真实 Conversation 在列表中不可见。

### 方案

替换 `@State sampleConversations` 为 SwiftData `@Query`。

### 修改文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `FluxQ/Views/ConversationListView.swift` | 重写 | `@Query` 替换假数据；行视图改用 Conversation 属性；删除 SampleConversation |
| `Modules/FluxQModels/.../Conversation.swift` | 扩展 | 添加 `displayName` 计算属性（从 participants 取昵称）|

### 数据映射

```
SampleConversation.name       → conversation.displayName (participants.first.nickname)
SampleConversation.lastMessage → conversation.messages?.last?.content ?? "暂无消息"
SampleConversation.timeString  → conversation.lastMessageTimestamp (DateFormatter)
SampleConversation.unreadCount → conversation.unreadCount
SampleConversation.avatarColor → UserAvatarView(avatarData:)
```

### 核心代码

```swift
@Query(sort: \Conversation.lastMessageTimestamp, order: .reverse)
private var conversations: [Conversation]
```

### 测试

- 单元测试：Conversation.displayName 计算属性
- 集成测试：ConversationService 创建会话 → @Query 能查到
- UI 测试：会话列表显示正确数据；空状态显示

---

## 切片 2：消息收发闭环

### 问题

- `sendMessage()` 只存 SwiftData，不发网络
- 收到的网络消息没有写入 SwiftData
- `currentUserID` 是硬编码 UUID

### 新增文件

#### `FluxQ/Services/CurrentUserService.swift`

从 NetworkManager 获取当前用户 senderName/hostname，在 SwiftData 中 findOrCreate 当前 User 对象。

```swift
struct CurrentUserService {
    static func currentUser(
        networkManager: NetworkManager,
        in context: ModelContext
    ) -> User
}
```

#### `FluxQ/Services/MessageReceiveHandler.swift`

接收消息的持久化处理器。

```swift
struct MessageReceiveHandler {
    static func handleReceivedMessage(
        packet: IPMsgPacket,
        in context: ModelContext
    )
}
```

逻辑：
1. 按 sender/hostname 查找/创建 User
2. 查找/创建 Conversation
3. 创建 Message（senderID = 对方, status: .received）
4. 更新 Conversation.lastMessageTimestamp
5. 发 RECVMSG 确认

### 修改文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `ConversationDetailView.swift` | 修改 | 接线 TCPMessageService；替换硬编码 UUID → CurrentUserService |
| `NetworkManager.swift` | 修改 | 添加消息接收回调钩子（delegate/closure） |

### 发送链路

```
用户点发送
  → Message 存 SwiftData（status: .sending）
  → 查找对方 User 的 ipAddress + port
  → TCPMessageService.sendMessage(content:to:port:)
  → 成功 → Message.status = .sent
  → 失败 → Message.status = .failed（显示重发按钮）
```

### 接收链路

```
NetworkManager 收到 UDP/TCP 包
  → 解析为 IPMsgPacket（command: .SENDMSG）
  → MessageReceiveHandler.handleReceivedMessage(packet:in:)
  → SwiftData @Query 自动刷新 UI
```

### 测试

- 单元测试：CurrentUserService 查找/创建；MessageReceiveHandler 解析+持久化；发送失败 status 正确
- 集成测试：发送 → TCPMessageService 调用验证；接收 → Message 出现在 SwiftData；端到端收发确认
- UI 测试：发送后气泡出现；接收后列表刷新；失败显示重发

---

## 切片 3：文件传输

### 问题

文件传输功能完全缺失。IP Messenger 协议支持文件传输（GETFILEDATA/RELEASEFILES/GETDIRFILES 命令已在 IPMsgCommand 中定义）。

### 协议层扩展（IPMsgProtocol）

新增 `FileMetadata` 类型：

```swift
public struct FileMetadata: Sendable, Equatable {
    public let fileID: Int
    public let fileName: String
    public let fileSize: Int64
    public let modificationTime: Date
    public let fileAttribute: FileAttribute  // .regular, .directory

    // 从 SENDMSG payload 解析
    // 格式: "fileID\afileName:fileSize:modTime:fileAttr:\a"
    public static func parse(from payload: String) -> [FileMetadata]
}

public enum FileAttribute: UInt32, Sendable {
    case regular = 0x01
    case directory = 0x02
    case symlink = 0x04
    case clipboard = 0x20
}
```

FILEATTACHOPT (0x00200000) 标志处理。

### 数据模型（FluxQModels）

```swift
@Model
public final class FileTransfer {
    @Attribute(.unique) public var id: UUID
    public var conversationID: UUID
    public var messageID: UUID?
    public var senderID: UUID
    public var fileName: String
    public var fileSize: Int64
    public var transferredBytes: Int64
    public var status: TransferStatus   // .pending/.transferring/.completed/.failed/.cancelled
    public var direction: TransferDirection  // .outgoing/.incoming
    public var localPath: String?
    public var timestamp: Date
    public var completedAt: Date?
    public var lastOffset: Int64        // 断点续传
}

public enum TransferStatus: String, Codable { ... }
public enum TransferDirection: String, Codable { ... }
```

Message 模型扩展：
```swift
public var fileAttachmentID: UUID?
public var messageType: MessageType  // .text / .file / .image
```

### 服务层（FluxQServices）

```
FileTransferService（协调者）
├── FileSender
│   ├── 构造 SENDMSG + FILEATTACHOPT payload
│   ├── 启动 TCP 监听等待 GETFILEDATA
│   ├── 分块发送（64KB blocks）
│   ├── 支持 offset（断点续传）
│   └── 完成/取消处理
├── FileReceiver
│   ├── 解析 FileMetadata
│   ├── 发送 GETFILEDATA（含 offset）
│   ├── 接收数据流写入本地
│   └── 完成后发 RELEASEFILES
└── TransferProgressTracker
    ├── 实时进度（bytes/total）
    ├── 传输速率计算
    └── FileTransfer.transferredBytes 同步
```

### UI 层

| 组件 | 位置 | 功能 |
|------|------|------|
| 文件选择器 | ConversationDetailView 快捷操作栏 | 选择文件发送 |
| 文件消息气泡 | MessageBubbleView 扩展 | 文件名、大小、进度条 |
| 接收确认 sheet | ConversationDetailView | 对方发文件时确认 |
| 传输进度视图 | 内嵌消息气泡 | 实时进度 + 取消 |
| 传输历史 | SettingsView 子页面 | 所有传输记录 |

### 发送流程

```
用户选文件 → FileTransferService.send(file:to:)
  → 构造 SENDMSG + FILEATTACHOPT payload
  → 创建 FileTransfer（status: .pending）
  → UDP 广播通知对方
  → 等待 GETFILEDATA
  → TCP 分块发送（64KB）
  → 进度实时更新
  → 完成 → status: .completed
```

### 接收流程

```
收到 SENDMSG + FILEATTACHOPT
  → 解析 FileMetadata → 显示接收确认
  → 确认 → 发 GETFILEDATA（offset 支持续传）
  → TCP 接收数据流 → 写入本地
  → 完成 → 发 RELEASEFILES → status: .completed
```

### 测试

- 单元测试：FileMetadata 解析（各种格式）；FileTransfer CRUD；FileSender 分块逻辑（0字节、64KB、超大）；FileReceiver offset 续传
- 集成测试：发送 → FILEATTACHOPT payload 正确；GETFILEDATA → TCP 连接 → 数据传输；断点续传 offset 恢复
- 性能测试：大文件吞吐量（100MB+）；并发多文件传输；内存使用（分块不爆内存）
- UI 测试：文件选择 → 气泡正确显示；进度条实时更新；取消传输

---

## 切片 4：消息操作接线

### 问题

RecallService 和 MessageActionService 已实现并有测试，但 ConversationDetailView 的 UI 回调是空壳。

### 撤回接线

```swift
// ConversationDetailView.recallMessage()
// → RecallService.recallMessage(packetNo:, to: ipAddress)
// → UDP 广播 RECALLMSG
// → 本地 message.isRecalled = true
```

接收撤回处理（新增）：
- NetworkManager 收到 RECALLMSG → 按 packetNo 找到 Message → 标记 isRecalled

### 转发接线

```swift
// contextMenu → 转发
// → 弹出会话/联系人选择器
// → MessageActionService.forwardMessage(content:to:port:)
```

新增 UI：转发目标选择器。

### 测试

- 单元测试：撤回时间窗口（120秒）；接收撤回命令标记消息
- 集成测试：发送撤回 → 对方标记；转发 → 目标收到
- UI 测试：撤回后气泡变"消息已撤回"；超120秒撤回选项消失；转发选择器

---

## 测试总体策略

| 测试类型 | 框架 | 范围 | 数量估计 |
|----------|------|------|---------|
| 单元测试 | Swift Testing | 所有服务/模型逻辑 | ~60+ 新增 |
| 集成测试 | Swift Testing | 跨服务交互、SwiftData 持久化 | ~20+ 新增 |
| UI 端对端测试 | XCUITest | 关键用户路径 | ~10+ 新增 |
| 性能测试 | Swift Testing + measure | 文件传输、消息吞吐 | ~5+ 新增 |

### UI 端对端关键路径

1. 发现用户 → 点击 → 进入聊天页
2. 发送文本消息 → 消息气泡出现
3. 选择文件 → 发送 → 进度显示 → 完成
4. 撤回消息 → 气泡变化
5. 断点续传场景

## 模块依赖

```
FluxQ (应用层)
├── ConversationDetailView → TCPMessageService, FileTransferService
├── ConversationListView → @Query Conversation
├── MessageReceiveHandler → ConversationService
└── CurrentUserService → NetworkManager

FluxQServices
├── FileTransferService → IPMsgProtocol (FileMetadata)
├── TCPMessageService (已有)
└── NetworkManager (已有)

FluxQModels
├── FileTransfer (@Model, 新增)
├── Conversation (@Model, 扩展 displayName)
└── Message (@Model, 扩展 fileAttachmentID/messageType)

IPMsgProtocol
└── FileMetadata (新增, 无外部依赖)
```

## 三平台行为

所有切片功能在 iPhone、iPad、macOS 三平台行为一致。文件选择器使用平台原生 API：
- iOS: `UIDocumentPickerViewController`
- macOS: `NSOpenPanel`
