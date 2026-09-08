'use client';

import { useState } from 'react';
import { calculateMaintenance, type MaintenanceInput } from './maintenance-dosing';
import { currentMaintenanceCycle, cycleRemainingMl, localCycleDate, prepareMaintenanceCycle, type MaintenanceCycle, type MaintenanceChemical } from './maintenance-cycle';
import { STOCK_ML_PER_0_1_DKH_100L_OPTIONS, type AlkalinityPlan } from './alkalinity-calculator';

const fmt = (v: number) => v === 0 ? '0' : v < 0.001 ? v.toExponential(3) : Number(v.toFixed(3)).toString();

export function MaintenanceDosingPanel({ tankName, tankId, cycles, initialChemical = 'po4', previousKh, onClose, onSave }: { tankName: string; tankId: number; cycles: MaintenanceCycle[]; initialChemical?: MaintenanceChemical; previousKh?: AlkalinityPlan | null; onClose: () => void; onSave: (cycle: MaintenanceCycle) => void }) {
  const [chemical, setChemical] = useState<MaintenanceChemical>(initialChemical);
  const [residualChoice, setResidualChoice] = useState<'' | 'yes' | 'no'>('');
  const [residualMl, setResidualMl] = useState('');
  const [saveError, setSaveError] = useState('');
  const today = localCycleDate();
  const previous = currentMaintenanceCycle(cycles, tankId, chemical);
  const [input, setInput] = useState<MaintenanceInput>(currentMaintenanceCycle(cycles, tankId, initialChemical)?.input ?? { solutionMl: 500, waterL: previousKh?.netWaterVolumeL ?? 200, po4Rise: 0.02, khDrop: previousKh?.dailyDkhConsumption ?? 0.5, khStrength: previousKh?.stockMlPer0_1Dkh100L ?? 6, khPurity: previousKh?.purityPercent ?? 100, temperature: previousKh?.stockTemperatureC ?? 20, po4Flow: 1.4, khFlow: 1.4, po4Minutes: 1, khMinutes: 1, po4Unit: 'ml/s', khUnit: 'ml/s' });
  let result: ReturnType<typeof calculateMaintenance> | undefined;
  let error = '';
  // Hidden channel inputs must not block the selected reagent.
  const activeInput = chemical === 'po4'
    ? { ...input, khDrop: 0, khFlow: 1.4, khMinutes: 1, khUnit: 'ml/s' as const, khStrength: 6, khPurity: 100, temperature: 20 }
    : { ...input, po4Rise: 0, po4Flow: 1.4, po4Minutes: 1, po4Unit: 'ml/s' as const };
  try { result = calculateMaintenance(activeInput); } catch (e) { error = e instanceof Error ? e.message : '请核对输入。'; }
  const r = result?.[chemical];
  const stockMl = r?.stockMl;
  let recipe: MaintenanceCycle | undefined;
  let recipeError = '';
  try { recipe = prepareMaintenanceCycle(activeInput, chemical, tankId, today, previous,
    residualChoice === 'yes' ? (residualMl.trim() === '' ? NaN : Number(residualMl)) : 0); }
  catch (e) { if (!error && r?.dailyStockMl !== 0) recipeError = (e as Error).message; }
  const needsChoice = Boolean(previous && !residualChoice);
  function numberField(key: keyof MaintenanceInput, label: string, min = 0) {
    return <label className="field">{label}<input type="number" step="any" min={min} required value={Number.isNaN(input[key]) ? '' : input[key] ?? ''} onChange={e => setInput({ ...input, [key]: e.target.value === '' ? NaN : Number(e.target.value) })} /></label>;
  }
  return <div className="modal-backdrop"><section className="sheet calculator-sheet" role="dialog" aria-modal="true" aria-labelledby="maintenance-title">
    <div className="sheet-handle" /><div className="section-head"><div><p className="eyebrow">{tankName} · 滴定配方</p><h2 id="maintenance-title">稳定滴定</h2></div><button className="icon-button" aria-label="关闭滴定计算器" onClick={onClose}>×</button></div>
    <label className="field">选择指标<select value={chemical} onChange={e => { const next = e.target.value as MaintenanceChemical; setChemical(next); setResidualChoice(''); setResidualMl(''); setSaveError(''); const old = currentMaintenanceCycle(cycles, tankId, next); if (old) setInput(old.input); }}><option value="po4">PO₄ · 氯化镧</option><option value="kh">KH · 碳酸氢钠</option></select></label>
    <div className="field-row">{numberField('waterL', '净水量（L）', 0.1)}{chemical === 'po4' ? numberField('po4Rise', '每日 PO₄ 上升（mg/L）') : numberField('khDrop', '每日 KH 下降（dKH）')}</div>
    {chemical === 'kh' && <label className="field">KH 母液浓度<select value={input.khStrength} onChange={e => setInput({ ...input, khStrength: Number(e.target.value) })}>{STOCK_ML_PER_0_1_DKH_100L_OPTIONS.map(v => <option key={v} value={v}>{v} ml / 100 L 提升 0.1 dKH</option>)}</select></label>}
    <div className="field-row">{numberField(`${chemical}Flow`, '泵流速', 0.001)}<label className="field">单位<select value={input[`${chemical}Unit`]} onChange={e => setInput({ ...input, [`${chemical}Unit`]: e.target.value })}><option value="ml/s">ml/秒</option><option value="ml/min">ml/分钟</option></select></label></div>
    <div className="field-row">{numberField(`${chemical}Minutes`, '每天运行时间（分钟）', 0.000001)}{numberField('solutionMl', '滴定溶液体积（mL）', 0.001)}</div>
    {previous && <section className="notification-note" style={{ display: 'block' }}>
      <p>上次配液：{previous.startDate} · 预计 {previous.refillDate} 补液</p>
      <label className="field">上次滴定液还有残留吗？<select value={residualChoice} onChange={e => { const choice = e.target.value as '' | 'yes' | 'no'; setResidualChoice(choice); setSaveError(''); if (choice === 'yes') setResidualMl(fmt(cycleRemainingMl(previous, today))); }}><option value="">请选择</option><option value="yes">有，保留残液继续配制</option><option value="no">没有，或已倒掉残液</option></select></label>
      {residualChoice === 'yes' && <label className="field">保留残液体积（mL）<input type="number" min="0" step="any" value={residualMl} onChange={e => setResidualMl(e.target.value)} /><small>已填预计剩余量，请按实际残液调整。</small></label>}
    </section>}
    {r && stockMl !== undefined && <section className="notification-note" style={{ display: 'block' }} aria-live="polite">
      {r.dailyStockMl === 0 ? <strong>无需添加此药剂</strong> : needsChoice ? <p>选择残液情况后查看续配用量。</p> : recipe && <>
        {recipe.retainedMl > 0 && <p>保留原滴定液 <strong>{fmt(recipe.retainedMl)} ml</strong></p>}
        <h3 data-testid="maintenance-stock">{previous ? '再加' : '取'}母液 {fmt(recipe.addedStockMl)} ml</h3>
        <p>加 RO/DI 水 {fmt(recipe.addedWaterMl)} ml，定容至 <strong>{fmt(r.solutionMl)} ml</strong></p>
        <small>每日母液 {fmt(r.dailyStockMl)} ml · 每日泵出 {fmt(r.dailyLiquidMl)} ml</small>
        <p data-testid="maintenance-days">预计可用 <strong>{r.estimatedDays} 天</strong>（{r.actualDays.toPrecision(3)} 天）</p>
        <p>补液日期：{recipe.refillDate}</p>
      </>}
    </section>}
    {!needsChoice && recipeError && <p role="alert">{recipeError}</p>}
    {saveError && <p role="alert">{saveError}</p>}
    <button className="primary-button wide" disabled={!recipe || needsChoice} onClick={() => {
      if (!recipe || needsChoice) return;
      try { onSave({ ...recipe, input: { ...input }, id: Date.now() }); } catch (e) { setSaveError((e as Error).message); }
    }}>已配好，{previous ? '开始新周期' : '添加每日平衡'}</button>
    <p className="field-note">配好后确认；平时显示在已完成，最后一天提醒补液。</p>
    {error && <p className="disclaimer" role="alert">{error}</p>}
    <details><summary>母液设置</summary>
      {chemical === 'kh' ? <><div className="field-row">{numberField('khPurity', '母液原料纯度（%）', 0.1)}{numberField('temperature', '最低保存温度（°C）')}</div><p className="field-note">请填写实际最低保存温度，避免浓度过高析出。</p>{result && <p className="field-note">此母液每 500 ml 称取 {fmt(result.khConcentration / 2)} g NaHCO₃ 后定容。</p>}</> : <p className="field-note">氯化镧母液：99.9% LaCl₃·7H₂O，19.571329 g 定容至 500 ml；每 ml 理论处理 10 mg PO₄。每日上升默认 0.02 仅为示例，请填未补偿时实测变化。</p>}
      <p className="field-note">PO4与KH分别配制，使用独立泵管，不混合。</p>
      <p className="field-note">每日复测 PO₄、KH/pH；PO₄ ≤ 0.03 mg/L、浑浊或生物异常时停止氯化镧，并通过机械过滤/蛋分捕获沉淀。</p>
    </details>
  </section></div>;
}
