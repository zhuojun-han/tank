# 网页与 App 剩余差异同步

2026-09-08 开始，2026-09-09 验收。用户明确要求同步网页版与 App；本批以已完成网页行为为准，不导入网页演示数据或改变两端独立存储。代码 `54c55f1`、两地回归与 Android 构建、保留数据升级均已完成。

## 范围

- WEB-009：按缸设置、修改、清空开缸日期，首页运行天数、标题编辑入口、跨日和恢复刷新；旧缸不推造日期，鱼只编辑保留。
- PARITY-005：补齐 App 海缸资料可选水体积；不自动填入计算器，保持其独立输入。新建海缸保存后直接进入，创建、启用指标及切缸在同一事务完成；编辑其他海缸不切换当前缸。
- PARITY-006：KH 滴定单值的首页、趋势和记录列表保留一位小数，人工修改后使用当前确认值；普通记录格式不受影响。
- APP-ISSUE-002：复核草稿后台入队及“确认并保存”等待期间，快照所属会话与全部确认输入，避免切缸后日期、插值和备注串用。返回草稿时读取已保存新值；用户开始编辑后，迟到的旧保存不得覆盖当前输入。

App 数据库和 JSON 备份 v12 新增可空开缸日期、水体积；版本兼容与日历合同见 [技术设计](../TECHNICAL_DESIGN.md)。行为见 [产品规格](../MVP_SPEC.md)，对应差异状态统一维护在 [同步清单](app-sync-backlog.md)。

## 本地验证

- `dart format --output=none --set-exit-if-changed lib test tool`：158 个文件、0 改动；`flutter analyze` 无问题；`flutter test --concurrency=1`：**293 项全部通过**。日志分别为忽略目录 `app/build/parity-delivery-format-check.log`、`parity-delivery-analyze.log`、`parity-delivery-tests.log`。
- 覆盖旧库迁移/旧备份/合并/完整恢复、元数据冲突重映射、失败事务回滚、两缸保存与清空隔离、真实日期选择器取消与非法体积拒绝、跨日及恢复刷新、KH 0.0/8.0/人工修改显示、两条异步复核保存路径。页面回归还复现并修复了返回草稿持续显示旧缓存的问题，保护尚未通过校验的用户输入。
- 数据定义经 `build_runner` 生成，日志 `app/build/tank-age-codegen-final.log`。根 `node tools/check-project.mjs`：78 份文档、链接/共享合同/样本检查通过；样本完整性不代表算法精度。
- 本轮 Web 源码、合同及依赖无改动，以现有网页行为核对 App，不重复 Web 构建或导入演示数据。

## Android 升级

- `flutter build apk --debug --no-pub` 成功，日志 `app/build/parity-delivery-build.log`；产物 `app/build/app/outputs/flutter-apk/app-debug.apk`，SHA-256 `677f06854fc5cd2d679c212a68909b585ea6f0b17986874fd6fcb3b79f9b6cef`。
- 现有 `emulator-5554` / `com.lanjiao.lanjiao_water_quality` 经 `adb install -r` 升级并确认前台 Activity；未卸载、清空数据或改模拟器图形配置。
- 升级前后 SQLite 从 v11 到 v12，12 张原业务表逐表按全部原列对比，行数和内容哈希完全一致；3 缸新增日期/体积均为空。包括 5 个任务、7 个任务事件、1 条检测记录及原偏好/鱼档案；无虚构默认日期或示例数据。
- 实际操作首页日期入口，选择 2026-09-07、输入 120.5 L 后取消，重开仍为空；设置中非当前缸编辑加载正确缸名，取消保留当前缸；鱼档案入口保留原 2 条鱼记录和 20 个内置选项。保存/清空、跨日、恢复及失败回滚由真实页面与数据库回归覆盖，设备操作仅检查取消路径。
- 本轮 App PID 8668 日志没有 Flutter 异常、素材加载失败、布局溢出或致命异常；验收后停止 App。证据在忽略目录 `artifacts/parity-device/`（前后 SQLite、`result.json`、截图/XML、`logcat.txt`），辅助比对脚本 `artifacts/parity-device-data.py`。

## GitHub 与边界

代码已推送 `main`，远端提交一致。[工程检查](https://github.com/zhuojun-han/tank/actions/runs/34249238222) 和 [Flutter 检查](https://github.com/zhuojun-han/tank/actions/runs/34249238279) 均成功。已读取实际云端日志确认 293 项测试通过、生成数据库代码无差异及 Android debug APK 编译成功；本地保留 `artifacts/web-ci-job-102139087417.log`。

文档将当前状态和同步清单收敛为本轮结果，旧实证保留；同时纠正“退出计时就清理通知”的过宽表述，按既有实现区分普通返回保留草稿与明确放弃。该项仅修正文档，没有改变后台计时行为。

Web 源码本轮无改动，功能同步不代表浏览器与 App 数据云同步或公开站点重新发布。真机相机、厂商后台通知、iOS 及商店发布不在本轮通过范围。
