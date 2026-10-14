#!/bin/bash

# check-progress.sh
# 
# 检查页面转换进度，用于新对话恢复
#
# 用法：
#   bash check-progress.sh --pageName <页面名称> [--outputDir <输出目录>]
#
# 示例：
#   bash check-progress.sh --pageName "HomePage"
#   bash check-progress.sh --pageName "HomePage" --outputDir "src/main/kotlin/pages"

set -e

PAGE_NAME=""
OUTPUT_DIR=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --pageName)
      PAGE_NAME="$2"
      shift 2
      ;;
    --outputDir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: bash check-progress.sh --pageName <页面名称> [--outputDir <输出目录>]"
      exit 1
      ;;
  esac
done

if [ -z "$PAGE_NAME" ]; then
  echo "错误: 必须指定 --pageName"
  echo "用法: bash check-progress.sh --pageName <页面名称> [--outputDir <输出目录>]"
  exit 1
fi

# 默认输出目录
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="react2kuikly/$PAGE_NAME/working"
fi

PROGRESS_FILE="react2kuikly/$PAGE_NAME/cache/progress.md"

echo "🔍 检查页面 [$PAGE_NAME] 的转换进度..."
echo ""

if [ ! -f "$PROGRESS_FILE" ]; then
  echo "❌ 未找到进度文件: $PROGRESS_FILE"
  echo "💡 建议执行: bash skill/scripts/setup-page-dirs.sh --pageName \"$PAGE_NAME\""
  exit 1
fi

echo "📄 进度文件: $PROGRESS_FILE"
echo ""

# 显示进度文件内容
cat "$PROGRESS_FILE"

echo ""
echo "🎯 基于进度文件，您可以："
echo "   1. 查看已完成的步骤"
echo "   2. 了解当前状态"
echo "   3. 执行下一步操作"
echo ""

# 检查工作目录中的文件
WORKING_DIR="$OUTPUT_DIR"
if [ -d "$WORKING_DIR" ]; then
  echo "📁 工作目录已生成的文件："
  find "$WORKING_DIR" -type f -name "*.kt" -o -name "*.md" -o -name "*.json" | head -10 | while read file; do
    echo "   - $(basename "$file")"
  done
  
  file_count=$(find "$WORKING_DIR" -type f -name "*.kt" -o -name "*.md" -o -name "*.json" | wc -l)
  if [ "$file_count" -gt 10 ]; then
    echo "   ... 还有 $((file_count - 10)) 个文件"
  fi
fi

echo ""

# 检查文件级转换进度（步骤 5.2 断点续传支持）
CONVERSION_PLAN="react2kuikly/$PAGE_NAME/cache/conversion-plan.md"

if grep -q "^### 📂 文件转换进度" "$PROGRESS_FILE" 2>/dev/null; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📂 文件级转换进度（步骤 5.2）："
  echo ""

  # 提取已完成的文件数
  DONE_COUNT=$(grep -c '^| [0-9]' "$PROGRESS_FILE" 2>/dev/null || echo "0")
  echo "   ✅ 已完成文件数: $DONE_COUNT"

  # 列出已完成的文件
  echo ""
  echo "   已完成的文件："
  grep '^| [0-9]' "$PROGRESS_FILE" 2>/dev/null | while IFS='|' read -r _ num src dst status ts _; do
    src=$(echo "$src" | xargs)
    dst=$(echo "$dst" | xargs)
    echo "     $num. $src -> $dst"
  done

  # 如果存在转换计划，对比显示剩余文件
  if [ -f "$CONVERSION_PLAN" ]; then
    echo ""
    echo "   💡 请对比 conversion-plan.md 中的转换计划，继续转换剩余未完成的文件"
    echo "   📄 转换计划: $CONVERSION_PLAN"
  fi

  echo ""
fi

echo ""