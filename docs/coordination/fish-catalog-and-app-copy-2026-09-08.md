# 新鱼种接入与 App 界面精简

2026-09-08。用户授权将新生成鱼类加入 Web 和 App，并精简 App；随后明确同意本地 Python 处理背景。WEB-009 开缸日期不在本轮 App 同步范围。

## 交付内容

- 两端新增蓝吊、黄狐狸、拉马克、番茄小丑、关刀、皇后、马鞍、金毛巾、蓝面、紫罗兰、黄金吊，共 20 个内置选项。原 9 项 ID、原用户库存和自定义鱼保留，不自动往海缸添加新鱼。
- 新鱼沿用已有选择、数量、入缸日期、动画及按缸存储流程；App 枚举在原值后追加，持久化仍按名称，数据库及备份版本保持 v11。新增备份恢复回归覆盖全部 11 种鱼。
- App 设置、隐私说明、建议、检测入口、记录、任务、鱼类管理与计算器去除重复声明、空算法信息和渲染实现说明；长计算依据和原始算法信息折叠。建议中的静态空勾选图标改为圆点，没有纯声明 Checkbox 留在操作流程。
- 计划覆盖提示明确保留已完成历史；保留真实功能开关、保存/删除/恢复/覆盖确认、输入校验、权限错误反馈及配制、复测和停止条件。未修改计算公式或业务排期。

## 素材与可追溯性

11 张原图均保留原始哈希。10 张 RGB 原图的棋盘格已移除；拉马克保留原透明轮廓并清理极低 Alpha 外围残留。内置图像工具曾输出仍有棋盘格的尝试稿，该稿未接入；最终成品使用用户授权的本地脚本处理。

两端新增 WebP 逐一字节一致，单张最大 768×480，每端合计 **795,380 字节（约 777 KiB）**。检查完整鱼鳍、透明外沿与深色、浅色、蓝色、珊瑚背景，避免仅以存在 Alpha 判断抠图成功。逐项原稿、脚本、透明 PNG、运行素材、尺寸与 SHA-256 见 [素材清单](../../design-concepts/fish-species/added-fish-2026-09-08.json)；每鱼目录保留处理说明和参考，不重绘或覆盖原图。

处理环境为 Pillow 12.3.0、NumPy 2.3.5、OpenCV headless 4.12.0.88；后者位于忽略目录 `artifacts/fish-python-deps`，未加入 App/Web 运行依赖。

## 实际验证

| 范围 | 命令与结果 | 本地证据（忽略目录） |
| --- | --- | --- |
| Web 完整检查 | `npm run check`：类型、Lint、163 项单元、构建、2 项 SSR、21 项浏览器回归通过 | `web-demo/artifacts/fish-web-final-check.log` |
| 新鱼 Web 交互 | 20 项目录、11 张解码/透明通道、黄金吊数量及日期保存/刷新、换缸隔离、390px 边界与左右朝向通过 | `web-demo/tests/fish-catalog-browser.mjs`；`web-demo/artifacts/fish-catalog-*.png` |
| 用户当前开发网页 | `localhost:3000` 返回 200；20 项目录、11 图解码通过，无鱼图 404 和页面异常 | `web-demo/artifacts/fish-live-3000.json`、`fish-live-3000.png` |
| App 全量检查 | 150 文件格式检查通过；`dart analyze` 无问题；`flutter test` 270 项通过 | `app/build/fish-app-final-format.log`、`fish-app-final-analyze.log`、`fish-app-final-tests-rerun.log` |
| 设备发现的文案补充 | 鱼档案及首页精简后重新格式化，分析无问题，`flutter test test/widget_test.dart` 11 项通过 | `app/build/fish-app-device-followup-analyze.log`、`fish-app-device-followup-tests.log` |
| Android 构建与升级 | 补充文案后 `flutter build apk --debug --no-pub` 通过；`adb install -r` 成功，升级前后 SQLite 字节及全部表内容一致 | `app/build/fish-app-delivery-build.log`；`artifacts/fish-device/upgrade.json` |
| 项目维护检查 | `node tools/check-project.mjs` 通过，77 份文档、数据集及共享合同无失败 | 检查输出 |

Web 使用 Node 24.19.0、Edge 与受管生产预览 3100；浏览器检查均为隔离 context，不修改用户浏览器存储。App 使用项目指定 Flutter，Windows ASCII 路径按 [App README](../../app/README.md) 构建。

全量 App 回归首次因新测试返回模式按钮时滚动方向错误失败 1 项；修正脚本滚动方向后，保留所有存储断言，全量 270 项通过。后续只对设备发现的三处页面文案做上述定向复验，不将之前的全量结果写成修改后重新执行。

历史 `app/build/tank-isolation-review-date_test.dart` 诊断证据改名为 `.dart.txt`，字节哈希不变，避免旧临时脚本被当前静态分析重复计入；对应已知问题仍在 [隔离核查](tank-isolation-audit-2026-09-08.md) 保留，没有顺带修复。

## 设备与发布边界

Android 模拟器 `emulator-5554` 已实际启动本轮包（`com.lanjiao.lanjiao_water_quality/.MainActivity`）。已查看新鱼横向选择、黄金吊选中后的数量/日期表单并取消，核查精简后的设置与海盐计算器；未给真实库存写入演示鱼。补充文案后的最终安装也已成功，原 3 个海缸、5 条维护任务、7 条任务事件、1 条检测记录及其他表数据全部保留。

本地最终 APK 为 `app/build/app/outputs/flutter-apk/app-debug.apk`，SHA-256：`dd10cc06d365604b9fcc2ff159832377880b90e0b68b2f14a2fe673cbeb6d402`。

本轮不证明 Android 真机性能、真实相机与后台通知、iOS 构建或商店发布。平台待同步项统一见 [同步清单](app-sync-backlog.md)，源码推送也不代表公开网页已发布。
