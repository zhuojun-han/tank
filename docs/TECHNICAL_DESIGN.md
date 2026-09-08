# 技术与数据合同

本文件维护两端架构边界、数据与时间语义。实现事实以源码与锁文件为准，当前测试和平台状态只在 [CURRENT_STATUS](CURRENT_STATUS.md) 维护；产品行为见 [MVP_SPEC](MVP_SPEC.md)。

## 分层与仓库

Flutter 使用页面/状态 → 业务服务与仓库 → Drift/SQLite、私有文件、平台能力的分层。页面不直接拼接 SQL、调度平台通知或管理检测照片文件。网页通过 React 页面调用纯计算/日期/颜色模块，使用 localStorage 保存本地状态；不依赖云数据库、账户或视觉大模型。

项目使用一个根 Git 仓库，统一管理 `app/`、`web-demo/`、`docs/`、`datasets/`、`resource/`、`contracts/` 和 `tools/`；`web-demo/` 是普通子目录。工作区由根 [project-workspace.json](../project-workspace.json) 定义，CI 统一从根 `.github/workflows/` 执行，App/Web 检查分别在对应目录运行。跨端改动分别记录验证；只有远程工作流实际执行后才报告 CI 结果，推送代码不等于发布网站或 App。

[工作区检查](../.github/workflows/workspace.yml) 对 push/PR 执行轻量结构、文档、样本、合同及工具测试；[App](../.github/workflows/flutter.yml) 和 [Web](../.github/workflows/web.yml) 按影响各端的源码、数据、合同与构建配置触发完整检查。纯文档变更只运行轻量流程，不重复编译两端；手动触发仍可执行完整检查。

原 Web 独立仓库的 38 次提交仅保存在本机根 `.git/legacy-web-repository/`；这份 Git 元数据不随当前根仓库推送，新克隆不会自带该历史。

## 时间与隔离

- `capturedAt`、`confirmedAt`、`dueAt`、事件时间、snooze 截止等时间点以 UTC 保存，显示时使用设备当前时区。
- 检测倒计时仅在前台运行时刷新 UI；后台保留 UTC 截止时刻及已安排的系统提醒，恢复后按截止重算，已到期仅完成一次。旧会话快照不得覆盖重启后的计时或正在复核的草稿。
- 任务开始日、发生日、实际完成日、延迟目标日、停止边界及配液/补液日是本地日历日期 `YYYY-MM-DD`，不是待偏移的 UTC 时间点。提醒时刻由本地日期和时分组合，再转 UTC；跨时区需重新安排平台提醒。
- 数据操作以 `tankId`、参数/任务 ID 等作用域重新校验；异步页面打开后的保存仍需检查目标归属和输入，避免串缸。
- 两端排期遵循 [最新产品合同](MVP_SPEC.md#网页完成驱动排期)，App 通过独立的滚动排期字段兼容旧规则；旧日期规则和历史按兼容读取，不给新任务生成过去的假完成。日历按窗口展开，不预生成无限实体。

## App 持久化与兼容

当前 Drift schema 和 JSON 备份格式均为 **v11**。版本定义分别在 [app_database.dart](../app/lib/data/database/app_database.dart) 与 [local_backup_service.dart](../app/lib/data/backup/local_backup_service.dart)；历史格式和列为兼容保留，不能按“无新写入”判断可直接删除。

| 实体/字段 | 当前合同 |
| --- | --- |
| Tanks / WaterParameters / TankParameters | 默认海缸、内置/自定义参数、按缸启停；停用不删除记录 |
| WaterQualityTargets | 同缸同参数唯一；上下限可各自为空，存在时非负且下限不大于上限；停用保留、清空保留空行 |
| ReagentProfiles | 试剂、单位、档位、计时与版本资料；缺资料不自动推断已验证 |
| TestRecords | 确认上下限与可空 confirmedInterpolation；原始 estimatedMinValue/estimatedMaxValue/estimatedInterpolation、算法方法/版本、质量/失败原因与人工结果分离 |
| ActiveTestSessions | 检测阶段、计时、确认/原始范围及插值草稿，放弃不形成正式记录 |
| MaintenanceTasks / TaskEvents | 一次性/有限计划；rollingJson 保存排期基准、版本与实际完成历史，recurrenceJson 与旧事件继续兼容 |
| AppPreferences / TestTimerDefaults | 当前缸、主题、提醒开关、鱼类档案与压缩自定义立绘、每缸每参数计时默认 |
| MaintenanceCycles | 每缸每药当前周期及旧配方链；本地开始/补液/关闭/延期日期、总体积/日泵量/当量、残液和新母液/水量 |

v11 新增周期表、任务 `rollingJson`、记录 `khTitrationJson`，目标上下限改为可空；升级保留旧值。`khTargetDefaultsApplied` 只给首次读取时已启用且无范围的 KH 补 7–9，之后用户清空不反复补回；旧备份恢复也执行一次初始化，不启用原本未启用的指标。KH 原始输入/查表结果存于元数据，人工确认可改值；App 单值按原约定仅保存 confirmedMinValue、confirmedMaxValue 为空，与网页上下限相等语义一致。

v10 增加确认/原始插值和对应草稿字段，并为已有 PO4 参数启用拍照入口；旧范围不补虚构插值。v9 周期字段、v8 鱼类档案继续兼容。旧 `measuredAt`、照片列等仍可能被迁移/旧备份使用；新检测的正式照片引用保持空。

修改人工值和备注不覆盖算法原始估值、拍摄时间或算法版本。单值、范围和范围内可空插值分别校验；展示取整不改变原始小数和记录值。

## 备份与文件

- JSON v11 及 ZIP 完整备份包含 12 张业务表的可迁移内容，支持读取 v1–v10；当前照片/草稿照片引用和设备派生通知 ID 在备份读取/写出时剥离。用户鱼类立绘是结构化业务配置，与检测照片不同。
- ZIP 新输出仅含 `database.json` 与 `manifest.json`，校验版本、字段、关联、路径、CRC、SHA-256 和容量限制；旧含照片 ZIP 仍校验完整性但不复制照片。
- 设置页恢复为权威快照：完整校验和影响确认后，在同一 SQLite 事务替换业务数据；失败需回滚，不以逐条部分成功替代。平台通知权限不迁移，提交后按本机权限重排。
- CSV 便于查看检测记录，含范围/插值，不是恢复格式；防止公式注入。备份层细节见 [README](../app/lib/data/backup/README.md)。
- 检测照片仅在当次拍照处理中使用私有缓存；确认、取消、重拍或手动降级后清理。正式记录和新备份不包含照片；不在升级时静默删除旧用户留档。

每次 schema 改动升级版本并提供迁移验证；不要修改生成代码代替源定义和生成步骤。空间不足、失败清理、恢复异常须优先保护已确认数据。

## 网页数据

当前浏览器业务状态保存在 `reef-demo-state-v10`。保留旧状态兼容；新增字段提供安全默认值，不把演示记录自动当用户实测。`maintenanceCycles` 保存配方快照和残液当量，日历发生项即时生成，普通 tasks 不被物化为每日自动完成事件。补液数据合同见 [滴定规范](MAINTENANCE_DOSING_CALCULATOR.md)；App 对应独立 MaintenanceCycles 表。

`Tank.startedOn` 为可选本地日历日期 `YYYY-MM-DD`，仅由用户设置；旧档缺失或空字符串均按未设置处理，不迁移推断日期。编辑保留海缸 ID 和其他业务数据，提交拒绝非法及未来日期。存档中的合法未来日期可能来自设备日期回拨，允许读取但不显示负天数；非法类型或日期仍阻断恢复。运行天数按日历日序差计算以避开夏令时，复用本地日期刷新；表单提交时重新读取当天日期。产品显示与 App 范围见 [产品规格](MVP_SPEC.md#首页检测趋势与设置)。

加载只读取首个现存版本；新存档损坏时仍阻断恢复，不回退覆盖。长历史图表保留全部记录和滚动范围，仅挂载可见区域附近的标记，范围缺插值时仍跨越连接前后有效点。计划按单遍分组选头，动画只展开可显示的鱼只。遗留时间戳提醒按真实时刻比较，长于浏览器单次定时上限时分段等待，未到期不重复写存档；图片和备份资源边界分别见 [拍照规范](IMAGE_ESTIMATION.md#图片资源边界) 与 [App 备份层](../app/lib/data/backup/README.md)。

网页任务的可选 `rolling` 保存 `version: 1`、`nextDate`、`revision` 与 `completed: [{ dueDate, completedDate }]`，分别记录待办排期基准、修改版本和实际完成历史；日期修改须重新核对版本及任务归属。可选 `legacySchedule` 保存旧 `scheduledDate`、可选 `intervalDays` 与 `defaultCompletedBeforeDate`，只兼容旧默认历史，编辑时保留，不给新任务补造完成记录。`projection: { date, today }` 仅为当前日期下的渲染投影，不写入存档；自动顺延不反复改写历史。行为与平台范围见 [产品合同](MVP_SPEC.md#网页完成驱动排期)。

KH 目标默认值使用一次初始化标记 `khTargetDefaultsApplied: true`，沿用现有存储键。读取旧存档时，仅给已有且上下限均为 `null` 的 KH 目标补 `7–9 dKH`，不新增目标行或启用未启用的 KH；既有自定义值和单边目标保持原样。初始化成功后随状态保存标记，用户随后清空目标再加载时保持为空，不重复填回。新建 KH 目标或用户主动启用 KH 时使用默认范围。

KH 滴定确认值按 `low = high = Number(displayDkh)` 保存一位小数的单值。可选 `khTitration` 保留 `initialMl`、`remainingMl`、`usedMl`、`tableReadingMl`、未按展示精度取整的 `dkh`，以及 `displayDkh`、`interpolated`、`tableId`；人工编辑确认值时保留这份原始计算信息。无此字段的旧记录继续兼容，沿用现有存储键。

网页 localStorage 与 App JSON/ZIP 不是兼容格式；同步功能不得顺带导入演示历史。网页只在打开时提醒，系统通知由 Flutter 独立实现和验证。

## 计算与算法

两端计划的目标预填遵循 [产品规则](MVP_SPEC.md#计算与通知)。完整有效范围指两端均为非负有限数且下限不大于上限；中点保留输入精度，KH 目标输入使用 `step="any"`，例如 `7.8–7.81` 预填 `7.805`，不能套用 KH 检测结果的一位小数展示规则。预填不放宽计算器及保存时的既有校验。

公式、单位、数值限制由 [PO4](LANTHANUM_CHLORIDE_CALCULATOR.md)、[KH](SODIUM_BICARBONATE_KH_CALCULATOR.md)、[海盐](SALINITY_CALCULATOR.md)、[稳定滴定](MAINTENANCE_DOSING_CALCULATOR.md) 维护。颜色比较合同在 [拍照规范](IMAGE_ESTIMATION.md)。两端使用共同的参考数据验证行为一致，不由此推定真实化学效果或浓度准确率。稳定滴定的同输入/输出样例只维护根 [contracts/maintenance-dosing.json](../contracts/maintenance-dosing.json)，App 与 Web 测试直接读取此文件。变更合同须审阅期望值并运行两端相关测试，不从某端实现临时生成期望而跳过审阅。

两端 KH 检测使用 [contracts/kh-titration.json](../contracts/kh-titration.json)，数据来自用户的 [KH 数值表](../resource/KH/数值表.jpg)。按用户指定公式以 `1 − (初始针筒容积 − 剩余溶液)`（mL）作为查表读数，档点间线性插值；初始值须大于 0 且不超过 1 mL，剩余量须在 0 至初始值内，输入须为有限数。原表仅覆盖 0.00–0.98 mL，末档 0.98 mL 对应 0 dKH；超出表域拒绝计算，不补 1.00 mL 档、不外推。结果显示一位小数，原始计算与确认记录按上述网页数据合同分开保存；本项同步验收见 [WEB-006](coordination/app-sync-backlog.md#web-006-验收范围)。
