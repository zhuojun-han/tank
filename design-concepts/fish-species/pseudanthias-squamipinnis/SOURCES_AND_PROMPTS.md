# 蓝眼海金鱼雄鱼立绘设计记录

## 范围

- 中文水族俗名：蓝眼海金鱼、蓝眼宝石、金花宝石（雄）
- 学名：丝鳍拟花鮨 `Pseudanthias squamipinnis`
- 素材：成年雄鱼右向侧视 App 立绘一张
- 物种外观依据：用户提供的实物照片
- 风格锚点：`app/assets/aquarium/clownfish.png`
- 生成方式：Codex 内置 ImageGen；透明背景使用经用户明确允许的本地确定性抠图
- 当前尚未加入网页版或 Flutter App 的内置鱼种目录。

## 物种核对

- 水族名录将“蓝眼海金鱼”对应为 `Pseudanthias squamipinnis`，并说明雄鱼第三背鳍棘明显延长：
  https://www.aquaml.com/s/Pseudanthias_squamipinnis.html
- Australian Museum 说明雄鱼第三背鳍棘显著延长、尾鳍呈月牙形且上下叶较长：
  https://australian.museum/learn/animals/fishes/orange-basslet-pseudanthias-squamipinnis/
- FishBase 记录其侧扁纺锤形体型，并指出不同地区颜色存在变化：
  https://www.fishbase.org/summary/pseudanthias-squamipinnis

## 最终生成约束

以实物图确定金黄色体侧、红紫色头背、淡色下颊、紫红胸鳍斑、红紫月牙尾、蓝紫臀鳍和单根显著延长的第三背鳍棘；以当前小丑鱼确定小眼、自然嘴型、轻写实动画 3D、湿润细鳞和柔和立体光照。完整鱼体朝右，四周为长尾叶和背鳍丝保留空间，无文字、水印、珊瑚、阴影或第二条鱼。

## App 素材与透明度

- `app-ready-v1/pseudanthias-squamipinnis-male.png`
  - `1536 × 1024`
  - 32 位 ARGB PNG
  - 四角 Alpha 均为 `0`
  - 含半透明抗锯齿边缘
  - SHA-256 `1356CFD980F476A7A173A64C00AEBB9002BA615EA3AEDD67FBA6BEE9996CACC9`
- `app-ready-v1/reef-app-preview.png`：合成到当前 App 珊瑚礁背景的视觉检查图，不是透明素材。

ImageGen 原图仍带烘焙棋盘格，因此复用 `design-concepts/fish-species/pseudanthias-bimaculatus/extract_checkerboard_alpha.py` 进行背景连通区域删除、最大鱼体保留、边缘内收柔化和去白边。最终 PNG 已检查真实透明像素、半透明边缘和珊瑚礁背景合成效果。
