/**
 * Unit Tests for Universal Pause Menu & Sunny Day High-Visibility Lighting Override (Task 3)
 * Validates Pause State toggling, Mouse Mode contracts, Sunny Day lighting parameters,
 * and World Layout Serializer flush triggers.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  PauseMenuState,
  PauseMenuAction,
  SUNNY_DAY_CONSTANTS,
  DEFAULT_ENVIRONMENT_BASELINE
} from '../world/pauseMenuState.ts';

describe('Universal Pause Menu & Editor Lighting Override System', () => {
  it('should initialize with default unpaused state and captured mouse', () => {
    const pauseState = new PauseMenuState(false);
    assert.strictEqual(pauseState.isPaused, false);
    assert.strictEqual(pauseState.getMouseMode(), 'CAPTURED');
    assert.strictEqual(pauseState.isSunnyDayActive, false);
    assert.strictEqual(pauseState.isSettingsOpen, false);
    assert.strictEqual(pauseState.isHelpOpen, false);
  });

  it('should toggle pause state and switch mouse mode between CAPTURED and VISIBLE', () => {
    const pauseState = new PauseMenuState(false);

    // Toggle ON
    const paused = pauseState.togglePause();
    assert.strictEqual(paused, true);
    assert.strictEqual(pauseState.isPaused, true);
    assert.strictEqual(pauseState.getMouseMode(), 'VISIBLE');

    // Toggle OFF
    const resumed = pauseState.togglePause();
    assert.strictEqual(resumed, false);
    assert.strictEqual(pauseState.isPaused, false);
    assert.strictEqual(pauseState.getMouseMode(), 'CAPTURED');
  });

  it('should close sub-modals (settings and help) when unpausing', () => {
    const pauseState = new PauseMenuState(true);
    pauseState.togglePause(true);
    pauseState.executeAction(PauseMenuAction.SETTINGS);
    assert.strictEqual(pauseState.isSettingsOpen, true);

    // Resuming closes sub-modals
    pauseState.executeAction(PauseMenuAction.RESUME);
    assert.strictEqual(pauseState.isPaused, false);
    assert.strictEqual(pauseState.isSettingsOpen, false);
  });

  it('should only permit Sunny Day lighting override when in Editor Mode', () => {
    const normalGamePause = new PauseMenuState(false);
    const editorPause = new PauseMenuState(true);

    // Normal game: Sunny day toggle is rejected
    const normalResult = normalGamePause.toggleSunnyDay();
    assert.strictEqual(normalResult, false);
    assert.strictEqual(normalGamePause.isSunnyDayActive, false);

    // Editor mode: Sunny day toggle succeeds
    const editorResult = editorPause.toggleSunnyDay();
    assert.strictEqual(editorResult, true);
    assert.strictEqual(editorPause.isSunnyDayActive, true);

    // Toggle off
    const toggledOff = editorPause.toggleSunnyDay();
    assert.strictEqual(toggledOff, false);
    assert.strictEqual(editorPause.isSunnyDayActive, false);
  });

  it('should resolve high-visibility sunny day lighting parameters when active', () => {
    const editorPause = new PauseMenuState(true);
    editorPause.setSunnyDay(true);

    const lighting = editorPause.resolveEffectiveLighting();
    assert.strictEqual(lighting.sunEnergy, SUNNY_DAY_CONSTANTS.SUN_ENERGY);
    assert.strictEqual(lighting.ambientEnergy, SUNNY_DAY_CONSTANTS.AMBIENT_ENERGY);
    assert.strictEqual(lighting.fogEnabled, false);
    assert.strictEqual(lighting.volumetricFogEnabled, false);
    assert.strictEqual(lighting.particleDensity, 0.0);
    assert.strictEqual(lighting.shadowsEnabled, false);
    assert.strictEqual(lighting.sunPitchDeg, 55.0);
    assert.deepStrictEqual(lighting.ambientColor, { r: 1.0, g: 1.0, b: 1.0 });
  });

  it('should restore base sector dynamic atmosphere when sunny day is deactivated', () => {
    const editorPause = new PauseMenuState(true);
    editorPause.setSunnyDay(false);

    const customSector = {
      sunEnergy: 1.45,
      fogEnabled: true,
      volumetricFogEnabled: true,
      particleDensity: 0.85
    };

    const lighting = editorPause.resolveEffectiveLighting(customSector);
    assert.strictEqual(lighting.sunEnergy, 1.45);
    assert.strictEqual(lighting.fogEnabled, true);
    assert.strictEqual(lighting.volumetricFogEnabled, true);
    assert.strictEqual(lighting.particleDensity, 0.85);
  });

  it('should correctly trigger World Layout Serializer flush on SAVE_WORLD action', () => {
    const pauseState = new PauseMenuState(true);
    let flushedCount = 0;
    const mockSerializer = () => {
      flushedCount += 1;
      return true;
    };

    const res = pauseState.executeAction(PauseMenuAction.SAVE_WORLD, mockSerializer);
    assert.strictEqual(res.success, true);
    assert.strictEqual(flushedCount, 1);
    assert.ok(res.message.includes('WORLD_LAYOUT_OVERRIDES.JSON'));
  });

  it('should handle serializer failures gracefully on SAVE_WORLD action', () => {
    const pauseState = new PauseMenuState(true);
    const mockFailingSerializer = () => false;

    const res = pauseState.executeAction(PauseMenuAction.SAVE_WORLD, mockFailingSerializer);
    assert.strictEqual(res.success, false);
    assert.ok(res.message.includes('ERROR'));
  });

  it('should format visible menu button entries including Sunny Day in Editor Mode', () => {
    const normalState = new PauseMenuState(false);
    const normalButtons = normalState.getVisibleMenuButtons();
    assert.strictEqual(normalButtons.some(b => b.includes('LUZ DE DÍA MÁXIMA')), false);

    const editorState = new PauseMenuState(true);
    let editorButtons = editorState.getVisibleMenuButtons();
    assert.strictEqual(editorButtons.some(b => b.includes('LUZ DE DÍA MÁXIMA: [DESACTIVADA]')), true);

    editorState.setSunnyDay(true);
    editorButtons = editorState.getVisibleMenuButtons();
    assert.strictEqual(editorButtons.some(b => b.includes('LUZ DE DÍA MÁXIMA: [ACTIVADA]')), true);
  });

  it('should auto-flush world layout overrides when exiting to main menu from Editor Mode', () => {
    const editorState = new PauseMenuState(true);
    let autoFlushCalled = false;
    const mockFlush = () => {
      autoFlushCalled = true;
      return true;
    };

    const res = editorState.executeAction(PauseMenuAction.MAIN_MENU, mockFlush);
    assert.strictEqual(res.success, true);
    assert.strictEqual(autoFlushCalled, true);
    assert.strictEqual(editorState.isPaused, false);
  });
});

