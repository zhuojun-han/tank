# 金毛巾立绘 · 2026-09-08

根据用户上传照片设计，沿用既有轻写实动画风格；中文名称按用户称呼，未独立核定学名。

- [用户参考](references/user-reference.png)：高圆侧扁鱼体、金黄底色、蓝黑弧形竖纹、深蓝后背鳍与黄色扇尾。
- 风格参考：项目现用 `app/assets/aquarium/clownfish.png`，只参考渲染质感。
- [设计稿](raw/golden-towel-v1.png)：内置 imagegen 生成；已查看完整朝右鱼形及条纹，不包含参考图中的手与容器。

## 提示摘要

按用户照片重建金毛巾完整健康单鱼，朝右侧视，高圆侧扁神仙鱼身形、小黄尖吻、小眼和蓝眼圈。金黄色头腹，体侧细电蓝和深蓝黑色弧形近竖纹分隔橙金条带，后背鳍深蓝圆区，圆润臀鳍有蓝橙嵌套曲纹，黄色扇尾和胸鳍。继承 A1 的轻写实动画 3D、自然嘴型和鱼皮质感，不复制小丑鱼白带。1536 × 1024 横图，鳍尾完整留边，要求实际 RGBA 透明背景，无手、容器、其他鱼、文字、棋盘格、阴影或光晕。

## 验证与状态

- Pillow 解码确认：RGB，1536 × 1024，无 Alpha。棋盘格仍是像素背景，不是透明成品；用户参考和原始生成稿已保存。
- 尚未交付经过实际鱼缸背景和显示比例验证的网站透明 PNG/WebP；当前为造型设计稿。
- 未替换既有立绘、修改生产代码或发布；按用户要求未向总调度发送消息。

## 2026-09-08 本地透明成品

用户已授权使用本地 Python 去除原图中烘焙的棋盘背景。本节更新上面的设计稿阶段状态；原始参考和 raw 图片保持不变，源文件 SHA-256 已核对。

- [处理脚本](../blueface/processing.py)：运行时传入 `golden-towel`；使用 Pillow 12.3.0、NumPy 2.3.5 和 OpenCV 4.12.0。色彩种子与 GrabCut 提取原鱼体，保留内部浅色部分；仅平滑透明边缘并处理半透明边缘底色，没有重画鱼形或花纹。
- [透明 PNG 源](app-ready-v1/golden-towel-transparent.png) 保留原图尺寸；[运行 PNG](app-ready-v1/golden-towel.png) 和 [WebP](app-ready-v1/golden-towel.webp) 保持纵横比，尺寸 683 × 480，鱼体四周约 4% 透明边距。WebP 使用 quality 90、method 6，大小 86460 字节。
- [处理参数与校验记录](app-ready-v1/processing-report.json) 包含源图哈希、Alpha 分布和成品哈希。Web `public/fish-species/golden-towel.webp` 与 App `assets/aquarium/golden-towel.webp` 均与此处 WebP 字节一致。
- 已查看[暗色、浅色、珊瑚背景预览](app-ready-v1/preview.png)，完整鳍尾与浅色鱼体保留，未见棋盘残留；WebP 实际解码具有非空鱼体和透明外边距。两端实际页面与设备运行验收由接入任务另行记录，此处不代表已发布。
