class_name VitalsAndGaugesWidget
extends RefCounted

## Top-Center Dual Vitals Bars, Sector/Weather Banner & Mid-Left Condition Stack Sub-Controller.
## Handles drawing procedural tick marks on health, stamina, and grit bars,
## dynamic crosshair ticks, formatting pristine/trauma status, hazard badges,
## condition entries, and damage feedback.

var hud: WastelandHUD

func _init(p_hud: WastelandHUD) -> void:
	hud = p_hud

# ─── Procedural Gauge & Bar Tick Drawing Aliases ─────────────────────────────
func _draw_health_bar_ticks() -> void:
	draw_health_bar_ticks()

func _draw_stamina_bar_ticks() -> void:
	draw_stamina_bar_ticks()

func _draw_grit_bar_ticks() -> void:
	draw_grit_bar_ticks()

func set_health(current: float, max_val: float) -> void:
	hud._last_health_current = maxf(0.0, current)
	hud._last_health_max = maxf(1.0, max_val)
	if hud.vitality_gauge != null:
		hud.vitality_gauge.max_value = hud._last_health_max
		hud.vitality_gauge.value = hud._last_health_current
	hud._is_low_health = (hud._last_health_current / hud._last_health_max <= 0.30)
	if hud._health_fill_style != null:
		hud._health_fill_style.bg_color = HUDThemeStyle.CRIMSON_HAZARD if hud._is_low_health else HUDThemeStyle.SANDALWOOD_AMBER
	refresh_top_center_header()
	hud._revolver_widget.update_bottom_left_panel_border()

func set_stamina(current: float, max_val: float) -> void:
	hud._last_stamina_current = maxf(0.0, current)
	hud._last_stamina_max = maxf(1.0, max_val)
	if hud.respiration_gauge != null:
		hud.respiration_gauge.max_value = hud._last_stamina_max
		hud.respiration_gauge.value = hud._last_stamina_current
	refresh_top_center_header()

func set_locomotion_state(state_name: String) -> void:
	hud._last_locomotion_state = state_name
	if hud.posture_tag != null:
		hud.posture_tag.text = Localization.translate_locomotion_state(state_name, hud.current_language)

func set_region_name(r_name: String) -> void:
	hud._last_region_name = r_name
	refresh_upper_left_banner()

func set_player_coordinates(coords: Vector3) -> void:
	hud._current_player_coords = coords
	refresh_upper_left_banner()

func set_weather_telemetry(preset_name: String, density: float) -> void:
	hud._last_weather_preset = preset_name
	hud._last_grit_density = density
	refresh_top_center_header()
	refresh_condition_stack()

func resolve_player_and_world_refs() -> void:
	if hud._player_node_ref == null or not is_instance_valid(hud._player_node_ref):
		var tree := hud.get_tree()
		if tree != null:
			var nodes := tree.get_nodes_in_group("player")
			if not nodes.is_empty():
				hud._player_node_ref = nodes[0] as Node3D
			elif hud.get_parent() != null:
				hud._player_node_ref = hud.get_parent().get_node_or_null("Player") as Node3D
	if (hud._world_manager_node_ref == null or not is_instance_valid(hud._world_manager_node_ref)) and hud.get_parent() != null:
		hud._world_manager_node_ref = hud.get_parent().get_node_or_null("WorldManager") as Node3D

func poll_and_update_coordinates() -> void:
	resolve_player_and_world_refs()
	if hud._player_node_ref != null and is_instance_valid(hud._player_node_ref):
		hud._current_player_coords = hud._player_node_ref.global_position
		refresh_upper_left_banner()
	if hud._world_manager_node_ref != null and is_instance_valid(hud._world_manager_node_ref) and "current_bubble_name" in hud._world_manager_node_ref:
		var b_name: String = String(hud._world_manager_node_ref.current_bubble_name)
		if not b_name.is_empty() and b_name != hud._last_region_name:
			set_region_name(b_name)


func draw_health_bar_ticks() -> void:
	if hud._health_ticks_overlay == null or hud.health_bar == null:
		return
	var size: Vector2 = hud._health_ticks_overlay.size
	var bar_w: float = size.x
	var bar_h: float = size.y

	for i in range(1, 4):
		var x: float = bar_w * (float(i) * 0.25)
		hud._health_ticks_overlay.draw_line(
			Vector2(x, 0.0),
			Vector2(x, bar_h),
			Color(0.04, 0.03, 0.02, 0.65),
			1.0
		)

func draw_stamina_bar_ticks() -> void:
	if hud._stamina_ticks_overlay == null or hud.stamina_bar == null:
		return
	var size: Vector2 = hud._stamina_ticks_overlay.size
	var bar_w: float = size.x
	var bar_h: float = size.y

	var tick_color := Color(0.04, 0.03, 0.02, 0.70)
	for i in range(1, 4):
		var x: float = bar_w * (float(i) * 0.25)
		var tick_h: float = bar_h * 0.75 if (i == 2) else bar_h * 0.5
		hud._stamina_ticks_overlay.draw_line(
			Vector2(x, bar_h - tick_h),
			Vector2(x, bar_h),
			tick_color,
			1.0
		)

func draw_grit_bar_ticks() -> void:
	if hud._grit_ticks_overlay == null or hud.grit_bar == null:
		return
	var size: Vector2 = hud._grit_ticks_overlay.size
	var bar_w: float = size.x
	var bar_h: float = size.y

	var marks: Array[float] = [0.50, 0.75, 0.90]
	for frac in marks:
		var x: float = bar_w * frac
		var col := Color(0.96, 0.28, 0.22, 0.85) if (frac >= 0.75) else Color(0.98, 0.82, 0.44, 0.65)
		hud._grit_ticks_overlay.draw_line(
			Vector2(x, 0.0),
			Vector2(x, bar_h),
			col,
			1.0
		)

func refresh_top_center_header() -> void:
	var is_pristine: bool = (hud._last_health_current >= hud._last_health_max)
	var health_status: String
	if is_pristine:
		health_status = hud.tr_ui("VITALITY_PRISTINE") # "ILESO"
	elif hud._last_health_current <= 30.0:
		health_status = hud.tr_ui("VITALITY_CRITICAL") # "TRAUMA CRÍTICO"
	else:
		health_status = hud.tr_ui("VITALITY_TRAUMA") # "TRAUMA LEVE"

	if hud.health_label != null:
		hud.health_label.text = "%s %d/%d" % [
			health_status,
			int(round(hud._last_health_current)),
			int(round(hud._last_health_max))
		]

	if hud.stamina_label != null:
		var stam_pct: float = (hud._last_stamina_current / maxf(1.0, hud._last_stamina_max)) * 100.0
		hud.stamina_label.text = "%d%%" % int(round(stam_pct))

	refresh_hazard_tag()
	refresh_upper_left_banner()

func refresh_hazard_tag() -> void:
	if hud.hazard_tag_label == null:
		return
	if hud._last_grit_density > 0.0:
		hud.hazard_tag_label.text = "◇  ⬡ Sílice en Suspensión: %.1f mg/m³" % hud._last_grit_density
	else:
		hud.hazard_tag_label.text = "◇  ⬡ Atmósfera Estable"

func refresh_upper_left_banner() -> void:
	var loc_region: String = Localization.translate_region_name(hud._last_region_name, hud.current_language)
	var loc_weather: String = Localization.translate_weather_preset(hud._last_weather_preset, hud.current_language)
	var clamped_x: float = clampf(hud._current_player_coords.x, -1250.0, 1250.0)
	var clamped_z: float = clampf(hud._current_player_coords.z, -1250.0, 1250.0)

	if hud.region_label != null:
		hud.region_label.text = loc_region.to_upper()
	if hud.sub_state_label != null:
		hud.sub_state_label.text = loc_weather
	if hud.coords_label != null:
		hud.coords_label.text = "X: %.1fm | Z: %.1fm" % [clamped_x, clamped_z]

func refresh_condition_stack() -> void:
	if hud.condition_vbox == null:
		return
	for child in hud.condition_vbox.get_children():
		child.queue_free()

	var conditions: Array[String] = []
	if hud._last_grit_index > 0.05:
		conditions.append("Grava: %d%%" % int(hud._last_grit_index * 100.0))
	if hud._last_fouling_index > 0.05:
		conditions.append("Hollín: %d%%" % int(hud._last_fouling_index * 100.0))
	if hud._last_grit_index > 0.30 or hud._last_fouling_index > 0.30:
		conditions.append("Roce Áspero")
	if hud._last_grit_density > 0.5:
		conditions.append("Sílice: %.1f mg/m³" % hud._last_grit_density)
	if not hud._last_weather_preset.is_empty() and hud._last_weather_preset != "CLEAR ARID":
		conditions.append(Localization.translate_weather_preset(hud._last_weather_preset, hud.current_language))

	for cond in conditions:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var bullet := Label.new()
		bullet.text = "◈"
		bullet.modulate = HUDThemeStyle.SANDALWOOD_AMBER
		bullet.add_theme_font_size_override("font_size", 10)
		var lbl := Label.new()
		lbl.text = cond
		lbl.modulate = HUDThemeStyle.BONE_WHITE
		lbl.add_theme_font_size_override("font_size", 10)
		if hud._mono_font != null:
			lbl.add_theme_font_override("font", hud._mono_font)
		row.add_child(bullet)
		row.add_child(lbl)
		hud.condition_vbox.add_child(row)

func build_dynamic_crosshair_ticks() -> void:
	if hud.crosshair == null:
		return
	for child in hud.crosshair.get_children():
		child.queue_free()
	hud._crosshair_ticks.clear()

	var dot := ColorRect.new()
	dot.name = "CenterDot"
	dot.custom_minimum_size = Vector2(2, 2)
	dot.color = Color(0.98, 0.88, 0.55, 0.85)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-1, -1)
	hud.crosshair.add_child(dot)

	for i in range(4):
		var tick := ColorRect.new()
		tick.name = "Tick_%d" % i
		tick.color = Color(0.92, 0.72, 0.38, 0.82)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.crosshair.add_child(tick)
		hud._crosshair_ticks.append(tick)

func set_crosshair_spread(is_aiming: bool, spread_factor: float) -> void:
	if hud._crosshair_ticks.size() < 4:
		return
	var base_d: float = 6.0 if is_aiming else 16.0
	var d: float = base_d + spread_factor * (12.0 if is_aiming else 28.0)
	var t_len: float = 6.0 if is_aiming else 8.0
	var t_w: float = 2.0

	hud._crosshair_ticks[0].size = Vector2(t_len, t_w)
	hud._crosshair_ticks[0].position = Vector2(-d - t_len, -t_w * 0.5)

	hud._crosshair_ticks[1].size = Vector2(t_len, t_w)
	hud._crosshair_ticks[1].position = Vector2(d, -t_w * 0.5)

	hud._crosshair_ticks[2].size = Vector2(t_w, t_len)
	hud._crosshair_ticks[2].position = Vector2(-t_w * 0.5, -d - t_len)

	hud._crosshair_ticks[3].size = Vector2(t_w, t_len)
	hud._crosshair_ticks[3].position = Vector2(-t_w * 0.5, d)

func trigger_damage_feedback(amount: float, _attacker_position: Vector3, _dir_key: String = "DIR_FRONT") -> void:
	hud._damage_flash_timer = clampf(amount * 0.02 + 0.15, 0.15, 0.45)
	hud._update_bottom_left_panel_border()

func trigger_low_health_warning() -> void:
	hud._is_low_health = true
	hud._update_bottom_left_panel_border()

func process_frame(delta: float) -> void:
	if hud._damage_flash_timer > 0.0:
		hud._damage_flash_timer = maxf(0.0, hud._damage_flash_timer - delta)
		if hud._damage_flash_timer == 0.0:
			hud._revolver_widget.update_bottom_left_panel_border()
	if hud._is_low_health or hud._low_health_pulse_timer > 0.0:
		hud._low_health_pulse_timer = hud._low_health_pulse_timer + delta if hud._is_low_health else 0.0
		hud._revolver_widget.update_bottom_left_panel_border()

func connect_siege_telemetry() -> void:
	var siege_mgr = hud.get_node_or_null("/root/WastelandSiegeManager")
	if siege_mgr != null and not siege_mgr.siege_started.is_connected(on_siege_started):
		siege_mgr.siege_started.connect(on_siege_started)

func on_siege_started(basin_id: String, total_waves: int) -> void:
	hud._is_under_siege = true
	hud._active_siege_basin = basin_id
	hud._active_siege_max_waves = total_waves
	hud.show_notification(hud.tr_ui("NOTIF_SIEGE_ALERT"), 4.0)

func update_perf_telemetry_readout(_delta: float) -> void:
	if hud.perf_telemetry_label != null and hud.perf_telemetry_label.visible:
		var fps := Engine.get_frames_per_second()
		hud.perf_telemetry_label.text = "FPS: %d | MEM: %.1f MB" % [fps, OS.get_static_memory_usage() / 1048576.0]

func toggle_perf_telemetry() -> void:
	if hud.perf_telemetry_label != null:
		hud.perf_telemetry_label.visible = not hud.perf_telemetry_label.visible

func refresh_localized_ui() -> void:
	if hud.settings_modal_title != null:
		hud.settings_modal_title.text = hud.tr_ui("SETTINGS_TITLE")
	if hud.btn_close_settings != null:
		hud.btn_close_settings.text = hud.tr_ui("SETTINGS_CLOSE")
	refresh_top_center_header()
	hud._revolver_widget.refresh_control_legend_visuals()
	hud._pause_toast_ctrl.refresh_death_screen_text()

func bootstrap_hud_defaults() -> void:
	hud.set_region_name(hud._last_region_name)
	hud.set_health(hud._last_health_current, hud._last_health_max)
	hud.set_stamina(hud._last_stamina_current, hud._last_stamina_max)
	hud.set_locomotion_state(hud._last_locomotion_state)
	hud.set_weather_telemetry(hud._last_weather_preset, hud._last_grit_density)
	hud.set_weapon_identity(hud._last_weapon_name, hud._last_weapon_caliber)
	hud.set_weapon_chamber(hud._last_chamber_state, false)
	hud.set_cylinder_count(hud._last_cylinder_loaded, hud._last_cylinder_capacity)
	hud.set_hammer_state(hud._hammer_state_str)
	hud.set_shoulder_state(hud._is_right_shoulder)
	hud.set_grit_fouling(hud._last_grit_index, hud._last_fouling_index)
	refresh_localized_ui()
	update_perf_telemetry_readout(0.016)
	connect_siege_telemetry()
