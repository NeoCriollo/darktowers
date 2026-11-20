/**
 * Dark Towers: The Path of Ka
 * Editor Boot Diagnostic Test Suite (Modo Arquitecto — Tasks 1, 2 & 3)
 *
 * Verifies unconditional instantiation, scene tree hierarchy, non-null / non-orphan
 * guarantees, idempotent initialization, and on-disk GDScript contracts.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  simulateWorldBoot,
  ensureEditorSuite,
  toggleEditorMode,
  buildBootReport,
  countSuiteNodes,
  auditWorldEditorBootSource,
  findInlinePropertyAccessors,
  REQUIRED_SUITE_KEYS,
  SUITE_NODE_NAMES,
  SUITE_CANVAS_LAYERS,
  WORLD_ROOT_NAME,
  CONTROLLER_NODE_NAME,
  type WorldBootOptions
} from '../world/editorBootDiagnostic.ts';

const REPO_ROOT = process.cwd();

describe('Editor Boot Diagnostic Domain & Scene Tree Hierarchy (Task 1 & 2)', () => {
  it('should unconditionally populate all required editor nodes when editor mode is active', () => {
    const opts: WorldBootOptions = {
      editorActive: true,
      playerPresent: true,
      worldScriptParses: true
    };
    const scene = simulateWorldBoot(opts);
    const report = buildBootReport(scene);

    assert.strictEqual(report.ok, true, 'Boot report must be ok');
    assert.strictEqual(report.editorActive, true);
    assert.strictEqual(report.missing.length, 0, 'No suite nodes can be missing');
    assert.strictEqual(report.orphaned.length, 0, 'No suite nodes can be orphaned');
    assert.strictEqual(report.misparented.length, 0, 'No suite nodes can be misparented');
    assert.strictEqual(report.visibilityViolations.length, 0);
    assert.strictEqual(report.playerBound, true);
    assert.strictEqual(report.cameraBound, true);

    // Verify all 6 nodes exist and are parented correctly
    for (const key of REQUIRED_SUITE_KEYS) {
      const nodeName = SUITE_NODE_NAMES[key];
      const node = scene.nodes.get(nodeName);
      assert.ok(node, `Node ${nodeName} (${key}) must exist in scene`);
      if (key === 'flight_controller') {
        assert.strictEqual(node.parent, WORLD_ROOT_NAME);
      } else {
        assert.strictEqual(node.parent, CONTROLLER_NODE_NAME);
      }
    }

    // Verify overlay is visible and gameplay HUD is hidden
    const overlay = scene.nodes.get(SUITE_NODE_NAMES.hud_overlay);
    assert.ok(overlay);
    assert.strictEqual(overlay.visible, true, 'EditorHUDOverlay must be visible when editor is active');

    const hud = scene.nodes.get('HUD');
    assert.ok(hud);
    assert.strictEqual(hud.visible, false, 'Gameplay HUD must be hidden when editor is active');
  });

  it('should instantiate and parent editor tools even when booted with editor mode inactive', () => {
    const opts: WorldBootOptions = {
      editorActive: false,
      playerPresent: true,
      worldScriptParses: true
    };
    const scene = simulateWorldBoot(opts);
    const report = buildBootReport(scene);

    assert.strictEqual(report.ok, true);
    assert.strictEqual(report.editorActive, false);
    assert.strictEqual(report.missing.length, 0);
    assert.strictEqual(countSuiteNodes(scene), 6, 'All 6 suite nodes must exist on boot');

    // Overlay, catalog and outliner must be hidden while inactive; HUD must be visible
    assert.strictEqual(scene.nodes.get(SUITE_NODE_NAMES.hud_overlay)?.visible, false);
    assert.strictEqual(scene.nodes.get(SUITE_NODE_NAMES.asset_catalog)?.visible, false);
    assert.strictEqual(scene.nodes.get(SUITE_NODE_NAMES.outliner_panel)?.visible, false);
    assert.strictEqual(scene.nodes.get('HUD')?.visible, true);
  });

  it('should enforce idempotent initialization without node duplication or leakage', () => {
    const scene = simulateWorldBoot({
      editorActive: true,
      playerPresent: true,
      worldScriptParses: true
    });
    assert.strictEqual(countSuiteNodes(scene), 6);

    // Trigger multiple redundant ensureEditorSuite calls
    ensureEditorSuite(scene);
    ensureEditorSuite(scene);
    ensureEditorSuite(scene);

    assert.strictEqual(countSuiteNodes(scene), 6, 'Repeated ensure calls must never duplicate nodes');
    assert.strictEqual(scene.initializeCalls, 5); // 2 from boot + 3 manual
  });

  it('should re-home orphaned or mis-parented flight controller back to World root', () => {
    const scene = simulateWorldBoot({
      editorActive: true,
      playerPresent: true,
      worldScriptParses: true
    });

    // Simulate accidental mis-parenting under HUD (which would hide it)
    const ctrl = scene.nodes.get(CONTROLLER_NODE_NAME)!;
    ctrl.parent = 'HUD';

    let badReport = buildBootReport(scene);
    assert.strictEqual(badReport.ok, false);
    assert.ok(badReport.misparented.includes('flight_controller'));

    // ensureEditorSuite must heal and re-parent under World
    ensureEditorSuite(scene);
    assert.strictEqual(ctrl.parent, WORLD_ROOT_NAME);

    const healedReport = buildBootReport(scene);
    assert.strictEqual(healedReport.ok, true);
  });

  it('should accurately handle live mode toggling and visibility synchronization', () => {
    const scene = simulateWorldBoot({
      editorActive: false,
      playerPresent: true,
      worldScriptParses: true
    });

    // Toggle to active
    toggleEditorMode(scene, true);
    assert.strictEqual(scene.editorActive, true);
    assert.strictEqual(scene.nodes.get(SUITE_NODE_NAMES.hud_overlay)?.visible, true);
    assert.strictEqual(scene.nodes.get('HUD')?.visible, false);

    // Toggle back to inactive
    toggleEditorMode(scene, false);
    assert.strictEqual(scene.editorActive, false);
    assert.strictEqual(scene.nodes.get(SUITE_NODE_NAMES.hud_overlay)?.visible, false);
    assert.strictEqual(scene.nodes.get('HUD')?.visible, true);
  });

  it('should detect total editor suite failure when world script fails to parse', () => {
    const brokenScene = simulateWorldBoot({
      editorActive: true,
      playerPresent: true,
      worldScriptParses: false
    });
    const report = buildBootReport(brokenScene);

    assert.strictEqual(report.ok, false);
    assert.strictEqual(report.missing.length, 6, 'All 6 suite nodes are missing if script fails to parse');
    assert.strictEqual(countSuiteNodes(brokenScene), 0);
  });

  it('should verify CanvasLayer stacking hierarchy preserves overlay priority', () => {
    assert.strictEqual(SUITE_CANVAS_LAYERS.hud_overlay, 101);
    assert.strictEqual(SUITE_CANVAS_LAYERS.outliner_panel, 104);
    assert.strictEqual(SUITE_CANVAS_LAYERS.asset_catalog, 105);
    assert.ok((SUITE_CANVAS_LAYERS.hud_overlay ?? 0) > 100, 'Editor overlay must render above standard HUD');
  });
});

describe('On-Disk Architecture & Source Invariant Audit (Tasks 1, 2 & Strict Constraints)', () => {
  it('should audit world.gd for strict unconditional editor bootstrapping and zero inline accessors', () => {
    const worldPath = path.join(REPO_ROOT, 'world.gd');
    assert.ok(fs.existsSync(worldPath), 'world.gd must exist');
    const source = fs.readFileSync(worldPath, 'utf8');

    const audit = auditWorldEditorBootSource(source);
    assert.strictEqual(
      audit.compliant,
      true,
      `world.gd failed boot source audit: ${audit.errors.join('; ')}`
    );

    const inlineAccessors = findInlinePropertyAccessors(source);
    assert.strictEqual(
      inlineAccessors.length,
      0,
      `world.gd must have 0 inline property accessors (found on lines ${inlineAccessors.join(', ')})`
    );
  });

  it('should confirm on-disk pause_and_toast_controller heals missing overlay on toggle', () => {
    const ptcPath = path.join(REPO_ROOT, 'ui', 'pause_and_toast_controller.gd');
    assert.ok(fs.existsSync(ptcPath), 'pause_and_toast_controller.gd must exist');
    const ptcSource = fs.readFileSync(ptcPath, 'utf8');

    assert.ok(
      ptcSource.includes('ensure_editor_suite'),
      'pause_and_toast_controller must call ensure_editor_suite if overlay missing on toggle'
    );
  });

  it('should confirm on-disk editor_flight_controller exposes get_editor_suite and re-links camera', () => {
    const efcPath = path.join(REPO_ROOT, 'world', 'editor', 'editor_flight_controller.gd');
    assert.ok(fs.existsSync(efcPath), 'editor_flight_controller.gd must exist');
    const efcSource = fs.readFileSync(efcPath, 'utf8');

    assert.ok(efcSource.includes('func get_editor_suite() -> Dictionary:'));
    assert.ok(efcSource.includes('func is_initialized() -> bool:'));
    assert.ok(efcSource.includes('func _resolve_camera() -> void:'));
  });

  it('should confirm on-disk editor_palette_hud implements compatibility shims for virtualized pool', () => {
    const hudPath = path.join(REPO_ROOT, 'world', 'editor', 'editor_palette_hud.gd');
    assert.ok(fs.existsSync(hudPath), 'editor_palette_hud.gd must exist');
    const hudSource = fs.readFileSync(hudPath, 'utf8');

    assert.ok(hudSource.includes('func _visible_pool_cards()'));
    assert.ok(hudSource.includes('func _clear_grid_cards()'));
  });

  it('should enforce strict file granularity between 150 and 450 lines for all modified files', () => {
    const filesToAudit = [
      'world.gd',
      'ui.gd',
      'world/world_bootstrap_builder.gd',
      'world/world_editor_bootstrap.gd',
      'world/editor/editor_flight_controller.gd',
      'world/editor/editor_hud_overlay.gd',
      'world/editor/editor_palette_hud.gd',
      'ui/pause_and_toast_controller.gd',
      'world/editorBootDiagnostic.ts',
      'tests/editorBootDiagnostic.test.ts'
    ];

    for (const relPath of filesToAudit) {
      const fullPath = path.join(REPO_ROOT, relPath);
      assert.ok(fs.existsSync(fullPath), `${relPath} must exist on disk`);
      const lineCount = fs.readFileSync(fullPath, 'utf8').split(/\r?\n/).length;

      assert.ok(
        lineCount >= 150,
        `${relPath} is ${lineCount} lines; must be >= 150 lines`
      );
      assert.ok(
        lineCount <= 450,
        `${relPath} is ${lineCount} lines; must be <= 450 lines (Anti-Monolith hard ceiling)`
      );
    }
  });
});

