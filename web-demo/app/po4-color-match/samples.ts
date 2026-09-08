import type { Rect } from '../color-match/color-analysis';
// Regions are manual geometric annotations, not fitted to concentration labels.
export const PO4_LEVELS = [0, .03, .1, .25, .5, 1, 3];
export const PO4_UPRIGHT = [3, 1, .5, .25, 0, .03, .1, .25];
export const PO4_SIDEWAYS = [0, 3, .03, 1, .1, .5, .25, .25];
export type Po4Sample = { id: string; label: string; columns: number; card: Rect; liquid: Rect };
export const PO4_SAMPLES: Po4Sample[] = [
  { id:'1', label:'0.25–0.5', columns:2, card:{x:.385,y:.187,w:.28,h:.61}, liquid:{x:.30,y:.48,w:.025,h:.025} },
  { id:'2', label:'0.1–0.25', columns:2, card:{x:.381,y:.165,w:.284,h:.608}, liquid:{x:.325,y:.345,w:.025,h:.025} },
  { id:'3', label:'3', columns:4, card:{x:.135,y:.274,w:.735,h:.326}, liquid:{x:.33,y:.70,w:.025,h:.03} },
  { id:'4', label:'0.1–0.25', columns:2, card:{x:.4075,y:.14,w:.30,h:.658}, liquid:{x:.34,y:.45,w:.028,h:.03} },
  { id:'5', label:'0.5–1', columns:2, card:{x:.395,y:.28,w:.18,h:.4}, liquid:{x:.59,y:.57,w:.018,h:.02} },
];
