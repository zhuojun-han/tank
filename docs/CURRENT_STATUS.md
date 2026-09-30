# 当前状态

更新时间：2026-09-30。本页仅维护最新快照和开放项；历史测试结果不自动证明后续修改树通过。

## 最新仓库设置：GitHub 公开与 MIT 许可

2026-09-30 按用户要求将 [zhuojun-han/tank](https://github.com/zhuojun-han/tank) 从私有改为公开，并采用用户确认的 MIT 许可证。匿名访问及 GitHub MIT 识别已验证，图片和第三方素材保留各自许可边界；应用功能与安装包未变。[实际操作、检查及未测边界](coordination/open-source-2026-09-30.md)。

## 最新交付：独立 WebView 安卓 App

2026-09-20 上传后的 CI 失败已修复：Dart 格式及备份版本断言、浏览器测试同步，并修复检测/鱼档案保存反馈时序。修复源码的 Workspace、Flutter、Web 三个云端流程均通过；本机保留 APK 未重新生成。[原因、回归与实际云端结果](coordination/ci-repair-2026-09-20.md)。

2026-09-20 最新源码已提交并推送 GitHub；免构建静态/单元检查通过。推送后清理 19 个旧网页交付归档（约 73 MB），最新 WebView 与最新纯 Flutter APK、本地备份及证据保留。[同步、清理与验证边界](coordination/repository-publish-2026-09-20.md)。

2026-09-19 按授权完成三批清理：首批 4,731 个冗余/可重建文件（8.73 GB）；同日补充 C 盘测试与共享 Gradle 派生缓存、D 盘零散缓存，共 23,401 文件（6.08 GB）。第三批另清理已安装工具的下载归档和剩余派生缓存（5.72 GB）。均为逻辑大小。最新 WebView、旧 Flutter 包、源码、备份、素材及验证证据保留，结构与保护文件核对通过。[清理范围、结果与现存安装包](coordination/repository-cleanup-2026-09-19.md)。业务版本未变。

2026-09-12 鱼种支持多选/再次取消与批量加入，共用网页和模拟器 App 已更新；定向操作及取消数据不变通过。[本次记录](coordination/fish-multiselect-2026-09-12.md)。

2026-09-12 提前配液保留残液增加今日滴定选项，完成后扣旧配方当日用量；共用网页与模拟器 App 已更新。[定向验证与产物](coordination/residual-dosed-2026-09-12.md)。

2026-09-12 修复旧任务操作被拒后连带阻塞后续按钮的问题；错误分类及失败后读取恢复已更新，模拟器连续拒绝与查看安排通过，原任务未变。[本次记录](coordination/task-error-recovery-2026-09-12.md)。

2026-09-12 鱼类加入按钮增加按下反馈和短暂成功提示，共用网页及模拟器 App 已更新；加入草稿与取消保留档案定向验证通过。[本次记录](coordination/fish-add-feedback-2026-09-12.md)。

2026-09-12 按用户最新要求，KH/PO4理论结果的“配置滴定液”按钮已移到结果页底部、关闭操作上方；共用网页和模拟器App已更新，位置与泵设置入口定向检查通过。[本次安装包与记录](coordination/theory-button-bottom-2026-09-12.md)。仅调整布局，未重复业务回归。

2026-09-12 综合核查完成：修复首秒暂停误回准备页、到期提醒被刷新取消、鱼档案关闭草稿滞后；减少重复读库、通知重排、取色统计与动画初始化，限制新导出分享缓存。最终 APK 已保留数据安装，已切回原用户；3个海缸、37条检测、15个任务等原业务数据逐类一致。实际操作、精简测试、安装包及未测边界统一见 [本轮综合验收](coordination/full-app-audit-2026-09-12.md)。

新版共用网页 UI，支持离线、原生保存、拍照、任务、理论/稳定配液、备份与数据，旧 Flutter 入口与数据保留。初始交付及此前设备范围见 [WebView 实施记录](coordination/webview-implementation-2026-09-12.md)。用户暂不连接真机；普通直板安卓机与 Mate X6 的厂商通知、拍照、折叠/键盘及长时间运行仍待验收。本轮未新增云端 CI 或正式发布。

此前同日工作保留追溯入口：[理论滴定](coordination/theory-dosing-2026-09-12.md)、[配液入口与日期对齐](coordination/theory-entry-2026-09-12.md)、[残液选择与草稿](coordination/residual-select-2026-09-12.md)、[原生弹窗主题](coordination/dialog-theme-2026-09-12.md)、[删除/重置与计时](coordination/webview-data-management-2026-09-12.md)、[任务按钮配色](../artifacts/task-button-colors-2026-09-12/)、[任务卡片外框](../artifacts/task-card-frame-2026-09-12/)。这些包已由本轮最终包承接，历史证据保留。

## 保留的旧 Flutter 交付：App UI 与网页版对齐

已按用户授权对齐首页、检测、趋势、任务和设置的布局、配色及入口，并加入共用时钟、离屏/后台暂停的鱼缸气泡；全部鱼缸文字放在图外。本地 312 项测试、格式/静态检查、Android 构建及模拟器保留数据升级通过，升级前后全部数据库表内容一致，当前进程未发现异常。实际证据见 [实施记录](coordination/app-ui-implementation-2026-09-09.md)，设计依据及独立算法差异见 [UI 规划](coordination/app-ui-redesign-plan-2026-09-09.md)。本轮尚未上传或运行新的云端 CI。

## 前批交付：网页版与 App 剩余差异同步

已按用户授权补齐开缸日期/运行时长、可选水体积、新建后切缸及 KH 滴定一位小数显示，并修复检测复核异步输入隔离和旧草稿缓存。App schema/备份 v12 保留旧数据；本地及云端 293 项全量测试、静态分析、Android 构建与模拟器保留数据升级通过。代码 `54c55f1` 已上传，云端检查全部成功；实际证据见 [本轮记录](coordination/app-web-parity-2026-09-08.md)。

上述结论属于旧 Flutter 批次。WEB-010–014 在新版复用情况及平台验收边界见 [同步清单](coordination/app-sync-backlog.md)；浏览器和 App 仍分别本地存储，功能同步不代表云端数据同步或公开网站重新发布。

## 近期已完成工作

- 网页稍后提醒已接入预设及自定义时长并通过浏览器验证；新版已接入原生通知，系统投递证据和真机边界见本轮实施记录（WEB-014），旧 Flutter 未同步本次网页改动。

- 新版保留备份与数据，外观固定沿用共用网页、不提供主题选择；已纳入本轮实现，要求仍以 [开发方向](PROJECT_CONTEXT.md#后续-app-方向) 为准。

- 2026-09-09：网页任务“待处理”改为仅今日未完成发生项，未来周期任务保留在全部及日历；新增浏览器场景覆盖今日/未来/逾期、切换所选日和跨日进入待处理，任务延期与补液相关浏览器回归、TypeScript 检查通过。旧 Flutter 未改，差异 WEB-012。

- 网页首页 KH 低/正常/高建议改为用户确认的滴定文案，按当前缸目标判断；TypeScript 及独立浏览器六种场景验证通过（含 7/9 边界、部分重叠、自定义目标），未改旧 App。文案见 [建议规则](ADVICE_RULES.md#kh-默认范围依据)，差异登记为 WEB-010。
- 测试精简：删除 3 个 App 重复用例，SSR 合并渲染，滴定截图改为按需；受影响检查通过，见 [记录](coordination/test-pruning-2026-09-09.md)。未改产品源码或重建 App。
- 用户要求的模拟器测试指标清理及 36 条日期演示记录：[数据记录](coordination/app-demo-history-2026-09-09.md)。这些是本地演示数据，不是实际检测。
- 新增 11 种鱼、两端共 20 个内置选项及 App 界面精简：[鱼类与文案交付](coordination/fish-catalog-and-app-copy-2026-09-08.md)。原稿、用户库存与必要操作保留。
- 补液/残液、KH 无计时查表、目标联动与完成驱动排期：[前批 App 同步](coordination/app-sync-followup-2026-09-08.md)；开缸功能的原网页实证：[Web 交付](coordination/tank-age-web-2026-09-08.md)。
- 多海缸核心任务、记录/趋势及鱼档案隔离核查，及 Web 新建清理、App 异步草稿缺陷修复：[隔离记录](coordination/tank-isolation-audit-2026-09-08.md)。
- 大图解码、PNG/ZIP 解压、长历史挂载及遗留提醒循环的资源保护：[内存修复实证](coordination/memory-audit-2026-09-08.md)。本次继续保留，并限制 App 通知队列仅处理当前与最新快照。
- Web CI 预览退出修复：[实证与云端结果](coordination/web-ci-preview-2026-09-08.md)。本地功能不等于公开网站已发布，公开网站最近记录仍为 [Sites 第 38 版](coordination/web-verification.md)。
- 此前拍照、趋势、记录与配方同步：[上一批 App 验收](coordination/app-sync-2026-09-08.md)；模拟器 CPU 与工程整理：[工作记录](coordination/android-cpu-and-repository-2026-09-08.md)。

## 开放项

- 2026-09-19 iOS 已整理为可续接的目标模式计划（IOS-00–07）：用户有 iPhone、暂无 Mac，先用于个人真机测试；含执行依赖、完成证据与断点快照，目标尚未启动，实施与签名路径待落实。[iOS 目标模式执行计划](coordination/ios-webview-plan-2026-09-19.md)。

- 拍照估算仍缺独立测试液批次、受控真值和充分设备/光照覆盖；NO3 编号 3 候选范围与人工标签不一致，未调整阈值。按 [拍照规范](IMAGE_ESTIMATION.md) 继续独立评估，不报告准确率或确定误差。
- Android 真机：用户暂不连接设备；普通直板机和 Mate X6 的相机/权限、厂商后台通知、键盘/布局、折叠切换及低存储仍待验收，模拟器不能替代。
- iOS：需 macOS/Xcode 构建及实际设备相机、通知验收。
- 发布：正式签名、应用标识、16 KB 原生库兼容性、隐私地址和商店资料等见 [发布清单](RELEASE_CHECKLIST.md)。
- Web 依赖：`vinext → image-size` 静态素材解析链仍待兼容处理，边界见 [依赖审计](coordination/project-optimization-followup-2026-09-08.md#剩余依赖与实际使用路径)。生产包审计为 0 不代表全部路径无风险。

Windows 路径/JBR 命令统一见 [App README](../app/README.md)。旧决策和结果保存在 [归档索引](archive/2026-09-08-before-workflow-cleanup/INDEX.md)；每次重要交付在 `coordination/` 保留实际命令、结果和未测边界，本页只链接证据。
