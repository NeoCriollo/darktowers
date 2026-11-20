import { describe, it } from 'node:test';
import assert from 'node:assert';
import * as fs from 'node:fs';
import {
  TOUR_VISTAS,
  TOUR_TIMING,
  SPIRAL_CONFIG,
  DOLLY_CONFIG,
  HABOOB_CONFIG,
  computeTourPhase,
  computeDescendingSpiralPosition,
} from '../ui/menuCinematicTour.ts';

describe('Menu Cinematic Tour Contracts & Vista Showcase', () => {
  it('should validate all 8 curated regional wasteland vistas with telephoto starting radii', () => {
    assert.strictEqual(TOUR_VISTAS.length, 8);
    assert.strictEqual(SPIRAL_CONFIG.BASE_FOV, 36.0);
    assert.strictEqual(SPIRAL_CONFIG.RADIUS_MULTIPLIER, 1.9);
    assert.strictEqual(SPIRAL_CONFIG.OMEGA, 0.025);
    assert.strictEqual(SPIRAL_CONFIG.K_R, 1.4);
    assert.strictEqual(SPIRAL_CONFIG.K_H, 0.65);

    const baseExpectedRadii = [95.0, 110.0, 130.0, 120.0, 100.0, 95.0, 140.0, 160.0];

    for (let i = 0; i < TOUR_VISTAS.length; i++) {
      const v = TOUR_VISTAS[i];
      assert.ok(v.locationEn.length > 0);
      assert.ok(v.locationEs.length > 0);
      assert.ok(v.atmosphereEn.length > 0);
      assert.ok(v.atmosphereEs.length > 0);
      assert.ok(v.sunEnergy > 0.0);
      assert.ok(v.fogDensity > 0.0);
      assert.strictEqual(v.poiCenter.length, 3);
      assert.strictEqual(v.rStart, baseExpectedRadii[i] * 1.9);

      // Verify POI coordinates stay strictly within +/-1250m map footprint
      assert.ok(Math.abs(v.poiCenter[0]) <= 1250.0);
      assert.ok(Math.abs(v.poiCenter[2]) <= 1250.0);
    }
  });

  it('should validate standard descending spiral math for non-dolly zones', () => {
    const v0 = TOUR_VISTAS[0];
    const initial = computeDescendingSpiralPosition(v0, 0.0);
    assert.strictEqual(initial.currentRadius, v0.rStart);
    assert.strictEqual(initial.currentHeight, v0.hStart);
    assert.strictEqual(initial.fov, 36.0);
    assert.strictEqual(initial.isDollyZoom, false);

    // At t = 8.0s of hold:
    const t8 = computeDescendingSpiralPosition(v0, 8.0);
    const expectedRadius = v0.rStart - (1.4 * 8.0);
    const expectedHeight = v0.hStart - (0.65 * 8.0);
    assert.strictEqual(t8.currentRadius, expectedRadius);
    assert.strictEqual(t8.currentHeight, expectedHeight);
    assert.strictEqual(t8.fov, 36.0);

    // Verify distance from POI center in XZ plane equals currentRadius
    const dx = t8.cameraPos[0] - v0.poiCenter[0];
    const dz = t8.cameraPos[2] - v0.poiCenter[2];
    const computedRadius = Math.hypot(dx, dz);
    assert.ok(Math.abs(computedRadius - expectedRadius) < 0.001);

    // Verify Y position equals poiCenter.y + currentHeight
    assert.ok(Math.abs(t8.cameraPos[1] - (v0.poiCenter[1] + expectedHeight)) < 0.001);

    // Verify camera continuously looks at the POI
    assert.deepStrictEqual(t8.cameraLook, v0.poiCenter);
  });

  it('should validate Selective Dolly Zoom on Zone 3 (Thinny) & Zone 7 (Dark Tower)', () => {
    assert.deepStrictEqual(DOLLY_CONFIG.DOLLY_ZONES, [3, 7]);
    assert.strictEqual(DOLLY_CONFIG.TARGET_WIDTH, 45.0);
    assert.strictEqual(DOLLY_CONFIG.DOLLY_FOV_MIN, 36.0);
    assert.strictEqual(DOLLY_CONFIG.DOLLY_FOV_MAX, 65.0);

    const v3 = TOUR_VISTAS[3];
    const v7 = TOUR_VISTAS[7];
    assert.strictEqual(v3.dollyZoom, true);
    assert.strictEqual(v7.dollyZoom, true);

    // At t = 0s: initial FOV is 36.0, dynamic radius compensates for 45m target width
    const v3Init = computeDescendingSpiralPosition(v3, 0.0, 3);
    assert.strictEqual(v3Init.isDollyZoom, true);
    assert.strictEqual(v3Init.fov, 36.0);
    const expectedR0 = 45.0 / (2.0 * Math.tan((36.0 * Math.PI) / 360.0));
    assert.ok(Math.abs(v3Init.currentRadius - expectedR0) < 0.001);

    // At t = 8.5s (end of hold duration): FOV reaches 65.0, radius contracts
    const v3End = computeDescendingSpiralPosition(v3, 8.5, 3);
    assert.strictEqual(v3End.fov, 65.0);
    const expectedR85 = 45.0 / (2.0 * Math.tan((65.0 * Math.PI) / 360.0));
    assert.ok(Math.abs(v3End.currentRadius - expectedR85) < 0.001);
    assert.ok(v3End.currentRadius < v3Init.currentRadius); // Camera moved inward as FOV dilated

    // Zone 7 (Dark Tower Citadel) should also execute Dolly Zoom
    const v7Init = computeDescendingSpiralPosition(v7, 0.0, 7);
    const v7Mid = computeDescendingSpiralPosition(v7, 4.25, 7);
    assert.strictEqual(v7Init.isDollyZoom, true);
    assert.strictEqual(v7Init.fov, 36.0);
    assert.ok(v7Mid.fov > 36.0 && v7Mid.fov < 65.0);
  });

  it('should validate Haboob Dust Wipe transition and ~0.4s 100% occlusion window', () => {
    assert.strictEqual(HABOOB_CONFIG.BURST_AMOUNT, 80);
    assert.strictEqual(HABOOB_CONFIG.DUST_COLOR_HEX, '#c2b280');
    assert.strictEqual(HABOOB_CONFIG.OCCLUSION_WINDOW, 0.4);

    // During hold phase (t = 0.0 and 5.0)
    const t0 = computeTourPhase(0.0);
    assert.strictEqual(t0.vistaIndex, 0);
    assert.strictEqual(t0.phase, 'HOLD');
    assert.strictEqual(t0.dustOpacity, 0.0);
    assert.strictEqual(t0.isOccluded, false);

    // Surge onset (transition_time = 0.45s)
    const tSurge = computeTourPhase(TOUR_TIMING.HOLD_DURATION + 0.45);
    assert.strictEqual(tSurge.vistaIndex, 0);
    assert.strictEqual(tSurge.phase, 'HABOOB_SURGE');
    assert.ok(tSurge.dustOpacity > 0.0 && tSurge.dustOpacity < 1.0);
    assert.strictEqual(tSurge.isOccluded, false);

    // Peak occlusion window (~0.4s between 0.9s and 1.3s): 100% occluded
    const tPeakStart = computeTourPhase(TOUR_TIMING.HOLD_DURATION + 0.95);
    assert.strictEqual(tPeakStart.phase, 'HABOOB_PEAK');
    assert.strictEqual(tPeakStart.dustOpacity, 1.0);
    assert.strictEqual(tPeakStart.isOccluded, true);

    // Mid-occlusion zone snap (at transition_time >= 1.1s)
    const tSnap = computeTourPhase(TOUR_TIMING.HOLD_DURATION + 1.15);
    assert.strictEqual(tSnap.phase, 'HABOOB_PEAK');
    assert.strictEqual(tSnap.dustOpacity, 1.0);
    assert.strictEqual(tSnap.isOccluded, true);
    assert.strictEqual(tSnap.vistaIndex, 1); // Snapped cleanly to next zone while occluded

    // Dispersal phase (transition_time = 1.95s)
    const tClear = computeTourPhase(TOUR_TIMING.HOLD_DURATION + 1.95);
    assert.strictEqual(tClear.phase, 'HABOOB_CLEAR');
    assert.ok(tClear.dustOpacity > 0.0 && tClear.dustOpacity < 1.0);
    assert.strictEqual(tClear.isOccluded, false);
    assert.strictEqual(tClear.vistaIndex, 1);
  });

  it('should verify 2D TourFadeCurtain ColorRect is removed from scenes/main_menu.tscn', () => {
    const sceneContent = fs.readFileSync('scenes/main_menu.tscn', 'utf-8');
    assert.strictEqual(sceneContent.includes('TourFadeCurtain'), false);
    assert.strictEqual(sceneContent.includes('CrossroadsCamera'), true);
  });
});
