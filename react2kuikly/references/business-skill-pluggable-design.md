# 业务 Skill 插拔式设计（react2kuikly）

本文件是 `react2kuikly` 框架 Skill 与业务 Skill 之间的「契约说明书」。当你需要为某个新项目接入业务 Skill、或理解 `PATH_CONFIG` 协议时，以本文为准。

---

## 4.1 设计背景：核心矛盾 —— 通用能力 vs 业务差异

| 层级 | 角色 | 内容 |
|------|------|------|
| 框架层（通用） | `react2kuikly` 主 Skill | 所有项目共享的组件映射、样式转换、代码生成流程、脚本工具集 |
| 业务层（差异） | 业务 Skill（如 `biz-react2kuikly`） | 每个项目独有的业务逻辑、组件封装、API 调用、代码风格 |

若不分离，项目差异会被硬编码进框架层，导致：框架更新影响业务代码、新项目需改主文件、多团队并行冲突、无关业务全量加载浪费 token。

## 4.2 设计思路：主从分离、接口约定、动态发现

- **主从分离**：主 Skill 只负责通用转换能力；业务差异全部外置到业务 Skill。
- **接口约定**：双方通过 `PATH_CONFIG` 协议约定资源位置，主 Skill 不感知具体业务内容。
- **动态发现**：主 Skill 在运行时扫描并解析业务 Skill 的 `PATH_CONFIG`，按需加载，零硬编码。

## 4.3 核心机制：PATH_CONFIG 协议

`PATH_CONFIG` 是主 Skill 与业务 Skill 之间的「契约」，嵌入在业务 Skill 的 `SKILL.md` 中，使用 HTML 注释标记边界，避免误解析：

```markdown
<!-- PATH_CONFIG_START -->
EXAMPLE_CODE=references/kuikly-example-code.md
CHECKLIST=references/checklist.md
BIZ_KEYWORDS_MAP=references/react-business-keywords.md
BIZ_RULES_DIR=references/react2kuikly-rules
BIZ_BASE_RULES=references/react2kuikly-rules/基础业务逻辑.md
<!-- PATH_CONFIG_END -->
```

主 Skill 的 `build-knowledge-cache.sh` 会：
1. 定位业务 Skill 目录（`$SKILL_DIR/../$BUSINESS_SKILL`）；
2. 提取 `PATH_CONFIG_START` / `PATH_CONFIG_END` 之间的 `KEY=VALUE`；
3. 拼接为绝对路径并做存在性校验（缺失则报错停止）；
4. 按关键字**按需合并**到 `knowledge-cache.md`。

> 业务 Skill 可使用任意文件名/目录名，只需在 `PATH_CONFIG` 中正确声明即可；**不要删除或修改此块的格式**。

## 4.4 业务 Skill 的 4 项标准能力

| 能力 | 配置项 | 用途 | 使用时机 |
|------|--------|------|----------|
| 业务关键字映射 | `BIZ_KEYWORDS_MAP` | 识别页面涉及哪些业务模块 | 步骤 4.3：扫描源码匹配关键字 |
| 业务转换规则 | `BIZ_RULES_DIR` + `BIZ_BASE_RULES` | 指导具体业务逻辑转化 | 步骤 4.5：按需合并到知识库 |
| 代码 Checklist | `CHECKLIST` | 生成后的规则检查清单 | 步骤 5.2：逐文件检查修正 |
| 参考示例代码 | `EXAMPLE_CODE` | 指导代码架构和风格 | 步骤 5.1 / 5.2：代码生成 |

### 各能力文件职责

- **`BIZ_KEYWORDS_MAP`（`references/<project>-business-keywords.md`）**
  定义「业务关键字 → 源码特征」的映射。格式：`` 【业务关键字】 `` 后列出该业务对应的代码关键字（如 `localStorage`、`useRouter`、`@scrolltolower`）；源码出现对应特征即判定页面涉及该业务。
- **`BIZ_RULES_DIR`（`references/<project>2kuikly-rules/`）**
  按业务关键字存放转换规则文档（如 `本地存储.md`、`平台设备信息.md`、`时间.md`、`滑动加载更多.md`、`自定义子组件.md`）。
- **`BIZ_BASE_RULES`（`references/<project>2kuikly-rules/基础业务逻辑.md`）**
  通用必读文档，无需关键字匹配，所有页面都会自动加载（含项目基础转换原则、硬约束、页面/组件模板、迁移速查）。
- **`CHECKLIST`（`references/checklist.md`）**
  生成代码后逐文件检查修正的规则清单（包名、页面入口、组件写法、业务专项等）。
- **`EXAMPLE_CODE`（`references/kuikly-example-code.md`）**
  完整 Kuikly 页面示例（文件结构、Pager 入口、ComposeView、数据模型、网络请求等），指导生成代码的架构与风格。

---

## 五、业务 Skill 标准结构（创建模板）

新建业务 Skill 时，目录结构如下（`<project>` 为项目名，如 `biz`）：

```
<project>-react2kuikly/
├── SKILL.md                       # name: <project>-react2kuikly + PATH_CONFIG 块 + beacon 上报
├── scripts/
│   ├── beacon-report.sh           # 事件上报（必须）
│   └── beacon-report.js
└── references/
    ├── <project>-business-keywords.md   # BIZ_KEYWORDS_MAP
    ├── checklist.md                     # CHECKLIST
    ├── kuikly-example-code.md           # EXAMPLE_CODE
    └── <project>2kuikly-rules/
        ├── 基础业务逻辑.md              # BIZ_BASE_RULES（必读）
        ├── 平台设备信息.md
        ├── 时间.md
        ├── 本地存储.md
        ├── 滑动加载更多.md
        └── 自定义子组件.md
```

### SKILL.md 最小骨架

```markdown
---
name: <project>-react2kuikly
description: <Project> business knowledge plugin for react2kuikly. Provides business keyword
  mappings, conversion rules, code checklists and example code specific to <Project>.
---

# <Project> React2Kuikly 业务知识 Skill

## 使用事件上报（必须执行）
bash "${SKILL_DIR}/scripts/beacon-report.sh" &

## 路径配置（PATH_CONFIG）
<!-- PATH_CONFIG_START -->
EXAMPLE_CODE=references/kuikly-example-code.md
CHECKLIST=references/checklist.md
BIZ_KEYWORDS_MAP=references/<project>-business-keywords.md
BIZ_RULES_DIR=references/<project>2kuikly-rules
BIZ_BASE_RULES=references/<project>2kuikly-rules/基础业务逻辑.md
<!-- PATH_CONFIG_END -->
```

> **命名约定**：业务 Skill 目录名通常为 `<project>-react2kuikly`，其 `SKILL.md` 的 `name` 必须以 `react2kuikly` 结尾，且与主 Skill 同级放置（脚本经 `$SKILL_DIR/../$BUSINESS_SKILL` 定位）。

## 六、快速创建（脚手架）

推荐使用脚手架脚本一键生成骨架，再补全业务特征：

```bash
bash "${SKILL_DIR}/scripts/scaffold-business-skill.sh" --project "<项目名，如 biz>"
```

脚本会复制内置模板 `react2kuikly-config-skill` 为 `<project>-react2kuikly`，自动重命名 `name` 与 `PATH_CONFIG` 资源路径，并在业务关键字/规则文件顶部标注「项目定制提示」。生成后请填写真实业务特征，详见 `react2kuikly` 主 Skill 的「步骤 0」。
