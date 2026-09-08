# App / 本地网页 / 公开 v38 功能对照

检查日期：2026-09-07。结论：**当前不能称为完全同步。** 核心模块大量重合，但有计算入口/目标约束、记录与趋势、目标持久化、管理能力和平台功能差异。不能将所有差异归结为 WEB-001，也不能把 App 描述为完全无法只计算。

## 当前证据与范围

- 本轮重新读取当前两端产品源码、配置和操作入口，未使用旧验收报告替代当前事实。未修改产品源码、App 文件或发布；仅新增本报告。
- 当前网页仓库 HEAD 为 `31065fc2f66e9069155ae22e29786870bd37df66`；工作树 page.tsx 包含未发布的 WEB-001。当前修改列表为 README、page.tsx、rendered-html 文字断言，以及既有/新增验证文件。
- 现场使用独立 Edge 浏览器只读打开本地 `http://localhost:3000` 与[公开站点](https://lanjiao-reef-demo.zhuojun-han.chatgpt.site)，均 HTTP 200。公开站点实际加载 `/assets/page-Bl98obBU.js`，与第 38 版基线对应；没有将本地预览当作已发布功能。
- App 对照的是当前 `app/lib` 源码。设备与 APK 实际运行版本、模拟器交互由 App 任务独占核验，本报告不重复设备操作，也不重跑刚通过的网页全量测试。
- 下文“重合”指已检查源码具备相同主要功能，不表示每个极端输入、每条分支、每个操作顺序已经做完跨端等价测试。

## 主要功能对照表

| 模块 | 本地网页 | 公开 v38 | 当前 App 源码 | 分类与结论 |
| --- | --- | --- | --- | --- |
| 主导航 | 首页、检测、趋势、任务；设置弹窗 | 同左 | 首页、检测记录、趋势、维护四分支；独立设置/计算/检测路由 | 主要页面重合，路由/弹窗属于呈现差异 |
| 多海缸 | 新建、切换，记录/任务/鱼/参数按缸归属 | 同左 | 新建、切换、编辑名称/备注、归档 | App 具备额外管理行为；网页的体积展示也不等于 App 备注字段 |
| 内置/自定义指标与目标 | 六项内置指标、自定义、启停、目标 | 同左 | 六项内置、自定义、启停、目标 | 基本能力重合，但停用后的目标保留不同，见 D3 |
| 检测记录 | 输入上下限、人工编辑参数/海缸/日期文字/备注，持久化简化记录 | 同左 | 手动新增/编辑/删除，结构化检测时间、原估值/确认值/来源分离；旧照片可单独删除 | 真实数据模型与操作能力不同，见 D4 |
| 拍照/计时 | NO3 与 PO4 均可进入示例照片演示；使用固定示例图，不连接相机 | 同左 | 仅 NO3 支持真实相机后的实验性人工比色流程；PO4 不启动估值；计时与未完成草稿持久化 | 平台及能力边界，不能称拍照已完全同步 |
| 记录趋势/首页摘要 | 按数组顺序取最近六条；首页仍标“近30天”；新记录日期为“刚刚” | 同左 | 首页实际按近30天过滤，趋势按 measuredAt 排序并保留区间上下界 | 实际数据范围差异，网页存在标注与筛选不符，见 D2 |
| 日常建议 | 按当前缸最近记录及目标生成 NO3/PO4 高低/范围建议，显示来源 | 同左 | 对应规则领域模型与来源，按检测时间选择最近值；其他指标不提供专用规则 | 主要建议能力重合，最近记录的选取仍受 D4 影响；未逐字判定文案等价 |
| PO4/KH 理论数学 | 七水氯化镧 99.9%、每 ml 10 mg PO4；NaHCO3 当量、每日消耗、4/6/8/10 档、溶解度 | 同左 | 对应常量/公式与档位存在 | 主要计算规则重合；页面默认与用户目标约束有差异，见 D5/D6 |
| 计算与任务写入 | 无冲突计算成功自动写任务；有冲突提供预览/覆盖/取消 | 无冲突自动写入；有冲突仅覆盖/取消 | 先计算并显示配方及完整每日安排，再点“加入每日任务”并确认；冲突框无三选项 | WEB-001 是流程/文案差异；App 已具备只算不保存能力，见 D1 |
| 稳定滴定 | PO4/KH 单选、500 ml、默认1.4 ml/s ×1 min，默认84 ml/天约6天、改时长/单位，隐藏输入隔离 | 同左 | 对应模块已存在；净水量同缸共享、每日变化和泵参数独立；4 ml温度限制 | 核心已对齐。下拉选择/分段按钮是样式差异；KH历史带入方式见 D6 |
| 海盐计算 | SG0作无盐水、目标1.025、38.2 g/L@1.0255示例、90%首次加入 | 同左 | 对应默认常量与结果模型 | 核心规则重合，不是通用海盐品牌常量 |
| 任务月历/分组 | 六周展开、开始日周期、逐日完成/跳过/恢复、稍后1小时、停止隐藏、化学计划合并、每日详情、今日完成筛选 | 同左 | 对应 recurrence、calendar、chemical plan card 和 repository 实现 | 主要能力重合；App 还存在旧周期兼容与更多管理操作，见 D7 |
| 鱼目录/管理 | 九项内置目录、自定义立绘、数量/日期、按缸保存；24条动画上限 | 同左 | 相同九项名称目录、按缸鱼档案、上传与管理，24条动画上限 | 功能重合；WebP/PNG、压缩档位和存储封装差异不是缺少鱼种 |
| 鱼运动 | 四边约4px安全边距、低频随机转向 | 同左 | 对应运动模型；aquarium_card当前包含更新时保留运动层的实现 | 不据源码声称逐帧表现完全等价；设备动画验证归 App 任务 |
| 提醒 | 默认关闭的网页内到期弹窗；页面打开才运行 | 同左 | 本地系统通知、权限状态、启停、稍后与补排；新日期周期预排近两次 | 平台能力差异，应保留，不要求照搬成同一实现 |
| 数据/设置 | localStorage v10，恢复演示数据；没有 App JSON/ZIP 备份或 CSV 入口 | 同左 | SQLite/Drift schema9、完整业务备份导入导出、CSV、深色模式、隐私限制页 | App 多出的真实功能，存储格式不互通，不是自动双端同步 |

## 需明确告知用户的实际差异

### D1：WEB-001 不是 App 无法只计算

App 的 `_calculate()` 仅生成 `_plan`；两药结果均直接遍历 `dailyPlan` 显示每一天。用户不点保存即可只看结果；点保存后确认框取消也不写任务。`confirmChemicalPlan()` 是显式保存阶段的二选项，返回 nullable bool 区分取消/新建/覆盖。

本地网页新增的是“重复计划确认框内直接选择仅计算”的三选项，以及清晰的未加入日历预览标识。公开 v38 尚无此选项。无冲突时网页直接写入，App 仍需单独确认，因此两端总体流程本来就不完全相同。

依据：[网页 page.tsx](../../web-demo/app/page.tsx) `submitLanthanumCalculation`、`submitAlkalinityCalculation`、`previewChemicalReplacement`（约 550/606/664 行）；[App PO4 页](../../app/lib/features/calculators/presentation/lanthanum_calculator_page.dart) 187 `_calculate` / 210 `_savePlan`；[App KH 页](../../app/lib/features/calculators/presentation/alkalinity_calculator_page.dart) 97–124 结果、135 `_calculate` / 168 `_save`；[确认框](../../app/lib/features/calculators/presentation/plan_confirmation.dart) 4–38。

### D2：网页“近30天”没有实际日期过滤

`tankRecords` 在 page.tsx:328 仅过滤 tankId；331 的趋势和 801 的首页摘要再按指标 `.reverse().slice(-6)`，没有按记录时间裁剪。由此，“近30天”可能显示更早记录，并限制为六条。App home_page.dart:103–106 则真实计算 `now - 30 days`；趋势领域模型按 measuredAt 排序，趋势详情没有网页的六条截断。这是源码已确认的行为差异，不是仅图表样式不同。

依据：[网页](../../web-demo/app/page.tsx)、[App 首页](../../app/lib/features/home/presentation/home_page.dart)、[App 趋势模型](../../app/lib/features/trends/domain/trend_series.dart) 50 `buildTrendSeries`、[趋势页](../../app/lib/features/trends/presentation/trends_page.dart) 66 起订阅检测记录。

### D3：停用再启用指标，目标是否保留不同

网页 page.tsx:767 `toggleParameter` 将启停状态直接寄存在 targets 数组：停用删除条目，重启新增 min/max=null。App `setParameterEnabled` 只更新 tankParameters.isEnabled，不删除 waterQualityTargets；既有目标保留。两端都要求至少一个启用指标，但持久化语义不同。

依据：[网页](../../web-demo/app/page.tsx) 767–774；[App tank_repository.dart](../../app/lib/features/tanks/data/tank_repository.dart) 307–336；[数据库表](../../app/lib/data/database/app_database.dart) 36–64。

### D4：记录时间、最近记录与编辑能力不同

网页 `RecordItem.date` 是文字，新增时写“刚刚”；编辑日期不自动按日期重排，`latestOf` 返回数组中第一个匹配项。App 保存真实时间，repository 按 measuredAt/updatedAt 排序，建议 provider 再按时间选择最新记录。网页还有上下限/备注等编辑，但没有 App 的删除记录、旧照片清理、原估值/确认值完整分离和草稿恢复模型。

依据：[网页](../../web-demo/app/page.tsx) 43/422/755–765；[记录 repository](../../app/lib/features/test_records/data/test_record_repository.dart) 11–18、50/94/125/173/190；[记录页](../../app/lib/features/test_records/presentation/test_records_page.dart) 339–350、623–638、1001；[建议 provider](../../app/lib/features/advice/application/water_quality_advice_provider.dart) 46–50；[计时会话 repository](../../app/lib/features/test_timer/data/test_session_repository.dart) 175/326。

### D5：网页用户目标范围门槛，App 没有对应校验

网页计算 PO4 时拒绝低于当前缸设定下限的目标；KH 拒绝低于用户下限或高于用户上限。App 两药计算页直接将输入交给理论计算域，并未读取当前海缸水质目标；保存端 `createAlkalinityPlanTasks` 和 `createLanthanumPlanTasks` 也没有补充读取/校验 waterQualityTargets。App 仍有公式自身的 PO4≥0.03、目标高低关系、范围与溶解度等检查，不能误写为“完全无校验”。

例如用户 PO4 下限设为0.05时，网页不能算到0.03，App当前理论计算/保存链路无这个用户范围门槛。此例是源码推导，尚未做设备复现。

依据：[网页](../../web-demo/app/page.tsx) `submitLanthanumCalculation`/`submitAlkalinityCalculation` 中 `po4Target`/`khTarget` 判断；[App PO4 页](../../app/lib/features/calculators/presentation/lanthanum_calculator_page.dart) 187；[App KH 页](../../app/lib/features/calculators/presentation/alkalinity_calculator_page.dart) 135；[App maintenance_repository](../../app/lib/features/maintenance/data/maintenance_repository.dart) 98–145、466–529。

### D6：计算页默认值与带入时机不同

App PO4 当前值为空、目标固定0.03；KH 当前值为空、目标8、母液最低温度默认0°C。网页带入最近单值、目标范围默认值，KH计划温度默认20°C。**这不是稳定滴定页的温度默认差异**：两端稳定滴定初始均20°C，但会接受当前会话成功KH计划带入。App calculatorSession按缸记忆成功计算，即使不保存任务；网页取当前 `alkalinityPlan`，打开KH计算器会先清空旧结果。

依据：[App PO4 页](../../app/lib/features/calculators/presentation/lanthanum_calculator_page.dart) 19–23；[App KH 页](../../app/lib/features/calculators/presentation/alkalinity_calculator_page.dart) 18–21、155–158；[App session](../../app/lib/features/calculators/domain/calculator_session.dart)；[App滴定页](../../app/lib/features/calculators/presentation/maintenance_dosing_page.dart) 38–53；[网页](../../web-demo/app/page.tsx) `openAlkalinityCalculator`、表单、MaintenanceDosingPanel传参；[网页滴定](../../web-demo/app/maintenance-dosing-panel.tsx) 9–18。

### D7：App 管理/平台能力多于网页

App 海缸可编辑和归档；任务可停用/启用、归档、永久删除；记录可删除；完整备份、CSV、深色模式在设置中有真实入口。网页侧当前是更简化的管理、停止后续和恢复演示数据。系统通知/相机/文件分享与网页内弹窗/固定示例是平台边界，不能列成需要机械补齐的按钮清单，也不代表真实设备权限/后台能力已经实测通过。

依据：[设置页](../../app/lib/features/settings/presentation/settings_page.dart) 60–180；[任务菜单](../../app/lib/features/maintenance/presentation/maintenance_page.dart) 463–515；[通知协调器](../../app/lib/features/maintenance/application/maintenance_notification_coordinator.dart) 541–553；[拍照资格](../../app/lib/features/image_estimation/domain/photo_capture_models.dart) 34；[网页设置](../../web-demo/app/page.tsx) 888；[网页演示拍照](../../web-demo/app/page.tsx) 180–181、809。

## 重合部分的源码定位

- 鱼目录与限额：[网页 aquarium-data](../../web-demo/app/aquarium-data.ts) 1–76；[App fish_stock](../../app/lib/features/aquarium/domain/fish_stock.dart) 4–9、39–94。同为小丑鱼、双斑公/母、蓝眼公、深水樱花、火焰仙、紫吊、粉蓝吊、东非金剪刀。自定义图片均8MiB输入限制、端侧压缩，但Web将data URL整体限制450000字符，App对base64限长；压缩参数和资产编码不同，未据此声称像素哈希相同。
- PO4规则：[网页领域](../../web-demo/app/lanthanum-calculator.ts) 7–23、177–211；[App领域](../../app/lib/features/calculators/domain/lanthanum_calculator.dart) 3–12、67起。KH规则：[网页领域](../../web-demo/app/alkalinity-calculator.ts) 1–25；[App领域](../../app/lib/features/calculators/domain/alkalinity_calculator.dart) 5–6、62–156。
- 滴定：[网页计算](../../web-demo/app/maintenance-dosing.ts)、[网页面板](../../web-demo/app/maintenance-dosing-panel.tsx)；[App计算](../../app/lib/features/calculators/domain/maintenance_dosing.dart) 28–94、[App面板](../../app/lib/features/calculators/presentation/maintenance_dosing_page.dart)。这里核对的是当前单指标UI实际调用，未将网页领域遗留的days参数当作仍有使用天数输入。
- 盐度：[网页](../../web-demo/app/salinity-calculator.ts)、[App](../../app/lib/features/calculators/domain/salinity_calculator.dart)。
- 任务规则：[网页 task-calendar](../../web-demo/app/task-calendar.ts)；[App recurrence](../../app/lib/features/maintenance/domain/recurrence.dart)、[任务日历](../../app/lib/features/maintenance/presentation/maintenance_calendar.dart)、[化学计划卡](../../app/lib/features/maintenance/presentation/chemical_plan_card.dart)。
- 持久化：[网页 page.tsx](../../web-demo/app/page.tsx) 273–301；[App schema](../../app/lib/data/database/app_database.dart) 241；[完整备份](../../app/lib/data/backup/complete_backup_service.dart)、[CSV](../../app/lib/data/backup/test_record_csv_export_service.dart)。

## 未确认项与后续边界

1. 当前 APK 是否与此刻所有源码完全一致、真实模拟器各功能实际可用性：由 App 任务提交证据；本报告不占用设备、不替代其测试。
2. D2/D3/D5/D6是当前源码确认的差异；本轮未逐项设备/浏览器复现，不自动修复、不改同步清单状态。总调度可记录并由用户决定统一方向。
3. 跨端所有输入/所有历史迁移路径的严格等价、相机真机权限、后台通知、iOS/Safari、鱼动画逐帧表现仍未由本轮验证。
4. 稳定滴定、任务分组等主功能相似，不表示业务数据会在网页与App自动同步；目前无跨端账号/云同步，网页localStorage与App备份格式也不互通。
5. WEB-001继续等待用户确认网页版并明确要求修改App。应按“冲突三选项流程待同步”描述，不能再写成“App不支持仅计算”。
