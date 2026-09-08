# App 首页性能检查（2026-09-07）

用户反馈首页鱼动画及滚动有些卡顿。本轮检查源码、现有模拟器和图像资源，没有修改产品代码、安装包或模拟器配置。以下是优化候选，不是优化后效果承诺。

## 已确认的环境

- emulator-5554、当前 App PID 11208，安装包 flags 包含 DEBUGGABLE；仍为上轮 bugfix 的 debug 构建。
- AVD `D:/Android/avd/Lanjiao_API_36.avd/config.ini`：4 核、2G RAM、`hw.gpu.enabled=no`、`hw.gpu.mode=auto`。启动命令包含 `-avd Lanjiao_API_36 -no-snapshot-save`，未见 GPU 覆盖参数；guest `ro.hardware.egl=emulation`。SurfaceFlinger 查询未返回明确 GPU renderer，因此不能断言当前一定由软件渲染。GPU 加速配置是优先排查的环境因素。
- `dumpsys gfxinfo` 历史窗口记录 373 帧，其中 72 帧 janky（19.30%），P95 34ms。这是 Android View 层累计统计，包含之前交互，不是首页固定场景采样，也不能当作 Flutter 鱼动画的掉帧率。
- 进程快照 TOTAL PSS 394840 KB，TOTAL RSS 482752 KB；单点内存值不能证明泄漏。

## 优化顺序

1. **隔离鱼的逐帧布局与绘制。** `aquarium_card.dart:197` 每帧 setState，261 行起更新每条鱼的 Positioned left/top，重建鱼组件并触发布局。动画层未显式设置 RepaintBoundary，静态背景与动态鱼在同一 Stack。优先固定布局，以绘制变换移动鱼，复用静态图片组件，并实测静态背景与动态层的绘制隔离收益。当前最多显示24条动画鱼，条数增加时更值得比较。现有 ListView 自带子项绘制边界，不能据此声称鱼每帧必定重绘整个首页。
2. **缩小首页时钟刷新范围。** `home_page.dart:22` 订阅每秒时钟，`_HomeContent` 每次筛选全部记录、找最新值、生成近30天分组并排序；维护任务也依赖秒时钟。建议记录/目标变化时才重算统计，日期与到期提醒局部更新；不能简单删掉时钟而破坏跨日及稍后到期功能。
3. **避免趋势无变化时重绘。** `home_page.dart:559` 用 List 实例不等判断重绘，而上层会重新创建趋势数据。缓存派生数据或进行内容等价比较，确保数据、目标、主题变化仍会更新。原当前缸暂无记录，因此该项是有数据时的放大因素，不应认定为本次空数据首页卡顿主因。
4. **按显示尺寸解码鱼图片。** `fish_artwork_view.dart` Image.asset/Image.memory 未指定解码尺寸。首页鱼宽仅38–54逻辑像素，小丑鱼资源却为1536×1024（约2.04MB压缩文件、约6MiB RGBA像素）；其他内置鱼约642–768像素宽。建议结合设备像素比设定缓存解码尺寸，管理页使用适合其展示尺寸的缓存。Flutter已有图片缓存，不能描述为每帧都重新解码原图。

## 验证建议与边界

先在同一数据、同一设备上比较 profile/release 与当前 debug 的首页静止游动、上下滚动及返回首页，再在真实 Android 手机复核。获取 Flutter UI/raster 帧时间与超预算比例，分别比较2条及24条鱼；测试数据使用独立验收缸。优先验证动画层、首页局部刷新、图片解码三项，避免先减少鱼种、改变已确认的鱼样式或直接降帧。

本轮未采集 Flutter FrameTiming/profile timeline，未运行正式构建对照，未测得任一候选的加速幅度；尚不能把具体卡顿唯一归因于某一项。未触碰 WEB-001 待同步流程及现有用户数据。
