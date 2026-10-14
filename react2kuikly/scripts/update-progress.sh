#!/bin/bash

# update-progress.sh
# 
# 更新页面转换进度跟踪
#
# 用法：
#   bash update-progress.sh --pageName <页面名称> --step <步骤号> --status <状态> --nextAction <下一步操作>
#
# 示例：
#   bash update-progress.sh --pageName "HomePage" --step "1" --status "completed" --nextAction "执行步骤2：分析代码"
#   bash update-progress.sh --pageName "HomePage" --step "5.2" --status "file_done" --fileInfo "ReactComponent.jsx -> ReactComponent.kt"

set -e

PAGE_NAME=""
STEP=""
STATUS=""
NEXT_ACTION=""
FILE_INFO=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --pageName)
      PAGE_NAME="$2"
      shift 2
      ;;
    --step)
      STEP="$2"
      shift 2
      ;;
    --status)
      STATUS="$2"
      shift 2
      ;;
    --nextAction)
      NEXT_ACTION="$2"
      shift 2
      ;;
    --fileInfo)
      FILE_INFO="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: bash update-progress.sh --pageName <页面名称> --step <步骤号> --status <状态> --nextAction <下一步操作>"
      exit 1
      ;;
  esac
done

if [ -z "$PAGE_NAME" ] || [ -z "$STEP" ] || [ -z "$STATUS" ]; then
  echo "错误: 必须指定 --pageName, --step 和 --status"
  echo "用法: bash update-progress.sh --pageName <页面名称> --step <步骤号> --status <状态> --nextAction <下一步操作>"
  exit 1
fi

PROGRESS_FILE="react2kuikly/$PAGE_NAME/cache/progress.md"

if [ ! -f "$PROGRESS_FILE" ]; then
  echo "错误: 进度文件不存在: $PROGRESS_FILE"
  echo "请先运行: bash skill/scripts/setup-page-dirs.sh --pageName \"$PAGE_NAME\""
  exit 1
fi

echo "📝 更新页面 [$PAGE_NAME] 的进度: 步骤 $STEP -> $STATUS"

# 辅助函数：更新最后更新时间（确保只保留一行）
# 使用 awk 替代 sed 以避免 macOS/Linux sed 差异
update_last_modified() {
  local current_date
  current_date="$(date)"
  awk -v ts="$current_date" '
    /^\*\*最后更新\*\*:/ { next }
    /^\*\*当前状态\*\*:/ { print; print "**最后更新**: " ts; next }
    { print }
  ' "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
}

# 辅助函数：更新最后更新时间（确保只保留一行）
# 使用 awk 替代 sed 以避免 macOS/Linux sed 差异
update_last_modified() {
  local current_date
  current_date="$(date)"
  awk -v ts="$current_date" '
    /^\*\*最后更新\*\*:/ { next }
    /^\*\*当前状态\*\*:/ { print; print "**最后更新**: " ts; next }
    { print }
  ' "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
}

# 根据状态更新进度文件
case $STATUS in
  "completed")
    # 标记当前步骤为完成（支持有/无前导空格的子步骤格式）
    # 标记当前步骤为完成（支持有/无前导空格的子步骤格式）
    sed -i.bak "s/- \[ \] 步骤 $STEP:/- [x] 步骤 $STEP:/" "$PROGRESS_FILE"
    
    # 更新当前状态
    sed -i.bak "s/^\*\*当前状态\*\*:.*/**当前状态**: 步骤 $STEP 已完成/" "$PROGRESS_FILE"
    sed -i.bak "s/^\*\*当前状态\*\*:.*/**当前状态**: 步骤 $STEP 已完成/" "$PROGRESS_FILE"
    
    # 更新最后更新时间
    update_last_modified
    ;;
  "in_progress")
    # 更新当前状态
    sed -i.bak "s/^\*\*当前状态\*\*:.*/**当前状态**: 正在执行步骤 $STEP/" "$PROGRESS_FILE"
    sed -i.bak "s/^\*\*当前状态\*\*:.*/**当前状态**: 正在执行步骤 $STEP/" "$PROGRESS_FILE"
    
    # 更新最后更新时间
    update_last_modified
    update_last_modified
    ;;
  *)
    echo "错误: 未知状态 '$STATUS'。支持的状态: completed, in_progress, file_done"
    exit 1
    ;;
esac

# 更新下一步操作（如果提供）
if [ -n "$NEXT_ACTION" ]; then
  # 使用 awk 安全替换"下一步操作"段落内容
  # 支持 ## 备注 存在或不存在的情况
  awk -v action="$NEXT_ACTION" '
    /^## 下一步操作/ {
      print
      print action
      print ""
      skip = 1
      next
    }
    skip && /^## / {
      skip = 0
    }
    !skip { print }
  ' "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
  # 使用 awk 安全替换"下一步操作"段落内容
  # 支持 ## 备注 存在或不存在的情况
  awk -v action="$NEXT_ACTION" '
    /^## 下一步操作/ {
      print
      print action
      print ""
      skip = 1
      next
    }
    skip && /^## / {
      skip = 0
    }
    !skip { print }
  ' "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
fi

# 清理备份文件
rm -f "$PROGRESS_FILE.bak"

echo "✅ 进度更新完成"
echo "📄 查看进度: cat \"$PROGRESS_FILE\""

