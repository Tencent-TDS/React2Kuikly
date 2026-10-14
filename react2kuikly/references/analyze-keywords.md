# 步骤 4：提取关键字并预加载知识

## 目标

扫描项目所有源代码文件，提取**组件关键字**和**业务关键字**，再根据关键字按需合并知识文件到 `knowledge-cache.md`，供步骤 5 使用。

> **缓存复用**：`cache/project-keywords.md` 已存在时，提示用户跳过或重新生成，若用户跳过则直接进行步骤4.4。

## 步骤 4.1：收集完整源文件集合

**目标**：确保后续分析覆盖所有业务相关代码，不遗漏跨目录引用的文件。

**执行流程**：

1. **扫描源目录下所有文件的 import/require 语句**，收集所有引用的文件
2. **排除第三方 npm 包**（`node_modules` 下的包），项目内任何被引用的 `.js/.jsx/.ts/.tsx` 文件都必须纳入分析范围，无论它位于哪个目录
3. **识别并标记外部依赖**：引用路径指向源目录之外的文件标记为**外部依赖文件**，同时记录其**被引用的具体导出内容**（组件、函数、常量等）
4. **对外部依赖进行分类**，区分**组件类**和**方法/变量类**：
   - **组件类外部依赖**：被引用的导出内容是 React 组件（class 组件或函数组件），**必须读取其源码文件内容**，添加进文件清单中
   - **方法/变量类外部依赖**：后续只需要匹配业务关键字
5. **输出完整文件集合**：源目录内文件 + 外部依赖文件

> ⚠️ **外部依赖中的组件一定不能漏掉。** 
```bash
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "4.1" --status "completed" --nextAction "继续执行步骤4.2：获取组件关键字"
```

## 步骤 4.2：获取组件关键字

参考 [kuikly-comp-keywords.md](kuikly-comp-keywords.md)：

1. 调用 `kuikly_list_component` 工具获取最新组件列表
2. 扫描**步骤 4.1 收集的完整文件集合**，提取项目中用到的 React Native 组件，映射为 Kuikly 组件关键字
3. 输出**组件关键字列表**

> - **组件类外部依赖**中被引用的组件内部使用的 React Native 组件必须被识别和提取（步骤 4.1 已读取其源码）
> - **方法/变量类外部依赖**不需要分析其内部使用的 React Native 组件，只根据被引用的导出名称判断是否涉及组件关键字
> - **不要分析外部文件中未被引用的部分**

```bash
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "4.2" --status "completed" --nextAction "继续执行步骤4.3：获取业务关键字"
```

## 步骤 4.3：获取业务关键字

1. 根据业务 Skill 的 SKILL.md 中 PATH_CONFIG 配置的 `BIZ_KEYWORDS_MAP` 路径，获取所有业务关键字及对应的代码特征
2. 扫描**步骤 4.1 收集的完整文件集合**，匹配代码特征，确定项目涉及的业务关键词
3. 输出**业务关键字列表**

> - **组件类外部依赖**中被引用的组件内部使用的业务关键字必须被识别和提取（步骤 4.1 已读取其源码）
> - **方法/变量类外部依赖**不需要分析其内部使用的业务关键字，只根据被引用的导出名称判断是否涉及业务关键字
> - **不要分析外部文件中未被引用的部分**

```bash
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "4.3" --status "completed" --nextAction "继续执行步骤4.4：汇总输出项目级关键字集合"
```

## 步骤 4.4：汇总关键字 → `project-keywords.md`

将步骤 4.2、4.3 的关键字写入 `react2kuikly/[页面名]/cache/project-keywords.md`。

**输出格式**（KEY=VALUE，脚本直接读取）：

```
COMP_KEYWORDS=View,Text,Image,List
BIZ_KEYWORDS=登录相关,版本判断,基础业务逻辑
```

格式约定：
- 每行一个参数，`KEY=value1,value2,...`，关键字用英文逗号分隔，**无空格**
- 某类为空则值留空，如 `BIZ_KEYWORDS=`
- 不添加任何 Markdown 标记或注释
- 不确定时关键字尽可能多保留
- 组件关键字必须是 `kuikly_list_component` 返回的组件名，不要自创
- 业务关键字必须在业务 Skill 的关键字文件中有明确定义


```bash
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "4.4" --status "completed" --nextAction "继续执行步骤4.5：用户确认关键字并构建知识库"
```

## 步骤 4.5：构建知识库 → `knowledge-cache.md`

> **缓存复用**：`cache/knowledge-cache.md` 已存在时，提示用户跳过或重新生成。若用户跳过则直接进行步骤5。

### ⏸️ 用户确认关键字

在构建知识库之前，必须先让用户确认关键字是否准确
> **重要**：此为阻塞环节，Agent 必须在此暂停并等待用户输入，不得自动跳过。
### 构建知识库

用户确认后，读取 `cache/project-keywords.md`，调用脚本按需合并知识文件，生成 `react2kuikly/[页面名]/cache/knowledge-cache.md`。

**执行脚本**：

```bash
bash skill/scripts/build-knowledge-cache.sh \
  --pageName "$PAGE_NAME" \
  --businessSkill "$BUSINESS_SKILL" \
  --keywordsFile "react2kuikly/$PAGE_NAME/cache/project-keywords.md"
```

**知识合并规则**：

| 章节 | 加载方式 | 来源 |
|------|---------|------|
| 一、基础框架知识 | **全量** | `docs/dev.txt` |
| 二、组件知识 | **按需** | `docs/{组件名}.txt`，根据 COMP_KEYWORDS |
| 三、业务知识 | **按需** | 业务 Skill PATH_CONFIG 中 `BIZ_RULES_DIR` 指定的目录下 `{关键字}.md`，根据 BIZ_KEYWORDS |
| 四、架构规范 | **必选** | 业务 Skill PATH_CONFIG 中 `EXAMPLE_CODE` + `CHECKLIST` 指定的文件 |

```bash
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "4.5" --status "completed" --nextAction "继续执行步骤5：生成 Kuikly 代码"
```
