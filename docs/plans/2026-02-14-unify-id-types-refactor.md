# 重构计划：统一 ID 类型为 UUID

> **前置条件**：Phase 4 聊天体验增强已完成

**目标**：将所有模型的 `id` 字段从 `String` 统一为 `UUID`，提升类型安全性

**优先级**：低（代码质量改进，非功能需求）

---

## 背景

当前 `User`、`Message`、`Conversation` 三个 SwiftData 模型均使用 `String` 类型的 ID（值为 `UUID().uuidString`）。这源于早期与 IP Messenger 协议的字符串交互需求，但带来以下问题：

1. **类型不安全** — 任意字符串均可作为 ID 传入，编译器无法检查
2. **语义模糊** — `String` 无法表达"这是一个唯一标识符"的意图
3. **冗余转换** — 多处代码需要 `UUID().uuidString`，而非直接使用 `UUID()`

## 影响范围

### 模型层 (FluxQModels)

| 文件 | 变更 |
|------|------|
| `Message.swift` | `id: String` → `id: UUID`，`senderID`/`conversationID` → `senderID`/`conversationID` 保持 `String`（外键引用） |
| `User.swift` | `id: String` → `id: UUID` |
| `Conversation.swift` | `id: String` → `id: UUID`，`participantIDs: [String]` 保持（协议交互层） |
| `Enums.swift` | 无变更 |

### 服务层 (FluxQServices)

| 文件 | 变更 |
|------|------|
| `NetworkManager.swift` | `discoveredUsers` key 类型适配 |
| `DiscoveredUser.swift` | `id` 类型变更 |
| `HeartbeatService.swift` | 适配新 ID 类型 |
| `TCPMessageService.swift` | 连接池 key、用户查询适配 |
| `RecallService.swift` | `recentRecalls` key 类型 `String` → `UUID` |
| `TypingStateService.swift` | `typingUsers` key 适配 |

### 测试层

- `FluxQModelsTests/` — 所有测试中的 ID 字面量从 `"xxx"` 改为 `UUID()` 或固定 UUID
- `FluxQServicesTests/` — 同上

### 协议交互层（不变更）

- `IPMsgPacket.sender` 保持 `String` — 这是协议规范
- 在服务层做 `UUID ↔ String` 转换（边界转换）

## 实施步骤

### Task 1: 更新 FluxQModels

1. 修改 `User.swift`：`id: String` → `id: UUID`，更新 `init`
2. 修改 `Message.swift`：`id: String` → `id: UUID`
3. 修改 `Conversation.swift`：`id: String` → `id: UUID`
4. 更新所有 FluxQModels 测试
5. 运行测试验证通过

### Task 2: 更新 FluxQServices

1. 更新 `DiscoveredUser.swift`
2. 适配 `NetworkManager.swift` 中的 dictionary key
3. 适配所有 Phase 3/4 服务
4. 更新所有 FluxQServices 测试
5. 运行测试验证通过

### Task 3: 更新应用层

1. 适配 `FluxQApp.swift` 中的 SwiftData schema
2. 适配所有 View 中的 ID 引用
3. Xcode 构建验证

### Task 4: SwiftData 迁移

1. 创建 `ModelMigrationPlan` 处理 `String` → `UUID` 的数据迁移
2. 测试迁移路径（旧数据 → 新格式）

## 设计决策

### 外键引用策略

`Message.senderID` 和 `Message.conversationID` 是否也改为 `UUID`？

**方案 A：全部改为 UUID** — 最一致，但需要所有查询都用 UUID 匹配
**方案 B：保持 String** — ID 字段用 UUID，外键用 `uuid.uuidString` 的 String → 实施时决定

### 协议边界转换

在 `NetworkManager` 中做转换：
```swift
// 收到协议包时
let userId = discoveredUsers.first { $0.value.nickname == packet.sender }?.key

// 发送协议包时
let packet = IPMsgPacket(sender: user.nickname, ...)
```

## 验收标准

- [ ] 所有模型 `id` 字段类型为 `UUID`
- [ ] 编译器层面阻止非 UUID 字符串传入 ID 参数
- [ ] 所有现有测试通过
- [ ] SwiftData 迁移方案已实现并测试
- [ ] 协议交互层正常工作（UDP 发现、TCP 消息等）

---

**预计时间**：0.5 天
**创建日期**：2026-02-14
**状态**：待 Phase 4 完成后实施
