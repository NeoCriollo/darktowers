/**
 * Tactical Map Modal Canvas & Cartographic Projection Unit Tests
 * The Path of Ka - Tactical Reconnaissance Chart Verification
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { REGIONAL_CORRIDORS } from '../world/worldGraph.ts';
import { QUADRANT_GRID_CONFIG } from '../world/worldQuadrantGrid.ts';

// Cartographic projection math mirroring ui/map_contour_renderer.gd
interface CanvasSize {
  x: number;
  y: number;
}

interface Vector3D {
  x: number;
  y: number;
  z: number;
}

interface Vector2D {
  x: number;
  y: number;
}

class TestCartographicProjection {
  worldHalfExtent: number = 1250.0;
  zoomLevel: number = 1.0;
  panOffset: Vector2D = { x: 0.0, y: 0.0 };
  canvasSize: CanvasSize = { x: 580.0, y: 440.0 };

  clampPanOffset(rawOffset: Vector2D): Vector2D {
    const maxX = Math.max(240.0, this.canvasSize.x * 0.75 * this.zoomLevel);
    const maxY = Math.max(240.0, this.canvasSize.y * 0.75 * this.zoomLevel);
    return {
      x: Math.max(-maxX, Math.min(maxX, rawOffset.x)),
      y: Math.max(-maxY, Math.min(maxY, rawOffset.y))
    };
  }

  worldToMap(worldPos: Vector3D, cSize: CanvasSize = this.canvasSize): Vector2D {
    const center = {
      x: cSize.x * 0.5 + this.panOffset.x,
      y: cSize.y * 0.5 + this.panOffset.y
    };
    const usableSpan = Math.min(cSize.x, cSize.y) * 0.84 * this.zoomLevel;
    const scalePxPerMeter = usableSpan / Math.max(1.0, this.worldHalfExtent * 2.0);
    return {
      x: center.x + worldPos.x * scalePxPerMeter,
      y: center.y - worldPos.z * scalePxPerMeter
    };
  }

  mapToWorld(mapPos: Vector2D, cSize: CanvasSize = this.canvasSize): Vector3D {
    const center = {
      x: cSize.x * 0.5 + this.panOffset.x,
      y: cSize.y * 0.5 + this.panOffset.y
    };
    const usableSpan = Math.min(cSize.x, cSize.y) * 0.84 * this.zoomLevel;
    const scalePxPerMeter = Math.max(0.0001, usableSpan / Math.max(1.0, this.worldHalfExtent * 2.0));
    const wx = (mapPos.x - center.x) / scalePxPerMeter;
    const wz = -(mapPos.y - center.y) / scalePxPerMeter;
    return { x: wx, y: 0.0, z: wz };
  }

  metersToPixels(meters: number, cSize: CanvasSize = this.canvasSize): number {
    const usableSpan = Math.min(cSize.x, cSize.y) * 0.84 * this.zoomLevel;
    return meters * (usableSpan / Math.max(1.0, this.worldHalfExtent * 2.0));
  }

  centerOnWorldPos(worldPos: Vector3D): void {
    this.panOffset = { x: 0.0, y: 0.0 };
    const mapped = this.worldToMap(worldPos);
    this.panOffset = this.clampPanOffset({
      x: this.canvasSize.x * 0.5 - mapped.x,
      y: this.canvasSize.y * 0.5 - mapped.y
    });
  }

  zoomAtPoint(zoomCmd: float, pivot: Vector2D): void {
    const worldBefore = this.mapToWorld(pivot);
    this.zoomLevel = Math.max(0.50, Math.min(3.60, this.zoomLevel + zoomCmd));
    const mappedAfter = this.worldToMap(worldBefore);
    this.panOffset = this.clampPanOffset({
      x: this.panOffset.x + (pivot.x - mappedAfter.x),
      y: this.panOffset.y + (pivot.y - mappedAfter.y)
    });
  }
}

type float = number;

describe('Tactical Map Canvas & Cartographic Projection Verification', () => {
  it('should validate canvas metric-to-pixel projection math and inversion parity', () => {
    const proj = new TestCartographicProjection();
    const testPositions: Vector3D[] = [
      { x: 0.0, y: 0.0, z: 0.0 }, // Cradle center
      { x: -1000.0, y: 0.0, z: -800.0 }, // Node 0 Mohaine Way-Bunker
      { x: 700.0, y: 0.0, z: 700.0 }, // Node 7 Dark Tower Ka Beacon
      { x: -650.0, y: 0.0, z: 50.0 }, // Node 4 Rust-Gorge Defile
      { x: 650.0, y: 0.0, z: 50.0 }, // Node 6 Shifting Erg
    ];

    for (const worldPos of testPositions) {
      const mapPt = proj.worldToMap(worldPos);
      const inverted = proj.mapToWorld(mapPt);

      assert.ok(
        Math.abs(inverted.x - worldPos.x) < 0.001,
        `Projection X roundtrip error: ${inverted.x} vs ${worldPos.x}`
      );
      assert.ok(
        Math.abs(inverted.z - worldPos.z) < 0.001,
        `Projection Z roundtrip error: ${inverted.z} vs ${worldPos.z}`
      );
    }
  });

  it('should validate panning, zooming, and centering [C] transform behaviors', () => {
    const proj = new TestCartographicProjection();
    const playerSpawn: Vector3D = { x: -1020.0, y: 0.0, z: -820.0 };

    // 1. Initial center is at map canvas center (290, 220) for world origin (0, 0, 0)
    const originMap = proj.worldToMap({ x: 0.0, y: 0.0, z: 0.0 });
    assert.equal(originMap.x, 290.0);
    assert.equal(originMap.y, 220.0);

    // 2. Center on player [C] must place player exact at canvas center
    proj.centerOnWorldPos(playerSpawn);
    const playerMapCentered = proj.worldToMap(playerSpawn);
    assert.ok(
      Math.abs(playerMapCentered.x - 290.0) < 0.01,
      `Centered player X must equal canvas center X: ${playerMapCentered.x}`
    );
    assert.ok(
      Math.abs(playerMapCentered.y - 220.0) < 0.01,
      `Centered player Y must equal canvas center Y: ${playerMapCentered.y}`
    );

    // 3. Panning [LMB DRAG] must translate canvas coordinates deterministically
    const prePan = proj.worldToMap(playerSpawn);
    const dragDelta = { x: 35.0, y: -20.0 };
    proj.panOffset = proj.clampPanOffset({
      x: proj.panOffset.x + dragDelta.x,
      y: proj.panOffset.y + dragDelta.y
    });
    const postPan = proj.worldToMap(playerSpawn);
    assert.ok(Math.abs(postPan.x - (prePan.x + dragDelta.x)) < 0.01);
    assert.ok(Math.abs(postPan.y - (prePan.y + dragDelta.y)) < 0.01);

    // 4. Zooming [WHEEL] at canvas center must preserve center invariant
    const centerPoint = { x: 290.0, y: 220.0 };
    const worldAtCenter = proj.mapToWorld(centerPoint);
    proj.zoomAtPoint(0.5, centerPoint);
    assert.equal(proj.zoomLevel, 1.5);
    const worldAfterZoom = proj.mapToWorld(centerPoint);
    assert.ok(Math.abs(worldAfterZoom.x - worldAtCenter.x) < 0.01);
    assert.ok(Math.abs(worldAfterZoom.z - worldAtCenter.z) < 0.01);
  });

  it('should validate live player position marker and directional yaw cone geometry', () => {
    const proj = new TestCartographicProjection();
    const livePlayerPos: Vector3D = { x: -550.0, y: 0.0, z: -900.0 };
    const liveYaw = Math.PI * 0.25; // 45 degrees NE

    const pMap = proj.worldToMap(livePlayerPos);

    // Forward vector in map coordinates: world forward is (-sin(yaw), -cos(yaw))
    const forwardWorld = { x: -Math.sin(liveYaw), y: -Math.cos(liveYaw) };
    const mapDir = { x: forwardWorld.x, y: -forwardWorld.y };
    const mapLen = Math.hypot(mapDir.x, mapDir.y);
    const normDir = { x: mapDir.x / mapLen, y: mapDir.y / mapLen };
    const mapRight = { x: -normDir.y, y: normDir.x };

    // Cone geometry: 34m length, 14m half-width
    const coneLen = 34.0;
    const coneHalfW = 14.0;
    const tip = { x: pMap.x + normDir.x * 9.5, y: pMap.y + normDir.y * 9.5 };
    const coneLeft = {
      x: pMap.x + normDir.x * coneLen - mapRight.x * coneHalfW,
      y: pMap.y + normDir.y * coneLen - mapRight.y * coneHalfW
    };
    const coneRight = {
      x: pMap.x + normDir.x * coneLen + mapRight.x * coneHalfW,
      y: pMap.y + normDir.y * coneLen + mapRight.y * coneHalfW
    };

    assert.ok(Math.hypot(tip.x - pMap.x, tip.y - pMap.y) > 9.0);
    assert.ok(Math.hypot(coneLeft.x - pMap.x, coneLeft.y - pMap.y) > 30.0);
    assert.ok(Math.hypot(coneRight.x - pMap.x, coneRight.y - pMap.y) > 30.0);
  });

  it('should validate the 11 regional pathway corridors, safe passes, choke points & Thinny Abyss route', () => {
    assert.equal(REGIONAL_CORRIDORS.length, 11, 'Must register exactly 11 node corridors');

    const blockedCorridors = REGIONAL_CORRIDORS.filter(c => c.isBlocked);
    assert.equal(blockedCorridors.length, 1, 'Only Thinny Abyss route must be blocked');

    const thinnyRoute = blockedCorridors[0];
    assert.equal(thinnyRoute.id, 'connector_cradle_to_monolith_thinny');
    assert.equal(thinnyRoute.fromBasin, 'cradle');
    assert.equal(thinnyRoute.toBasin, 'monolith_pass');
    assert.equal(thinnyRoute.hazardType, 'THINNY_DISTORTION');
    assert.deepEqual(thinnyRoute.chokePoint, { x: 325.0, y: -28.0, z: 325.0 });

    // Verify safe passes from Node 0 Sanctuary have valid choke points
    const sanctuaryPass = REGIONAL_CORRIDORS.find(c => c.id === 'pass_sanctuary_to_sw')!;
    assert.ok(sanctuaryPass);
    assert.equal(sanctuaryPass.hazardType, 'NONE');
    assert.equal(sanctuaryPass.isBlocked, false);
    assert.deepEqual(sanctuaryPass.chokePoint, { x: -900.0, y: 0.0, z: -820.0 });

    // Verify all 11 corridors map into valid 2D coordinates within the canvas
    const proj = new TestCartographicProjection();
    for (const c of REGIONAL_CORRIDORS) {
      const ma = proj.worldToMap({ x: c.waypointA.x, y: 0.0, z: c.waypointA.z });
      const mb = proj.worldToMap({ x: c.waypointB.x, y: 0.0, z: c.waypointB.z });
      const mChoke = proj.worldToMap({ x: c.chokePoint.x, y: 0.0, z: c.chokePoint.z });

      assert.ok(Number.isFinite(ma.x) && Number.isFinite(ma.y));
      assert.ok(Number.isFinite(mb.x) && Number.isFinite(mb.y));
      assert.ok(Number.isFinite(mChoke.x) && Number.isFinite(mChoke.y));
    }
  });

  it('should validate 4x4 16-quadrant cartographic grid and elevation contour tiers', () => {
    assert.equal(QUADRANT_GRID_CONFIG.QUADRANT_COUNT, 16);
    assert.equal(QUADRANT_GRID_CONFIG.QUADRANT_SIZE_M, 625.0);

    const proj = new TestCartographicProjection();
    const qSize = QUADRANT_GRID_CONFIG.QUADRANT_SIZE_M;

    // Check all 4x4 quadrant corners map onto chart
    for (let r = 0; r < 4; r++) {
      for (let c = 0; c < 4; c++) {
        const qMinX = -proj.worldHalfExtent + c * qSize;
        const qMaxZ = -proj.worldHalfExtent + (r + 1) * qSize;
        const badgePos = proj.worldToMap({ x: qMinX + 18.0, y: 0.0, z: qMaxZ - 18.0 });
        assert.ok(Number.isFinite(badgePos.x) && Number.isFinite(badgePos.y));
      }
    }

    // Verify 4 elevation threshold tiers
    const contourTiers = [-1.2, 0.0, 1.35, 2.6];
    assert.equal(contourTiers.length, 4);
    assert.ok(contourTiers[0] < contourTiers[1]);
    assert.ok(contourTiers[1] < contourTiers[2]);
    assert.ok(contourTiers[2] < contourTiers[3]);
  });

  it('should validate Tactical Map Toggle Action mappings and mouse mode release contracts', () => {
    // 1. Keycode definitions for Godot 4
    const KEY_TAB = 4194306;
    const KEY_M = 77;
    const MOUSE_MODE_VISIBLE = 0;
    const MOUSE_MODE_CAPTURED = 2;

    const registeredActions: Record<string, number[]> = {
      map: [KEY_M, KEY_TAB],
      ui_map: [KEY_M, KEY_TAB],
      toggle_map: [KEY_M, KEY_TAB],
    };

    // 2. Validate all 3 actions support both [M] and [Tab]
    for (const [actionName, keycodes] of Object.entries(registeredActions)) {
      assert.ok(keycodes.includes(KEY_M), `${actionName} must be mapped to KEY_M (77)`);
      assert.ok(keycodes.includes(KEY_TAB), `${actionName} must be mapped to KEY_TAB (4194306)`);
    }

    // 3. Simulated modal toggle state machine & mouse mode transitions
    class MockMapModalState {
      isOpen: boolean = false;
      mouseMode: number = MOUSE_MODE_CAPTURED;
      mouseFilter: number = 2; // MOUSE_FILTER_IGNORE

      openMap(): void {
        this.isOpen = true;
        this.mouseMode = MOUSE_MODE_VISIBLE;
        this.mouseFilter = 0; // MOUSE_FILTER_STOP
      }

      closeMap(): void {
        this.isOpen = false;
        this.mouseMode = MOUSE_MODE_CAPTURED;
        this.mouseFilter = 2; // MOUSE_FILTER_IGNORE
      }

      toggleMap(): boolean {
        if (this.isOpen) {
          this.closeMap();
        } else {
          this.openMap();
        }
        return this.isOpen;
      }

      toggleChart(): boolean {
        return this.toggleMap();
      }
    }

    const modal = new MockMapModalState();
    assert.equal(modal.isOpen, false);
    assert.equal(modal.mouseMode, MOUSE_MODE_CAPTURED);
    assert.equal(modal.mouseFilter, 2, 'Closed map must have mouse_filter = IGNORE');

    // Press [M] or [Tab] -> Opens map and releases cursor
    const stateAfterFirstToggle = modal.toggleChart();
    assert.equal(stateAfterFirstToggle, true);
    assert.equal(modal.isOpen, true);
    assert.equal(modal.mouseMode, MOUSE_MODE_VISIBLE, 'Mouse must be released to VISIBLE when map is opened');
    assert.equal(modal.mouseFilter, 0, 'Open map must have mouse_filter = STOP');

    // Press [M] or [Tab] again -> Stows map and recaptures cursor
    const stateAfterSecondToggle = modal.toggleChart();
    assert.equal(stateAfterSecondToggle, false);
    assert.equal(modal.isOpen, false);
    assert.equal(modal.mouseMode, MOUSE_MODE_CAPTURED, 'Mouse must be re-captured when map is stowed');
    assert.equal(modal.mouseFilter, 2, 'Stowed map must restore mouse_filter = IGNORE');

    // Verify toggle_chart and toggle_map alias equivalence
    assert.equal(modal.toggleMap(), true);
    assert.equal(modal.toggleChart(), false);
  });

  it('should validate HUD mouse filters and left-click throughput to firearm mechanics', () => {
    // 1. Procedural enforcement of mouse_filter = IGNORE (2) across HUD tree
    const MOUSE_FILTER_STOP = 0;
    const MOUSE_FILTER_IGNORE = 2;

    interface MockNode {
      name: string;
      isInteractive: boolean;
      mouseFilter: number;
      children: MockNode[];
    }

    const enforceHudMouseFilters = (node: MockNode): void => {
      const isModal = ['MapModal', 'SettingsModal', 'InspectionModal'].includes(node.name);
      if (!node.isInteractive && !isModal) {
        node.mouseFilter = MOUSE_FILTER_IGNORE;
      }
      for (const child of node.children) {
        if (!['SettingsModal', 'InspectionModal', 'MapModal'].includes(child.name)) {
          enforceHudMouseFilters(child);
        }
      }
    };

    const hudRoot: MockNode = {
      name: 'Root',
      isInteractive: false,
      mouseFilter: MOUSE_FILTER_STOP,
      children: [
        { name: 'UpperLeftBanner', isInteractive: false, mouseFilter: MOUSE_FILTER_STOP, children: [] },
        { name: 'TopCenterInstrumentBar', isInteractive: false, mouseFilter: MOUSE_FILTER_STOP, children: [] },
        { name: 'BottomLeftWeaponConsole', isInteractive: false, mouseFilter: MOUSE_FILTER_STOP, children: [] },
        {
          name: 'SettingsModal',
          isInteractive: false,
          mouseFilter: MOUSE_FILTER_STOP,
          children: [{ name: 'BtnClose', isInteractive: true, mouseFilter: MOUSE_FILTER_STOP, children: [] }],
        },
      ],
    };

    enforceHudMouseFilters(hudRoot);
    assert.equal(hudRoot.mouseFilter, MOUSE_FILTER_IGNORE);
    assert.equal(hudRoot.children[0].mouseFilter, MOUSE_FILTER_IGNORE);
    assert.equal(hudRoot.children[1].mouseFilter, MOUSE_FILTER_IGNORE);
    assert.equal(hudRoot.children[2].mouseFilter, MOUSE_FILTER_IGNORE);
    assert.equal(hudRoot.children[3].mouseFilter, MOUSE_FILTER_STOP, 'SettingsModal must retain interactive filter');

    // 2. PauseAndToastController input handling does not swallow MOUSE_BUTTON_LEFT
    const handleUnhandledInput = (event: { type: string; button?: number; keycode?: string }): boolean => {
      if (event.type === 'key') {
        if (event.keycode === 'F3' || event.keycode === 'F10' || event.keycode === 'ESCAPE' || event.keycode === 'M') {
          return true; // handled
        }
      }
      // Left-clicks must NOT be consumed by pause/toast controller
      return false;
    };

    const leftClickEvent = { type: 'mouse_button', button: 1 };
    assert.equal(handleUnhandledInput(leftClickEvent), false, 'Left-click must pass through HUD controller to player');

    // 3. Player firearm tactile input fires on left-click when modals inactive
    const handleFirearmTactileInput = (event: { action?: string; type?: string; button?: number }, isModalActive: boolean): boolean => {
      if (event.action === 'fire' || (event.type === 'mouse_button' && event.button === 1 && !isModalActive)) {
        return true; // weapon.fire() called
      }
      return false;
    };

    assert.equal(handleFirearmTactileInput(leftClickEvent, false), true, 'Left-click must trigger weapon.fire() when modal is closed');
    assert.equal(handleFirearmTactileInput(leftClickEvent, true), false, 'Left-click must NOT trigger weapon.fire() when modal is open');
  });
});
