class_name PauseAndToastController
extends RefCounted

## Pause Menu, Settings Modal, Death Overlay, Map Bridge & Notification Controller.
## Orchestrates pause/settings modal, death overlay sequence, map modal synchronization,
## and diegetic toast notifications.

var hud: WastelandHUD
var is_paused: bool = false

func _init(p_hud: WastelandHUD) -> void:
	hud = p_hud

func toggle_pause_menu() -> bool:
	is_paused = not is_paused
	if is_paused:
		show_settings_modal()
	else:
		hide_settings_modal()
	return is_paused

func show_toast_message(text: String, duration: float = 3.5) -> void:
	if hud.notification_banner == null or hud.notification_label == null:
		hud._resolve_nodes()
	if hud.notification_banner and hud.notification_label:
		hud.notification_label.text = text
		hud.notification_label.modulate = HUDThemeStyle.AMBER_GOLD
		hud.notification_banner.visible = true
		hud._notification_timer = duration

func _show_toast_message(text: String, duration: float = 3.5) -> void:
	show_toast_message(text, duration)

func handle_unhandled_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var iek := event as InputEventKey
		if iek.keycode == KEY_F3 or iek.physical_keycode == KEY_F3:
			hud.toggle_perf_telemetry()
			hud.get_viewport().set_input_as_handled()
			return true
		elif iek.keycode == KEY_F10 or iek.physical_keycode == KEY_F10:
			toggle_settings_modal()
			hud.get_viewport().set_input_as_handled()
			return true
		elif (iek.keycode == KEY_ESCAPE or iek.physical_keycode == KEY_ESCAPE) and hud.settings_modal != null and hud.settings_modal.visible:
			hide_settings_modal()
			hud.get_viewport().set_input_as_handled()
			return true
		elif event.is_action_pressed("toggle_recon_map") or event.is_action_pressed("map") or event.is_action_pressed("ui_map") or event.is_action_pressed("toggle_map") or iek.keycode == KEY_M or iek.physical_keycode == KEY_M:
			if WorldSaveData.is_editor_active(): return false
			toggle_map_modal()
			hud.get_viewport().set_input_as_handled()
			return true
	return false

func setup_death_overlay() -> void:
	if hud.death_overlay == null:
		hud.death_overlay = hud.get_node_or_null("DeathOverlay") as Control
		if hud.death_overlay == null:
			hud.death_overlay = hud.get_node_or_null("Root/DeathOverlay") as Control
	if hud.death_overlay == null:
		var root_ctrl := hud.get_node_or_null("Root") as Control
		hud.death_overlay = Control.new()
		hud.death_overlay.name = "DeathOverlay"
		hud.death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud.death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if root_ctrl != null:
			root_ctrl.add_child(hud.death_overlay)
		else:
			hud.add_child(hud.death_overlay)

	hud._death_crt_rect = hud.death_overlay.get_node_or_null("CRTScanlineRect") as ColorRect
	if hud._death_crt_rect == null:
		hud._death_crt_rect = ColorRect.new()
		hud._death_crt_rect.name = "CRTScanlineRect"
		hud._death_crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud._death_crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud._death_crt_rect.color = Color(0.04, 0.03, 0.02, 0.0)
		hud.death_overlay.add_child(hud._death_crt_rect)

	if ResourceLoader.exists("res://shaders/crt_scanline.gdshader"):
		var shader := load("res://shaders/crt_scanline.gdshader") as Shader
		if shader != null:
			hud._crt_shader_mat = ShaderMaterial.new()
			hud._crt_shader_mat.shader = shader
			hud._crt_shader_mat.set_shader_parameter("fade_to_black", 0.0)
			hud._death_crt_rect.material = hud._crt_shader_mat

	var center_box := hud.death_overlay.get_node_or_null("Center") as CenterContainer
	if center_box == null:
		center_box = CenterContainer.new()
		center_box.name = "Center"
		center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.death_overlay.add_child(center_box)

	var term_panel := center_box.get_node_or_null("TerminalPanel") as PanelContainer
	if term_panel == null:
		term_panel = PanelContainer.new()
		term_panel.name = "TerminalPanel"
		term_panel.custom_minimum_size = Vector2(560, 260)
		term_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var term_style := HUDThemeStyle.create_glass_and_iron_stylebox("left", Color(0.04, 0.025, 0.02, 0.94), HUDThemeStyle.PANEL_BORDER_JAMMED, 28.0, 20.0)
		term_panel.add_theme_stylebox_override("panel", term_style)
		center_box.add_child(term_panel)

	var vbox := term_panel.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 10)
		term_panel.add_child(vbox)

	hud.death_header_label = _ensure_label(vbox, "HeaderLabel", 12, HUDThemeStyle.TARNISHED_BRONZE, hud._mono_font)
	hud.death_title_label = _ensure_label(vbox, "TitleLabel", 22, Color(0.96, 0.28, 0.22, 1.0), hud._serif_font)
	hud.death_subtitle_label = _ensure_label(vbox, "SubtitleLabel", 13, HUDThemeStyle.BONE_WHITE, hud._serif_font)
	hud.death_epigraph_label = _ensure_label(vbox, "EpigraphLabel", 11, Color(0.72, 0.68, 0.60, 0.85), hud._serif_font)
	hud.death_respawn_label = _ensure_label(vbox, "RespawnLabel", 12, HUDThemeStyle.SANDALWOOD_AMBER, hud._mono_font)

func _ensure_label(parent: Control, name_str: String, f_size: int, color: Color, font: Font) -> Label:
	var lbl := parent.get_node_or_null(name_str) as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = name_str
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(lbl)
	lbl.add_theme_font_size_override("font_size", f_size)
	if font != null:
		lbl.add_theme_font_override("font", font)
	lbl.modulate = color
	return lbl

func show_death_screen(region_name: String, respawn_duration: float) -> void:
	hud._death_respawn_region = region_name if not region_name.is_empty() else "The Mohaine Way-Bunker"
	hud._death_respawn_total_time = maxf(1.0, respawn_duration)
	hud._death_respawn_timer = hud._death_respawn_total_time
	hud._death_fade_ratio = 0.0
	hud._is_dead_screen_active = true

	if hud.death_overlay == null:
		setup_death_overlay()
	refresh_death_screen_text()
	if hud.death_overlay != null:
		hud.death_overlay.visible = true

func hide_death_screen() -> void:
	hud._is_dead_screen_active = false
	hud._death_fade_ratio = 0.0
	if hud._crt_shader_mat != null:
		hud._crt_shader_mat.set_shader_parameter("fade_to_black", 0.0)
	if hud.death_overlay != null:
		hud.death_overlay.visible = false

func refresh_death_screen_text() -> void:
	if hud.death_header_label != null:
		hud.death_header_label.text = hud.tr_ui("DEATH_TERMINAL_HEADER")
	if hud.death_title_label != null:
		hud.death_title_label.text = hud.tr_ui("DEATH_TERMINAL_TITLE")
	if hud.death_subtitle_label != null:
		hud.death_subtitle_label.text = hud.tr_ui("DEATH_TERMINAL_SUBTITLE")
	if hud.death_epigraph_label != null:
		hud.death_epigraph_label.text = hud.tr_ui("DEATH_TERMINAL_EPIGRAPH")
	if hud.death_respawn_label != null:
		hud.death_respawn_label.text = hud.tr_ui("DEATH_TERMINAL_RESPAWN_FMT") % [
			hud._death_respawn_region,
			maxf(0.0, hud._death_respawn_timer)
		]

func setup_settings_modal() -> void:
	if hud.settings_modal == null:
		var host: Node = hud.get_node_or_null("Root/CenterModal")
		if host == null:
			host = hud.get_node_or_null("Root")
		if host == null:
			host = hud
		hud.settings_modal = PanelContainer.new()
		hud.settings_modal.name = "SettingsModal"
		hud.settings_modal.visible = false
		hud.settings_modal.custom_minimum_size = Vector2(540, 420)
		host.add_child(hud.settings_modal)

		var margin := MarginContainer.new()
		margin.name = "Margin"
		hud.settings_modal.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.name = "VBox"
		margin.add_child(vbox)

		var header_row := HBoxContainer.new()
		header_row.name = "HeaderRow"
		vbox.add_child(header_row)

		hud.settings_modal_title = Label.new()
		hud.settings_modal_title.name = "ModalTitle"
		hud.settings_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(hud.settings_modal_title)

		hud.btn_close_settings = Button.new()
		hud.btn_close_settings.name = "BtnCloseSettings"
		header_row.add_child(hud.btn_close_settings)

	if hud.btn_close_settings != null and not hud.btn_close_settings.pressed.is_connected(hide_settings_modal):
		hud.btn_close_settings.pressed.connect(hide_settings_modal)

func toggle_settings_modal() -> void:
	if hud.settings_modal == null:
		return
	if hud.settings_modal.visible:
		hide_settings_modal()
	else:
		show_settings_modal()

func show_settings_modal() -> void:
	if hud.inspection_modal != null:
		hud.inspection_modal.visible = false
		hud._is_inspecting = false
	if hud.map_modal != null and hud.map_modal.is_map_open:
		hud.map_modal.close_map()
	if hud.settings_modal != null:
		hud.settings_modal.visible = true
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_settings_modal() -> void:
	if hud.settings_modal != null:
		hud.settings_modal.visible = false
	if DisplayServer.get_name() != "headless" and (hud.map_modal == null or not hud.map_modal.is_map_open):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func setup_map_modal() -> void:
	if hud.map_modal == null:
		hud.map_modal = hud.get_node_or_null("MapModal") as MapModal
		if hud.map_modal == null:
			hud.map_modal = hud.get_node_or_null("Root/MapModal") as MapModal
		if hud.map_modal == null:
			hud.map_modal = hud.get_node_or_null("Root/CenterModal/MapModal") as MapModal
	if hud.map_modal == null:
		if hud.get("MAP_MODAL_SCENE") != null:
			var packed: PackedScene = hud.MAP_MODAL_SCENE
			hud.map_modal = packed.instantiate() as MapModal
		elif ResourceLoader.exists("res://scenes/map_modal.tscn"):
			var packed := load("res://scenes/map_modal.tscn") as PackedScene
			if packed != null: hud.map_modal = packed.instantiate() as MapModal
		if hud.map_modal == null:
			hud.map_modal = MapModal.new()
			hud.map_modal.name = "MapModal"
		hud.map_modal.visible = false
		hud.add_child(hud.map_modal)
	if hud.map_modal != null:
		hud.map_modal._hud_ref = hud
		hud.map_modal.visible = false
		_ensure_map_world_binding()
		sync_radar_with_map_modal()

func _ensure_map_world_binding() -> void:
	if hud.map_modal == null: return
	if hud.map_modal._player_ref == null:
		var p: Node3D = hud._player_node_ref
		var wm: Node = hud._world_manager_node_ref
		var ps: Node3D = null
		if hud.get_parent() != null:
			if p == null: p = hud.get_parent().get_node_or_null("Player") as Node3D
			if wm == null: wm = hud.get_parent().get_node_or_null("WorldManager")
			ps = hud.get_parent().get_node_or_null("PropScatter") as Node3D
		hud.map_modal.bind_world_context(p, wm, ps, hud)

func sync_radar_with_map_modal() -> void:
	if hud.tactical_radar == null or hud.map_modal == null:
		return
	if hud.map_modal.get("_contour_polylines") != null:
		var contours: Array = hud.map_modal._contour_polylines
		if not contours.is_empty() and hud.tactical_radar.has_method("set_contour_data"):
			hud.tactical_radar.call("set_contour_data", contours)

func toggle_chart() -> bool: return toggle_map_modal()

func toggle_map_modal() -> bool:
	if hud.map_modal == null:
		setup_map_modal()
	if hud.map_modal == null:
		return false
	_ensure_map_world_binding()
	if not hud.map_modal.is_map_open:
		if hud.inspection_modal != null and hud.inspection_modal.visible:
			hud.hide_inspection()
		if hud.settings_modal != null and hud.settings_modal.visible:
			hide_settings_modal()
	return hud.map_modal.toggle_map()

func show_map_modal() -> void:
	if hud.map_modal == null:
		setup_map_modal()
	if hud.map_modal != null:
		_ensure_map_world_binding()
		if hud.inspection_modal != null and hud.inspection_modal.visible:
			hud.hide_inspection()
		if hud.settings_modal != null and hud.settings_modal.visible:
			hide_settings_modal()
		hud.map_modal.open_map()

func hide_map_modal() -> void:
	if hud.map_modal != null:
		hud.map_modal.close_map()

func update_map_player_telemetry(world_pos: Vector3, facing_yaw_rad: float) -> void:
	hud._current_player_coords = world_pos
	if hud.map_modal != null:
		hud.map_modal.update_player_telemetry(world_pos, facing_yaw_rad)
	if hud.tactical_radar != null and hud.tactical_radar.has_method("update_player_transform"):
		hud.tactical_radar.call("update_player_transform", world_pos, facing_yaw_rad)

func resolve_nodes() -> void:
	hud._resolve_player_and_world_refs()
	hud.upper_left_banner = _find(["Root/UpperLeftBanner"], hud.upper_left_banner)
	hud.top_left_panel = _find(["Root/TopLeftDebugPanel"], hud.top_left_panel)
	hud.top_center_bar = _find(["Root/TopCenterInstrumentBar"], hud.top_center_bar)
	hud.top_right_minimap_panel = _find(["Root/TopRightMinimapPanel"], hud.top_right_minimap_panel)
	hud.tactical_radar = _find(["Root/TopRightMinimapPanel/TacticalRadar2D"], hud.tactical_radar)
	hud.debug_text = _find(["Root/TopLeftDebugPanel/DebugText"], hud.debug_text)

	hud.region_header = _find(["Root/TopCenterInstrumentBar/VBoxContainer/RegionHeader"], hud.region_header)
	hud.region_label = _find(["Root/UpperLeftBanner/HBoxContainer/BannerVBox/HeaderStrip/RegionLabel", "Root/TopLeft/VBox/RegionLabel"], hud.region_label)
	if hud.region_label == null:
		hud.region_label = hud.region_header
	hud.sub_state_label = _find(["Root/UpperLeftBanner/HBoxContainer/BannerVBox/SubStateRow/SubStateLabel"], hud.sub_state_label)
	hud.coords_label = _find(["Root/UpperLeftBanner/HBoxContainer/BannerVBox/SubStateRow/CoordsLabel"], hud.coords_label)
	hud.weather_label = _find(["Root/TopLeft/VBox/WeatherLabel"], hud.weather_label)
	hud.dust_density_label = _find(["Root/TopLeft/VBox/DustDensityLabel"], hud.dust_density_label)
	hud.perf_telemetry_label = _find(["Root/TopLeft/VBox/PerfTelemetryLabel"], hud.perf_telemetry_label)
	if hud.perf_telemetry_label == null:
		hud.perf_telemetry_label = hud.debug_text

	hud.health_bar = _find(["Root/TopCenterInstrumentBar/VBoxContainer/VitalityGauge", "Root/TopCenterInstrumentBar/VBoxContainer/VitalsRow/VitalityVBox/VitalityGauge", "Root/BottomLeft/VBox/HealthBar"], hud.health_bar)
	hud.vitality_gauge = hud.health_bar
	hud.health_label = _find(["Root/TopCenterInstrumentBar/VBoxContainer/VitalsHeaderRow/VitalityLabel", "Root/TopCenterInstrumentBar/VBoxContainer/VitalsRow/VitalityVBox/VitalityLabel", "Root/BottomLeft/VBox/HealthLabel"], hud.health_label)
	hud.stamina_bar = _find(["Root/TopCenterInstrumentBar/VBoxContainer/RespirationGauge", "Root/TopCenterInstrumentBar/VBoxContainer/VitalsRow/RespirationVBox/RespirationGauge", "Root/BottomLeft/VBox/StaminaBar"], hud.stamina_bar)
	hud.respiration_gauge = hud.stamina_bar
	hud.stamina_label = _find(["Root/TopCenterInstrumentBar/VBoxContainer/VitalsHeaderRow/RespirationLabel", "Root/TopCenterInstrumentBar/VBoxContainer/VitalsRow/RespirationVBox/RespirationLabel", "Root/BottomLeft/VBox/StaminaLabel"], hud.stamina_label)
	hud.hazard_tag_label = _find(["Root/TopCenterInstrumentBar/VBoxContainer/HazardTagLabel"], hud.hazard_tag_label)
	hud.locomotion_label = _find(["Root/TopCenterInstrumentBar/VBoxContainer/PostureTag", "Root/BottomLeft/VBox/LocomotionLabel"], hud.locomotion_label)
	hud.posture_tag = hud.locomotion_label

	hud.mid_left_condition_stack = _find(["Root/MidLeftConditionStack"], hud.mid_left_condition_stack)
	hud.condition_vbox = _find(["Root/MidLeftConditionStack/ConditionVBox"], hud.condition_vbox)

	hud.bottom_left_weapon_console = _find(["Root/BottomLeftWeaponConsole"], hud.bottom_left_weapon_console)
	hud.cylinder_diamond_ctrl = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/CylinderDiamondControl"], hud.cylinder_diamond_ctrl)
	if hud.cylinder_diamond_ctrl != null and not hud.cylinder_diamond_ctrl.draw.is_connected(hud._draw_revolver_cylinder):
		hud.cylinder_diamond_ctrl.draw.connect(hud._draw_revolver_cylinder)

	hud.cylinder_indicator = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock/AmmoRow/CylinderIndicator", "Root/BottomLeftWeaponConsole/HBoxContainer/CylinderIndicator"], hud.cylinder_indicator)
	if hud.cylinder_indicator != null and not hud.cylinder_indicator.draw.is_connected(hud._draw_cylinder_indicator):
		hud.cylinder_indicator.draw.connect(hud._draw_cylinder_indicator)

	hud.tile_cock = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/ActionTilesRow/TileCock"], hud.tile_cock)
	hud.tile_load = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/ActionTilesRow/TileLoad"], hud.tile_load)
	hud.tile_clear = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/ActionTilesRow/TileClear"], hud.tile_clear)
	hud.tile_clean = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/ActionTilesRow/TileClean"], hud.tile_clean)

	hud.live_round_label = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock/AmmoRow/LiveRoundCount"], hud.live_round_label)
	hud.reserve_ammo_label = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock/AmmoRow/ReserveAmmoCount"], hud.reserve_ammo_label)
	hud.caliber_label = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock/AmmoRow/CaliberLabel"], hud.caliber_label)
	hud.tolerance_bar = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock/ToleranceBar"], hud.tolerance_bar)
	hud.status_tag_label = _find(["Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock/StatusTag"], hud.status_tag_label)

	hud.weapon_console_vbox = _find(["Root/LowerRightWeaponConsole/VBoxContainer"], hud.weapon_console_vbox)
	hud.weapon_name_label = _find(["Root/LowerRightWeaponConsole/VBoxContainer/WeaponNameLabel", "Root/BottomRight/VBox/WeaponNameLabel"], hud.weapon_name_label)
	hud.chamber_status_label = _find(["Root/LowerRightWeaponConsole/VBoxContainer/ChamberStatusLabel", "Root/BottomRight/VBox/ChamberStatusLabel"], hud.chamber_status_label)
	hud.cylinder_status_label = _find(["Root/LowerRightWeaponConsole/VBoxContainer/CylinderStatusLabel", "Root/BottomRight/VBox/CylinderStatusLabel"], hud.cylinder_status_label)
	hud.hammer_shoulder_label = _find(["Root/LowerRightWeaponConsole/VBoxContainer/HammerShoulderLabel"], hud.hammer_shoulder_label)
	hud.hammer_status_label = hud.hammer_shoulder_label if hud.hammer_shoulder_label != null else _find(["Root/BottomRight/VBox/HammerStatusLabel"], hud.hammer_status_label)
	hud.shoulder_status_label = hud.hammer_shoulder_label if hud.hammer_shoulder_label != null else _find(["Root/BottomRight/VBox/ShoulderStatusLabel"], hud.shoulder_status_label)
	hud.grit_bar = hud.tolerance_bar if hud.tolerance_bar != null else _find(["Root/LowerRightWeaponConsole/VBoxContainer/GritBar"], hud.grit_bar)
	hud.grit_label = hud.status_tag_label if hud.status_tag_label != null else _find(["Root/LowerRightWeaponConsole/VBoxContainer/GritLabel"], hud.grit_label)

	hud.jam_banner = _find(["Root/CenterNotifications/JamBanner"], hud.jam_banner)
	hud.jam_banner_label = _find(["Root/CenterNotifications/JamBanner/Label"], hud.jam_banner_label)
	hud.tactical_hints_label = _find(["Root/LowerRightWeaponConsole/VBoxContainer/TacticalHintsLabel", "Root/BottomRight/VBox/TacticalHintsLabel"], hud.tactical_hints_label)
	hud.notification_banner = _find(["Root/CenterNotifications/NotificationBanner"], hud.notification_banner)
	hud.notification_label = _find(["Root/CenterNotifications/NotificationBanner/Label"], hud.notification_label)
	hud.siege_telemetry_label = _find(["Root/CenterNotifications/SiegeTelemetryLabel"], hud.siege_telemetry_label)

	hud.crosshair = _find(["Root/Crosshair"], hud.crosshair)
	hud.vignette_overlay = _find(["Root/VignetteOverlay"], hud.vignette_overlay)
	hud.inspection_modal = _find(["Root/CenterModal/InspectionModal"], hud.inspection_modal)
	hud.inspection_title_label = _find(["Root/CenterModal/InspectionModal/Margin/VBox/TitleLabel"], hud.inspection_title_label)
	hud.inspection_body_label = _find(["Root/CenterModal/InspectionModal/Margin/VBox/BodyLabel"], hud.inspection_body_label)

func _find(paths: Array, current_val: Object) -> Object:
	if current_val != null:
		return current_val
	for p in paths:
		var n: Object = hud.get_node_or_null(p)
		if n != null:
			return n
	return null

func process_frame(delta: float) -> void:
	if hud.notification_banner and hud.notification_banner.visible:
		hud._notification_timer -= delta
		if hud._notification_timer <= 0.0:
			hud.notification_banner.visible = false
	if hud._is_dead_screen_active:
		hud._death_respawn_timer -= delta
		hud._death_fade_ratio = clampf(1.0 - (hud._death_respawn_timer / hud._death_respawn_total_time), 0.0, 1.0)
		if hud._crt_shader_mat != null:
			hud._crt_shader_mat.set_shader_parameter("fade_to_black", hud._death_fade_ratio)
		if hud.death_respawn_label != null:
			hud.death_respawn_label.text = hud.tr_ui("DEATH_TERMINAL_RESPAWN_FMT") % [hud._death_respawn_region, maxf(0.0, hud._death_respawn_timer)]

# ─── Mode Swapping Orchestration (Modo Arquitecto Isolation) ─────────────────

func set_editor_mode_ui_state(active: bool) -> void:
	set_survival_hud_visible(not active)
	_sync_editor_hud_overlay_visibility(active)

func set_survival_hud_visible(p_visible: bool) -> void:
	if hud.top_center_bar != null: hud.top_center_bar.visible = p_visible
	if hud.bottom_left_weapon_console != null: hud.bottom_left_weapon_console.visible = p_visible
	if hud.crosshair != null: hud.crosshair.visible = p_visible
	if hud.upper_left_banner != null: hud.upper_left_banner.visible = p_visible
	if hud.mid_left_condition_stack != null: hud.mid_left_condition_stack.visible = p_visible
	if hud.tactical_radar != null: hud.tactical_radar.visible = p_visible
	if hud.top_right_minimap_panel != null: hud.top_right_minimap_panel.visible = p_visible
	if hud.jam_banner != null and not p_visible: hud.jam_banner.visible = false
	if not p_visible and hud.inspection_modal != null: hud.inspection_modal.visible = false

func _sync_editor_hud_overlay_visibility(active: bool) -> void:
	if hud == null or not hud.is_inside_tree() or hud.get_tree() == null or hud.get_tree().current_scene == null:
		return
	var scene_root: Node = hud.get_tree().current_scene
	var overlay := scene_root.find_child("EditorHUDOverlay", true, false) as CanvasLayer
	if overlay == null and active and scene_root.has_method("ensure_editor_suite") and scene_root.is_node_ready():
		# Overlay missing on toggle: ask World to (re)build the editor suite rather than staying bare.
		scene_root.call("ensure_editor_suite")
		overlay = scene_root.find_child("EditorHUDOverlay", true, false) as CanvasLayer
	if overlay != null: overlay.visible = active
