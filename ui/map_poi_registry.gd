class_name MapPOIRegistry
extends RefCounted

## Points of Interest (POI) Registry, UI Hierarchy & Sidebar Directory Sub-Controller.
## Manages landmark registry, regional basins, discovery proximity, save data synchronization,
## tactical button/label creation, and directory list reconstruction.

var modal: MapModal = null

const BASIN_TO_POI_MAP: Dictionary = {
	"waystation_sanctuary": "region_waystation_sanctuary", "sw_desolation": "region_sw_desolation",
	"south_salt": "region_dead_creek_salt_flats", "cradle": "region_caliche_cradle",
	"west_gorge": "region_rust_gorge_defile", "north_alkali": "region_bleached_alkali_sink",
	"east_dunes": "region_great_shifting_erg", "monolith_pass": "region_threshold_dark_tower"
}

func _init(p_modal: MapModal = null) -> void:
	modal = p_modal

# ─── POI Initialization & Management ─────────────────────────────────────────

func initialize_default_pois() -> void:
	modal._pois.clear()
	modal._canyon_corridors.clear()

	modal.dark_tower_world_position = Vector3(700.0, modal._sample_world_elevation(700.0, 700.0), 700.0)
	register_poi("dark_tower_beacon", "MAP_POI_DARK_TOWER", modal.dark_tower_world_position, "DARK_TOWER", true, true, 120.0)

	var poi_specs := [
		["region_waystation_sanctuary", "REGION_WAYSTATION_SANCTUARY", Vector3(-1000.0, 0.0, -800.0), "SANCTUARY", true, true, 150.0], ["region_sw_desolation", "REGION_SOUTHWEST_DESOLATION", Vector3(-550.0, 0.0, -900.0), "REGION", true, true, 250.0],
		["region_dead_creek_salt_flats", "REGION_DEAD_CREEK_SALT_FLATS", Vector3(-150.0, 0.0, -550.0), "REGION", false, false, 250.0], ["region_caliche_cradle", "REGION_CALICHE_CRADLE", Vector3(0.0, 0.0, 0.0), "REGION", true, true, 250.0],
		["region_rust_gorge_defile", "REGION_RUST_GORGE_DEFILE", Vector3(-650.0, 0.0, 50.0), "REGION", false, false, 250.0], ["region_bleached_alkali_sink", "REGION_BLEACHED_ALKALI_SINK", Vector3(0.0, 0.0, 650.0), "REGION", false, false, 250.0],
		["region_great_shifting_erg", "REGION_THE_GREAT_SHIFTING_ERG", Vector3(650.0, 0.0, 50.0), "REGION", false, false, 250.0], ["region_threshold_dark_tower", "REGION_THRESHOLD_OF_THE_DARK_TOWER", Vector3(650.0, 0.0, 650.0), "REGION", false, false, 250.0],
		["poi_rust_gorge_highway", "MAP_POI_HIGHWAY_JUNCTION", Vector3(-650.0, 0.0, 15.0), "OVERPASS", true, false, 24.0], ["poi_cradle_overlook", "MAP_POI_CRADLE_OVERLOOK", Vector3(140.0, 0.0, 140.0), "OVERLOOK", true, false, 24.0],
		["poi_erg_monolith_ruin", "MAP_POI_BRUTALIST_MONOLITH", Vector3(680.0, 0.0, -20.0), "MONOLITH", false, false, 24.0], ["poi_tower_fortress_barrier", "MAP_POI_OUTER_FORTRESS", Vector3(650.0, 0.0, 650.0), "FORTRESS", false, false, 32.0],
		["poi_waystation_interior", "MAP_POI_WAYSTATION_SANCTUARY", Vector3(-1020.0, 0.0, -820.0), "OUTPOST", true, true, 20.0], ["poi_threshold_warning_gate", "MAP_POI_THRESHOLD_GATE", Vector3(-900.0, 0.0, -820.0), "GATE", true, true, 18.0],
		["poi_sw_desolation_beacon", "BEACON_SW_DESOLATION", Vector3(-530.0, 0.0, -880.0), "MONOLITH", false, false, 20.0], ["poi_south_salt_beacon", "BEACON_SOUTH_SALT", Vector3(-130.0, 0.0, -530.0), "MONOLITH", false, false, 20.0],
		["poi_cradle_beacon", "BEACON_CALICHE_CRADLE", Vector3(25.0, 0.0, -20.0), "MONOLITH", true, false, 20.0], ["poi_west_gorge_beacon", "BEACON_RUST_GORGE", Vector3(-630.0, 0.0, 70.0), "MONOLITH", false, false, 20.0],
		["poi_north_alkali_beacon", "BEACON_NORTH_ALKALI", Vector3(45.0, 0.0, 680.0), "MONOLITH", false, false, 24.0], ["poi_east_dunes_beacon", "BEACON_EAST_DUNES", Vector3(670.0, 0.0, 70.0), "MONOLITH", false, false, 20.0],
		["poi_monolith_pass_beacon", "BEACON_MONOLITH_PASS", Vector3(630.0, 0.0, 630.0), "MONOLITH", false, false, 24.0], ["poi_thinny_beam_abyss", "MAP_POI_THINNY_BEAM_ABYSS", Vector3(325.0, 0.0, 325.0), "THINNY", true, true, 160.0],
		["poi_thinny_nw_hollow", "MAP_POI_THINNY_NW_HOLLOW", Vector3(-650.0, 0.0, 650.0), "THINNY", true, false, 180.0], ["poi_thinny_se_rift", "MAP_POI_THINNY_SE_RIFT", Vector3(650.0, 0.0, -650.0), "THINNY", true, false, 180.0]
	]
	for p in poi_specs:
		register_poi(p[0], p[1], p[2], p[3], p[4], p[5], p[6])

	modal._canyon_corridors = [
		{"id": "pass_sanctuary_to_sw", "from": "waystation_sanctuary", "to": "sw_desolation", "a": Vector2(-900.0, -820.0), "b": Vector2(-650.0, -880.0), "choke": Vector2(-900.0, -820.0), "blocked": false, "hazard": "NONE"},
		{"id": "pass_sanctuary_to_salt", "from": "waystation_sanctuary", "to": "south_salt", "a": Vector2(-950.0, -780.0), "b": Vector2(-280.0, -650.0), "choke": Vector2(-615.0, -715.0), "blocked": false, "hazard": "SALT_CORROSION"},
		{"id": "pass_sw_to_salt", "from": "sw_desolation", "to": "south_salt", "a": Vector2(-450.0, -800.0), "b": Vector2(-250.0, -650.0), "choke": Vector2(-350.0, -725.0), "blocked": false, "hazard": "SILICA_HABOOB"},
		{"id": "pass_salt_to_cradle", "from": "south_salt", "to": "cradle", "a": Vector2(-100.0, -420.0), "b": Vector2(-30.0, -150.0), "choke": Vector2(-65.0, -285.0), "blocked": false, "hazard": "SALT_CORROSION"},
		{"id": "pass_cradle_to_gorge", "from": "cradle", "to": "west_gorge", "a": Vector2(-150.0, 15.0), "b": Vector2(-500.0, 40.0), "choke": Vector2(-325.0, 27.5), "blocked": false, "hazard": "IRON_OXIDE"},
		{"id": "pass_cradle_to_north", "from": "cradle", "to": "north_alkali", "a": Vector2(0.0, 150.0), "b": Vector2(0.0, 500.0), "choke": Vector2(0.0, 325.0), "blocked": false, "hazard": "NONE"},
		{"id": "pass_cradle_to_east", "from": "cradle", "to": "east_dunes", "a": Vector2(150.0, 15.0), "b": Vector2(500.0, 40.0), "choke": Vector2(325.0, 27.5), "blocked": false, "hazard": "SILICA_HABOOB"},
		{"id": "pass_gorge_to_north", "from": "west_gorge", "to": "north_alkali", "a": Vector2(-500.0, 180.0), "b": Vector2(-150.0, 520.0), "choke": Vector2(-325.0, 350.0), "blocked": false, "hazard": "IRON_OXIDE"},
		{"id": "pass_north_to_monolith", "from": "north_alkali", "to": "monolith_pass", "a": Vector2(150.0, 650.0), "b": Vector2(500.0, 650.0), "choke": Vector2(325.0, 650.0), "blocked": false, "hazard": "NONE"},
		{"id": "pass_east_to_monolith", "from": "east_dunes", "to": "monolith_pass", "a": Vector2(650.0, 150.0), "b": Vector2(650.0, 500.0), "choke": Vector2(650.0, 325.0), "blocked": false, "hazard": "SILICA_HABOOB"},
		{"id": "connector_cradle_to_monolith_thinny", "from": "cradle", "to": "monolith_pass", "a": Vector2(140.0, 140.0), "b": Vector2(585.0, 585.0), "choke": Vector2(325.0, 325.0), "blocked": true, "hazard": "THINNY_DISTORTION"}
	]

	rebuild_poi_directory_buttons()

func register_poi(poi_id: String, translation_key: String, world_pos: Vector3, category: String = "POI", discovered: bool = false, always_visible: bool = false, radius: float = 24.0) -> void:
	modal._pois[poi_id] = {
		"id": poi_id, "key": translation_key, "world_pos": world_pos,
		"category": category, "discovered": discovered,
		"always_visible": always_visible, "radius": radius
	}

func discover_poi(poi_id: String) -> bool:
	if not modal._pois.has(poi_id): return false
	var poi: Dictionary = modal._pois[poi_id]
	if poi.get("discovered", false): return false
	poi["discovered"] = true
	modal._pois[poi_id] = poi
	var loc_name: String = get_poi_localized_name(poi_id)
	modal.poi_discovered.emit(poi_id, loc_name)
	modal.status_readout_emitted.emit(Localization.t("MAP_STATUS_POI_DISCOVERED") % loc_name)
	rebuild_poi_directory_buttons()
	if modal._map_canvas != null: modal._map_canvas.queue_redraw()
	return true

func is_poi_visible_on_map(poi_id: String) -> bool:
	if not modal._pois.has(poi_id): return false
	var poi: Dictionary = modal._pois[poi_id]
	return bool(poi.get("always_visible", false)) or bool(poi.get("discovered", false))

func get_poi_data(poi_id: String) -> Dictionary: return modal._pois.get(poi_id, {})
func get_all_pois() -> Dictionary: return modal._pois

func get_poi_localized_name(poi_id: String) -> String:
	if not modal._pois.has(poi_id): return poi_id
	var key: String = String(modal._pois[poi_id].get("key", poi_id))
	return Localization.t(key)

func unlock_basin_region(basin_name: String) -> void:
	var lower_id: String = basin_name.to_lower().strip_edges()
	if BASIN_TO_POI_MAP.has(lower_id):
		discover_poi(String(BASIN_TO_POI_MAP[lower_id]))
	else:
		for k in modal._pois.keys():
			if k.to_lower().contains(lower_id):
				discover_poi(k)

func sync_with_world_save_data() -> void:
	var wsd = modal.get_node_or_null("/root/WorldSaveData")
	if wsd == null: return
	if "liberated_basins" in wsd and wsd.liberated_basins is Array:
		for b in wsd.liberated_basins: unlock_basin_region(String(b))
	if wsd.has_signal("basin_liberated") and not wsd.basin_liberated.is_connected(unlock_basin_region):
		wsd.basin_liberated.connect(unlock_basin_region)

func check_poi_proximity_discovery(player_pos: Vector3) -> void:
	for poi_id in modal._pois.keys():
		var poi: Dictionary = modal._pois[poi_id]
		if poi.get("discovered", false): continue
		var w_pos: Vector3 = poi.get("world_pos", Vector3.ZERO)
		var dist_sq: float = Vector2(player_pos.x - w_pos.x, player_pos.z - w_pos.z).length_squared()
		if dist_sq <= modal.discovery_radius_meters * modal.discovery_radius_meters:
			discover_poi(poi_id)

func find_poi_at_canvas_pos(canvas_pos: Vector2) -> String:
	var closest_id: String = ""
	var closest_dist_sq: float = 24.0 * 24.0
	for poi_id in modal._pois.keys():
		if not is_poi_visible_on_map(poi_id): continue
		var w_pos: Vector3 = modal._pois[poi_id].get("world_pos", Vector3.ZERO)
		var map_pt: Vector2 = modal.world_to_map(w_pos)
		var d_sq: float = canvas_pos.distance_squared_to(map_pt)
		if d_sq < closest_dist_sq:
			closest_dist_sq = d_sq
			closest_id = poi_id
	return closest_id

# ─── Sidebar Directory, Legend & Inspector ───────────────────────────────────

func rebuild_legend_rows() -> void:
	if modal._legend_items_vbox == null: return
	for child in modal._legend_items_vbox.get_children(): child.queue_free()
	var legend_specs := [
		["MAP_LEGEND_PLAYER", MapModal.AMBER_BRIGHT], ["MAP_LEGEND_TOWER", MapModal.KA_BEACON_CRIMSON],
		["MAP_LEGEND_REGION", MapModal.AMBER_PRIMARY], ["MAP_LEGEND_OUTPOST", Color(0.86, 0.76, 0.56, 0.95)],
		["MAP_LEGEND_OVERPASS", Color(0.80, 0.72, 0.58, 0.90)], ["MAP_LEGEND_CARAVAN", Color(0.76, 0.68, 0.54, 0.90)]
	]
	for spec in legend_specs:
		var lbl := make_mono_label(spec[0], 10, spec[1])
		lbl.text = Localization.t(spec[0])
		modal._legend_items_vbox.add_child(lbl)

func rebuild_poi_directory_buttons() -> void:
	if modal._poi_list_vbox == null: return
	for child in modal._poi_list_vbox.get_children(): child.queue_free()

	var ordered_ids: Array[String] = []
	if modal._pois.has("dark_tower_beacon"): ordered_ids.append("dark_tower_beacon")
	for k in modal._pois.keys():
		if k != "dark_tower_beacon" and String(modal._pois[k].get("category", "")) == "REGION": ordered_ids.append(k)
	for k in modal._pois.keys():
		if k not in ordered_ids: ordered_ids.append(k)

	for poi_id in ordered_ids:
		var poi: Dictionary = modal._pois[poi_id]
		var vis: bool = is_poi_visible_on_map(poi_id)
		var btn := Button.new()
		btn.name = "PoiBtn_" + poi_id
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)
		if modal._mono_font != null: btn.add_theme_font_override("font", modal._mono_font)

		var prefix: String = "◈ " if poi_id == "dark_tower_beacon" else ("◯ " if String(poi.get("category", "")) == "REGION" else "■ ")
		var display_name: String = get_poi_localized_name(poi_id) if vis else Localization.t("MAP_POI_UNDISCOVERED")
		btn.text = prefix + display_name

		var text_col: Color = MapModal.KA_BEACON_CRIMSON if poi_id == "dark_tower_beacon" else (MapModal.AMBER_BRIGHT if vis else Color(0.55, 0.50, 0.42, 0.65))
		btn.add_theme_color_override("font_color", text_col)
		btn.pressed.connect(func() -> void: modal.select_poi(poi_id, true))
		modal._poi_list_vbox.add_child(btn)

func refresh_selected_poi_inspector() -> void:
	if modal._selected_poi_title_label == null: return
	if not modal._pois.has(modal._selected_poi_id): modal._selected_poi_id = "dark_tower_beacon"
	var poi: Dictionary = modal._pois.get(modal._selected_poi_id, {})
	var vis: bool = is_poi_visible_on_map(modal._selected_poi_id)
	var w_pos: Vector3 = poi.get("world_pos", Vector3.ZERO)

	modal._selected_poi_title_label.text = get_poi_localized_name(modal._selected_poi_id) if vis else Localization.t("MAP_POI_UNDISCOVERED")
	if modal._selected_poi_coords_label != null:
		var dist_to_player: int = int(round(Vector2(modal.player_world_position.x, modal.player_world_position.z).distance_to(Vector2(w_pos.x, w_pos.z))))
		modal._selected_poi_coords_label.text = "X %+04d m | Z %+04d m  (%d m)" % [int(round(w_pos.x)), int(round(w_pos.z)), dist_to_player]
	if modal._selected_poi_status_label != null:
		if modal._selected_poi_id == "dark_tower_beacon":
			modal._selected_poi_status_label.text = Localization.t("MAP_POI_STATE_ANCHORED")
		elif vis:
			modal._selected_poi_status_label.text = Localization.t("MAP_POI_STATE_DISCOVERED")
		else:
			modal._selected_poi_status_label.text = Localization.t("MAP_POI_STATE_RECON")

# ─── UI Hierarchy Construction & Styling ─────────────────────────────────────

func apply_modal_styling() -> void:
	var s := _make_box(MapModal.MODAL_BG_COLOR, MapModal.MODAL_BORDER_COLOR, Vector2(20.0, 16.0), 4, 3)
	s.border_width_top = 2; s.border_width_right = 2; s.border_width_bottom = 2
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.68); s.shadow_size = 12; s.shadow_offset = Vector2(0, 4)
	modal.add_theme_stylebox_override("panel", s)

static func _make_box(bg: Color, border: Color, pad: Vector2, radius: int = 3, w_left: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.border_width_left = w_left
	s.set_corner_radius_all(radius); s.content_margin_left = pad.x; s.content_margin_right = pad.x
	s.content_margin_top = pad.y; s.content_margin_bottom = pad.y
	return s

func build_or_resolve_ui_tree() -> void:
	var root_vbox := modal.get_node_or_null("Margin/RootVBox") as VBoxContainer
	if root_vbox != null:
		_resolve_existing_scene_nodes()
		return

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]: margin.add_theme_constant_override(side, 6)
	for side in ["margin_top", "margin_bottom"]: margin.add_theme_constant_override(side, 4)
	modal.add_child(margin)

	root_vbox = VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.add_theme_constant_override("separation", 12)
	root_vbox.add_child(header_row)

	var title_vbox := VBoxContainer.new()
	title_vbox.name = "TitleVBox"
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	header_row.add_child(title_vbox)

	modal._title_label = _create_label("ModalTitle", 16, MapModal.AMBER_BRIGHT, modal._serif_font)
	title_vbox.add_child(modal._title_label)
	modal._subtitle_label = _create_label("ModalSubtitle", 11, Color(0.78, 0.72, 0.62, 0.88), modal._mono_font)
	title_vbox.add_child(modal._subtitle_label)

	var controls_hbox := HBoxContainer.new()
	controls_hbox.name = "HeaderButtons"
	controls_hbox.add_theme_constant_override("separation", 8)
	header_row.add_child(controls_hbox)

	modal._btn_center = _add_hdr_btn(controls_hbox, "BtnCenter", "[ C / CENTER ]", modal.center_on_player)
	modal._btn_reset_zoom = _add_hdr_btn(controls_hbox, "BtnResetZoom", "[ Z / 1.0x ]", modal.reset_zoom)
	modal._btn_close = _add_hdr_btn(controls_hbox, "BtnCloseMap", "[ M / TAB / ESC ]", modal.close_map)

	var body_hbox := HBoxContainer.new()
	body_hbox.name = "BodyHBox"
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 14)
	root_vbox.add_child(body_hbox)

	modal._map_viewport_frame = PanelContainer.new()
	modal._map_viewport_frame.name = "CartographicFrame"
	modal._map_viewport_frame.custom_minimum_size = Vector2(580, 440)
	modal._map_viewport_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal._map_viewport_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal._map_viewport_frame.add_theme_stylebox_override("panel", _make_box(MapModal.CANVAS_BG_COLOR, Color(0.92, 0.72, 0.38, 0.45), Vector2(2, 2), 3, 2))
	body_hbox.add_child(modal._map_viewport_frame)

	modal._map_canvas = MapModal._MapCanvasControl.new(modal)
	modal._map_canvas.name = "CartographicCanvas"
	modal._map_canvas.custom_minimum_size = Vector2(580, 440)
	modal._map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal._map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal._map_canvas.clip_contents = true
	modal._map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	modal._map_canvas.draw.connect(modal._on_canvas_draw)
	modal._map_canvas.gui_input.connect(modal._on_canvas_gui_input)
	modal._map_canvas.mouse_exited.connect(modal._on_canvas_mouse_exited)
	modal._map_viewport_frame.add_child(modal._map_canvas)

	var sidebar_panel := PanelContainer.new()
	sidebar_panel.name = "TacticalSidebar"
	sidebar_panel.custom_minimum_size = Vector2(320, 440)
	sidebar_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_panel.add_theme_stylebox_override("panel", _make_box(Color(0.032, 0.028, 0.024, 0.92), Color(0.92, 0.72, 0.38, 0.32), Vector2(12, 10), 3, 2))
	body_hbox.add_child(sidebar_panel)

	var side_vbox := VBoxContainer.new()
	side_vbox.name = "SidebarVBox"
	side_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_theme_constant_override("separation", 8)
	sidebar_panel.add_child(side_vbox)

	modal._legend_header_label = _add_mono_lbl(side_vbox, "LegendHeader", 10, MapModal.AMBER_BRIGHT, "CARTOGRAPHIC LEGEND & TELEMETRY")
	modal._telemetry_pos_label = _add_mono_lbl(side_vbox, "TelemetryPosLabel", 11, Color(0.94, 0.84, 0.62, 0.96))
	modal._telemetry_beacon_label = _add_mono_lbl(side_vbox, "TelemetryBeaconLabel", 11, Color(1.0, 0.56, 0.34, 0.96))
	modal._telemetry_cursor_label = _add_mono_lbl(side_vbox, "TelemetryCursorLabel", 11, Color(0.76, 0.72, 0.64, 0.90))

	modal._legend_items_vbox = VBoxContainer.new()
	modal._legend_items_vbox.name = "LegendItemsVBox"
	modal._legend_items_vbox.add_theme_constant_override("separation", 3)
	side_vbox.add_child(modal._legend_items_vbox)

	var sep1 := HSeparator.new()
	sep1.modulate = Color(0.92, 0.72, 0.38, 0.35)
	side_vbox.add_child(sep1)

	modal._poi_header_label = _add_mono_lbl(side_vbox, "PoiHeader", 10, MapModal.AMBER_BRIGHT, "REGIONAL POINTS OF INTEREST")

	var poi_scroll := ScrollContainer.new()
	poi_scroll.name = "PoiScroll"
	poi_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poi_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	poi_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_vbox.add_child(poi_scroll)

	modal._poi_list_vbox = VBoxContainer.new()
	modal._poi_list_vbox.name = "PoiListVBox"
	modal._poi_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal._poi_list_vbox.add_theme_constant_override("separation", 4)
	poi_scroll.add_child(modal._poi_list_vbox)

	var sep2 := HSeparator.new()
	sep2.modulate = Color(0.92, 0.72, 0.38, 0.35)
	side_vbox.add_child(sep2)

	var inspect_box := VBoxContainer.new()
	inspect_box.name = "SelectedPoiInspector"
	inspect_box.add_theme_constant_override("separation", 2)
	side_vbox.add_child(inspect_box)

	modal._selected_poi_title_label = _add_mono_lbl(inspect_box, "SelectedPoiTitle", 12, MapModal.AMBER_BRIGHT)
	modal._selected_poi_coords_label = _add_mono_lbl(inspect_box, "SelectedPoiCoords", 11, Color(0.84, 0.78, 0.66, 0.92))
	modal._selected_poi_status_label = _add_mono_lbl(inspect_box, "SelectedPoiStatus", 11, Color(0.68, 0.84, 0.72, 0.92))

	modal._footer_hints_label = make_mono_label("FooterHintsLabel", 11, Color(0.82, 0.76, 0.64, 0.88))
	modal._footer_hints_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(modal._footer_hints_label)

func _add_hdr_btn(parent: Control, p_name: String, p_txt: String, p_target: Callable) -> Button:
	var btn := make_tactical_button(p_name, p_txt)
	btn.pressed.connect(p_target)
	parent.add_child(btn)
	return btn

func _add_mono_lbl(parent: Control, p_name: String, p_sz: int, p_col: Color, p_txt: String = "") -> Label:
	var lbl := make_mono_label(p_name, p_sz, p_col)
	if not p_txt.is_empty(): lbl.text = p_txt
	parent.add_child(lbl)
	return lbl

func _create_label(p_name: String, p_size: int, p_col: Color, p_font: Font) -> Label:
	var l := Label.new()
	l.name = p_name
	l.add_theme_font_size_override("font_size", p_size)
	l.add_theme_color_override("font_color", p_col)
	if p_font != null: l.add_theme_font_override("font", p_font)
	return l

func _resolve_existing_scene_nodes() -> void:
	modal._title_label = modal.get_node_or_null("Margin/RootVBox/HeaderRow/TitleVBox/ModalTitle") as Label
	modal._subtitle_label = modal.get_node_or_null("Margin/RootVBox/HeaderRow/TitleVBox/ModalSubtitle") as Label
	modal._btn_center = modal.get_node_or_null("Margin/RootVBox/HeaderRow/HeaderButtons/BtnCenter") as Button
	modal._btn_reset_zoom = modal.get_node_or_null("Margin/RootVBox/HeaderRow/HeaderButtons/BtnResetZoom") as Button
	modal._btn_close = modal.get_node_or_null("Margin/RootVBox/HeaderRow/HeaderButtons/BtnCloseMap") as Button
	modal._map_viewport_frame = modal.get_node_or_null("Margin/RootVBox/BodyHBox/CartographicFrame") as PanelContainer
	modal._sub_viewport_container = modal.get_node_or_null("Margin/RootVBox/BodyHBox/CartographicFrame/MapSubViewportContainer") as SubViewportContainer
	modal._sub_viewport = modal.get_node_or_null("Margin/RootVBox/BodyHBox/CartographicFrame/MapSubViewportContainer/MapSubViewport") as SubViewport
	modal._map_canvas = modal.get_node_or_null("Margin/RootVBox/BodyHBox/CartographicFrame/CartographicCanvas") as Control
	if modal._map_canvas == null:
		modal._map_canvas = modal.get_node_or_null("Margin/RootVBox/BodyHBox/CartographicFrame/MapSubViewportContainer/MapSubViewport/CartographicCanvas") as Control
	if modal._map_canvas == null and modal._map_viewport_frame != null:
		modal._map_canvas = MapModal._MapCanvasControl.new(modal)
		modal._map_canvas.name = "CartographicCanvas"
		modal._map_viewport_frame.add_child(modal._map_canvas)
	if modal._map_canvas != null:
		modal._map_canvas.custom_minimum_size = Vector2(580, 440)
		modal._map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modal._map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		modal._map_canvas.clip_contents = true
		modal._map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
		if not modal._map_canvas.draw.is_connected(modal._on_canvas_draw):
			modal._map_canvas.draw.connect(modal._on_canvas_draw)
		if not modal._map_canvas.gui_input.is_connected(modal._on_canvas_gui_input):
			modal._map_canvas.gui_input.connect(modal._on_canvas_gui_input)
		if not modal._map_canvas.mouse_exited.is_connected(modal._on_canvas_mouse_exited):
			modal._map_canvas.mouse_exited.connect(modal._on_canvas_mouse_exited)

	var sb_path := "Margin/RootVBox/BodyHBox/TacticalSidebar/SidebarVBox/"
	modal._legend_header_label = modal.get_node_or_null(sb_path + "LegendHeader") as Label
	modal._telemetry_pos_label = modal.get_node_or_null(sb_path + "TelemetryPosLabel") as Label
	modal._telemetry_beacon_label = modal.get_node_or_null(sb_path + "TelemetryBeaconLabel") as Label
	modal._telemetry_cursor_label = modal.get_node_or_null(sb_path + "TelemetryCursorLabel") as Label
	modal._legend_items_vbox = modal.get_node_or_null(sb_path + "LegendItemsVBox") as VBoxContainer
	modal._poi_header_label = modal.get_node_or_null(sb_path + "PoiHeader") as Label
	modal._poi_list_vbox = modal.get_node_or_null(sb_path + "PoiScroll/PoiListVBox") as VBoxContainer
	modal._selected_poi_title_label = modal.get_node_or_null(sb_path + "SelectedPoiInspector/SelectedPoiTitle") as Label
	modal._selected_poi_coords_label = modal.get_node_or_null(sb_path + "SelectedPoiInspector/SelectedPoiCoords") as Label
	modal._selected_poi_status_label = modal.get_node_or_null(sb_path + "SelectedPoiInspector/SelectedPoiStatus") as Label
	modal._footer_hints_label = modal.get_node_or_null("Margin/RootVBox/FooterHintsLabel") as Label

	var btns: Array = [[modal._btn_center, modal.center_on_player], [modal._btn_reset_zoom, modal.reset_zoom], [modal._btn_close, modal.close_map]]
	for b in btns:
		if b[0] != null and not b[0].pressed.is_connected(b[1]): b[0].pressed.connect(b[1])

func make_tactical_button(btn_name: String, label_text: String) -> Button:
	var btn := Button.new()
	btn.name = btn_name
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 10)
	if modal._mono_font != null: btn.add_theme_font_override("font", modal._mono_font)
	btn.add_theme_color_override("font_color", MapModal.AMBER_PRIMARY)
	btn.add_theme_color_override("font_hover_color", MapModal.AMBER_BRIGHT)
	btn.add_theme_stylebox_override("normal", _make_box(Color(0.08, 0.07, 0.05, 0.88), Color(0.92, 0.72, 0.38, 0.42), Vector2(8.0, 4.0), 2, 1))
	return btn

func make_section_label(node_name: String, text_str: String) -> Label:
	var lbl := Label.new()
	lbl.name = node_name
	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", MapModal.AMBER_BRIGHT)
	if modal._mono_font != null: lbl.add_theme_font_override("font", modal._mono_font)
	return lbl

func make_mono_label(node_name: String, font_sz: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.name = node_name
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	if modal._mono_font != null: lbl.add_theme_font_override("font", modal._mono_font)
	return lbl
