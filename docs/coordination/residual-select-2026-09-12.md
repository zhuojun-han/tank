# 残液选择与 WebView 生命周期修复（2026-09-12）

## 原因与修复

模拟器点击残液下拉框，记录到 `paused → resumed` 仅相隔约 45 ms：宿主将系统对话框引起的 `inactive` 误当后台，暂停 WebView 并关闭弹窗。现仅在真正后台暂停，并去重恢复事件。状态含义依据 [Flutter 生命周期](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html)。

残液改为共用网页内的二选一，保留自动估算、手动编辑及确认保存边界。验证中另发现草稿会回放已锁定指标的切换事件，使理论输入变为默认值；已跳过禁用/只读字段，并恢复单选后才出现的残量输入，批量数值更新改用最新状态。

## 实际验证

- TypeScript、宿主定向 Dart 格式/分析、静态网页及 Android debug 构建通过。
- 复用 `maintenance-cycle-browser.mjs`：残液有/无、自动预填、编辑、取消、续配保存与日期边界通过。其他三个既有脚本仅随控件更新定位，未本轮重复执行；未跑全仓回归。
- 模拟器实际点击系统“单位”下拉框：保持打开，触摸选择成功，无错误暂停/恢复；按 Home 真正后台再回来，恰好一对暂停/恢复，手工残量保留。
- 页面重新加载：锁定的理论日用量仍为 0.1，修改的流速 1.6、运行 2.1 分钟、瓶体积 700、单选与手填残量 300 均恢复。取消验证输入后重新打开原计划，自动残量仍为 500 mL。
- 升级前后海缸、当前缸、检测、目标、任务、周期和鱼类数据相同；未保存测试配方。截图、生命周期日志及草稿结果在 `artifacts/residual-select-2026-09-12/`，本地数据快照不入 Git。

最终安装包：`artifacts/residual-select-2026-09-12/lanjiao-webview-residual-fix.apk`，已保留数据安装到 `emulator-5554` 的独立 `.webview` App。

SHA256：`D795BD1757E31EE981DAF93B62E6CEE94EB6A9A180BD20BB2AD2B69DF98DB712`。

本轮没有普通安卓机或 Mate X6 真机验收。前两次安装后的定向验证暴露草稿问题，因此修正后重新打包；最终结论不以中间包代替。

## 后续按钮顺序调整

按用户要求，KH/PO4 的“配置滴定液”放到预览提示下方。仅调整元素顺序，两个网页结果页截图检查通过，未重复业务回归。已保留数据更新模拟器；本次安装包为 `artifacts/theory-button-order-2026-09-12/lanjiao-webview.apk`，SHA256 `47735680C9F01AEF8EC2073664AED61FB922F9C48A8D32D950C666F4A8025236`。

## 残液选项字号修正

残液选项误继承通知图标的 20px 字号；现单独继承表单的 11px，标题降为 10px。390/320px 页面截图确认选项单行显示，点击区域仍至少 44px；未跑业务回归。已保留数据安装 `artifacts/residual-select-2026-09-12/lanjiao-webview-compact-labels.apk`，为本次最新包。
