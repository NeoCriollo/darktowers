/**
 * Unit Tests for In-Game World Editor Mode & Halo-Forge Manipulator (Phases 1 & 2)
 * Validates Flight Physics, Hub Teleportation, Surface Clamping,
 * Snap Yaw Rotation, Distance Tethering, and Uniform Scaling.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  DEFAULT_EDITOR_CONFIG,
  MANIPULATOR_CONSTANTS,
  EDITOR_SECTOR_HUBS,
  EditorSessionState,
  computeClampedSurfaceY,
  snapRotateYaw,
  applyUniformScale,
  adjustTetherDistance,
  adjustElevationOffset,
  isNodeSelectable,
  computeFlightDisplacement,
  formatEditorTelemetry,
  formatGrabbedTelemetry,
  formatHoveredTelemetry,
  validateHubBoundaries,
  resolveLookVector,
  PALETTE_CATEGORIES,
  CATALOG_ASSETS,
  getCatalogCategories,
  getAssetsByCategory,
  getAssetById,
  cyclePaletteCategory,
  computeSpawnPlacement,
  toggleSelection,
  duplicateSelectedNodes
} from '../world/editorMode.ts';

describe('Editor Mode & Halo-Forge Manipulator (Phases 1 & 2)', () => {
  it('should validate default editor flight velocity configuration', () => {
    assert.strictEqual(DEFAULT_EDITOR_CONFIG.normalSpeed, 25.0);
    assert.strictEqual(DEFAULT_EDITOR_CONFIG.fastSpeed, 120.0);
    assert.strictEqual(DEFAULT_EDITOR_CONFIG.crawlSpeed, 6.0);
    assert.ok(DEFAULT_EDITOR_CONFIG.fastSpeed > DEFAULT_EDITOR_CONFIG.normalSpeed);
    assert.ok(DEFAULT_EDITOR_CONFIG.normalSpeed > DEFAULT_EDITOR_CONFIG.crawlSpeed);
    assert.strictEqual(DEFAULT_EDITOR_CONFIG.minSpeedMultiplier, 0.2);
    assert.strictEqual(DEFAULT_EDITOR_CONFIG.maxSpeedMultiplier, 5.0);
  });

  it('should compute effective flight speeds with Shift/Alt modifiers and wheel multipliers', () => {
    const session = new EditorSessionState(true);

    assert.strictEqual(session.computeCurrentSpeed(false, false), 25.0);
    assert.strictEqual(session.computeCurrentSpeed(true, false), 120.0);
    assert.strictEqual(session.computeCurrentSpeed(false, true), 6.0);

    const boostedMult = session.adjustSpeed(true);
    assert.ok(boostedMult > 1.0);
    assert.strictEqual(session.computeCurrentSpeed(false, false), 25.0 * boostedMult);

    for (let i = 0; i < 30; i++) session.adjustSpeed(false);
    assert.strictEqual(session.speedMultiplier, DEFAULT_EDITOR_CONFIG.minSpeedMultiplier);

    for (let i = 0; i < 60; i++) session.adjustSpeed(true);
    assert.strictEqual(session.speedMultiplier, DEFAULT_EDITOR_CONFIG.maxSpeedMultiplier);
  });

  it('should validate all 8 wasteland sector teleport hubs geometry and boundaries', () => {
    assert.strictEqual(EDITOR_SECTOR_HUBS.length, 8);

    for (let i = 0; i < 8; i++) {
      const hub = EDITOR_SECTOR_HUBS[i];
      assert.strictEqual(hub.id, i + 1);
      assert.strictEqual(hub.key, `KEY_${i + 1}`);
      assert.ok(validateHubBoundaries(hub));
    }

    const sanctuary = EDITOR_SECTOR_HUBS[0];
    assert.strictEqual(sanctuary.worldX, -1180.0);
    assert.strictEqual(sanctuary.worldZ, -1180.0);
    assert.strictEqual(sanctuary.sectorTag, 'waystation_sanctuary');

    const darkTower = EDITOR_SECTOR_HUBS[7];
    assert.strictEqual(darkTower.worldX, 650.0);
    assert.strictEqual(darkTower.worldZ, 650.0);
  });

  it('should compute exact 6DoF flight displacement vectors', () => {
    const dirForward = { x: 0.0, y: 0.0, z: -1.0 };
    const speed = 120.0;
    const delta = 0.016;

    const disp = computeFlightDisplacement(dirForward, speed, delta);
    assert.strictEqual(disp.x, 0.0);
    assert.strictEqual(disp.y, 0.0);
    assert.ok(Math.abs(disp.z - (-1.92)) < 0.001);
  });

  it('should calculate surface clamping with sink depth and Alt free-Y override', () => {
    const groundY = 14.5;
    const sinkDepth = 2.5;
    const heightOffset = 0.0;

    // Normal Sand-Slide mode: y = groundY - sinkDepth + heightOffset
    const clampedY = computeClampedSurfaceY(groundY, sinkDepth, heightOffset, false, 50.0);
    assert.strictEqual(clampedY, 12.0);

    // Free-Y mode (Alt held): tracks ray target height directly
    const freeY = computeClampedSurfaceY(groundY, sinkDepth, heightOffset, true, 48.0);
    assert.strictEqual(freeY, 48.0);

    // With height offset in normal mode
    const offsetClamped = computeClampedSurfaceY(groundY, sinkDepth, 3.0, false, 50.0);
    assert.strictEqual(offsetClamped, 15.0);
  });

  it('should adjust elevation offset smoothly with arrow key inputs', () => {
    let offset = 0.0;
    // Arrow UP tap (+0.35m)
    offset = adjustElevationOffset(offset, 0.35);
    assert.ok(Math.abs(offset - 0.35) < 0.001);

    // Arrow UP tap again (+0.35m)
    offset = adjustElevationOffset(offset, 0.35);
    assert.ok(Math.abs(offset - 0.70) < 0.001);

    // Arrow DOWN tap (-0.35m)
    offset = adjustElevationOffset(offset, -0.35);
    assert.ok(Math.abs(offset - 0.35) < 0.001);
  });

  it('should execute 15-degree snap yaw rotation in both directions', () => {
    const rad15 = (15.0 * Math.PI) / 180.0;

    // Clockwise (+15 deg)
    const yawCW = snapRotateYaw(0.0, true);
    assert.ok(Math.abs(yawCW - rad15) < 0.0001);

    // Counter-clockwise (-15 deg)
    const yawCCW = snapRotateYaw(0.0, false);
    assert.ok(Math.abs(yawCCW - (-rad15)) < 0.0001);

    // Full 360 wrap around
    let yaw = 0.0;
    for (let i = 0; i < 24; i++) {
      yaw = snapRotateYaw(yaw, true);
    }
    assert.ok(Math.abs(yaw) < 0.0001);
  });

  it('should clamp uniform scaling within [0.1x, 30.0x] boundary envelope', () => {
    const baseScale = { x: 2.0, y: 2.0, z: 2.0 };

    // Scale up by 10%
    const scaledUp = applyUniformScale(baseScale, 1.10);
    assert.ok(Math.abs(scaledUp.x - 2.2) < 0.001);
    assert.ok(Math.abs(scaledUp.y - 2.2) < 0.001);

    // Hit max scale boundary
    let scale = { x: 25.0, y: 25.0, z: 25.0 };
    scale = applyUniformScale(scale, 1.5); // 37.5 > 30.0 -> rejected
    assert.strictEqual(scale.x, 25.0);

    // Hit min scale boundary
    let smallScale = { x: 0.12, y: 0.12, z: 0.12 };
    smallScale = applyUniformScale(smallScale, 0.5); // 0.06 < 0.10 -> rejected
    assert.strictEqual(smallScale.x, 0.12);
  });

  it('should clamp distance tether adjustments within [3m, 250m]', () => {
    let tether = 25.0;

    tether = adjustTetherDistance(tether, 5.0);
    assert.strictEqual(tether, 30.0);

    tether = adjustTetherDistance(tether, -10.0);
    assert.strictEqual(tether, 20.0);

    // Clamp to min
    tether = adjustTetherDistance(tether, -50.0);
    assert.strictEqual(tether, MANIPULATOR_CONSTANTS.MIN_TETHER_DIST);

    // Clamp to max
    tether = adjustTetherDistance(tether, 500.0);
    assert.strictEqual(tether, MANIPULATOR_CONSTANTS.MAX_TETHER_DIST);
  });

  it('should reject terrain colliders and accept valid world prop nodes', () => {
    assert.strictEqual(isNodeSelectable('DesertTerrain', false), false);
    assert.strictEqual(isNodeSelectable('GroundMesh', false), false);
    assert.strictEqual(isNodeSelectable('Rock3 (5K)', true), false); // direct terrain collider
    assert.strictEqual(isNodeSelectable('Rock3 (5K)', false), true);
    assert.strictEqual(isNodeSelectable('EscarpmentCliff_1042', false), true);
    assert.strictEqual(isNodeSelectable('BunkerBlastGate', false), true);
    assert.strictEqual(isNodeSelectable('LootCrate_Common', false), true);
  });

  it('should format grabbed and hovered telemetry HUD headers correctly', () => {
    const pos = { x: -950.2, y: 1.4, z: -812.0 };
    const sc = { x: 2.5, y: 2.5, z: 2.5 };

    const grabbedText = formatGrabbedTelemetry('Rock3 (5K)', pos, sc);
    assert.ok(grabbedText.includes('[ AGARRADO: Rock3 (5K) ]'));
    assert.ok(grabbedText.includes('POS: (-950.2, 1.4, -812.0)'));
    assert.ok(grabbedText.includes('SCALE: (2.50, 2.50, 2.50)'));
    assert.ok(grabbedText.includes('[Q/E] ROTAR'));
    assert.ok(grabbedText.includes('[↑/↓] ELEVAR'));
    assert.ok(grabbedText.includes('[←/→] ROTAR'));
    assert.ok(grabbedText.includes('[CTRL+D] CLONAR'));

    const hoverText = formatHoveredTelemetry('Rock1 (38K)', pos, sc);
    assert.ok(hoverText.includes('[ APUNTANDO: Rock1 (38K) ]'));
    assert.ok(hoverText.includes('[CLICK IZQ] AGARRAR'));
    assert.ok(hoverText.includes('[X / SUPR] BORRAR'));
  });

  it('should validate all 3 Asset Palette categories and asset catalog distribution', () => {
    const categories = getCatalogCategories();
    assert.strictEqual(categories.length, 3);
    assert.deepStrictEqual(
      categories.map((c) => c.id),
      ['rocks', 'architecture', 'props']
    );

    const rocks = getAssetsByCategory('rocks');
    const architecture = getAssetsByCategory('architecture');
    const props = getAssetsByCategory('props');

    assert.strictEqual(rocks.length, 7);
    assert.strictEqual(architecture.length, 4);
    assert.strictEqual(props.length, 4);
    assert.strictEqual(CATALOG_ASSETS.length, 15);

    // Verify all IDs are unique
    const idSet = new Set(CATALOG_ASSETS.map((a) => a.id));
    assert.strictEqual(idSet.size, 15);
  });

  it('should validate all 7 Photogrammetry Rock definitions and tier badges', () => {
    const rocks = getAssetsByCategory('rocks');
    const rockIds = rocks.map((r) => r.id);
    assert.ok(rockIds.includes('rock_3'));
    assert.ok(rockIds.includes('rock_5b'));
    assert.ok(rockIds.includes('rock_5c'));
    assert.ok(rockIds.includes('rock_1'));
    assert.ok(rockIds.includes('rock_5a'));
    assert.ok(rockIds.includes('rock_2'));
    assert.ok(rockIds.includes('rock_4'));

    const rock3 = getAssetById('rock_3');
    assert.ok(rock3);
    assert.strictEqual(rock3.tierBadge, '[TIER A - 5K]');
    assert.strictEqual(rock3.material, 'STONE');
    assert.ok(rock3.defaultSink > 0.0);

    const rock4 = getAssetById('rock_4');
    assert.ok(rock4);
    assert.strictEqual(rock4.tierBadge, '[HERO - 60K]');
    assert.ok(rock4.defaultScale.y >= 16.0);
  });

  it('should validate Architecture and Props asset catalog entries and collision materials', () => {
    const pylon = getAssetById('monolith_pylon');
    assert.ok(pylon);
    assert.strictEqual(pylon.material, 'STEEL');

    const bunkerSlab = getAssetById('bunker_slab');
    assert.ok(bunkerSlab);
    assert.strictEqual(bunkerSlab.material, 'STONE');

    const door = getAssetById('midworld_door');
    assert.ok(door);
    assert.strictEqual(door.material, 'WOOD');

    const thinny = getAssetById('thinny_anomaly');
    assert.ok(thinny);
    assert.strictEqual(thinny.material, 'ENERGY');

    const pole = getAssetById('telegraph_pole');
    assert.ok(pole);
    assert.strictEqual(pole.material, 'WOOD');
  });

  it('should cycle category tabs correctly with Q and E wrap-around navigation', () => {
    let idx = 0;
    // Step forward (E)
    idx = cyclePaletteCategory(idx, 1, 3);
    assert.strictEqual(idx, 1);
    idx = cyclePaletteCategory(idx, 1, 3);
    assert.strictEqual(idx, 2);
    // Wrap around to start
    idx = cyclePaletteCategory(idx, 1, 3);
    assert.strictEqual(idx, 0);

    // Step backward (Q) with negative wrap-around
    idx = cyclePaletteCategory(idx, -1, 3);
    assert.strictEqual(idx, 2);
    idx = cyclePaletteCategory(idx, -1, 3);
    assert.strictEqual(idx, 1);
  });

  it('should compute spawn placement in front of camera clamped to terrain elevation with sink depth', () => {
    const camPos = { x: -1000.0, y: 15.0, z: -800.0 };
    const forward = { x: 0.0, y: 0.0, z: 1.0 }; // Facing North (+Z)
    const spawnDist = 20.0;
    const fakeGroundSample = (x: number, z: number) => 3.5; // Mock ground at 3.5m
    const sinkDepth = 0.5;

    const spawn = computeSpawnPlacement(
      camPos,
      forward,
      spawnDist,
      fakeGroundSample,
      sinkDepth
    );

    assert.strictEqual(spawn.x, -1000.0);
    assert.strictEqual(spawn.z, -780.0); // -800 + 20
    assert.strictEqual(spawn.y, 3.0); // 3.5 - 0.5
  });

  it('should support non-moving single select and Shift multi-selection', () => {
    // 1. Single click selects single node
    let sel = toggleSelection([], 'rock_5c_001', false);
    assert.deepStrictEqual(sel, ['rock_5c_001']);

    // Single click another node replaces selection
    sel = toggleSelection(sel, 'rock_3_002', false);
    assert.deepStrictEqual(sel, ['rock_3_002']);

    // 2. Shift+click adds to selection
    sel = toggleSelection(sel, 'rock_5c_001', true);
    assert.deepStrictEqual(sel, ['rock_3_002', 'rock_5c_001']);

    sel = toggleSelection(sel, 'arch_pylon_003', true);
    assert.deepStrictEqual(sel, ['rock_3_002', 'rock_5c_001', 'arch_pylon_003']);

    // Shift+click existing node deselects it
    sel = toggleSelection(sel, 'rock_5c_001', true);
    assert.deepStrictEqual(sel, ['rock_3_002', 'arch_pylon_003']);
  });

  it('should duplicate multiple selected nodes simultaneously', () => {
    const selected = [
      { id: 'rock_5c_001', position: { x: 10.0, y: 2.0, z: -30.0 } },
      { id: 'rock_3_002', position: { x: 14.0, y: 2.5, z: -28.0 } }
    ];

    const clones = duplicateSelectedNodes(selected);
    assert.strictEqual(clones.length, 2);
    assert.strictEqual(clones[0].id, 'rock_5c_001_Copy');
    assert.deepStrictEqual(clones[0].position, { x: 10.0, y: 2.0, z: -30.0 });
    assert.strictEqual(clones[1].id, 'rock_3_002_Copy');
    assert.deepStrictEqual(clones[1].position, { x: 14.0, y: 2.5, z: -28.0 });
  });
});
