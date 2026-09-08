import contract from '../../contracts/kh-titration.json' with { type: 'json' };

export const KH_TITRATION_TABLE_ID = contract.contract;

export type KhTitrationResult = {
  initialMl: number;
  remainingMl: number;
  usedMl: number;
  tableReadingMl: number;
  dkh: number;
  displayDkh: string;
  interpolated: boolean;
};

// Only absorb arithmetic round-off at a printed row; this is not a measurement tolerance.
const arithmeticEpsilon = Number.EPSILON * 8;

function displayDkh(value: number): string {
  const scale = 10 ** contract.displayFractionDigits;
  const scaled = value * scale;
  const rounded = Math.round(scaled + arithmeticEpsilon * Math.max(1, Math.abs(scaled)));
  return (rounded / scale).toFixed(contract.displayFractionDigits);
}

/** Uses the supplied syringe table, with no extrapolation beyond its printed rows. */
export function calculateKhTitration(initialMl: number, remainingMl: number): KhTitrationResult {
  if (!Number.isFinite(initialMl) || !Number.isFinite(remainingMl)) {
    throw new Error('请输入有效的初始容积和剩余溶剂体积。');
  }
  if (initialMl < 0 || initialMl > contract.referenceVolumeMl) {
    throw new Error('针筒初始容积须在 0–1 mL 之间。');
  }
  if (remainingMl < 0 || remainingMl > initialMl) {
    throw new Error('剩余溶剂须在 0 与初始容积之间。');
  }

  const usedMl = initialMl - remainingMl;
  const rawReadingMl = contract.referenceVolumeMl - usedMl;
  const rows = contract.rows;
  const exact = rows.find(row => Math.abs(row.readingMl - rawReadingMl) <= arithmeticEpsilon);
  // Snap only machine round-off at a row (e.g. 1 - (1 - 0.02)).
  const tableReadingMl = exact?.readingMl ?? rawReadingMl;
  if (tableReadingMl < rows[0].readingMl || tableReadingMl > rows[rows.length - 1].readingMl) {
    throw new Error('换算读数超出表格 0.00–0.98 mL 范围，无法查表，请核对输入。');
  }

  let dkh: number;
  if (exact) {
    dkh = exact.dkh;
  } else {
    const upperIndex = rows.findIndex(row => row.readingMl > tableReadingMl);
    const lower = rows[upperIndex - 1];
    const upper = rows[upperIndex];
    const fraction = (tableReadingMl - lower.readingMl) / (upper.readingMl - lower.readingMl);
    dkh = lower.dkh + fraction * (upper.dkh - lower.dkh);
  }

  return { initialMl, remainingMl, usedMl, tableReadingMl, dkh, displayDkh: displayDkh(dkh), interpolated: !exact };
}
