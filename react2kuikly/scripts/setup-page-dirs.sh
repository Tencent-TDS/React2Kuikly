#!/bin/bash

# setup-page-dirs.sh
# 
# 检查并创建页面目录结构
#
# 用法：
#   bash setup-page-dirs.sh --pageName <页面名称> [--outputDir <输出目录>]
#
# 示例：
#   bash setup-page-dirs.sh --pageName "HomePage"
#   bash setup-page-dirs.sh --pageName "HomePage" --outputDir "src/main/kotlin/com/example/pages/home"

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
      echo "用法: bash setup-page-dirs.sh --pageName <页面名称> [--outputDir <输出目录>]"
      exit 1
      ;;
  esac
done

if [ -z "$PAGE_NAME" ]; then
  echo "错误: 必须指定 --pageName"
  echo "用法: bash setup-page-dirs.sh --pageName <页面名称> [--outputDir <输出目录>]"
  exit 1
fi

# 默认输出目录
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="react2kuikly/$PAGE_NAME/working"
fi

echo "🔧 设置页面 [$PAGE_NAME] 的目录结构..."
echo "📂 输出目录: $OUTPUT_DIR"
echo ""

# 创建缓存目录（始终在 react2kuikly/[页面名]/cache/ 下）
CACHE_DIR="react2kuikly/$PAGE_NAME/cache"

if [ -d "$CACHE_DIR" ]; then
  echo "✅ 缓存目录已存在: $CACHE_DIR"
else
  echo "📂 创建缓存目录: $CACHE_DIR"
  mkdir -p "$CACHE_DIR"
fi

# 创建代码输出目录
if [ -d "$OUTPUT_DIR" ]; then
  echo "✅ 输出目录已存在: $OUTPUT_DIR"
else
  echo "📄 创建输出目录: $OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR/composedview"
  mkdir -p "$OUTPUT_DIR/utils"
fi

echo ""
echo "🎯 页面 [$PAGE_NAME] 目录结构准备完成"
echo ""
echo "📁 创建的目录结构："
echo "   react2kuikly/$PAGE_NAME/"
echo "   └── cache/                    # 缓存目录"
echo "       ├── progress.md           # 进度跟踪文件"
echo "       └── knowledge-cache.md    # 统一转化知识库（步骤 4 生成）"
echo "   $OUTPUT_DIR/"
echo "   ├── composedview/             # 组合组件目录"
echo "   └── utils/                    # 工具类/常量定义"
echo ""

# 创建进度跟踪文件（如果不存在）
PROGRESS_FILE="$CACHE_DIR/progress.md"
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "📝 创建进度跟踪文件: $PROGRESS_FILE"
  cat > "$PROGRESS_FILE" << EOF
# 页面转换进度跟踪

**页面名称**: $PAGE_NAME  
**输出目录**: $OUTPUT_DIR  
**开始时间**: $(date)  
**当前状态**: 初始化完成  

## 进度记录

### ✅ 已完成步骤
- [x] 步骤 1: 创建目录结构

### 🔄 当前步骤
- [ ] 步骤 2: 预处理 - 提取内联资源

### 📋 待完成步骤
- [ ] 步骤 3: 检查知识缓存文件
- [ ] 步骤 4: 分析代码并提取关键字
  - [ ] 步骤 4.1: 收集完整源文件集合
  - [ ] 步骤 4.2: 获取 Kuikly 组件关键字
  - [ ] 步骤 4.3: 获取业务关键字
  - [ ] 步骤 4.4: 汇总关键字集合
  - [ ] 步骤 4.5: 构建知识库
- [ ] 步骤 5: 生成 Kuikly 代码
  - [ ] 步骤 5.1: 分析文件结构和依赖关系
  - [ ] 步骤 5.2: 逐文件转换
  - [ ] 步骤 5.3: 架构整理与目录规范化
- [ ] 步骤 6: 代码验证和完善

## 下一步操作
执行: \`bash skill/scripts/check-cache.sh --pageName "$PAGE_NAME"\`

## 备注
项目初始化完成，可以开始转换流程。
EOF
else
  echo "✅ 进度跟踪文件已存在: $PROGRESS_FILE"
fi