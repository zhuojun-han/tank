# 当前状态

更新时间：2026-09-08。这里仅维护最新快照和开放项；历史结果按批次报告引用，不自动作为当前修改树的验证证明。

## 本轮工作：网页目标范围联动

已完成 PO4 降低、KH 提升计划默认目标与当前海缸范围中值联动，以及 KH 默认范围，详见 [本轮实证](coordination/target-linkage-web-2026-09-08.md)。本项沿用网页优先流程，App 暂未同步。

- 计划目标按当前缸完整范围取中点，允许手动修改；KH 默认 7–9 dKH，中点 8，保留已有自定义范围。
- 旧存档已启用且双空的 KH 范围只初始化一次；之后主动清空仍保持空白，不自动启用未关注的 KH。
- 类型、全项目 lint、114 项单元测试、一次生产构建和 2 项 SSR 通过；4 项相关浏览器流程通过，覆盖目标联动、存储、计划预览与 KH 检测回归。
- 产品和数据合同已更新，差异登记 WEB-007；WEB-005/006 状态不变。没有修改 App 或发布网站。

上一项 KH 无计时滴定查表与一位小数记录见 [KH 检测实证](coordination/kh-titration-web-2026-09-08.md)，本轮定向浏览器回归仍通过。

此前模拟器 CPU、App 计时修复、根仓和 CI 整理见 [上一批实证](coordination/android-cpu-and-repository-2026-09-08.md)；存储、分页、备份与依赖验证见 [优化收尾](coordination/project-optimization-followup-2026-09-08.md)。历史测试数不替代当前修改的验证。

## 已交付基线

| 范围 | 最近已记录的结果 | 证据与限制 |
| --- | --- | --- |
| 网页每日平衡补液周期 | 本地实现；当轮 94 项测试、生产构建与浏览器流程通过 | [网页工作记录](coordination/maintenance-cycle-web-2026-09-08.md)；未发布，App 未同步 |
| 此前网页功能 → App | 已同步并保留数据覆盖安装 Android 模拟器；当轮 200 项全量与最后 6 项相关回归通过 | [同步验收](coordination/app-sync-2026-09-08.md)；真实相机、真机通知、iOS 未验证 |
| 公开网站 | 最近记录为 Sites 第 38 版 | [当轮报告](coordination/web-verification.md)；此后本地功能未据此宣称上线 |

当前平台差异仅由 [App 同步清单](coordination/app-sync-backlog.md) 管理；数据库与备份合同由 [技术设计](TECHNICAL_DESIGN.md) 管理。

## 开放项

- **WEB-005**：每日平衡补液周期仅网页完成，等待用户确认该功能并要求同步 App；后续需要 App 持久化、备份、日期发生项和通知实现。
- **WEB-006**：KH 无计时滴定查表、插值与可选记录仅网页完成，等待用户确认并要求同步 App。
- **WEB-007**：PO4/KH 目标范围中值联动、KH 默认范围与旧存档初始化仅网页完成，等待用户确认并要求同步 App。
- 拍照：已收到 NO3/PO4 色卡与多张样本，仍缺独立测试液批次、受控真值和充分设备/光照覆盖；不得报告准确率或确定误差。按 [拍照规范](IMAGE_ESTIMATION.md) 继续数据审计与独立评估。
- Android 真机：相机权限、真实拍摄、缓存清理、通知栏/后台限制、低存储、备份分享恢复；模拟器不能替代。
- iOS：macOS/Xcode 构建、启动、相机/通知和设备验收；Windows 不具备该验证条件。
- 发布：正式签名、应用标识及商店资料、16 KB 原生库兼容性、隐私公开地址等见 [发布清单](RELEASE_CHECKLIST.md)。
- NO3 编号 3 的当前候选范围与人工标签不一致，已如实保留在本轮实图审计中；本轮未调整阈值。
- 依赖维护：image-size 静态素材解析和 Miniflare 锁定 undici 的两条工具依赖链尚待独立兼容处理，见 [剩余依赖](coordination/project-optimization-followup-2026-09-08.md)。不能把生产审计为 0 或本地 CI 配置存在写成全面安全或 CI 已在线运行。

## 环境与历史

Windows 中文路径及 JBR 临时目录问题的当前命令统一见 [App README](../app/README.md)，不从旧日志复制环境变量。Java native access 和 flutter_timezone Kotlin 迁移警告须在相关升级时复核，不等同于本轮构建失败。

整理前完整状态、用户决策和旧验收结果保存在 [归档索引](archive/2026-09-08-before-workflow-cleanup/INDEX.md)。每次重要交付在 `coordination/` 保留日期、范围、命令、结果和未测边界；本页只链接最新证据。
