/**
 * Unit Tests for Editor Mode UI & Input Isolation (Modo Arquitecto Handoff)
 *
 * Validates deterministic mode swapping between Survival Mode and Editor Flight Mode:
 *   - Immediate hiding of Survival HUD, weapon console, and crosshair upon entering Editor Mode.
 *   - Activation of Editor HUD overlay and handoff to 6DoF Flight Controller.
 *   - Player collision shape deactivation, visual/weapon viewmodel hiding, and spring arm collapse.
 *   - Clean restoration of Survival Mode upon exit.
 *   - On-disk GDScript source contracts across ui.gd, pause_and_toast_controller.gd, player.gd,
 *     and editor_flight_controller.gd.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  createInitialIsolationState,
  transitionIsolationMode,
  validateIsolationInvariants,
  resolveSurvivalHUDVisibility,
  resolvePlayerPhysicsHandoff,
  resolveFlightControllerHandoff,
  SURVIVAL_CAMERA_SPRING_LENGTH,
  EDITOR_CAMERA_SPRING_LENGTH,
  SURVIVAL_CAMERA_OFFSET_RIGHT,
  EDITOR_CAMERA_OFFSET_CENTER,
  type EditorModeIsolationState
} from '../world/editorModeIsolation.ts';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '..');

describe('Editor Mode UI & Input Isolation Contracts (Modo Arquitecto)', () => {
  it('should initialize with standard survival mode baseline settings', () => {
    const state: EditorModeIsolationState = createInitialIsolationState(false);
    assert.strictEqual(state.isEditorActive, false);

    // Survival HUD must be fully visible
    assert.strictEqual(state.survivalHUD.topCenterVitals, true);
    assert.strictEqual(state.survivalHUD.weaponConsole, true);
    assert.strictEqual(state.survivalHUD.crosshair, true);
    assert.strictEqual(state.survivalHUD.upperLeftBanner, true);
    assert.strictEqual(state.survivalHUD.conditionStack, true);
    assert.strictEqual(state.survivalHUD.tacticalRadar, true);

    // Editor HUD must be inactive
    assert.strictEqual(state.editorHUD.overlayVisible, false);
    assert.strictEqual(state.editorHUD.paletteDrawerVisible, false);
    assert.strictEqual(state.editorHUD.outlinerVisible, false);

    // Player physics must be active
    assert.strictEqual(state.playerPhysics.collisionEnabled, true);
    assert.strictEqual(state.playerPhysics.meshVisualsVisible, true);
    assert.strictEqual(state.playerPhysics.weaponViewmodelVisible, true);
    assert.strictEqual(state.playerPhysics.physicsProcessEnabled, true);
    assert.strictEqual(state.playerPhysics.cameraCurrent, true);
    assert.strictEqual(state.playerPhysics.isFrozen, false);
    assert.strictEqual(state.playerPhysics.inputProcessEnabled, true);
    assert.strictEqual(state.playerPhysics.cameraSpringLength, SURVIVAL_CAMERA_SPRING_LENGTH);
    assert.deepStrictEqual(state.playerPhysics.cameraOffset, SURVIVAL_CAMERA_OFFSET_RIGHT);

    // Flight controller must be inactive
    assert.strictEqual(state.flightController.flightActive, false);
    assert.strictEqual(state.flightController.mouseLookPriority, 'player');
    assert.strictEqual(state.flightController.cameraAuthority, false);
    assert.strictEqual(state.flightController.physicsProcessEnabled, false);
    assert.strictEqual(state.flightController.driftVelocityZeroed, true);

    const inv = validateIsolationInvariants(state);
    assert.strictEqual(inv.isValid, true);
    assert.strictEqual(inv.violations.length, 0);
  });

  it('should completely isolate and hide survival HUD and viewmodels when entering editor mode', () => {
    const initial = createInitialIsolationState(false);
    const editorState = transitionIsolationMode(initial, true);

    assert.strictEqual(editorState.isEditorActive, true);

    // All survival HUD components must be forced hidden
    assert.strictEqual(editorState.survivalHUD.topCenterVitals, false);
    assert.strictEqual(editorState.survivalHUD.weaponConsole, false);
    assert.strictEqual(editorState.survivalHUD.crosshair, false);
    assert.strictEqual(editorState.survivalHUD.upperLeftBanner, false);
    assert.strictEqual(editorState.survivalHUD.conditionStack, false);
    assert.strictEqual(editorState.survivalHUD.tacticalRadar, false);
    assert.strictEqual(editorState.survivalHUD.jamBanner, false);
    assert.strictEqual(editorState.survivalHUD.inspectionModal, false);

    // Editor HUD overlay must be active
    assert.strictEqual(editorState.editorHUD.overlayVisible, true);

    // Player collision, meshes, and viewmodels must be disabled
    assert.strictEqual(editorState.playerPhysics.collisionEnabled, false);
    assert.strictEqual(editorState.playerPhysics.meshVisualsVisible, false);
    assert.strictEqual(editorState.playerPhysics.weaponViewmodelVisible, false);
    assert.strictEqual(editorState.playerPhysics.physicsProcessEnabled, false);
    assert.strictEqual(editorState.playerPhysics.cameraCurrent, false);
    assert.strictEqual(editorState.playerPhysics.isFrozen, true);
    assert.strictEqual(editorState.playerPhysics.inputProcessEnabled, false);
    assert.strictEqual(editorState.playerPhysics.cameraSpringLength, EDITOR_CAMERA_SPRING_LENGTH);
    assert.deepStrictEqual(editorState.playerPhysics.cameraOffset, EDITOR_CAMERA_OFFSET_CENTER);

    // Flight controller must take 100% priority
    assert.strictEqual(editorState.flightController.flightActive, true);
    assert.strictEqual(editorState.flightController.mouseLookPriority, 'flight');
    assert.strictEqual(editorState.flightController.paletteInputEnabled, true);
    assert.strictEqual(editorState.flightController.cameraAuthority, true);
    assert.strictEqual(editorState.flightController.physicsProcessEnabled, true);
    assert.strictEqual(editorState.flightController.driftVelocityZeroed, false);

    const inv = validateIsolationInvariants(editorState);
    assert.strictEqual(inv.isValid, true);
    assert.strictEqual(inv.violations.length, 0);
  });

  it('should cleanly restore all survival mode components and camera when returning to survival', () => {
    const editorState = createInitialIsolationState(true);
    const restoredSurvival = transitionIsolationMode(editorState, false);

    assert.strictEqual(restoredSurvival.isEditorActive, false);
    assert.strictEqual(restoredSurvival.survivalHUD.topCenterVitals, true);
    assert.strictEqual(restoredSurvival.survivalHUD.weaponConsole, true);
    assert.strictEqual(restoredSurvival.survivalHUD.crosshair, true);
    assert.strictEqual(restoredSurvival.editorHUD.overlayVisible, false);

    assert.strictEqual(restoredSurvival.playerPhysics.collisionEnabled, true);
    assert.strictEqual(restoredSurvival.playerPhysics.meshVisualsVisible, true);
    assert.strictEqual(restoredSurvival.playerPhysics.weaponViewmodelVisible, true);
    assert.strictEqual(restoredSurvival.playerPhysics.physicsProcessEnabled, true);
    assert.strictEqual(restoredSurvival.playerPhysics.cameraCurrent, true);
    assert.strictEqual(restoredSurvival.playerPhysics.isFrozen, false);
    assert.strictEqual(restoredSurvival.playerPhysics.inputProcessEnabled, true);
    assert.strictEqual(restoredSurvival.playerPhysics.cameraSpringLength, SURVIVAL_CAMERA_SPRING_LENGTH);

    assert.strictEqual(restoredSurvival.flightController.flightActive, false);
    assert.strictEqual(restoredSurvival.flightController.mouseLookPriority, 'player');
    assert.strictEqual(restoredSurvival.flightController.cameraAuthority, false);
    assert.strictEqual(restoredSurvival.flightController.physicsProcessEnabled, false);
    assert.strictEqual(restoredSurvival.flightController.driftVelocityZeroed, true);

    const inv = validateIsolationInvariants(restoredSurvival);
    assert.strictEqual(inv.isValid, true);
  });

  it('should reject invalid mixed states where survival and editor elements co-exist', () => {
    // Malformed state: editor active but survival vitals still visible
    const corruptedState: EditorModeIsolationState = {
      isEditorActive: true,
      survivalHUD: { ...resolveSurvivalHUDVisibility(true), topCenterVitals: true },
      editorHUD: { overlayVisible: true, paletteDrawerVisible: false, outlinerVisible: false },
      playerPhysics: resolvePlayerPhysicsHandoff(true),
      flightController: resolveFlightControllerHandoff(true)
    };

    const result = validateIsolationInvariants(corruptedState);
    assert.strictEqual(result.isValid, false);
    assert.ok(result.violations.some((v) => v.includes('topCenterVitals must be hidden')));

    // Malformed state: editor active but player collision still enabled
    const colliderCorrupted: EditorModeIsolationState = {
      ...corruptedState,
      survivalHUD: resolveSurvivalHUDVisibility(true),
      playerPhysics: { ...resolvePlayerPhysicsHandoff(true), collisionEnabled: true }
    };
    const colResult = validateIsolationInvariants(colliderCorrupted);
    assert.strictEqual(colResult.isValid, false);
    assert.ok(colResult.violations.some((v) => v.includes('collisionShape must be disabled')));
  });

  it('should validate on-disk GDScript source contracts for mode swapping orchestration', () => {
    // 1. Verify ui.gd connects to WorldSaveData.editor_mode_toggled and delegates to sub-controller
    const uiPath = path.join(REPO_ROOT, 'ui.gd');
    assert.ok(fs.existsSync(uiPath), 'ui.gd must exist');
    const uiContent = fs.readFileSync(uiPath, 'utf-8');
    assert.ok(
      uiContent.includes('editor_mode_toggled.connect') || uiContent.includes('_on_editor_mode_toggled'),
      'ui.gd must listen to WorldSaveData.editor_mode_toggled'
    );

    // 2. Verify ui/pause_and_toast_controller.gd implements set_editor_mode_ui_state and set_survival_hud_visible
    const ptcPath = path.join(REPO_ROOT, 'ui', 'pause_and_toast_controller.gd');
    assert.ok(fs.existsSync(ptcPath), 'pause_and_toast_controller.gd must exist');
    const ptcContent = fs.readFileSync(ptcPath, 'utf-8');
    assert.ok(
      ptcContent.includes('set_editor_mode_ui_state') || ptcContent.includes('set_survival_hud_visible'),
      'pause_and_toast_controller.gd must implement UI mode swapping orchestration'
    );

    // 3. Verify player.gd connects to WorldSaveData.editor_mode_toggled and properly restores physics/camera on reversion
    const playerPath = path.join(REPO_ROOT, 'player.gd');
    assert.ok(fs.existsSync(playerPath), 'player.gd must exist');
    const playerContent = fs.readFileSync(playerPath, 'utf-8');
    assert.ok(
      playerContent.includes('editor_mode_toggled') || playerContent.includes('_on_editor_mode_toggled'),
      'player.gd must connect to editor_mode_toggled'
    );
    assert.ok(playerContent.includes('is_frozen = false'), 'player.gd must unfreeze character on reversion to survival');
    assert.ok(playerContent.includes('camera.current = true'), 'player.gd must regain camera authority on reversion to survival');
    assert.ok(playerContent.includes('set_physics_process(true)'), 'player.gd must resume physics on reversion to survival');
    assert.ok(playerContent.includes('set_process_input(true)'), 'player.gd must resume input handling on reversion to survival');

    // 4. Verify world/editor/editor_flight_controller.gd yields camera authority, zeros drift velocity, and collapses spring arm
    const efcPath = path.join(REPO_ROOT, 'world', 'editor', 'editor_flight_controller.gd');
    assert.ok(fs.existsSync(efcPath), 'editor_flight_controller.gd must exist');
    const efcContent = fs.readFileSync(efcPath, 'utf-8');
    assert.ok(
      efcContent.includes('spring_length = 0.0') || efcContent.includes('spring_length = 0'),
      'editor_flight_controller.gd must collapse spring arm to 0.0m in flight'
    );
    assert.ok(
      efcContent.includes('_current_velocity = Vector3.ZERO'),
      'editor_flight_controller.gd must zero drift velocity when deactivating'
    );
    assert.ok(
      efcContent.includes('current = false'),
      'editor_flight_controller.gd must yield camera authority when deactivating'
    );
    assert.ok(
      efcContent.includes('func _is_flight_key_commanded(keycode: int) -> bool:'),
      'editor_flight_controller.gd must gate flight movement on explicit key commands (_is_flight_key_commanded)'
    );
    assert.ok(
      !efcContent.includes('elif is_ctrl'),
      'editor_flight_controller.gd must never map Ctrl/Cmd modifier keys to downward flight descent'
    );
  });

  it('should verify bidirectional handoff and deadlock prevention across repeated mode toggles', () => {
    let state = createInitialIsolationState(false);
    assert.strictEqual(state.isEditorActive, false);
    assert.strictEqual(state.playerPhysics.isFrozen, false);
    assert.strictEqual(state.playerPhysics.cameraCurrent, true);

    // Toggle 1: Survival -> Editor
    state = transitionIsolationMode(state, true);
    assert.strictEqual(state.isEditorActive, true);
    assert.strictEqual(state.playerPhysics.isFrozen, true);
    assert.strictEqual(state.playerPhysics.cameraCurrent, false);
    assert.strictEqual(state.flightController.flightActive, true);
    assert.strictEqual(state.flightController.cameraAuthority, true);
    assert.strictEqual(validateIsolationInvariants(state).isValid, true);

    // Toggle 2: Editor -> Survival (Reversion)
    state = transitionIsolationMode(state, false);
    assert.strictEqual(state.isEditorActive, false);
    assert.strictEqual(state.playerPhysics.isFrozen, false);
    assert.strictEqual(state.playerPhysics.cameraCurrent, true);
    assert.strictEqual(state.playerPhysics.physicsProcessEnabled, true);
    assert.strictEqual(state.playerPhysics.inputProcessEnabled, true);
    assert.strictEqual(state.flightController.flightActive, false);
    assert.strictEqual(state.flightController.cameraAuthority, false);
    assert.strictEqual(state.flightController.driftVelocityZeroed, true);
    assert.strictEqual(validateIsolationInvariants(state).isValid, true);

    // Toggle 3: Survival -> Editor -> Survival
    state = transitionIsolationMode(state, true);
    state = transitionIsolationMode(state, false);
    assert.strictEqual(state.isEditorActive, false);
    assert.strictEqual(state.playerPhysics.isFrozen, false);
    assert.strictEqual(state.playerPhysics.cameraCurrent, true);
    assert.strictEqual(state.flightController.cameraAuthority, false);
    assert.strictEqual(validateIsolationInvariants(state).isValid, true);
  });
});

