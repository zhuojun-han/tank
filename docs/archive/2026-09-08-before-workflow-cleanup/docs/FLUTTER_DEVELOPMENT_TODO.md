> 历史归档：2026-09-08 工作流整理前的原文。保留当时结论与命令，不作为当前执行规范；相对链接已转向原目标。[当前文档](../../../FLUTTER_DEVELOPMENT_TODO.md)。

# Flutter 开发执行提示与 To-do

本文是后续 Codex 开发正式 Android/iOS App 时的执行入口。每次开始 Flutter 开发前，先阅读 `AGENTS.md`、`README.md`、`docs/PROJECT_CONTEXT.md`、`docs/CURRENT_STATUS.md` 和本文；只完成当前阶段，不提前堆叠未验证功能。

## 总体目标

使用 Flutter 构建离线优先的海缸水质管理 App。Android 与 iOS 共用业务代码；首版不需要账号和云同步。网页版 Demo 只作为交互参考，正式 App 的数据、通知、计时和相机能力必须在 Flutter 工程中独立实现并验证。

## 开发原则

- 页面不得直接访问 SQLite、安排通知或操作照片文件。
- 按“页面/组件 → 控制器/状态 → 用例服务 → 仓库/平台服务 → 本地存储或系统能力”分层。
- 使用 Riverpod 管理状态，使用声明式路由管理导航。
- 使用 Drift/SQLite 保存本地数据；每次 schema 变化必须增加版本并提供迁移测试。
- 算法原始估值与用户最终确认值必须分开保存。
- 所有时间点以 UTC 保存，按设备当前时区显示。
- 建议规则必须展示触发数据、规则来源和安全边界；不能替代专业诊断。
- 拍照只能描述为辅助估算；没有真实样本验证时不得承诺精度。
- 每个阶段只有在适用测试和实际验收完成后才能标记完成。
- 完成重要工作后同步检查并更新 `README.md`、`docs/PROJECT_CONTEXT.md` 和 `docs/CURRENT_STATUS.md`。

## 推荐目录

```text
app/
  lib/
    app/                  应用入口、主题、路由
    core/                 日志、错误、时间和公共工具
    features/
      tanks/              海缸管理
      parameters/         水质参数与目标范围
      test_records/       检测记录
      trends/             趋势
      advice/             维护建议规则
      maintenance/        周期任务
      test_timer/         检测计时器
      image_estimation/   拍照辅助估值
    data/
      database/           Drift 数据库与迁移
      backup/             备份、恢复、CSV
  test/
  integration_test/
```

正式 Flutter 工程目录为 `app/`；平台工程由实际 Flutter CLI 生成，后续仍不得手写伪造平台工程文件。

## 阶段 0：工程初始化

### 0.1 环境准备

- [x] 检查 Flutter、Dart、Java、Android SDK 和 ADB 是否可用。
- [x] 安装或定位 Flutter SDK。
- [x] 安装或定位 Android Studio、Android SDK、平台工具和 Java。
- [x] 执行 `flutter doctor -v` 并记录真实输出摘要。
- [x] 接受实际需要的 Android SDK 许可证。
- [x] 创建或连接 Android 模拟器/真机。
- [ ] iOS 构建环境在 macOS/Xcode 上验证；Windows 阶段标记为待确认。

### 0.2 创建工程

- [x] 使用实际 Flutter CLI 在 `app/` 创建 Android/iOS 工程。
- [x] 记录 Flutter、Dart、Gradle、Android SDK 和 Java 的实际版本。
- [x] 锁定依赖并保留 Flutter 生成的锁文件。
- [x] 确认 Android debug 构建能够完成。
- [x] 确认 Android 模拟器或真机能够启动 App。

### 0.3 基础架构

- [x] 建立 `app/`、`core/`、`features/` 和 `data/` 分层。
- [x] 接入 Riverpod；版本根据创建工程当日的兼容情况选择并锁定。
- [x] 接入声明式路由；版本根据实际兼容情况选择并锁定。
- [x] 建立中文主题、浅色/深色基础配色和文字样式。
- [x] 建立首页、检测、趋势、任务四个底部入口和设置入口。
- [x] 建立统一错误展示与日志接口，不记录照片或敏感本地数据。
- [x] 为首屏和导航添加 Widget 测试。

### 0.4 工程质量

- [x] 配置 `flutter analyze`。
- [x] 配置 `flutter test`。
- [x] 添加最小持续集成配置，执行格式、分析和测试。
- [x] 在 README 写入已实际运行成功的命令。
- [x] 更新 `docs/CURRENT_STATUS.md`，区分“代码已写”“构建成功”和“真机/模拟器已启动”。

### 阶段 0 验收

- [x] `flutter doctor -v` 的 Android 开发必要项不存在阻断错误。
- [x] `flutter analyze` 通过。
- [x] `flutter test` 通过。
- [x] Android debug 构建通过。
- [x] Android 模拟器或真机至少完成一次启动验证。
- [x] iOS 启动验证已在 macOS 完成，或明确记录为“待 Mac 环境确认”；不得在 Windows 上宣称通过。

## 阶段 1：本地数据与海缸

- [x] 接入 Drift/SQLite 和 schema 版本管理。
- [x] 实现 `Tank`、`WaterParameter`、`TankParameter`、`WaterQualityTarget` 和 `ReagentProfile`。
- [x] 首次启动事务性创建一个默认海缸。
- [x] 实现海缸新增、编辑、切换和归档。
- [x] 内置 NO3、PO4、KH、Ca、Mg、K；新海缸默认只启用 NO3、PO4。
- [x] 支持每缸独立启用 KH、Ca、Mg、K 和自定义参数。
- [x] 停用参数不得删除目标或历史。
- [x] 实现仓库层和跨海缸隔离测试。
- [x] 实现最小本地备份/恢复并测试记录关联。

### 阶段 1 验收

- [x] 首次启动只有一个默认海缸。
- [x] 新增、切换、归档后数据不串缸。
- [x] 自定义参数能关联正确海缸。
- [x] schema 迁移和备份恢复测试通过。

说明：当前数据库为 schema v7，迁移测试覆盖 v1–v7；备份格式 v7 覆盖全部 11 张业务表，以权威快照恢复配置（含主题和维护提醒总开关）、记录/趋势来源、有限计划和任务历史，不含照片，并兼容读取 v1–v6 旧格式。

## 阶段 2：手动检测、首页与趋势

- [x] 实现 `TestRecord`，分离算法估值和人工确认值。
- [x] 支持单值、范围、检测时间、备注和历史编辑。
- [x] 实现每缸、每参数目标范围。
- [x] 实现首页最近记录、设备当天日期和真实空状态。
- [x] 实现趋势图、目标区间和数据不足提示。
- [x] 按 `docs/ADVICE_RULES.md` 接入 NO3/PO4 建议规则。
- [x] 建议展示触发记录、用户目标、规则来源和“不能替代专业诊断”的安全边界。
- [x] 编辑记录后立即刷新首页、趋势和建议。

## 阶段 3：维护任务与通知

- [x] 实现 `MaintenanceTask` 和 `TaskEvent`。
- [x] 实现新增、编辑、停用、归档、永久删除、完成、跳过和稍后提醒。
- [x] 实现待处理、已完成和全部筛选。
- [x] 默认 09:00；完成/跳过从操作时间计算下一周期。
- [x] 接入 Android/iOS 本地通知和通知点击路由。
- [x] 权限拒绝时 App 内任务状态仍正确。
- [x] 启动及任务变化时重新核对通知计划。

## 阶段 4：检测计时器与拍照流程

- [x] 实现按海缸和参数保存的计时默认值。
- [x] 支持 3/5/10 分钟快捷时间和 10 秒至 60 分钟自定义时间。
- [x] 根据绝对结束时间恢复后台或进程重启后的计时。
- [x] 实现检测草稿、跳过计时直接录入和结束通知。
- [x] 接入相机权限、拍摄引导、压缩、质量检查和手动降级流程。
- [x] 算法未验证前只提供实验性 NO3 临时拍照辅助和人工选择档位；确认或取消后删除照片，PO4 保持手动录入。

## 阶段 5：NO3 辅助估值

- [x] 建立版本化、按批次隔离的样本清单格式及调参/验证集泄漏审计；当前仍缺可用于最终评估的独立验证样本。
- [ ] 实现真实照片上的色卡/试管自动定位和完整颜色校正；当前仅有调用方预提取颜色后的距离、质量与拒绝规则骨架。
- [x] 规则骨架只输出已知单档、相邻范围或无法估值，不输出未经验证的连续精确值。
- [x] 数据模型保存算法版本、质量评分、置信度和最终人工结果。
- [ ] 输出完整离线评估报告，不只展示成功案例。

## 阶段 6：PO4 与发布准备

- [ ] 取得 PO4 品牌、色卡、单位、量程、显色时间和样本后再实现估值。
- [ ] 完成 Android/iOS 核心流程真机回归。
- [ ] 完成无网络、权限、时区、空间不足、备份恢复和可访问性测试。
- [x] 在 App 与项目文档中展示隐私边界和已知限制。
- [ ] 正式发布前在商店与发布说明中同步展示隐私边界和已知限制。

## 当前执行状态

- 当前阶段：Android 阶段 0–4 与阶段 5 规则骨架已完成当前树自动化测试和 debug 构建；同日较早的 debug 基线完成了模拟器验收。阶段 5 真实独立样本评估、最新 APK 模拟器复验、Android 真机以及 macOS/iOS 验收仍待完成。
- 2026-08-09 已安装 Flutter 3.44.7、Dart 3.12.2、Android Studio Quail 3、Android SDK 36、build-tools 36.0.0、Gradle 9.1.0 和 OpenJDK 25.0.2。
- `flutter doctor -v` 的 Android toolchain 已通过；Visual Studio 缺失只影响本项目不构建的 Windows 桌面目标。
- `app/` 当前为 Drift schema v7，包含海缸与参数、主题及提醒偏好、检测记录、目标、首页与趋势、可追溯建议、月历任务与通知、海盐及氯化镧计算器、实验性 NO3 临时拍照辅助流程和完整业务数据备份/恢复。
- 2026-08-24 当前树已通过 `flutter analyze`、132 项 `flutter test` 和 Android debug APK 构建；同日较早的 debug 基线已通过 API 36 模拟器安装/冷启动。相机与通知仍须真机验证，拍照估值仍不得报告准确率或误差范围。
- iOS 验证：待 macOS/Xcode 环境确认。

## 每次开发任务的结束检查

1. 运行本阶段适用的格式化、分析、单元测试、构建或真机验证。
2. 记录实际命令和实际结果；未运行的检查不得写成通过。
3. 重新阅读 `AGENTS.md`。
4. 更新本文复选框和 `docs/CURRENT_STATUS.md`。
5. 同步核对 `README.md` 与 `docs/PROJECT_CONTEXT.md`，避免把计划描述成已实现。
