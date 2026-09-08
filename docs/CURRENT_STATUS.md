# 当前状态

更新时间：2026-09-09。本页仅维护最新快照和开放项；历史测试结果不自动证明后续修改树通过。

## 最新交付：网页版与 App 剩余差异同步

已按用户授权补齐开缸日期/运行时长、可选水体积、新建后切缸及 KH 滴定一位小数显示，并修复检测复核异步输入隔离和旧草稿缓存。App schema/备份 v12 保留旧数据；本地及云端 293 项全量测试、静态分析、Android 构建与模拟器保留数据升级通过。代码 `54c55f1` 已上传，云端检查全部成功；实际证据见 [本轮记录](coordination/app-web-parity-2026-09-08.md)。

同步清单中的已授权功能差异已完成，永久 ID 与验收索引见 [同步清单](coordination/app-sync-backlog.md)。Web 与 App 仍分别本地存储；功能同步不代表云端数据同步或公开网站重新发布。

## 近期已完成工作

- 新增 11 种鱼、两端共 20 个内置选项及 App 界面精简：[鱼类与文案交付](coordination/fish-catalog-and-app-copy-2026-09-08.md)。原稿、用户库存与必要操作保留。
- 补液/残液、KH 无计时查表、目标联动与完成驱动排期：[前批 App 同步](coordination/app-sync-followup-2026-09-08.md)；开缸功能的原网页实证：[Web 交付](coordination/tank-age-web-2026-09-08.md)。
- 多海缸核心任务、记录/趋势及鱼档案隔离核查，及 Web 新建清理、App 异步草稿缺陷修复：[隔离记录](coordination/tank-isolation-audit-2026-09-08.md)。
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
