# Android 模拟器 CPU 与仓库整理

日期：2026-09-08。范围：用户反馈的 Windows 模拟器 CPU、已授权 App 后台修复、维护文档精简，以及上传到指定的 [GitHub 仓库](https://github.com/zhuojun-han/tank)。WEB-005 补液周期仍只在网页，不借本轮修复同步 App。

## CPU 结论与实测

主要高占用来自无窗口模拟器仍在前台绘制首页鱼动画，并使用 SwiftShader 软件渲染。Windows 窗口隐藏不等于 Android App 已进入后台。原 AVD 为 `hw.gpu.enabled=no`；虚拟机 CPU 加速 WHPX 已可用，问题不是未开启 CPU 虚拟化。

同一台 16 逻辑处理器 Windows 主机，API 36 x86_64、4 个虚拟核心、2 GB RAM、1080×2400、60 Hz，运行相同 Debug APK 和首页数据。每段约 12 秒；宿主按进程 CPU 时间增量除以实际时长及 16 核计算，Android App 按 `/proc/<pid>/stat` 的 CPU ticks 增量计算，后者以单核为 100%，两列不能直接相比。

| 渲染与场景 | 宿主 PID / App PID | 模拟器 CPU（整机口径） | App CPU（单核口径） |
| --- | --- | --- | --- |
| SwiftShader，首页前台 | 24968 / 4275 | 66.288% | 105.659% |
| SwiftShader，退到 Android 桌面 | 24968 / 4275 | 0.964% | 0.000% |
| NVIDIA 硬件渲染，首页前台 | 33048 / 2998 | 15.544% | 108.606% |
| NVIDIA 硬件渲染，退到 Android 桌面 | 33048 / 2998 | 2.333% | 0.000% |

对照使用修改计时源码前的同一个 APK（SHA256 `91554578f99358778bc6787168bef11e591b4e76597a841791a93d3820b400bb`），避免把图形设置改善归因于计时修复。实际 GLES 从 Google SwiftShader 变为 NVIDIA GeForce RTX 5060 Laptop GPU；已查看截图，首页渲染正常。`host` 与软件渲染的配置含义见 [Android 官方说明](https://developer.android.com/studio/run/emulator-acceleration)。

本机处理：备份 AVD 配置，正常关闭后以 `-gpu host -no-window -no-boot-anim -no-snapshot-load` 启动；验证实际渲染器后，只把本机 AVD 的 `hw.gpu.enabled` 和 `hw.gpu.mode` 改为 `yes` / `host`。没有清空模拟器数据。这是本机已验证设置，不要求其他机器固定使用该 GPU 模式。完成设备检查后已将 App 退回 Android 桌面。

这些短采样定位了本次问题；前台 Debug App 仍有约一个核心的运行开销，尚无 profile/release 真机帧率、长期功耗或 iOS 性能结论。

## 独立修复的计时问题

倒计时原来在页面仍挂载时每秒回调；Android 暂停帧更新后，页面可能一直持有旧的运行中草稿，在截止后重复完成、写数据库并取消通知。这与本次首页软件渲染高 CPU 是两个问题。

- UI 计时器只在 App 前台且检测运行中刷新；后台、销毁时停止，系统截止提醒继续保留，恢复时按持久化 UTC 截止时间结算。
- 同一草稿/截止时间避免重复尝试；数据库按海缸、草稿、阶段和截止时间条件更新，旧快照与并发回调不能覆盖重启计时或复核草稿。
- 回归使用 SQLite trigger 记录实际 UPDATE 次数：后台过期无写入，恢复只完成一次；覆盖重复恢复、旧快照、并发、初始暂停和页面销毁。
- schema、备份格式和生成文件未变；没有新增 App 产品功能。

## 仓库与文档

App、Web、文档、样本与工具统一由根 Git 管理。原 Web 的 38 次提交及元数据完整移至本机 `.git/legacy-web-repository`，没有删除；它们不属于此次根仓上传的提交历史。

根 `.github/workflows/` 分别运行两端检查，Web 工作目录、缓存和产物路径已按单仓调整。两端测试直接读取根 `contracts/maintenance-dosing.json`，删除重复副本；忽略本机数据库、日志、构建包、缓存和密钥文件。归档使用 `.gitattributes` 保留原始字节，20 份归档哈希核对一致。

README 只负责导航，AGENTS 只留协作要求；同步授权在 PROJECT_CONTEXT、结构在 TECHNICAL_DESIGN、验证选择和性能测量在 DEVELOPMENT_PLAN、命令用法在各端 README。删除循环阅读要求、重复授权描述及陈旧命令说明；历史报告不改写成当前完成事实。

## 验证与上传状态

| 范围 | 本轮结果 |
| --- | --- |
| Flutter | 205 项全量测试通过，Dart 分析 0 问题，改动文件格式检查通过，Debug APK 构建成功 |
| Android 覆盖安装 | `adb install -r` 成功，前台 Activity 核对及首页截图正常；11 张表逐行一致，当前进程所查日志无未处理异常 |
| Web 单仓调整 | 96 项单元测试通过，其中根滴定合同 10 项；本轮未改变 Web 产品源码，未重复上批完整浏览器流程 |
| 根工程 | 5 项工具测试、入口/文档/样本/合同检查通过；两份 CI YAML 解析和路径检查通过 |
| 上传准备 | 已建立指定 origin，实际暂存内容未发现 gitlink、超过 50 MiB 的文件、受检凭据模式或被排除的本机产物；最终提交后核对远程 SHA |

上传状态：已完成本地准备，尚待本轮首次提交与推送；远程 CI 尚无执行结果。上传源码不等于部署网站或发布 App。

新 APK：201,571,385 字节，SHA256 `29fc173e7c789e8950a46162283afa2e65d530ee723df1a1ac9f65a4264e0430`。覆盖安装后再采样 12.048 秒，宿主 PID 33048 为 0.932%，App PID 4009 为 0.000%，前台为 Android 桌面。本地实证位于忽略目录 `artifacts/android-cpu-2026-09-08/`（采样、AVD 配置备份、截图、数据库对照与日志）以及 `app/build/background-timer-*-2026-09-08.log`，不随源码上传。暂存检查记录为 `artifacts/github-publish-staging-review.json`。

仍未验证真实手机相机、系统后台限制、通知送达、长期功耗和 iOS；剩余依赖链及其他产品开放项见 [当前状态](../CURRENT_STATUS.md)，本轮未据此宣称全面安全或两端完全同步。
