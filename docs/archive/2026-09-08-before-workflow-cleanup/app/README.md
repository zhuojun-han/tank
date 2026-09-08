> 历史归档：2026-09-08 工作流整理前的原文。保留当时结论与命令，不作为当前执行规范；相对链接已转向原目标。[当前文档](../../../../app/README.md)。

# 澜礁海缸水质助手 Flutter App

正式 Android/iOS 客户端工程。当前工作树包含本地海缸与参数、首页动画鱼缸与鱼类档案、检测记录、首页与趋势、可追溯建议、维护任务与通知、实验性 NO3 临时拍照辅助流程、离线估算规则骨架和不含检测照片的完整业务数据备份恢复。

2026-09-05 已同步网页版第 36 版的 KH 计划、PO4 可选母液体积、同类计划日期范围覆盖、按开始日重复的任务、逐日完成/恢复/稍后、计划合并详情、停止隐藏与本日筛选。v9 保留旧 v1–v8 App 备份兼容；鱼类素材与业务能力保持。差异和验证见 `../docs/FLUTTER_WEB_V36_SYNC.md` 与当前状态文档。

旧任务保留原有推进方式，编辑后转为日期规则。新日期规则系统通知只预排近两次实际发生日，打开、恢复 App 或修改任务时补排，尚无无限后台补排。相机、真机通知、真实样本及 iOS 验收仍待完成。

本轮全量测试：169 项全部通过；Flutter 分析 0 问题，Android debug APK 构建成功；产物与验收边界见 [当前状态](../../../CURRENT_STATUS.md)。

## 已验证环境

- Flutter 3.44.7
- Dart 3.12.2
- Android SDK 36 / build-tools 36.0.0
- Gradle 9.1.0
- OpenJDK 25.0.2（Android Studio 自带 JBR）

## 验证命令

在本目录执行：

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --concurrency=1
flutter build apk --debug
```

2026-08-10 的旧基线曾通过 17 项测试和 Android 模拟器启动；该记录只作为历史基线。

2026-09-01 上一已验证基线：`dart analyze` 输出 `No issues found!`，`flutter test --concurrency=1 --reporter=compact` 的 154 项测试全部通过；Android debug APK 构建成功。该基线 debug APK 为 201,443,688 字节，SHA-256 为 `5C213AA6844066CCC0E24864A5953608057AFC64B9E9635EBB239438FF7C894F`。APK 已覆盖安装到 `Lanjiao_API_36`，首页确认自然珊瑚礁背景和 A1 小丑鱼实际渲染，前台 Activity 正常且近期日志未匹配致命异常。该历史 APK 不包含 2026-09-04 新增的 8 个鱼种；当前构建结果见项目状态文档。相机、真机通知栏/后台、自定义图片选择器真机交互、不同设备视觉比例和低存储仍未验收。

检测照片只在当次比色时写入应用缓存，并在确认或取消后删除；正式记录与 v9 备份不保存检测照片。Drift schema v9 在 v8 基础上新增可空周期规则与逐日状态，保留 v8 的按海缸隔离鱼类档案；压缩后的用户自定义鱼立绘随结构化备份导出/恢复。完整数据备份覆盖 11 张业务表，包含海缸、参数启停、目标、主题、提醒开关、鱼类档案、试剂/计时、当前海缸、检测记录（趋势来源）、每日任务与历史及未完成草稿；恢复前完整校验并二次确认。

CameraX 构建问题通过将 `camera_android_camerax` 从 `0.7.4+4` 定向升级到包含官方 `androidx.concurrent:concurrent-futures:1.2.0` 修复的 `0.7.4+6` 解决，未加入项目级 Gradle 绕过。完整结果与下一步见 [`../docs/CURRENT_STATUS.md`](../../../CURRENT_STATUS.md)。

Windows 中文路径存在工具兼容风险时，可从 `D:\DevWorkspaces\lanjiao-app-workspace` 运行命令；该目录联接不会复制或改变源码。若 JBR 25 报 `Unable to establish loopback connection`，可为当次 PowerShell 进程把 `TEMP` 和 `TMP` 指向短的本地路径（本轮使用 `D:\jtmp`）后重试；不需要写入用户级环境变量。当前构建仍会出现 Java native access 和 `flutter_timezone` 未来 Kotlin 迁移提醒，但未阻断 debug 构建。

iOS 构建与启动仍待 macOS/Xcode 环境确认；Android 真机相机/通知/低存储与正式签名 release 也尚未验收。
