/**
 * Dark Towers: The Path of Ka
 * Editor Boot Diagnostic Domain (Modo Arquitecto — Persistent Editor Bootstrapping)
 *
 * Deterministic TypeScript mirror of world.gd + world/world_editor_bootstrap.gd +
 * world/editor/editor_flight_controller.gd boot behaviour. Models the scene tree
 * produced by world initialization and verifies that the editor tool suite is:
 *   - instantiated unconditionally (no player / editor-active guard),
 *   - parented under the World root (never orphaned or under the HUD layer),
 *   - idempotent across repeated ensure calls and mode toggles,
 *   - visible/hidden according to WorldSaveData.is_editor_active().
 *
 * Also exposes a GDScript source scanner for the root-cause regression: Godot 4.7
 * rejects single-line `var x: T: get: return ...` property accessors, which made
 * world.gd fail to parse and silently removed every editor node from the viewport.
 */

// ─── Constants (mirror world_editor_bootstrap.gd) ───────────────────────────

export const WORLD_ROOT_NAME = 'World';
export const CONTROLLER_NODE_NAME = 'EditorFlightController';

export type SuiteKey =
  | 'flight_controller'
  | 'selection_manager'
  | 'manipulator'
  | 'asset_catalog'
  | 'outliner_panel'
  | 'hud_overlay';

export const REQUIRED_SUITE_KEYS: readonly SuiteKey[] = [
  'flight_controller', 'selection_manager', 'manipulator',
  'asset_catalog', 'outliner_panel', 'hud_overlay'
];

export const VISIBLE_WHEN_ACTIVE_KEYS: readonly SuiteKey[] = ['hud_overlay'];
export const HIDDEN_WHEN_INACTIVE_KEYS: readonly SuiteKey[] = ['hud_overlay', 'asset_catalog', 'outliner_panel'];

/** Node names assigned by EditorFlightController.initialize(). */
export const SUITE_NODE_NAMES: Readonly<Record<SuiteKey, string>> = {
  flight_controller: CONTROLLER_NODE_NAME,
  selection_manager: 'EditorSelectionManager',
  manipulator: 'EditorManipulator',
  asset_catalog: 'EditorAssetCatalog',
  outliner_panel: 'EditorOutlinerPanel',
  hud_overlay: 'EditorHUDOverlay'
};

/** CanvasLayer z-order used by the editor UI (must stay above the survival HUD). */
export const SUITE_CANVAS_LAYERS: Readonly<Partial<Record<SuiteKey, number>>> = {
  hud_overlay: 101,
  outliner_panel: 104,
  asset_catalog: 105
};

// ─── Scene Tree Model ───────────────────────────────────────────────────────

export interface SceneNode {
  name: string;
  parent: string | null;
  visible: boolean;
}

export interface WorldBootOptions {
  editorActive: boolean;
  playerPresent: boolean;
  /** False reproduces the Godot 4.7 parse failure in world.gd. */
  worldScriptParses: boolean;
}

export interface WorldSceneModel {
  nodes: Map<string, SceneNode>;
  editorActive: boolean;
  controllerInitialized: boolean;
  cameraBound: boolean;
  playerBound: boolean;
  initializeCalls: number;
}

export function createWorldScene(opts: WorldBootOptions): WorldSceneModel {
  const nodes = new Map<string, SceneNode>();
  nodes.set(WORLD_ROOT_NAME, { name: WORLD_ROOT_NAME, parent: null, visible: true });
  nodes.set('HUD', { name: 'HUD', parent: WORLD_ROOT_NAME, visible: true });
  if (opts.playerPresent) nodes.set('Player', { name: 'Player', parent: WORLD_ROOT_NAME, visible: true });
  return {
    nodes, editorActive: opts.editorActive, controllerInitialized: false,
    cameraBound: false, playerBound: false, initializeCalls: 0
  };
}

/** Mirrors EditorFlightController.initialize(): idempotent sub-node construction. */
function initializeController(scene: WorldSceneModel, active: boolean): void {
  scene.initializeCalls += 1;
  scene.playerBound = scene.nodes.has('Player');
  // _resolve_camera(): player camera, or a private Camera3D fallback when no player.
  scene.cameraBound = true;
  if (!scene.controllerInitialized) {
    for (const key of REQUIRED_SUITE_KEYS) {
      if (key === 'flight_controller') continue;
      const name = SUITE_NODE_NAMES[key];
      scene.nodes.set(name, { name, parent: CONTROLLER_NODE_NAME, visible: false });
    }
    scene.controllerInitialized = true;
  }
  setControllerActive(scene, active);
}

/** Mirrors EditorFlightController.set_active() visibility side-effects. */
export function setControllerActive(scene: WorldSceneModel, active: boolean): void {
  scene.editorActive = active;
  const overlay = scene.nodes.get(SUITE_NODE_NAMES.hud_overlay);
  if (overlay) overlay.visible = active;
  if (!active) {
    for (const key of ['asset_catalog', 'outliner_panel'] as const) {
      const n = scene.nodes.get(SUITE_NODE_NAMES[key]);
      if (n) n.visible = false;
    }
  }
  const hud = scene.nodes.get('HUD');
  if (hud) hud.visible = !active;
}

/** Mirrors WorldEditorBootstrap.ensure_editor_suite(). Unconditional + idempotent. */
export function ensureEditorSuite(scene: WorldSceneModel): void {
  const existing = scene.nodes.get(CONTROLLER_NODE_NAME);
  if (!existing) {
    scene.nodes.set(CONTROLLER_NODE_NAME, { name: CONTROLLER_NODE_NAME, parent: WORLD_ROOT_NAME, visible: true });
  } else if (existing.parent !== WORLD_ROOT_NAME) {
    existing.parent = WORLD_ROOT_NAME; // re-home orphaned / mis-parented controller
  }
  initializeController(scene, scene.editorActive);
}

/** Mirrors World._ready() → WorldBootstrapBuilder stage 6 → _on_bootstrap_completed(). */
export function simulateWorldBoot(opts: WorldBootOptions): WorldSceneModel {
  const scene = createWorldScene(opts);
  if (!opts.worldScriptParses) {
    // Script never attaches: no bootstrap stages run, no editor suite exists.
    return scene;
  }
  ensureEditorSuite(scene); // stage 6: _check_and_init_editor_mode()
  ensureEditorSuite(scene); // finalize_after_bootstrap()
  return scene;
}

/** Mirrors WorldEditorBootstrap.on_editor_mode_toggled(). */
export function toggleEditorMode(scene: WorldSceneModel, active: boolean): void {
  if (!scene.controllerInitialized || !scene.nodes.has(CONTROLLER_NODE_NAME)) ensureEditorSuite(scene);
  setControllerActive(scene, active);
}

// ─── Diagnostics (mirror build_boot_report) ─────────────────────────────────

export interface EditorBootReport {
  ok: boolean;
  editorActive: boolean;
  missing: SuiteKey[];
  orphaned: SuiteKey[];
  misparented: SuiteKey[];
  visibilityViolations: string[];
  playerBound: boolean;
  cameraBound: boolean;
}

function isDescendantOfWorld(scene: WorldSceneModel, name: string): boolean {
  let cursor = scene.nodes.get(name);
  const guard = new Set<string>();
  while (cursor && cursor.parent !== null) {
    if (guard.has(cursor.name)) return false;
    guard.add(cursor.name);
    if (cursor.parent === WORLD_ROOT_NAME) return true;
    cursor = scene.nodes.get(cursor.parent);
  }
  return false;
}

export function buildBootReport(scene: WorldSceneModel): EditorBootReport {
  const report: EditorBootReport = {
    ok: false, editorActive: scene.editorActive, missing: [], orphaned: [], misparented: [],
    visibilityViolations: [], playerBound: scene.playerBound, cameraBound: scene.cameraBound
  };
  for (const key of REQUIRED_SUITE_KEYS) {
    const node = scene.nodes.get(SUITE_NODE_NAMES[key]);
    if (!node) report.missing.push(key);
    else if (node.parent === null || !scene.nodes.has(node.parent)) report.orphaned.push(key);
    else if (!isDescendantOfWorld(scene, node.name)) report.misparented.push(key);
  }
  const ctrl = scene.nodes.get(CONTROLLER_NODE_NAME);
  if (ctrl && ctrl.parent !== WORLD_ROOT_NAME && !report.misparented.includes('flight_controller')
    && !report.orphaned.includes('flight_controller')) {
    report.misparented.push('flight_controller');
  }
  const keys = scene.editorActive ? VISIBLE_WHEN_ACTIVE_KEYS : HIDDEN_WHEN_INACTIVE_KEYS;
  for (const key of keys) {
    const node = scene.nodes.get(SUITE_NODE_NAMES[key]);
    if (node && node.visible !== scene.editorActive) {
      report.visibilityViolations.push(`${key} must be ${scene.editorActive ? 'visible' : 'hidden'}`);
    }
  }
  report.ok = report.missing.length === 0 && report.orphaned.length === 0
    && report.misparented.length === 0 && report.visibilityViolations.length === 0 && report.cameraBound;
  return report;
}

export function countSuiteNodes(scene: WorldSceneModel): number {
  const names = new Set(Object.values(SUITE_NODE_NAMES));
  let count = 0;
  for (const node of scene.nodes.values()) if (names.has(node.name)) count += 1;
  return count;
}

// ─── GDScript Source Scanners ───────────────────────────────────────────────

/** Matches Godot-4.7-invalid single-line property accessors: `var x: T: get: ...`. */
const INLINE_ACCESSOR_RE = /^\s*(?:static\s+)?var\s+\w+\s*:\s*[\w.\[\]]+\s*:\s*(?:get|set)\b/;

export function findInlinePropertyAccessors(source: string): number[] {
  const hits: number[] = [];
  source.split(/\r?\n/).forEach((line, idx) => {
    if (INLINE_ACCESSOR_RE.test(line)) hits.push(idx + 1);
  });
  return hits;
}

export interface BootSourceAudit {
  compliant: boolean;
  errors: string[];
}

/** Audits world.gd for unconditional, delegated editor bootstrapping. */
export function auditWorldEditorBootSource(worldSource: string): BootSourceAudit {
  const errors: string[] = [];
  if (!worldSource.includes('WorldEditorBootstrap.new(self)')) errors.push('world.gd must construct WorldEditorBootstrap');
  if (!/func _check_and_init_editor_mode\(\)[^\n]*_editor_boot\.ensure_editor_suite\(\)/.test(worldSource)) {
    errors.push('_check_and_init_editor_mode must delegate to ensure_editor_suite');
  }
  if (/func _check_and_init_editor_mode\(\)[\s\S]{0,80}if player == null: return/.test(worldSource)) {
    errors.push('editor suite instantiation must not be guarded by player == null');
  }
  if (!worldSource.includes('func ensure_editor_suite()')) errors.push('world.gd must expose ensure_editor_suite()');
  if (!worldSource.includes('_editor_boot.finalize_after_bootstrap()')) errors.push('bootstrap completion must re-assert editor suite');
  if (findInlinePropertyAccessors(worldSource).length > 0) errors.push('world.gd contains inline property accessors');
  return { compliant: errors.length === 0, errors };
}

