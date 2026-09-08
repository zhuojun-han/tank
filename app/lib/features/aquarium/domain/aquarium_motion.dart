import 'dart:math' as math;

const _edgePadding = 4.0;
const _minimumRandomTurnSeconds = 8.0;
const _randomTurnWindowSeconds = 8.0;

class AquariumBounds {
  const AquariumBounds({required this.width, required this.height});

  final double width;
  final double height;
}

class FishMotionLimits {
  const FishMotionLimits({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}

class FishMotionState {
  FishMotionState({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.direction,
    required this.phase,
    required this.speed,
    required this.seed,
    required this.randomState,
    required this.secondsSinceTurn,
    required this.nextRandomTurnAfter,
  });

  double x;
  double y;
  double vx;
  double vy;
  int direction;
  double phase;
  final double speed;
  final int seed;
  int randomState;
  double secondsSinceTurn;
  double nextRandomTurnAfter;
}

int fishSeed(String value) {
  var hash = 2166136261;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0xffffffff;
  }
  hash ^= hash >>> 16;
  hash = (hash * 0x85ebca6b) & 0xffffffff;
  hash ^= hash >>> 13;
  hash = (hash * 0xc2b2ae35) & 0xffffffff;
  hash ^= hash >>> 16;
  return hash & 0xffffffff;
}

FishMotionLimits fishMotionLimits(AquariumBounds bounds, double fishWidth) {
  final safeWidth = math.max(1.0, bounds.width);
  final safeHeight = math.max(1.0, bounds.height);
  final halfWidth = math.max(1.0, fishWidth / 2);
  final halfHeight = math.max(1.0, fishWidth * (25 / 88));
  final minX = math.min(safeWidth / 2, halfWidth + _edgePadding);
  final minY = math.min(safeHeight / 2, halfHeight + _edgePadding);
  return FishMotionLimits(
    minX: minX,
    maxX: math.max(minX, safeWidth - halfWidth - _edgePadding),
    minY: minY,
    maxY: math.max(minY, safeHeight - halfHeight - _edgePadding),
  );
}

FishMotionState createFishMotion(
  String key,
  AquariumBounds bounds,
  double fishWidth,
) {
  final seed = fishSeed(key);
  final limits = fishMotionLimits(bounds, fishWidth);
  final horizontalRatio = 0.16 + (seed % 680) / 1000;
  final verticalRatio = 0.1 + ((seed >>> 9) % 800) / 1000;
  final direction = (seed & 1) == 0 ? 1 : -1;
  final speed = 20.0 + ((seed >>> 3) % 9);
  final state = FishMotionState(
    x: limits.minX + (limits.maxX - limits.minX) * horizontalRatio,
    y: limits.minY + (limits.maxY - limits.minY) * verticalRatio,
    vx: direction * speed,
    vy: (((seed >>> 13) % 9) - 4) * 0.7,
    direction: direction,
    phase: ((seed % 1000) / 1000) * math.pi * 2,
    speed: speed,
    seed: seed,
    randomState: seed == 0 ? 1 : seed,
    secondsSinceTurn: 0,
    nextRandomTurnAfter: _minimumRandomTurnSeconds,
  );
  _scheduleRandomTurn(state);
  state.secondsSinceTurn = ((seed >>> 17) % 45) / 10;
  return state;
}

FishMotionState stepFishMotion(
  FishMotionState state,
  double elapsedSeconds,
  AquariumBounds bounds,
  double fishWidth,
) {
  final delta = _clamp(elapsedSeconds.isFinite ? elapsedSeconds : 0, 0, 0.05);
  final limits = fishMotionLimits(bounds, fishWidth);
  final horizontalTurnZone = math.min(
    32.0,
    math.max(18.0, bounds.width * 0.08),
  );
  final verticalTurnZone = math.min(30.0, math.max(18.0, bounds.height * 0.12));
  var boundaryTurned = false;
  if (state.direction > 0 && state.x >= limits.maxX - horizontalTurnZone) {
    state.direction = -1;
    boundaryTurned = true;
  } else if (state.direction < 0 &&
      state.x <= limits.minX + horizontalTurnZone) {
    state.direction = 1;
    boundaryTurned = true;
  }
  if (boundaryTurned) {
    _scheduleRandomTurn(state);
  } else {
    state.secondsSinceTurn += delta;
    final hasRoomToTurn =
        state.x > limits.minX + horizontalTurnZone * 1.35 &&
        state.x < limits.maxX - horizontalTurnZone * 1.35;
    if (hasRoomToTurn && state.secondsSinceTurn >= state.nextRandomTurnAfter) {
      state.direction = state.direction == 1 ? -1 : 1;
      _scheduleRandomTurn(state);
    }
  }
  state.vx = _approach(
    state.vx,
    state.direction * state.speed,
    state.speed * 2.15 * delta,
  );
  state.phase =
      (state.phase + delta * (0.58 + (state.seed % 13) / 60)) % (math.pi * 2);
  var desiredVy =
      (math.sin(state.phase) * 0.34 +
          math.sin(state.phase * 0.47 + (state.seed % 17)) * 0.13) *
      state.speed;
  if (state.y <= limits.minY + verticalTurnZone) {
    final strength =
        1 - _clamp((state.y - limits.minY) / verticalTurnZone, 0, 1);
    desiredVy += state.speed * 0.72 * strength;
  } else if (state.y >= limits.maxY - verticalTurnZone) {
    final strength =
        1 - _clamp((limits.maxY - state.y) / verticalTurnZone, 0, 1);
    desiredVy -= state.speed * 0.72 * strength;
  }
  state.vy = _approach(state.vy, desiredVy, state.speed * 0.9 * delta);
  state.x += state.vx * delta;
  state.y += state.vy * delta;
  if (state.x <= limits.minX) {
    state.x = limits.minX;
    state.vx = math.max(state.vx.abs() * 0.72, state.speed * 0.18);
    state.direction = 1;
  } else if (state.x >= limits.maxX) {
    state.x = limits.maxX;
    state.vx = -math.max(state.vx.abs() * 0.72, state.speed * 0.18);
    state.direction = -1;
  }
  if (state.y <= limits.minY) {
    state.y = limits.minY;
    state.vy = state.vy.abs() * 0.62;
  } else if (state.y >= limits.maxY) {
    state.y = limits.maxY;
    state.vy = -state.vy.abs() * 0.62;
  }
  return state;
}

int fishFacing(double vx, int previous) {
  if (vx > 0.35) return 1;
  if (vx < -0.35) return -1;
  return previous;
}

double fishPitchDegrees(double vx, double vy) {
  final facing = vx < 0 ? -1 : 1;
  final raw = math.atan2(vy, math.max(vx.abs(), 1)) * 180 / math.pi * facing;
  return _clamp(raw, -13, 13);
}

double _clamp(num value, num minimum, num maximum) =>
    value.clamp(minimum, maximum).toDouble();

double _approach(double value, double target, double maximumChange) {
  if (value < target) return math.min(value + maximumChange, target);
  return math.max(value - maximumChange, target);
}

double _nextRandom(FishMotionState state) {
  var value = state.randomState == 0 ? 0x9e3779b9 : state.randomState;
  value ^= (value << 13) & 0xffffffff;
  value ^= value >>> 17;
  value ^= (value << 5) & 0xffffffff;
  state.randomState = value & 0xffffffff;
  return state.randomState / 0x100000000;
}

void _scheduleRandomTurn(FishMotionState state) {
  state.secondsSinceTurn = 0;
  state.nextRandomTurnAfter =
      _minimumRandomTurnSeconds + _nextRandom(state) * _randomTurnWindowSeconds;
}
