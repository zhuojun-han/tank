# 当前状态

更新时间：2026-09-08。本页仅维护最新快照和开放项；历史测试结果不自动证明后续修改树通过。

## 本轮：网页版功能同步到 App

用户已授权并完成 WEB-005–008 与 PARITY-004 同步：补液周期与残液续配、KH 无计时查表、目标范围联动、任务延期与实际完成日期。269 项全量测试、静态分析和 Android debug 构建通过，模拟器已保留数据覆盖升级；云端结果及设备边界见 [本轮交付报告](coordination/app-sync-followup-2026-09-08.md)。平台差异统一在 [同步清单](coordination/app-sync-backlog.md) 维护。

旧数据通过 v11 迁移保留，备份继续支持旧版本。补液和普通任务共用日期展示与通知重排；未把网页演示数据导入 App，也未同步独立设计任务中的候选立绘。数据合同见 [技术设计](TECHNICAL_DESIGN.md)。

## 近期已完成工作

- 大图解码、PNG/ZIP 解压、长历史挂载及遗留提醒循环的资源保护：[内存修复实证](coordination/memory-audit-2026-09-08.md)。本次继续保留，并限制 App 通知队列仅处理当前与最新快照。
- Web CI 预览退出修复：[实证与云端结果](coordination/web-ci-preview-2026-09-08.md)。本地功能不等于公开网站已发布，公开网站最近记录仍为 [Sites 第 38 版](coordination/web-verification.md)。
- 此前拍照、趋势、记录与配方同步：[上一批 App 验收](coordination/app-sync-2026-09-08.md)；模拟器 CPU 与工程整理：[工作记录](coordination/android-cpu-and-repository-2026-09-08.md)。

## 开放项

- 拍照估算仍缺独立测试液批次、受控真值和充分设备/光照覆盖；NO3 编号 3 候选范围与人工标签不一致，未调整阈值。按 [拍照规范](IMAGE_ESTIMATION.md) 继续独立评估，不报告准确率或确定误差。
- Android 真机：真实相机/权限、不同厂商后台通知、真机内存峰值、低存储和备份分享恢复；模拟器不能替代。
- iOS：需 macOS/Xcode 构建及实际设备相机、通知验收。
- 发布：正式签名、应用标识、16 KB 原生库兼容性、隐私地址和商店资料等见 [发布清单](RELEASE_CHECKLIST.md)。
- Web 依赖：`vinext → image-size` 静态素材解析链仍待兼容处理，边界见 [依赖审计](coordination/project-optimization-followup-2026-09-08.md#剩余依赖与实际使用路径)。生产包审计为 0 不代表全部路径无风险。

Windows 路径/JBR 命令统一见 [App README](../app/README.md)。旧决策和结果保存在 [归档索引](archive/2026-09-08-before-workflow-cleanup/INDEX.md)；每次重要交付在 `coordination/` 保留实际命令、结果和未测边界，本页只链接证据。
