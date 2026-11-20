/**
 * Input Normalization & Physical Keybinding Parity Test Suite
 * Phase 1.1: Resolution of Keybinding Collisions
 *
 * Verifies non-colliding key configurations between firearm maintenance routines
 * and camera perspective swapping, modal triggers, and on-disk Godot configuration.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  InputNormalizationRegistry,
  PHYSICAL_KEYS,
  NORMALIZED_ACTION_CONFIGS,
} from '../world/inputNorm.ts';

describe('Phase 1.1: Input Normalization & Key Collision Elimination', () => {
  it('should guarantee tactical_shoulder_swap is mapped exclusively to physical key [Q]', () => {
    const swapBinding = InputNormalizationRegistry.getBinding('tactical_shoulder_swap');
    assert.ok(swapBinding, 'tactical_shoulder_swap must be defined in the normalization registry');

    assert.equal(
      swapBinding.primaryKey.godotPhysicalCode,
      PHYSICAL_KEYS.KEY_Q.godotPhysicalCode,
      'tactical_shoulder_swap primary physical key must be Q (81)'
    );
    assert.equal(swapBinding.primaryKey.symbol, 'Q');

    const allSwapCodes = [
      swapBinding.primaryKey.godotPhysicalCode,
      ...swapBinding.alternateKeys.map(k => k.godotPhysicalCode),
    ];
    assert.ok(
      !allSwapCodes.includes(PHYSICAL_KEYS.KEY_V.godotPhysicalCode),
      'tactical_shoulder_swap must NOT include physical key V (86)'
    );
  });

  it('should guarantee clear_jam is mapped exclusively to physical key [V]', () => {
    const jamBinding = InputNormalizationRegistry.getBinding('clear_jam');
    assert.ok(jamBinding, 'clear_jam must be defined in the normalization registry');

    assert.equal(
      jamBinding.primaryKey.godotPhysicalCode,
      PHYSICAL_KEYS.KEY_V.godotPhysicalCode,
      'clear_jam primary physical key must be V (86)'
    );
    assert.equal(jamBinding.primaryKey.symbol, 'V');

    const allJamCodes = [
      jamBinding.primaryKey.godotPhysicalCode,
      ...jamBinding.alternateKeys.map(k => k.godotPhysicalCode),
    ];
    assert.ok(
      !allJamCodes.includes(PHYSICAL_KEYS.KEY_Q.godotPhysicalCode),
      'clear_jam must NOT include physical key Q (81)'
    );
  });

  it('should verify zero key collisions between clear_jam and tactical_shoulder_swap', () => {
    const hasCollision = InputNormalizationRegistry.hasCollision('clear_jam', 'tactical_shoulder_swap');
    assert.equal(hasCollision, false, 'clear_jam and tactical_shoulder_swap must be strictly non-colliding');

    const exclusivity = InputNormalizationRegistry.validatePhysicalExclusivity();
    assert.equal(exclusivity.clearJamExclusivelyV, true, 'clear_jam must exclusively map to V');
    assert.equal(exclusivity.shoulderSwapExclusivelyQ, true, 'tactical_shoulder_swap must exclusively map to Q');
    assert.equal(exclusivity.isCollisionFree, true, 'Pair must be collision free');
  });

  it('should map toggle_recon_map exclusively to [M]', () => {
    const mapBinding = InputNormalizationRegistry.getBinding('toggle_recon_map');
    assert.ok(mapBinding, 'toggle_recon_map must be defined in the registry');

    assert.equal(
      mapBinding.primaryKey.godotPhysicalCode,
      PHYSICAL_KEYS.KEY_M.godotPhysicalCode,
      'toggle_recon_map primary key must be M (77)'
    );
    assert.equal(mapBinding.primaryKey.symbol, 'M');

    const alternateCodes = mapBinding.alternateKeys.map(k => k.godotPhysicalCode);
    assert.ok(
      !alternateCodes.includes(PHYSICAL_KEYS.KEY_TAB.godotPhysicalCode),
      'toggle_recon_map must NOT support Tab (4194306) as an alternate hotkey'
    );
  });

  it('should map field_gunsmith_inspect to [I] exclusively', () => {
    const inspectBinding = InputNormalizationRegistry.getBinding('field_gunsmith_inspect');
    assert.ok(inspectBinding, 'field_gunsmith_inspect must be defined in the registry');

    assert.equal(
      inspectBinding.primaryKey.godotPhysicalCode,
      PHYSICAL_KEYS.KEY_I.godotPhysicalCode,
      'field_gunsmith_inspect primary key must be I (73)'
    );
    assert.equal(inspectBinding.primaryKey.symbol, 'I');
    assert.equal(inspectBinding.category, 'INSPECTION');
  });

  it('should configure crouch_or_center_map on [C] with contextual tap and hold behaviors', () => {
    const crouchBinding = InputNormalizationRegistry.getBinding('crouch_or_center_map');
    assert.ok(crouchBinding, 'crouch_or_center_map must be defined in the registry');

    assert.equal(
      crouchBinding.primaryKey.godotPhysicalCode,
      PHYSICAL_KEYS.KEY_C.godotPhysicalCode,
      'crouch_or_center_map primary key must be C (67)'
    );
    assert.equal(crouchBinding.interactionMode, 'CONTEXTUAL_TAP_HOLD');

    // Context 1: World exploration (Hold for Crouch)
    const worldRes = InputNormalizationRegistry.resolveContextualInput('C', 'WORLD_EXPLORATION');
    assert.ok(worldRes, 'Resolution must succeed in world exploration context');
    assert.equal(worldRes.actionName, 'crouch_or_center_map');
    assert.equal(worldRes.locomotionPosture, 'CROUCHING');
    assert.equal(worldRes.mapAction, 'NONE');
    assert.equal(worldRes.effectiveMode, 'HOLD_CONTINUOUS');

    // Context 2: Recon Map Modal open (Tap to Center Map)
    const mapRes = InputNormalizationRegistry.resolveContextualInput('C', 'RECON_MAP_OPEN');
    assert.ok(mapRes, 'Resolution must succeed in recon map context');
    assert.equal(mapRes.actionName, 'crouch_or_center_map');
    assert.equal(mapRes.locomotionPosture, 'UNCHANGED');
    assert.equal(mapRes.mapAction, 'CENTER_ON_PLAYER');
    assert.equal(mapRes.effectiveMode, 'TRIGGER_INSTANT');
  });

  it('should enforce that pressing [V] triggers only jam clearance and never camera perspective swap', () => {
    const resV = InputNormalizationRegistry.resolveContextualInput('V', 'FIREARM_ENGAGEMENT');
    assert.ok(resV, 'Input resolution for V must succeed');
    assert.equal(resV.actionName, 'clear_jam');
    assert.equal(resV.triggersJamClearing, true, 'Pressing V must trigger jam clearing');
    assert.equal(resV.triggersShoulderSwap, false, 'Pressing V must NEVER trigger shoulder perspective swap');
  });

  it('should enforce that pressing [Q] triggers only perspective swap and never jam clearance', () => {
    const resQ = InputNormalizationRegistry.resolveContextualInput('Q', 'FIREARM_ENGAGEMENT');
    assert.ok(resQ, 'Input resolution for Q must succeed');
    assert.equal(resQ.actionName, 'tactical_shoulder_swap');
    assert.equal(resQ.triggersShoulderSwap, true, 'Pressing Q must trigger shoulder perspective swap');
    assert.equal(resQ.triggersJamClearing, false, 'Pressing Q must NEVER trigger weapon jam clearing');
  });

  it('should validate legacy action backwards compatibility', () => {
    const legacyActions = ['crouch', 'inspect_weapon', 'toggle_map', 'map', 'ui_map'] as const;
    for (const legacy of legacyActions) {
      const binding = NORMALIZED_ACTION_CONFIGS[legacy];
      assert.ok(binding, `Legacy action [${legacy}] must be retained for backward compatibility`);
      assert.ok(binding.primaryKey.godotPhysicalCode > 0, `Legacy action [${legacy}] must have valid physical keycode`);
    }
  });

  it('should validate 100% parity against on-disk project.godot input map', () => {
    const projectGodotPath = path.resolve(process.cwd(), 'project.godot');
    assert.ok(fs.existsSync(projectGodotPath), 'project.godot must exist on disk');

    const content = fs.readFileSync(projectGodotPath, 'utf8');

    // 1. Check tactical_shoulder_swap
    assert.ok(content.includes('tactical_shoulder_swap={'), 'project.godot must contain tactical_shoulder_swap');
    const shoulderBlockMatch = content.match(/tactical_shoulder_swap=\{[\s\S]*?"events":\s*\[([\s\S]*?)\]\s*\}/);
    assert.ok(shoulderBlockMatch, 'tactical_shoulder_swap block must be well-formed');
    const shoulderEvents = shoulderBlockMatch[1];
    assert.ok(shoulderEvents.includes('"physical_keycode":81'), 'tactical_shoulder_swap must contain physical_keycode 81 (Q)');
    assert.ok(!shoulderEvents.includes('"physical_keycode":86'), 'tactical_shoulder_swap must NOT contain physical_keycode 86 (V)');

    // 2. Check clear_jam
    assert.ok(content.includes('clear_jam={'), 'project.godot must contain clear_jam');
    const jamBlockMatch = content.match(/clear_jam=\{[\s\S]*?"events":\s*\[([\s\S]*?)\]\s*\}/);
    assert.ok(jamBlockMatch, 'clear_jam block must be well-formed');
    const jamEvents = jamBlockMatch[1];
    assert.ok(jamEvents.includes('"physical_keycode":86'), 'clear_jam must contain physical_keycode 86 (V)');
    assert.ok(!jamEvents.includes('"physical_keycode":81'), 'clear_jam must NOT contain physical_keycode 81 (Q)');

    // 3. Check toggle_recon_map
    assert.ok(content.includes('toggle_recon_map={'), 'project.godot must contain toggle_recon_map');
    const reconBlockMatch = content.match(/toggle_recon_map=\{[\s\S]*?"events":\s*\[([\s\S]*?)\]\s*\}/);
    assert.ok(reconBlockMatch, 'toggle_recon_map block must be well-formed');
    const reconEvents = reconBlockMatch[1];
    assert.ok(!reconEvents.includes('"physical_keycode":4194306'), 'toggle_recon_map must NOT contain physical_keycode 4194306 (Tab)');
    assert.ok(reconEvents.includes('"physical_keycode":77'), 'toggle_recon_map must contain physical_keycode 77 (M)');

    // 3b. Check toggle_editor_catalog
    assert.ok(content.includes('toggle_editor_catalog={'), 'project.godot must contain toggle_editor_catalog');
    const catalogBlockMatch = content.match(/toggle_editor_catalog=\{[\s\S]*?"events":\s*\[([\s\S]*?)\]\s*\}/);
    assert.ok(catalogBlockMatch, 'toggle_editor_catalog block must be well-formed');
    const catalogEvents = catalogBlockMatch[1];
    assert.ok(catalogEvents.includes('"physical_keycode":4194306'), 'toggle_editor_catalog must contain physical_keycode 4194306 (Tab)');
    assert.ok(!catalogEvents.includes('"physical_keycode":77'), 'toggle_editor_catalog must NOT contain physical_keycode 77 (M)');

    // 4. Check field_gunsmith_inspect
    assert.ok(content.includes('field_gunsmith_inspect={'), 'project.godot must contain field_gunsmith_inspect');
    const inspectBlockMatch = content.match(/field_gunsmith_inspect=\{[\s\S]*?"events":\s*\[([\s\S]*?)\]\s*\}/);
    assert.ok(inspectBlockMatch, 'field_gunsmith_inspect block must be well-formed');
    const inspectEvents = inspectBlockMatch[1];
    assert.ok(inspectEvents.includes('"physical_keycode":73'), 'field_gunsmith_inspect must contain physical_keycode 73 (I)');

    // 5. Check crouch_or_center_map
    assert.ok(content.includes('crouch_or_center_map={'), 'project.godot must contain crouch_or_center_map');
    const crouchBlockMatch = content.match(/crouch_or_center_map=\{[\s\S]*?"events":\s*\[([\s\S]*?)\]\s*\}/);
    assert.ok(crouchBlockMatch, 'crouch_or_center_map block must be well-formed');
    const crouchEvents = crouchBlockMatch[1];
    assert.ok(crouchEvents.includes('"physical_keycode":67'), 'crouch_or_center_map must contain physical_keycode 67 (C)');
  });
});
