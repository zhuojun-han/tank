import assert from "node:assert/strict";
import test from "node:test";

import {
  createFishMotion,
  fishFacing,
  fishMotionLimits,
  fishPitchDegrees,
  stepFishMotion,
} from "../app/aquarium-motion.ts";

test("keeps the complete fish body inside every aquarium edge", () => {
  const bounds = { width: 394, height: 190 };
  const fishWidth = 48;
  const limits = fishMotionLimits(bounds, fishWidth);
  const motion = createFishMotion("clownfish-1", bounds, fishWidth);

  for (let frame = 0; frame < 60 * 180; frame += 1) {
    stepFishMotion(motion, 1 / 60, bounds, fishWidth);
    assert.ok(motion.x >= limits.minX && motion.x <= limits.maxX);
    assert.ok(motion.y >= limits.minY && motion.y <= limits.maxY);
  }
});

test("uses nearly the full visible aquarium instead of a reduced inner box", () => {
  const bounds = { width: 394, height: 190 };
  const fishWidth = 48;
  const limits = fishMotionLimits(bounds, fishWidth);
  const halfHeight = fishWidth * (25 / 88);

  assert.equal(limits.minX - fishWidth / 2, 4);
  assert.equal(bounds.width - (limits.maxX + fishWidth / 2), 4);
  assert.equal(limits.minY - halfHeight, 4);
  assert.equal(bounds.height - (limits.maxY + halfHeight), 4);
});

test("distributes neighboring fish keys across different starting positions", () => {
  const bounds = { width: 394, height: 190 };
  const first = createFishMotion("clownfish-0", bounds, 38);
  const second = createFishMotion("clownfish-1", bounds, 43);

  assert.ok(Math.abs(first.x - second.x) + Math.abs(first.y - second.y) > 20);
});

test("turns before a side wall and points the head along horizontal velocity", () => {
  const bounds = { width: 394, height: 190 };
  const fishWidth = 43;
  const limits = fishMotionLimits(bounds, fishWidth);
  const motion = createFishMotion("wall-turn", bounds, fishWidth);
  motion.x = limits.maxX - 8;
  motion.vx = motion.speed;
  motion.direction = 1;

  stepFishMotion(motion, 1 / 60, bounds, fishWidth);
  assert.equal(motion.direction, -1);
  assert.ok(motion.vx > 0 && motion.vx < motion.speed, "fish should decelerate before reversing");

  let facing = fishFacing(motion.vx, 1);
  for (let frame = 0; frame < 119; frame += 1) {
    stepFishMotion(motion, 1 / 60, bounds, fishWidth);
    facing = fishFacing(motion.vx, facing);
  }

  assert.equal(motion.direction, -1);
  assert.ok(motion.vx < 0);
  assert.equal(facing, -1);
  assert.ok(motion.x < limits.maxX);
});

test("adds vertical movement while keeping body pitch upright", () => {
  const bounds = { width: 394, height: 190 };
  const motion = createFishMotion("vertical-cruise", bounds, 38);
  const initialY = motion.y;

  for (let frame = 0; frame < 180; frame += 1) {
    stepFishMotion(motion, 1 / 60, bounds, 38);
  }

  assert.notEqual(motion.y, initialY);
  assert.ok(Math.abs(fishPitchDegrees(motion.vx, motion.vy)) <= 13);
});

test("changes horizontal direction occasionally in open water", () => {
  const bounds = { width: 394, height: 190 };
  const fishWidth = 43;
  const limits = fishMotionLimits(bounds, fishWidth);
  const motion = createFishMotion("open-water-turn", bounds, fishWidth);
  motion.x = (limits.minX + limits.maxX) / 2;
  motion.direction = 1;
  motion.vx = motion.speed;
  motion.secondsSinceTurn = motion.nextRandomTurnAfter;

  stepFishMotion(motion, 1 / 60, bounds, fishWidth);

  assert.equal(motion.direction, -1);
  assert.ok(motion.nextRandomTurnAfter >= 8 && motion.nextRandomTurnAfter <= 16);
  assert.ok(motion.secondsSinceTurn < 0.1);
});
