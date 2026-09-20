"use client";

import { useRef, useState, type FormEvent } from "react";
import { calculateKhTitration, type KhTitrationResult } from "./kh-titration";

export function KhTitrationPanel({ onRecord, onCancel, disabled = false }: {
  onRecord: (result: KhTitrationResult) => void | Promise<void>;
  onCancel: () => void;
  disabled?: boolean;
}) {
  const [initial, setInitial] = useState("1");
  const [remaining, setRemaining] = useState("");
  const [result, setResult] = useState<KhTitrationResult | null>(null);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const savePending = useRef(false);

  function changeInput(value: string, field: "initial" | "remaining") {
    if (field === "initial") setInitial(value);
    else setRemaining(value);
    setResult(null);
    setError("");
  }

  function calculate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setResult(null);
    try {
      if (!initial.trim() || !remaining.trim()) throw new Error("请填写初始容积和剩余溶剂。");
      setResult(calculateKhTitration(Number(initial), Number(remaining)));
      setError("");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "请检查输入读数。");
    }
  }

  async function record() {
    if (!result || disabled || savePending.current) return;
    savePending.current = true;
    setSaving(true);
    setError("");
    try { await onRecord(result); }
    catch (caught) { setError(caught instanceof Error ? caught.message : "暂时无法录入，请重试。"); }
    finally { savePending.current = false; setSaving(false); }
  }

  return <section className="panel kh-titration" data-testid="kh-titration">
    <h2>KH 滴定检测</h2>
    <p className="kh-titration-hint">填写滴定前后针筒的读数。</p>
    <form onSubmit={calculate} noValidate>
      <fieldset disabled={saving} style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}>
      <div className="field-row">
        <label>初始容积（mL）<input aria-label="初始容积（mL）" type="number" inputMode="decimal" min="0" max="1" step="any" value={initial} onChange={event => changeInput(event.target.value, "initial")} /></label>
        <label>剩余溶剂（mL）<input aria-label="剩余溶剂（mL）" type="number" inputMode="decimal" min="0" max="1" step="any" placeholder="滴定后的读数" value={remaining} onChange={event => changeInput(event.target.value, "remaining")} /></label>
      </div>
      {!result && <button className="primary-button wide" type="submit">计算 KH</button>}
      </fieldset>
    </form>
    {error && <p className="calculation-error" role="alert">{error}</p>}
    {result && <div className="kh-titration-result" aria-live="polite">
      <span>KH 结果</span>
      <output data-testid="kh-result">{result.displayDkh} <small>dKH</small></output>
      <p>查表读数：{Number(result.tableReadingMl.toFixed(6))} mL{result.interpolated ? " · 已插值" : ""}</p>
      <button className="primary-button wide" type="button" disabled={disabled || saving} onClick={record}>{saving ? "保存中…" : "确认并录入"}</button>
      <button className="text-button" type="button" disabled={saving} onClick={() => {
        setRemaining(""); setResult(null); setError(""); onCancel();
      }}>本次不记录</button>
    </div>}
  </section>;
}
