# WebView 数据管理与计时修复（2026-09-12）

## 范围

新增新版 App 删除海缸、重置数据及必要确认；行为见 [产品合同](../MVP_SPEC.md#新版-app-数据管理)。浏览器与旧 Flutter 未新增入口，旧 APK 与外部备份保留。

修复 NO3 未开始会话（preparation、300 秒、空截止时间）被恢复为 0 秒的问题；共用恢复逻辑同样适用于 PO4。真实运行/暂停会话继续按原状态恢复。

## 实际验证

- 新增两个原生事务测试通过：删除的确认与版本校验、跨缸隔离、注入失败回滚、重启持久化、删除最后一个海缸；重置失败回滚、业务表清空与内置指标恢复。
- Dart 格式及相关静态分析、Web TypeScript 检查、静态构建、Android debug 构建通过。
- 模拟器创建临时海缸和检测记录，取消删除后数据保留，确认删除后原有海缸/记录/任务/鱼类/周期/目标数组与测试前一致。重置输入确认和取消实测通过，未实际清空用户数据库。
- 保留数据升级后读取同一 preparation 会话，实际检测页面显示 05:00 和“开始计时”，截图已检查。最初自动化定位因按钮含图标超时，改用文字匹配后通过，并非产品故障。
- 本次未重跑完整回归；未重新实测运行/暂停/完成各阶段的通知投递。普通手机与 Mate X6 真机仍待验收。

## 产物

本地目录 `artifacts/webview-data-management-2026-09-12/`：`device-check.mjs`、`delete-confirm.png`、`reset-confirm.png`、`timer-check.mjs`、`timer-fixed.png` 和更新 APK `lanjiao-webview-data-management.apk`。该目录包含本地验证数据，不纳入 Git。

APK 包名已核对为 `com.lanjiao.lanjiao_water_quality.webview`，已安装到当前模拟器；SHA256：`74AC14C71C12CA3D2A9A2B65472C003E3E26B694D27B8DD697063A1BE4CC8D91`。原交付安装包未覆盖。
