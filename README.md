# React2Kuikly

把 React / React Native 页面翻译成 Kuikly 代码的 Skill 仓库。主 Skill 负责通用翻译流程，业务 Skill 只补项目差异：先分析清楚，再按依赖逐文件生成，最后用编译和审计兜底。

迁移流水线：**零创造、零遗漏、按需规则、逐文件生成、编译闭环。**

## 仓库内容

| 目录 | 角色 |
| --- | --- |
| [`react2kuikly`](react2kuikly/SKILL.md) | 主 Skill。负责源码分析、关键字提取、按需知识加载、逐文件生成、架构整理和编译验证。 |
| [`react2kuikly-config-skill`](react2kuikly-config-skill/SKILL.md) | 业务 Skill 模板。通过 `PATH_CONFIG` 注入项目关键字、业务规则、Checklist 和示例代码。 |

设计说明、流程图和接入细节见 [`react2kuikly/README.md`](react2kuikly/README.md)。

## 转码流程

1. **读源项目。** 读取入口页面、组件依赖、状态、样式、资源、路由、请求和存储，列出 React 里实际有什么。
2. **分析语义和依赖。** 识别状态、props、hooks、事件、条件渲染、列表和资源引用，并按依赖分层排序。不按文件名猜测语义。
3. **加载转码知识。** 主 Skill 加载框架通用规则。传入业务 Skill 时，通过 `PATH_CONFIG` 加载项目自己的关键字、业务规则、Checklist 和示例代码。
4. **逐文件迁移。** 先转模型 / 工具，再转叶子组件，再转组合组件，最后转页面入口。关键逻辑保留 `// Source:` 注释，保证可追溯。
5. **资源同步。** 把图片、字体、SVG 和静态资源迁到目标 Kuikly assets，并生成资源映射。内联 base64 / SVG 会先抽成本地文件，避免占用上下文。
6. **验证修复。** 跑 Kuikly 编译和资源校验。编译失败时按目标项目已有 API 修，不新增不存在的扩展函数。

## 主从分离

`react2kuikly` 是主 Skill，`react2kuikly-config-skill` 是业务 Skill。二者采用主从分离、接口约定、动态发现的插拔式架构：

- 主 Skill 只负责通用转换，不感知具体业务。
- 业务 Skill 用 `PATH_CONFIG` 声明资源路径，主 Skill 运行时扫描并加载，路径不写死。
- 项目差异放在业务 Skill 里，不写进框架层。

接入某个项目时，用脚手架从模板生成业务 Skill：

```bash
bash react2kuikly/scripts/scaffold-business-skill.sh --project myproject
# 生成 myproject-react2kuikly/
```

也可以手动复制 `react2kuikly-config-skill`。业务 Skill 的 `SKILL.md` 必须保留 `PATH_CONFIG_START` / `PATH_CONFIG_END`，并声明示例代码、Checklist、业务关键字和规则目录。执行时指定业务 Skill 名称、目标 package 和输出目录。示例：

```text
请将 src/visitors 下的代码根据 react2kuikly skill 转化为 Kuikly 代码，业务 Skill 为 myproject-react2kuikly，目标 package 为 com.example.business.kuikly.pages.visitors
```

未接入业务 Skill 时可以做通用转码，进度或审计里需要标记“未接入业务 Skill”。完整步骤见 [`react2kuikly/SKILL.md`](react2kuikly/SKILL.md)。

## 测评记录

| 项 | 内容 |
| --- | --- |
| 测试工程 | RN App 工程、KuiklyUI 项目 |
| Skill | `react2kuikly` + `react2kuikly-config-skill` |
| 模型 | Codex + GPT 5.5（思考模式：高） |

转码后的 Kuikly 页面：

![React 转码后的 Kuikly 页面](docs/react-result.png)
