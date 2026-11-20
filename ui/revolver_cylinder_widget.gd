class_name RevolverCylinderWidget
extends RefCounted

## Revolver Cylinder & Weapon Cluster Sub-Controller.
## Manages 76x76 diamond revolver drum rotation, 6-chamber states, diegetic chamber pills,
## 4 compact action tiles ([F] Montar, [R] Cargar, [V] Desencasq., [B] Limpiar),
## 2-row structured tactical legend grid, and ammo/stance block updates.

var hud: WastelandHUD

const LEGEND_ACTIONS: Array[Dictionary] = [
	{"id": "fire", "key": "LMB", "tr_key": "HINT_FIRE"}, {"id": "aim", "key": "RMB", "tr_key": "HINT_AIM"},
	{"id": "cock", "key": "F", "tr_key": "HINT_COCK"}, {"id": "holster", "key": "H", "tr_key": "HINT_HOLSTER"},
	{"id": "load", "key": "R", "tr_key": "HINT_LOAD"}, {"id": "clear", "key": "V", "tr_key": "HINT_CLEAR"},
	{"id": "clean", "key": "B", "tr_key": "HINT_CLEAN"}, {"id": "inspect", "key": "I", "tr_key": "HINT_INSPECT"}
]

func _init(p_hud: WastelandHUD) -> void:
	hud = p_hud

# ─── Backward-Compatibility & Drawing Aliases ────────────────────────────────
func _draw_revolver_cylinder() -> void: draw_revolver_cylinder()
func _refresh_cylinder_states() -> void: refresh_cylinder_states()
func _setup_diegetic_cylinder_pills() -> void: setup_diegetic_cylinder_pills()

func _refresh_weapon_cluster(update_border: bool = false) -> void:
	refresh_action_tiles()
	refresh_ammo_and_stance_block()
	refresh_control_legend_visuals()
	if update_border:
		update_bottom_right_panel_border()

func set_weapon_identity(name_str: String, caliber: String) -> void:
	hud._last_weapon_name = name_str; hud._last_weapon_caliber = caliber
	if hud.weapon_name_label != null: hud.weapon_name_label.text = name_str
	refresh_ammo_and_stance_block()

func set_weapon_chamber(state_str: String, jammed: bool) -> void:
	hud._last_chamber_state = state_str; hud._is_jammed = jammed
	if hud.chamber_status_label != null: hud.chamber_status_label.text = Localization.translate_chamber_state(state_str, hud.current_language)
	if hud.jam_banner != null: hud.jam_banner.visible = jammed
	refresh_cylinder_states(); _refresh_weapon_cluster(true)

func set_cylinder_count(loaded: int, capacity: int) -> void:
	hud._last_cylinder_loaded = loaded; hud._last_cylinder_capacity = capacity
	if hud.cylinder_status_label != null: hud.cylinder_status_label.text = "%d / %d" % [loaded, capacity]
	refresh_cylinder_states(); _refresh_weapon_cluster(false)

func set_hammer_state(state_str: String) -> void:
	hud._hammer_state_str = state_str; _refresh_weapon_cluster(true)

func set_holster_state(holstered: bool) -> void:
	hud._is_holstered = holstered; _refresh_weapon_cluster(true)

func set_shoulder_state(is_right: bool) -> void:
	hud._is_right_shoulder = is_right; refresh_ammo_and_stance_block(); update_bottom_right_panel_border()

func set_grit_fouling(grit: float, fouling: float) -> void:
	hud._last_grit_index = grit; hud._last_fouling_index = fouling
	hud._vitals_widget.refresh_condition_stack(); _refresh_weapon_cluster(false)

static func _make_pill_style(bg: Color, border: Color, pad_h: float, pad_v: float, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border
	s.set_border_width_all(1); s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h; s.content_margin_right = pad_h; s.content_margin_top = pad_v; s.content_margin_bottom = pad_v
	return s


func draw_revolver_cylinder() -> void:
	if hud.cylinder_diamond_ctrl == null:
		return
	var ctrl := hud.cylinder_diamond_ctrl
	var size := ctrl.size
	var center := size * 0.5

	# 1. Rotated Brass-bordered Diamond Background
	var pad := 4.0
	var diamond_pts := PackedVector2Array([Vector2(center.x, pad), Vector2(size.x - pad, center.y), Vector2(center.x, size.y - pad), Vector2(pad, center.y)])
	ctrl.draw_colored_polygon(diamond_pts, HUDThemeStyle.OBSIDIAN_PANEL_BG)
	var stroke_pts := diamond_pts.duplicate()
	stroke_pts.append(stroke_pts[0])
	ctrl.draw_polyline(stroke_pts, HUDThemeStyle.TARNISHED_BRONZE, 1.2, true)

	# 2. Revolver Drum Base
	var drum_radius: float = 23.5
	ctrl.draw_circle(center, drum_radius, Color(0.10, 0.08, 0.06, 0.95))
	ctrl.draw_arc(center, drum_radius, 0.0, TAU, 32, HUDThemeStyle.TARNISHED_BRONZE_HAIRLINE, 1.2, true)

	# Cylinder outer scallop flutes
	var flute_orbit: float = 23.0
	for f in range(6):
		var flute_ang: float = (f * TAU / 6.0) + (TAU / 12.0) + hud._cylinder_current_rotation
		var flute_pos: Vector2 = center + Vector2(cos(flute_ang), sin(flute_ang)) * flute_orbit
		ctrl.draw_arc(flute_pos, 3.2, flute_ang + PI * 0.5, flute_ang + PI * 1.5, 8, Color(0.04, 0.03, 0.02, 0.8), 1.0, true)

	# 3. 6 Chambers
	var orbit_radius: float = 14.5
	var chamber_radius: float = 4.6
	for i in range(6):
		var angle: float = -PI * 0.5 + (i * TAU / 6.0) + hud._cylinder_current_rotation
		var ch_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * orbit_radius
		var state: int = hud._chamber_states[i] if i < hud._chamber_states.size() else 0

		ctrl.draw_circle(ch_pos, chamber_radius, Color(0.05, 0.04, 0.03, 1.0))
		ctrl.draw_arc(ch_pos, chamber_radius, 0.0, TAU, 16, Color(0.25, 0.20, 0.16, 0.7), 1.0, true)

		if state == 1:
			ctrl.draw_circle(ch_pos, chamber_radius - 0.8, Color(0.96, 0.78, 0.35, 1.0))
			ctrl.draw_circle(ch_pos, 2.2, Color(0.98, 0.88, 0.55, 1.0))
			ctrl.draw_circle(ch_pos, 0.8, Color(0.45, 0.35, 0.20, 1.0))
		elif state == 2:
			ctrl.draw_circle(ch_pos, chamber_radius - 0.8, Color(0.48, 0.32, 0.20, 0.95))
			ctrl.draw_circle(ch_pos, 2.0, Color(0.08, 0.06, 0.05, 1.0))
		elif state == 3:
			ctrl.draw_circle(ch_pos, chamber_radius - 0.8, Color(0.85, 0.25, 0.20, 1.0))
			ctrl.draw_circle(ch_pos, 1.8, Color(0.12, 0.04, 0.04, 1.0))

	# 4. Central Drum Axle
	ctrl.draw_circle(center, 5.0, Color(0.35, 0.28, 0.18, 1.0))
	ctrl.draw_arc(center, 5.0, 0.0, TAU, 16, HUDThemeStyle.TARNISHED_BRONZE, 1.0, true)
	ctrl.draw_circle(center, 2.0, Color(0.12, 0.09, 0.07, 1.0))

	# 5. Top Barrel Alignment Notch at 12 o'clock
	var notch_y: float = center.y - drum_radius
	ctrl.draw_colored_polygon(PackedVector2Array([Vector2(center.x - 3.0, notch_y - 4.5), Vector2(center.x + 3.0, notch_y - 4.5), Vector2(center.x, notch_y + 0.5)]), HUDThemeStyle.SANDALWOOD_AMBER)

func animate_cylinder_advance() -> void:
	hud._cylinder_target_rotation += TAU / 6.0
	if hud._chamber_states.size() == 6:
		var first: int = hud._chamber_states.pop_front()
		hud._chamber_states.push_back(first)
	if hud.cylinder_diamond_ctrl != null: hud.cylinder_diamond_ctrl.queue_redraw()
	if hud.cylinder_indicator != null: hud.cylinder_indicator.queue_redraw()
	refresh_cylinder_pills_visual()

func refresh_cylinder_states() -> void:
	var upper_chamber: String = hud._last_chamber_state.to_upper()
	var chamber_is_spent: bool = ("SPENT" in upper_chamber or "PERCUTIDO" in upper_chamber)
	var chamber_is_live: bool = ("LIVE" in upper_chamber or "VIVO" in upper_chamber)

	hud._chamber_states.resize(6)
	for i in range(6): hud._chamber_states[i] = 1 if i < hud._last_cylinder_loaded else 0
	if hud._is_jammed: hud._chamber_states[0] = 3
	elif chamber_is_spent: hud._chamber_states[0] = 2
	elif chamber_is_live and hud._last_cylinder_loaded > 0: hud._chamber_states[0] = 1

	if hud.cylinder_diamond_ctrl != null: hud.cylinder_diamond_ctrl.queue_redraw()
	if hud.cylinder_indicator != null: hud.cylinder_indicator.queue_redraw()
	refresh_cylinder_pills_visual()

func refresh_action_tiles() -> void:
	var can_cock: bool = (hud._hammer_state_str != "COCKED" and not hud._is_holstered)
	var can_load: bool = (hud._last_cylinder_loaded < hud._last_cylinder_capacity and not hud._is_holstered)
	var can_clear: bool = hud._is_jammed
	var can_clean: bool = (hud._last_grit_index > 0.15 or hud._last_fouling_index > 0.15)
	style_action_tile(hud.tile_cock, can_cock)
	style_action_tile(hud.tile_load, can_load)
	style_action_tile(hud.tile_clear, can_clear)
	style_action_tile(hud.tile_clean, can_clean)

func style_action_tile(tile: PanelContainer, is_actionable: bool) -> void:
	if tile == null: return
	var bg := Color(0.16, 0.12, 0.06, 0.85) if is_actionable else Color(0.0627, 0.051, 0.0392, 0.55)
	var border := HUDThemeStyle.SANDALWOOD_AMBER if is_actionable else Color(0.549, 0.427, 0.231, 0.35)
	var style := _make_pill_style(bg, border, 4.0, 4.0, 3)
	if is_actionable: style.border_width_bottom = 2
	tile.add_theme_stylebox_override("panel", style)
	var key_lbl := tile.get_node_or_null("VBox/KeyLabel") as Label
	var act_lbl := tile.get_node_or_null("VBox/ActionLabel") as Label
	if key_lbl != null: key_lbl.modulate = HUDThemeStyle.BRASS_BRIGHT if is_actionable else Color(0.847, 0.608, 0.251, 0.65)
	if act_lbl != null: act_lbl.modulate = HUDThemeStyle.BONE_WHITE if is_actionable else Color(0.70, 0.68, 0.65, 0.70)

func refresh_ammo_and_stance_block() -> void:
	if hud.live_round_label != null: hud.live_round_label.text = "%d" % hud._last_cylinder_loaded
	if hud.reserve_ammo_label != null: hud.reserve_ammo_label.text = "/ 36"
	if hud.caliber_label != null: hud.caliber_label.text = hud._last_weapon_caliber if not hud._last_weapon_caliber.is_empty() else ".45 COLT"
	if hud.tolerance_bar != null: hud.tolerance_bar.value = maxf(hud._last_grit_index, hud._last_fouling_index) * 100.0
	if hud.status_tag_label != null:
		var localized_hammer: String = Localization.translate_hammer_state(hud._hammer_state_str, hud.current_language)
		var shoulder_str: String = "DER ►" if hud._is_right_shoulder else "◀ IZQ"
		var holster_str: String = "[H] " + (hud.tr_ui("CARRY_DRAWN") if hud._is_holstered else hud.tr_ui("CARRY_HOLSTERED"))
		hud.status_tag_label.text = "%s | %s | %s" % [localized_hammer, shoulder_str, holster_str]

func setup_cylinder_indicator() -> void:
	if hud.cylinder_indicator == null:
		hud.cylinder_indicator = hud.get_node_or_null("Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock/AmmoRow/CylinderIndicator") as Control
	if hud.cylinder_indicator == null:
		var ammo_row := hud.get_node_or_null("Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock/AmmoRow") as HBoxContainer
		if ammo_row != null:
			hud.cylinder_indicator = Control.new()
			hud.cylinder_indicator.name = "CylinderIndicator"
			hud.cylinder_indicator.custom_minimum_size = Vector2(34, 34)
			hud.cylinder_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ammo_row.add_child(hud.cylinder_indicator)
			if hud.reserve_ammo_label != null and hud.reserve_ammo_label.get_parent() == ammo_row:
				ammo_row.move_child(hud.cylinder_indicator, hud.reserve_ammo_label.get_index() + 1)
	if hud.cylinder_indicator != null and not hud.cylinder_indicator.draw.is_connected(draw_cylinder_indicator):
		hud.cylinder_indicator.draw.connect(draw_cylinder_indicator)

func draw_cylinder_indicator() -> void:
	if hud.cylinder_indicator == null: return
	var ctrl := hud.cylinder_indicator
	var sz := ctrl.size
	var center := sz * 0.5
	var outer_r: float = minf(sz.x, sz.y) * 0.44
	if outer_r <= 4.0: return
	var amber_dim := Color(0.72, 0.52, 0.24, 0.35)
	var amber_bright := Color(0.96, 0.68, 0.24, 0.92)
	ctrl.draw_circle(center, outer_r, Color(0.08, 0.075, 0.07, 0.95))
	ctrl.draw_arc(center, outer_r, 0.0, TAU, 32, amber_dim, 1.2, true)
	ctrl.draw_circle(center, outer_r * 0.18, Color(0.18, 0.15, 0.11, 1.0))

	var base_rot: float = -PI * 0.5 + hud._cylinder_current_rotation
	for i in range(6):
		var angle: float = base_rot + float(i) * (TAU / 6.0)
		var c_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (outer_r * 0.55)
		var ch_r: float = outer_r * 0.21
		ctrl.draw_circle(c_pos, ch_r, Color(0.03, 0.03, 0.03, 1.0))
		var state: int = hud._chamber_states[i] if i < hud._chamber_states.size() else 0
		if state == 1:
			ctrl.draw_circle(c_pos, ch_r * 0.82, Color(0.96, 0.78, 0.35, 1.0))
			ctrl.draw_circle(c_pos, ch_r * 0.38, Color(0.98, 0.88, 0.55, 1.0))
			ctrl.draw_arc(c_pos, ch_r, 0.0, TAU, 16, amber_bright, 1.2, true)
		elif state == 2:
			ctrl.draw_circle(c_pos, ch_r * 0.80, Color(0.48, 0.32, 0.20, 0.95))
			ctrl.draw_circle(c_pos, ch_r * 0.35, Color(0.08, 0.06, 0.05, 1.0))
			ctrl.draw_arc(c_pos, ch_r, 0.0, TAU, 16, Color(0.48, 0.32, 0.20, 0.6), 1.0, true)
		elif state == 3:
			ctrl.draw_circle(c_pos, ch_r * 0.82, Color(0.85, 0.25, 0.20, 1.0))
			ctrl.draw_arc(c_pos, ch_r, 0.0, TAU, 16, Color(0.96, 0.28, 0.22, 1.0), 1.2, true)
		else:
			ctrl.draw_arc(c_pos, ch_r, 0.0, TAU, 16, amber_dim, 1.0, true)

	var notch_tip := Vector2(center.x, center.y - outer_r + 1.0)
	ctrl.draw_colored_polygon(PackedVector2Array([Vector2(center.x - 2.5, notch_tip.y - 3.5), Vector2(center.x + 2.5, notch_tip.y - 3.5), notch_tip]), amber_bright)

func setup_diegetic_cylinder_pills() -> void:
	var parent_box: BoxContainer = hud.get_node_or_null("Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock/AmmoRow") as BoxContainer
	if parent_box == null:
		parent_box = hud.get_node_or_null("Root/BottomLeftWeaponConsole/HBoxContainer/AmmoStanceBlock") as BoxContainer
	if parent_box == null and hud.cylinder_status_label != null:
		parent_box = hud.cylinder_status_label.get_parent() as BoxContainer
	if parent_box == null: return

	hud._cylinder_pills_hbox = parent_box.get_node_or_null("CylinderPillsRow") as HBoxContainer
	if hud._cylinder_pills_hbox == null:
		hud._cylinder_pills_hbox = HBoxContainer.new()
		hud._cylinder_pills_hbox.name = "CylinderPillsRow"
		hud._cylinder_pills_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud._cylinder_pills_hbox.add_theme_constant_override("separation", 3)
		parent_box.add_child(hud._cylinder_pills_hbox)
		if hud.caliber_label != null and parent_box == hud.caliber_label.get_parent():
			parent_box.move_child(hud._cylinder_pills_hbox, hud.caliber_label.get_index())

	rebuild_cylinder_pill_nodes(hud._last_cylinder_capacity)

func rebuild_cylinder_pill_nodes(capacity: int) -> void:
	if hud._cylinder_pills_hbox == null:
		return
	var target_cap: int = maxi(1, capacity)
	if hud._cylinder_pill_panels.size() == target_cap:
		return

	for child in hud._cylinder_pills_hbox.get_children():
		child.queue_free()
	hud._cylinder_pill_panels.clear()
	hud._cylinder_pill_labels.clear()
	hud._cylinder_pill_styles.clear()

	for i in range(target_cap):
		var pill := PanelContainer.new()
		pill.name = "ChamberPill_%d" % i
		pill.custom_minimum_size = Vector2(36, 22)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var pill_style := _make_pill_style(Color(0.14, 0.10, 0.05, 0.88), Color(0.92, 0.72, 0.38, 0.55), 4.0, 2.0, 3)
		pill.add_theme_stylebox_override("panel", pill_style)

		var lbl := Label.new()
		lbl.name = "MarkerLabel"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		if hud._mono_font != null:
			lbl.add_theme_font_override("font", hud._mono_font)
		lbl.text = "[●]"
		pill.add_child(lbl)

		hud._cylinder_pills_hbox.add_child(pill)
		hud._cylinder_pill_panels.append(pill)
		hud._cylinder_pill_labels.append(lbl)
		hud._cylinder_pill_styles.append(pill_style)

func refresh_cylinder_pills_visual() -> void:
	if hud._cylinder_pills_hbox == null:
		setup_diegetic_cylinder_pills()
	if hud._cylinder_pills_hbox == null:
		return
	rebuild_cylinder_pill_nodes(hud._last_cylinder_capacity)
	var upper_chamber: String = hud._last_chamber_state.to_upper()
	var chamber_is_spent: bool = ("SPENT" in upper_chamber or "PERCUTIDO" in upper_chamber)
	var chamber_is_live: bool = ("LIVE" in upper_chamber or "VIVO" in upper_chamber)

	for i in range(hud._cylinder_pill_panels.size()):
		var style: StyleBoxFlat = hud._cylinder_pill_styles[i]
		var lbl: Label = hud._cylinder_pill_labels[i]
		var is_loaded_slot: bool = (i < hud._last_cylinder_loaded)

		if i == 0 and hud._is_jammed:
			lbl.text = "[✕]"; lbl.modulate = Color(1.0, 0.35, 0.30, 1.0)
			style.bg_color = Color(0.24, 0.04, 0.04, 0.94); style.border_color = Color(0.98, 0.28, 0.22, 0.95); style.border_width_bottom = 2
		elif i == 0 and chamber_is_spent:
			lbl.text = "[·]"; lbl.modulate = HUDThemeStyle.SPENT_COPPER
			style.bg_color = Color(0.12, 0.08, 0.05, 0.86); style.border_color = Color(0.76, 0.48, 0.28, 0.65); style.border_width_bottom = 2
		elif is_loaded_slot:
			lbl.text = "[●]"; var is_primed_battery: bool = (i == 0 and chamber_is_live)
			lbl.modulate = HUDThemeStyle.BRASS_BRIGHT if is_primed_battery else HUDThemeStyle.AMBER_GOLD
			style.bg_color = Color(0.20, 0.14, 0.06, 0.94) if is_primed_battery else Color(0.12, 0.09, 0.04, 0.85)
			style.border_color = Color(0.98, 0.82, 0.44, 0.92) if is_primed_battery else Color(0.92, 0.72, 0.38, 0.48)
			style.border_width_bottom = 2 if is_primed_battery else 1
		else:
			lbl.text = "[·]"; lbl.modulate = HUDThemeStyle.EMPTY_SLATE
			style.bg_color = Color(0.05, 0.045, 0.04, 0.76); style.border_color = Color(0.42, 0.36, 0.28, 0.26); style.border_width_bottom = 1

func setup_structured_control_legend() -> void:
	var br_vbox := hud.get_node_or_null("Root/BottomRight/VBox") as VBoxContainer
	if br_vbox == null and hud.tactical_hints_label != null:
		br_vbox = hud.tactical_hints_label.get_parent() as VBoxContainer
	if br_vbox == null:
		return

	if hud.tactical_hints_label != null:
		hud.tactical_hints_label.visible = false

	hud._tactical_legend_grid = br_vbox.get_node_or_null("TacticalLegendGrid") as GridContainer
	if hud._tactical_legend_grid == null:
		hud._tactical_legend_grid = GridContainer.new()
		hud._tactical_legend_grid.name = "TacticalLegendGrid"
		hud._tactical_legend_grid.columns = 4
		hud._tactical_legend_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud._tactical_legend_grid.add_theme_constant_override("h_separation", 6)
		hud._tactical_legend_grid.add_theme_constant_override("v_separation", 5)
		hud._tactical_legend_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		br_vbox.add_child(hud._tactical_legend_grid)

	if hud._tactical_pill_entries.is_empty():
		for child in hud._tactical_legend_grid.get_children():
			child.queue_free()
		for spec in LEGEND_ACTIONS:
			hud._tactical_pill_entries.append(_build_hint_pill(spec))

	refresh_control_legend_visuals()

func _build_hint_pill(spec: Dictionary) -> Dictionary:
	var pill := PanelContainer.new(); pill.name = "HintPill_%s" % String(spec["id"])
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_style := _make_pill_style(Color(0.07, 0.06, 0.05, 0.88), Color(0.92, 0.72, 0.38, 0.28), 6.0, 3.0, 3)
	p_style.border_width_left = 2; pill.add_theme_stylebox_override("panel", p_style)

	var row := HBoxContainer.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_theme_constant_override("separation", 4)
	pill.add_child(row)
	var key_lbl := _make_hint_label("[%s]" % String(spec["key"]), Color(0.96, 0.78, 0.42, 0.96))
	var act_lbl := _make_hint_label(hud.tr_ui(String(spec["tr_key"])), Color(0.84, 0.80, 0.72, 0.92), true)
	row.add_child(key_lbl); row.add_child(act_lbl); hud._tactical_legend_grid.add_child(pill)
	return {"id": String(spec["id"]), "tr_key": String(spec["tr_key"]), "panel": pill, "style": p_style, "key_label": key_lbl, "action_label": act_lbl}

func _make_hint_label(text_val: String, col: Color, expand: bool = false) -> Label:
	var l := Label.new()
	l.text = text_val
	l.add_theme_font_size_override("font_size", 10)
	l.modulate = col
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
	if hud._mono_font != null:
		l.add_theme_font_override("font", hud._mono_font)
	return l

func refresh_control_legend_visuals() -> void:
	if hud._tactical_legend_grid == null:
		setup_structured_control_legend()
	for entry in hud._tactical_pill_entries:
		var act_id: String = String(entry["id"])
		var tr_key: String = String(entry["tr_key"])
		var p_style: StyleBoxFlat = entry["style"] as StyleBoxFlat
		var act_lbl: Label = entry["action_label"] as Label
		var key_lbl: Label = entry["key_label"] as Label
		if act_lbl != null:
			act_lbl.text = hud.tr_ui(tr_key)

		var highlight_col := Color(0.92, 0.72, 0.38, 0.28)
		var bg_col := Color(0.07, 0.06, 0.05, 0.88)
		var key_col := Color(0.96, 0.78, 0.42, 0.96)

		if act_id == "clear" and hud._is_jammed:
			highlight_col = Color(0.98, 0.30, 0.24, 0.92); bg_col = Color(0.22, 0.05, 0.04, 0.94); key_col = Color(1.0, 0.42, 0.34, 1.0)
		elif act_id == "cock" and not hud._is_holstered and not ("COCKED" in hud._hammer_state_str):
			highlight_col = Color(0.98, 0.80, 0.38, 0.75); bg_col = Color(0.14, 0.10, 0.05, 0.92)
		elif act_id == "load" and hud._last_cylinder_loaded < hud._last_cylinder_capacity:
			highlight_col = Color(0.92, 0.72, 0.38, 0.58)
		elif act_id == "clean" and (hud._last_grit_index > 0.30 or hud._last_fouling_index > 0.30):
			highlight_col = Color(0.96, 0.64, 0.26, 0.78); bg_col = Color(0.15, 0.09, 0.04, 0.92)
		elif act_id == "holster" and hud._is_holstered:
			highlight_col = Color(0.55, 0.78, 0.65, 0.68); bg_col = Color(0.05, 0.11, 0.08, 0.90); key_col = Color(0.68, 0.90, 0.76, 1.0)

		if p_style != null:
			p_style.border_color = highlight_col; p_style.bg_color = bg_col
		if key_lbl != null: key_lbl.modulate = key_col

func update_bottom_right_panel_border() -> void:
	if hud._bottom_right_style == null: return
	if hud._is_jammed: hud._bottom_right_style.border_color = HUDThemeStyle.PANEL_BORDER_JAMMED
	elif hud._is_holstered: hud._bottom_right_style.border_color = HUDThemeStyle.PANEL_BORDER_HOLSTERED
	elif "COCKED" in hud._hammer_state_str: hud._bottom_right_style.border_color = HUDThemeStyle.PANEL_BORDER_PRIMED
	else: hud._bottom_right_style.border_color = HUDThemeStyle.PANEL_BORDER_AMBER

	if hud.hammer_shoulder_label != null:
		var loc_h := Localization.translate_hammer_state(hud._hammer_state_str, hud.current_language)
		var holster_tag := hud.tr_ui("CARRY_HOLSTERED") if hud._is_holstered else hud.tr_ui("CARRY_DRAWN")
		var side_tag := hud.tr_ui("SHOULDER_RIGHT_ACTIVE") if hud._is_right_shoulder else hud.tr_ui("SHOULDER_LEFT_ACTIVE")
		hud.hammer_shoulder_label.text = "%s | %s" % [hud.tr_ui("HUD_HAMMER_CARRY_FMT") % [loc_h, holster_tag], hud.tr_ui("HUD_SHOULDER_FMT") % side_tag]

func update_bottom_left_panel_border() -> void:
	if hud._bottom_left_style == null: return
	if hud._damage_flash_timer > 0.0: hud._bottom_left_style.border_color = Color(0.96, 0.28, 0.22, 0.95)
	elif hud._is_low_health:
		var pulse: float = 0.5 + 0.5 * sin(hud._low_health_pulse_timer * 5.0)
		hud._bottom_left_style.border_color = HUDThemeStyle.TARNISHED_BRONZE_HAIRLINE.lerp(HUDThemeStyle.CRIMSON_HAZARD, pulse)
	else: hud._bottom_left_style.border_color = HUDThemeStyle.TARNISHED_BRONZE_HAIRLINE

func process_frame(delta: float) -> void:
	if not is_equal_approx(hud._cylinder_current_rotation, hud._cylinder_target_rotation):
		hud._cylinder_current_rotation = lerpf(hud._cylinder_current_rotation, hud._cylinder_target_rotation, delta * 18.0)
		if absf(hud._cylinder_current_rotation - hud._cylinder_target_rotation) < 0.005:
			hud._cylinder_current_rotation = hud._cylinder_target_rotation
		if hud.cylinder_diamond_ctrl != null: hud.cylinder_diamond_ctrl.queue_redraw()
		if hud.cylinder_indicator != null: hud.cylinder_indicator.queue_redraw()
