#!/bin/bash
# scaffold-business-skill.sh
# 为 react2kuikly 快速生成一个业务 Skill（业务插件）骨架。
# 复制内置模板 react2kuikly-config-skill，按项目名重命名 PATH_CONFIG 资源路径，
# 并在业务特征文件顶部标注「项目定制提示」，作为可编辑起点。
#
# 用法:
#   bash skill/scripts/scaffold-business-skill.sh --project biz
#   bash skill/scripts/scaffold-business-skill.sh --project biz --outputDir /path/to/skills
#
# 说明:
#   - 生成的业务 Skill 目录为 <outputDir>/<project>-react2kuikly
#   - name 字段与 PATH_CONFIG 资源文件名自动按项目名重命名
#   - Kuikly 实现侧内容（example-code / checklist / rules）保留为模板，待用户按项目真实业务覆盖

set -e

PROJECT=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --outputDir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

if [ -z "$PROJECT" ]; then
  echo "错误: 请指定 --project <项目名，如 biz>"
  exit 1
fi

# 项目名只含字母/数字/下划线/连字符，避免路径注入
if ! echo "$PROJECT" | grep -qE '^[A-Za-z0-9_-]+$'; then
  echo "错误: 项目名仅允许字母/数字/下划线/连字符: $PROJECT"
  exit 1
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$(cd "$SKILL_DIR/.." && pwd)/react2kuikly-config-skill"

if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$(cd "$SKILL_DIR/.." && pwd)"
fi

BIZ_SKILL_NAME="${PROJECT}-react2kuikly"
BIZ_SKILL_DIR="$OUTPUT_DIR/$BIZ_SKILL_NAME"

if [ -d "$BIZ_SKILL_DIR" ]; then
  echo "错误: 目标业务 Skill 已存在，拒绝覆盖: $BIZ_SKILL_DIR"
  echo "  如需重建，请先手动删除该目录。"
  exit 1
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "错误: 未找到模板业务 Skill: $TEMPLATE_DIR"
  exit 1
fi

echo "复制模板业务 Skill: $TEMPLATE_DIR -> $BIZ_SKILL_DIR"
cp -R "$TEMPLATE_DIR" "$BIZ_SKILL_DIR"

# 重命名资源文件以匹配项目名
mv "$BIZ_SKILL_DIR/references/react-business-keywords.md" \
   "$BIZ_SKILL_DIR/references/${PROJECT}-business-keywords.md"
mv "$BIZ_SKILL_DIR/references/react2kuikly-rules" \
   "$BIZ_SKILL_DIR/references/${PROJECT}2kuikly-rules"

# 重写 SKILL.md: name + PATH_CONFIG 路径
BIZ_MD="$BIZ_SKILL_DIR/SKILL.md"

# name: template-react2kuikly -> name: <project>-react2kuikly
sed -i '' "s/^name: template-react2kuikly/name: ${BIZ_SKILL_NAME}/" "$BIZ_MD"

# PATH_CONFIG 资源路径重命名
sed -i '' "s#BIZ_KEYWORDS_MAP=references/react-business-keywords.md#BIZ_KEYWORDS_MAP=references/${PROJECT}-business-keywords.md#" "$BIZ_MD"
sed -i '' "s#BIZ_RULES_DIR=references/react2kuikly-rules#BIZ_RULES_DIR=references/${PROJECT}2kuikly-rules#" "$BIZ_MD"
sed -i '' "s#BIZ_BASE_RULES=references/react2kuikly-rules/基础业务逻辑.md#BIZ_BASE_RULES=references/${PROJECT}2kuikly-rules/基础业务逻辑.md#" "$BIZ_MD"

# 在业务特征文件顶部加「项目定制提示」横幅
BANNER_FILE="$(mktemp)"
cat > "$BANNER_FILE" <<EOF
> 项目定制提示：本文件由 react2kuikly 脚手架基于模板生成。请将下方通用示例替换为 ${PROJECT} 项目的真实业务特征与转换规则后再用于转码。

EOF

add_banner() {
  local f="$1"
  if [ -f "$f" ]; then
    cat "$BANNER_FILE" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
}

add_banner "$BIZ_SKILL_DIR/references/${PROJECT}-business-keywords.md"
add_banner "$BIZ_SKILL_DIR/references/${PROJECT}2kuikly-rules/基础业务逻辑.md"
rm -f "$BANNER_FILE"

echo "业务 Skill 已生成: $BIZ_SKILL_DIR"
echo ""
echo "下一步（请补全业务特征）:"
echo "  1. 编辑 references/${PROJECT}-business-keywords.md  填入 ${PROJECT} 项目的真实业务关键字"
echo "  2. 编辑 references/${PROJECT}2kuikly-rules/ 下的规则文档（平台设备信息 / 时间 / 本地存储 / 滑动加载更多 / 自定义子组件）"
echo "  3. 调用 react2kuikly 时指定 --businessSkill ${BIZ_SKILL_NAME}"
echo "  4. 可选：将 ${BIZ_SKILL_NAME}/ 移动到你的 .codebuddy/skills/ 目录，与主 Skill 同级"
