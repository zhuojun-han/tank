"use client";
import { type EntityId } from "./entity-id.ts";

import { useRef, useState, type FormEvent } from "react";
import type { Tank } from "./demo-state";
import { tankAgeDays, validateTankStartDate } from "./tank-age";
import { localCycleDate } from "./maintenance-cycle";
import { isNativeApp } from "./native-bridge";

export type TankManagerView = { mode: "list" } | { mode: "add" } | { mode: "edit"; tankId: EntityId };
export type TankDetails = { name: string; volume: string; startedOn?: string };

export function TankManagerSheet({ tanks, currentTankId, today, initialView, onSave, onDelete, onClose }: {
  tanks: Tank[];
  currentTankId: EntityId;
  today: string;
  initialView: TankManagerView;
  onSave: (details: TankDetails, editingId?: EntityId) => void | Promise<void>;
  onDelete?: (id: EntityId) => Promise<void>;
  onClose: () => void;
}) {
  const [view, setView] = useState(initialView);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState('');
  const deletePending = useRef(false);
  const title = view.mode === "list" ? "海缸管理" : view.mode === "add" ? "添加海缸" : "编辑海缸";
  const editing = view.mode === "edit" ? tanks.find(tank => tank.id === view.tankId) : undefined;
  return <div className="modal-backdrop" onMouseDown={() => { if (!saving) onClose(); }}>
    <section className="sheet tank-manager-sheet" role="dialog" aria-modal="true" aria-label={title} onMouseDown={event => event.stopPropagation()}>
      <div className="sheet-handle" />
      <div className="section-head"><h2>{title}</h2><button type="button" className="icon-button close-button" aria-label="关闭海缸管理" disabled={saving} onClick={onClose}>×</button></div>
      {deleting && editing ? <section role="alertdialog" aria-label="确认删除海缸">
        <h3>删除“{editing.name}”？</h3>
        <p>该海缸的检测、趋势、任务、配液周期和鱼类资料会一并删除，无法撤销。其他海缸不受影响。</p>
        {deleteError && <p role="alert">{deleteError}</p>}
        <div className="tank-form-actions">
          <button className="soft-button" disabled={saving} onClick={() => setDeleting(false)}>取消</button>
          <button className="primary-button" disabled={saving} onClick={async () => {
            if (!onDelete || deletePending.current) return;
            deletePending.current = true; setSaving(true); setDeleteError('');
            try { await onDelete(editing.id); }
            catch (error) { setDeleteError((error as Error).message); }
            finally { deletePending.current = false; setSaving(false); }
          }}>{saving ? '正在删除…' : '确认删除海缸'}</button>
        </div>
      </section> : view.mode === "list" ? <>
        <div className="tank-manager-list">{tanks.map(tank => {
          const age = tankAgeDays(tank.startedOn, today);
          return <div className="tank-manager-row" key={tank.id} data-testid={`tank-manager-row-${tank.id}`}>
            <div><strong>{tank.name}{tank.id === currentTankId && <small>当前海缸</small>}</strong>
              <p>{tank.volume && `${tank.volume} · `}{age === null ? "未设置开缸日期" : `已运行 ${age} 天`}</p>
              {tank.startedOn && <p>开缸日期 {tank.startedOn}</p>}
            </div>
            <button type="button" className="soft-button" onClick={() => setView({ mode: "edit", tankId: tank.id })}>编辑</button>
          </div>;
        })}</div>
        <button type="button" className="primary-button wide" onClick={() => setView({ mode: "add" })}>＋ 添加海缸</button>
      </> : view.mode === "edit" && !editing ? <p role="alert">此海缸已不存在，请重新打开。</p> :
        <TankDetailsForm key={editing?.id ?? "new"} tank={editing} today={today} onSave={onSave} onClose={onClose} saving={saving} setSaving={setSaving} />}
      {editing && onDelete && !deleting && <button type="button" className="danger-link" disabled={saving} onClick={() => setDeleting(true)}>删除此海缸</button>}
    </section>
  </div>;
}

function TankDetailsForm({ tank, today, onSave, onClose, saving, setSaving }: {
  tank?: Tank;
  today: string;
  onSave: (details: TankDetails, editingId?: EntityId) => void | Promise<void>;
  onClose: () => void;
  saving: boolean;
  setSaving: (saving: boolean) => void;
}) {
  const [error, setError] = useState("");
  const savePending = useRef(false);
  const initialVolume = tank?.volume.replace(/\s*L$/i, "").replace(/^--$/, "") ?? "";
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (savePending.current) return;
    const data = new FormData(event.currentTarget);
    try {
      const name = String(data.get("name") ?? "").trim();
      const volume = String(data.get("volume") ?? "").trim();
      const unchangedVolume = tank !== undefined && volume === initialVolume.trim();
      if (!name) throw new Error("请填写海缸名称。");
      if (!unchangedVolume && volume && (!Number.isFinite(Number(volume)) || Number(volume) <= 0)) throw new Error("水体体积须大于 0。");
      // Validate against the actual date again if the sheet stayed open overnight.
      const startedOn = validateTankStartDate(String(data.get("startedOn") ?? ""), localCycleDate());
      // Legacy volumes were free text; editing a date must not rewrite that value.
      savePending.current = true;
      setSaving(true);
      setError("");
      await onSave({ name, volume: isNativeApp() && !volume ? "" : unchangedVolume ? tank.volume : `${volume || "--"} L`, startedOn }, tank?.id);
      onClose();
    } catch (reason) { setError((reason as Error).message); }
    finally { savePending.current = false; setSaving(false); }
  }
  return <form onSubmit={submit}>
    <fieldset disabled={saving} style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}>
    <label className="field">海缸名称<input name="name" required maxLength={80} defaultValue={tank?.name ?? ""} placeholder="例如：书房珊瑚缸" /></label>
    <label className="field">水体体积（可选）<input name="volume" inputMode="decimal" defaultValue={initialVolume} placeholder="例如：120" /></label>
    <label className="field">开缸日期（可选）<input name="startedOn" type="date" min="0001-01-01" max={today} defaultValue={tank?.startedOn ?? ""} /></label>
    {error && <p className="calculation-error" role="alert">{error}</p>}
    <div className="tank-form-actions">
      <button type="button" className="soft-button" onClick={onClose}>取消</button>
      <button type="submit" className="primary-button">{saving ? "保存中…" : tank ? "保存海缸" : "创建海缸"}</button>
    </div>
    </fieldset>
  </form>;
}
