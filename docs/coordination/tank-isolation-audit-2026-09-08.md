# 多海缸隔离核查

2026-09-08，核查提交 `943836b` 的 App/Web。用户要求确认任务、数据、趋势和首页鱼缸是否独立。本轮核查与隔离环境复现不修改业务源码或用户存档。

## 结论

| 范围 | 当前行为 |
| --- | --- |
| 任务、完成事件、有限加药计划、补液及残液 | 按海缸隔离，补液再按药剂区分；操作重新核对归属 |
| 检测记录、目标、指标启停、趋势、计时默认值 | 按海缸及指标隔离；记录编辑允许用户明确迁移所属海缸 |
| 首页鱼只 | 鱼种、数量、入缸日期、自定义立绘按缸保存；切换后显示对应缸内容 |
| 共用部分 | 界面样式和背景、参数/试剂目录、主题、提醒总开关、整库备份/恢复；Web 的页面/日历选择及“今天不再提示”也为全局状态 |

主要实现依据：[App 鱼档案仓库](../../app/lib/features/aquarium/data/fish_stock_repository.dart)、[App 任务仓库](../../app/lib/features/maintenance/data/maintenance_repository.dart)、[App 趋势数据源](../../app/lib/features/trends/data/record_history_source.dart)、[网页页面](../../web-demo/app/page.tsx)。共用背景不表示鱼档案共用；全局提醒关闭不删除其他缸待办。

## 已复现、尚未修复

1. **Web 新建海缸期间旧复核结果未清空。** A 缸输入 NO3 范围 12–18、插值 15，尚未确认时从顶部新建 B 缸；旧复核卡保留，确认后记录写入 B。`page.tsx` 的新建缸处理未调用 `resetDetection`，`saveDetection` 直接使用当前缸。应统一切缸清理，并在保存时核对草稿原属缸。隔离 Edge context 实测，证据在忽略目录 `artifacts/tank-isolation-web-check.json`。
2. **App 排队保存旧草稿时读取另一草稿的日期。** [复核保存队列](../../app/lib/features/test_timer/presentation/test_workflow_page.dart) 的 `_queueReviewPersistence` 已快照数值与备注，却在闭包执行时读取可变 `_confirmedAt`。真实页面、控制器和内存 SQLite 下，延迟 A 的第一次保存、继续输入、在同一页面切到 B 后释放队列：A 日期从 `2001-02-03T04:05Z` 变成 B 的 `2002-03-04T05:06Z`；两缸数值和归属未交换。应在入队前一并快照日期。临时诊断位于 `app/build/tank-isolation-review-date_test.dart`，日志 `app/build/tank-isolation-review-date.log`；诊断通过表示复现漏洞，不表示产品隔离通过。

## 验证边界

后续状态：第 1 项已随 [Web 开缸日期功能](tank-age-web-2026-09-08.md) 统一新建/切换海缸清理并通过浏览器回归；第 2 项 App 排队日期问题仍开放。上面的复现保留为当时证据。

- App 现有 7 个相关测试文件重新运行，**33 项通过**：鱼档案、首页切缸/趋势、维护任务、补液仓库、目标联动、记录页面、检测会话。命令使用 `flutter test --no-pub --concurrency=1` 指定这些文件，日志 `app/build/tank-isolation-check.log`。既有断言未覆盖上述异步日期场景。
- Web 用独立浏览器 context 确认上述错缸保存，以及 A 缸关闭当日弹窗会抑制 B 缸弹窗、B 待办仍可见；未触碰用户浏览器存储。
- 本轮没有重新安装 App、运行全量构建或修改功能。核心读写隔离与共享配置已核对，两个缺陷需单独修复回归后才能扩大结论。
