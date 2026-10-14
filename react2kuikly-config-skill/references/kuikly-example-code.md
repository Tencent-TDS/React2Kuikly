# Kuikly 代码架构规范（Template 项目示例代码）

## 1 文件结构规范

```
页面名/
├── composedview/          # 组合组件目录
├── models/                # 数据模型目录
│   └── XxxItem.kt         # 数据类型定义
├── XxxPage.kt             # 页面入口（放在根目录）
```

### 文件职责划分

| 文件类型 | 职责 | 不应包含 |
|---------|------|--------|
| **Pager** | 渲染逻辑（`body`）、生命周期、事件处理 | 复杂数据处理 |
| **ComposedView** | 可复用 UI 组件、Attr/Event 定义 | 直接网络请求、全局状态 |
| **Models** | 数据类型、JSON 编解码 | 业务逻辑 |

---

## 2 页面入口（Pager）骨架

```kotlin
package com.tencent.template

import com.tencent.kuikly.core.annotations.Page
import com.tencent.kuikly.core.base.*
import com.tencent.kuikly.core.directives.vif
import com.tencent.kuikly.core.directives.velse
import com.tencent.kuikly.core.directives.vfor
import com.tencent.kuikly.core.module.RouterModule
import com.tencent.kuikly.core.nvi.serialization.json.JSONObject
import com.tencent.kuikly.core.views.*
import com.tencent.kuikly.core.views.compose.Button
import com.tencent.kuikly.core.reactive.handler.*
import com.tencent.template.base.BasePager
import com.tencent.template.base.bridgeModule

@Page("页面名")
internal class XxxPage : BasePager() {

    // ── 响应式状态 ──
    var title by observable("")
    var dataList by observableList<XxxItem>()

    // ── ViewRef 引用 ──
    lateinit var inputRef: ViewRef<InputView>

    // ── 生命周期：页面创建 ──
    override fun created() {
        super.created()
        // 初始化数据加载
    }

    // ── 生命周期：页面加载完成 ──
    override fun viewDidLoad() {
        super.viewDidLoad()
    }

    // ── 生命周期：页面显示 ──
    override fun pageDidAppear() {
        super.pageDidAppear()
    }

    // ── 生命周期：页面销毁 ──
    override fun pageWillDestroy() {
        super.pageWillDestroy()
    }

    // ── UI 渲染入口 ──
    override fun body(): ViewBuilder {
        val ctx = this
        return {
            attr {
                backgroundColor(Color.WHITE)
            }

            // 示例：文本显示
            Text {
                attr {
                    text(ctx.title)
                    fontSize(17f)
                    color(Color.BLACK)
                }
            }

            // 示例：列表渲染
            List {
                attr {
                    flex(1f)
                }
                vfor({ ctx.dataList }) { item ->
                    View {
                        attr {
                            height(50f)
                            flexDirectionRow()
                            alignItemsCenter()
                        }
                        Text {
                            attr {
                                text(item.title)
                                fontSize(15f)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 业务方法 ──
    private fun loadData() {
        bridgeModule.ssoRequest("cmd", JSONObject()) { json ->
            // 处理网络回调
        }
    }

    private fun jumpPage(pageName: String) {
        acquireModule<RouterModule>(RouterModule.MODULE_NAME).openPage(pageName, JSONObject())
    }
}
```

---

## 3 组合组件（ComposeView）骨架

```kotlin
package com.tencent.template

import com.tencent.kuikly.core.base.*
import com.tencent.kuikly.core.reactive.handler.observable
import com.tencent.kuikly.core.views.*

internal class XxxItemView : ComposeView<XxxItemAttr, ComposeEvent>() {
    override fun createEvent(): ComposeEvent {
        return ComposeEvent()
    }

    override fun createAttr(): XxxItemAttr {
        return XxxItemAttr()
    }

    override fun body(): ViewBuilder {
        val ctx = this
        return {
            View {
                attr {
                    flexDirectionRow()
                    alignItemsCenter()
                    padding(10f)
                }
                Image {
                    attr {
                        size(40f, 40f)
                        borderRadius(20f)
                        src(ctx.attr.imageUrl)
                    }
                }
                Text {
                    attr {
                        text(ctx.attr.title)
                        fontSize(15f)
                        marginLeft(10f)
                        flex(1f)
                    }
                }
            }
        }
    }
}

internal class XxxItemAttr : ComposeAttr() {
    var title: String by observable("")
    var imageUrl: String by observable("")
}

internal fun ViewContainer<*, *>.XxxItem(init: XxxItemView.() -> Unit) {
    addChild(XxxItemView(), init)
}
```

---

## 4 数据模型（Model）骨架

### 4.1 数据类

```kotlin
package com.tencent.template

import com.tencent.kuikly.core.nvi.serialization.json.JSONObject
import com.tencent.kuikly.core.reactive.handler.observable

internal class XxxItem {
    // 普通属性
    var id: Long = 0
    var title: String = ""
    var cover: String = ""

    // 响应式属性（需要驱动 UI 更新的）
    var isSelected by observable<Boolean>(false)

    // JSON 解析方法
    fun decode(data: JSONObject): XxxItem {
        title = data.optString("title")
        id = data.optLong("id")
        cover = data.optString("cover")
        return this
    }
}
```

---

## 5 Base 类说明

### 5.1 BasePager

Template 项目的 `BasePager` 继承自 `Pager`，提供以下能力：

- 注册 `BridgeModule` 作为外部模块
- 夜间模式支持（`isNightMode()`）
- 主题变更回调（`themeDidChanged`）

```kotlin
package com.tencent.template.base

import com.tencent.kuikly.core.pager.Pager
import com.tencent.kuikly.core.module.Module
import com.tencent.kuikly.core.nvi.serialization.json.JSONObject
import com.tencent.kuikly.core.reactive.handler.*

internal abstract class BasePager : Pager() {
    private var nightModel: Boolean? by observable(null)

    override fun createExternalModules(): Map<String, Module>? {
        val externalModules = hashMapOf<String, Module>()
        externalModules[BridgeModule.MODULE_NAME] = BridgeModule()
        return externalModules
    }

    override fun isNightMode(): Boolean {
        if (nightModel == null) {
            nightModel = pageData.params.optBoolean(IS_NIGHT_MODE_KEY)
        }
        return nightModel!!
    }

    companion object {
        const val IS_NIGHT_MODE_KEY = "isNightMode"
    }
}
```

### 5.2 BridgeModule

Template 项目通过 `BridgeModule`（模块名 `HRBridgeModule`）与原生端通信，提供以下能力：

| 方法 | 功能 | 类型 |
|------|------|------|
| `closePage()` | 关闭当前页面 | 异步 |
| `log(content)` | 打印日志 | 异步 |
| `toast(content)` | 显示 Toast 提示 | 异步 |
| `openPage(url, closeCurPage, closeSamePage, userData, callbackFn)` | 打开页面 | 异步 |
| `ssoRequest(cmd, reqParams, responseCallbackFn)` | SSO 网络请求 | 异步 |
| `ssoRequest(cmd, reqParams): JSONObject?` | SSO 网络请求（协程版本） | 挂起 |
| `reportDT(eventCode, data)` | 灯塔上报 | 异步 |
| `reportRealTime(eventCode, data)` | 实时上报 | 异步 |
| `reportPageCostTimeForCache()` | 首屏缓存耗时上报 | 异步 |
| `reportPageCostTimeForSuccess()` | 首屏成功耗时上报 | 异步 |
| `reportPageCostTimeForError()` | 首屏失败耗时上报 | 异步 |
| `localServeTime(cb)` | 获取本地服务器时间戳 | 异步 |
| `localServeTime(): JSONObject?` | 获取本地服务器时间戳（协程版本） | 挂起 |
| `currentTimeStamp()` | 同步获取时间戳（毫秒） | 同步 |
| `dateFormatter(timeStamp, format)` | 同步获取日期格式化 | 同步 |
| `fetchCachedFromNative(key, callbackFn)` | 异步读取本地缓存 | 异步 |
| `getCachedFromNative(key)` | 同步读取本地缓存 | 同步 |
| `setCachedToNative(key, value, callbackFn)` | 写入本地缓存 | 异步 |
| `copyToPasteboard(content)` | 复制到剪贴板 | 异步 |
| `showAlert(title, message, leftBtnTitle, rightBtnTitle, callbackFn)` | 显示弹窗 | 异步 |
| `callPhone(phoneNumber)` | 拨打电话 | 异步 |
| `preDownloadImage(url, callbackFn)` | 预下载图片资源 | 异步 |
| `urlEncode(string)` | URL 编码 | 同步 |
| `urlDecode(string)` | URL 解码 | 同步 |
| `closeKeyboard()` | 关闭键盘 | 同步 |

### 5.3 获取 BridgeModule 的方式

```kotlin
// 方式一：通过 IPagerIdKtx 扩展属性（推荐）
import com.tencent.template.base.bridgeModule

bridgeModule.toast("提示内容")
bridgeModule.ssoRequest("cmd", reqParams) { response -> }

// 方式二：通过 Utils 工具类
Utils.bridgeModule(pagerId).toast("提示内容")
```

### 5.4 setTimeout 工具

```kotlin
import com.tencent.template.base.setTimeout

// 延时执行
setTimeout(1000) {
    // 延时回调
}
```

---

## 6 Import 路径汇总

### 框架核心

```
com.tencent.kuikly.core.annotations.Page
com.tencent.kuikly.core.base.Color
com.tencent.kuikly.core.base.ViewBuilder
com.tencent.kuikly.core.base.ViewRef
com.tencent.kuikly.core.base.ViewContainer
com.tencent.kuikly.core.base.Border
com.tencent.kuikly.core.base.BorderStyle
com.tencent.kuikly.core.base.ComposeView
com.tencent.kuikly.core.base.ComposeAttr
com.tencent.kuikly.core.base.ComposeEvent
com.tencent.kuikly.core.base.Direction
com.tencent.kuikly.core.base.ColorStop
```

### 指令系统

```
com.tencent.kuikly.core.directives.vif
com.tencent.kuikly.core.directives.velseif
com.tencent.kuikly.core.directives.velse
com.tencent.kuikly.core.directives.vfor
com.tencent.kuikly.core.directives.vforIndex
com.tencent.kuikly.core.directives.vforLazy
com.tencent.kuikly.core.directives.vbind
```

### 响应式

```
com.tencent.kuikly.core.reactive.handler.observable
com.tencent.kuikly.core.reactive.handler.observableList
```

### UI 组件

```
com.tencent.kuikly.core.views.View
com.tencent.kuikly.core.views.Text
com.tencent.kuikly.core.views.Image
com.tencent.kuikly.core.views.ImageView
com.tencent.kuikly.core.views.Input
com.tencent.kuikly.core.views.InputView
com.tencent.kuikly.core.views.List
com.tencent.kuikly.core.views.Scroller
com.tencent.kuikly.core.views.FooterRefresh
com.tencent.kuikly.core.views.FooterRefreshView
com.tencent.kuikly.core.views.FooterRefreshState
com.tencent.kuikly.core.views.FooterRefreshEndState
com.tencent.kuikly.core.views.compose.Button
```

### 模块

```
com.tencent.kuikly.core.module.RouterModule
com.tencent.kuikly.core.module.SharedPreferencesModule
com.tencent.kuikly.core.module.CallbackFn
```

### 工具类

```
com.tencent.kuikly.core.nvi.serialization.json.JSONObject
com.tencent.kuikly.core.nvi.serialization.json.JSONArray
com.tencent.kuikly.core.timer.setTimeout
com.tencent.kuikly.core.utils.urlParams
```

### 业务基础（Template 项目）

```
com.tencent.template.base.BasePager
com.tencent.template.base.BridgeModule
com.tencent.template.base.Utils
com.tencent.template.base.bridgeModule
com.tencent.template.base.setTimeout
```
