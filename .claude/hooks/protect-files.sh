#!/bin/bash
# 保护敏感配置文件的 PreToolUse hook

# 从 stdin 读取 hook 输入
INPUT=$(cat)

# 提取文件路径
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# 如果没有文件路径，放行
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 检查是否是敏感文件
if echo "$FILE_PATH" | grep -qE '\.(entitlements|plist)$|/xcodeproj/|generate-icons\.sh$|Package\.(swift|resolved)$'; then
  # 返回 JSON 决策，请求用户确认
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "⚠️ 这是敏感配置文件，确定要修改吗？"
  }
}
EOF
  exit 0
fi

# 其他文件放行
exit 0
