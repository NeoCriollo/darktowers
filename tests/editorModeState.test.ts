/**
 * Editor Mode State Machine & Input Routing Test Suite — "Dark Towers: The Path of Ka"
 * Task 1 & 2: State Machine Isolation, Input Bleed Prevention & Persistence Parity
 *
 * Verifies mutual exclusivity between WALK and EDITOR_FLIGHT modes,
 * validates input action isolation, and confirms on-disk Godot parity.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  EditorModeStateMachine,
  DEDICATED_EDITOR_MODE_KEY,
  MODE_CAPABILITIES,
} from '../world/editorModeState.ts';
import type { InputAction } from '../world/editorModeState.ts';

const REPO_ROOT = process.cwd();

describe('Editor Mode State Machine & Input Isolation (Tasks 1 & 2)', () => {
  it('should initialize with WALK mode by default and correct baseline capabilities', () => {
    const sm = new EditorModeStateMachine('WALK');
    assert.strictEqual(sm.currentMode, 'WALK');
    assert.strictEqual(sm.isWalkActive(), true);
    assert.strictEqual(sm.isEditorActive(), false);

    const caps = sm.capabilities;
    assert.strictEqual(caps.gravityEnabled, true);
    assert.strictEqual(caps.groundSnappingEnabled, true);
    assert.strictEqual(caps.playerColliderEnabled, true);
    assert.strictEqual(caps.flight6DoFEnabled, false);
    assert.strictEqual(caps.raycastSelectionEnabled, false);
    assert.strictEqual(caps.assetCatalogAccessible, false);
    assert.strictEqual(caps.reconMapAccessible, true);
    assert.strictEqual(caps.hudType, 'GAMEPLAY_HUD');
  });

  it('should enforce strict mutual exclusivity when transitioning to EDITOR_FLIGHT mode', () => {
    const sm = new EditorModeStateMachine('WALK');
    const newMode = sm.toggleMode();

    assert.strictEqual(newMode, 'EDITOR_FLIGHT');
    assert.strictEqual(sm.currentMode, 'EDITOR_FLIGHT');
    assert.strictEqual(sm.isEditorActive(), true);
    assert.strictEqual(sm.isWalkActive(), false);

    const caps = sm.capabilities;
    assert.strictEqual(caps.gravityEnabled, false, 'Gravity must be disabled in editor flight mode');
    assert.strictEqual(caps.groundSnappingEnabled, false, 'Ground snapping must be disabled in editor flight mode');
    assert.strictEqual(caps.playerColliderEnabled, false, 'Player collision must be disabled in editor flight mode');
    assert.strictEqual(caps.flight6DoFEnabled, true, '6DoF flight must be enabled in editor flight mode');
    assert.strictEqual(caps.raycastSelectionEnabled, true, 'Raycast hover/selection must be enabled in editor flight mode');
    assert.strictEqual(caps.assetCatalogAccessible, true, 'Asset catalog must be accessible in editor flight mode');
    assert.strictEqual(caps.reconMapAccessible, false, 'Recon map must be disabled in editor flight mode');
    assert.strictEqual(caps.hudType, 'EDITOR_HUD');
  });

  it('should isolate input actions and prevent action bleed across modes', () => {
    const sm = new EditorModeStateMachine('WALK');

    // 1. In WALK mode: Gameplay actions allowed, Editor actions rejected
    const walkAllowed: InputAction[] = [
      'move_ground',
      'sprint',
      'crouch',
      'jump',
      'fire',
      'aim',
      'reload',
      'clear_jam',
      'tactical_shoulder_swap',
      'field_gunsmith_inspect',
      'toggle_recon_map',
    ];
    for (const act of walkAllowed) {
      assert.strictEqual(sm.isActionAllowed(act), true, `Action "${act}" must be allowed in WALK mode`);
    }

    const walkRejected: InputAction[] = [
      'flight_6dof',
      'speed_scaling_wheel',
      'speed_fast_shift',
      'speed_crawl_alt',
      'raycast_hover_and_select',
      'manipulator_grab_and_carry',
      'toggle_palette',
      'toggle_outliner',
      'save_world_layout',
    ];
    for (const act of walkRejected) {
      assert.strictEqual(sm.isActionAllowed(act), false, `Action "${act}" must be rejected in WALK mode`);
    }

    // 2. Transition to EDITOR_FLIGHT
    sm.setMode('EDITOR_FLIGHT');

    // In EDITOR_FLIGHT mode: Editor actions allowed, Gameplay actions rejected
    for (const act of walkRejected) {
      assert.strictEqual(sm.isActionAllowed(act), true, `Action "${act}" must be allowed in EDITOR_FLIGHT mode`);
    }
    for (const act of walkAllowed) {
      assert.strictEqual(sm.isActionAllowed(act), false, `Action "${act}" must be rejected in EDITOR_FLIGHT mode`);
    }

    // Dedicated mode toggle must be available in BOTH modes
    assert.strictEqual(sm.isActionAllowed('toggle_editor_mode'), true);
    assert.strictEqual(sm.isActionAllowed('pause_menu'), true);
  });

  it('should contextually route the [TAB] key without collision between modes', () => {
    const sm = new EditorModeStateMachine('WALK');
    assert.strictEqual(sm.resolveTabKeyBehavior(), 'TOGGLE_RECON_MAP', '[TAB] in WALK mode must toggle recon map');

    sm.setMode('EDITOR_FLIGHT');
    assert.strictEqual(sm.resolveTabKeyBehavior(), 'TOGGLE_PALETTE', '[TAB] in EDITOR_FLIGHT mode must toggle asset palette');
  });

  it('should verify the [V] key is normalized to clear_jam and never toggles flight mode', () => {
    const sm = new EditorModeStateMachine('WALK');
    assert.strictEqual(sm.resolveVKeyBehavior(), 'CLEAR_JAM', '[V] in WALK mode must be firearm jam clearance');

    sm.setMode('EDITOR_FLIGHT');
    assert.strictEqual(sm.resolveVKeyBehavior(), 'IGNORED', '[V] in EDITOR_FLIGHT mode must not trigger weapon clearing or flight toggle');

    // Dedicated mode toggle is routed to [F6]
    assert.strictEqual(sm.resolveF6KeyBehavior(), 'TOGGLE_EDITOR_MODE');
    assert.strictEqual(DEDICATED_EDITOR_MODE_KEY.actionName, 'toggle_editor_mode');
    assert.strictEqual(DEDICATED_EDITOR_MODE_KEY.primaryPhysicalKey, 'F6');
    assert.strictEqual(DEDICATED_EDITOR_MODE_KEY.godotPhysicalCode, 4194337);
  });

  it('should correctly serialize and deserialize active mode state across persistence cycles', () => {
    const sm = new EditorModeStateMachine('WALK');
    sm.setSpeedMultiplier(2.5);

    // Initial walk state serialization
    const walkCfg = sm.serializeToConfig();
    assert.strictEqual(walkCfg.game_mode.is_editor_mode_active, false);

    // Toggle to editor flight and serialize
    sm.toggleMode();
    const editorCfg = sm.serializeToConfig();
    assert.strictEqual(editorCfg.game_mode.is_editor_mode_active, true);
    assert.strictEqual(editorCfg.journey.speed_multiplier, 2.5);

    // Deserialize into fresh instance
    const restoredSM = new EditorModeStateMachine('WALK');
    assert.strictEqual(restoredSM.isEditorActive(), false);
    restoredSM.deserializeFromConfig(editorCfg);
    assert.strictEqual(restoredSM.isEditorActive(), true);
    assert.strictEqual(restoredSM.speedMultiplier, 2.5);
  });

  it('should validate on-disk Godot configuration and GDScript contracts for editor mode', () => {
    // 1. Verify project.godot contains toggle_editor_mode with physical keycode 4194337 (F6)
    const godotPath = path.join(REPO_ROOT, 'project.godot');
    assert.ok(fs.existsSync(godotPath), 'project.godot must exist');
    const godotContent = fs.readFileSync(godotPath, 'utf-8');
    assert.ok(godotContent.includes('toggle_editor_mode={'), 'project.godot must define toggle_editor_mode action');
    assert.ok(godotContent.includes('"physical_keycode":4194337'), 'toggle_editor_mode must map to F6 (4194337)');

    // 2. Verify world_save_data.gd persists is_editor_mode_active and has editor_mode_toggled signal
    const wsdPath = path.join(REPO_ROOT, 'world_save_data.gd');
    assert.ok(fs.existsSync(wsdPath), 'world_save_data.gd must exist');
    const wsdContent = fs.readFileSync(wsdPath, 'utf-8');
    assert.ok(wsdContent.includes('signal editor_mode_toggled(active: bool)'), 'world_save_data.gd must declare editor_mode_toggled signal');
    assert.ok(wsdContent.includes('is_editor_mode_active'), 'world_save_data.gd must reference is_editor_mode_active');
    assert.ok(wsdContent.includes('toggle_editor_mode'), 'world_save_data.gd must declare toggle_editor_mode');

    // 3. Verify world.gd initializes editor_flight_controller and connects to editor_mode_toggled
    const worldPath = path.join(REPO_ROOT, 'world.gd');
    assert.ok(fs.existsSync(worldPath), 'world.gd must exist');
    const worldContent = fs.readFileSync(worldPath, 'utf-8');
    assert.ok(worldContent.includes('editor_flight_controller'), 'world.gd must track editor_flight_controller');
    assert.ok(worldContent.includes('_on_editor_mode_toggled'), 'world.gd must handle _on_editor_mode_toggled');

    // 4. Verify player.gd zeroes velocity and bypasses physics process when editor mode is active
    const playerPath = path.join(REPO_ROOT, 'player.gd');
    assert.ok(fs.existsSync(playerPath), 'player.gd must exist');
    const playerContent = fs.readFileSync(playerPath, 'utf-8');
    assert.ok(playerContent.includes('if WorldSaveData.is_editor_active():'), 'player.gd must check WorldSaveData.is_editor_active()');
    assert.ok(playerContent.includes('toggle_editor_mode'), 'player.gd must listen for toggle_editor_mode action');

    // 5. Verify editor_flight_controller.gd does NOT use KEY_V for flight toggle
    const efcPath = path.join(REPO_ROOT, 'world', 'editor', 'editor_flight_controller.gd');
    assert.ok(fs.existsSync(efcPath), 'editor_flight_controller.gd must exist');
    const efcContent = fs.readFileSync(efcPath, 'utf-8');
    assert.ok(!efcContent.includes('and event.keycode == KEY_V:'), 'editor_flight_controller.gd must not bind flight toggle to KEY_V');
    assert.ok(efcContent.includes('toggle_editor_mode'), 'editor_flight_controller.gd must bind to toggle_editor_mode');

    // 6. Verify pause_and_toast_controller does not intercept TAB when in editor mode
    const ptcPath = path.join(REPO_ROOT, 'ui', 'pause_and_toast_controller.gd');
    assert.ok(fs.existsSync(ptcPath), 'pause_and_toast_controller.gd must exist');
    const ptcContent = fs.readFileSync(ptcPath, 'utf-8');
    assert.ok(ptcContent.includes('if WorldSaveData.is_editor_active(): return false'), 'pause_and_toast_controller.gd must not intercept map in editor mode');
  });
});
