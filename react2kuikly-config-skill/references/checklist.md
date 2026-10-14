# Kuikly 代码规则检查

对生成的 Kuikly 代码逐文件进行以下规则检查，发现不符合的地方直接修正，这里定义了一些常见的幻觉代码的检查规则。

## 基本规则

1. 所有类需要 `internal` 修饰符
2. 不要使用示例代码和 Kuikly 文档中没出现过的语法，如 `slot` 等
3. 包名使用 `com.tencent.template` 开头
4. 页面必须继承 `BasePager`（来自 `com.tencent.template.base.BasePager`）
5. 通过 `bridgeModule` 扩展属性访问 `BridgeModule`，而不是直接实例化

## 属性检查

| 错误写法 | 正确写法 |
|---------|---------|
| `paddingVertical` | 分别设置 `paddingTop` 和 `paddingBottom` |
| `paddingHorizontal` | 分别设置 `paddingLeft` 和 `paddingRight` |
| `marginVertical` | 分别设置 `marginTop` 和 `marginBottom` |
| `marginHorizontal` | 分别设置 `marginLeft` 和 `marginRight` |
| `borderStyle` / `borderWidth` / `borderColor` | 使用 `border(Border(...))` 替代（见下方示例） |
| `numberOfLines` | 使用 `lines(1)` 替代 |
| Text 中使用 `padding` | 改为 `margin` |
| `onPress` | 使用 `event` 中的 `click` 事件 |
| `fontWeight(400)` | 使用 `fontWeight400()` 等预定义方法 |
| Text 中使用 `alignItemsCenter` | 使用 `textAlignCenter()` |

### border 正确写法示例

```kotlin
border(
    Border(
        lineWidth = 2f,
        color = Color(0xFF23D3FD),
        lineStyle = BorderStyle.SOLID
    )
)
```

## 页面规则

1. **主页面**使用 `@Page("页面名")` 注解，继承 `BasePager`
2. **主页面** UI 写在 `override fun body()` 方法中：
```kotlin
override fun body(): ViewBuilder {
    val ctx = this
    return {
        // UI 代码
    }
}
```

3. **组合组件** UI 也写在 `override fun body()` 方法中：
```kotlin
override fun body(): ViewBuilder {
    val ctx = this
    return {
        // 组件 UI 代码
    }
}
```

4. **渲染方法提取与调用**：当页面 `body()` 或组件 `body()` 中需要将部分 UI 拆分为独立渲染方法时，必须遵循以下规则：

   - 渲染方法声明为 **返回 `ViewBuilder` 的普通私有方法**（不要用 `ViewContainer` 扩展函数）
   - 方法体用 `return { ... }` 包裹，在 lambda 内编写 UI 代码
   - 调用处必须用 **`apply()`** 包裹，将渲染方法返回的 `ViewBuilder` 展开到当前渲染上下文中

```kotlin
// ✅ 正确：渲染方法声明 —— 返回 ViewBuilder
private fun buildSomeSection(): ViewBuilder {
    val ctx = this
    return {
        View {
            attr {
                height(46f)
            }
            Text {
                attr {
                    text("内容")
                    fontSize(15f)
                    color(Color.BLACK)
                }
            }
        }
    }
}

// ✅ 正确：在 body() 中用 apply() 调用渲染方法
override fun body(): ViewBuilder {
    val ctx = this
    return {
        apply(ctx.buildSomeSection())
    }
}

// ❌ 错误：不要用 ViewContainer 扩展函数
private fun ViewContainer<*, *>.buildSomeSection() { ... }

// ❌ 错误：不要直接调用（不用 apply 包裹）
ctx.buildSomeSection()
```

## BridgeModule 使用规则

1. 获取 BridgeModule 使用扩展属性 `bridgeModule`：
```kotlin
import com.tencent.template.base.bridgeModule

// 在 BasePager 子类中直接使用
bridgeModule.toast("提示")
bridgeModule.log("日志")
bridgeModule.ssoRequest("cmd", params) { response -> }
```

2. 不要直接 `BridgeModule()` 实例化，始终通过 `bridgeModule` 扩展属性获取

## 路由规则

使用 `RouterModule` 进行页面跳转：
```kotlin
import com.tencent.kuikly.core.module.RouterModule

// 打开页面
acquireModule<RouterModule>(RouterModule.MODULE_NAME).openPage(pageName, pageData)

// 关闭页面
acquireModule<RouterModule>(RouterModule.MODULE_NAME).closePage()
```

或使用 `BridgeModule` 的 `openPage`/`closePage`：
```kotlin
bridgeModule.openPage(url)
bridgeModule.closePage()
```
