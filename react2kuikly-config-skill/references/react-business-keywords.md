# React Native 中特定业务关键字对应的代码

【】中是业务关键字，后面是其对应关键代码，出现对应关键代码，则认为页面有【】业务关键字

## 【本地存储】
- AsyncStorage
- @react-native-async-storage/async-storage
- getItem
- setItem

## 【滑动加载更多 / 列表】
- FlatList
- onEndReached
- onEndReachedThreshold
- loadMore
- hasMore

## 【平台设备信息】
- Platform.OS
- Dimensions.get
- StatusBar
- PixelRatio
- DeviceInfo
- SafeAreaView / useSafeAreaInsets

## 【导航路由】
- navigation.navigate
- react-navigation
- createStackNavigator / createBottomTabNavigator
- PagerView（多 Tab / 页面横向切换）

## 【时间】
- 出现 Date 相关方法
- new Date
- Date.now
- getTime
- setTimeout
- setInterval

## 【自定义子组件】
- 出现自定义的 React 组件（class 或 function 组件）
