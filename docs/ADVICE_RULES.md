# 水质维护建议规则

## 使用边界

- 建议以当前海缸保存的目标范围和最近一次人工确认记录为输入，目标可由用户修改。
- 所有建议仅用于辅助日常维护，不能替代规范复测、专业诊断或对缸内生物的持续观察。
- 常规维护建议不提供所谓通用安全药剂剂量；任何调整都应在复测和观察后决定下一步。网页版与 App 独立的氯化镧计算器固定采用纯度 `99.9%` 的七水合氯化镧和每 `1 mL` 母液理论处理 `10 mg PO4` 的强度，并按当前/目标 PO4、净水体积和 `0.1–0.5 mg/L` 单日计划范围给出理论取液量；它不属于常规建议，该范围不能称为通用安全剂量。
- 范围型检测结果若与目标区间部分重叠，只提示复测，不直接判定偏高或偏低。
- NO3、PO4、KH 以外的参数在没有已确认专用规则来源时，只提示复测或查阅可靠资料。KH 的下述专用文案当前仅在网页版实施，旧 Flutter App 尚未同步。

## NO3 规则

| 状态 | 建议 |
| --- | --- |
| 高于用户目标 | 复测；检查残饵或死亡生物；适量减少高营养饲料或单次投喂；清洁机械过滤并检查蛋分；采用适量分次换水，避免骤降。 |
| 低于用户目标 | 复测；避免继续加强换水或脱氮；检查碳源等营养盐去除措施；在生物可承受范围内小幅增加喂食；不盲目添加硝酸盐药剂。 |
| 位于用户目标内 | 保持当前喂食、过滤和维护节奏，按计划复测。 |

## PO4 规则

| 状态 | 建议 |
| --- | --- |
| 高于用户目标 | 复测；检查残饵、底砂和积污；适量减少高磷或荤性饲料及单次投喂；清洁机械过滤并分次换水；按产品说明检查或更换吸磷材料。 |
| 低于用户目标 | 使用适合低量程的方式复测；避免继续新增吸磷材料并酌情降低吸附强度；在生物可承受范围内小幅增加喂食；不盲目添加磷酸盐。 |
| 位于用户目标内 | 保持当前喂食、过滤和维护节奏，按计划复测。 |

## KH 默认范围依据

2026-09-09 用户确认的网页版首页文案如下。按当前缸有效目标上下限判断，默认 7–9 dKH；用户修改目标后随之改变，不硬编码 7 和 9。无记录、无完整目标及部分重叠保留原处理。“若连续记录稳定”是条件建议，本次不增加自动趋势稳定判断。

| 状态 | 标题与建议 |
| --- | --- |
| 低于用户目标 | **复测后检查滴定。**核对滴定液余量、泵流量和管路；确认补充不足后，再逐步调整。 |
| 位于用户目标内 | **在目标范围内。**若连续记录稳定，保持当前滴定量，固定时段复测。 |
| 高于用户目标 | **复测并核对是否投加过量。**检查配液浓度和泵设置；确认后降低 KH 补充量，并跟踪变化。 |

网页默认采用 `7–9 dKH` 是可调整的产品初始值，不是所有海缸的通用安全边界。[Fauna Marin BOLUS 官方指南，第 7 页](https://www.faunamarin.de/wp-content/uploads/2024/05/BOLUS_EN_How-To-Use_24_05_24__.pdf) 在该方法的启动条件中列出 `7–9 dKH`；[Salifert KH + pH Buffer 官方说明](https://salifert.com/sup/kp.htm) 列出约 `7.8–9 dKH`。这些厂家资料提供参考，不能据此推定不同系统或药剂均适用；预填行为统一见 [产品规格](MVP_SPEC.md#计算与通知)，界面不增加长声明或确认勾选。

## 规则依据

- Red Sea，Algae Management Program：说明 NO3/PO4 应依据实测值调节营养盐去除措施，NO3 过低时应降低去除剂量。  
  <https://redseafish.com/wp-content/uploads/2013/12/Algae-management-Program_Multilanguage-Manual_GB_DE_FR_SE_NL_SP_PT_JP_CH_17A.pdf>
- Tropic Marin，Nutrient Control：说明饲料会增加 PO4，并提供磷酸盐吸附材料作为降低 PO4 的手段。  
  <https://www.tropic-marin.com/naehrstoffkontrolle?lang=en>
- Tropic Marin，Plus-NP：说明极低营养系统可能出现营养限制，NO3/PO4 过低时不应继续盲目强化去除。  
  <https://calulator.tropic-marin.com/en/control/plus-np.html>
- Hanna Instruments，Saltwater Aquarium Water Parameters Guidelines：提供海水和珊瑚缸参数的一般参考，并明确实际目标会随系统类型变化。  
  <https://pages.hannainst.com/hubfs/006-finished-content/Aquarium/Saltwater-Aquarium-Water-Parameters-Guidelines-1.pdf>

## 氯化镧理论计算与本规则的关系

PO4 偏高规则仍优先建议复测、排查来源、清洁机械过滤、分次换水及按实际产品说明检查吸附材料，不会自动跳转成氯化镧投加处方。只有用户主动进入网页版或 App 的独立计算器，输入当前/精确目标 PO4、实际净水体积和 `0.1–0.5 mg/L` 内的单日最大计划降幅后，才会按固定纯度 `99.9%` 的七水合氯化镧和固定母液强度计算理论取液量；目标不得低于 `0.03 mg/L`。

计算器使用简化反应 `La3+ + PO4^3- -> LaPO4` 的 `1:1` 摩尔关系以及公开摩尔质量；它不测量海水中的实际效率，不允许用经验系数自动补偿。没有适用于纯氯化镧和所有海水缸的通用安全日降幅，因此 `0.1–0.5 mg/L` 只能标记为用户指定计划范围，不能重新命名为“安全剂量”。简化表单不设置机械过滤/蛋分确认门，但继续以文字提示捕获沉淀的必要性。

每天的任务只是复测清单：先测 PO4/KH、检查浑浊和生物状态；达到目标、参数异常或生物应激时停止剩余计划。具体公式、化学品操作要求、来源和证据边界见 [`LANTHANUM_CHLORIDE_CALCULATOR.md`](LANTHANUM_CHLORIDE_CALCULATOR.md)。

氯化镧计算的研究和厂家资料必须分开解读：

- [美国 EPA 的镧盐除磷报告](https://nepis.epa.gov/Exe/ZyPURL.cgi?Dockey=9101YSAA.TXT)、[PubChem 的 phosphate](https://pubchem.ncbi.nlm.nih.gov/compound/Phosphate-Ion)和[七水合氯化镧](https://pubchem.ncbi.nlm.nih.gov/compound/165791)用于化学计量、分子量和危害信息，不是海水缸剂量试验。
- [2020 年镧基除磷材料综述](https://pubmed.ncbi.nlm.nih.gov/32949878/)用于说明溶液化学、有机物和环境影响会改变实际表现，不提供海水缸通用日降幅。
- [Brightwell Aquatics Phosphat-E 厂家说明](https://brightwellaquatics.com/products/phosphat-et.php)支持在机械过滤/蛋分入口附近使用、捕获颗粒及避免过快变化的工作流；其用量只适用于该厂家专有液体产品，不能反推纯 `LaCl3` 或 `LaCl3·7H2O` 的安全上限。
