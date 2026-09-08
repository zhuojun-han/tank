# 当前状态

更新时间：2026-09-08。这里仅维护最新快照和开放项；历史结果按批次报告引用，不自动作为当前修改树的验证证明。

## 本轮工作：模拟器 CPU、后台修复与 GitHub 上传

详见 [本轮实证](coordination/android-cpu-and-repository-2026-09-08.md)。用户已授权 App 修复及上传指定 GitHub 仓库；WEB-005 的网页优先授权不变。

- CPU：无窗口模拟器仍在首页前台使用软件渲染。相同 Debug 首页切换硬件 GPU 后，宿主 CPU 约 66.3% → 15.5%；退到 Android 桌面约 1%–2%，App 进程该段采样为 0。不能据此推定发布版真机性能。
- App：修复检测计时在后台持有旧草稿、到期重复完成的问题；前台恢复按截止时间结算，数据库条件更新防止旧快照覆盖。205 项全量测试、分析、格式和 Debug 构建通过；保留数据安装，11 张表逐行一致，所查启动日志无未处理异常。
- 仓库：App/Web 已统一根仓并上传到 [GitHub 私有仓库](https://github.com/zhuojun-han/tank)。首次源码提交 `eab147a` 已核对本地与远程 main 一致；GitHub 两端检查已启动，结果见本轮实证，不把本地通过当作远程通过。
- 文档：README、AGENTS 与模块规范按单一权威整理，67 份文档及根检查通过；纯文档提交只跑轻量工作区 CI。旧 Web Git 历史仍完整保存在本机，20 份历史文档原文和哈希保留。
- 本轮单仓调整验证：根工具 5 项、Web 单元 96 项及合同/文档检查通过；没有部署网站或发布 App。

上一批存储、查询分页、备份、依赖和趋势设备验证见 [优化收尾](coordination/project-optimization-followup-2026-09-08.md)；此前分阶段实证见 [原交接](coordination/project-optimization-2026-09-08.md) 与 [文档整理](coordination/project-workflow-cleanup-2026-09-08.md)，旧测试数不替代当前验证。

## 已交付基线

| 范围 | 最近已记录的结果 | 证据与限制 |
| --- | --- | --- |
| 网页每日平衡补液周期 | 本地实现；当轮 94 项测试、生产构建与浏览器流程通过 | [网页工作记录](coordination/maintenance-cycle-web-2026-09-08.md)；未发布，App 未同步 |
| 此前网页功能 → App | 已同步并保留数据覆盖安装 Android 模拟器；当轮 200 项全量与最后 6 项相关回归通过 | [同步验收](coordination/app-sync-2026-09-08.md)；真实相机、真机通知、iOS 未验证 |
| 公开网站 | 最近记录为 Sites 第 38 版 | [当轮报告](coordination/web-verification.md)；此后本地功能未据此宣称上线 |

当前平台差异仅由 [App 同步清单](coordination/app-sync-backlog.md) 管理；数据库与备份合同由 [技术设计](TECHNICAL_DESIGN.md) 管理。

## 开放项

- **WEB-005**：每日平衡补液周期仅网页完成，等待用户确认该功能并要求同步 App；后续需要 App 持久化、备份、日期发生项和通知实现。
- 拍照：已收到 NO3/PO4 色卡与多张样本，仍缺独立测试液批次、受控真值和充分设备/光照覆盖；不得报告准确率或确定误差。按 [拍照规范](IMAGE_ESTIMATION.md) 继续数据审计与独立评估。
- Android 真机：相机权限、真实拍摄、缓存清理、通知栏/后台限制、低存储、备份分享恢复；模拟器不能替代。
- iOS：macOS/Xcode 构建、启动、相机/通知和设备验收；Windows 不具备该验证条件。
- 发布：正式签名、应用标识及商店资料、16 KB 原生库兼容性、隐私公开地址等见 [发布清单](RELEASE_CHECKLIST.md)。
- NO3 编号 3 的当前候选范围与人工标签不一致，已如实保留在本轮实图审计中；本轮未调整阈值。
- 依赖维护：image-size 静态素材解析和 Miniflare 锁定 undici 的两条工具依赖链尚待独立兼容处理，见 [剩余依赖](coordination/project-optimization-followup-2026-09-08.md)。不能把生产审计为 0 或本地 CI 配置存在写成全面安全或 CI 已在线运行。

## 环境与历史

Windows 中文路径及 JBR 临时目录问题的当前命令统一见 [App README](../app/README.md)，不从旧日志复制环境变量。Java native access 和 flutter_timezone Kotlin 迁移警告须在相关升级时复核，不等同于本轮构建失败。

整理前完整状态、用户决策和旧验收结果保存在 [归档索引](archive/2026-09-08-before-workflow-cleanup/INDEX.md)。每次重要交付在 `coordination/` 保留日期、范围、命令、结果和未测边界；本页只链接最新证据。
