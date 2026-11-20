/**
 * Dark Towers: The Path of Ka
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit Tests: Editor Mode Input Routing, Mouse Capture, & Key Exclusivity
 *
 * Verifies Task 1, 2, and 3 constraints:
 * - [M] (77) triggers Reconnaissance Map exclusively in Survival Mode.
 * - [TAB] (4194306) triggers Editor Asset Catalog Grid exclusively in Editor Mode.
 * - Zero collision / cross-triggering between map and catalog keys.
 * - Immediate mouse capture in Todash Flight Cam without requiring an extra click.
 * - On-disk project.godot input configuration integrity.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  PHYSICAL_KEYCODES,
  EditorInputRoutingContract,
} from '../world/editorInputRouting.ts';

describe('Editor Input Routing & Key Exclusivity Contracts', () => {
  it('should enforce strict key partition with zero collision between [M] and [TAB]', () => {
    const report = EditorInputRoutingContract.verifyKeyPartitionExclusivity();
    assert.equal(report.isExclusivelyPartitioned, true, 'Key partition must be exclusively partitioned');
    assert.equal(report.hasCollision, false, 'No collision permitted between map and catalog keys');
    assert.equal(report.reconMapKeyCode, 77, 'Recon Map must use keycode 77 (M)');
    assert.equal(report.editorCatalogKeyCode, 4194306, 'Editor Catalog must use keycode 4194306 (Tab)');
    assert.equal(report.violations.length, 0, 'Must have zero violations');
  });

  it('should route [M] to map modal in survival mode and close map when already open', () => {
    // 1. Open map from survival world
    const openDecision = EditorInputRoutingContract.routeKeyInput(
      PHYSICAL_KEYCODES.KEY_M,
      'SURVIVAL_WORLD'
    );
    assert.equal(openDecision.action, 'toggle_recon_map');
    assert.equal(openDecision.targetSubsystem, 'MAP_MODAL');
    assert.equal(openDecision.consumed, true);
    assert.equal(openDecision.mouseCaptureDesired, false, 'Opening map releases mouse look capture');

    // 2. Close map when already open
    const closeDecision = EditorInputRoutingContract.routeKeyInput(
      PHYSICAL_KEYCODES.KEY_M,
      'SURVIVAL_MAP_OPEN'
    );
    assert.equal(closeDecision.action, 'toggle_recon_map');
    assert.equal(closeDecision.targetSubsystem, 'MAP_MODAL');
    assert.equal(closeDecision.consumed, true);
    assert.equal(closeDecision.mouseCaptureDesired, true, 'Closing map re-engages mouse capture');
  });

  it('should completely suppress [M] map modal triggers when in Editor Mode', () => {
    const editorFlightDecision = EditorInputRoutingContract.routeKeyInput(
      PHYSICAL_KEYCODES.KEY_M,
      'EDITOR_FLIGHT'
    );
    assert.equal(editorFlightDecision.action, 'unhandled');
    assert.equal(editorFlightDecision.targetSubsystem, 'NONE');
    assert.equal(editorFlightDecision.consumed, false);
    assert.equal(editorFlightDecision.blocksReconMap, true, 'Must block recon map from opening in editor');

    const editorCatalogDecision = EditorInputRoutingContract.routeKeyInput(
      PHYSICAL_KEYCODES.KEY_M,
      'EDITOR_CATALOG_OPEN'
    );
    assert.equal(editorCatalogDecision.blocksReconMap, true);
  });

  it('should route [TAB] to editor asset catalog in editor flight and reject in survival mode', () => {
    // In Editor Flight, TAB opens catalog
    const openCatalogDecision = EditorInputRoutingContract.routeKeyInput(
      PHYSICAL_KEYCODES.KEY_TAB,
      'EDITOR_FLIGHT'
    );
    assert.equal(openCatalogDecision.action, 'toggle_editor_catalog');
    assert.equal(openCatalogDecision.targetSubsystem, 'EDITOR_ASSET_CATALOG');
    assert.equal(openCatalogDecision.consumed, true);
    assert.equal(openCatalogDecision.mouseCaptureDesired, false, 'Catalog needs cursor visible');

    // With Catalog open, TAB closes catalog and returns to flight capture
    const closeCatalogDecision = EditorInputRoutingContract.routeKeyInput(
      PHYSICAL_KEYCODES.KEY_TAB,
      'EDITOR_CATALOG_OPEN'
    );
    assert.equal(closeCatalogDecision.action, 'toggle_editor_catalog');
    assert.equal(closeCatalogDecision.targetSubsystem, 'EDITOR_ASSET_CATALOG');
    assert.equal(closeCatalogDecision.consumed, true);
    assert.equal(closeCatalogDecision.mouseCaptureDesired, true, 'Dismissing catalog restores flight capture');

    // In Survival Mode, TAB must NEVER open recon map
    const survivalDecision = EditorInputRoutingContract.routeKeyInput(
      PHYSICAL_KEYCODES.KEY_TAB,
      'SURVIVAL_WORLD'
    );
    assert.equal(survivalDecision.action, 'unhandled');
    assert.notEqual(survivalDecision.targetSubsystem, 'MAP_MODAL', 'TAB must never route to MAP_MODAL');
    assert.equal(survivalDecision.consumed, false);
  });

  it('should route [B] as alternate toggle for Editor Asset Catalog in editor mode', () => {
    const bDecision = EditorInputRoutingContract.routeKeyInput(
      PHYSICAL_KEYCODES.KEY_B,
      'EDITOR_FLIGHT'
    );
    assert.equal(bDecision.action, 'toggle_editor_catalog');
    assert.equal(bDecision.targetSubsystem, 'EDITOR_ASSET_CATALOG');
    assert.equal(bDecision.consumed, true);
  });

  it('should require immediate mouse capture upon flight camera engagement without extra click', () => {
    // When Editor Mode is activated and catalog is closed:
    const flightCapture = EditorInputRoutingContract.shouldCaptureMouseImmediately(true, false);
    assert.equal(flightCapture, true, 'Flight camera must immediately capture mouse without extra click');

    // When Catalog modal is open, mouse must be freed for clicking grid cards:
    const catalogCapture = EditorInputRoutingContract.shouldCaptureMouseImmediately(true, true);
    assert.equal(catalogCapture, false, 'Opening catalog must free mouse cursor');

    // When Editor Mode is inactive (survival mode):
    const survivalCapture = EditorInputRoutingContract.shouldCaptureMouseImmediately(false, false);
    assert.equal(survivalCapture, false, 'Editor flight controller should not capture when inactive');
  });

  it('should validate 100% compliance of on-disk project.godot input mapping', () => {
    const godotProjectPath = path.resolve(process.cwd(), 'project.godot');
    assert.ok(fs.existsSync(godotProjectPath), 'project.godot must exist on disk');

    const content = fs.readFileSync(godotProjectPath, 'utf8');
    const audit = EditorInputRoutingContract.auditProjectGodotContent(content);

    assert.equal(audit.isCompliant, true, `project.godot audit failed with errors: ${audit.errors.join('; ')}`);
    assert.equal(audit.reconMapHasOnlyM, true, 'toggle_recon_map must map to physical key 77 [M] and not [TAB]');
    assert.equal(audit.catalogHasTab, true, 'toggle_editor_catalog must map to physical key 4194306 [TAB]');
    assert.equal(audit.noTabInMapActions, true, 'Legacy map actions must not contain [TAB]');
  });

  it('should verify on-disk GDScript files enforce clean input isolation', () => {
    const flightControllerPath = path.resolve(process.cwd(), 'world/editor/editor_flight_controller.gd');
    assert.ok(fs.existsSync(flightControllerPath), 'editor_flight_controller.gd must exist');
    const flightContent = fs.readFileSync(flightControllerPath, 'utf8');

    // Verify flight controller captures mouse and sets process
    assert.ok(
      flightContent.includes('Input.mouse_mode = Input.MOUSE_MODE_CAPTURED'),
      'Flight controller must set MOUSE_MODE_CAPTURED'
    );
    assert.ok(
      flightContent.includes('set_process(_is_active)'),
      'Flight controller must activate process when active'
    );
    assert.ok(
      flightContent.includes('_camera_ref.current = true'),
      'Flight controller must set camera current = true when active'
    );

    // Verify map_modal.gd doesn't register TAB
    const mapModalPath = path.resolve(process.cwd(), 'map_modal.gd');
    const mapContent = fs.readFileSync(mapModalPath, 'utf8');
    assert.ok(!mapContent.includes('for code in [KEY_M, KEY_TAB]:'), 'map_modal.gd must not register KEY_TAB');
    assert.ok(mapContent.includes('for code in [KEY_M]:'), 'map_modal.gd must register KEY_M exclusively');

    // Verify player_camera_rig.gd uses exclusive binding
    const rigPath = path.resolve(process.cwd(), 'player/player_camera_rig.gd');
    const rigContent = fs.readFileSync(rigPath, 'utf8');
    assert.ok(
      rigContent.includes('_set_action_exclusive_keys("toggle_recon_map", [KEY_M])'),
      'player_camera_rig.gd must exclusively bind toggle_recon_map to KEY_M'
    );
    assert.ok(
      rigContent.includes('_set_action_exclusive_keys("toggle_editor_catalog", [KEY_TAB])'),
      'player_camera_rig.gd must bind toggle_editor_catalog to KEY_TAB'
    );
  });
});

