import type { PhotoReview } from "./color-match/page";
import type { KhTitrationResult } from "./kh-titration";

export type Tank = { id: number; name: string; volume: string };
export type Parameter = { id: string; name: string; label: string; unit: string; builtIn: boolean; photoSupported: boolean };
export type Target = { tankId: number; parameterId: string; min: number | null; max: number | null };
export type RecordItem = { id: number; tankId: number; parameterId: string; low: number; high: number; date: string; note: string; edited?: boolean; interpolation?: number | null; photoEstimate?: PhotoReview; khTitration?: KhTitrationResult & { tableId: string } };
export type TaskItem = {
  id: number;
  tankId: number;
  title: string;
  cycle: string;
  due: string;
  state: "due" | "soon" | "done" | "snoozed" | "skipped";
  handledAt?: string;
  detail?: string;
  source?: "manual" | "lanthanum-plan" | "alkalinity-plan" | "maintenance-cycle";
  maintenanceCycleId?: number;
  planId?: string;
  dayIndex?: number;
  totalDays?: number;
  oneOff?: boolean;
  scheduledDate?: string;
  intervalDays?: number;
  completedDates?: string[];
  skippedDates?: string[];
  snoozedDates?: string[];
  snoozedUntil?: string;
  snoozedUntilByDate?: Record<string, string>;
  defaultCompletedBeforeDate?: string;
  reopenedDates?: string[];
  hiddenFromCalendar?: boolean;
  stoppedAfterDate?: string;
};
export type TimerDefaults = Record<string, number>;

export const defaultTanks: Tank[] = [
  { id: 1, name: "客厅主缸", volume: "200 L" },
  { id: 2, name: "小丑鱼缸", volume: "80 L" },
];

export const defaultParameters: Parameter[] = [
  { id: "no3", name: "NO3", label: "硝酸盐", unit: "mg/L", builtIn: true, photoSupported: true },
  { id: "po4", name: "PO4", label: "磷酸盐", unit: "mg/L", builtIn: true, photoSupported: true },
  { id: "kh", name: "KH", label: "碳酸盐硬度", unit: "dKH", builtIn: true, photoSupported: false },
  { id: "ca", name: "Ca", label: "钙", unit: "mg/L", builtIn: true, photoSupported: false },
  { id: "mg", name: "Mg", label: "镁", unit: "mg/L", builtIn: true, photoSupported: false },
  { id: "k", name: "K", label: "钾", unit: "mg/L", builtIn: true, photoSupported: false },
];

export const defaultTargets: Target[] = [
  { tankId: 1, parameterId: "no3", min: 2, max: 10 },
  { tankId: 1, parameterId: "po4", min: 0.03, max: 0.1 },
  { tankId: 2, parameterId: "no3", min: 1, max: 8 },
  { tankId: 2, parameterId: "po4", min: 0.02, max: 0.08 },
];

export const defaultRecords: RecordItem[] = [
  { id: 1, tankId: 1, parameterId: "no3", low: 10, high: 25, date: "8月3日 19:42", note: "益尔试剂，人工确认" },
  { id: 2, tankId: 1, parameterId: "po4", low: 0.08, high: 0.08, date: "7月30日 20:15", note: "手动录入" },
  { id: 3, tankId: 1, parameterId: "no3", low: 10, high: 10, date: "7月27日 18:20", note: "换水前" },
  { id: 4, tankId: 1, parameterId: "no3", low: 5, high: 5, date: "7月20日 19:10", note: "" },
];

export const defaultTasks: TaskItem[] = [
  { id: 1, tankId: 1, title: "更换滤棉", cycle: "每 3 天", due: "今天 09:00", state: "due" },
  { id: 2, tankId: 1, title: "更换 15% 海水", cycle: "每 2 周", due: "明天 09:00", state: "soon" },
  { id: 3, tankId: 1, title: "检查吸磷材料", cycle: "每 30 天", due: "8月12日 09:00", state: "soon" },
  { id: 4, tankId: 1, title: "清洁蛋白质分离器", cycle: "每 7 天", due: "下次 8月9日 09:00", state: "done", handledAt: "今天 08:36 完成" },
];
