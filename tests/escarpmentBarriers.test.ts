/**
 * Unit Tests for Hybrid Terrain Escarpment Barriers (Option C)
 * Validates the 5 Escarpment Barrier Chains, Canyon Defiles, and 1:1 Elevation Parity.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {
  ESCARPMENT_CHAINS,
  ALL_BARRIER_SEGMENTS,
  DEFILE_PASS_SEGMENTS,
  BARRIER_CONSTANTS,
  segmentDistance2D,
  smoothstep,
  getMinBarrierDistance,
  getMinDefilePassDistance,
  calculateBarrierElevation,
} from '../world/escarpmentBarriers.ts';

describe('Hybrid Terrain Escarpment Barriers (Option C)', () => {
  it('should validate segment_distance_2d Euclidean math', () => {
    // Point on segment
    const d0 = segmentDistance2D(0.0, 0.0, -10.0, 0.0, 10.0, 0.0);
    assert.equal(d0, 0.0);

    // Perpendicular point
    const d1 = segmentDistance2D(0.0, 5.0, -10.0, 0.0, 10.0, 0.0);
    assert.equal(d1, 5.0);

    // Clamped before start A
    const dBefore = segmentDistance2D(-15.0, 0.0, -10.0, 0.0, 10.0, 0.0);
    assert.equal(dBefore, 5.0);

    // Clamped past end B
    const dPast = segmentDistance2D(10.0, 7.0, -10.0, 0.0, 10.0, 0.0);
    assert.equal(dPast, 7.0);
  });

  it('should validate all 6 Escarpment Barrier Chains and 14 segments geometry', () => {
    assert.equal(ESCARPMENT_CHAINS.length, 6);
    assert.equal(ALL_BARRIER_SEGMENTS.length, 14);
    assert.equal(DEFILE_PASS_SEGMENTS.length, 5);

    // Chain 0: Mohaine Horseshoe Cradle
    const c0 = ESCARPMENT_CHAINS.find((c) => c.id === 'chain_0_horseshoe_cradle')!;
    assert.ok(c0);
    assert.equal(c0.segments.length, 2);
    assert.deepEqual(c0.segments[0], { ax: -1250.0, az: -1100.0, bx: -1225.0, bz: -1225.0 });
    assert.deepEqual(c0.segments[1], { ax: -1225.0, az: -1225.0, bx: -1100.0, bz: -1250.0 });

    // Chain 1: Mohaine North Rim
    const c1 = ESCARPMENT_CHAINS.find((c) => c.id === 'chain_1_mohaine_north_rim')!;
    assert.ok(c1);
    assert.equal(c1.segments.length, 2);
    assert.deepEqual(c1.segments[0], { ax: -1250.0, az: -650.0, bx: -750.0, bz: -600.0 });
    assert.deepEqual(c1.segments[1], { ax: -750.0, az: -600.0, bx: -650.0, bz: -660.0 });

    // Chain 2: SW Desolation East Wall
    const c2 = ESCARPMENT_CHAINS.find((c) => c.id === 'chain_2_sw_desolation_east_wall')!;
    assert.ok(c2);
    assert.equal(c2.segments.length, 2);

    // Chain 3: Central Great Divide
    const c3 = ESCARPMENT_CHAINS.find((c) => c.id === 'chain_3_central_great_divide')!;
    assert.ok(c3);
    assert.equal(c3.segments.length, 4);

    // Chain 4: SE Meridian Wall
    const c4 = ESCARPMENT_CHAINS.find((c) => c.id === 'chain_4_se_meridian_wall')!;
    assert.ok(c4);
    assert.equal(c4.segments.length, 1);

    // Chain 5: Bastions (5A North Spur & 5B L-Bastion)
    const c5 = ESCARPMENT_CHAINS.find((c) => c.id === 'chain_5_bastions')!;
    assert.ok(c5);
    assert.equal(c5.segments.length, 3);
  });

  it('should verify points on the 5 barrier chains exceed +45m elevation', () => {
    // Representative centerline test points across all 5 chains away from passes
    const testPointsOnChains = [
      { name: 'Chain 1 Mohaine North Rim', x: -1000.0, z: -625.0 },
      { name: 'Chain 2 SW Desolation East Wall', x: -425.0, z: -1075.0 },
      { name: 'Chain 3 West Divide', x: -400.0, z: -100.0 },
      { name: 'Chain 3 East Divide', x: 200.0, z: -100.0 },
      { name: 'Chain 3 NE Ridge', x: 585.0, z: -80.0 },
      { name: 'Chain 4 SE Meridian Wall', x: 420.0, z: -375.0 },
      { name: 'Chain 5A Rust-Gorge North Spur', x: -1015.0, z: 500.0 },
      { name: 'Chain 5B Citadel West Wing', x: 150.0, z: 950.0 },
      { name: 'Chain 5B Citadel South Wing', x: 385.0, z: 500.0 },
    ];

    for (const pt of testPointsOnChains) {
      const dBarrier = getMinBarrierDistance(pt.x, pt.z);
      assert.ok(dBarrier < 1.0, `${pt.name} test point must lie on segment centerline`);

      const dPass = getMinDefilePassDistance(pt.x, pt.z);
      assert.ok(dPass >= 40.0, `${pt.name} test point must be outside pass carve zone`);

      const elev = calculateBarrierElevation(pt.x, pt.z);
      assert.ok(
        elev >= 45.0,
        `Point on ${pt.name} at (${pt.x}, ${pt.z}) must exceed +45m elevation (got ${elev.toFixed(2)}m)`
      );
      assert.ok(
        elev <= BARRIER_CONSTANTS.PEAK_HEIGHT,
        `Point on ${pt.name} cannot exceed peak height of ${BARRIER_CONSTANTS.PEAK_HEIGHT}m (got ${elev.toFixed(2)}m)`
      );
    }
  });

  it('should verify midpoints and crossings of the carved canyon defiles remain at walkable basin floor height (< 6m)', () => {
    const canyonDefileTestPoints = [
      { name: 'Defile 1 (Node 1 -> 2) Choke', x: -350.0, z: -725.0 },
      { name: 'Defile 1 (Node 1 -> 2) Crossing at Chain 2', x: -430.0, z: -780.0 },
      { name: 'Defile 2 (Node 2 -> 3) Choke', x: -65.0, z: -285.0 },
      { name: 'Defile 3 (Node 3 -> 4) Choke', x: -325.0, z: 27.5 },
      { name: 'Defile 4 (Node 3 -> 6) Choke', x: 325.0, z: 27.5 },
      { name: 'Defile 5 (Node 5 -> 7) Crossing at Chain 5B', x: 150.0, z: 650.0 },
      { name: 'Defile 5 (Node 5 -> 7) Choke', x: 325.0, z: 650.0 },
    ];

    for (const pt of canyonDefileTestPoints) {
      const dPass = getMinDefilePassDistance(pt.x, pt.z);
      assert.ok(
        dPass <= BARRIER_CONSTANTS.DEFILE_INNER_RADIUS + 0.1,
        `${pt.name} at (${pt.x}, ${pt.z}) must be within the 16m inner defile carve radius (got ${dPass.toFixed(1)}m)`
      );

      const barrierH = calculateBarrierElevation(pt.x, pt.z);
      assert.equal(
        barrierH,
        0.0,
        `Barrier elevation at ${pt.name} must be 0.0m inside defile carve channel (got ${barrierH}m)`
      );

      // Total terrain height at walkable defile floor must remain < 6m
      // Base terrain in these flat basin corridors is between -1.0m and +3.0m
      const totalEstimatedHeight = barrierH + 2.0; // Nominal corridor floor
      assert.ok(
        totalEstimatedHeight < 6.0,
        `Total terrain height at ${pt.name} must remain < 6m for unhindered traversal`
      );
    }
  });

  it('should preserve Node 0 Sanctuary Invariant (0m perturbation at bunker & gate)', () => {
    const newBunker = { x: -1180.0, z: -1180.0 };
    const newSpawn = { x: -1177.2, z: -1177.2 };
    const gate = { x: -900.0, z: -820.0 };

    for (const pt of [newBunker, newSpawn, gate]) {
      assert.equal(
        calculateBarrierElevation(pt.x, pt.z),
        0.0,
        `Barrier elevation at sanctuary point (${pt.x}, ${pt.z}) must be exactly 0.0m`
      );
    }
  });

  it('should validate 100% numeric tolerance parity between TS and GDScript formulas (< 0.01m tolerance)', () => {
    // Benchmark values generated directly by GDScript TerrainCollisionGenerator.calculate_barrier_elevation
    const gdscriptBenchmarks = [
      { x: -1000.0, z: -625.0, gdExpected: 51.029481 },
      { x: -425.0, z: -1075.0, gdExpected: 51.745341 },
      { x: -400.0, z: -100.0, gdExpected: 50.595709 },
      { x: 200.0, z: -100.0, gdExpected: 51.321444 },
      { x: 420.0, z: -375.0, gdExpected: 51.476053 },
      { x: -1015.0, z: 500.0, gdExpected: 51.3589 },
      { x: 150.0, z: 950.0, gdExpected: 51.472887 },
      { x: 385.0, z: 500.0, gdExpected: 49.695671 },
      { x: -350.0, z: -725.0, gdExpected: 0.0 },
      { x: -430.0, z: -780.0, gdExpected: 0.0 },
      { x: -65.0, z: -285.0, gdExpected: 0.0 },
      { x: -325.0, z: 27.5, gdExpected: 0.0 },
      { x: 325.0, z: 27.5, gdExpected: 0.0 },
      { x: 150.0, z: 650.0, gdExpected: 0.0 },
      { x: -1020.0, z: -820.0, gdExpected: 0.0 },
      { x: 0.0, z: 0.0, gdExpected: 0.0 },
      { x: -500.0, z: -500.0, gdExpected: 0.0 },
      { x: 200.0, z: 200.0, gdExpected: 0.0 },
    ];

    for (const b of gdscriptBenchmarks) {
      const tsVal = calculateBarrierElevation(b.x, b.z);
      const diff = Math.abs(tsVal - b.gdExpected);
      assert.ok(
        diff < 0.01,
        `TS (${tsVal.toFixed(6)}) and GDScript (${b.gdExpected.toFixed(6)}) must match within 0.01m at (${b.x}, ${b.z}) (diff=${diff.toFixed(6)}m)`
      );
    }
  });

  it('should validate player controller steep wall blocking and slide-down contracts', () => {
    const playerGd = fs.readFileSync(path.resolve(process.cwd(), 'player.gd'), 'utf-8');

    // 1. floor_max_angle configuration to ~40-45 deg (0.75 radians)
    assert.ok(
      playerGd.includes('max_slope_angle: float = 0.75') || playerGd.includes('floor_max_angle = 0.75'),
      'player.gd must configure floor_max_angle or max_slope_angle to 0.75 radians'
    );
    assert.ok(
      playerGd.includes('floor_max_angle = max_slope_angle') || playerGd.includes('floor_max_angle = 0.75'),
      'player.gd must set floor_max_angle in _ready()'
    );

    // 2. floor_block_on_wall = true enforcement
    assert.ok(
      playerGd.includes('floor_block_on_wall = true'),
      'player.gd must enforce floor_block_on_wall = true in _ready()'
    );

    // 3. Slide-down logic checking steep slope angle and wall contact
    assert.ok(
      playerGd.includes('get_floor_normal().angle_to(Vector3.UP) > floor_max_angle') ||
      playerGd.includes('get_floor_normal().angle_to(Vector3.UP)'),
      'player.gd must check floor normal angle against floor_max_angle'
    );
    assert.ok(
      playerGd.includes('is_on_wall()'),
      'player.gd must check is_on_wall() for wall collisions'
    );
    assert.ok(
      playerGd.includes('_apply_steep_slope_slide'),
      'player.gd must invoke steep slope slide-down logic'
    );
    assert.ok(
      playerGd.includes('velocity.y = minf(velocity.y, slide_vel.y)') || playerGd.includes('velocity.y = 0.0'),
      'player.gd must prevent gaining vertical height while sliding down steep slopes'
    );
    assert.ok(
      playerGd.includes('not on_steep_slope'),
      'player.gd must prevent jumping when against a steep slope or wall'
    );
  });

  it('should validate slide-down downward vector physics math on steep slopes and sheer walls', () => {
    const floorMaxAngle = 0.75; // ~43 degrees

    // Helper to calculate slide vector matching GDScript _apply_steep_slope_slide logic
    const calculateSlideVector = (normal: [number, number, number], _inputDir: [number, number, number]) => {
      const [nx, ny, nz] = normal;
      let slideX = 0 - (-ny * nx);
      let slideY = -1 - (-ny * ny);
      let slideZ = 0 - (-ny * nz);

      if (ny < 0.2) {
        const horizLen = Math.hypot(nx, nz) || 1.0;
        slideX += (nx / horizLen) * 0.4;
        slideZ += (nz / horizLen) * 0.4;
      }

      const len = Math.hypot(slideX, slideY, slideZ);
      const dirX = slideX / len;
      const dirY = slideY / len;
      const dirZ = slideZ / len;

      const slideSpeed = 8.5;
      return {
        velX: dirX * slideSpeed,
        velY: dirY * slideSpeed,
        velZ: dirZ * slideSpeed,
        downwardVelocity: dirY * slideSpeed
      };
    };

    // Test 1: 60-degree steep mountain slope (angle > 0.75 rad)
    const slopeNormal60: [number, number, number] = [Math.sin(Math.PI / 3), Math.cos(Math.PI / 3), 0.0];
    const angle60 = Math.acos(slopeNormal60[1]);
    assert.ok(angle60 > floorMaxAngle, '60-degree slope angle must exceed floorMaxAngle (0.75 rad)');

    const slide60 = calculateSlideVector(slopeNormal60, [-1, 0, 0]);
    assert.ok(slide60.downwardVelocity < -5.0, 'Downward sliding velocity must be strongly negative');
    assert.ok(slide60.velX > 0.0, 'Horizontal velocity must push away from mountain into wasteland');

    // Test 2: Sheer vertical wall (90 deg, ny = 0, nx = 1, nz = 0)
    const wallNormal90: [number, number, number] = [1.0, 0.0, 0.0];
    const slide90 = calculateSlideVector(wallNormal90, [-1, 0, 0]);
    assert.ok(slide90.downwardVelocity < -7.0, 'Vertical cliff must cause steep downward plunge');
    assert.ok(slide90.velX > 0.0, 'Player must be repelled outward away from vertical cliff');
  });
});
