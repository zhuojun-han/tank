# App 缺陷修复验收（2026-09-07）

## 结果与范围

已修复 APP-AUDIT-001（海缸弹窗关闭时红屏，及同根因自定义参数弹窗）和 WEB-002（PO4/KH 计划忽略当前海缸用户目标范围）。静态分析无问题，188 项测试全部通过，debug APK 已保留数据覆盖安装到 API 36 模拟器，并完成下述实际界面验收。

本轮不修改网页、鱼缸 UI、趋势或 WEB-001“只计算不覆盖”差异；现有鱼动画刷新修复保留。不能据此宣称 App 与网页完全一致或所有设备无 bug。共享 README、PROJECT_CONTEXT、CURRENT_STATUS 由总调度统一更新。

## 修改内容

- `app/lib/features/settings/presentation/settings_entry_dialog.dart`：用独立 StatefulWidget 持有输入控制器，在弹窗 State 销毁时释放，避免 showDialog 返回后、反向关闭动画尚未结束时提前 dispose。
- `app/lib/features/settings/presentation/settings_page.dart`：海缸新增/编辑与自定义参数统一使用上述弹窗。
- `app/lib/features/maintenance/data/maintenance_repository.dart`：新增当前缸目标校验。PO4 不低于用户下限，KH 位于用户上下限之间；边界值允许。没有用户目标时沿用原公式限制，保留 PO4 固定 0.03 mg/L 等既有边界。校验在替换旧计划之前的同一事务内重新读取，拒绝时旧任务和事件不变。
- `app/lib/features/calculators/presentation/alkalinity_calculator_page.dart`、`lanthanum_calculator_page.dart`：计算及保存前校验，确认后防止换缸，保存事务再次读目标；失败清除不可保存的计算结果并显示原因。

## 自动验证

证据目录：`app/artifacts/bugfix-2026-09-07/`。

- 修复前 `regression-before.log`：8 项测试中 6 项失败，4 项明确复现控制器过早销毁（先出现 TextEditingController used after being disposed，再出现 _dependents.isEmpty）；另 2 项复现用户目标越界仍可写入。
- 新增 `settings_dialog_lifecycle_test.dart` 4 项：海缸/自定义参数保存及取消，覆盖聚焦输入框后关闭的反向动画。
- 新增 `plan_target_repository_test.dart` 4 项：上下限、包含边界、无目标与跨缸隔离，以及拒绝覆盖时原任务/事件完整保留。
- 新增 `plan_target_page_test.dart` 4 项：两种计算器越界提示、边界计算、取消无写入、确认覆盖期间目标变化仍拒绝并保留原记录。
- `analyze.log`：No issues found。`full-test.log`：188/188 All tests passed。`build.log`：debug 构建成功。格式检查 8 个文件，无剩余格式修改。

## 实际设备验收

设备 `Lanjiao_API_36` / `emulator-5554`。未擦除应用数据。

| 项目 | 实测结果 | PNG/XML 证据前缀 |
| --- | --- | --- |
| 添加海缸并保存 | 正常返回设置，新增缸存在，无红屏 | 01、02、03 |
| 添加海缸后取消 | 返回设置，未多建一缸 | 后续 17 列表仍为 3 缸 |
| PO4 当前值 0.23、目标 0.03，用户下限 0.05 | 显示下限错误，无计划结果 | 05 |
| PO4 目标等于下限 0.05 | 正常算出 2 天、3.60 mL | 07 |
| KH 用户范围 7–8、目标 9 | 显示上限错误 | 11 |
| KH 目标 6.5 | 显示下限错误 | 12 |
| KH 当前值 6、目标等于上限 8 | 正常算出 4 天、480 mL | 13 |
| 自定义参数保存 | 正常返回参数列表，AUDITFIX 存在，无红屏 | 15、16 |
| 恢复原当前缸 | 首页显示“我的海缸”，原有两条鱼 | 17、18 |

实际目标计算没有点击加入任务；保存期间目标变动及取消不覆盖由页面和事务回归测试验证。截图 06 是修改输入后尚未点击正确计算按钮的中间状态，最终边界结果以 07 为准。

保留验收数据：新增空缸 `Audit-dialog-20260907`；已有 `Audit-20260907` 的 KH 目标设为 7–8 dKH，增加自定义参数 AUDITFIX / AuditParameter / mg/L。原缸的鱼、目标、检测记录与任务未编辑；自定义参数作为全局参数定义可在其他缸参数设置中看到，但本次只在验收缸启用。原验收缸历史任务保留。

最终前台 Activity 为 `com.lanjiao.lanjiao_water_quality/.MainActivity`，PID 11208。`final-device.log` 未检出 E/flutter、FATAL EXCEPTION、_dependents 或 used after being disposed。此结论仅限本次进程已执行流程。

## 安装产物

- APK：`app/build/app/outputs/flutter-apk/app-debug.apk`
- 大小：201,513,287 字节
- SHA-256：`3947A2815F008A42491BBF4EDA46959C6D17BD96F81A23E0AE40C518BD2F68F6`
- ADB install -r 返回 Success；安装后已实际运行验收。

真实手机、iOS、相机及后台通知不在本轮验证范围。最终交付前重新核对 AGENTS.md；公共状态文档更新交由总调度完成。
