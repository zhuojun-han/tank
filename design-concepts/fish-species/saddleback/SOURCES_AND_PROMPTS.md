# 马鞍立绘 · 2026-09-08

根据用户所附照片设计马鞍海水鱼，沿用既有轻写实动画立绘风格。名称按用户称呼，不附加未经核定的学名。

- [用户参考](references/user-reference.png)：金黄背部与上身、蓝紫斑点、深蓝腹侧及后部马鞍形色块、浅蓝边线、黄色尾鳍。
- 风格参考：现用 `app/assets/aquarium/clownfish.png`，仅借用渲染质感，不复制小丑鱼花纹。
- [第一版设计稿](raw/saddleback-v1.png)：内置 imagegen 生成，完整朝右单鱼，已查看鱼形、斑点与鳍尾。

## 提示摘要

按照片重建高圆侧扁鱼体，金黄色背鳍与上部鱼身、密集蓝紫点渐变至深蓝腹侧和臀鳍，后部向背鳍延伸的深蓝马鞍形区域有浅青边线。灰蓝上脸、黄色下脸与下巴、浅青白颊线和头后短竖线；小眼与自然鱼嘴。黄色圆扇尾，深蓝胸腹鳍，细青色鳍缘与完整腹鳍尖。继承 A1 克制的轻写实动画 3D、细腻鱼皮，不夸张眼睛或笑脸。1536 × 1024，完整朝右侧视并留安全边距，要求真实 RGBA 透明、无背景、棋盘格、阴影、光晕、文字、水印或其他生物。

## 验证与边界

- Pillow 解码确认 RGB、1536 × 1024，无 Alpha，棋盘格是像素背景，尚非透明成品。
- 已保存参考和生成稿；网站透明 PNG/WebP 与实际鱼缸显示比例、边缘验证仍待完成。
- 未替换既有立绘、修改生产代码或发布；遵循用户要求未向总调度发送消息。

## 2026-09-08 本地透明成品

用户已授权使用本地 Python 去除原图中烘焙的棋盘背景。本节更新上面的设计稿阶段状态；原始参考和 raw 图片保持不变，源文件 SHA-256 已核对。

- [处理脚本](../blueface/processing.py)：运行时传入 `saddleback`；使用 Pillow 12.3.0、NumPy 2.3.5 和 OpenCV 4.12.0。色彩种子与 GrabCut 提取原鱼体，保留内部浅色部分；仅平滑透明边缘并处理半透明边缘底色，没有重画鱼形或花纹。
- [透明 PNG 源](app-ready-v1/saddleback-transparent.png) 保留原图尺寸；[运行 PNG](app-ready-v1/saddleback.png) 和 [WebP](app-ready-v1/saddleback.webp) 保持纵横比，尺寸 659 × 480，鱼体四周约 4% 透明边距。WebP 使用 quality 90、method 6，大小 83432 字节。
- [处理参数与校验记录](app-ready-v1/processing-report.json) 包含源图哈希、Alpha 分布和成品哈希。Web `public/fish-species/saddleback.webp` 与 App `assets/aquarium/saddleback.webp` 均与此处 WebP 字节一致。
- 已查看[暗色、浅色、珊瑚背景预览](app-ready-v1/preview.png)，完整鳍尾与浅色鱼体保留，未见棋盘残留；WebP 实际解码具有非空鱼体和透明外边距。两端实际页面与设备运行验收由接入任务另行记录，此处不代表已发布。
