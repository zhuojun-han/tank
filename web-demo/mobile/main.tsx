import { createRoot } from 'react-dom/client';
import { useEffect, useState, type FormEvent } from 'react';
import Home from '../app/page';
import { NativeDataPanel } from '../app/native-data-panel';
import { readNativeState, saveApplicationState } from '../app/application-storage';
import { isNativeApp } from '../app/native-bridge';
import type { DemoState } from '../app/demo-storage';
import { validateTankStartDate } from '../app/tank-age';
import { localCycleDate } from '../app/maintenance-cycle';
import '../app/globals.css';
import './styles.css';

function RemovalNotice() {
  const [message, setMessage] = useState(() => sessionStorage.getItem('lanjiao-removal-warning'));
  if (!message) return null;
  return <div role="status">{message}<button onClick={() => { sessionStorage.removeItem('lanjiao-removal-warning'); setMessage(null); }}>知道了</button></div>;
}

function MobileApp() {
  const [state, setState] = useState<DemoState>();
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(true);
  const [saving, setSaving] = useState(false);
  async function load() {
    setBusy(true); setError('');
    try { setState(await readNativeState()); }
    catch (e) { setError((e as Error).message); }
    finally { setBusy(false); }
  }
  useEffect(() => {
    const startup = window.setTimeout(() => { void load(); }, 0);
    const listener = (e: Event) => setSaving((e as CustomEvent<boolean>).detail);
    window.addEventListener('lanjiao:storage-busy', listener);
    return () => { window.clearTimeout(startup); window.removeEventListener('lanjiao:storage-busy', listener); };
  }, []);
  async function create(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (!state || busy) return;
    const form = new FormData(event.currentTarget);
    setBusy(true); setError('');
    try {
      const name = String(form.get('name')).trim();
      const volume = String(form.get('volume')).trim();
      const startedOn = validateTankStartDate(String(form.get('startedOn') || ''), localCycleDate());
      if (!name || name.length > 80) throw new Error('请填写海缸名称（最多 80 字）。');
      if (volume && (!Number.isFinite(Number(volume)) || Number(volume) <= 0)) throw new Error('水体体积须大于 0。');
      const id = crypto.randomUUID();
      const next = { ...state, tankId: id, tanks: [{ id, name, volume: volume ? `${volume} L` : '', startedOn }], targets: [
        { tankId: id, parameterId: 'no3', min: 2, max: 10 },
        { tankId: id, parameterId: 'po4', min: .03, max: .1 },
        { tankId: id, parameterId: 'kh', min: 7, max: 9 },
      ] };
      const result = await saveApplicationState(next);
      if (!result.ok) throw new Error(result.message);
      setState(await readNativeState());
    } catch (e) { setError((e as Error).message); }
    finally { setBusy(false); }
  }
  if (state?.tanks.length) return <><RemovalNotice /><Home />{saving && <div className="native-save-overlay" role="status">正在保存…</div>}</>;
  return <main className="native-onboarding"><p className="eyebrow">澜礁海缸助手</p><h1>{state ? '创建你的海缸' : '读取本机数据'}</h1>
    <RemovalNotice />{error && <p role="alert">{error}</p>}
    {!state ? <button className="primary-button wide" disabled={busy} onClick={load}>{busy ? '正在连接…' : '重新读取'}</button> :
      <form onSubmit={create}><label className="field">海缸名称<input name="name" required maxLength={80} placeholder="例如：我的海缸" /></label>
        <label className="field">水体体积（L，可选）<input name="volume" type="number" step="any" /></label>
        <label className="field">开缸日期（可选）<input name="startedOn" type="date" /></label>
        <button className="primary-button wide" disabled={busy} type="submit">{busy ? '正在保存…' : '创建海缸'}</button>
      </form>}
    {state && <NativeDataPanel />}
  </main>;
}

const root = createRoot(document.getElementById('root')!);
root.render(isNativeApp() ? <MobileApp /> : <main className="native-onboarding"><h1>澜礁</h1><p>请在安卓 App 中打开。</p></main>);
