#!/bin/bash

# check-cache.sh
# 
# 检查缓存文件是否存在，询问用户是否使用已有缓存
#
# 用法：
#   bash check-cache.sh --pageName <页面名称>
#
# 返回值：
#   0 - 使用已有缓存，可跳转到步骤 5（若 knowledge-cache.md 存在）或步骤 4
#   1 - 重新生成，继续执行步骤 4
#   2 - 无缓存文件，继续执行步骤 4

set -e

PAGE_NAME=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --pageName)
      PAGE_NAME="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: bash check-cache.sh --pageName <页面名称>"
      exit 1
      ;;
  esac
done

if [ -z "$PAGE_NAME" ]; then
  echo "错误: 必须指定 --pageName"
  echo "用法: bash check-cache.sh --pageName <页面名称>"
  exit 1
fi

CACHE_DIR="react2kuikly/$PAGE_NAME/cache"
KEYWORDS_FILE="$CACHE_DIR/project-keywords.md"
KNOWLEDGE_CACHE_FILE="$CACHE_DIR/knowledge-cache.md"

echo "🔍 检查页面 [$PAGE_NAME] 的缓存文件..."
echo ""

HAS_CACHE=false

# 检查知识缓存文件
if [ -f "$KNOWLEDGE_CACHE_FILE" ]; then
  HAS_CACHE=true
  echo "✅ 发现知识缓存文件："
  echo "   📄 $KNOWLEDGE_CACHE_FILE"
fi

# 检查关键字文件
if [ -f "$KEYWORDS_FILE" ]; then
  HAS_CACHE=true
  echo "✅ 发现项目关键字缓存："
  echo "   📄 $KEYWORDS_FILE"
fi

echo ""

if [ "$HAS_CACHE" = true ]; then
  echo "❓ 是否使用已有的缓存文件？"
  if [ -f "$KNOWLEDGE_CACHE_FILE" ]; then
    echo "   y/Y - 使用已有缓存，直接跳转到步骤 5（生成 Kuikly 代码）"
  else
    echo "   y/Y - 使用已有缓存，跳转到步骤 4（继续构建知识库）"
  fi
  echo "   n/N - 重新生成，从步骤 4 开始"
  echo ""
  read -p "请选择 (y/n): " -r use_cache
  
  echo ""
  
  if [ "$use_cache" = "y" ] || [ "$use_cache" = "Y" ]; then
    echo "✅ 使用已有缓存"
    echo ""
    exit 0
  else
    echo "🔄 重新生成，从步骤 4 开始..."
    echo ""
    exit 1
  fi
else
  echo "❌ 未发现页面 [$PAGE_NAME] 的缓存文件"
  echo "📂 缓存目录: $CACHE_DIR"
  echo ""
  echo "🚀 继续执行步骤 4..."
  echo ""
  exit 2
fi
