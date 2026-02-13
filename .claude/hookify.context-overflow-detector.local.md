---
name: context-overflow-detector
enabled: true
event: prompt
conditions:
  - field: user_prompt
    operator: regex_match
    pattern: (context|token).*(too long|full|limit|overflow|达到|过长|满了)|compact|压缩上下文|上下文.*问题
action: warn
---

## ⚠️ 上下文管理建议

检测到你提到了上下文相关问题!

### 📊 基于使用率的分级响应 (200K tokens 标准)

#### 60-85% (120K-170K tokens) — 准备阶段

- **状态**: 正常运行,但应开始关注
- **建议**:
  - 完成当前大型任务后主动 `/compact`
  - 将重要决策/发现写入 MEMORY.md
  - 避免在主线程中执行大规模代码搜索,改用 Subagents
  - 精简不必要的文件读取

#### 85-90% (170K-180K tokens) — 警告级别

- **状态**: 即将接近上限,需要主动管理
- **行动**:
  1. **保存关键信息**: 将当前任务状态写入 MEMORY.md 或 TODO.md
  2. **运行 `/compact`**: 压缩对话历史,释放上下文空间
  3. **检查任务列表**: 使用 `TaskList` 确认进度
  4. **精简后续操作**: 避免大段代码输出,使用精确的文件编辑

#### 90-95% (180K-190K tokens) — 紧急行动

- **状态**: 高风险,可能影响响应质量
- **行动**:
  1. **立即保存所有状态**: 任务进度、git 状态、关键发现
  2. **立即 `/compact`**: 不要再做其他操作,先 compact
  3. **如果 compact 后仍然过高**: 准备保存并重启 session
  4. **通知用户**: 说明上下文状况,建议采取措施

#### >95% (>190K tokens) — 立即 compact 或重启

- **状态**: 危急,必须立即处理
- **行动**:
  1. **停止当前工作**
  2. **保存所有未完成状态到文件**
  3. **执行 `/compact`**
  4. **如果 compact 不够**: 保存任务后重启新 session

---

### 🎯 具体行动方案

**方案 1: 使用 /compact (推荐)**
```
/compact
```
- **作用**: 自动压缩对话历史,保留关键信息
- **优点**: 不丢失上下文,继续当前任务
- **耗时**: ~30秒
- **建议**: 当前使用率 > 80% 时使用

**方案 2: 保存任务并重启**
1. 保存当前任务列表状态
2. 将关键信息写入 MEMORY.md
3. 提交或暂存 git 更改
4. 重启新 session,从 MEMORY.md 恢复上下文

**方案 3: Agent Teams + 并行执行**
如果有多个独立任务,使用 Subagents 分散上下文压力:
- 每个 Subagent 使用独立上下文窗口
- 适合代码搜索、文件分析等可并行任务

---

### 🔧 上下文优化策略

#### 1. MCP 服务器优化
- 减少不必要的 MCP 工具调用
- 批量处理 MCP 请求而非逐个调用
- 优先使用轻量级工具 (Glob/Grep) 替代重量级搜索

#### 2. CLAUDE.md 优化
- 确保 CLAUDE.md 简洁、结构化
- 避免在 CLAUDE.md 中放置大段冗余内容
- 使用引用链接而非内联大段文档

#### 3. Subagents 策略
- **代码搜索**: 使用 `subagent_type="Explore"` 进行深度搜索
- **独立任务**: 将不依赖主上下文的任务委托给 Subagents
- **文件分析**: 大文件的分析工作交给 Subagents 处理
- **好处**: 每个 Subagent 有独立上下文,不消耗主线程空间

#### 4. 日常习惯
- 完成大型任务后立即 compact
- 开始新阶段工作前 compact
- 感觉响应变慢时 compact
- 看到 "context" 警告时立即 compact
- 将大任务拆分为多个小任务

---

**当前建议**: 先运行 `/compact`,如果还有问题再考虑重启。定期使用 `/context` 监控使用率!
