#!/bin/bash
# Swift 文件修改通知的 PostToolUse hook

# 从 stdin 读取 hook 输入
INPUT=$(cat)

# 提取文件路径
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# 如果是 Swift 文件，显示通知
if [[ "$FILE_PATH" == *.swift ]]; then
  echo "✓ Swift 文件已修改: $FILE_PATH"
fi

exit 0
