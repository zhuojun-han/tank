# App 网页同款 UI 实施

2026-09-09 · 已完成本地实施、Android 构建及模拟器保留数据升级。

## 授权与范围

用户在审核 [UI 规划](app-ui-redesign-plan-2026-09-09.md) 后明确要求实施 App，与网页版基本一致，并加入鱼缸气泡。本轮修改 Flutter 展示与必要入口衔接，保留网页源码、用户存档、schema v12 和取色/配方算法。

- 全局主题、当前缸切换顶栏与设置底部面板；设置保持网页菜单顺序，保留 App 外观、备份及通知权限入口。
- 首页按网页顺序布局，使用两列彩色指标卡；鱼缸文字在图外，三个气泡与鱼共用受控动画。
- 检测直接选择指标进入现有流程；NO3/PO4 共用圆环计时、拍照与复核，KH 无计时。准备态调整计时时长通过仓库校验，不修改运行中或已结束的会话。
- 趋势保留五点横滑、范围端点、跨空插值连线和十条分页；任务保留完整月历、所选日操作与全局计划/所选日记录的区分。
- 提前延期的补液提醒立即进入全局待处理；有限计划的剩余日期摘要只取未完成部分，详情保留处理历史。没有改变原补液日、剂量、周期数量或数据排期。
- 修复卡片背景遮挡点击效果、窄屏大字体按钮挤压，以及切走检测页后迟到的相机/手动表单跳转。

## 实际验证

最终 `flutter test --concurrency=1 --timeout=60s` **312 项全部通过**；日志 `app/build/ui-full-accepted-2026-09-09.log`。覆盖海缸隔离、准备态时长与计时恢复、迟到导航、手动草稿恢复/取消、目标与设置入口、范围图/分页、补液提醒、真实完成日期、备份和迁移。早期失败已修复，旧失败日志保留用于排查。

`dart format --output=none --set-exit-if-changed lib test tool` 与 `dart analyze` 已通过；App 源码无 schema、算法或依赖升级。使用 Flutter 3.44.7 / Dart 3.12.2，从已核对指向本 `app/` 的 ASCII 联接运行；Windows 构建临时目录沿用 [App README](../../app/README.md) 的进程级配置。

`flutter build apk --debug` 成功，Gradle 构建 10.7 秒；原有 JBR native-access 与 flutter_timezone Kotlin 迁移警告仍在，未改 SDK、模拟器图形配置或依赖。安装包为 `app/build/app/outputs/flutter-apk/app-debug.apk`，SHA-256：`5820cbac54ccd4ccfbc81a8c9925c974204965a983f2e458a93724171c5f2d23`。

在现有 `emulator-5554`（1080×2400、420 dpi）执行 `adb install -r` 成功；前台已确认 `com.lanjiao.lanjiao_water_quality/.MainActivity`。实际查看首页鱼缸/气泡、检测圆环、趋势空态、任务月历/列表及设置面板，截图在本地忽略目录 `artifacts/app-ui-device-2026-09-09/` 的 `home.png`、`detection.png`、`trends.png`、`tasks.png`、`task-list.png`、`settings.png`。截图日期按模拟器自己的系统日期显示，未修改设备时间。

升级前后逐表比较列、行数与行内容 SHA-256：schema 均为 v12，**无变化表**；3 个海缸、1 条检测记录、5 个维护任务、7 个任务事件和 1 个准备态检测草稿均保留。当前 App 进程 PID 10170 的日志未发现 Flutter 异常、丢失素材、布局溢出或原生致命错误；`result.json` 保存比较结果。验收未创建或完成用户任务，结束后 App 已退到安卓桌面并停止，现有图形模拟器保持打开。

根目录 `node tools/check-project.mjs` 检查 80 篇文档通过；`git diff --check` 通过。本轮为本地交付，未以之前云端 CI 或公开 Web 发布证明当前修改树。

## 未测边界

Android 模拟器不能证明真机相机、厂商后台提醒或实际功耗；iOS 仍需 macOS/Xcode 和设备验收。本轮 UI 验收不等于已实施独立的建议算法草案或验证照片准确率。
