"use client";

import { useEffect, useRef, useState } from "react";
import { isAppVisible, observeAppVisibility } from "./app-visibility";
import { nativeRequest } from "./native-bridge";

type NotificationStatus = { permission: string; enabled: boolean };

export function NativeNotificationPanel({ onChanged }: { onChanged: () => void | Promise<void> }) {
  const [status, setStatus] = useState<NotificationStatus>();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const pending = useRef(false);
  const requestVersion = useRef(0);

  async function refresh() {
    const version = ++requestVersion.current;
    try {
      const next = await nativeRequest<NotificationStatus>("notifications.status");
      if (version === requestVersion.current) { setStatus(next); setError(""); }
      return next;
    } catch (reason) {
      if (version === requestVersion.current) setError((reason as Error).message);
      return undefined;
    }
  }

  useEffect(() => {
    // refresh only publishes state after the asynchronous native reply.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void refresh();
    const update = () => { if (isAppVisible()) void refresh(); };
    const removeVisibility = observeAppVisibility(update);
    return () => {
      // This ref is a request generation counter, not a captured DOM element.
      // eslint-disable-next-line react-hooks/exhaustive-deps
      requestVersion.current++;
      removeVisibility();
    };
  }, []);

  async function change(action: "permission" | "settings" | "toggle") {
    if (pending.current) return;
    pending.current = true; setBusy(true); setError("");
    try {
      if (action === "permission") {
        const result = await nativeRequest<{ permission: string }>("notifications.permission");
        if (result.permission === "granted") await nativeRequest("notifications.enabled", { enabled: true });
      } else if (action === "settings") {
        const result = await nativeRequest<{ status: string }>("notifications.settings");
        if (result.status !== "succeeded") throw new Error("暂时无法打开通知设置。");
      } else {
        await nativeRequest("notifications.enabled", { enabled: !status?.enabled });
      }
      await refresh();
      await onChanged();
    } catch (reason) { setError((reason as Error).message); }
    finally { pending.current = false; setBusy(false); }
  }

  const allowed = status?.permission === "granted";
  return <section aria-label="系统任务提醒" aria-busy={busy}>
    <div className="notification-note">
      <span aria-hidden="true">🔔</span>
      <div><strong>系统任务提醒</strong><p>{!status ? "正在读取通知状态…" : !allowed ? "尚未允许系统通知" : status.enabled ? "已开启" : "已关闭"}</p></div>
      {allowed && <button type="button" disabled={busy} className={`toggle-switch ${status.enabled ? "on" : ""}`} role="switch" aria-checked={status.enabled} aria-label="系统任务提醒" onClick={() => void change("toggle")}><i /></button>}
    </div>
    {status && !allowed && <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
      <button type="button" disabled={busy} className="primary-button" style={{ flex: 1 }} onClick={() => void change("permission")}>允许通知</button>
      <button type="button" disabled={busy} className="soft-button" style={{ flex: 1 }} onClick={() => void change("settings")}>系统设置</button>
    </div>}
    {error && <p className="calculation-error" role="alert">{error}</p>}
  </section>;
}
