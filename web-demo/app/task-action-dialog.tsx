"use client";

import { useState, type FormEvent } from "react";

type CommonProps = {
  title: string;
  today: string;
  onClose: () => void;
};

export type TaskActionDialogProps = CommonProps & (
  | { mode: "delay"; onConfirm: (days: number) => void }
  | { mode: "complete"; initialCompletedDate?: string; onConfirm: (date: string) => void }
);

export function TaskActionDialog(props: TaskActionDialogProps) {
  const [value, setValue] = useState(props.mode === "delay" ? "1" : props.initialCompletedDate ?? props.today);
  const [error, setError] = useState("");
  const delaying = props.mode === "delay";

  function confirm(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    try {
      if (props.mode === "delay") {
        const days = Number(value);
        if (!value.trim() || !Number.isSafeInteger(days) || days <= 0) {
          throw new Error("延迟天数须为大于 0 的整数。");
        }
        props.onConfirm(days);
      } else {
        const timestamp = Date.parse(`${value}T00:00:00Z`);
        if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || value < "0001-01-01"
          || !Number.isFinite(timestamp) || new Date(timestamp).toISOString().slice(0, 10) !== value) {
          throw new Error("请选择有效的实际完成日期。");
        }
        if (value > props.today) throw new Error("实际完成日期不能晚于今天。");
        props.onConfirm(value);
      }
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "操作未保存，请重试。");
    }
  }

  return <div className="modal-backdrop" onMouseDown={event => {
    if (event.target === event.currentTarget) props.onClose();
  }}>
    <form className="sheet" role="dialog" aria-modal="true" aria-label={props.title}
      data-testid="task-action-dialog" onSubmit={confirm} noValidate onKeyDown={event => {
        if (event.key === "Escape") { event.stopPropagation(); props.onClose(); }
      }}>
      <div className="sheet-handle" />
      <div className="section-head">
        <div><p className="eyebrow">{props.title}</p><h2>{delaying ? "延迟任务" : "完成任务"}</h2></div>
        <button className="icon-button" type="button" aria-label="关闭任务操作" onClick={props.onClose}>×</button>
      </div>
      <label className="field">{delaying ? "延迟天数" : "实际完成日期"}
        <input type={delaying ? "number" : "date"} required
          min={delaying ? 1 : "0001-01-01"} max={delaying ? Number.MAX_SAFE_INTEGER : props.today}
          step={delaying ? 1 : undefined} inputMode={delaying ? "numeric" : undefined}
          value={value} onChange={event => { setValue(event.target.value); setError(""); }} />
      </label>
      <p className="form-hint">{delaying ? "后续安排随之顺延" : "下次提醒按实际完成日期计算"}</p>
      {error && <p className="calculation-error" role="alert">{error}</p>}
      <button className="primary-button wide" type="submit">{delaying ? "确认延迟" : "确认完成"}</button>
      <button className="text-button wide" type="button" onClick={props.onClose}>取消</button>
    </form>
  </div>;
}
