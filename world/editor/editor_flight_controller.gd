class_name EditorFlightController
extends Node3D

## EditorFlightController: "The Todash Flight Cam" (Phase 1 & 2)
## 6DoF noclip flight, EditorSelectionManager (hover/selection), EditorManipulator.

@export var normal_speed: float = 25.0
@export var fast_speed: float = 120.0
@export var crawl_speed: float = 6.0
@export var mouse_sensitivity: float = 0.002
@export var acceleration: float = 14.0

const SECTOR_HUBS: Array[Dictionary] = [
	{"name": "1: Waystation Sanctuary", "pos": Vector2(-1180.0, -1180.0)}, {"name": "2: SW Desolation", "pos": Vector2(-550.0, -900.0)},
	{"name": "3: Dead-Creek Salt Flats", "pos": Vector2(-150.0, -550.0)}, {"name": "4: Caliche Cradle Nexus", "pos": Vector2(0.0, 0.0)},
	{"name": "5: Rust-Gorge Defile", "pos": Vector2(-650.0, 50.0)}, {"name": "6: Bleached Alkali Sink", "pos": Vector2(0.0, 650.0)},
	{"name": "7: The Great Shifting Erg", "pos": Vector2(650.0, 50.0)}, {"name": "8: Dark Tower Threshold", "pos": Vector2(650.0, 650.0)}
]

var _player_ref: CharacterBody3D = null
var _camera_ref: Camera3D = null
var _is_active: bool = false
var _speed_multiplier: float = 1.0
var _current_velocity: Vector3 = Vector3.ZERO
var _held_flight_keys: Dictionary = {}
var _yaw: float = 0.0
var _pitch: float = 0.0

# Sub-Controllers (Phases 2, 3, 4, 6 & 7)
var _selection_mgr: EditorSelectionManager = null
var _manipulator: EditorManipulator = null
var _palette_hud: EditorAssetCatalogUI = null
var _outliner_panel: EditorOutlinerPanel = null
var _serializer: WorldLayoutSerializer = null
var _hud_overlay: EditorHUDOverlay = null
var _initialized: bool = false

func _ready() -> void:
	if WorldSaveData != null and not WorldSaveData.editor_mode_toggled.is_connected(_on_world_save_editor_toggled):
		WorldSaveData.editor_mode_toggled.connect(_on_world_save_editor_toggled)
	# Activation before initialize() would run with no overlay/camera/sub-nodes;
	# WorldEditorBootstrap calls initialize() which applies the correct state.
	if _initialized and WorldSaveData != null and WorldSaveData.is_editor_active():
		set_active(true)

func _exit_tree() -> void:
	if WorldSaveData != null and WorldSaveData.editor_mode_toggled.is_connected(_on_world_save_editor_toggled):
		WorldSaveData.editor_mode_toggled.disconnect(_on_world_save_editor_toggled)

func _on_world_save_editor_toggled(active: bool) -> void:
	if _initialized: set_active(active)

func is_initialized() -> bool:
	return _initialized

## Live references to every editor suite node (consumed by WorldEditorBootstrap diagnostics).
func get_editor_suite() -> Dictionary:
	return {
		"flight_controller": self, "selection_manager": _selection_mgr, "manipulator": _manipulator,
		"asset_catalog": _palette_hud, "outliner_panel": _outliner_panel, "hud_overlay": _hud_overlay,
		"player": _player_ref, "camera": _camera_ref
	}

func _resolve_camera() -> void:
	if _camera_ref != null and is_instance_valid(_camera_ref) and _camera_ref.is_inside_tree(): return
	_camera_ref = null
	if _player_ref != null and is_instance_valid(_player_ref):
		_camera_ref = _player_ref.get_node_or_null("SpringArm3D/OffsetNode/Camera3D") as Camera3D
		if _camera_ref == null:
			_camera_ref = _player_ref.find_child("Camera3D", true, false) as Camera3D
	if _camera_ref == null:
		_camera_ref = get_node_or_null("Camera3D") as Camera3D
		if _camera_ref == null:
			_camera_ref = Camera3D.new()
			_camera_ref.name = "Camera3D"
			add_child(_camera_ref)

func initialize(player: CharacterBody3D, start_active: bool = true) -> void:
	if player != null: _player_ref = player
	_resolve_camera()
	if _initialized:
		# Idempotent re-entry: re-bind player/camera only, never duplicate sub-nodes.
		set_active(start_active)
		return

	_selection_mgr = EditorSelectionManager.new(); _selection_mgr.name = "EditorSelectionManager"; add_child(_selection_mgr)
	_manipulator = EditorManipulator.new(); _manipulator.name = "EditorManipulator"; add_child(_manipulator)

	var cat_path := "res://scenes/editor_asset_catalog.tscn"
	if ResourceLoader.exists(cat_path): _palette_hud = load(cat_path).instantiate() as EditorAssetCatalogUI
	if _palette_hud == null: _palette_hud = EditorPaletteHUD.new()
	_palette_hud.name = "EditorAssetCatalog"
	add_child(_palette_hud)

	var outliner_scene_path := "res://scenes/editor_outliner_panel.tscn"
	if ResourceLoader.exists(outliner_scene_path):
		_outliner_panel = load(outliner_scene_path).instantiate() as EditorOutlinerPanel
	if _outliner_panel == null: _outliner_panel = EditorOutlinerPanel.new()
	_outliner_panel.name = "EditorOutlinerPanel"
	add_child(_outliner_panel)
	_outliner_panel.initialize(_selection_mgr)
	_outliner_panel.prop_focus_requested.connect(_on_outliner_focus_requested)

	_serializer = WorldLayoutSerializer.new()

	_selection_mgr.hover_changed.connect(_on_hover_changed); _selection_mgr.selection_changed.connect(_on_selection_changed)
	_manipulator.object_transformed.connect(_on_object_transformed); _manipulator.object_cloned.connect(_on_object_cloned)
	_manipulator.object_deleted.connect(_on_object_deleted); _palette_hud.asset_spawn_requested.connect(_on_palette_asset_spawn_requested)
	_palette_hud.palette_closed.connect(_on_palette_closed)

	_hud_overlay = EditorHUDOverlay.new()
	add_child(_hud_overlay)
	_initialized = true
	set_active(start_active)

func set_active(active: bool) -> void:
	_is_active = active
	_current_velocity = Vector3.ZERO
	_held_flight_keys.clear()
	set_process(_is_active)
	set_physics_process(_is_active)
	if WorldSaveData.is_editor_active() != _is_active:
		WorldSaveData.set_editor_mode_active(_is_active)
	if _is_active: _resolve_camera() # Re-link raycast/manipulator camera if the rig was rebuilt
	if _hud_overlay != null: _hud_overlay.visible = _is_active
	if not _is_active:
		if _palette_hud != null: _palette_hud.close_palette()
		if _outliner_panel != null: _outliner_panel.close_panel()
		var own_cam: Camera3D = get_node_or_null("Camera3D") as Camera3D
		if own_cam != null: own_cam.current = false
		if _camera_ref != null and _camera_ref.get_parent() == self: _camera_ref.current = false

	# Synchronize gameplay HUD visibility
	if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		var hud: CanvasLayer = get_tree().current_scene.find_child("HUD", true, false) as CanvasLayer
		if hud != null:
			if hud.has_method("set_survival_hud_visible"): hud.call("set_survival_hud_visible", not _is_active)
			hud.visible = not _is_active

	if _player_ref != null:
		if _player_ref.has_method("_on_editor_mode_toggled"): _player_ref.call("_on_editor_mode_toggled", _is_active)
		_player_ref.velocity = Vector3.ZERO
		if _is_active:
			var p: Vector3 = _player_ref.global_position
			var ground_y: float = TerrainCollisionGenerator.sample_height(p.x, p.z)
			if p.y < ground_y + 1.0:
				_player_ref.global_position.y = ground_y + 2.0
		var visuals: Node3D = _player_ref.get_node_or_null("Visuals")
		if visuals != null: visuals.visible = not _is_active
		var ws: Node3D = _player_ref.find_child("WeaponSystem", true, false)
		if ws != null: ws.visible = not _is_active
		var spring_arm: SpringArm3D = _player_ref.get_node_or_null("SpringArm3D")
		if spring_arm != null:
			spring_arm.spring_length = 0.0 if _is_active else 3.0
			spring_arm.rotation = Vector3.ZERO
		if _camera_ref != null:
			_camera_ref.position = Vector3.ZERO if _is_active else Vector3(0.75, 0.0, 0.0)
			_camera_ref.rotation = Vector3(_pitch, 0.0, 0.0) if _is_active else Vector3.ZERO
		_player_ref.set_physics_process(not _is_active); _player_ref.set_process_input(not _is_active); _player_ref.set_process_unhandled_input(not _is_active)
		var col: CollisionShape3D = _player_ref.get_node_or_null("CollisionShape3D")
		if col != null: col.disabled = _is_active
	if _camera_ref != null:
		if _is_active: _camera_ref.current = true
		elif _camera_ref.get_parent() == self: _camera_ref.current = false
	if _is_active:
		if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		call_deferred("_capture_mouse")
		_suspend_survival_handicaps()

func _capture_mouse() -> void:
	if not _is_active: return
	if (_palette_hud != null and _palette_hud.is_palette_open()) or (_outliner_panel != null and _outliner_panel.is_panel_open()): return
	if get_tree() != null and get_tree().paused: return
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_held_flight_keys.clear()
		_current_velocity = Vector3.ZERO
	if (what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN) and _is_active:
		call_deferred("_capture_mouse")

func _input(event: InputEvent) -> void:
	if not _is_active or (_palette_hud != null and _palette_hud.is_palette_open()) or (_outliner_panel != null and _outliner_panel.is_panel_open()) or (get_tree() != null and get_tree().paused):
		_held_flight_keys.clear(); _current_velocity = Vector3.ZERO; return
	if event is InputEventKey:
		var k1: int = event.keycode; var k2: int = event.physical_keycode
		if event.is_pressed() and not (event.ctrl_pressed or event.meta_pressed):
			if k1 != 0: _held_flight_keys[k1] = true
			if k2 != 0: _held_flight_keys[k2] = true
		elif not event.is_pressed():
			if k1 != 0: _held_flight_keys.erase(k1)
			if k2 != 0: _held_flight_keys.erase(k2)
	if (event is InputEventMouseButton and event.is_pressed()) or event is InputEventMouseMotion:
		if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _is_flight_key_commanded(keycode: int) -> bool:
	if not _held_flight_keys.get(keycode, false): return false
	if Input.is_key_pressed(keycode) or Input.is_physical_key_pressed(keycode): return true
	_held_flight_keys.erase(keycode)
	return false

func is_flight_active() -> bool:
	return _is_active

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		if event.is_action_pressed("toggle_editor_mode") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_F6 or event.physical_keycode == KEY_F6)):
			set_active(true)
			get_viewport().set_input_as_handled()
		return

	if get_tree() != null and get_tree().paused:
		return

	# Phase 3 & 6: Palette drawer or Outliner panel take priority when open
	if _palette_hud != null and _palette_hud.is_palette_open():
		if _palette_hud.handle_input(event): get_viewport().set_input_as_handled(); return
	if _outliner_panel != null and _outliner_panel.is_panel_open():
		if _outliner_panel.handle_input(event): get_viewport().set_input_as_handled(); return

	# Phase 3 & 6: Toggle Palette (Tab/B) or Outliner (P)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if event.is_action_pressed("toggle_editor_catalog") or code == KEY_TAB or code == KEY_B:
			if _palette_hud != null: _palette_hud.toggle_palette(); get_viewport().set_input_as_handled(); return
		elif code == KEY_P:
			toggle_outliner(); get_viewport().set_input_as_handled(); return

	# Phase 2: Check Manipulator inputs first (Q/E, Shift+Wheel, R, Ctrl+D, Del)
	if _manipulator != null and _manipulator.handle_input(event, _camera_ref):
		get_viewport().set_input_as_handled()
		return

	# Phase 2: Check Selection inputs (Left-Click to select, Right-Click to deselect)
	if _selection_mgr != null and _selection_mgr.handle_input(event):
		get_viewport().set_input_as_handled()
		return

	# Mouse look
	if event is InputEventMouseMotion:
		if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not (_palette_hud != null and _palette_hud.is_palette_open()) and not (_outliner_panel != null and _outliner_panel.is_panel_open()):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x * mouse_sensitivity
			_pitch -= event.relative.y * mouse_sensitivity
			_pitch = clampf(_pitch, -deg_to_rad(88.0), deg_to_rad(88.0))
			if _player_ref != null: _player_ref.rotation.y = _yaw
			if _camera_ref != null: _camera_ref.rotation.x = _pitch

	# Mouse wheel adjusts speed multiplier if not holding shift or manipulating
	if event is InputEventMouseButton and event.is_pressed() and (_manipulator == null or not _manipulator.is_grabbing()):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _speed_multiplier = clampf(_speed_multiplier * 1.15, 0.2, 5.0); _update_hud_telemetry()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _speed_multiplier = clampf(_speed_multiplier / 1.15, 0.2, 5.0); _update_hud_telemetry()

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if (event.ctrl_pressed or event.meta_pressed or Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL)) and code == KEY_S:
			_save_world_layout(); get_viewport().set_input_as_handled(); return
		elif (event.ctrl_pressed or event.meta_pressed or event.is_command_or_control_pressed() or Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL)) and code == KEY_D:
			_clone_target_or_hovered(); get_viewport().set_input_as_handled(); return
		elif code == KEY_DELETE or code == KEY_BACKSPACE or code == KEY_X:
			_delete_target_or_hovered(); get_viewport().set_input_as_handled(); return
		elif event.is_action_pressed("toggle_editor_mode") or code == KEY_F6:
			set_active(false); get_viewport().set_input_as_handled(); return
		elif code == KEY_F:
			_snap_to_terrain(); get_viewport().set_input_as_handled(); return
		elif code >= KEY_1 and code <= KEY_8:
			var idx: int = code - KEY_1
			if idx >= 0 and idx < SECTOR_HUBS.size():
				teleport_to_sector(idx); get_viewport().set_input_as_handled(); return
		elif code == KEY_ESCAPE:
			var pm: Node = get_tree().current_scene.find_child("PauseMenu", true, false) if (get_tree() != null and get_tree().current_scene != null) else null
			if pm != null and pm.has_method("open_pause_menu"):
				pm.call("open_pause_menu")
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled(); return

func _process(delta: float) -> void:
	if not _is_active or _player_ref == null or (get_tree() != null and get_tree().paused):
		_current_velocity = Vector3.ZERO; return

	if (_palette_hud != null and _palette_hud.is_palette_open()) or (_outliner_panel != null and _outliner_panel.is_panel_open()):
		_current_velocity = Vector3.ZERO
		if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	_suspend_survival_handicaps()

	# Phase 2: Raycast hover check & manipulation tracking
	if _selection_mgr != null and _camera_ref != null and is_inside_tree():
		var space := get_world_3d().direct_space_state if get_world_3d() != null else null
		if space != null: _selection_mgr.process_raycast(_camera_ref, space)

	if _manipulator != null and _camera_ref != null:
		_manipulator.update_manipulation(_camera_ref, delta)

	# 6DoF Flight Movement — strictly gated on explicit flight commands
	var target_speed: float = fast_speed if Input.is_key_pressed(KEY_SHIFT) else (crawl_speed if Input.is_key_pressed(KEY_ALT) else normal_speed)
	var effective_speed: float = target_speed * _speed_multiplier
	var cam_basis: Basis = _camera_ref.global_transform.basis if _camera_ref != null else _player_ref.global_transform.basis
	var is_ctrl := Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META) or Input.is_physical_key_pressed(KEY_META)
	var input_vec := Vector3.ZERO
	if not is_ctrl:
		if _is_flight_key_commanded(KEY_W): input_vec -= cam_basis.z
		if _is_flight_key_commanded(KEY_S): input_vec += cam_basis.z
		if _is_flight_key_commanded(KEY_A): input_vec -= cam_basis.x
		if _is_flight_key_commanded(KEY_D): input_vec += cam_basis.x
		if _is_flight_key_commanded(KEY_SPACE): input_vec += Vector3.UP
		if _is_flight_key_commanded(KEY_C): input_vec += Vector3.DOWN

	if input_vec.length_squared() > 0.0:
		var target_vel := input_vec.normalized() * effective_speed
		_current_velocity = _current_velocity.lerp(target_vel, clampf(delta * acceleration, 0.0, 1.0))
		_player_ref.global_position += _current_velocity * delta
	else:
		_current_velocity = Vector3.ZERO

	_update_hud_telemetry(effective_speed)

func _on_hover_changed(_target: Node3D, _hit_point: Vector3) -> void:
	_update_hud_telemetry()

func _on_selection_changed(_target: Node3D) -> void:
	if _manipulator != null and _selection_mgr != null:
		_manipulator.set_targets(_selection_mgr.get_selected_nodes())
	_update_hud_telemetry()

func _on_object_transformed(target: Node3D) -> void:
	if _serializer != null and target != null: _serializer.record_modification(target)
	if _selection_mgr != null and target != null: _selection_mgr.mark_prop_modified(target)
	_update_hud_telemetry()

func _on_object_cloned(new_instance: Node3D) -> void:
	if _serializer != null and new_instance != null:
		var asset_id: String = str(new_instance.get_meta("catalog_asset_id", "prop"))
		_serializer.record_spawn(new_instance, asset_id)
		if _selection_mgr != null: _selection_mgr.mark_prop_modified(new_instance)
	_update_hud_telemetry()

func _clone_target_or_hovered() -> void:
	var targets := _selection_mgr.get_selected_nodes() if _selection_mgr != null else []
	if targets.is_empty() and _selection_mgr != null and _selection_mgr.get_hovered_node() != null: targets = [_selection_mgr.get_hovered_node()]
	if targets.is_empty() or _manipulator == null: return
	_manipulator.set_targets(targets)
	var clones := _manipulator.duplicate_targets(_camera_ref)
	if clones.is_empty(): return
	if _selection_mgr != null:
		_selection_mgr.clear_selection()
		for cl in clones: _selection_mgr.select_node(cl, true)
	_show_toast("[ ARQUITECTO ] %d OBJETO(S) CLONADOS" % clones.size(), 2.0)
	_update_hud_telemetry()

func _on_object_deleted(deleted_node: Node3D) -> void:
	if _selection_mgr != null and deleted_node != null: _selection_mgr.notify_node_deleted(deleted_node)
	if _serializer != null and deleted_node != null: _serializer.record_deletion(deleted_node)
	_update_hud_telemetry()

func _delete_target_or_hovered() -> void:
	var targets := _selection_mgr.get_selected_nodes() if _selection_mgr != null else []
	if targets.is_empty() and _selection_mgr != null and _selection_mgr.get_hovered_node() != null: targets = [_selection_mgr.get_hovered_node()]
	if targets.is_empty(): return
	var count := targets.size()
	for t in targets:
		if is_instance_valid(t):
			if _selection_mgr != null: _selection_mgr.notify_node_deleted(t)
			_on_object_deleted(t)
			t.queue_free()
	if _manipulator != null: _manipulator.set_targets([])
	_show_toast("[ ARQUITECTO ] %d OBJETO(S) ELIMINADOS" % count, 2.5)
	_update_hud_telemetry()

func _on_palette_asset_spawn_requested(asset_id: String) -> void:
	if _camera_ref == null or _player_ref == null: return
	var cam_pos := _camera_ref.global_position
	var forward := -_camera_ref.global_transform.basis.z
	var spawn_pos := cam_pos + forward * 18.0
	spawn_pos.y = TerrainCollisionGenerator.sample_height(spawn_pos.x, spawn_pos.z)

	var current_scene := get_tree().current_scene if get_tree() != null else null
	var parent_node: Node = current_scene if current_scene != null else self
	var spawned := EditorAssetCatalog.spawn_asset(asset_id, spawn_pos, parent_node)
	if spawned != null:
		if _serializer != null: _serializer.record_spawn(spawned, asset_id)
		if _selection_mgr != null:
			_selection_mgr.select_node(spawned)
			_selection_mgr.mark_prop_modified(spawned)
		elif _manipulator != null: _manipulator.set_targets([spawned])
		_update_hud_telemetry()

func _save_world_layout() -> void:
	if _serializer == null: return
	var ok := _serializer.save_to_json()
	if ok and _selection_mgr != null: _selection_mgr.clear_modified_flags()
	_show_toast("[ ARQUITECTO ] GUARDADO EN WORLD_LAYOUT_OVERRIDES.JSON" if ok else "[ ERROR ] NO SE PUDO GUARDAR")

func toggle_outliner() -> void:
	if _outliner_panel != null:
		_outliner_panel.toggle_panel(); _update_hud_telemetry()

func _on_outliner_focus_requested(target: Node3D) -> void:
	if target == null or not is_instance_valid(target) or _player_ref == null: return
	var p := target.global_position
	_player_ref.global_position = Vector3(p.x, p.y + 4.0, p.z + 10.0)
	_current_velocity = Vector3.ZERO
	var dir := (p - _player_ref.global_position).normalized()
	_yaw = atan2(-dir.x, -dir.z)
	_pitch = asin(clampf(dir.y, -0.99, 0.99))
	if _player_ref != null: _player_ref.rotation.y = _yaw
	if _camera_ref != null: _camera_ref.rotation.x = _pitch
	_update_hud_telemetry()

func _show_toast(msg: String, duration: float = 2.5) -> void:
	if _hud_overlay != null: _hud_overlay.show_toast(msg, duration)

func _on_palette_closed() -> void:
	_update_hud_telemetry()

func teleport_to_sector(sector_index: int) -> void:
	if sector_index < 0 or sector_index >= SECTOR_HUBS.size() or _player_ref == null: return
	var hub: Dictionary = SECTOR_HUBS[sector_index]
	var pos_2d: Vector2 = hub["pos"]
	var gy := TerrainCollisionGenerator.sample_height(pos_2d.x, pos_2d.y)
	_player_ref.global_position = Vector3(pos_2d.x, gy + 8.0, pos_2d.y)
	_current_velocity = Vector3.ZERO; _update_hud_telemetry()

func _snap_to_terrain() -> void:
	if _player_ref == null: return
	var p := _player_ref.global_position
	_player_ref.global_position = Vector3(p.x, TerrainCollisionGenerator.sample_height(p.x, p.z) + 1.8, p.z)
	_current_velocity = Vector3.ZERO

func _suspend_survival_handicaps() -> void:
	if _player_ref == null: return
	if "stamina" in _player_ref and "max_stamina" in _player_ref: _player_ref.set("stamina", _player_ref.get("max_stamina"))
	if "current_health" in _player_ref and "max_health" in _player_ref: _player_ref.set("current_health", _player_ref.get("max_health"))
	if "weapon_system" in _player_ref and _player_ref.get("weapon_system") != null and "grit_index" in _player_ref.get("weapon_system"):
		_player_ref.get("weapon_system").set("grit_index", 0.0)

func _update_hud_telemetry(cur_spd: float = 25.0) -> void:
	# Context-sensitive formatting lives in EditorHUDOverlay.render_editor_state().
	if _hud_overlay == null: return
	_hud_overlay.render_editor_state(_palette_hud, _manipulator, _selection_mgr, _player_ref, cur_spd, _speed_multiplier)
