---
name: react2kuikly
description: Convert React / React Native page code to Kuikly page code. Use this skill when the user wants to transform React (RN) frontend pages into Kuikly (Kotlin-based cross-platform framework) pages. Provides a complete step-by-step workflow including code analysis, keyword extraction, knowledge gathering, code generation, optimization and validation.
---

# react2kuikly



## Skill 简介

将 React / React Native 页面代码转化为 Kuikly 页面代码的完整工作流。

## 主 Skill 与业务 Skill

`react2kuikly/` 是主 Skill，负责通用的 React Native 到 Kuikly 转码流程。`react2kuikly-config-skill/` 是业务知识 Skill 模板，不是第二个主 Skill，也不会独立完成转码。

为具体项目接入业务规则时，优先使用脚手架：

```bash
bash "$SKILL_DIR/scripts/scaffold-business-skill.sh" --project "<项目名>"
```

脚手架会基于 `react2kuikly-config-skill/` 生成 `<项目名>-react2kuikly/`，并自动重命名 frontmatter `name` 与 `PATH_CONFIG` 资源路径。也可以手动复制模板，但必须保留 `PATH_CONFIG_START` / `PATH_CONFIG_END` 标记及配置项。

执行本 Skill 时，步骤 0 会扫描同级业务 Skill。确定 `BUSINESS_SKILL` 后，知识缓存脚本通过业务 Skill 名称加载项目规则：

```bash
bash "$SKILL_DIR/scripts/build-knowledge-cache.sh" \
  --pageName "$PAGE_NAME" \
  --businessSkill "$BUSINESS_SKILL" \
  --keywordsFile "react2kuikly/$PAGE_NAME/cache/project-keywords.md"
```

如果用户明确说暂不接入业务 Skill 且接受通用转码质量，可以跳过步骤 0 的创建动作，但进度或审计中必须标记“未接入业务 Skill”。

## 使用方式

用户提供需要转化的 React / React Native 源代码文件，指定以下信息：
- **业务 Skill**：业务方的 Skill 名称，用于获取业务关键字和转换规则。**若不存在，步骤 0 会检测并帮你创建一套**（详见步骤 0）
- **目标 package**：指定生成的 Kuikly 代码放在哪个 package 下（如 `com.example.business.kuikly.pages.home`）
- **输出目录**（可选）：指定生成的 Kuikly 代码存放目录。默认为 `react2kuikly/[页面名]/working/`，用户可自定义为项目中的任意目录（如 `kuikly/main/kotlin/com/example/pages/home`）

> **业务 Skill 要求**：业务关键字由业务方 Skill 提供，不同项目可接入不同的业务 Skill。业务 Skill 需提供以下 4 项能力：
> 1. **业务关键字与代码特征的映射** — 定义业务关键字及其对应的源码特征，用于识别页面涉及的业务
> 2. **业务规则文档** — 按关键字查询对应的业务转换规则，指导代码转化
> 3. **代码 checklist**（必选） — 生成代码后逐文件进行规则检查和修正
> 4. **参考示例代码**（必选） — 提供完整的 Kuikly 页面示例，用于指导代码架构和风格
>
> **业务 Skill 路径配置规范（PATH_CONFIG）**：业务 Skill 必须在 SKILL.md 中通过 `PATH_CONFIG` 配置块声明资源路径，脚本会从中**动态解析**路径，不硬编码任何路径规则：
> ```markdown
> <!-- PATH_CONFIG_START -->
> ```
> EXAMPLE_CODE=references/kuikly-example-code.md
> CHECKLIST=references/checklist.md
> BIZ_KEYWORDS_MAP=references/react-business-keywords.md
> BIZ_RULES_DIR=references/react2kuikly-rules
> ```
> <!-- PATH_CONFIG_END -->
> ```
> 不同业务 Skill 可使用不同的文件名和目录名，只需在 PATH_CONFIG 中正确声明即可。
>
> **前置校验**：业务 Skill 的存在性与创建由 **步骤 0** 统一处理；若用户确认不接入业务 Skill，则至少需指定目标 package，**否则停止任务**。

### 变量定义

在流程开始时，根据用户输入设置以下变量，后续所有步骤和脚本均使用这些变量：

```bash
PAGE_NAME="[页面名称]"          # 页面名称
BUSINESS_SKILL="[业务Skill名]"  # 业务 Skill 名称
OUTPUT_DIR="[输出目录]"          # Kuikly 代码输出目录（默认: react2kuikly/$PAGE_NAME/working）
```

> **OUTPUT_DIR 说明**：如果用户指定了输出目录，则使用用户指定的路径；否则使用默认值 `react2kuikly/$PAGE_NAME/working`。后续所有步骤中提到的"输出目录"均指 `$OUTPUT_DIR`。

### 示例 prompt

```
请将 src/visitors下的代码 根据react2kuikly skill转化为 Kuikly 代码，业务 Skill 为 biz-react2kuikly，目标 package 为 package com.example.business.bizkuikly.pages.feat.visitors，输出到/path/to/project/bizkuikly/kuikly_biz/src/commonMain/kotlin/com/example/business/bizkuikly/pages/feat/visitors
```

### 🔄 继续执行 / 新对话恢复机制

当用户说"继续执行"、"继续生成"、"继续"等类似表达时，**必须先读取 progress 文件确认当前进度**，然后从上次中断的步骤继续执行。

**执行流程**：

1. **读取进度文件**：读取 `react2kuikly/[页面名称]/cache/progress.md` 文件内容
2. **解析当前状态**：
   - 查看"当前状态"字段，确认整体进度
   - 查看"下一步操作"字段，确认应该执行什么
   - 查看各步骤的完成状态（`[x]` 已完成，`[ ]` 未完成）
3. **跳转到对应步骤**：根据进度直接跳转到未完成的步骤继续执行，**不要从头开始**
4. **如果是新对话**（没有上下文信息），额外执行：
   ```bash
   bash skill/scripts/check-progress.sh --pageName "[页面名称]" --outputDir "$OUTPUT_DIR"
   ```
   查看工作目录中的现有文件，建立上下文后再继续

> **重要**：继续执行时，已完成的步骤不要重复执行，直接从"下一步操作"指示的步骤开始。

---

## 执行步骤

按照以下步骤流程执行 React / React Native 页面转 Kuikly 的转换。

---

### 步骤 0：业务 Skill 检测与插拔引导（必须首先执行）

> **目标**：确认是否存在业务 Skill（业务插件）。业务 Skill 承载项目特有的业务逻辑、组件封装、API 调用与代码风格，是转码质量的关键。若缺失，本步骤会引导你快速创建一套，避免把项目差异硬编码进框架层。

**1. 插拔式设计速览（详见 [references/business-skill-pluggable-design.md](references/business-skill-pluggable-design.md)）**

主 Skill（`react2kuikly`，框架层）与业务 Skill（业务层）采用「主从分离、接口约定、动态发现」的插拔式架构：
- 主 Skill 提供通用能力：组件映射、样式转换、代码生成流程、脚本工具集；
- 业务 Skill 通过 `PATH_CONFIG` 协议声明资源路径，主 Skill 在运行时**动态解析、按需加载**，零硬编码；
- 业务 Skill 必须提供 **4 项标准能力**（见下表），缺任意一项都将导致转码质量下降或脚本失败。

| 能力 | 配置项 | 用途 | 使用时机 |
|------|--------|------|----------|
| 业务关键字映射 | `BIZ_KEYWORDS_MAP` | 识别页面涉及哪些业务模块 | 步骤 4.3 扫描源码匹配关键字 |
| 业务转换规则 | `BIZ_RULES_DIR` + `BIZ_BASE_RULES` | 指导具体业务逻辑转化 | 步骤 4.5 按需合并到知识库 |
| 代码 Checklist | `CHECKLIST` | 生成后的规则检查清单 | 步骤 5.2 逐文件检查修正 |
| 参考示例代码 | `EXAMPLE_CODE` | 指导代码架构和风格 | 步骤 5.1 / 5.2 代码生成 |

**2. 检测已安装的业务 Skill**

运行以下命令，扫描主 Skill 的兄弟目录（业务 Skill 与主 Skill 同级放置，脚本经 `$SKILL_DIR/../$BUSINESS_SKILL` 定位）：

```bash
SKILL_DIR_ABS="$(cd "${SKILL_DIR}" && pwd)"
PARENT_DIR="$(dirname "$SKILL_DIR_ABS")"
echo "在 $PARENT_DIR 下检测业务 Skill ..."
for d in "$PARENT_DIR"/*/; do
  sd="$d/SKILL.md"
  [ -f "$sd" ] || continue
  nm=$(grep -m1 '^name:' "$sd" | sed 's/^name:[[:space:]]*//')
  [ -z "$nm" ] && continue
  [ "$nm" = "react2kuikly" ] && continue
  case "$nm" in
    *react2kuikly) echo "  发现业务 Skill: $nm" ;;
  esac
done
```

- **若发现 1 个**：直接将其作为 `BUSINESS_SKILL`（如有疑问用 AskUserQuestion 与用户确认）。
- **若发现多个**：用 AskUserQuestion 让用户选择要使用哪一个，设为 `BUSINESS_SKILL`。
- **若未发现（0 个）**：进入第 3 步引导创建。

> 业务 Skill 目录名通常为 `<项目名>-react2kuikly`（如 `biz-react2kuikly`），也可使用通用模板 `react2kuikly-config-skill`。其 `SKILL.md` 的 `name` 字段必须以 `react2kuikly` 结尾，且包含完整 `PATH_CONFIG` 块（否则 `build-knowledge-cache.sh` 会校验失败）。

**3. 无业务 Skill → 提醒并帮用户创建一套**

若第 2 步未发现任何业务 Skill，**先向用户说明业务 Skill 的价值**（项目差异解耦、按需加载节省 token、框架/业务独立演进），然后**帮助创建一套**，二选一：

- **方式 A（推荐，自动化）**：运行脚手架脚本，基于内置模板一键生成骨架，再让用户补全业务特征：

  ```bash
  bash "${SKILL_DIR}/scripts/scaffold-business-skill.sh" --project "<项目名>"
  # 生成 <项目名>-react2kuikly/ 业务 Skill（含 PATH_CONFIG 与 4 项能力文件）
  ```

  生成后：① 请用户把真实业务关键字填入 `references/<项目名>-business-keywords.md`；② 按需修改 `references/<项目名>2kuikly-rules/` 下的规则文档（平台设备信息 / 时间 / 本地存储 / 滑动加载更多 / 自定义子组件）；③ 将 `BUSINESS_SKILL` 设为 `<项目名>-react2kuikly`。

- **方式 B（手动）**：复制 `react2kuikly-config-skill/` 模板为 `<项目名>-react2kuikly/`，按 [references/business-skill-pluggable-design.md](references/business-skill-pluggable-design.md) 的「业务 Skill 标准结构」补齐 `PATH_CONFIG` 与 4 项能力文件。

**4. 确定 BUSINESS_SKILL 后继续**

将选中的业务 Skill 名称写入变量，后续 `build-knowledge-cache.sh` 等脚本均通过它动态加载业务知识：

```bash
BUSINESS_SKILL="[业务Skill名]"   
```

> 完成本步骤后再进入步骤 1。若用户明确说「暂不需要业务 Skill 且接受通用转码质量」，可跳过，但需在进度中标注「未接入业务 Skill」。

### 步骤 1：创建目标目录

检查并创建页面目录结构。如果目录已存在，则跳过创建：

```bash
# 创建页面目录结构（含输出目录）
bash skill/scripts/setup-page-dirs.sh --pageName "$PAGE_NAME" --outputDir "$OUTPUT_DIR"
```

**目录结构**（在用户项目根目录下创建）：
```
<用户项目根目录>/
├── react2kuikly/
│   └── [页面名称]/
│       └── cache/                         # 缓存目录
│           ├── progress.md                # 进度跟踪文件
│           ├── project-keywords.md        # 提取的关键字集合（步骤 4.4 生成）
│           ├── knowledge-cache.md         # 统一转化知识库（步骤 4.5 生成）
│           ├── analysis-report.md         # 代码分析报告（步骤 5.1 生成）
│           ├── conversion-plan.md         # 转换计划（步骤 5.1 生成）
└── $OUTPUT_DIR/                           # 代码输出目录（默认: react2kuikly/[页面名]/working/）
    ├── [PageName]Pager.kt                 # 页面入口文件
    ├── composedview/                      # 组合组件目录
    ├── models/                            # 数据模型目录
    ├── viewmodel/                         # ViewModel 目录
    └── utils/                             # 工具类/常量定义
```

> **注意**：`react2kuikly/[页面名]/cache/` 始终在项目根目录下创建，用于存放缓存和进度文件。代码输出目录 `$OUTPUT_DIR` 可由用户自定义指定。代码输出目录结构根据传入的代码架构来生成。

**进度跟踪**：
- 每个页面都有独立的 `progress.md` 文件记录转换进度
- 支持新对话中基于进度恢复工作
- 自动记录每步的完成状态和下一步操作

### 步骤 2：预处理 - 提取内联资源

**目标**：提取 React / React Native 源代码中的内联资源（base64 图片、SVG 组件），保存为本地图片文件并替换源代码引用，显著减少后续转换步骤的 token 消耗。

**详细流程**：参考 [步骤2详细流程](references/preprocess-inline-assets.md) 执行内联资源提取，包括：

- **扫描并提取 base64 内联图片** — 解码保存为 `.png`/`.jpeg` 等本地图片
- **扫描并提取 SVG 组件** — 识别 `react-native-svg` 组件，提取为独立 `.svg` 文件
- **替换源代码引用** — 内联数据替换为 `require('./assets/xxx')`，清理不再需要的 SVG import

**执行**：
```bash
node skill/scripts/extract-inline-assets.js --sourceDir "[React Native源代码目录]"
```

**进度更新**：
```bash
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "2" --status "completed" --nextAction "继续执行步骤3：检查知识缓存"
```

### 步骤 3：检查知识缓存文件

检查当前页面是否已存在知识缓存文件：

```bash
bash skill/scripts/check-cache.sh --pageName "$PAGE_NAME"
```

**脚本执行结果**：
- **返回 0**：发现缓存文件且用户选择使用 → 若 `knowledge-cache.md` 存在则可直接跳转到 [步骤 5：生成 Kuikly 代码](#步骤-5生成-kuikly-代码)，否则跳转到步骤 4
- **返回 1**：发现缓存文件但用户选择重新生成 → 继续执行步骤 4
- **返回 2**：未发现缓存文件 → 继续执行步骤 4

**缓存文件检查**：
- `react2kuikly/[页面名]/cache/project-keywords.md` - 项目级关键字集合缓存

**进度更新**：
```bash
# 步骤3完成后更新进度
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "3" --status "completed" --nextAction "继续执行步骤4或跳转到步骤5"
```

### 步骤 4：分析代码并提取关键字

> **缓存复用**：`cache/knowledge-cache.md` 已存在时，提示用户跳过或重新生成。若用户跳过则直接进行步骤5。

**详细流程**：参考 [步骤4详细流程](references/analyze-keywords.md) 进行关键字分析，包括：

- **步骤 4.1**：收集完整源文件集合
- **步骤 4.2**：获取组件关键字
- **步骤 4.3**：获取业务关键字
- **步骤 4.4**：汇总关键字集合（组件关键字 + 业务关键字）
- **步骤 4.5**：**用户确认关键字**后，运行 `build-knowledge-cache.sh` 脚本，读取步骤 4.4 生成的 `cache/project-keywords.md` 文件，自动解析其中的关键字列表，**按需**合并知识（必读+框架全量，组件+业务按需 → `knowledge-cache.md`）

**进度更新**：
```bash
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "4.5" --status "completed" --nextAction "继续执行步骤5：生成 Kuikly 代码"
```
### 步骤 5：生成 Kuikly 代码

进行分文件、渐进式的代码转换。

**执行子skill**：
```bash
# 更新进度
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "5" --status "in_progress" --nextAction "执行步骤5生成 Kuikly 代码"
```

**详细转换流程**：
参考 [步骤5详细流程](references/react2kuikly-generate.md) 进行完整的代码转换，包括：

- **步骤 5.1**：分析文件结构和依赖关系
- **暂停确认**：展示转换计划（转换顺序、输出文件、不转换文件等），**等待用户确认后**再继续
- **步骤 5.2**：逐文件转换
- **步骤 5.3**：架构整理与目录规范化

**转换特点**：
- 单一组件转换策略，避免复杂度爆炸
- 渐进式转换：基础组件 → 页面组件

**输出目录**：

根据 `knowledge-cache.md` 中架构规范（示例代码）的目录结构来决定各类文件的输出位置。转换后的文件统一输出到 `$OUTPUT_DIR` 下，子目录结构以示例代码为准。

**完成标志**：
```bash
# 步骤5完成后更新进度
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "5" --status "completed" --nextAction "继续步骤6：代码验证和完善"
```

### 步骤 6：代码验证和完善

**目标**：最终验证和完善转换结果，确保功能完整性和代码可编译。

**详细流程**：参考 [步骤6详细流程](references/verify-and-refine.md) 进行代码验证和完善，包括：

- **步骤 6.1**：逻辑功能完整性验证（逐文件对比源代码和生成代码，检查分支、循环、状态、事件等逻辑完整性）
- **步骤 6.2**：编译检查（使用 `analyze_files` 工具循环检测并修正编译错误）

**完成标志**：
```bash
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "6.2" --status "completed" --nextAction "全部转换流程结束"
```

---

## Reference 文件说明

### 脚本工具

| 文件 | 说明 |
|------|------|
| `scripts/setup-page-dirs.sh` | 创建页面目录结构 |
| `scripts/extract-inline-assets.js` | 提取内联资源（base64/SVG）预处理 |
| `scripts/check-cache.sh` | 检查知识缓存文件 |
| `scripts/check-progress.sh` | 检查转换进度（新对话恢复） |
| `scripts/update-progress.sh` | 更新转换进度 |
| `scripts/analyze-file-structure.sh` | 分析文件结构和依赖关系 |
| `scripts/build-knowledge-cache.sh` | 根据关键字列表按需构建转化知识库（必读+框架全量，组件+业务按需合并） |

### Reference 文件

| 文件 | 说明 |
|------|------|
| `references/preprocess-inline-assets.md` | 步骤 2 预处理内联资源详细流程 |
| `references/analyze-keywords.md` | 步骤 4 分析代码并提取关键字详细流程 |
| `references/kuikly-comp-keywords.md` | Kuikly 组件关键字获取指引 |
| `references/react2kuikly-generate.md` | 步骤 5 代码生成详细流程 |
| `references/verify-and-refine.md` | 步骤 6 代码验证和完善详细流程 |
| `references/business-skill-pluggable-design.md` | 业务 Skill 插拔式设计（PATH_CONFIG 协议 + 4 项标准能力 + 创建模板），详见步骤 0 |
