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

### 🎯 立即行动方案

**🔧 方案 1: 使用 /compact (推荐)**
```
/compact
```
- **作用**: 自动压缩对话历史,保留关键信息
- **优点**: 不丢失上下文,继续当前任务
- **耗时**: ~30秒
- **建议**: 当前使用率 > 80% 时使用

**💾 方案 2: 保存任务并重启**
1. **保存当前状态**:
   ```bash
   # 保存任务列表
   TaskList > /tmp/tasks-backup.txt

   # 保存 git 状态
   git status > /tmp/git-backup.txt
   ```

2. **记录关键信息**:
   - 当前正在做什么
   - 下一步计划
   - 重要的决策/发现

3. **重启新 session**:
   - 退出当前对话
   - 开始新对话
   - 从备份恢复任务

**🚀 方案 3: Agent Teams + 并行执行**
如果有多个独立任务:
```
# 创建 team
TeamCreate(team_name="继续任务")

# 分配任务给 agents
Task(subagent_type="general-purpose", ...)
```
agents 使用独立上下文,不影响主 session

### 📊 预防措施

**定期 compact 策略**:
- ✅ 完成大型任务后立即 compact
- ✅ 开始新阶段工作前 compact
- ✅ 感觉响应变慢时 compact
- ✅ 看到 "context" 警告时立即 compact

**任务分解策略**:
- 将大任务拆分为多个小任务
- 使用 Agent Teams 并行处理
- 每个阶段完成后 compact

---

💡 **当前建议**: 先运行 `/compact`,如果还有问题再考虑重启
