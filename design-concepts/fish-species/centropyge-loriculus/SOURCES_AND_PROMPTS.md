# 火焰仙立绘设计记录

## 范围

- 中文水族俗名：火焰仙、火焰神仙
- 中文名：胄刺尻鱼
- 当前接受学名：`Centropyge loriculus`
- 常见旧写法/异名：`Centropyge loricula`
- 素材：典型健康成鱼右向侧视 App 立绘一张
- 物种外观依据：用户提供的实物照片
- 风格锚点：`app/assets/aquarium/clownfish.png`
- 生成方式：Codex 内置 ImageGen；透明背景使用此前经用户明确允许的本地确定性抠图
- 当前尚未加入网页版或 Flutter App 的内置鱼种目录。

## 物种与外观依据

- 水族名录将国内市场俗名“火焰仙”对应为胄刺尻鱼 `Centropyge loriculus`：
  https://www.aquaml.com/s/Centropyge_loriculus.html
- Australian Museum 使用接受名 `Centropyge loriculus`，并描述其为明亮红橙色、体侧带深色竖纹，背鳍和臀鳍后部具有蓝黑条纹：
  https://australian.museum/learn/animals/fishes/flame-angelfish-centropyge-loriculus/
- USGS 的识别资料描述：橙红鱼体中央偏橙黄，胸鳍后有纵向黑斑、其后通常有五条黑色竖纹；背鳍和臀鳍后部为黑色并带蓝紫色横纹，尾鳍为浅橙黄色鳍条和透明鳍膜：
  https://nas.er.usgs.gov/queries/FactSheet.aspx?speciesID=2591
- FishBase 将 `Centropyge loricula` 列为 `Centropyge loriculus` 的异名：
  https://fishbase.se/Nomenclature/7814

用户实物照片保存在 `references/user-reference.png`，只作为外形、体色和花纹参考，不直接作为 App 素材发布。

## 最终生成约束

以用户照片确定侧扁而较高的椭圆神仙鱼体型、短吻、自然小嘴、连续背鳍和臀鳍、约五条不规则黑色竖纹，以及背鳍和臀鳍后段的黑底蓝紫横纹；补全原照片中裁切的半透明橙黄色尾鳍。以当前小丑鱼确定小眼、自然表情、轻写实动画 3D、湿润细鳞和柔和立体光照，但不复制小丑鱼体型、白带或黑边。完整鱼体朝右，四周保留安全边距，无文字、水印、背景、阴影或第二条鱼。

## App 素材与透明度

- `app-ready-v1/centropyge-loriculus.png`
  - `1536 × 1024`
  - 32 位 RGBA PNG
  - 四角 Alpha 均为 `0`
  - 透明像素 `856,809`，半透明抗锯齿像素 `23,325`，不透明像素 `692,730`
  - Alpha 边界框 `(89, 101)–(1402, 912)`，尾鳍、背鳍和臀鳍均未裁切
  - SHA-256 `F20A689FF7F470D530D58EB8CD13F3C012AD06FEDC6624FD89EF121314053478`
- `app-ready-v1/reef-app-preview.png`：合成到当前 App 珊瑚礁背景的视觉检查图，不是透明素材。

ImageGen 原图带烘焙棋盘格，因此复用 `design-concepts/fish-species/pseudanthias-bimaculatus/extract_checkerboard_alpha.py` 删除与边界连通的近白中性背景、保留鱼体连通区域、生成真实 Alpha，并对边缘做内收、柔化和去白边。最终 PNG 已检查真实透明像素、半透明边缘和珊瑚礁背景合成效果。
