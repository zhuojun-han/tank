# 澜礁 Flutter App

Android/iOS 客户端，包含本地海缸、参数、鱼类档案、检测/趋势、NO3/PO4 辅助比色、任务/通知和维护计算器。当前交付及设备边界见 [当前状态](../docs/CURRENT_STATUS.md)，本轮网页新增功能是否允许同步见 [同步清单](../docs/coordination/app-sync-backlog.md)。

## 环境与仓库

工程工具约束以 pubspec、锁文件及 Android 配置为准。最近有记录的本机工具链是 Flutter 3.44.7 / Dart 3.12.2、Android SDK 36、build-tools 36.0.0、JBR 25；这是已使用的环境，不是必须永久锁死的升级要求。iOS 构建需要 macOS/Xcode。

App 与 Web 都由项目根仓库管理，CI 从根 `.github/workflows/` 运行；目录与共享合同约定见 [技术设计](../docs/TECHNICAL_DESIGN.md)。

## 运行与验证

在 `app/` 执行；首次准备或依赖变化时先 `flutter pub get`。

```powershell
flutter run
```

按 [开发与验收](../docs/DEVELOPMENT_PLAN.md) 选择范围，完整 App 检查可依次执行：

```powershell
dart format --output=none --set-exit-if-changed lib test tool
dart analyze
flutter test --concurrency=1
flutter build apk --debug
```

定向检查可指定实际测试文件。表结构变化时升级 schema 并补迁移/备份测试；涉及 Drift 表定义或生成注解时执行 `dart run build_runner build`，核对生成产物后再验证，不手改 `.g.dart` 替代生成。仅仓库查询逻辑变化无需提高 schema。

Debug APK 默认输出到 `build/app/outputs/flutter-apk/app-debug.apk`；构建成功不代表已安装，也不代表真机相机/通知通过。记录安装和升级验证时保留原数据，并检查对应设备前台和当前进程日志。卡顿与 CPU 排查按 [性能测量口径](../docs/DEVELOPMENT_PLAN.md#性能测量口径) 记录；正式发布见 [发布清单](../docs/RELEASE_CHECKLIST.md)。

设备截图使用 [device_sync_smoke.py](tool/device_sync_smoke.py)，需要 Python 3 和 Android SDK；`python` 未加入 PATH 时使用本机 Python 的完整路径调用。以下 SDK 和设备序号应替换为实际值：

```powershell
python tool/device_sync_smoke.py trends --sdk 'D:\Android\Sdk' --serial 'emulator-5554'
```

也可用 `--adb` 指定可执行文件，或通过 `ANDROID_SDK_ROOT` / `ANDROID_HOME` 提供 SDK；省略 `--serial` 时只接受恰好一个就绪设备。默认输出在 `build/sync-device/`，可用 `--output` 改目录。脚本只取截图和当前 UI 层级，不安装应用；动画页面可能无法获取层级，此时以实际截图为准。

## Windows 已验证的环境处理

模拟器图形加速按本机兼容性选择，并用实际 GLES/渲染器信息确认硬件渲染是否生效，不能只看启动参数；配置参考 [Android 官方说明](https://developer.android.com/studio/run/emulator-acceleration)。自行启动的无窗口（headless）验证结束后，将测试 App 退回 Android 桌面，或按需正常关闭自行启动的模拟器，用户明确要求保持前台时除外；宿主窗口隐藏或切后台不代表 Android App 已暂停。

中文路径下若 Dart 分析服务器出现 LSP JSON 截断，可从已确认指向本 `app/` 的 ASCII 目录联接 `D:\DevWorkspaces\lanjiao-app-workspace` 运行。使用前核对链接目标，避免在另一个旧副本验证；`dart analyze` 是本地已验证的分析入口。

若 Windows/JBR 报 `Unable to establish loopback connection`，本项目已成功使用该联接下的 `build/jtmp`，只对当前 PowerShell 进程设置临时目录：

```powershell
Set-Location -LiteralPath 'D:\DevWorkspaces\lanjiao-app-workspace'
New-Item -ItemType Directory -Force -Path 'build/jtmp' | Out-Null
$env:TEMP = 'D:\DevWorkspaces\lanjiao-app-workspace\build\jtmp'
$env:TMP = $env:TEMP
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=D:\DevWorkspaces\lanjiao-app-workspace\build\jtmp'
flutter build apk --debug
```

不要为此改全局环境或并发启动第二次构建；历史日志中的其他临时路径不是当前保证。相关 Java native access / flutter_timezone Kotlin 迁移警告在依赖升级时复核，不用删除缓存或修改全局 SDK 来掩盖源码错误。

数据库及备份版本只在 [技术设计](../docs/TECHNICAL_DESIGN.md) 维护，照片与旧版兼容见 [备份层](lib/data/backup/README.md)。真实样本、Android 真机权限/后台、低存储和 iOS 的未测边界仍需单独验证。
