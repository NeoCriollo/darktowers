class_name MapModal
extends PanelContainer

## Diegetic Tactical Map System ("Military Scouting Chart") — "Dark Towers: The Path of Ka"
## Modular Map Coordinator Façade. Delegates cartographic contours & 2D rendering to
## MapContourRenderer, and landmark registration & UI directory tree to MapPOIRegistry.

signal map_toggled(is_open: bool)
signal poi_discovered(poi_id: String, localized_name: String)
signal poi_selected(poi_id: String, poi_data: Dictionary)
signal status_readout_emitted(message: String)

# --- PALETTE CONSTANTS ("Military Scouting Chart" & "Glass & Iron") ---
const MODAL_BG_COLOR: Color = Color(0.04, 0.035, 0.03, 0.95)
const MODAL_BORDER_COLOR: Color = Color(0.92, 0.72, 0.38, 0.4)
const CANVAS_BG_COLOR: Color = Color(0.028, 0.025, 0.022, 0.98)
const AMBER_PRIMARY: Color = Color(0.92, 0.72, 0.38, 1.0)
const AMBER_BRIGHT: Color = Color(0.98, 0.84, 0.48, 1.0)
const AMBER_DIM: Color = Color(0.92, 0.72, 0.38, 0.32)
const AMBER_GRID_MINOR: Color = Color(0.92, 0.72, 0.38, 0.07)
const AMBER_GRID_MAJOR: Color = Color(0.92, 0.72, 0.38, 0.16)
const CONTOUR_LOW_COLOR: Color = Color(0.58, 0.48, 0.32, 0.18)
const CONTOUR_MID_COLOR: Color = Color(0.78, 0.62, 0.36, 0.25)
const CONTOUR_HIGH_COLOR: Color = Color(0.92, 0.74, 0.40, 0.35)
const KA_BEACON_CRIMSON: Color = Color(1.0, 0.38, 0.12, 1.0)
const KA_BEACON_GLOW: Color = Color(1.0, 0.45, 0.16, 0.38)
const FOG_OF_WAR_COLOR: Color = Color(0.02, 0.018, 0.015, 0.68)

# --- WORLD & CARTOGRAPHIC CONSTANTS ---
const DEFAULT_WORLD_EXTENT: float = 1250.0
const MIN_ZOOM: float = 0.50
const MAX_ZOOM: float = 3.60
const ZOOM_STEP: float = 0.18
const DEFAULT_DISCOVERY_RADIUS: float = 180.0
const DARK_TOWER_VALLEY_AXIS_RAD: float = 0.785
const DARK_TOWER_COORDINATES: Vector3 = Vector3(700.0, 0.0, 700.0)

# --- CONFIGURATION EXPORTS ---
@export var world_half_extent: float = DEFAULT_WORLD_EXTENT
@export var zoom_level: float = 1.0:
	set(value):
		zoom_level = clampf(value, MIN_ZOOM, MAX_ZOOM)
		_on_view_transform_changed()
@export var pan_offset: Vector2 = Vector2.ZERO:
	set(value):
		pan_offset = _clamp_pan_offset(value)
		_on_view_transform_changed()
@export var discovery_radius_meters: float = DEFAULT_DISCOVERY_RADIUS
@export var pause_gameplay_when_open: bool = false
@export var dim_backdrop_when_open: bool = true

# --- RUNTIME TRACKING STATE ---
var is_map_open: bool = false
var player_world_position: Vector3 = Vector3.ZERO
var player_facing_yaw_rad: float = 0.0
var dark_tower_world_position: Vector3 = DARK_TOWER_COORDINATES
var ka_origin_world_position: Vector3 = Vector3.ZERO

var _player_ref: Node3D = null; var _world_manager_ref: Node = null
var _prop_scatter_ref: Node3D = null; var _hud_ref: CanvasLayer = null

var _pois: Dictionary = {}; var _canyon_corridors: Array[Dictionary] = []; var _contour_polylines: Array[Dictionary] = []
var _selected_poi_id: String = "dark_tower_beacon"; var _hovered_poi_id: String = ""
var _cursor_world_pos: Vector3 = Vector3.ZERO; var _has_cursor_on_map: bool = false
var _is_dragging_map: bool = false; var _drag_start_mouse: Vector2 = Vector2.ZERO; var _drag_start_pan: Vector2 = Vector2.ZERO
var _pulse_time: float = 0.0; var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _open_tween: Tween = null; var _serif_font: SystemFont = null; var _mono_font: SystemFont = null; var _is_initialized: bool = false

# --- SUB-CONTROLLER DELEGATES ---
var _contour_renderer: MapContourRenderer = null
var _poi_registry: MapPOIRegistry = null

# --- UI NODE REFERENCES ---
var _backdrop_dimmer: ColorRect = null; var _title_label: Label = null; var _subtitle_label: Label = null
var _btn_center: Button = null; var _btn_reset_zoom: Button = null; var _btn_close: Button = null
var _map_viewport_frame: PanelContainer = null; var _sub_viewport_container: SubViewportContainer = null; var _sub_viewport: SubViewport = null
var _map_canvas: Control = null; var _telemetry_pos_label: Label = null; var _telemetry_beacon_label: Label = null; var _telemetry_cursor_label: Label = null
var _legend_header_label: Label = null; var _legend_items_vbox: VBoxContainer = null; var _poi_header_label: Label = null; var _poi_list_vbox: VBoxContainer = null
var _selected_poi_title_label: Label = null; var _selected_poi_coords_label: Label = null; var _selected_poi_status_label: Label = null; var _footer_hints_label: Label = null

# ─── Inner Cartographic 2D Canvas Renderer ───────────────────────────────────
class _MapCanvasControl extends Control:
	var modal: MapModal = null
	func _init(p_modal: MapModal = null) -> void:
		modal = p_modal
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		if modal != null and not draw.is_connected(modal._on_canvas_draw):
			modal._draw_cartographic_canvas(self)

func _on_canvas_draw() -> void:
	if _map_canvas != null:
		_draw_cartographic_canvas(_map_canvas)

func get_live_player_position() -> Vector3:
	if _player_ref != null and is_instance_valid(_player_ref): return _player_ref.global_position
	if _world_manager_ref != null and is_instance_valid(_world_manager_ref) and _world_manager_ref.has_method("get_player_position"):
		return _world_manager_ref.call("get_player_position")
	var wm := get_node_or_null("/root/WorldManager")
	if wm != null and wm.has_method("get_player_position"): return wm.call("get_player_position")
	var glob := get_node_or_null("/root/Global")
	if glob != null and "player_pos" in glob: return glob.player_pos
	return player_world_position

func get_live_player_yaw() -> float:
	if _player_ref != null and is_instance_valid(_player_ref): return _extract_player_yaw(_player_ref)
	var glob := get_node_or_null("/root/Global")
	if glob != null and "player_yaw" in glob: return float(glob.player_yaw)
	return player_facing_yaw_rad

# ─── Lifecycle & Sub-Controllers ─────────────────────────────────────────────

func _init() -> void:
	_contour_renderer = MapContourRenderer.new(self)
	_poi_registry = MapPOIRegistry.new(self)
	_initialize_default_pois()

func _ready() -> void:
	_ensure_initialized()
	if not is_map_open: visible = false

func _ensure_initialized() -> void:
	if _is_initialized: return
	_is_initialized = true; process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions(); _init_typography(); _apply_modal_styling()
	_build_or_resolve_ui_tree(); _build_topographic_contours()
	if _pois.is_empty(): _initialize_default_pois()
	else: _rebuild_poi_directory_buttons()
	Localization.register_listener(_on_language_changed)
	_refresh_localized_strings(); _refresh_telemetry_labels(); _sync_with_world_save_data()

func _exit_tree() -> void:
	Localization.unregister_listener(_on_language_changed)

func _ensure_input_actions() -> void:
	for action in ["toggle_recon_map", "toggle_map", "map", "ui_map"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for code in [KEY_M]:
			var exists := false
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey and (ev.physical_keycode == code or ev.keycode == code):
					exists = true; break
			if not exists:
				var new_ev := InputEventKey.new(); new_ev.physical_keycode = code; new_ev.device = -1
				InputMap.action_add_event(action, new_ev)

func _init_typography() -> void:
	_serif_font = SystemFont.new(); _serif_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Palatino", "Times New Roman", "Serif"]); _serif_font.font_weight = 600
	_mono_font = SystemFont.new(); _mono_font.font_names = PackedStringArray(["JetBrains Mono", "Menlo", "Monaco", "Courier New", "Monospace"]); _mono_font.font_weight = 500

# ─── Delegated Cartography & Projections ─────────────────────────────────────

func get_map_canvas_size() -> Vector2: return _contour_renderer.get_map_canvas_size()
func world_to_map(w_pos: Vector3, c_size: Vector2 = Vector2.ZERO) -> Vector2: return _contour_renderer.world_to_map(w_pos, c_size)
func map_to_world(m_pos: Vector2, c_size: Vector2 = Vector2.ZERO) -> Vector3: return _contour_renderer.map_to_world(m_pos, c_size)
func _meters_to_pixels(meters: float, c_size: Vector2 = Vector2.ZERO) -> float: return _contour_renderer.meters_to_pixels(meters, c_size)
func _sample_world_elevation(world_x: float, world_z: float) -> float: return _contour_renderer.sample_world_elevation(world_x, world_z)
func _build_topographic_contours() -> void: _contour_renderer.build_topographic_contours()
func _draw_cartographic_canvas(canvas: Control) -> void: _contour_renderer.draw_cartographic_canvas(canvas)

# ─── Delegated POI Registry & UI Construction ────────────────────────────────

func _initialize_default_pois() -> void: _poi_registry.initialize_default_pois()
func register_poi(p_id: String, key: String, pos: Vector3, cat: String = "POI", disc: bool = false, alw: bool = false, rad: float = 24.0) -> void:
	_poi_registry.register_poi(p_id, key, pos, cat, disc, alw, rad)
func discover_poi(poi_id: String) -> bool: return _poi_registry.discover_poi(poi_id)
func is_poi_visible_on_map(poi_id: String) -> bool: return _poi_registry.is_poi_visible_on_map(poi_id)
func get_poi_data(poi_id: String) -> Dictionary: return _poi_registry.get_poi_data(poi_id)
func get_all_pois() -> Dictionary: return _poi_registry.get_all_pois()
func get_poi_localized_name(poi_id: String) -> String: return _poi_registry.get_poi_localized_name(poi_id)
func unlock_basin_region(basin_name: String) -> void: _poi_registry.unlock_basin_region(basin_name)
func _sync_with_world_save_data() -> void: _poi_registry.sync_with_world_save_data()
func on_siege_completed(basin_id: String) -> void: _poi_registry.on_siege_completed(basin_id)
func _on_siege_completed(basin_id: String) -> void: _poi_registry.on_siege_completed(basin_id)
func _check_poi_proximity_discovery(pos: Vector3) -> void: _poi_registry.check_poi_proximity_discovery(pos)
func _find_poi_at_canvas_pos(pos: Vector2) -> String: return _poi_registry.find_poi_at_canvas_pos(pos)
func _rebuild_legend_rows() -> void: _poi_registry.rebuild_legend_rows()
func _rebuild_poi_directory_buttons() -> void: _poi_registry.rebuild_poi_directory_buttons()
func _refresh_selected_poi_inspector() -> void: _poi_registry.refresh_selected_poi_inspector()
func _apply_modal_styling() -> void: _poi_registry.apply_modal_styling()
func _build_or_resolve_ui_tree() -> void: _poi_registry.build_or_resolve_ui_tree()

# ─── Pan, Zoom & Viewport Controls ───────────────────────────────────────────

func _clamp_pan_offset(raw_offset: Vector2) -> Vector2:
	var c_size: Vector2 = get_map_canvas_size()
	var max_x: float = maxf(240.0, c_size.x * 0.75 * zoom_level)
	var max_y: float = maxf(240.0, c_size.y * 0.75 * zoom_level)
	return Vector2(clampf(raw_offset.x, -max_x, max_x), clampf(raw_offset.y, -max_y, max_y))

func _on_view_transform_changed() -> void:
	if _btn_reset_zoom != null: _btn_reset_zoom.text = "[ Z / %.1fx ]" % zoom_level
	_refresh_telemetry_labels()
	if _map_canvas != null: _map_canvas.queue_redraw()

func pan_by_pixels(delta_pixels: Vector2) -> void: pan_offset = _clamp_pan_offset(pan_offset + delta_pixels)

func zoom_at_point(zoom_cmd: float, pivot_canvas_pos: Vector2 = Vector2.ZERO) -> void:
	var c_size: Vector2 = get_map_canvas_size()
	var pivot: Vector2 = pivot_canvas_pos if pivot_canvas_pos != Vector2.ZERO else (c_size * 0.5)
	var world_before: Vector3 = map_to_world(pivot, c_size)
	zoom_level = clampf(zoom_level + zoom_cmd, MIN_ZOOM, MAX_ZOOM)
	var mapped_after: Vector2 = world_to_map(world_before, c_size)
	pan_offset = _clamp_pan_offset(pan_offset + (pivot - mapped_after))

func center_on_player() -> void: center_on_world_pos(get_live_player_position())

func center_on_world_pos(world_pos: Vector3) -> void:
	pan_offset = Vector2.ZERO
	var c_size: Vector2 = get_map_canvas_size()
	var mapped: Vector2 = world_to_map(world_pos, c_size)
	pan_offset = _clamp_pan_offset((c_size * 0.5) - mapped)

func reset_zoom() -> void:
	zoom_level = 1.0; pan_offset = Vector2.ZERO

func select_poi(poi_id: String, center_view: bool = false) -> void:
	if not _pois.has(poi_id): return
	_selected_poi_id = poi_id
	var poi: Dictionary = _pois[poi_id]
	if center_view and is_poi_visible_on_map(poi_id):
		center_on_world_pos(poi.get("world_pos", Vector3.ZERO))
	_refresh_selected_poi_inspector(); poi_selected.emit(poi_id, poi)
	if _map_canvas != null: _map_canvas.queue_redraw()

# ─── Modal Open / Close / Toggle State ───────────────────────────────────────

func toggle_map() -> bool:
	if is_map_open: close_map()
	else: open_map()
	return is_map_open

func toggle_chart() -> bool: return toggle_map()

func open_map() -> void:
	_ensure_initialized()
	if is_map_open and visible: return
	is_map_open = true; visible = true; mouse_filter = Control.MOUSE_FILTER_STOP; sync_from_world()
	if _contour_polylines.is_empty(): _build_topographic_contours()
	_refresh_localized_strings(); _refresh_telemetry_labels(); _set_backdrop_dimmed(true)
	if pause_gameplay_when_open and is_inside_tree() and get_tree() != null: get_tree().paused = true
	if DisplayServer.get_name() != "headless":
		_previous_mouse_mode = Input.get_mouse_mode(); Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _open_tween != null and _open_tween.is_valid(): _open_tween.kill()
	if is_inside_tree():
		modulate = Color(1.0, 1.0, 1.0, 0.0); scale = Vector2(0.96, 0.96)
		_open_tween = create_tween()
		_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_open_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_open_tween.tween_property(self, "modulate", Color.WHITE, 0.18)
		_open_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18)
	else:
		modulate = Color.WHITE; scale = Vector2.ONE
	if _map_canvas != null: _map_canvas.queue_redraw()
	_emit_localized_status(Localization.t("MAP_STATUS_OPENED"))
	map_toggled.emit(true)

func close_map() -> void:
	if DisplayServer.get_name() != "headless": Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not is_map_open and not visible: return
	is_map_open = false; _is_dragging_map = false; _set_backdrop_dimmed(false)
	if pause_gameplay_when_open and is_inside_tree() and get_tree() != null: get_tree().paused = false
	if _open_tween != null and _open_tween.is_valid(): _open_tween.kill()
	visible = false; mouse_filter = Control.MOUSE_FILTER_IGNORE; modulate = Color.WHITE; scale = Vector2.ONE
	_emit_localized_status(Localization.t("MAP_STATUS_CLOSED")); map_toggled.emit(false)

func _set_backdrop_dimmed(active: bool) -> void:
	if not dim_backdrop_when_open: return
	var p := get_parent()
	if p == null: return
	if _backdrop_dimmer == null or not is_instance_valid(_backdrop_dimmer):
		_backdrop_dimmer = p.get_node_or_null("MapBackdropDimmer") as ColorRect
		if _backdrop_dimmer == null and p is Control:
			_backdrop_dimmer = ColorRect.new(); _backdrop_dimmer.name = "MapBackdropDimmer"
			_backdrop_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_backdrop_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_backdrop_dimmer.color = Color(0.01, 0.01, 0.008, 0.0)
			p.add_child(_backdrop_dimmer); p.move_child(_backdrop_dimmer, maxi(0, get_index() - 1))
	if _backdrop_dimmer != null:
		_backdrop_dimmer.visible = active; _backdrop_dimmer.color = Color(0.015, 0.012, 0.01, 0.58 if active else 0.0)

func _emit_localized_status(msg: String) -> void:
	status_readout_emitted.emit(msg)
	if _hud_ref != null and is_instance_valid(_hud_ref) and _hud_ref.has_method("show_notification"):
		_hud_ref.call("show_notification", msg, 2.6)

# ─── World Binding & Telemetry ───────────────────────────────────────────────

func bind_world_context(player_node: Node3D, world_manager: Node = null, prop_scatter: Node3D = null, hud_node: CanvasLayer = null) -> void:
	_player_ref = player_node; _world_manager_ref = world_manager; _prop_scatter_ref = prop_scatter; _hud_ref = hud_node; sync_from_world()

func sync_from_world() -> void:
	if _player_ref != null and is_instance_valid(_player_ref):
		update_player_telemetry(_player_ref.global_position, _extract_player_yaw(_player_ref))
	if _prop_scatter_ref != null and is_instance_valid(_prop_scatter_ref):
		for group in _prop_scatter_ref.get_children():
			if not (group is Node3D): continue
			var g_name: String = String(group.name)
			if g_name == "HorizonLandmark_DarkTower":
				dark_tower_world_position = (group as Node3D).global_position
				if _pois.has("dark_tower_beacon"): _pois["dark_tower_beacon"]["world_pos"] = dark_tower_world_position
			elif g_name.begins_with("Vignettes_") and not ("Escarpment" in g_name or "Sanctuary" in g_name or "Medieval_Ruins" in g_name):
				for cluster in group.get_children():
					if not (cluster is Node3D): continue
					var c_node := cluster as Node3D
					var c_id: String = "scatter_" + String(c_node.name).to_lower()
					if not _pois.has(c_id):
						var cat := "OVERPASS" if "Overpass" in g_name else ("CARAVAN" if "Caravan" in g_name else ("MONOLITH" if "Monolith" in g_name else "OUTPOST"))
						var tr := "MAP_POI_HIGHWAY_JUNCTION" if "Overpass" in g_name else ("MAP_POI_CARAVAN_WRECK" if "Caravan" in g_name else ("MAP_POI_BRUTALIST_MONOLITH" if "Monolith" in g_name else ("MAP_POI_WAYSTATION_RANGE" if "BallisticRange" in g_name else "MAP_POI_SCAVENGER_OUTPOST")))
						var dist: float = Vector2(c_node.global_position.x, c_node.global_position.z).length()
						register_poi(c_id, tr, c_node.global_position, cat, dist <= discovery_radius_meters, false, 18.0)

func _extract_player_yaw(player_node: Node3D) -> float:
	var arm := player_node.get_node_or_null("SpringArm3D") as Node3D
	if arm != null: return arm.rotation.y
	var vis := player_node.get_node_or_null("Visuals") as Node3D
	return vis.rotation.y if vis != null else player_node.rotation.y

func update_player_telemetry(world_pos: Vector3, facing_yaw_rad: float) -> void:
	player_world_position = world_pos; player_facing_yaw_rad = facing_yaw_rad
	_check_poi_proximity_discovery(world_pos); _refresh_telemetry_labels()
	if _map_canvas != null and is_map_open: _map_canvas.queue_redraw()

# ─── Process & Input Routing ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not is_map_open or not visible: return
	_pulse_time += delta
	var live_pos := get_live_player_position()
	var live_yaw := get_live_player_yaw()
	if live_pos != player_world_position or live_yaw != player_facing_yaw_rad or _player_ref != null:
		player_world_position = live_pos
		player_facing_yaw_rad = live_yaw
		_check_poi_proximity_discovery(player_world_position)
		_refresh_telemetry_labels()
	if _sub_viewport != null and _sub_viewport_container != null:
		var target_sz := Vector2i(maxi(320, int(_sub_viewport_container.size.x)), maxi(240, int(_sub_viewport_container.size.y)))
		if _sub_viewport.size != target_sz:
			_sub_viewport.size = target_sz
			if _map_canvas != null: _map_canvas.size = Vector2(target_sz.x, target_sz.y)
	if _map_canvas != null:
		if _map_canvas.size.x <= 8.0 or _map_canvas.size.y <= 8.0:
			_map_canvas.size = get_map_canvas_size()
		_map_canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_map_open or not visible: return
	var target_rect: Control = _map_canvas if _map_canvas != null else _map_viewport_frame
	if target_rect != null and (event is InputEventMouseButton or event is InputEventMouseMotion):
		var global_rect: Rect2 = target_rect.get_global_rect()
		var mouse_pos: Vector2 = (event as InputEventMouse).global_position
		if global_rect.has_point(mouse_pos) or _is_dragging_map:
			var local_ev: InputEventMouse = event.duplicate() as InputEventMouse
			local_ev.position = mouse_pos - global_rect.position
			_on_canvas_gui_input(local_ev)
			if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_map_open or not visible or not (event is InputEventKey and event.is_pressed() and not event.is_echo()): return
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if code in [KEY_ESCAPE, KEY_M] or event.is_action_pressed("toggle_recon_map") or event.is_action_pressed("map") or event.is_action_pressed("ui_map") or event.is_action_pressed("toggle_map"):
		close_map(); get_viewport().set_input_as_handled()
	elif code == KEY_C or event.is_action_pressed("crouch_or_center_map"): center_on_player(); get_viewport().set_input_as_handled()
	elif code == KEY_Z: reset_zoom(); get_viewport().set_input_as_handled()

func _on_canvas_mouse_exited() -> void:
	_has_cursor_on_map = false
	_hovered_poi_id = ""
	_refresh_telemetry_labels()

func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: zoom_at_point(ZOOM_STEP, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: zoom_at_point(-ZOOM_STEP, mb.position)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_is_dragging_map = mb.pressed
			if mb.pressed:
				_drag_start_mouse = mb.position; _drag_start_pan = pan_offset
				var clicked: String = _find_poi_at_canvas_pos(mb.position)
				if not clicked.is_empty(): select_poi(clicked, false)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_has_cursor_on_map = true; _cursor_world_pos = map_to_world(mm.position)
		if _is_dragging_map: pan_offset = _clamp_pan_offset(_drag_start_pan + (mm.position - _drag_start_mouse))
		else: _hovered_poi_id = _find_poi_at_canvas_pos(mm.position)
		_refresh_telemetry_labels()
		if _map_canvas != null: _map_canvas.queue_redraw()

# ─── Localization & Telemetry Refresh ────────────────────────────────────────

func _on_language_changed(_locale: String) -> void:
	_refresh_localized_strings()
	_rebuild_legend_rows()
	_rebuild_poi_directory_buttons()
	_refresh_telemetry_labels()
	if _map_canvas != null: _map_canvas.queue_redraw()

func _refresh_localized_strings() -> void:
	var pairs := [[_title_label, "MAP_MODAL_TITLE"], [_subtitle_label, "MAP_MODAL_SUBTITLE"], [_legend_header_label, "MAP_SECTION_LEGEND"], [_poi_header_label, "MAP_SECTION_POIS"], [_footer_hints_label, "MAP_FOOTER_CONTROLS"]]
	for p in pairs:
		if p[0] != null: p[0].text = Localization.t(p[1])

func _refresh_telemetry_labels() -> void:
	var deg: int = _yaw_to_compass_degrees(player_facing_yaw_rad)
	var cardinal: String = _degrees_to_cardinal(deg)
	if _telemetry_pos_label != null:
		_telemetry_pos_label.text = Localization.t("MAP_TELEMETRY_POS_FMT") % [
			int(round(player_world_position.x)), int(round(player_world_position.z)), deg, cardinal
		]

	if _telemetry_beacon_label != null:
		var p_xz := Vector2(player_world_position.x, player_world_position.z)
		var t_xz := Vector2(dark_tower_world_position.x, dark_tower_world_position.z)
		var dist_m: int = int(round(p_xz.distance_to(t_xz)))
		var to_tower: Vector2 = (t_xz - p_xz).normalized()
		var bearing_deg: int = posmod(int(round(rad_to_deg(atan2(to_tower.x, to_tower.y)))), 360)
		_telemetry_beacon_label.text = Localization.t("MAP_TELEMETRY_BEACON_FMT") % [dist_m, bearing_deg, zoom_level]

	if _telemetry_cursor_label != null:
		var ref_pos: Vector3 = _cursor_world_pos if _has_cursor_on_map else player_world_position
		var sector_code: String = _world_pos_to_grid_sector(ref_pos)
		_telemetry_cursor_label.text = Localization.t("MAP_TELEMETRY_CURSOR_FMT") % [
			sector_code, int(round(ref_pos.x)), int(round(ref_pos.z)), ref_pos.y
		]

	_refresh_selected_poi_inspector()

func _yaw_to_compass_degrees(yaw_rad: float) -> int:
	var fwd := Vector2(-sin(yaw_rad), -cos(yaw_rad))
	return posmod(int(round(rad_to_deg(atan2(fwd.x, -fwd.y)))), 360)

func _degrees_to_cardinal(deg: int) -> String:
	var dirs: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return dirs[int(round(float(posmod(deg, 360)) / 45.0)) % 8]

func _world_pos_to_grid_sector(pos: Vector3) -> String:
	var cols: Array[String] = ["A", "B", "C", "D", "E"]
	var cx: int = clampi(int(floor((pos.x + world_half_extent) / 100.0)), 0, 4)
	var cz: int = clampi(int(floor((world_half_extent - pos.z) / 100.0)) + 1, 1, 5)
	return "%s%d" % [cols[cx], cz]
