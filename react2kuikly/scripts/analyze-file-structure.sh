#!/bin/bash

# analyze-file-structure.sh
# 
# 分析 React Native 源代码文件结构和依赖关系（含外部依赖追踪）
#
# 用法：
#   bash analyze-file-structure.sh --pageName <页面名称> --sourceDir <源代码目录> [--outputDir <输出目录>] [--aliasDir <@别名映射目录>]
#
# 示例：
#   bash analyze-file-structure.sh --pageName "HomePage" --sourceDir "/path/to/react-native/source"
#   bash analyze-file-structure.sh --pageName "HomePage" --sourceDir "/path/to/react-native/source" --outputDir "src/main/kotlin/pages" --aliasDir "/path/to/src"

set -e

PAGE_NAME=""
SOURCE_DIR=""
OUTPUT_DIR=""
ALIAS_DIR=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --pageName)
      PAGE_NAME="$2"
      shift 2
      ;;
    --sourceDir)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --outputDir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --aliasDir)
      ALIAS_DIR="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: bash analyze-file-structure.sh --pageName <页面名称> --sourceDir <源代码目录> [--outputDir <输出目录>] [--aliasDir <@别名映射目录>]"
      exit 1
      ;;
  esac
done

if [ -z "$PAGE_NAME" ] || [ -z "$SOURCE_DIR" ]; then
  echo "错误: 必须指定 --pageName 和 --sourceDir"
  echo "用法: bash analyze-file-structure.sh --pageName <页面名称> --sourceDir <源代码目录> [--outputDir <输出目录>] [--aliasDir <@别名映射目录>]"
  exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "错误: 源代码目录不存在: $SOURCE_DIR"
  exit 1
fi

# 默认输出目录
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="react2kuikly/$PAGE_NAME/working"
fi

WORKING_DIR="$OUTPUT_DIR"
CACHE_DIR="react2kuikly/$PAGE_NAME/cache"
ANALYSIS_FILE="$WORKING_DIR/file-structure-analysis.md"

# 获取源目录的绝对路径
SOURCE_DIR_ABS=$(cd "$SOURCE_DIR" && pwd)

# 获取别名目录的绝对路径（用于解析 @/ 开头的 import）
ALIAS_DIR_ABS=""
if [ -n "$ALIAS_DIR" ] && [ -d "$ALIAS_DIR" ]; then
  ALIAS_DIR_ABS=$(cd "$ALIAS_DIR" && pwd)
  echo "📎 @别名映射目录: $ALIAS_DIR_ABS"
fi

echo "🔍 分析页面 [$PAGE_NAME] 的文件结构..."
echo "📂 源代码目录: $SOURCE_DIR"
echo ""

# 确保缓存目录存在
mkdir -p "$CACHE_DIR"

# 创建分析文件
cat > "$ANALYSIS_FILE" << EOF
# 文件结构分析报告

**页面名称**: $PAGE_NAME  
**源代码目录**: $SOURCE_DIR  
**分析时间**: $(date)  

## 文件清单

### JavaScript/TypeScript 文件
EOF

# 查找所有 JS/TS 文件
echo "📄 扫描 JavaScript/TypeScript 文件..."
find "$SOURCE_DIR" -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \) | while read file; do
  # macOS 兼容：使用 python 或 perl 替代 realpath --relative-to
  relative_path=$(python3 -c "import os; print(os.path.relpath('$file', '$SOURCE_DIR'))" 2>/dev/null || echo "$file")
  file_size=$(wc -l < "$file")
  echo "- \`$relative_path\` ($file_size 行)" >> "$ANALYSIS_FILE"
done

cat >> "$ANALYSIS_FILE" << EOF

### 样式文件
EOF

# 查找样式文件
echo "🎨 扫描样式文件..."
find "$SOURCE_DIR" -type f \( -name "*.css" -o -name "*.scss" -o -name "*.less" \) | while read file; do
  relative_path=$(python3 -c "import os; print(os.path.relpath('$file', '$SOURCE_DIR'))" 2>/dev/null || echo "$file")
  file_size=$(wc -l < "$file")
  echo "- \`$relative_path\` ($file_size 行)" >> "$ANALYSIS_FILE"
done

cat >> "$ANALYSIS_FILE" << EOF

## 依赖关系分析

### Import/Export 关系
EOF

echo "🔗 分析依赖关系..."

# ══════════════════════════════════════
#  外部依赖追踪（记录到分析报告中，不生成独立缓存文件）
# ══════════════════════════════════════

echo "🔍 追踪外部依赖文件..."

cat >> "$ANALYSIS_FILE" << EOF

## 外部依赖

> 以下列出了源目录外被引用的组件文件。Agent 在步骤 5.1 分析时，
> **必须直接读取这些文件的源码中被引用的部分**，理解其内部使用了哪些 React Native 组件，以正确选择 Kuikly 对应组件。
> **不需要为外部依赖生成独立的 Kuikly 文件**，其功能在引用处内联实现。如果同一个外部依赖被多个文件引用，可提取为独立文件以复用。

EOF

EXTERNAL_COUNT=0

# 提取所有 import/require 路径并识别外部依赖
while IFS= read -r file; do
  relative_path=$(python3 -c "import os; print(os.path.relpath('$file', '$SOURCE_DIR'))" 2>/dev/null || echo "$file")
  file_dir=$(dirname "$file")
  
  # 查找 import 语句
  imports=$(grep -n "^import\|from ['\"]" "$file" 2>/dev/null | head -20 || true)
  if [ -n "$imports" ]; then
    echo "" >> "$ANALYSIS_FILE"
    echo "**$relative_path**:" >> "$ANALYSIS_FILE"
    echo "\`\`\`" >> "$ANALYSIS_FILE"
    echo "$imports" >> "$ANALYSIS_FILE"
    echo "\`\`\`" >> "$ANALYSIS_FILE"
  fi

  # 提取相对路径引用（排除 node_modules 包如 react、react-native 等）
  # 匹配 from '../xxx' 或 from '../../xxx' 或 require('../xxx') 等相对路径
  ext_imports=$(grep -oE "from ['\"](\.\./[^'\"]+)['\"]|require\(['\"](\.\./[^'\"]+)['\"]\)" "$file" 2>/dev/null || true)
  
  # 同时提取 @/ 别名路径引用（如 from '@/component/xxx'）
  if [ -n "$ALIAS_DIR_ABS" ]; then
    alias_imports=$(grep -oE "from ['\"]@/([^'\"]+)['\"]|require\(['\"]@/([^'\"]+)['\"]\)" "$file" 2>/dev/null || true)
  else
    alias_imports=""
  fi
  
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # 提取路径部分
    import_path=$(echo "$line" | grep -oE "\.\./[^'\")(]+" || true)
    [ -z "$import_path" ] && continue
    
    # 解析为绝对路径
    resolved=""
    for ext in "" ".js" ".jsx" ".ts" ".tsx" "/index.js" "/index.ts" "/index.tsx" "/index.jsx"; do
      candidate="$file_dir/$import_path$ext"
      if [ -f "$candidate" ]; then
        resolved=$(cd "$(dirname "$candidate")" && echo "$(pwd)/$(basename "$candidate")")
        break
      fi
    done
    
    [ -z "$resolved" ] && continue
    
    # 检查是否在源目录之外
    case "$resolved" in
      "$SOURCE_DIR_ABS"/*) 
        # 在源目录内，跳过
        ;;
      *)
        # 外部依赖！记录到分析报告中
        EXTERNAL_COUNT=$((EXTERNAL_COUNT + 1))
        
        # 获取文件行数
        dep_lines=$(wc -l < "$resolved" 2>/dev/null | tr -d ' ' || echo "?")
        
        # 提取文件中使用的 React Native 原生组件
        rn_components=$(grep -oE "import.*from ['\"]react-native['\"]" "$resolved" 2>/dev/null | grep -oE "\{[^}]+\}" | tr -d '{}' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort -u | tr '\n' ',' | sed 's/,$//' || echo "未检测到")
        
        echo "### $import_path" >> "$ANALYSIS_FILE"
        echo "- **文件路径**: \`$resolved\`" >> "$ANALYSIS_FILE"
        echo "- **被引用位置**: \`$relative_path\`" >> "$ANALYSIS_FILE"
        echo "- **文件大小**: $dep_lines 行" >> "$ANALYSIS_FILE"
        echo "- **内部使用的 React Native 组件**: $rn_components" >> "$ANALYSIS_FILE"
        echo "- **⚠️ Agent 须读取此文件中被引用部分的源码，分析其内部实现行为，确定正确的 Kuikly 组件映射**" >> "$ANALYSIS_FILE"
        echo "" >> "$ANALYSIS_FILE"
        ;;
    esac
  done <<< "$ext_imports"
  
  # 处理 @/ 别名路径引用
  if [ -n "$alias_imports" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      # 提取 @/ 后面的路径部分
      alias_path=$(echo "$line" | grep -oE "@/[^'\")(]+" | sed 's|^@/||' || true)
      [ -z "$alias_path" ] && continue
      
      # 解析为绝对路径（基于 ALIAS_DIR_ABS）
      resolved=""
      for ext in "" ".js" ".jsx" ".ts" ".tsx" "/index.js" "/index.ts" "/index.tsx" "/index.jsx"; do
        candidate="$ALIAS_DIR_ABS/$alias_path$ext"
        if [ -f "$candidate" ]; then
          resolved=$(cd "$(dirname "$candidate")" && echo "$(pwd)/$(basename "$candidate")")
          break
        fi
      done
      
      [ -z "$resolved" ] && continue
      
      # @/ 路径解析的文件如果不在源目录内，视为外部依赖
      case "$resolved" in
        "$SOURCE_DIR_ABS"/*) 
          ;;
        *)
          EXTERNAL_COUNT=$((EXTERNAL_COUNT + 1))
          dep_lines=$(wc -l < "$resolved" 2>/dev/null | tr -d ' ' || echo "?")
          rn_components=$(grep -oE "import.*from ['\"]react-native['\"]" "$resolved" 2>/dev/null | grep -oE "\{[^}]+\}" | tr -d '{}' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort -u | tr '\n' ',' | sed 's/,$//' || echo "未检测到")
          
          echo "### @/$alias_path" >> "$ANALYSIS_FILE"
          echo "- **文件路径**: \`$resolved\`" >> "$ANALYSIS_FILE"
          echo "- **被引用位置**: \`$relative_path\`" >> "$ANALYSIS_FILE"
          echo "- **文件大小**: $dep_lines 行" >> "$ANALYSIS_FILE"
          echo "- **内部使用的 React Native 组件**: $rn_components" >> "$ANALYSIS_FILE"
          echo "- **⚠️ Agent 须读取此文件中被引用部分的源码，分析其内部实现行为，确定正确的 Kuikly 组件映射**" >> "$ANALYSIS_FILE"
          echo "" >> "$ANALYSIS_FILE"
          ;;
      esac
    done <<< "$alias_imports"
  fi
done < <(find "$SOURCE_DIR" -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \))

echo "✅ 文件结构分析完成"
echo "📄 分析报告: $ANALYSIS_FILE"
echo ""
echo "📊 统计信息："

# 统计信息
js_count=$(find "$SOURCE_DIR" -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \) | wc -l)
css_count=$(find "$SOURCE_DIR" -type f \( -name "*.css" -o -name "*.scss" -o -name "*.less" \) | wc -l)

echo "   📄 JavaScript/TypeScript 文件: $js_count 个"
echo "   🎨 样式文件: $css_count 个"
echo ""
echo "💡 建议查看分析报告后，开始逐文件转换过程"
echo "⚠️  请确保 Agent 直接读取分析报告中列出的外部依赖文件源码中被引用的部分"
