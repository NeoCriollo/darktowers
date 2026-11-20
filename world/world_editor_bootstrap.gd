class_name WorldEditorBootstrap
extends RefCounted

## World Editor Suite Bootstrap — "Modo Arquitecto" persistence layer.
##
## Owns the lifecycle of the editor tool suite on behalf of world.gd:
##   - EditorFlightController (6DoF Todash flight cam) parented directly under World
##   - EditorSelectionManager / EditorManipulator (raycast selection + gizmo)
##   - EditorAssetCatalogUI (palette drawer), EditorOutlinerPanel, EditorHUDOverlay
##
## Contract (mirrored in world/editorBootDiagnostic.ts):
##   1. The suite is instantiated UNCONDITIONALLY at bootstrap — no player guard,
##      no editor-active guard. Activation is a visibility/processing concern only.
##   2. ensure_editor_suite() is idempotent: repeated calls never duplicate nodes.
##   3. Orphaned or mis-parented controllers are re-attached to the World root.
##   4. Toggling editor mode lazily re-runs ensure_editor_suite() so a missing
##      suite is rebuilt instead of silently ignored.

const CONTROLLER_NODE_NAME := "EditorFlightController"

## Suite keys reported by EditorFlightController.get_editor_suite().
const REQUIRED_SUITE_KEYS: Array[String] = [
	"flight_controller", "selection_manager", "manipulator",
	"asset_catalog", "outliner_panel", "hud_overlay"
]

## Nodes that must be visible whenever editor mode is active.
const VISIBLE_WHEN_ACTIVE_KEYS: Array[String] = ["hud_overlay"]

## Nodes that must be hidden whenever editor mode is inactive.
const HIDDEN_WHEN_INACTIVE_KEYS: Array[String] = ["hud_overlay", "asset_catalog", "outliner_panel"]

var world: World = null
var _signal_connected: bool = false
var _last_report: Dictionary = {}

func _init(p_world: World = null) -> void:
	world = p_world

# ─── Suite Construction ──────────────────────────────────────────────────────

## Instantiates, parents and initializes the full editor suite. Safe to call at
## any point after World._ready() has started; returns the live controller.
func ensure_editor_suite() -> EditorFlightController:
	if world == null or not is_instance_valid(world):
		push_error("[WorldEditorBootstrap] No World context; editor suite cannot boot.")
		return null
	var efc := _resolve_or_create_controller()
	_attach_to_world(efc)
	world.editor_flight_controller = efc
	# Initialization is idempotent inside the controller: the first call builds
	# sub-nodes, later calls only re-bind player/camera and re-apply activation.
	efc.initialize(world.player, _is_editor_active())
	_connect_toggle_signal()
	_last_report = build_boot_report()
	if not bool(_last_report.get("ok", false)):
		push_error("[WorldEditorBootstrap] Editor suite boot incomplete: %s" % str(_last_report))
	return efc

func _resolve_or_create_controller() -> EditorFlightController:
	var efc: EditorFlightController = world.editor_flight_controller
	if efc != null and not is_instance_valid(efc):
		efc = null
	if efc == null:
		efc = world.find_child(CONTROLLER_NODE_NAME, true, false) as EditorFlightController
	if efc == null:
		efc = EditorFlightController.new()
		efc.name = CONTROLLER_NODE_NAME
	return efc

func _attach_to_world(efc: EditorFlightController) -> void:
	var parent := efc.get_parent()
	if parent == world:
		return
	if parent == null:
		world.add_child(efc)
	else:
		# Mis-parented (e.g. dragged under the HUD CanvasLayer, which hides it
		# together with the survival HUD). Re-home it under World.
		efc.reparent(world, false)
	efc.name = CONTROLLER_NODE_NAME

func _connect_toggle_signal() -> void:
	if _signal_connected or WorldSaveData == null: return
	if not WorldSaveData.editor_mode_toggled.is_connected(world._on_editor_mode_toggled):
		WorldSaveData.editor_mode_toggled.connect(world._on_editor_mode_toggled)
	_signal_connected = true

func _is_editor_active() -> bool:
	return WorldSaveData != null and WorldSaveData.is_editor_active()

# ─── Mode Toggling ───────────────────────────────────────────────────────────

func on_editor_mode_toggled(active: bool) -> void:
	var efc: EditorFlightController = world.editor_flight_controller if world != null else null
	if efc == null or not is_instance_valid(efc) or not efc.is_initialized() or not efc.is_inside_tree():
		efc = ensure_editor_suite()
	if efc == null: return
	if efc.is_flight_active() != active:
		efc.set_active(active)
	_sync_overlay_visibility(efc, active)

## Called once the player has been grounded and its input restored; the
## bootstrap unfreeze re-enables player input, so editor ownership is re-applied.
func finalize_after_bootstrap() -> void:
	var efc := ensure_editor_suite()
	if efc == null: return
	var active := _is_editor_active()
	efc.set_active(active)
	_sync_overlay_visibility(efc, active)

func _sync_overlay_visibility(efc: EditorFlightController, active: bool) -> void:
	var suite: Dictionary = efc.get_editor_suite()
	var overlay: CanvasLayer = suite.get("hud_overlay") as CanvasLayer
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = active

# ─── Diagnostics ─────────────────────────────────────────────────────────────

## Builds a structured report of the editor suite's scene-tree health.
## Keys: ok, editor_active, missing, orphaned, misparented, visibility_violations,
## player_bound, camera_bound.
func build_boot_report() -> Dictionary:
	var report := {
		"ok": false, "editor_active": _is_editor_active(),
		"missing": [], "orphaned": [], "misparented": [], "visibility_violations": [],
		"player_bound": false, "camera_bound": false
	}
	if world == null or not is_instance_valid(world):
		report["missing"] = REQUIRED_SUITE_KEYS.duplicate()
		return report
	var efc: EditorFlightController = world.editor_flight_controller
	if efc == null or not is_instance_valid(efc):
		report["missing"] = REQUIRED_SUITE_KEYS.duplicate()
		return report

	var suite: Dictionary = efc.get_editor_suite()
	for key in REQUIRED_SUITE_KEYS:
		var node: Node = suite.get(key) as Node
		if node == null or not is_instance_valid(node):
			report["missing"].append(key)
		elif not node.is_inside_tree() or node.get_parent() == null:
			report["orphaned"].append(key)
		elif not _is_descendant_of_world(node):
			report["misparented"].append(key)

	if efc.get_parent() != world and not report["missing"].has("flight_controller"):
		if not report["misparented"].has("flight_controller"):
			report["misparented"].append("flight_controller")

	_collect_visibility_violations(suite, bool(report["editor_active"]), report["visibility_violations"])
	report["player_bound"] = suite.get("player") != null
	report["camera_bound"] = suite.get("camera") != null and is_instance_valid(suite.get("camera"))
	report["ok"] = report["missing"].is_empty() and report["orphaned"].is_empty() \
		and report["misparented"].is_empty() and report["visibility_violations"].is_empty() \
		and bool(report["camera_bound"])
	return report

func _collect_visibility_violations(suite: Dictionary, active: bool, out: Array) -> void:
	var keys: Array[String] = VISIBLE_WHEN_ACTIVE_KEYS if active else HIDDEN_WHEN_INACTIVE_KEYS
	for key in keys:
		var node: Node = suite.get(key) as Node
		if node == null or not is_instance_valid(node) or not ("visible" in node):
			continue
		if bool(node.get("visible")) != active:
			out.append("%s must be %s" % [key, "visible" if active else "hidden"])

func _is_descendant_of_world(node: Node) -> bool:
	return node == world or world.is_ancestor_of(node)

func get_last_report() -> Dictionary:
	return _last_report.duplicate(true)

## Human-readable single-line status for logs / debug overlays.
func format_report(report: Dictionary) -> String:
	if bool(report.get("ok", false)):
		return "[EDITOR BOOT] OK — suite attached (editor_active=%s)" % str(report.get("editor_active", false))
	return "[EDITOR BOOT] FAULT — missing=%s orphaned=%s misparented=%s visibility=%s camera=%s" % [
		str(report.get("missing", [])), str(report.get("orphaned", [])),
		str(report.get("misparented", [])), str(report.get("visibility_violations", [])),
		str(report.get("camera_bound", false))
	]

