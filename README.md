# PointLocation · 定点

原生 iPhone 选点定位工具，基于 [Waypoint](https://github.com/raph559/WaypointApp) 修改。

支持地图选点、拖动标记、地点搜索、启动/停止位置模拟。主要界面为中文，使用 SwiftUI 和 MapKit。此版本不含路线功能。

## 从 GitHub Actions 获取安装包

推送到 `main` 后自动构建，也可在 **Actions → Build Pinpoint unsigned IPA → Run workflow** 手动构建。
构建成功后，在该次运行页面底部下载 **Pinpoint-unsigned**，解压得到 `Pinpoint-unsigned.ipa`。

**IPA 未签名，必须用自己的签名方式签名后安装。** 不要把 Apple 账号密码、证书、设备配对文件上传到此仓库。

## 手机使用

首次配置需要开启开发者模式、安装 LocalDevVPN，并导入这台 iPhone 的配对文件。日常操作在手机上完成；签名和配对失效时仍需维护。

选点并启动后，可到微信的“发送位置”页面检查实际读取结果。此项目不能保证微信接受模拟位置；后台运行、网络切换和具体 iOS 小版本需要真机验证。

详见 [开始使用](开始使用.txt)。工程目标 iOS 17.4+，推荐按上游 iOS 26 流程验证。

## 本地构建

macOS 安装 Xcode 26+ 和 XcodeGen 后运行：

```sh
bash scripts/build-pinpoint.sh
```

输出：`build/Pinpoint-unsigned.ipa`。工程由 `project.yml` 生成。

## 来源与许可

上游提交：`be9a48a88882d934d6a0e2f3e3d97d97396600d9`。
保留上游底层连接实现与图标。本修改版包含中文主要界面、控制卡片、帮助页、独立包名及构建流程。

按 [AGPL-3.0](LICENSE) 分发；依赖说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
