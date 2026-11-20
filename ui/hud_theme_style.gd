class_name HUDThemeStyle
extends RefCounted

## Dark-Tower Western Tactical Minimalist HUD Theme & Stylebox Factory.
## Provides Obsidian, Tarnished Bronze, Sandalwood Amber, and Bone White palettes,
## typography setup, and dynamic StyleBoxFlat styling for HUD panels and progress bars.

# ─── Dark-Tower Western Minimalist Palette Constants ──────────────────────────
const OBSIDIAN_PANEL_BG: Color = Color(0.0627, 0.051, 0.0392, 0.55) ## rgba(16, 13, 10, 0.55)
const TARNISHED_BRONZE: Color = Color(0.549, 0.427, 0.231, 1.0)     ## #8c6d3b
const TARNISHED_BRONZE_HAIRLINE: Color = Color(0.549, 0.427, 0.231, 0.65)
const BONE_WHITE: Color = Color(0.957, 0.937, 0.902, 1.0)           ## #f4efe6
const ANTIQUE_BONE_WHITE: Color = BONE_WHITE
const SANDALWOOD_AMBER: Color = Color(0.847, 0.608, 0.251, 1.0)     ## #d89b40
const CRIMSON_HAZARD: Color = Color(0.88, 0.23, 0.18, 1.0)
const CRIMSON_EMBER: Color = CRIMSON_HAZARD
const SPENT_COPPER_DARK: Color = Color(0.48, 0.32, 0.20, 0.95)
const VERDIGRIS_ACCENT: Color = Color(0.35, 0.65, 0.55, 0.85)

const PANEL_BG_COLOR: Color = OBSIDIAN_PANEL_BG
const PANEL_BORDER_AMBER: Color = TARNISHED_BRONZE_HAIRLINE
const PANEL_BORDER_PRIMED: Color = SANDALWOOD_AMBER
const PANEL_BORDER_HOLSTERED: Color = Color(0.55, 0.78, 0.65, 0.42)
const PANEL_BORDER_JAMMED: Color = CRIMSON_HAZARD
const AMBER_GOLD: Color = SANDALWOOD_AMBER
const AMBER_DIM: Color = Color(0.847, 0.608, 0.251, 0.5)
const BRASS_BRIGHT: Color = Color(0.98, 0.82, 0.44, 1.0)
const SPENT_COPPER: Color = SPENT_COPPER_DARK
const EMPTY_SLATE: Color = Color(0.52, 0.48, 0.44, 0.68)

static func create_serif_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Palatino", "Times New Roman", "Serif"])
	f.font_weight = 400
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.multichannel_signed_distance_field = false
	return f

static func create_mono_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["JetBrains Mono", "Menlo", "Monaco", "Courier New", "Monospace"])
	f.font_weight = 500
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.multichannel_signed_distance_field = false
	return f

static func create_glass_and_iron_stylebox(
	accent_side: String = "left",
	bg_col: Color = PANEL_BG_COLOR,
	border_col: Color = PANEL_BORDER_AMBER,
	pad_h: float = 16.0,
	pad_v: float = 12.0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_col
	box.border_color = border_col
	box.border_width_left = 3 if accent_side == "left" else 1
	box.border_width_right = 3 if accent_side == "right" else 1
	box.border_width_top = 2 if accent_side == "top" else 1
	box.border_width_bottom = 2 if accent_side == "bottom" else 1
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	box.content_margin_left = pad_h
	box.content_margin_right = pad_h
	box.content_margin_top = pad_v
	box.content_margin_bottom = pad_v
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	return box

static func ensure_panel_backdrop(container: Control, style: StyleBoxFlat) -> void:
	if container == null or style == null:
		return
	if container is PanelContainer:
		(container as PanelContainer).add_theme_stylebox_override("panel", style)
	else:
		container.add_theme_constant_override("margin_left", int(style.content_margin_left))
		container.add_theme_constant_override("margin_right", int(style.content_margin_right))
		container.add_theme_constant_override("margin_top", int(style.content_margin_top))
		container.add_theme_constant_override("margin_bottom", int(style.content_margin_bottom))
		var bg_panel := container.get_node_or_null("GlassIronBackdrop") as Panel
		if bg_panel == null:
			bg_panel = Panel.new()
			bg_panel.name = "GlassIronBackdrop"
			bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			container.add_child(bg_panel)
			container.move_child(bg_panel, 0)
		bg_panel.add_theme_stylebox_override("panel", style)

static func apply_hud_anchors_and_typography(hud: WastelandHUD) -> void:
	var root_ctrl := hud.get_node_or_null("Root") as Control
	if root_ctrl != null:
		root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root_ctrl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		root_ctrl.grow_vertical = Control.GROW_DIRECTION_BOTH

	if hud.vignette_overlay != null:
		hud.vignette_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud.vignette_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
		hud.vignette_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH

	if hud.crosshair != null:
		hud.crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	if hud.upper_left_banner != null:
		hud.upper_left_banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
		hud.upper_left_banner.offset_left = 20.0
		hud.upper_left_banner.offset_top = 16.0
		hud.upper_left_banner.offset_right = 420.0
		hud.upper_left_banner.offset_bottom = 75.0

	if hud.top_center_bar != null:
		hud.top_center_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
		hud.top_center_bar.offset_left = -210.0
		hud.top_center_bar.offset_top = 16.0
		hud.top_center_bar.offset_right = 210.0
		hud.top_center_bar.offset_bottom = 72.0
		hud.top_center_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH

	if hud.top_right_minimap_panel != null:
		hud.top_right_minimap_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		hud.top_right_minimap_panel.offset_left = -180.0
		hud.top_right_minimap_panel.offset_top = 12.0
		hud.top_right_minimap_panel.offset_right = -12.0
		hud.top_right_minimap_panel.offset_bottom = 180.0
		hud.top_right_minimap_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	if hud.mid_left_condition_stack != null:
		hud.mid_left_condition_stack.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		hud.mid_left_condition_stack.offset_left = 20.0
		hud.mid_left_condition_stack.offset_top = -240.0
		hud.mid_left_condition_stack.offset_right = 260.0
		hud.mid_left_condition_stack.offset_bottom = -135.0

	var bl_node: Control = hud.bottom_left_weapon_console
	if bl_node == null:
		bl_node = hud.get_node_or_null("Root/BottomLeftWeaponConsole") as Control
	if bl_node != null:
		bl_node.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		bl_node.offset_left = 20.0
		bl_node.offset_top = -125.0
		bl_node.offset_right = 460.0
		bl_node.offset_bottom = -15.0

	if hud.cylinder_diamond_ctrl != null:
		hud.cylinder_diamond_ctrl.custom_minimum_size = Vector2(76, 76)

	for tile in [hud.tile_cock, hud.tile_load, hud.tile_clear, hud.tile_clean]:
		if tile != null:
			tile.custom_minimum_size = Vector2(48, 48)

	_apply_font_hierarchy(hud)

static func _apply_font_hierarchy(hud: WastelandHUD) -> void:
	if hud.region_label != null:
		hud.region_label.add_theme_font_size_override("font_size", 14)
		if hud._serif_font != null:
			hud.region_label.add_theme_font_override("font", hud._serif_font)
		hud.region_label.modulate = TARNISHED_BRONZE

	if hud.sub_state_label != null:
		hud.sub_state_label.add_theme_font_size_override("font_size", 10)
		if hud._serif_font != null:
			hud.sub_state_label.add_theme_font_override("font", hud._serif_font)
		hud.sub_state_label.modulate = BONE_WHITE

	if hud.coords_label != null:
		hud.coords_label.add_theme_font_size_override("font_size", 9)
		if hud._mono_font != null:
			hud.coords_label.add_theme_font_override("font", hud._mono_font)
		hud.coords_label.modulate = Color(0.85, 0.70, 0.40, 0.65)

	if hud.health_label != null:
		hud.health_label.add_theme_font_size_override("font_size", 10)
		if hud._mono_font != null:
			hud.health_label.add_theme_font_override("font", hud._mono_font)
		hud.health_label.modulate = BONE_WHITE

	if hud.stamina_label != null:
		hud.stamina_label.add_theme_font_size_override("font_size", 9)
		if hud._mono_font != null:
			hud.stamina_label.add_theme_font_override("font", hud._mono_font)
		hud.stamina_label.modulate = Color(0.957, 0.937, 0.902, 0.85)

	if hud.hazard_tag_label != null:
		hud.hazard_tag_label.add_theme_font_size_override("font_size", 9)
		if hud._mono_font != null:
			hud.hazard_tag_label.add_theme_font_override("font", hud._mono_font)
		hud.hazard_tag_label.modulate = TARNISHED_BRONZE

	if hud.live_round_label != null:
		hud.live_round_label.add_theme_font_size_override("font_size", 28)
		if hud._mono_font != null:
			hud.live_round_label.add_theme_font_override("font", hud._mono_font)
		hud.live_round_label.modulate = BONE_WHITE

	if hud.reserve_ammo_label != null:
		hud.reserve_ammo_label.add_theme_font_size_override("font_size", 13)
		if hud._mono_font != null:
			hud.reserve_ammo_label.add_theme_font_override("font", hud._mono_font)
		hud.reserve_ammo_label.modulate = Color(0.70, 0.66, 0.60, 0.75)

	if hud.caliber_label != null:
		hud.caliber_label.add_theme_font_size_override("font_size", 10)
		if hud._serif_font != null:
			hud.caliber_label.add_theme_font_override("font", hud._serif_font)
		hud.caliber_label.modulate = TARNISHED_BRONZE

	if hud.status_tag_label != null:
		hud.status_tag_label.add_theme_font_size_override("font_size", 9)
		if hud._mono_font != null:
			hud.status_tag_label.add_theme_font_override("font", hud._mono_font)
		hud.status_tag_label.modulate = Color(0.85, 0.70, 0.40, 0.80)

static func style_hud_panels_and_modals(hud: WastelandHUD) -> void:
	hud._top_left_panel = hud.get_node_or_null("Root/TopLeftDebugPanel") as Control
	hud._bottom_left_panel = hud.bottom_left_weapon_console if hud.bottom_left_weapon_console != null else hud.get_node_or_null("Root/BottomLeftWeaponConsole") as Control
	hud._bottom_right_panel = hud.get_node_or_null("Root/LowerRightWeaponConsole") as Control

	hud._top_left_style = create_glass_and_iron_stylebox("left", Color(0.04, 0.035, 0.03, 0.65), Color(0.92, 0.72, 0.38, 0.25), 8.0, 4.0)
	hud._bottom_left_style = create_glass_and_iron_stylebox("left", OBSIDIAN_PANEL_BG, TARNISHED_BRONZE_HAIRLINE, 12.0, 8.0)
	hud._bottom_right_style = create_glass_and_iron_stylebox("right", PANEL_BG_COLOR, PANEL_BORDER_AMBER, 16.0, 12.0)

	ensure_panel_backdrop(hud._top_left_panel, hud._top_left_style)
	if hud._bottom_left_panel != null:
		hud._bottom_left_panel.add_theme_stylebox_override("panel", hud._bottom_left_style)
	ensure_panel_backdrop(hud._bottom_right_panel, hud._bottom_right_style)

	if hud.notification_banner != null:
		var notif_style := create_glass_and_iron_stylebox("top", Color(0.05, 0.04, 0.03, 0.90), Color(0.92, 0.72, 0.38, 0.48), 18.0, 10.0)
		hud.notification_banner.add_theme_stylebox_override("panel", notif_style)

	if hud.jam_banner != null:
		var jam_style := create_glass_and_iron_stylebox("top", Color(0.14, 0.03, 0.03, 0.92), Color(0.96, 0.28, 0.22, 0.85), 18.0, 10.0)
		hud.jam_banner.add_theme_stylebox_override("panel", jam_style)

	if hud.inspection_modal != null:
		var inspect_style := create_glass_and_iron_stylebox("left", Color(0.04, 0.035, 0.03, 0.94), Color(0.92, 0.72, 0.38, 0.52), 22.0, 18.0)
		hud.inspection_modal.add_theme_stylebox_override("panel", inspect_style)

	if hud.settings_modal != null:
		var settings_style := create_glass_and_iron_stylebox("left", Color(0.04, 0.035, 0.03, 0.94), Color(0.92, 0.72, 0.38, 0.52), 20.0, 16.0)
		hud.settings_modal.add_theme_stylebox_override("panel", settings_style)

	if hud.weapon_name_label != null:
		hud.weapon_name_label.modulate = Color(0.96, 0.84, 0.58, 1.0)

static func setup_styled_progress_bars(hud: WastelandHUD) -> void:
	if hud.health_bar != null:
		if hud.health_bar == hud.vitality_gauge:
			hud.health_bar.custom_minimum_size = Vector2(420, 6)
			var health_bg := StyleBoxFlat.new()
			health_bg.bg_color = Color(0.0627, 0.051, 0.0392, 0.65)
			health_bg.set_corner_radius_all(1)
			hud.health_bar.add_theme_stylebox_override("background", health_bg)

			hud._health_fill_style = StyleBoxFlat.new()
			hud._health_fill_style.bg_color = SANDALWOOD_AMBER
			hud._health_fill_style.set_corner_radius_all(1)
			hud.health_bar.add_theme_stylebox_override("fill", hud._health_fill_style)
		else:
			hud.health_bar.custom_minimum_size = Vector2(280, 12)
			hud.health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var health_bg := StyleBoxFlat.new()
			health_bg.bg_color = Color(0.08, 0.07, 0.06, 0.92)
			health_bg.border_color = Color(0.92, 0.72, 0.38, 0.28)
			health_bg.set_border_width_all(1)
			health_bg.set_corner_radius_all(3)
			hud.health_bar.add_theme_stylebox_override("background", health_bg)

			hud._health_fill_style = StyleBoxFlat.new()
			hud._health_fill_style.bg_color = Color(0.85, 0.72, 0.38, 0.92)
			hud._health_fill_style.border_color = Color(0.98, 0.86, 0.52, 0.75)
			hud._health_fill_style.border_width_right = 2
			hud._health_fill_style.border_width_top = 1
			hud._health_fill_style.set_corner_radius_all(2)
			hud.health_bar.add_theme_stylebox_override("fill", hud._health_fill_style)

			hud._health_ticks_overlay = hud.health_bar.get_node_or_null("TicksOverlay") as Control
			if hud._health_ticks_overlay == null:
				hud._health_ticks_overlay = Control.new()
				hud._health_ticks_overlay.name = "TicksOverlay"
				hud._health_ticks_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hud._health_ticks_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				hud.health_bar.add_child(hud._health_ticks_overlay)
			if not hud._health_ticks_overlay.draw.is_connected(hud._draw_health_bar_ticks):
				hud._health_ticks_overlay.draw.connect(hud._draw_health_bar_ticks)

	if hud.stamina_bar != null:
		if hud.stamina_bar == hud.respiration_gauge:
			hud.stamina_bar.custom_minimum_size = Vector2(420, 3)
			var stam_bg := StyleBoxFlat.new()
			stam_bg.bg_color = Color(0.0627, 0.051, 0.0392, 0.65)
			stam_bg.set_corner_radius_all(1)
			hud.stamina_bar.add_theme_stylebox_override("background", stam_bg)

			hud._stamina_fill_style = StyleBoxFlat.new()
			hud._stamina_fill_style.bg_color = BONE_WHITE
			hud._stamina_fill_style.set_corner_radius_all(1)
			hud.stamina_bar.add_theme_stylebox_override("fill", hud._stamina_fill_style)
		else:
			hud.stamina_bar.custom_minimum_size = Vector2(280, 12)
			hud.stamina_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var stam_bg := StyleBoxFlat.new()
			stam_bg.bg_color = Color(0.08, 0.07, 0.06, 0.92)
			stam_bg.border_color = Color(0.92, 0.72, 0.38, 0.28)
			stam_bg.set_border_width_all(1)
			stam_bg.set_corner_radius_all(3)
			hud.stamina_bar.add_theme_stylebox_override("background", stam_bg)

			hud._stamina_fill_style = StyleBoxFlat.new()
			hud._stamina_fill_style.bg_color = Color(0.92, 0.72, 0.38, 0.90)
			hud._stamina_fill_style.border_color = Color(1.0, 0.88, 0.58, 0.65)
			hud._stamina_fill_style.border_width_right = 2
			hud._stamina_fill_style.border_width_top = 1
			hud._stamina_fill_style.set_corner_radius_all(2)
			hud.stamina_bar.add_theme_stylebox_override("fill", hud._stamina_fill_style)

			hud._stamina_ticks_overlay = hud.stamina_bar.get_node_or_null("TicksOverlay") as Control
			if hud._stamina_ticks_overlay == null:
				hud._stamina_ticks_overlay = Control.new()
				hud._stamina_ticks_overlay.name = "TicksOverlay"
				hud._stamina_ticks_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hud._stamina_ticks_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				hud.stamina_bar.add_child(hud._stamina_ticks_overlay)
			if not hud._stamina_ticks_overlay.draw.is_connected(hud._draw_stamina_bar_ticks):
				hud._stamina_ticks_overlay.draw.connect(hud._draw_stamina_bar_ticks)

	if hud.tolerance_bar != null:
		hud.tolerance_bar.custom_minimum_size = Vector2(160, 3)
		var tol_bg := StyleBoxFlat.new()
		tol_bg.bg_color = Color(0.0627, 0.051, 0.0392, 0.65)
		tol_bg.set_corner_radius_all(1)
		hud.tolerance_bar.add_theme_stylebox_override("background", tol_bg)

		var tol_fill := StyleBoxFlat.new()
		tol_fill.bg_color = SANDALWOOD_AMBER
		tol_fill.set_corner_radius_all(1)
		hud.tolerance_bar.add_theme_stylebox_override("fill", tol_fill)

	if hud.grit_bar != null:
		hud.grit_bar.custom_minimum_size = Vector2(280, 10)
		hud.grit_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var grit_bg := StyleBoxFlat.new()
		grit_bg.bg_color = Color(0.08, 0.07, 0.06, 0.92)
		grit_bg.border_color = Color(0.92, 0.72, 0.38, 0.28)
		grit_bg.set_border_width_all(1)
		grit_bg.set_corner_radius_all(3)
		hud.grit_bar.add_theme_stylebox_override("background", grit_bg)

		hud._grit_fill_style = StyleBoxFlat.new()
		hud._grit_fill_style.bg_color = Color(0.84, 0.64, 0.32, 0.88)
		hud._grit_fill_style.border_color = Color(0.98, 0.82, 0.44, 0.70)
		hud._grit_fill_style.border_width_right = 2
		hud._grit_fill_style.border_width_top = 1
		hud._grit_fill_style.set_corner_radius_all(2)
		hud.grit_bar.add_theme_stylebox_override("fill", hud._grit_fill_style)

		hud._grit_ticks_overlay = hud.grit_bar.get_node_or_null("TicksOverlay") as Control
		if hud._grit_ticks_overlay == null:
			hud._grit_ticks_overlay = Control.new()
			hud._grit_ticks_overlay.name = "TicksOverlay"
			hud._grit_ticks_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hud._grit_ticks_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hud.grit_bar.add_child(hud._grit_ticks_overlay)
		if not hud._grit_ticks_overlay.draw.is_connected(hud._draw_grit_bar_ticks):
			hud._grit_ticks_overlay.draw.connect(hud._draw_grit_bar_ticks)

# ─── Static Backward-Compatibility & Contract Aliases ────────────────────────
static func _apply_hud_anchors_and_typography(hud: WastelandHUD) -> void:
	apply_hud_anchors_and_typography(hud)

static func _create_glass_and_iron_stylebox(
	accent_side: String = "left",
	bg_col: Color = PANEL_BG_COLOR,
	border_col: Color = PANEL_BORDER_AMBER,
	pad_h: float = 16.0,
	pad_v: float = 12.0
) -> StyleBoxFlat:
	return create_glass_and_iron_stylebox(accent_side, bg_col, border_col, pad_h, pad_v)

static func _style_hud_panels_and_modals(hud: WastelandHUD) -> void:
	style_hud_panels_and_modals(hud)

static func _setup_styled_progress_bars(hud: WastelandHUD) -> void:
	setup_styled_progress_bars(hud)


