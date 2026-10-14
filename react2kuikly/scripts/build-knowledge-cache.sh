#!/bin/bash
# build-knowledge-cache.sh
# 根据关键字列表按需合并转化知识文件到 knowledge-cache.md
#
# 推荐用法（从 project-keywords.md 直接读取关键字参数）:
# bash skill/scripts/build-knowledge-cache.sh \
#   --pageName "Home" \
#   --businessSkill "biz-react2kuikly" \
#   --keywordsFile "react2kuikly/Home/cache/project-keywords.md"
#
# project-keywords.md 文件格式（KEY=VALUE，逗号分隔，脚本直接读取）:
#   COMP_KEYWORDS=View,Text,Image,List
#   BIZ_KEYWORDS=登录相关,版本判断,基础业务逻辑
#
# 手动指定关键字（调试/覆盖用）:
# bash skill/scripts/build-knowledge-cache.sh \
#   --pageName "Home" \
#   --businessSkill "biz-react2kuikly" \
#   --compKeywords "View,Text,Image,List" \
#   --bizKeywords "版本判断,登录相关,基础业务逻辑"
#
# 当同时指定 --keywordsFile 和 --compKeywords/--bizKeywords 时，以 --keywordsFile 为准。

set -e

# 解析参数
PAGE_NAME=""
BUSINESS_SKILL=""
COMP_KEYWORDS=""
BIZ_KEYWORDS=""
KEYWORDS_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --pageName)
      PAGE_NAME="$2"
      shift 2
      ;;
    --businessSkill)
      BUSINESS_SKILL="$2"
      shift 2
      ;;
    --compKeywords)
      COMP_KEYWORDS="$2"
      shift 2
      ;;
    --bizKeywords)
      BIZ_KEYWORDS="$2"
      shift 2
      ;;
    --keywordsFile)
      KEYWORDS_FILE="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

if [ -z "$PAGE_NAME" ]; then
  echo "错误: 请指定 --pageName 参数"
  exit 1
fi

if [ -z "$BUSINESS_SKILL" ]; then
  echo "错误: 请指定 --businessSkill 参数"
  exit 1
fi

# ==========================================
# 从 project-keywords.md 读取关键字
# ==========================================
# 当指定 --keywordsFile 时，直接读取文件中的 KEY=VALUE 参数
# 文件格式约定（由步骤 4.4 生成）：
#   COMP_KEYWORDS=View,Text,Image,List
#   BIZ_KEYWORDS=登录相关,版本判断,基础业务逻辑

if [ -n "$KEYWORDS_FILE" ]; then
  if [ ! -f "$KEYWORDS_FILE" ]; then
    echo "❌ 错误: 关键字文件不存在: $KEYWORDS_FILE"
    echo "  请确认步骤 4.4 已执行并生成了 project-keywords.md"
    exit 1
  fi

  echo "📖 从 project-keywords.md 读取关键字..."
  echo "  - 文件路径: $KEYWORDS_FILE"

  # 直接 source 读取 KEY=VALUE 格式的参数
  # 先保存当前值，source 后覆盖
  PARSED_COMP=""
  PARSED_BIZ=""

  # 安全读取：只提取 COMP_KEYWORDS 和 BIZ_KEYWORDS 行
  PARSED_COMP=$(grep '^COMP_KEYWORDS=' "$KEYWORDS_FILE" | head -1 | cut -d'=' -f2-)
  PARSED_BIZ=$(grep '^BIZ_KEYWORDS=' "$KEYWORDS_FILE" | head -1 | cut -d'=' -f2-)

  # --keywordsFile 优先级高于 --compKeywords/--bizKeywords
  if [ -n "$PARSED_COMP" ]; then
    COMP_KEYWORDS="$PARSED_COMP"
    echo "  ✅ 读取到组件关键字: $COMP_KEYWORDS"
  else
    echo "  ⚠️ 未读取到组件关键字，将使用 --compKeywords 参数值（如有）"
  fi

  if [ -n "$PARSED_BIZ" ]; then
    BIZ_KEYWORDS="$PARSED_BIZ"
    echo "  ✅ 读取到业务关键字: $BIZ_KEYWORDS"
  else
    echo "  ⚠️ 未读取到业务关键字，将使用 --bizKeywords 参数值（如有）"
  fi
fi

# 路径定义
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$SKILL_DIR/references/docs"
BUSINESS_SKILL_DIR="$(cd "$SKILL_DIR/../$BUSINESS_SKILL" && pwd 2>/dev/null || echo "")"
OUTPUT_DIR="react2kuikly/$PAGE_NAME/cache"
OUTPUT_FILE="$OUTPUT_DIR/knowledge-cache.md"

# ==========================================
# 从业务 Skill 的 SKILL.md 中动态解析 PATH_CONFIG
# ==========================================
# 业务 Skill 通过 SKILL.md 中的 PATH_CONFIG 块声明资源路径，
# 脚本从中动态读取，不硬编码任何路径规则。
#
# PATH_CONFIG 格式（在 <!-- PATH_CONFIG_START --> 和 <!-- PATH_CONFIG_END --> 之间）：
#   EXAMPLE_CODE=references/kuikly-example-code.md
#   CHECKLIST=references/checklist.md
#   BIZ_KEYWORDS_MAP=references/react-business-keywords.md
#   BIZ_RULES_DIR=references/react2kuikly-rules

BIZ_EXAMPLE_CODE=""
BIZ_CHECKLIST=""
BIZ_KEYWORDS_MAP=""
BIZ_RULES_DIR=""
BIZ_BASE_RULES=""

if [ -z "$BUSINESS_SKILL_DIR" ] || [ ! -d "$BUSINESS_SKILL_DIR" ]; then
  echo "❌ 错误: 未找到业务 Skill 目录: $BUSINESS_SKILL"
  echo "  请确认业务 Skill 名称正确，且位于 .codebuddy/skills/ 目录下"
  exit 1
fi

echo "  - 业务 Skill 目录: $BUSINESS_SKILL_DIR"

# 从业务 Skill 的 SKILL.md 中解析 PATH_CONFIG
BIZ_SKILL_MD="$BUSINESS_SKILL_DIR/SKILL.md"
if [ ! -f "$BIZ_SKILL_MD" ]; then
  echo "❌ 错误: 未找到业务 Skill 的 SKILL.md: $BIZ_SKILL_MD"
  echo "  业务 Skill 必须提供 SKILL.md 文件，并在其中定义 PATH_CONFIG 配置块"
  exit 1
fi

echo "📖 从业务 Skill 的 SKILL.md 中解析 PATH_CONFIG..."

# 提取 PATH_CONFIG_START 和 PATH_CONFIG_END 之间的配置内容
PATH_CONFIG_CONTENT=$(sed -n '/<!-- PATH_CONFIG_START -->/,/<!-- PATH_CONFIG_END -->/p' "$BIZ_SKILL_MD" | grep -E '^\s*[A-Z_]+=.+' | sed 's/^[[:space:]]*//')

if [ -z "$PATH_CONFIG_CONTENT" ]; then
  echo "❌ 错误: 业务 Skill 的 SKILL.md 中未找到有效的 PATH_CONFIG 配置块"
  echo "  请在业务 Skill 的 SKILL.md 中添加以下格式的配置："
  echo ""
  echo "  <!-- PATH_CONFIG_START -->"
  echo '  ```'
  echo "  EXAMPLE_CODE=references/kuikly-example-code.md"
  echo "  CHECKLIST=references/checklist.md"
  echo "  BIZ_KEYWORDS_MAP=references/react-business-keywords.md"
  echo "  BIZ_RULES_DIR=references/react2kuikly-rules"
  echo '  ```'
  echo "  <!-- PATH_CONFIG_END -->"
  exit 1
fi

# 逐行解析 PATH_CONFIG
while IFS='=' read -r key value; do
  # 去除首尾空格
  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs)
  case "$key" in
    EXAMPLE_CODE)
      BIZ_EXAMPLE_CODE="$BUSINESS_SKILL_DIR/$value"
      echo "  ✅ 示例代码路径: $value"
      ;;
    CHECKLIST)
      BIZ_CHECKLIST="$BUSINESS_SKILL_DIR/$value"
      echo "  ✅ Checklist路径: $value"
      ;;
    BIZ_KEYWORDS_MAP)
      BIZ_KEYWORDS_MAP="$BUSINESS_SKILL_DIR/$value"
      echo "  ✅ 业务关键字映射路径: $value"
      ;;
    BIZ_RULES_DIR)
      BIZ_RULES_DIR="$BUSINESS_SKILL_DIR/$value"
      echo "  ✅ 业务规则目录路径: $value"
      ;;
    BIZ_BASE_RULES)
      BIZ_BASE_RULES="$BUSINESS_SKILL_DIR/$value"
      echo "  ✅ 基础业务规则路径: $value"
      ;;
  esac
done <<< "$PATH_CONFIG_CONTENT"

# 前置校验：必选配置项是否已定义
VALIDATION_FAILED=0

if [ -z "$BIZ_EXAMPLE_CODE" ]; then
  echo "❌ 错误: PATH_CONFIG 中缺少 EXAMPLE_CODE 配置"
  VALIDATION_FAILED=1
elif [ ! -f "$BIZ_EXAMPLE_CODE" ]; then
  echo "❌ 错误: 示例代码文件不存在: $BIZ_EXAMPLE_CODE"
  VALIDATION_FAILED=1
fi

if [ -z "$BIZ_CHECKLIST" ]; then
  echo "❌ 错误: PATH_CONFIG 中缺少 CHECKLIST 配置"
  VALIDATION_FAILED=1
elif [ ! -f "$BIZ_CHECKLIST" ]; then
  echo "❌ 错误: Checklist 文件不存在: $BIZ_CHECKLIST"
  VALIDATION_FAILED=1
fi

if [ -z "$BIZ_RULES_DIR" ]; then
  echo "❌ 错误: PATH_CONFIG 中缺少 BIZ_RULES_DIR 配置"
  VALIDATION_FAILED=1
elif [ ! -d "$BIZ_RULES_DIR" ]; then
  echo "❌ 错误: 业务规则目录不存在: $BIZ_RULES_DIR"
  VALIDATION_FAILED=1
fi

if [ $VALIDATION_FAILED -eq 1 ]; then
  echo ""
  echo "请检查业务 Skill 的 SKILL.md 中 PATH_CONFIG 配置，确保路径正确且文件/目录存在"
  exit 1
fi

# BIZ_BASE_RULES 非必选，但如果配置了则校验文件存在
if [ -n "$BIZ_BASE_RULES" ] && [ ! -f "$BIZ_BASE_RULES" ]; then
  echo "⚠️ 警告: BIZ_BASE_RULES 配置的基础业务规则文件不存在: $BIZ_BASE_RULES"
fi

echo "  ✅ 业务 Skill 路径校验通过（基于 PATH_CONFIG 动态解析）"

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

echo "📚 开始构建统一转化知识库..."
echo "  - 页面: $PAGE_NAME"
echo "  - 业务 Skill: $BUSINESS_SKILL"
echo "  - 组件关键字: ${COMP_KEYWORDS:-（无）}"
echo "  - 业务关键字: ${BIZ_KEYWORDS:-（无）}"
echo "  - 输出文件: $OUTPUT_FILE"

# 清空输出文件
> "$OUTPUT_FILE"

# ==========================================
# 组件名 → 文件名 映射函数
# ==========================================
comp_to_filename() {
  local comp="$1"
  case "$comp" in
    View|Modal|Mask) echo "view.txt" ;;
    Text) echo "text.txt" ;;
    List) echo "list.txt" ;;
    Scroller) echo "scroller.txt" ;;
    WaterfallList) echo "waterfall-list.txt" ;;
    PageList) echo "page-list.txt" ;;
    Input|TextArea) echo "input.txt" ;;
    Button) echo "button.txt" ;;
    Checkbox|CheckBox) echo "checkbox.txt" ;;
    Switch) echo "switch.txt" ;;
    Slider) echo "slider.txt" ;;
    Image) echo "image.txt" ;;
    Video) echo "video.txt" ;;
    Canvas) echo "canvas.txt" ;;
    APNG) echo "apng.txt" ;;
    PAG) echo "pag.txt" ;;
    AlertDialog) echo "alert-dialog.txt" ;;
    ActionSheet) echo "action-sheet.txt" ;;
    DatePicker) echo "date-picker.txt" ;;
    ScrollPicker) echo "scroll-picker.txt" ;;
    Tabs) echo "tabs.txt" ;;
    SliderPage) echo "slider-page.txt" ;;
    Refresh|Refresher) echo "refresh.txt" ;;
    FooterRefresh) echo "footer-refresh.txt" ;;
    Blur) echo "blur.txt" ;;
    Hover) echo "hover.txt" ;;
    RichText) echo "rich-text.txt" ;;
    ActivityIndicator) echo "activity-indicator.txt" ;;
    *) 
      # 默认：组件名小写化 + .txt
      local lower=$(echo "$comp" | tr '[:upper:]' '[:lower:]')
      echo "${lower}.txt"
      ;;
  esac
}

# ==========================================
# 一、基础框架知识（dev.txt 全量加载）
# ==========================================
echo "" >> "$OUTPUT_FILE"
echo "# 转化知识库（统一缓存）" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "## 一、基础框架知识" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
DEV_FILE="$DOCS_DIR/dev.txt"
if [ -f "$DEV_FILE" ]; then
  cat "$DEV_FILE" >> "$OUTPUT_FILE"
  echo "  ✅ dev.txt ($(wc -c < "$DEV_FILE" | tr -d ' ') bytes)"
else
  echo "> ⚠️ 文件不存在: $DEV_FILE" >> "$OUTPUT_FILE"
  echo "  ❌ dev.txt 不存在"
fi

# ==========================================
# 二、组件知识（按关键字按需加载）
# ==========================================
echo "" >> "$OUTPUT_FILE"
echo "## 二、组件知识" >> "$OUTPUT_FILE"

COMP_COUNT=0
COMP_LOADED_FILES="" # 去重用，记录已加载的文件名

if [ -n "$COMP_KEYWORDS" ]; then
  # 将逗号分隔的关键字列表转为数组
  IFS=',' read -ra COMP_ARRAY <<< "$COMP_KEYWORDS"
  
  for comp in "${COMP_ARRAY[@]}"; do
    # 去除首尾空格
    comp=$(echo "$comp" | xargs)
    [ -z "$comp" ] && continue
    
    # 获取对应的文件名
    filename=$(comp_to_filename "$comp")
    
    # 去重：同一个文件不重复加载（如 Input 和 TextArea 都映射到 input.txt）
    if echo "$COMP_LOADED_FILES" | grep -q "|${filename}|" 2>/dev/null; then
      echo "  ⏭️ $comp → $filename（已加载，跳过）"
      continue
    fi
    
    filepath="$DOCS_DIR/$filename"
    if [ -f "$filepath" ]; then
      echo "" >> "$OUTPUT_FILE"
      echo "### $comp" >> "$OUTPUT_FILE"
      echo "" >> "$OUTPUT_FILE"
      cat "$filepath" >> "$OUTPUT_FILE"
      COMP_COUNT=$((COMP_COUNT + 1))
      COMP_LOADED_FILES="${COMP_LOADED_FILES}|${filename}|"
      echo "  ✅ $comp → $filename ($(wc -c < "$filepath" | tr -d ' ') bytes)"
    else
      echo "" >> "$OUTPUT_FILE"
      echo "### $comp" >> "$OUTPUT_FILE"
      echo "" >> "$OUTPUT_FILE"
      echo "> ⚠️ 未找到组件文档: $filename" >> "$OUTPUT_FILE"
      echo "  ⚠️ $comp → $filename 不存在"
    fi
  done
else
  echo "" >> "$OUTPUT_FILE"
  echo "> 未指定组件关键字，跳过组件知识加载" >> "$OUTPUT_FILE"
  echo "  ⚠️ 未指定 --compKeywords 参数"
fi

echo "  ✅ 组件知识: ${COMP_COUNT} 个组件文件"

# ==========================================
# 三、业务知识（按关键字按需加载）
# ==========================================
echo "" >> "$OUTPUT_FILE"
echo "## 三、业务知识" >> "$OUTPUT_FILE"

BIZ_COUNT=0

if [ -n "$BUSINESS_SKILL_DIR" ] && [ -d "$BUSINESS_SKILL_DIR" ]; then
  # 无条件先加载基础业务规则（通用必读，不需要关键字匹配）
  if [ -n "$BIZ_BASE_RULES" ] && [ -f "$BIZ_BASE_RULES" ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "### 基础业务逻辑（通用必读）" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    cat "$BIZ_BASE_RULES" >> "$OUTPUT_FILE"
    BIZ_COUNT=$((BIZ_COUNT + 1))
    echo "  ✅ 基础业务逻辑 ← BIZ_BASE_RULES ($(wc -c < "$BIZ_BASE_RULES" | tr -d ' ') bytes)"
  elif [ -n "$BIZ_BASE_RULES" ]; then
    echo "  ⚠️ 基础业务规则文件不存在: $BIZ_BASE_RULES"
  fi
fi

if [ -n "$BIZ_KEYWORDS" ] && [ -n "$BUSINESS_SKILL_DIR" ] && [ -d "$BUSINESS_SKILL_DIR" ]; then
  # 使用 PATH_CONFIG 中解析到的 BIZ_RULES_DIR
  if [ -n "$BIZ_RULES_DIR" ] && [ -d "$BIZ_RULES_DIR" ]; then
    # 将逗号分隔的关键字列表转为数组
    IFS=',' read -ra BIZ_ARRAY <<< "$BIZ_KEYWORDS"
    
    for biz in "${BIZ_ARRAY[@]}"; do
      # 去除首尾空格
      biz=$(echo "$biz" | xargs)
      [ -z "$biz" ] && continue
      
      biz_file="$BIZ_RULES_DIR/${biz}.md"
      
      # 跳过已由 BIZ_BASE_RULES 加载的基础业务规则文件，避免重复
      if [ -n "$BIZ_BASE_RULES" ] && [ "$biz_file" = "$BIZ_BASE_RULES" ]; then
        echo "  ⏭️ $biz → ${biz}.md（已由 BIZ_BASE_RULES 加载，跳过）"
        continue
      fi
      
      if [ -f "$biz_file" ]; then
        echo "" >> "$OUTPUT_FILE"
        echo "### $biz" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        cat "$biz_file" >> "$OUTPUT_FILE"
        BIZ_COUNT=$((BIZ_COUNT + 1))
        echo "  ✅ $biz → ${biz}.md ($(wc -c < "$biz_file" | tr -d ' ') bytes)"
      else
        echo "" >> "$OUTPUT_FILE"
        echo "### $biz" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "> ⚠️ 未找到业务规则文档: ${biz}.md" >> "$OUTPUT_FILE"
        echo "  ⚠️ $biz → ${biz}.md 不存在"
      fi
    done
  else
    echo "" >> "$OUTPUT_FILE"
    echo "> 未找到业务规则目录" >> "$OUTPUT_FILE"
    echo "  ⚠️ 未找到业务规则目录"
  fi
elif [ -z "$BIZ_KEYWORDS" ]; then
  echo "" >> "$OUTPUT_FILE"
  echo "> 未指定业务关键字，跳过业务知识加载" >> "$OUTPUT_FILE"
  echo "  ⚠️ 未指定 --bizKeywords 参数"
else
  echo "" >> "$OUTPUT_FILE"
  echo "> 未找到业务 Skill 目录: $BUSINESS_SKILL" >> "$OUTPUT_FILE"
  echo "  ⚠️ 未找到业务 Skill 目录: $BUSINESS_SKILL"
fi

echo "  ✅ 业务知识: ${BIZ_COUNT} 个业务规则文件"

# ==========================================
# 四、架构规范（必选加载）
# ==========================================
echo "" >> "$OUTPUT_FILE"
echo "## 四、架构规范" >> "$OUTPUT_FILE"

# 4.1 示例代码（必选）
echo "" >> "$OUTPUT_FILE"
echo "### 4.1 示例代码" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 使用前置校验中已定义的路径变量 BIZ_EXAMPLE_CODE
if [ -f "$BIZ_EXAMPLE_CODE" ]; then
  cat "$BIZ_EXAMPLE_CODE" >> "$OUTPUT_FILE"
  echo "  ✅ 示例代码 ($(wc -c < "$BIZ_EXAMPLE_CODE" | tr -d ' ') bytes)"
else
  echo "  ❌ 错误: 未找到示例代码文件（必选），请检查: $BIZ_EXAMPLE_CODE"
  exit 1
fi

# 4.2 代码 checklist（必选）
echo "" >> "$OUTPUT_FILE"
echo "### 4.2 代码 checklist" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 使用前置校验中已定义的路径变量 BIZ_CHECKLIST
if [ -f "$BIZ_CHECKLIST" ]; then
  cat "$BIZ_CHECKLIST" >> "$OUTPUT_FILE"
  echo "  ✅ 代码 checklist ($(wc -c < "$BIZ_CHECKLIST" | tr -d ' ') bytes)"
else
  echo "  ❌ 错误: 未找到 checklist 文件（必选），请检查: $BIZ_CHECKLIST"
  exit 1
fi

# ==========================================
# 输出统计
# ==========================================
echo ""
echo "=========================================="
TOTAL_SIZE=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
TOTAL_LINES=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
echo "📦 知识库构建完成！"
echo "  - 输出文件: $OUTPUT_FILE"
echo "  - 文件大小: ${TOTAL_SIZE} bytes (约 $((TOTAL_SIZE / 4)) tokens)"
echo "  - 总行数: ${TOTAL_LINES} 行"
echo "  - 组件: ${COMP_COUNT} 个（按需加载）"
echo "  - 业务: ${BIZ_COUNT} 个（按需加载）"
echo "=========================================="
