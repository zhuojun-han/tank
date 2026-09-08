# Flutter 第 38 版稳定滴定同步

日期：2026-09-07。负责范围：`app/` 与本文件。总调度：`01a07bcc-a662-73d1-8a0d-0e8c67f2e3f5`。

## 完成范围

- 设置页新增「稳定滴定」入口，路由 `/maintenance-dosing`。选择 PO₄ 或 KH 后只显示当前指标的简洁表单和一份 500 ml 配方，没有使用天数输入。
- 净水量默认 200 L，PO₄ 日上升默认 0.02 mg/L，KH 日下降默认 0.5 dKH。两指标独立保留流速、单位、运行时间及每日变化；流速默认 1.4 ml/s、时间可修改且默认 1 分钟，支持 ml/s、ml/min。隐藏指标的错误不阻断当前计算。
- 每日泵出恰为 84 ml（容差 1e-9）时，母液按 6 天需求计算，显示约 6 天并说明忽略末次约 4 ml 差额；其他设置以 `500 / 每日泵出量` 计算实际天数及所需母液。默认 PO₄ 母液 2.4 ml、KH 母液 360 ml，均加 RO/DI 水定容至 500 ml。
- 无需求显示无需添加；母液超出 500 ml 时显示容量错误且不给出可执行配方；拒绝非有限值、负数和零水量/流速/时间等输入。
- 原 KH 计划与新滴定页共用 `4/6/8/10` 母液档位，默认 6，保留现有 0–40°C 插值及 20% 溶解度余量检查。4 ml 档在 20°C 拒绝、30°C 合理纯度下可计算；旧 5 ml 档不再可选。
- KH 成功计算按海缸 ID 保存于当前 ProviderScope 的内存会话；滴定页带入同缸最近成功 KH 计算的水量、每日消耗、档位、纯度与最低温度。其他缸不带入；重启后恢复默认，不从历史任务推测配方，不改数据库或备份格式。
- 母液参数及说明默认折叠，保留独立容器/管路、不混合、复测停止条件、理论估算和不能替代专业诊断说明。模型依据为现有 `web-demo/app/maintenance-dosing.ts`、`maintenance-dosing-panel.tsx`、`alkalinity-calculator.ts` 及项目药剂规则文档，不新增准确性声明或硬件控制。

## 修改文件

- `app/lib/features/calculators/domain/maintenance_dosing.dart`（新增）：单指标纯计算与数值边界。
- `app/lib/features/calculators/domain/calculator_session.dart`（新增）：按缸隔离的 KH 会话参数。
- `app/lib/features/calculators/domain/alkalinity_calculator.dart`：共用档位常量及校验。
- `app/lib/features/calculators/presentation/maintenance_dosing_page.dart`（新增）：简洁表单、结果、折叠参数。
- `app/lib/features/calculators/presentation/alkalinity_calculator_page.dart`：档位选项及成功计算会话记录。
- `app/lib/features/settings/presentation/settings_page.dart`、`app/lib/app/router.dart`：设置入口和当前海缸/会话参数接入。
- `app/test/features/calculators/maintenance_dosing_test.dart`、`maintenance_dosing_page_test.dart`（新增）：5 项数值与页面回归。

## 验证

命令工作目录为已存在的英文联接 `D:\DevWorkspaces\lanjiao-app-workspace`，实际目标是项目 `app/`。仅格式化本任务修改的 Dart 文件，没有全目录格式化或清理。

- `flutter analyze`：通过，`No issues found! (ran in 8.6s)`；日志：`app/analyze-v38.log`。
- `flutter test --concurrency=1 --reporter=expanded`：174 项全部通过，37 秒；日志：`app/test-v38-sync.log`。新增覆盖默认 84 ml/天约定、其他时间与单位换算、零需求/容量/非法值、KH 各档位与温度/纯度、同缸会话参数带入、320 px 窄屏展开/错误状态、两指标输入保留与隐藏错误隔离。原计算器、备份、通知、任务、鱼缸等回归同时通过。
- 初轮计算器定向测试 14 项通过，日志：`app/test-v38-calculators.log`；最终新增会话/窄屏测试包含在上述 174 项中。
- `flutter build apk --debug`：成功，`assembleDebug` 31.5 秒；日志：`app/build-v38.log`。产物 `app/build/app/outputs/flutter-apk/app-debug.apk`，201,505,771 字节，SHA-256 `6203CDF8756DD6E7D2CDB3FB859A82D951F21853B65227AD1CCEC103612C36D0`。保留既有 Java native access、flutter_timezone Kotlin 迁移和 SDK XML 版本警告。

工具边界：首次受限执行时 Dart 无法创建用户目录的分析配置（拒绝访问），Flutter 包装脚本未推进；终止这些调用后通过自动审核允许现有 SDK/用户工具缓存访问，最终分析和测试正常完成。未改变全局设置。构建仅对本次进程设置英文 TEMP/TMP 与 `jdk.net.unixdomain.tmpdir`，沿用项目已验证过的本机 JBR 临时目录配置。

## 设备与交付边界

本任务未安装 APK、未操作模拟器或真机，没有浏览器验收、真实泵标定或实际投加验证，也未验证 Android 真机通知/相机、iOS 或正式签名 release。页面测试属于 Flutter 自动化布局/交互测试，不能替代真实设备验收。

未编辑网页版、鱼类素材或鱼缸逻辑；未推送、提交或发布。已重读项目规则并核对 README/PROJECT_CONTEXT/CURRENT_STATUS 中“Flutter 未同步”的旧表述，公共文档由总调度统一更新，本文件提供可引用的当前实现与证据。

## APP-ISSUE-001：2026-09-07 首页鱼位置重置修复

用户在本任务明确报告鱼反复来回跳动，并授权“需改这一问题”。本次单独修复 App 鱼缸，不包含 WEB-001 网页仅计算预览同步。以上“不修改鱼缸逻辑/未安装设备”描述属于此前第 38 版同步范围，本次设备结果如下。

原因：`HomePage` 订阅每秒更新的 `maintenanceClockProvider`，触发鱼缸更新；`_AnimatedFishLayer.didUpdateWidget` 原先无条件清空运动状态，使鱼每秒回到初始位置。

- 修改 `app/lib/features/aquarium/presentation/aquarium_card.dart`：逐项比较档案内容，未变化时保留位置、速度、方向和动画时间；即使传入新列表/新模型但内容相同，也不重置。真正增删鱼、切缸或修改档案仍执行原更新流程。未改变立绘素材、选鱼UI或游动算法。
- 新增 `app/test/features/aquarium/aquarium_card_test.dart` 两项回归：模拟连续三秒游动和每秒父级重建，断言刷新瞬间位置连续且随后继续游动；验证增鱼、清空、切缸后重新添加仍更新并恢复动画。
- 修复前该测试稳定捕获刷新时跳变 `21.64379661635922 px`（要求小于 0.01 px），日志 `app/test-fish-refresh-before.log`。修复后通过，证明测试能识别本次缺陷。
- `flutter analyze`：通过，11.7 秒，日志 `app/analyze-fish-refresh.log`。
- `flutter test --concurrency=1 --reporter=expanded`：176 项全部通过，48 秒，日志 `app/test-fish-refresh.log`。
- `flutter build apk --debug`：成功，assembleDebug 16.7 秒，日志 `app/build-fish-refresh.log`。APK 路径 `app/build/app/outputs/flutter-apk/app-debug.apk`，201,504,829 字节，SHA-256 `6C579A6E3BC338BDF41179DE48E76B2B75ACC6E011343905E9C77D406162706E`。
- `emulator-5554`：`adb install -r` 返回 Success，保留数据覆盖安装后启动 MainActivity，前台 `topResumedActivity` 为本 App，PID 7771；当前进程日志未命中 FATAL EXCEPTION、E/flutter、FlutterError、failed assertion 或 Unable to load asset，日志 `app/device-fish-refresh.log`。

设备验收仅覆盖安装、启动、前台及日志；没有录屏/逐帧观察模拟器跨秒动画，本次“不随首页刷新跳回”由上述实际渲染位置回归测试证明。真机与 iOS 未验收。公共文档与统一清单仍由总调度更新，本任务未发布或提交。
