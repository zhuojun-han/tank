import type { Target } from './demo-state.ts';
import { MIN_TARGET_PO4_MG_L } from './lanthanum-calculator.ts';

export const DEFAULT_KH_TARGET_RANGE = Object.freeze({ min: 7, max: 9 });

export function createParameterTarget(tankId: number, parameterId: string): Target {
  return {
    tankId,
    parameterId,
    ...(parameterId === 'kh' ? DEFAULT_KH_TARGET_RANGE : { min: null, max: null }),
  };
}

/** Fill only enabled KH targets with neither boundary set. */
export function initializeKhTargetRanges(targets: readonly Target[]): Target[] {
  return targets.map(target => target.parameterId === 'kh' && target.min === null && target.max === null
    ? { ...target, ...DEFAULT_KH_TARGET_RANGE }
    : target);
}

function decimalParts(value: number): { coefficient: bigint; exponent: number } {
  const [mantissa, exponent = '0'] = value.toString().split('e');
  const [integer, fraction = ''] = mantissa.split('.');
  return { coefficient: BigInt(integer + fraction), exponent: Number(exponent) - fraction.length };
}

/** Average the input decimals without rounding to a fixed number of places or significant figures. */
function decimalMidpoint(min: number, max: number): number {
  const low = decimalParts(min);
  const high = decimalParts(max);
  const exponent = Math.min(low.exponent, high.exponent);
  const sum = low.coefficient * BigInt(10) ** BigInt(low.exponent - exponent)
    + high.coefficient * BigInt(10) ** BigInt(high.exponent - exponent);
  // Dividing by two is multiplying by five and reducing the decimal exponent.
  return Number(`${sum * BigInt(5)}e${exponent - 1}`);
}

export function calculatorTargetDefault(
  parameterId: 'po4' | 'kh',
  target?: Pick<Target, 'min' | 'max'>,
): number | '' {
  if (!target || (target.min === null && target.max === null)) {
    return parameterId === 'kh'
      ? decimalMidpoint(DEFAULT_KH_TARGET_RANGE.min, DEFAULT_KH_TARGET_RANGE.max)
      : MIN_TARGET_PO4_MG_L;
  }
  const { min, max } = target;
  if (min === null || max === null || !Number.isFinite(min) || !Number.isFinite(max)
    || min < 0 || max < 0 || min > max) return '';
  return decimalMidpoint(min, max);
}
