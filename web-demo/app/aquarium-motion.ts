export type FishDirection = -1 | 1;

export type FishMotionBounds = {
  width: number;
  height: number;
};

export type FishMotionState = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  direction: FishDirection;
  phase: number;
  speed: number;
  seed: number;
  randomState: number;
  secondsSinceTurn: number;
  nextRandomTurnAfter: number;
};

export type FishMotionLimits = {
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
};

const TAU = Math.PI * 2;
const EDGE_PADDING = 4;
const MIN_RANDOM_TURN_SECONDS = 8;
const RANDOM_TURN_WINDOW_SECONDS = 8;

function clamp(value: number, minimum: number, maximum: number) {
  return Math.min(Math.max(value, minimum), maximum);
}

function approach(value: number, target: number, maximumChange: number) {
  if (value < target) return Math.min(value + maximumChange, target);
  return Math.max(value - maximumChange, target);
}

function nextRandom(state: FishMotionState) {
  let value = state.randomState || 0x9e3779b9;
  value ^= value << 13;
  value ^= value >>> 17;
  value ^= value << 5;
  state.randomState = value >>> 0;
  return state.randomState / 0x100000000;
}

function scheduleRandomTurn(state: FishMotionState) {
  state.secondsSinceTurn = 0;
  state.nextRandomTurnAfter = MIN_RANDOM_TURN_SECONDS + nextRandom(state) * RANDOM_TURN_WINDOW_SECONDS;
}

export function fishSeed(value: string) {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  hash ^= hash >>> 16;
  hash = Math.imul(hash, 0x85ebca6b);
  hash ^= hash >>> 13;
  hash = Math.imul(hash, 0xc2b2ae35);
  hash ^= hash >>> 16;
  return hash >>> 0;
}

export function fishMotionLimits(
  bounds: FishMotionBounds,
  fishWidth: number,
): FishMotionLimits {
  const safeWidth = Math.max(1, bounds.width);
  const safeHeight = Math.max(1, bounds.height);
  const halfWidth = Math.max(1, fishWidth / 2);
  const halfHeight = Math.max(1, fishWidth * (25 / 88));
  const minX = Math.min(safeWidth / 2, halfWidth + EDGE_PADDING);
  const minY = Math.min(safeHeight / 2, halfHeight + EDGE_PADDING);

  return {
    minX,
    maxX: Math.max(minX, safeWidth - halfWidth - EDGE_PADDING),
    minY,
    maxY: Math.max(minY, safeHeight - halfHeight - EDGE_PADDING),
  };
}

export function createFishMotion(
  key: string,
  bounds: FishMotionBounds,
  fishWidth: number,
): FishMotionState {
  const seed = fishSeed(key);
  const limits = fishMotionLimits(bounds, fishWidth);
  const horizontalRatio = 0.16 + ((seed % 680) / 1000);
  const verticalRatio = 0.1 + (((seed >>> 9) % 800) / 1000);
  const direction: FishDirection = (seed & 1) === 0 ? 1 : -1;
  const speed = 20 + ((seed >>> 3) % 9);

  const state: FishMotionState = {
    x: limits.minX + (limits.maxX - limits.minX) * horizontalRatio,
    y: limits.minY + (limits.maxY - limits.minY) * verticalRatio,
    vx: direction * speed,
    vy: (((seed >>> 13) % 9) - 4) * 0.7,
    direction,
    phase: ((seed % 1000) / 1000) * TAU,
    speed,
    seed,
    randomState: seed || 1,
    secondsSinceTurn: 0,
    nextRandomTurnAfter: MIN_RANDOM_TURN_SECONDS,
  };
  scheduleRandomTurn(state);
  state.secondsSinceTurn = ((seed >>> 17) % 45) / 10;
  return state;
}

export function stepFishMotion(
  state: FishMotionState,
  elapsedSeconds: number,
  bounds: FishMotionBounds,
  fishWidth: number,
) {
  const delta = clamp(Number.isFinite(elapsedSeconds) ? elapsedSeconds : 0, 0, 0.05);
  const limits = fishMotionLimits(bounds, fishWidth);
  const horizontalTurnZone = Math.min(32, Math.max(18, bounds.width * 0.08));
  const verticalTurnZone = Math.min(30, Math.max(18, bounds.height * 0.12));
  let boundaryTurned = false;

  if (state.direction > 0 && state.x >= limits.maxX - horizontalTurnZone) {
    state.direction = -1;
    boundaryTurned = true;
  } else if (state.direction < 0 && state.x <= limits.minX + horizontalTurnZone) {
    state.direction = 1;
    boundaryTurned = true;
  }

  if (boundaryTurned) {
    scheduleRandomTurn(state);
  } else {
    state.secondsSinceTurn += delta;
    const hasRoomToTurn = state.x > limits.minX + horizontalTurnZone * 1.35 &&
      state.x < limits.maxX - horizontalTurnZone * 1.35;
    if (hasRoomToTurn && state.secondsSinceTurn >= state.nextRandomTurnAfter) {
      state.direction = state.direction === 1 ? -1 : 1;
      scheduleRandomTurn(state);
    }
  }

  const horizontalAcceleration = state.speed * 2.15;
  state.vx = approach(
    state.vx,
    state.direction * state.speed,
    horizontalAcceleration * delta,
  );

  state.phase = (state.phase + delta * (0.58 + (state.seed % 13) / 60)) % TAU;
  let desiredVy = (
    Math.sin(state.phase) * 0.34 +
    Math.sin(state.phase * 0.47 + (state.seed % 17)) * 0.13
  ) * state.speed;

  if (state.y <= limits.minY + verticalTurnZone) {
    const strength = 1 - clamp((state.y - limits.minY) / verticalTurnZone, 0, 1);
    desiredVy += state.speed * 0.72 * strength;
  } else if (state.y >= limits.maxY - verticalTurnZone) {
    const strength = 1 - clamp((limits.maxY - state.y) / verticalTurnZone, 0, 1);
    desiredVy -= state.speed * 0.72 * strength;
  }

  state.vy = approach(state.vy, desiredVy, state.speed * 0.9 * delta);
  state.x += state.vx * delta;
  state.y += state.vy * delta;

  if (state.x <= limits.minX) {
    state.x = limits.minX;
    state.vx = Math.max(Math.abs(state.vx) * 0.72, state.speed * 0.18);
    state.direction = 1;
  } else if (state.x >= limits.maxX) {
    state.x = limits.maxX;
    state.vx = -Math.max(Math.abs(state.vx) * 0.72, state.speed * 0.18);
    state.direction = -1;
  }

  if (state.y <= limits.minY) {
    state.y = limits.minY;
    state.vy = Math.abs(state.vy) * 0.62;
  } else if (state.y >= limits.maxY) {
    state.y = limits.maxY;
    state.vy = -Math.abs(state.vy) * 0.62;
  }

  return state;
}

export function fishFacing(vx: number, previous: FishDirection): FishDirection {
  if (vx > 0.35) return 1;
  if (vx < -0.35) return -1;
  return previous;
}

export function fishPitchDegrees(vx: number, vy: number) {
  const facing = vx < 0 ? -1 : 1;
  const raw = Math.atan2(vy, Math.max(Math.abs(vx), 1)) * (180 / Math.PI) * facing;
  return clamp(raw, -13, 13);
}
