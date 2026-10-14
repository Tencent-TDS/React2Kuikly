# React2Kuikly 步骤2：预处理 - 提取内联资源

## 目标

提取 React Native 源代码中的内联资源（base64 图片、SVG 组件），将它们保存为本地图片文件，并替换源代码中的引用。这样可以显著减少后续转换步骤中的 token 消耗，避免大段 base64 和 SVG Path 数据浪费上下文。

## 执行方式

```bash
# 执行内联资源提取脚本
node skill/scripts/extract-inline-assets.js --sourceDir "[React Native源代码目录]"
```

**参数说明**：
- `--sourceDir`：必填，React Native 源代码目录的绝对路径或相对路径

**外部依赖追踪**：脚本会自动从源目录内的文件出发，解析所有 import/require 语句（支持相对路径和 `@/` 别名路径），递归追踪源目录外部被引用的文件。这些外部依赖文件中的 base64 图片和 SVG 组件也会被一并提取。只有第三方 npm 包（`node_modules` 下的包）会被排除。

## 脚本功能

### 1. 扫描 base64 内联图片

匹配源代码中 `data:image/xxx;base64,...` 格式的变量定义，将 base64 数据解码保存为本地图片文件（`.png`/`.jpeg` 等）。

**匹配模式**：
```javascript
// 匹配以下形式的变量声明
const varName = 'data:image/png;base64,iVBOR...';
const varName = "data:image/jpeg;base64,/9j/4A...";
```

### 2. 扫描 SVG 组件定义

识别基于 `react-native-svg` 的 SVG 组件，提取 `<Svg>` 和 `<Path d="..."/>` 数据生成独立的 `.svg` 文件。

**识别条件**：
- 文件中包含 `react-native-svg` 的 import，或同时包含 `<Svg` 和 `<Path` 标签
- 导出组件内部包含 `<Svg` 标签
- 导出组件内部包含 `<Path d="...">` 数据

**尺寸提取优先级**：
1. 组件内的 `const width = N` / `const height = N` 变量定义
2. `<Svg>` 标签上的 `width={N}` / `height={N}` 属性
3. `viewBox` 中的宽高值
4. 默认值 24×24

**提取范围**：
- 源目录内部定义的 SVG 组件
- 源目录外部被引用的 SVG 图标组件（自动通过 import 路径检测，支持相对路径和 `@/` 别名路径）
- 外部依赖文件中的 base64 内联图片（自动递归追踪）

### 3. 替换 base64 引用

将内联 base64 数据替换为本地图片路径字符串：

```javascript
// 替换前
const bgImage = 'data:image/png;base64,iVBOR...';

// 替换后
const bgImage = './assets/bgImage.png';
```

### 4. 替换 SVG 组件引用

将 SVG 组件标签替换为 `<Image>` 组件引用本地 SVG 文件：

```jsx
// 替换前
import { IconArrow } from '../../component/Icon';
<IconArrow style={{ width: 24, height: 24 }} />

// 替换后
<Image source={'./assets/icon_arrow.svg'} style={{ width: 24, height: 24 }} />
```

**color → tintColor 自动转换**：如果 SVG 组件设置了 `color` 属性，替换后会自动转为 `tintColor` 属性（与 `style` 同级）：

```jsx
// 替换前
<IconArrow color={commonStyle.fontColor} style={{ width: 24, height: 24 }} />

// 替换后（color 转为同级的 tintColor 属性）
<Image source={'./assets/icon_arrow.svg'} style={{ width: 24, height: 24 }} tintColor={commonStyle.fontColor} />

// 替换前（只有 color，没有 style）
<IconPlay color="#ffffff" />

// 替换后
<Image source={'./assets/icon_play.svg'} tintColor={'#ffffff'} />
```

**同时执行**：
- 清理不再需要的 SVG import 语句
- 确保 `Image` 组件已被正确 import（如不存在则自动添加到 `react-native` 的 import 中）

## 输出

- 在 React Native 源目录下创建 `assets/` 子目录，保存提取的图片文件
- 源代码中的内联资源引用被替换为本地图片引用
- 控制台输出提取汇总报告（base64 图片数量、SVG 组件数量、生成的文件列表）

## 注意事项

1. **无内联资源**：如果源代码中没有内联资源，脚本会正常结束并提示"无需预处理"
2. **SVG 颜色**：SVG 文件中 fill 默认为 `#000000`，原始代码中通过 `color` 属性动态传入的颜色会被脚本自动转换为 `tintColor` 样式。如果有未被自动处理的情况，转 Kuikly 时可手动用 `tintColor` 处理图标着色
3. **人工检查**：脚本执行后建议人工检查替换结果，确保无遗漏
4. **排除目录**：脚本自动排除 `node_modules`、`scripts`、`assets`、`.git` 目录
5. **幂等性**：重复执行不会产生重复文件（同名文件会被覆盖）

## 进度更新

```bash
bash skill/scripts/update-progress.sh --pageName "$PAGE_NAME" --step "2" --status "completed" --nextAction "继续执行步骤3：检查知识缓存"
```
