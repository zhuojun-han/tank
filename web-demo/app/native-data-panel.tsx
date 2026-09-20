"use client";
import { useState } from 'react';
import { nativeRequest } from './native-bridge';
import type { EntityId } from './entity-id';
import { resetNativeDraftCache, suspendNativeDraftWrites } from './native-drafts';
import { prepareNativeRestore, readNativeState } from './application-storage';
import { removeNativeData } from './native-data-actions';

type BackupSelection = { cancelled?: boolean; token?: string; createdAt?: string };
export function NativeDataPanel({ tankId }: { tankId?: EntityId }) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [selection, setSelection] = useState<BackupSelection>();
  const [resetOpen, setResetOpen] = useState(false);
  const [resetText, setResetText] = useState('');
  async function run(action: () => Promise<void>) {
    if (busy) return;
    setBusy(true); setMessage('');
    try { await action(); }
    catch (e) { setMessage((e as Error).message); }
    finally { setBusy(false); }
  }
  async function exportData(method: string) {
    const result = await nativeRequest<{ cancelled?: boolean; status?: string }>(method, { tankId });
    setMessage(result.cancelled || result.status === 'dismissed' ? '已取消' : result.status === 'unavailable' ? '文件已生成，系统分享暂不可用，请重试。' : '文件已交给系统分享面板。');
  }
  return <section className="native-data-panel" aria-busy={busy}>
    <h2>备份与数据</h2>
    <p className="field-note">完整备份用于迁移或恢复全部数据；CSV 仅导出当前海缸的检测表格。</p>
    <button disabled={busy} className="settings-row" onClick={() => run(() => exportData('backup.export'))}><strong>导出完整数据备份</strong><span>›</span></button>
    <button disabled={busy} className="settings-row" onClick={() => run(async () => {
      const result = await nativeRequest<BackupSelection>('backup.pick');
      if (!result.cancelled && result.token) setSelection(result);
    })}><strong>导入完整数据备份</strong><span>›</span></button>
    {tankId !== undefined && <button disabled={busy} className="settings-row" onClick={() => run(() => exportData('backup.csv'))}><strong>导出当前海缸 CSV</strong><span>›</span></button>}
    {selection && <div className="impact-panel"><strong>以备份替换本机数据？</strong><p>海缸、记录、任务和鱼类档案将被替换。导入前会保留一份本机备份。</p>
      <div className="task-actions"><button disabled={busy} className="soft-button" onClick={() => run(async () => { await nativeRequest('backup.cancel'); setSelection(undefined); })}>取消</button><button disabled={busy} className="primary-button" onClick={() => run(async () => {
        await prepareNativeRestore();
        await suspendNativeDraftWrites(true);
        try {
          await nativeRequest('backup.restore', { token: selection.token, confirmed: true });
          await resetNativeDraftCache();
          window.location.reload();
        } catch (e) {
          await readNativeState();
          await suspendNativeDraftWrites(false);
          throw e;
        }
      })}>确认导入</button></div></div>}
    {!selection && !resetOpen && <button disabled={busy} className="danger-link" onClick={() => { setResetOpen(true); setResetText(''); }}>重置所有数据</button>}
    {resetOpen && <section className="impact-panel" role="alertdialog" aria-label="确认重置所有数据">
      <h3>重置所有数据？</h3><p>清空本 App 的所有海缸、检测、任务、鱼类及设置，无法撤销。已导出到外部的备份和旧版 App 不受影响。</p>
      <label className="field">输入“重置”确认<input aria-label="输入重置确认" value={resetText} disabled={busy} onChange={e => setResetText(e.target.value)} autoComplete="off" /></label>
      <div className="task-actions"><button disabled={busy} className="soft-button" onClick={() => setResetOpen(false)}>取消</button><button disabled={busy || resetText !== '重置'} className="primary-button" onClick={() => run(() => removeNativeData())}>确认重置所有数据</button></div>
    </section>}
    {busy && <p role="status">正在处理…</p>}
    {message && <p role="status">{message}</p>}
  </section>;
}
