# 获取Kuikly组件关键字

## 步骤1：获取组件列表

调用 kuikly-mcp 的 `kuikly_list_component` 工具来获取最新的完整组件列表。

如果MCP工具不存在或工具调用失败，使用以下备选组件列表：

| 组件名 | 说明 |
|--------|------|
| WaterfallList | 瀑布流组件 |
| View | 视图组件 |
| Text | 文本组件 |
| Tabs | 选项卡切换组件 |
| Switch | 开关组件 |
| Slider | 滑动选择器组件，可用于拖动进度条场景 |
| SliderPage | 用于展示一组图片或内容的视图组件，支持自动轮播和手动切换页面 |
| RichText | 富文本组件 |
| Refresher | 下拉刷新组件 |
| PAG | pag图片组件 |
| List | 列表组件 |
| Input | 输入框组件 |
| Image | 图片组件 |
| Scroller | 横向滚动组件 |
| Hover | 实现列表滚动时自动悬停置顶功能的专用视图组件 |
| FooterRefresh | 列表底部滑动加载更多组件 |
| DatePicker | 日期选择器组件 |
| CheckBox | 复选框组件 |
| Canvas | 画布组件 |
| Button | 按钮组件 |
| Blur | 模糊效果组件 |
| APNG | APNG图片组件 |
| AlertDialog | 弹窗组件 |
| ActivityIndicator | 加载loading组件 |
| ActionSheet | 弹出式菜单组件 |

## 步骤2：了解组件映射关系

参考 React Native 组件 → Kuikly 组件映射关系：

| React Native 组件 | Kuikly 组件 |
|------------|-------------|
| WaterfallView | WaterfallList |
| View | View |
| Text | Text |
| Image | Image |
| RefreshWrapper | Refresh |
| PAG | PAG |
| ListView | List |
| ScrollView | Scroller |
| TextInput | 单行用 Input，多行用 TextArea |
| Modal | Modal |
| ViewPager | SliderPage |

## 步骤3：分析源代码

仔细阅读 React Native 源代码文件，全面分析代码结构，理解页面功能和 UI 结构。

## 步骤4：确定所需组件

结合 React Native 组件→Kuikly 组件映射关系和 Kuikly 组件介绍中各个组件功能，分析得到该页面用到的所有 Kuikly 组件。