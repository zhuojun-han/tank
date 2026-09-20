/** Browser records keep their numeric IDs; native database IDs remain opaque strings. */
export type EntityId = string | number;

export function isEntityId(value: unknown): value is EntityId {
  return typeof value === "string"
    ? value.length > 0 && value.trim() === value
    : typeof value === "number" && Number.isSafeInteger(value) && value > 0;
}

/** Deterministic tie-break only. An opaque ID does not imply creation order. */
export function compareEntityIds(left: EntityId, right: EntityId): number {
  if (typeof left === "number" && typeof right === "number") return left - right;
  if (typeof left !== typeof right) return typeof left === "number" ? -1 : 1;
  return left < right ? -1 : left > right ? 1 : 0;
}
