> 历史归档：2026-09-08 工作流整理前的原文。保留当时结论与命令，不作为当前执行规范；相对链接已转向原目标。[当前文档](../../../TECHNICAL_DESIGN.md)。

# 技术与数据设计

本文记录 Flutter App 已采用的技术方案与仍需外部验收的边界。实现事实以当前源码、锁文件、测试和 `docs/CURRENT_STATUS.md` 为准；真机相机/通知、真实样本和 iOS 未完成前不得写成已验证。

## 技术方案

- 客户端：Flutter 与 Dart，一套代码支持 Android 和 iOS。
- 状态管理：Riverpod；按功能划分状态，避免页面直接访问数据库或通知插件。
- 导航：声明式路由，支持通知点击后定位到任务或检测流程。
- 本地数据库：SQLite，使用 Drift 提供类型安全查询和迁移管理。
- 相机：Flutter 官方 `camera` 插件作为首选接入层。
- 通知：`flutter_local_notifications` 作为首选本地通知接入层。
- 图像估值：端侧传统计算机视觉为主；小型端侧检测/分割模型仅在规则定位不足时辅助识别区域。
- 网络：首版业务流程不依赖网络，不接视觉大模型、不上传检测照片。
- 依赖版本：创建工程时根据当日官方兼容信息锁定，本文不写死版本号。

选择依据：本项目需要双平台、本地关系数据、系统通知、相机采集和离线运行。Drift 基于 SQLite 并支持迁移；Flutter 官方相机插件支持预览、拍照和图像流。第三方依赖仍需在工程创建时进行许可证、平台要求和真机兼容验证。

## 分层

```text
页面与组件
  -> 功能控制器/状态
    -> 用例服务
      -> 数据仓库 / 通知服务 / 相机与图像估值服务 / 文件备份服务
        -> SQLite / 临时照片缓存 / Android与iOS平台能力
```

- 页面不直接拼接 SQL、安排系统通知或读写照片。
- 所有时间在数据库中以 UTC 时间点保存，界面按设备当前时区显示。
- 通知计划是数据库任务状态的派生结果；App 启动和任务变更时重新核对，避免通知与任务不一致。
- 图像算法输出与用户最终确认值分开保存，便于以后复核算法而不覆盖真实使用记录。

## 氯化镧理论计算边界

该计算器已进入 `web-demo/` 与 Flutter App；App 把有限分日事项写入当前海缸的本地任务表，但不进入任何自动加药链路。核心计算放在无界面副作用的函数中并由单元测试覆盖；输入、输出与校验规则以 `docs/LANTHANUM_CHLORIDE_CALCULATOR.md` 为准。

必填输入为人工确认的当前 PO4 单值、精确目标 PO4、实际净水体积和单日最大计划降幅。盐固定为纯度 `99.9%` 的七水合氯化镧 `LaCl3·7H2O`；净水体积默认 `200 L`，目标不得低于 `0.03 mg/L`，单日计划输入限制为 `0.1–0.5 mg/L`。范围记录、非有限数值、非正体积或目标不低于当前值时不得形成计划。

计算只采用 `La3+ + PO4^3- -> LaPO4` 的 `1:1` 摩尔关系：

```text
stockPO4Capacity_mg_per_mL = 0.1 mg/L * 100 L = 10 mg/mL
stockReagent_mg_per_mL = 10 * (371.37 / 94.971) / 0.999
stockBatch_g = stockReagent_mg_per_mL * selectedStockFinalVolume_mL / 1000
days = ceil((currentPO4_mgL - targetPO4_mgL) / userConfirmedDailyDrop_mgL)
dayDrop_i = min(userConfirmedDailyDrop_mgL, remainingPO4Gap_mgL)
dailyStock_mL_i = dayDrop_i * netVolume_L / 10
nominalDilutionWater_mL_i = 500 - dailyStock_mL_i
```

七水合氯化镧 `LaCl3·7H2O` 的摩尔质量取 `371.37 g/mol`。固定母液浓度约为 `39.142658 mg/mL`；网页版允许选择母液最终体积，默认 `500 mL` 时称量值约为 `19.571329 g`，其他体积按比例缩放，Flutter App 当前仍固定为 `500 mL`。这里的母液体积均表示“定容后的最终总体积”；每日工作液仍定容至最终 `500 mL`，补水差值只作界面名义量，实际操作应逐步加水至体积刻度。实现中不得添加反应效率、吸附效率或所谓海缸经验修正系数；实际下降与计划不符时必须复测和重算，不能自动补量。

简化界面不再使用检测可靠下限、日降幅来源或安全复选框作为独立安全门。确认计划后按计算出的预计天数保存有限数量的全部分日条件任务，每项带计划 ID、天数序号、当天母液体积和本地日历日期；任务页以周一开头的六周月历显示事项，并支持前后翻月、按日查看及直接完成/跳过。普通周期任务只持久化一条规则；网页 Demo 可按可见窗口预览重复日期，Flutter App 只显示当前已经确定的下一次到期日，完成或跳过后再从实际操作时间推进下一周期，两者都不预生成无限记录。氯化镧事项仍要求每天先复测 PO4/KH、观察生物并用机械过滤或蛋分捕获沉淀；目标达到、读数异常、KH 明显变化、持续浑浊或生物应激时，停止当天会同步停止同一计划当天及后续事项。

网页 Demo 的到期弹窗设置持久化 `notificationEnabled` 与当天关闭日期；开启后页面仅在当前海缸存在当天未处理事项且当天尚未关闭提示时显示站内弹窗。该实现没有 Service Worker 或后台推送，不得描述为浏览器关闭后的手机系统通知；Flutter App 的本地通知仍按独立调度和真机权限验收。

## 网页版 Demo 的海盐配制估算边界

海盐计算放在无界面副作用的 `web-demo/app/salinity-calculator.ts` 中。输入为初始 SG、目标 SG、起始水量、包装每升用盐量和该用盐量对应的包装基准 SG。初始输入 `0` 映射到 `SG 1.000`；目标不高于初始值、非正水量、非有限数值或无效包装基准时拒绝计算。

```text
effectiveInitialSG = initialSG == 0 ? 1.000 : initialSG
fraction = (targetSG - effectiveInitialSG) / (labelReferenceSG - 1.000)
requiredSalt_g = waterVolume_L * labelSalt_g_per_L * fraction
initialAddition_g = requiredSalt_g * 0.9
reservedAdjustment_g = requiredSalt_g - initialAddition_g
```

默认目标为 `1.025`，默认包装校准为 Red Sea Salt 示例 `38.2 g/L @ SG 1.0255`。公式只是比重差的线性起始估算，必须允许用户按实际产品包装修改校准；界面不得把结果描述为跨品牌精确保证。最终比重以充分溶解、达到产品标注温度并经校准量具复测为准。完整边界见 `docs/SALINITY_CALCULATOR.md`。

## 数据实体

### Tank

- `id`：本地唯一标识。
- `name`：必填，界面内不可为空。
- `notes`：可选。
- `isArchived`、`createdAt`、`updatedAt`。

### WaterQualityTarget

- `id`、`tankId`、`parameterId`。
- `minValue`、`maxValue`、`unit`（mg/L）。
- 同一海缸同一指标最多一条有效目标范围，且最小值不得大于最大值。

### WaterParameter

- `id`、`name`、`displayName`、`unit`、`isBuiltIn`、`photoSupported`。
- 内置 NO3、PO4、KH、Ca、Mg、K；自定义参数名称在本地不区分大小写且不得重复。
- `TankParameter` 关联海缸与已启用参数；停用关联不级联删除目标或历史记录。

### TestRecord

- `id`、`tankId`、`parameter`、`reagentProfileId`。
- `capturedAt`、`confirmedAt`。
- `estimatedMin`、`estimatedMax`、`confidence`、`failureReason`：算法输出，可为空。
- `confirmedMin`、`confirmedMax`：用户最终结果；单档结果两者相等。
- `unit`、`photoPath`、`note`。
- `wasManuallyEdited`、`updatedAt`：标记保存后的人工修改及最后修改时间。
- 保存后允许修改 `tankId`、`parameter`、`confirmedMin/Max`、`confirmedAt`、`reagentProfileId` 和 `note`；不得覆盖算法原始估值、置信度和原始拍摄时间。
- 首版不要求保存每次编辑前的完整历史版本，但算法结果与最终确认结果必须始终分离。

### ReagentProfile

- `id`、`brand`、`parameter`、`unit`、`colorLevels`。
- `defaultDevelopmentSeconds`、`cardVersion`、`isEnabled`。
- 首版内置益尔 NO3 档位 0、1、5、10、25、50、100 mg/L；具体色卡版本仍为待确认。

### MaintenanceTask

- `id`、`tankId`、`title`、`notes`。
- `intervalAmount`、`intervalUnit`（天/周/月）。
- `dueAt`、`preferredReminderTime`、`status`（启用/停用/归档/一次性已完成/一次性已跳过）。
- `isOneOff`、`source`、`planId`、`planDayIndex`、`planTotalDays`：有限一次性计划及其来源元数据；普通周期任务保持为空。
- `notificationId`、`createdAt`、`updatedAt`。

### TaskEvent

- `id`、`taskId`、`type`（完成/跳过/稍后提醒）。
- `occurredAt`、`snoozedUntil`、`note`。
- 完成和跳过从事件发生时间计算下一次到期；稍后提醒不改变周期。

### ActiveTestSession

- `id`、`tankId`、`parameter`、`reagentProfileId`。
- `startedAt`、`timerDurationSeconds`、`timerEndsAt`、`draftPhotoPath`、`stage`；草稿复制开始检测时的默认时长，避免进行中的计时被配置变化影响。
- 仅保留未完成检测草稿；保存记录或明确放弃后删除。

### 检测计时默认值

- 按 `tankId + parameterId` 保存 `durationSeconds`，范围为 10 秒至 60 分钟。
- 未设置时使用 5 分钟初始值；用户修改后持续用于该海缸该参数的后续检测。

## 文件和备份

- 数据库位于应用私有目录；当次比色照片使用随机文件名写入应用缓存，相册权限不是首版必需权限。
- 拍照页确认、取消、重拍或改为手动录入时清理临时文件；正式记录和新备份始终写入空照片引用。schema v7 的可空照片列只为旧数据库/旧备份兼容保留，应用偏好表同时持久化当前海缸、主题模式和维护提醒总开关。
- 完整备份为 v7 版本化 JSON 数据快照和 SHA-256 清单打包成的 ZIP，只含 11 张业务表的可迁移数据，不含照片或设备通知权限；趋势由检测记录重建。
- 恢复先解析并校验版本、必填字段、关联、ZIP 路径、CRC 和 SHA-256，再由用户二次确认；移动到新设备时在同一 SQLite 事务中以备份为准替换本机业务数据。旧 v1–v6 JSON/旧完整 ZIP 可读取，但照片引用被清空且图片不复制。
- CSV 只导出水质记录和任务历史，不含照片，也不作为恢复格式。

## 数据迁移与错误处理

- 每次数据库结构变化必须提高 schema 版本并提供迁移测试。
- 写入记录、任务事件和下一次到期计算使用事务。
- 编辑检测记录后，使涉及的海缸/指标查询失效并重新计算首页摘要、趋势和建议。
- 通知安排失败不回滚任务本身；记录错误并在界面显示“通知未安排”，允许重试。
- 照片处理失败时允许重试或改用手动录入，并尽力清理相机源文件和缓存工作文件。
- 本地空间不足时不丢失已确认数值，提示用户清理缓存或导出数据备份。

## 首版不做

- 账号、云同步、多人共享和网页端。
- 云端视觉大模型或将照片发送到第三方。
- 自动加药、控制硬件或给出没有可追溯输入与适用来源的通用药剂剂量。网页版 Demo 与 Flutter App 可以展示氯化镧的理论化学计量和用户确认日上限后的有限分日计划，但不得称为通用安全剂量。
- 未经样本验证的连续数值回归或“实验室级精度”宣传。
