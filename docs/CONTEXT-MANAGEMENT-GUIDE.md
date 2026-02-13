# FluxQ 自动上下文管理系统

## 概述

Claude Code 的上下文窗口有 200K tokens 的限制。当对话过长时，系统可能会丢失早期信息或完全停止响应。FluxQ 项目配置了一套自动上下文管理系统，通过三层防护机制帮助开发者及时发现并处理上下文膨胀问题。

### 三层防护机制

1. **Hookify 规则** -- 自动检测和提醒，在关键时刻触发上下文管理建议
2. **Statusline 监控** -- 状态栏实时显示上下文时间戳，随时掌握 session 状态
3. **手动 /context 分析** -- 按需查看详细的上下文使用情况和优化建议

### 核心指标

| 指标 | 值 | 说明 |
|------|------|------|
| 上下文窗口总量 | 200K tokens | Claude Code 单次对话的最大容量 |
| 警告阈值 | 85% (~170K) | 开始关注，建议 compact |
| 强烈建议阈值 | 90% (~180K) | 立即 compact 或保存进度 |
| 必须行动阈值 | 95% (~190K) | 保存所有状态，compact 或重启 |

---

## 组件说明

### 1. auto-save-before-stop (停止前检查)

- **文件**: `.claude/hookify.auto-save-before-stop.local.md`
- **触发事件**: `stop` -- 当 Claude Code 即将停止工作时触发
- **行为**: `warn` -- 显示检查清单提醒
- **用途**: 确保在 session 结束前保存任务状态、检查上下文使用率、确认 git 状态

**检查清单包含**:
- 任务状态保存（TaskList、TODO.md）
- 上下文管理（Token 阈值分级行动表）
- Git 状态检查（未提交更改、暂存修改）
- 继续任务的三种选项（compact、重启、继续）

### 2. context-overflow-detector (溢出检测)

- **文件**: `.claude/hookify.context-overflow-detector.local.md`
- **触发事件**: `prompt` -- 当用户输入匹配特定模式时触发
- **匹配模式**: 包含 `context`/`token` + `too long`/`full`/`limit`/`overflow`/`达到`/`过长`/`满了`，或包含 `compact`/`压缩上下文`/`上下文.*问题`
- **行为**: `warn` -- 显示上下文管理建议
- **用途**: 当用户提到上下文相关问题时，自动提供解决方案

**提供三种方案**:
1. 使用 `/compact` 压缩对话历史（推荐）
2. 保存任务并重启新 session
3. 使用 Agent Teams 并行执行

### 3. context-usage-advisor (/context 分析)

- **触发方式**: 用户运行 `/context` 命令
- **用途**: 按需查看当前上下文使用的详细情况，获取针对性的优化建议
- **输出内容**: 当前 token 使用量估算、使用率百分比、对应的行动建议

---

## Statusline 监控

### 实时显示

Statusline 在 Claude Code 界面底部持续显示当前 session 的状态信息，无需手动查询。

当前配置显示时间戳，帮助追踪 session 时长：

```json
{
  "statusLine": {
    "type": "command",
    "command": "echo \"Context: $(date +%H:%M)\""
  }
}
```

### 配置位置

Statusline 配置在全局设置文件中：

```
~/.claude/settings.json
```

在 `statusLine` 字段下配置。`type` 为 `command` 表示执行 shell 命令获取显示内容。

---

## 使用方法

### 监控上下文

1. **查看 statusline**: 界面底部始终显示当前状态
2. **运行 /context**: 获取详细的 token 使用分析
3. **理解警告级别**:
   - **< 85%**: 正常工作，无需特别处理
   - **85% (警告)**: 保存重要信息到文档，考虑 compact
   - **90% (强烈建议)**: 立即运行 `/compact` 压缩历史
   - **95% (必须行动)**: 保存所有状态后 compact 或重启 session

### 响应 Hook 提醒

当 Hook 触发时，会在界面上显示提醒信息：

- **停止前检查**: 按照检查清单逐项确认，确保工作不丢失
- **溢出检测**: 选择推荐的方案执行（通常是 `/compact`）

### 优化策略

以下策略可以有效减少上下文占用：

#### 定期 Compact

```
/compact
```

compact 会压缩对话历史，保留关键信息。建议在以下时机执行：
- 完成一个大型任务后
- 开始新阶段工作前
- 感觉响应变慢时

#### 禁用闲置 MCP

不使用的 MCP 服务器会占用上下文空间。在 `~/.claude/settings.json` 的 `enabledPlugins` 中，将不需要的插件设为 `false`。

#### 迁移 CLAUDE.md 到 Skills

如果 CLAUDE.md 内容过长，可以将部分内容迁移到 Skills 中。Skills 只在需要时加载，不会持续占用上下文。

#### 使用 Subagents

将独立的子任务分配给 Subagents（通过 Agent Teams 或 Task 工具）。每个 Subagent 使用独立的上下文窗口，不影响主 session。

---

## 最佳实践

### 何时 Compact

- 上下文使用率达到 85% 时
- 完成一个阶段性任务后
- 开始处理新的、不相关的任务前
- 对话中出现大量代码输出后

### 何时重启

- compact 后使用率仍然很高（> 90%）
- 需要切换到完全不同的工作内容
- session 运行时间过长，响应明显变慢

### 如何保存状态

在 compact 或重启前，确保以下信息已保存：

1. **任务列表**: 使用 `TaskList` 查看，将未完成任务记录到文档
2. **关键决策**: 将重要的技术决策写入 `MEMORY.md`
3. **Git 状态**: 提交或暂存所有重要修改
4. **进度记录**: 在任务描述或 TODO 中记录当前进度和下一步计划

---

## 故障排查

### Hooks 不触发

1. **检查 Hookify 插件是否启用**:
   - 确认 `~/.claude/settings.json` 中 `hookify@claude-plugins-official` 为 `true`

2. **检查规则文件是否存在**:
   ```bash
   ls .claude/hookify.*.local.md
   ```

3. **检查规则格式**:
   - 确认 YAML frontmatter 格式正确（`---` 包围）
   - 确认 `enabled: true`
   - 确认 `event` 和 `pattern`/`conditions` 设置正确

4. **检查匹配条件**:
   - `auto-save-before-stop`: 仅在 `stop` 事件触发
   - `context-overflow-detector`: 仅在用户输入匹配正则表达式时触发

### Statusline 不显示

1. **检查全局设置**:
   ```bash
   cat ~/.claude/settings.json
   ```
   确认存在 `statusLine` 配置

2. **检查命令是否可执行**:
   ```bash
   echo "Context: $(date +%H:%M)"
   ```
   在终端中测试命令是否正常输出

3. **重启 Claude Code**: 修改配置后可能需要重启才能生效

### 阈值调整

如果默认阈值不适合你的工作模式，可以修改 `.claude/hookify.auto-save-before-stop.local.md` 中的阈值表：

```markdown
| 使用率 | 约 Token 数 | 级别 | 行动 |
|--------|-------------|------|------|
| < 85%  | < 170K      | 正常 | 继续工作,定期检查 |
| 85%    | ~170K       | 警告 | 建议运行 /compact |
| 90%    | ~180K       | 强烈建议 | 立即 /compact 或保存进度 |
| 95%    | ~190K       | 必须行动 | 立即保存所有状态 |
```

根据实际使用情况，可以适当调低或调高阈值百分比。

---

## 参考链接

- [Claude Code 官方文档](https://docs.anthropic.com/en/docs/claude-code)
- [Hookify 插件文档](https://github.com/anthropics/claude-code-plugins)
- [IP Messenger 协议](http://ipmsg.org/)
- [FluxQ 项目 CLAUDE.md](/CLAUDE.md)
