# 当前状态

更新时间：2026-09-09。本页仅维护最新快照和开放项；历史测试结果不自动证明后续修改树通过。

## 进行中：网页版与 App 剩余差异同步

用户已明确授权本轮同步。已补齐 WEB-009 开缸日期/运行时长、海缸可选水体积、KH 滴定在首页与趋势的一位小数显示，并修复检测复核异步保存与旧缓存问题。App schema/备份升至 v12，旧缸新增资料保持空值；格式、静态分析和 293 项全量测试通过，Android 构建、保留数据升级及云端检查正在验收。继续入口见 [本轮记录](coordination/app-web-parity-2026-09-08.md)。

## 上一批：新鱼种与 App 界面精简

新增蓝吊、黄狐狸、黄金吊等 11 种鱼，两端现有 20 个内置选项；用户授权本地处理后已去除棋盘格，原稿和原库存保留。App 精简设置、计算器、检测、记录、建议和鱼类管理中的重复说明，保留操作确认、输入校验和实际开关。两端回归、本地及云端 Android 构建通过，模拟器已保留数据覆盖升级；验证、素材映射与交付边界见 [工作记录](coordination/fish-catalog-and-app-copy-2026-09-08.md)。本次不包含 WEB-009。

## 本轮：Web 开缸日期与运行时长

首页鱼缸标题改为运行天数，海缸管理支持分别设置、修改或清空开缸日期；旧缸不补造日期，跨日及恢复前台自动更新。同步修复 Web 新建海缸保留旧检测结果的问题，并兼容旧体积文字。实测范围见 [本轮 Web 记录](coordination/tank-age-web-2026-09-08.md)；新功能登记为 [WEB-009](coordination/app-sync-backlog.md#web-009-开缸日期与运行时长)，等待用户确认网页版后明确要求同步 App。

## 上一批：网页版功能同步到 App

用户已授权并完成 WEB-005–008 与 PARITY-004 同步：补液周期与残液续配、KH 无计时查表、目标范围联动、任务延期与实际完成日期。269 项全量测试、静态分析和 Android debug 构建通过，模拟器已保留数据覆盖升级；云端结果及设备边界见 [本轮交付报告](coordination/app-sync-followup-2026-09-08.md)。平台差异统一在 [同步清单](coordination/app-sync-backlog.md) 维护。

旧数据通过 v11 迁移保留，备份继续支持旧版本。补液和普通任务共用日期展示与通知重排；未把网页演示数据导入 App，也未同步独立设计任务中的候选立绘。数据合同见 [技术设计](TECHNICAL_DESIGN.md)。

## 近期已完成工作

- 大图解码、PNG/ZIP 解压、长历史挂载及遗留提醒循环的资源保护：[内存修复实证](coordination/memory-audit-2026-09-08.md)。本次继续保留，并限制 App 通知队列仅处理当前与最新快照。
- Web CI 预览退出修复：[实证与云端结果](coordination/web-ci-preview-2026-09-08.md)。本地功能不等于公开网站已发布，公开网站最近记录仍为 [Sites 第 38 版](coordination/web-verification.md)。
- 此前拍照、趋势、记录与配方同步：[上一批 App 验收](coordination/app-sync-2026-09-08.md)；模拟器 CPU 与工程整理：[工作记录](coordination/android-cpu-and-repository-2026-09-08.md)。

## 开放项

- 多海缸核查：核心任务、记录/趋势和鱼档案按缸隔离；Web 新建海缸携带旧检测结果已修复，App 排队草稿保存串确认日期仍待修复。复现和共享配置见 [隔离核查](coordination/tank-isolation-audit-2026-09-08.md)。
- 拍照估算仍缺独立测试液批次、受控真值和充分设备/光照覆盖；NO3 编号 3 候选范围与人工标签不一致，未调整阈值。按 [拍照规范](IMAGE_ESTIMATION.md) 继续独立评估，不报告准确率或确定误差。
- Android 真机：真实相机/权限、不同厂商后台通知、真机内存峰值、低存储和备份分享恢复；模拟器不能替代。
- iOS：需 macOS/Xcode 构建及实际设备相机、通知验收。
- 发布：正式签名、应用标识、16 KB 原生库兼容性、隐私地址和商店资料等见 [发布清单](RELEASE_CHECKLIST.md)。
- Web 依赖：`vinext → image-size` 静态素材解析链仍待兼容处理，边界见 [依赖审计](coordination/project-optimization-followup-2026-09-08.md#剩余依赖与实际使用路径)。生产包审计为 0 不代表全部路径无风险。

Windows 路径/JBR 命令统一见 [App README](../app/README.md)。旧决策和结果保存在 [归档索引](archive/2026-09-08-before-workflow-cleanup/INDEX.md)；每次重要交付在 `coordination/` 保留实际命令、结果和未测边界，本页只链接证据。
