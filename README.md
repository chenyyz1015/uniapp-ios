# uniapp-ios

> 基于 uni-app 框架的 iOS 本地离线打包工程。

- Hbuilder 版本：5.15
- Hbuilder iOS SDK 版本：5.15

## 一、环境准备与版本一致性

| 项目                 | 要求                               |
| :------------------- | :--------------------------------- |
| **Xcode**            | 26.0+（推荐最新稳定版）            |
| **HBuilderX**        | 与离线 SDK 版本号完全一致          |
| **iOS 离线 SDK**     | 从 DCloud 官网下载最新包           |
| **Apple 开发者账号** | 用于生成证书、描述文件及 Bundle ID |

> **版本一致性**：
>
> - 在 HBuilderX 中查看版本号（如 `3.8.4.20230201`）。
> - 离线 SDK 压缩包名称或 `HBuilder-Hello/control.xml` 中 `version` 字段必须与之相同。
> - 版本不一致时，App 启动会弹窗提示并可能功能异常。

## 二、工程结构概览（关键目录说明）

解压离线 SDK 后，核心目录如下：

```text
App-iOS-SDK/
├── HBuilder-Hello/                          # 示例工程（需改造）
│   ├── HBuilder-Hello.xcodeproj             # Xcode 工程文件
│   ├── HBuilder-Hello/                      # 源码主目录
│   │   ├── Pandora/                         # 应用资源目录
│   │   │   └── apps/
│   │   │       └── __UNI__XXXXXX/           # 示例应用包
│   │   ├── control.xml                      # 调试开关、appid配置
│   │   ├── Info.plist                       # 全局配置文件
│   │   └── ...
│   ├── Podfile                              # CocoaPods 依赖管理
│   ├── Pods                                 # CocoaPods 已安装依赖库
│   └── ...
├── Feature-iOS.xls                          # 功能模块配置表（参考用）
└── SDK/                                     # 公共 SDK（独立），自行前往官网下载
```

> `xcuserdata`（位于 `.xcodeproj` 包内）和 `project.xcworkspace` 是本地缓存，可安全删除，Xcode 会重新生成。

## 三、替换为自己的 uni-app 应用资源

### 3.1 生成离线打包资源

1. 在 HBuilderX 中打开你的 uni-app 项目。
2. 点击菜单 **发行 → 原生App-本地打包 → 生成资源**。
3. 选择输出目录，得到 `__UNI__XXXXXX` 文件夹（X 为你的 appid）。

### 3.2 替换 Pandora/apps 目录

1. 在 Xcode 工程中，找到 `Pandora/apps` 目录。
2. 删除原有的 `__UNI__XXXXXX` 文件夹（或备份）。
3. 将你生成的 `__UNI__XXXXXX` 文件夹完整拖入 `apps` 下。

### 3.3 修改 control.xml（关键）

1. 进入 `Pandora/apps/__UNI__XXXXXX/`，打开 `control.xml`。
2. 修改 `appid` 属性值为你的 **DCloud appid**（与 manifest.json 中一致）。
3. **自定义调试基座**时，必须增加 `debug="true" syncDebug="true"`：

```xml
<HBuilder debug="true" syncDebug="true" version="5.15">
  <apps>
    <app appid="__UNI__XXXXXX" appver="1.0.0"/>
  </apps>
</HBuilder>
```

> **注意**：打正式包（App Store）时，必须移除 `debug` 和 `syncDebug`，否则热更新功能失效。

### 3.4 验证资源唯一性

- `Pandora/apps` 下**只能有一个**应用文件夹（即 `__UNI__XXXXXX`）。
- 确保 `control.xml` 中的 `appid` 与文件夹名称一致，且与 HBuilderX 项目 manifest.json 中的 appid 相同。

## 四、Xcode 工程基础配置

### 4.1 修改 Bundle Identifier（应用标识）

1. 在 Xcode 左侧选中工程根目录（`HBuilder-Hello`）。
2. 在中间区域 **TARGETS** 下选中 `HBuilder`。
3. 切换到 **General** 标签页，在 **Identity** 区：
   - **Bundle Identifier**：改为你在苹果开发者后台申请的 App ID（如 `com.yourcompany.yourapp`）。
   - **Version**：与 `manifest.json` 中 `version.name` 保持一致。
   - **Build**：与 `manifest.json` 中 `version.code` 保持一致（整数）。

### 4.2 修改应用名称（Display Name）

- **方式一**：在 **General → Identity → Display Name** 直接填写（如 "我的应用"）。
- **方式二**：在 `Info.plist` 中修改 `CFBundleDisplayName`。
- 推荐与 `manifest.json` 中的 `name` 字段一致。

### 4.3 配置签名（Signing & Capabilities）

1. 勾选 **Automatically manage signing**（自动管理）或手动选择 Profile。
2. 选择正确的 **Team**（开发者账号）。
3. 确保 **Provisioning Profile** 与 Bundle ID 匹配。

## 五、配置 AppKey（3.1.10+ 版本必须）

1. 在 Xcode 中打开 `Info.plist`。
2. 添加一行：
   - **Key**：`dcloud_appkey`
   - **Type**：`String`
   - **Value**：填入从 DCloud 开发者中心申请到的 AppKey。
3. 保存。

> ⚠️ 若 AppKey 不正确或未配置，运行时将弹出 "appkey 错误" 提示。

## 六、配置 URL Scheme（用于外部唤起 App）

### 6.1 在 manifest.json 中配置（推荐）

1. 打开 HBuilderX 项目下的 `manifest.json`。
2. 切换到 **App常用其它设置 → iOS设置 → UrlSchemes**。
3. 填入自定义 scheme（如 `simpleapp`），多个用逗号分隔。
4. 重新生成离线资源并替换（重复第三章步骤）。

### 6.2 在 Xcode 中手动配置（备选）

1. 打开 `Info.plist`，添加 **URL types**。
2. 在 `Item 0` → `URL Schemes` 中添加你的 scheme（注意全小写）。

### 6.3 配置白名单（LSApplicationQueriesSchemes）

若需要检测其他 App（如微信、支付宝）是否安装，需在 `Info.plist` 中添加：

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>weixin</string>
  <string>alipay</string>
</array>
```

- 若 Xcode 界面未显示该项，可右键 `Info.plist` → Open As → Source Code 手动添加。
- 该配置在 iOS 9+ 上有效，用于 `canOpenURL:` 检测。

### 6.4 关于 URL Scheme 唤起的说明

- **Safari 可稳定唤起**，因其为系统应用享有特权。
- **Chrome 等第三方浏览器**可能因安全策略拦截，建议配置 `LSApplicationQueriesSchemes` 并测试。
- 更稳定的长期方案是迁移到 **Universal Link**（通用链接）。

## 七、处理隐私清单（Privacy Manifest，iOS 17+ 要求）

SDK 4.13+ 已内置基础隐私清单。

1. 在 `Info.plist` 中添加 **Privacy - App Privacy Configuration**（或 `NSPrivacyAccessedAPITypes`）。
2. 若集成了 uni-AD 或统计模块，需补充额外条目。

**基础模块默认包含**：

- `User Defaults` (CA92.1)
- `Disk Space` (E174.1)
- `File Timestamp` (C617.1)

## 八、CocoaPods 依赖管理（替换国内镜像源）

若 Pod 下载缓慢，可在 `Podfile` 顶部替换为国内 Git 镜像：

```ruby
# 国内 CDN 镜像
source 'https://cdn.cocoapods.org/'
```

然后执行：

```bash
pod install
# 或
pod install --repo-update
```

之后**必须**打开 `.xcworkspace`（而非 `.xcodeproj`）进行后续操作。

## 九、制作自定义调试基座（关键步骤）

### 9.1 修改 control.xml 开启调试

确保 `debug="true" syncDebug="true"`（参见 3.3 节）。

### 9.2 确保 Bundle ID 不为 `io.cloud.HBuilder`

这是示例默认 ID，必须换成你自己的。

### 9.3 开启 iTunes 文件共享（便于查看沙盒）

在 `Info.plist` 中添加：

- **Key**：`Application supports iTunes file sharing`
- **Type**：`Boolean`
- **Value**：`YES`

### 9.4 打包生成 ipa

1. 在 Xcode 菜单栏选择 **Product → Archive**。
2. 归档完成后，在 Organizer 窗口点击 **Distribute App**。
3. 选择 **Development**（或 Ad Hoc）导出 ipa。
4. 将生成的 ipa 重命名为 **`iOS_debug.ipa`**。

### 9.5 将 ipa 放入 HBuilderX 项目目录

在你的 uni-app 项目根目录下：

1. 创建（如有则跳过）`unpackage/debug` 文件夹。
2. 将 `iOS_debug.ipa` 复制到 `unpackage/debug/` 下。

### 9.6 在 HBuilderX 中使用自定义基座运行

1. 确保 HBuilderX 中当前打开的项目 appid 与 `control.xml` 中一致。
2. 点击 **运行 → 运行到手机或模拟器 → 使用自定义基座运行（iOS）**。
3. 连接 iPhone 后，HBuilderX 会将 ipa 安装到设备并启动调试。

## 十、工程改名（安全操作指南）

若要将 `HBuilder-Hello` 改为自己的工程名（如 `SimpleApp`），按以下步骤：

1. 关闭 Xcode。
2. 在 Finder 中：
   - 重命名 `HBuilder-Hello.xcodeproj` → `SimpleApp.xcodeproj`
   - 重命名 `HBuilder-Hello/` 文件夹 → `SimpleApp/`
3. 右键 `SimpleApp.xcodeproj` → 显示包内容，用文本编辑器打开 `project.pbxproj`。
4. 将所有 `HBuilder-Hello` 替换为 `SimpleApp`（区分大小写）。
5. 保存，双击 `SimpleApp.xcodeproj` 打开。

## 十一、常见问题排查

| 问题现象                          | 可能原因及解决                                                                                               |
| :-------------------------------- | :----------------------------------------------------------------------------------------------------------- |
| 启动时弹窗"版本不一致"            | HBuilderX 版本与离线 SDK 不匹配，更换一致版本。                                                              |
| AppKey 错误提示                   | `dcloud_appkey` 未设置或与 Bundle ID、appid 不匹配，重新申请。                                               |
| 自定义基座运行时无法连接          | `control.xml` 未开启 `debug` 或 `syncDebug`；或 `iOS_debug.ipa` 未正确放置。                                 |
| URL Scheme 无法唤起               | 检查 scheme 是否小写、是否在 `Info.plist` 正确配置；测试时使用 Safari 或配置 `LSApplicationQueriesSchemes`。 |
| Xcode 编译报错（找不到头文件/库） | 执行 `pod install` 确保依赖完整；检查 `Pandora/api` 等路径引用。                                             |
| 隐私清单审核被拒                  | 确认已添加 `NSPrivacyAccessedAPITypes` 并填写合理的使用理由。                                                |
| 工程改名后 Xcode 崩溃             | 删除 `xcuserdata` 和 `project.xcworkspace` 缓存，重新打开工程。                                              |

## 十二、附录：关键文件路径与作用速查

| 文件/目录                         | 作用                                 |
| :-------------------------------- | :----------------------------------- |
| `HBuilder-Hello/control.xml`      | 调试开关、appid 配置                 |
| `HBuilder-Hello/Info.plist`       | AppKey、URL Schemes、隐私清单等      |
| `HBuilder-Hello/Podfile`          | 第三方库依赖（可改镜像源）           |
| `HBuilder-Hello.xcworkspace`      | Cocoapods 生成的工程入口（打开这个） |
| `.xcodeproj/xcuserdata/`          | 本地用户缓存（可删）                 |
| `.xcodeproj/project.xcworkspace/` | 本地状态缓存（可删）                 |

> **最终提醒**：制作正式发布包（App Store）前，务必：
>
> - 移除 `control.xml` 中的 `debug` 和 `syncDebug`。
> - 确认 `dcloud_appkey` 为生产环境 key。
> - 检查隐私清单完整，并通过 Xcode 的 Privacy Report 验证。
> - 使用 Release 配置打包 Archive。
