import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/features/aquarium/domain/aquarium_motion.dart';

void main() {
  test('完整鱼体连续三分钟保持在鱼缸四壁内', () {
    const bounds = AquariumBounds(width: 394, height: 232);
    const fishWidth = 48.0;
    final limits = fishMotionLimits(bounds, fishWidth);
    final motion = createFishMotion('clownfish-1', bounds, fishWidth);

    for (var frame = 0; frame < 60 * 180; frame++) {
      stepFishMotion(motion, 1 / 60, bounds, fishWidth);
      expect(motion.x, inInclusiveRange(limits.minX, limits.maxX));
      expect(motion.y, inInclusiveRange(limits.minY, limits.maxY));
    }
  });

  test('游动边界只在整个可见鱼缸内缩 4 像素', () {
    const bounds = AquariumBounds(width: 394, height: 232);
    const fishWidth = 48.0;
    final limits = fishMotionLimits(bounds, fishWidth);
    const halfHeight = fishWidth * (25 / 88);

    expect(limits.minX - fishWidth / 2, 4);
    expect(bounds.width - (limits.maxX + fishWidth / 2), 4);
    expect(limits.minY - halfHeight, 4);
    expect(bounds.height - (limits.maxY + halfHeight), 4);
  });

  test('鱼在侧壁前减速转向且鱼头跟随水平速度', () {
    const bounds = AquariumBounds(width: 394, height: 152);
    const fishWidth = 43.0;
    final limits = fishMotionLimits(bounds, fishWidth);
    final motion = createFishMotion('wall-turn', bounds, fishWidth)
      ..x = limits.maxX - 8
      ..vx = 24
      ..direction = 1;

    stepFishMotion(motion, 1 / 60, bounds, fishWidth);
    expect(motion.direction, -1);
    expect(motion.vx, greaterThan(0));
    var facing = fishFacing(motion.vx, 1);
    for (var frame = 0; frame < 120; frame++) {
      stepFishMotion(motion, 1 / 60, bounds, fishWidth);
      facing = fishFacing(motion.vx, facing);
    }
    expect(motion.vx, lessThan(0));
    expect(facing, -1);
    expect(fishPitchDegrees(motion.vx, motion.vy).abs(), lessThanOrEqualTo(13));
  });

  test('相邻鱼拥有不同初始位置和上下运动', () {
    const bounds = AquariumBounds(width: 394, height: 152);
    final first = createFishMotion('fish-0', bounds, 42);
    final second = createFishMotion('fish-1', bounds, 42);
    expect(
      (first.x - second.x).abs() + (first.y - second.y).abs(),
      greaterThan(10),
    );
    final initialY = first.y;
    for (var frame = 0; frame < 180; frame++) {
      stepFishMotion(first, 1 / 60, bounds, 42);
    }
    expect(first.y, isNot(initialY));
  });

  test('开阔水域中会低频随机变向', () {
    const bounds = AquariumBounds(width: 394, height: 232);
    const fishWidth = 43.0;
    final limits = fishMotionLimits(bounds, fishWidth);
    final motion = createFishMotion('open-water-turn', bounds, fishWidth)
      ..x = (limits.minX + limits.maxX) / 2
      ..direction = 1
      ..vx = 24;
    motion.secondsSinceTurn = motion.nextRandomTurnAfter;

    stepFishMotion(motion, 1 / 60, bounds, fishWidth);

    expect(motion.direction, -1);
    expect(motion.nextRandomTurnAfter, inInclusiveRange(8, 16));
    expect(motion.secondsSinceTurn, lessThan(0.1));
  });
}
