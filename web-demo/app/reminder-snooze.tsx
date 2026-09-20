"use client";
import { useState } from 'react';

export function ReminderSnooze({ onSnooze }: { onSnooze: (minutes: number) => void | Promise<void> }) {
  const [open, setOpen] = useState(false);
  const [amount, setAmount] = useState('1');
  const [unit, setUnit] = useState('60');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  async function save(minutes: number) {
    if (busy) return;
    setBusy(true); setError('');
    try { await onSnooze(minutes); setOpen(false); }
    catch (e) { setError((e as Error).message); }
    finally { setBusy(false); }
  }
  if (!open) return <button className="soft-button task-action-defer wide" onClick={() => setOpen(true)}>稍后提醒</button>;
  return <div className="snooze-options">
    <div className="task-actions">{[30, 60, 120].map(minutes => <button disabled={busy} key={minutes} className="soft-button task-action-defer" onClick={() => save(minutes)}>{minutes < 60 ? '30 分钟后' : `${minutes / 60} 小时后`}</button>)}</div>
    <form onSubmit={event => {
      event.preventDefault();
      const minutes = Number(amount) * Number(unit);
      if (!amount.trim() || !Number.isSafeInteger(minutes) || minutes < 1 || minutes > 10080) { setError('请输入 1 分钟至 7 天内的时间，精确到分钟。'); return; }
      void save(minutes);
    }}>
      <div className="field-row"><label>自定义时间<input aria-label="自定义提醒时间" type="number" step="any" value={amount} onChange={e => setAmount(e.target.value)} /></label><label>单位<select aria-label="提醒时间单位" value={unit} onChange={e => setUnit(e.target.value)}><option value="1">分钟</option><option value="60">小时</option></select></label></div>
      {error && <p role="alert">{error}</p>}
      <button disabled={busy} className="soft-button task-action-defer wide" type="submit">{busy ? '正在保存…' : '确认稍后提醒'}</button>
    </form>
  </div>;
}
