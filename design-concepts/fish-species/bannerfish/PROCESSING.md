# 关刀本地透明化 · 2026-09-08

用户已明确同意本地 Python 处理。[原稿](raw/bannerfish-v1.png) 与参考图保留不变；不重新生成或重绘鱼形、花纹。此前等待透明化的说明属于设计稿阶段。

- [处理脚本](../prepare-banner-violet-lamarck.py)：前景保护与 GrabCut 提取鱼体，人工轮廓约束保留白色鱼身、细长背鳍飘带，处理透明边缘后按比例裁切并留透明边距。
- 已输出 [透明 PNG](app-ready-v1/bannerfish.png)、[Web WebP](../../../web-demo/public/fish-species/bannerfish.webp) 与 [App WebP](../../../app/assets/aquarium/bannerfish.webp)。两端使用同一成品字节，WebP 保比例缩放至 768 × 480 以内，quality 90、method 6。
- 原图/成品哈希、最终尺寸与 Alpha 计数以 [素材清单](../added-fish-2026-09-08.json) 为准。此记录说明素材处理结果；实际页面、设备验收及发布状态由接入工作记录维护。
