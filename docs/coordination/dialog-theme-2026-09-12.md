# WebView 原生弹窗主题 · 2026-09-12

新版 WebView 使用独立的 Material 浅色上下文，统一选择框、日期和时间弹窗：青绿色选中态、浅绿背景、圆角及细边框。保留系统选择/取消及键盘输入能力，旧 Flutter 入口不变。

Android debug 构建成功，已保留数据安装到 emulator-5554。实际点选单位、日期取消、时间确认通过；没有错误触发后台/恢复事件，海缸、记录、目标、任务、配液周期和鱼类数据与操作前一致。本次为样式修改，未运行全量业务回归。

- APK：`artifacts/dialog-theme-2026-09-12/lanjiao-webview.apk`
- SHA256：`CEE12F7D335E02D1DCA2B7F699F01C0355876B719AD9DC248AB18824DEFA8B7A`
- 截图、操作结果：同目录 `select.png`、`date.png`、`time.png`、`result.json`。

当前模拟器为英文系统，因此原生日期和按钮显示英文；语言与时间制式遵循系统。普通手机和 Mate X6 真机显示仍待验收。
