# 黄狐狸立绘设计 · 2026-09-08

当前素材已按用户授权完成本地 Python 透明化并输出两端 WebP，见 [处理记录](PROCESSING.md)。以下保留设计稿阶段的提示与验证，不作为当前素材就绪状态。

用户要求：根据上传的黄狐狸海水鱼照片设计立绘。沿用本任务此前确认的已选立绘风格及网站使用目标。

## 素材

- [用户参考](references/user-reference.png)：黄色侧扁鱼身、黄色尾鳍、黑白面罩、突出长吻与背鳍棘。
- 风格参考：项目当前 `app/assets/aquarium/clownfish.png`，轻写实动画 3D、小眼、自然小嘴与细腻鱼皮。
- [第一版设计稿](raw/foxface-v1-checkerboard.png)：内置 imagegen 生成，1536 × 1024，已查看完整朝右造型与鳍尾。

## 实际生成提示

Create ONE yellow foxface marine fish sprite matching the user photo (image 1) in the existing selected fish illustration rendering style (image 2). Image 1 is anatomical and color reference only; image 2 is STYLE only, do not copy clownfish anatomy or markings or glow. Foxface features to preserve precisely: lemon-yellow tall laterally compressed body and yellow tail, prominent long narrow foxlike snout, black diagonal mask through small eye to snout, white face and chest region, black triangular throat/chest patch, yellow spiny dorsal fin. No added black flank spot. Complete single fish facing RIGHT in strict side profile, small realistic eye and small natural fish mouth, subtle fine skin, restrained light semi-realistic animated 3D shading consistent with image 2, no exaggerated smile, no toy look. Restore any cropped tail from the photo naturally, show all fins intact. True transparent RGBA background for website use, all pixels outside the fish silhouette alpha=0; solid body opaque. No background scene, NO surrounding glow or cast shadow, NO checkerboard pattern or white backdrop, no other fish, text or watermarks. Landscape composition 1536x1024, fit entire fish with about 7 percent empty margin on all sides. Clean production sprite.

## 验证与交付边界

- 本地 Pillow 解码确认：RGB，1536 × 1024，无 Alpha。生成工具未实现提示要求的透明背景，棋盘格仍是像素内容。
- 因此当前仅交付造型设计稿，不称为网站透明成品；尚需背景处理、透明 PNG/WebP 和实际鱼缸背景边缘/比例检查。
- 上一条蓝吊任务已询问是否允许本地脚本抠图，用户尚未明确答复；本轮没有据新鱼种请求推定已授权切换处理方式。
- 没有修改既有素材、App/Web 目录或发布；没有运行不相关业务测试。
