# 皇后海水鱼立绘 · 2026-09-08

按用户所附照片设计皇后，沿用已选轻写实动画风格与网站素材目标。名称按用户称呼，形态以照片为准。

- [用户参考](references/user-reference.png)：深蓝鱼身、细密黄色横纹、眼部黑罩、浅灰蓝吻部、黄尾。
- 风格参考：现用 `app/assets/aquarium/clownfish.png`，只作为渲染质感依据。
- [第一版设计稿](raw/emperor-v1.png)：内置 imagegen 生成，已查看完整朝右鱼身、条纹与鳍尾。

## 提示摘要

高而侧扁椭圆鱼身，深蓝底色上密集细黄平行横纹，背侧与后鳍处自然弯曲；浅灰蓝短吻与自然小嘴，带蓝边的黑色眼罩、小眼，浅黄绿额部、深色鳃胸、黄扇尾，后背鳍轻微拖尖、圆臀鳍与细曲纹。继承 A1 克制的轻写实动画 3D、自然鱼皮和柔和立体光，不加小丑鱼白带、幼鱼环纹或其他鱼造型。单鱼完整朝右侧视、1536 × 1024、安全留边，要求真实 RGBA 透明、无棋盘格/光晕/阴影/篮子/场景/文字。

## 验证与边界

- Pillow 解码确认 RGB、1536 × 1024，无 Alpha，棋盘格是像素背景，尚非透明成品。用户照片和设计稿已保存。
- 当前为造型设计稿；网站透明 PNG/WebP、实际背景边缘及显示比例验证尚未完成。
- 未替换已有素材、修改生产代码或发布；按用户要求未向总调度发消息。

## 2026-09-08 本地透明成品

用户已授权使用本地 Python 去除原图中烘焙的棋盘背景。本节更新上面的设计稿阶段状态；原始参考和 raw 图片保持不变，源文件 SHA-256 已核对。

- [处理脚本](../blueface/processing.py)：运行时传入 `emperor`；使用 Pillow 12.3.0、NumPy 2.3.5 和 OpenCV 4.12.0。色彩种子与 GrabCut 提取原鱼体，保留内部浅色部分；仅平滑透明边缘并处理半透明边缘底色，没有重画鱼形或花纹。
- [透明 PNG 源](app-ready-v1/emperor-transparent.png) 保留原图尺寸；[运行 PNG](app-ready-v1/emperor.png) 和 [WebP](app-ready-v1/emperor.webp) 保持纵横比，尺寸 732 × 480，鱼体四周约 4% 透明边距。WebP 使用 quality 90、method 6，大小 97662 字节。
- [处理参数与校验记录](app-ready-v1/processing-report.json) 包含源图哈希、Alpha 分布和成品哈希。Web `public/fish-species/emperor.webp` 与 App `assets/aquarium/emperor.webp` 均与此处 WebP 字节一致。
- 已查看[暗色、浅色、珊瑚背景预览](app-ready-v1/preview.png)，完整鳍尾与浅色鱼体保留，未见棋盘残留；WebP 实际解码具有非空鱼体和透明外边距。两端实际页面与设备运行验收由接入任务另行记录，此处不代表已发布。
