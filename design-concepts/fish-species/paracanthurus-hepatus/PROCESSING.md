# paracanthurus-hepatus 本地透明化 · 2026-09-08

用户已明确授权 Python 本地抠图。输入为 [原始 RGB 图片](raw/blue-tang-v1-checkerboard.png)，原图字节保留，不调用生成工具、不重绘鱼身或花纹。

- 处理：[processing.py](processing.py)。先按灰度棋盘与鱼身色差建立前景种子，填充封闭前景，再用 GrabCut 修正边界；边缘收缩 1 个原图像素以去除棋盘污染，之后按比例裁切、添加每侧约 4% 透明边距并缩放。
- 保留 [原尺寸透明 PNG](app-ready-v1/paracanthurus-hepatus-full-resolution.png) 和 [成品 PNG](app-ready-v1/paracanthurus-hepatus.png)；[成品 WebP](app-ready-v1/paracanthurus-hepatus.webp) 为 768 × 413，quality 90 / method 6。
- 原尺寸 PNG 的 RGB 与 raw 完全相同，只新增 alpha。成品 WebP alpha 与成品 PNG 逐像素相同；App 与 Web 资源字节一致。
- 已逐张检查暗底、浅底和项目珊瑚背景：鱼形、眼睛、花纹、背腹鳍、胸鳍和尾鳍保留，未见矩形棋盘背景或分离的背景残片。原图并无真实 alpha，处理不声称恢复物理透光率。
- 参数、alpha 计数、原图/成品 SHA-256 见 [metrics.json](app-ready-v1/metrics.json)。合成检查图位于根目录忽略的 `artifacts/fish-cutout-review/paracanthurus-hepatus-contact.png`。

复现使用带 Pillow、NumPy 的 Python，并在根 `artifacts/fish-python-deps` 提供 OpenCV；脚本自身定位目录。执行 `python design-concepts/fish-species/paracanthurus-hepatus/processing.py`。此步骤会重新写入该鱼种的两端 WebP；素材检查不等于业务页面或设备验收。
