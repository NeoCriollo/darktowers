class_name WastelandHUD
extends CanvasLayer

## Diegetic Tactical Survival RPG HUD — Façade Coordinator ("Dark Towers: The Path of Ka")
## Delegates domain logic to focused sub-controllers:
##   • HUDThemeStyle: Color palettes, typography, and procedural StyleBoxFlat frames.
##   • RevolverCylinderWidget: 76x76 rotating diamond drum, 4 action tiles, 6-chamber pills.
##   • VitalsAndGaugesWidget: Top-Center dual bars, hazard badge, region banner, condition stack.
##   • InventoryAndJournalModal: Tactile item grid, saddlebags, and inspection views.
##   • PauseAndToastController: Pause/settings modal, death overlay, map bridge, and toasts.

signal language_changed(new_language: String)

const MAP_MODAL_SCENE: PackedScene = preload("res://scenes/map_modal.tscn")
const SAVE_FILE_PATH: String = "user://path_of_ka_save.cfg"
const TRANSLATIONS: Dictionary = Localization.TRANSLATIONS

# --- PALETTE CONSTANTS (Dark-Tower Western Tactical Minimalist Aesthetic) ---
const OBSIDIAN_PANEL_BG: Color = HUDThemeStyle.OBSIDIAN_PANEL_BG; const TARNISHED_BRONZE: Color = HUDThemeStyle.TARNISHED_BRONZE
const TARNISHED_BRONZE_HAIRLINE: Color = HUDThemeStyle.TARNISHED_BRONZE_HAIRLINE; const BONE_WHITE: Color = HUDThemeStyle.BONE_WHITE
const ANTIQUE_BONE_WHITE: Color = HUDThemeStyle.ANTIQUE_BONE_WHITE; const SANDALWOOD_AMBER: Color = HUDThemeStyle.SANDALWOOD_AMBER
const CRIMSON_HAZARD: Color = HUDThemeStyle.CRIMSON_HAZARD; const CRIMSON_EMBER: Color = HUDThemeStyle.CRIMSON_EMBER
const SPENT_COPPER_DARK: Color = HUDThemeStyle.SPENT_COPPER_DARK; const VERDIGRIS_ACCENT: Color = HUDThemeStyle.VERDIGRIS_ACCENT
const PANEL_BG_COLOR: Color = OBSIDIAN_PANEL_BG; const PANEL_BORDER_AMBER: Color = TARNISHED_BRONZE_HAIRLINE
const PANEL_BORDER_PRIMED: Color = SANDALWOOD_AMBER; const PANEL_BORDER_HOLSTERED: Color = HUDThemeStyle.PANEL_BORDER_HOLSTERED
const PANEL_BORDER_JAMMED: Color = CRIMSON_HAZARD; const AMBER_GOLD: Color = SANDALWOOD_AMBER
const AMBER_DIM: Color = HUDThemeStyle.AMBER_DIM; const BRASS_BRIGHT: Color = HUDThemeStyle.BRASS_BRIGHT
const SPENT_COPPER: Color = SPENT_COPPER_DARK; const EMPTY_SLATE: Color = HUDThemeStyle.EMPTY_SLATE

# --- NODE REFERENCES ---
@export var health_bar: ProgressBar
@export var health_label: Label
@export var stamina_bar: ProgressBar
@export var stamina_label: Label
@export var locomotion_label: Label
@onready var vitality_gauge: ProgressBar = health_bar; @onready var respiration_gauge: ProgressBar = stamina_bar; @onready var posture_tag: Label = locomotion_label

@export var upper_left_banner: MarginContainer
@export var sub_state_label: Label
@export var coords_label: Label
@export var hazard_tag_label: Label
@export var mid_left_condition_stack: MarginContainer
@export var condition_vbox: VBoxContainer
@export var bottom_left_weapon_console: PanelContainer
@export var cylinder_diamond_ctrl: Control
@export var cylinder_indicator: Control
@export var live_round_label: Label
@export var reserve_ammo_label: Label
@export var caliber_label: Label
@export var tolerance_bar: ProgressBar
@export var status_tag_label: Label

@export var tile_cock: PanelContainer
@export var tile_load: PanelContainer
@export var tile_clear: PanelContainer
@export var tile_clean: PanelContainer

@export var death_overlay: Control
@export var death_header_label: Label
@export var death_title_label: Label
@export var death_subtitle_label: Label
@export var death_respawn_label: Label
@export var death_epigraph_label: Label

@export var weapon_name_label: Label
@export var chamber_status_label: Label
@export var cylinder_status_label: Label
@export var hammer_status_label: Label
@export var shoulder_status_label: Label
@export var hammer_shoulder_label: Label
@export var grit_bar: ProgressBar
@export var grit_label: Label
@export var jam_banner: Control
@export var jam_banner_label: Label
@export var tactical_hints_label: Label
@export var tactical_legend_grid: GridContainer

@export var region_header: Label
@export var region_label: Label
@export var weather_label: Label
@export var dust_density_label: Label
@export var debug_text: Label
@export var perf_telemetry_label: Label
@export var siege_telemetry_label: Label
@export var notification_banner: Control
@export var notification_label: Label

@export var top_left_panel: Control
@export var top_center_bar: Control
@export var top_right_minimap_panel: Control
@export var tactical_radar: Control
@export var weapon_console_vbox: VBoxContainer

@export var crosshair: Control
@export var vignette_overlay: ColorRect
@export var inspection_modal: PanelContainer
@export var inspection_title_label: Label
@export var inspection_body_label: Label
@export var settings_modal: PanelContainer
@export var settings_modal_title: Label
@export var language_row: HBoxContainer
@export var language_label: Label
@export var language_option: OptionButton
@export var language_cycle_button: Button
@export var master_vol_label: Label
@export var master_vol_slider: HSlider
@export var master_vol_value: Label
@export var wind_vol_label: Label
@export var wind_vol_slider: HSlider
@export var wind_vol_value: Label
@export var taa_check: CheckButton
@export var fog_check: CheckButton
@export var controls_header_label: Label
@export var controls_body_label: Label
@export var btn_close_settings: Button
@export var map_modal: MapModal

# --- RUNTIME STATE ---
var current_language: String = Localization.DEFAULT_LANGUAGE
var _updating_language_controls: bool = false
var _notification_timer: float = 0.0
var _is_inspecting: bool = false
var _jammed_blink_timer: float = 0.0
var _is_jammed: bool = false
var _is_holstered: bool = false
var _is_right_shoulder: bool = true
var _hammer_state_str: String = "COCKED"
var _crosshair_ticks: Array[ColorRect] = []
var _serif_font: SystemFont = null
var _mono_font: SystemFont = null

var _cylinder_current_rotation: float = 0.0
var _cylinder_target_rotation: float = 0.0
var _chamber_states: Array[int] = [1, 1, 1, 1, 1, 1]

var _top_left_panel: Control = null
var _bottom_left_panel: Control = null
var _bottom_right_panel: Control = null
var _bottom_left_style: StyleBoxFlat = null
var _bottom_right_style: StyleBoxFlat = null
var _top_left_style: StyleBoxFlat = null
var _health_fill_style: StyleBoxFlat = null
var _stamina_fill_style: StyleBoxFlat = null
var _grit_fill_style: StyleBoxFlat = null
var _health_ticks_overlay: Control = null
var _stamina_ticks_overlay: Control = null
var _grit_ticks_overlay: Control = null

var _last_health_current: float = 100.0
var _last_health_max: float = 100.0
var _is_low_health: bool = false
var _damage_flash_timer: float = 0.0
var _low_health_pulse_timer: float = 0.0
var _is_dead_screen_active: bool = false
var _death_fade_ratio: float = 0.0
var _death_respawn_region: String = "The Mohaine Way-Bunker"
var _death_respawn_total_time: float = 6.0
var _death_respawn_timer: float = 0.0
var _crt_shader_mat: ShaderMaterial = null
var _death_crt_rect: ColorRect = null

var _cylinder_pills_hbox: HBoxContainer = null
var _cylinder_pill_panels: Array[PanelContainer] = []
var _cylinder_pill_labels: Array[Label] = []
var _cylinder_pill_styles: Array[StyleBoxFlat] = []

var _tactical_legend_grid: GridContainer = null
var _tactical_pill_entries: Array[Dictionary] = []

var _last_region_name: String = "THE MOHAINE WAY-BUNKER"
var _last_stamina_current: float = 100.0
var _last_stamina_max: float = 100.0
var _last_locomotion_state: String = "IDLE"
var _last_weather_preset: String = "CLEAR ARID"
var _last_grit_density: float = 4.0
var _last_weapon_name: String = "Sandalwood-Grip Frontier Revolver"
var _last_weapon_caliber: String = ".45 LC"
var _last_chamber_state: String = "CHAMBERED LIVE"
var _last_cylinder_loaded: int = 6
var _last_cylinder_capacity: int = 6
var _last_grit_index: float = 0.0
var _last_fouling_index: float = 0.0
var _last_rendered_grit_pct: int = -1
var _last_rendered_foul_pct: int = -1
var _last_rendered_lang: String = ""
var _last_inspection_data: Dictionary = {}
var _perf_sample_timer: float = 0.0
const PERF_UPDATE_INTERVAL: float = 0.25

var _is_under_siege: bool = false
var _active_siege_basin: String = ""
var _active_siege_max_waves: int = 5
var _current_siege_wave: int = 0
var _current_siege_enemies: int = 0

const COORD_UPDATE_INTERVAL: float = 0.1
var _coord_update_timer: float = 0.0
var _current_player_coords: Vector3 = Vector3(-1020.0, 0.0, -820.0)
var _player_node_ref: Node3D = null
var _world_manager_node_ref: Node3D = null

const LEGEND_ACTIONS: Array[Dictionary] = RevolverCylinderWidget.LEGEND_ACTIONS

# --- DECOUPLED SUB-CONTROLLERS ---
var _revolver_widget: RevolverCylinderWidget
var _vitals_widget: VitalsAndGaugesWidget
var _inventory_modal: InventoryAndJournalModal
var _pause_toast_ctrl: PauseAndToastController

func _init() -> void:
	_ensure_subcontrollers()

func _ensure_subcontrollers() -> void:
	if _revolver_widget == null: _revolver_widget = RevolverCylinderWidget.new(self)
	if _vitals_widget == null: _vitals_widget = VitalsAndGaugesWidget.new(self)
	if _inventory_modal == null: _inventory_modal = InventoryAndJournalModal.new(self)
	if _pause_toast_ctrl == null: _pause_toast_ctrl = PauseAndToastController.new(self)

func _ready() -> void:
	_ensure_subcontrollers()
	_serif_font = HUDThemeStyle.create_serif_font()
	_mono_font = HUDThemeStyle.create_mono_font()

	Localization.register_listener(_on_external_language_changed)
	current_language = Localization.load_language_preference(SAVE_FILE_PATH)

	_resolve_nodes()
	_pause_toast_ctrl.setup_settings_modal()
	_pause_toast_ctrl.setup_death_overlay()
	_configure_window_and_hud_layout()
	HUDThemeStyle.style_hud_panels_and_modals(self)
	HUDThemeStyle.setup_styled_progress_bars(self)
	_revolver_widget.setup_cylinder_indicator()
	_revolver_widget.setup_diegetic_cylinder_pills()
	_revolver_widget.setup_structured_control_legend()
	_vitals_widget.build_dynamic_crosshair_ticks()

	for node in [jam_banner, notification_banner, inspection_modal, settings_modal, death_overlay]:
		if node != null:
			node.visible = false
	_pause_toast_ctrl.setup_map_modal()
	_enforce_hud_mouse_filters(get_node_or_null("Root"))

	set_region_name(_last_region_name)
	set_health(_last_health_current, _last_health_max)
	set_stamina(_last_stamina_current, _last_stamina_max)
	set_locomotion_state(_last_locomotion_state)
	set_weather_telemetry(_last_weather_preset, _last_grit_density)
	set_weapon_identity(_last_weapon_name, _last_weapon_caliber)
	set_weapon_chamber(_last_chamber_state, false)
	set_cylinder_count(_last_cylinder_loaded, _last_cylinder_capacity)
	set_hammer_state(_hammer_state_str)
	set_shoulder_state(_is_right_shoulder)
	set_grit_fouling(_last_grit_index, _last_fouling_index)
	_refresh_localized_ui()
	_update_perf_telemetry_readout(0.016)
	_connect_siege_telemetry()
	if WorldSaveData != null and not WorldSaveData.editor_mode_toggled.is_connected(_on_editor_mode_toggled):
		WorldSaveData.editor_mode_toggled.connect(_on_editor_mode_toggled)
	_on_editor_mode_toggled(WorldSaveData.is_editor_active())

func _exit_tree() -> void:
	Localization.unregister_listener(_on_external_language_changed)
	if WorldSaveData != null and WorldSaveData.editor_mode_toggled.is_connected(_on_editor_mode_toggled):
		WorldSaveData.editor_mode_toggled.disconnect(_on_editor_mode_toggled)

func _on_editor_mode_toggled(active: bool) -> void:
	if _pause_toast_ctrl != null: _pause_toast_ctrl.set_editor_mode_ui_state(active)

func set_survival_hud_visible(p_visible: bool) -> void:
	if _pause_toast_ctrl != null: _pause_toast_ctrl.set_survival_hud_visible(p_visible)

func _unhandled_input(event: InputEvent) -> void:
	if WorldSaveData.is_editor_active(): return
	if _pause_toast_ctrl.handle_unhandled_input(event):
		return
	if _inventory_modal.handle_inventory_input(event):
		return

func _configure_window_and_hud_layout() -> void:
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)
	HUDThemeStyle.apply_hud_anchors_and_typography(self)

func _on_viewport_size_changed() -> void:
	HUDThemeStyle.apply_hud_anchors_and_typography(self)

func _process(delta: float) -> void:
	_pause_toast_ctrl.process_frame(delta)
	_vitals_widget.process_frame(delta)
	_revolver_widget.process_frame(delta)
	if _is_jammed and jam_banner:
		_jammed_blink_timer += delta * 4.0
		jam_banner.modulate = Color(1.0, 0.3, 0.3, 0.65 + 0.35 * sin(_jammed_blink_timer))
	if perf_telemetry_label != null and perf_telemetry_label.visible:
		_perf_sample_timer += delta
		if _perf_sample_timer >= PERF_UPDATE_INTERVAL:
			_perf_sample_timer = 0.0
			_update_perf_telemetry_readout(delta)
	_coord_update_timer += delta
	if _coord_update_timer >= COORD_UPDATE_INTERVAL:
		_coord_update_timer = 0.0
		_poll_and_update_coordinates()

func _resolve_nodes() -> void:
	if _pause_toast_ctrl != null: _pause_toast_ctrl.resolve_nodes()

func _resolve_player_and_world_refs() -> void:
	if _vitals_widget != null: _vitals_widget.resolve_player_and_world_refs()

func _poll_and_update_coordinates() -> void:
	if _vitals_widget != null: _vitals_widget.poll_and_update_coordinates()

# --- BACKWARD-COMPATIBLE PUBLIC FAÇADE API ---
func set_health(current: float, max_val: float) -> void: if _vitals_widget != null: _vitals_widget.set_health(current, max_val)
func set_stamina(current: float, max_val: float) -> void: if _vitals_widget != null: _vitals_widget.set_stamina(current, max_val)
func set_locomotion_state(state_name: String) -> void: if _vitals_widget != null: _vitals_widget.set_locomotion_state(state_name)
func set_weapon_identity(name_str: String, caliber: String) -> void: if _revolver_widget != null: _revolver_widget.set_weapon_identity(name_str, caliber)
func set_weapon_chamber(state_str: String, jammed: bool) -> void: if _revolver_widget != null: _revolver_widget.set_weapon_chamber(state_str, jammed)
func set_cylinder_count(loaded: int, capacity: int) -> void: if _revolver_widget != null: _revolver_widget.set_cylinder_count(loaded, capacity)
func set_hammer_state(state_str: String) -> void: if _revolver_widget != null: _revolver_widget.set_hammer_state(state_str)
func set_holster_state(holstered: bool) -> void: if _revolver_widget != null: _revolver_widget.set_holster_state(holstered)
func set_shoulder_state(is_right: bool) -> void: if _revolver_widget != null: _revolver_widget.set_shoulder_state(is_right)
func set_grit_fouling(grit: float, fouling: float) -> void: if _revolver_widget != null: _revolver_widget.set_grit_fouling(grit, fouling)
func set_region_name(r_name: String) -> void: if _vitals_widget != null: _vitals_widget.set_region_name(r_name)
func set_player_coordinates(coords: Vector3) -> void: if _vitals_widget != null: _vitals_widget.set_player_coordinates(coords)
func set_weather_telemetry(preset_name: String, density: float) -> void: if _vitals_widget != null: _vitals_widget.set_weather_telemetry(preset_name, density)

func set_crosshair_spread(is_aiming: bool, spread_factor: float) -> void: if _vitals_widget != null: _vitals_widget.set_crosshair_spread(is_aiming, spread_factor)
func trigger_damage_feedback(amount: float, attacker_pos: Vector3, dir_key: String = "DIR_FRONT") -> void: if _vitals_widget != null: _vitals_widget.trigger_damage_feedback(amount, attacker_pos, dir_key)
func trigger_low_health_warning() -> void: if _vitals_widget != null: _vitals_widget.trigger_low_health_warning()

func show_death_screen(r_name: String, duration: float) -> void: if _pause_toast_ctrl != null: _pause_toast_ctrl.show_death_screen(r_name, duration)
func hide_death_screen() -> void: if _pause_toast_ctrl != null: _pause_toast_ctrl.hide_death_screen()
func show_notification(text: String, duration: float = 3.5) -> void: if _pause_toast_ctrl != null: _pause_toast_ctrl.show_toast_message(text, duration)

func toggle_inspection(data: Dictionary) -> void: if _inventory_modal != null: _inventory_modal.toggle_inspection(data)
func show_inspection(data: Dictionary) -> void: if _inventory_modal != null: _inventory_modal.show_inspection(data)
func hide_inspection() -> void: if _inventory_modal != null: _inventory_modal.hide_inspection()

func toggle_chart() -> bool: return _pause_toast_ctrl.toggle_map_modal() if _pause_toast_ctrl != null else false
func toggle_map_modal() -> bool: return _pause_toast_ctrl.toggle_map_modal() if _pause_toast_ctrl != null else false
func show_map_modal() -> void: if _pause_toast_ctrl != null: _pause_toast_ctrl.show_map_modal()
func hide_map_modal() -> void: if _pause_toast_ctrl != null: _pause_toast_ctrl.hide_map_modal()
func update_map_player_telemetry(world_pos: Vector3, facing_yaw_rad: float) -> void: if _pause_toast_ctrl != null: _pause_toast_ctrl.update_map_player_telemetry(world_pos, facing_yaw_rad)

func toggle_settings_modal() -> void: if _pause_toast_ctrl != null: _pause_toast_ctrl.toggle_settings_modal()
func show_settings_modal() -> void: if _pause_toast_ctrl != null: _pause_toast_ctrl.show_settings_modal()
func hide_settings_modal() -> void: if _pause_toast_ctrl != null: _pause_toast_ctrl.hide_settings_modal()
func toggle_pause_menu() -> bool: return _pause_toast_ctrl.toggle_pause_menu() if _pause_toast_ctrl != null else false
func toggle_journal() -> bool: return _inventory_modal.toggle_journal() if _inventory_modal != null else false
func toggle_inventory() -> bool: return _inventory_modal.toggle_inventory() if _inventory_modal != null else false
func animate_cylinder_advance() -> void: if _revolver_widget != null: _revolver_widget.animate_cylinder_advance()

# Semantic aliases for contract completeness
func update_player_stats(hp_cur: float, hp_max: float, stam_cur: float, stam_max: float) -> void:
	set_health(hp_cur, hp_max)
	set_stamina(stam_cur, stam_max)

func update_weapon_hud(loaded: int, capacity: int, chamber: String, is_j: bool, hammer: String, grit: float, foul: float) -> void:
	set_cylinder_count(loaded, capacity)
	set_weapon_chamber(chamber, is_j)
	set_hammer_state(hammer)
	set_grit_fouling(grit, foul)

func update_location_display(region: String, coords: Vector3) -> void:
	set_region_name(region)
	set_player_coordinates(coords)

func update_weather_display(preset: String, density: float) -> void:
	set_weather_telemetry(preset, density)

func update_stamina_drain_readout(drain_rate: float) -> void:
	if posture_tag != null:
		posture_tag.text = "%.1f/s" % drain_rate

func update_tower_nexus_strain(strain_pct: float) -> void:
	if hazard_tag_label != null:
		hazard_tag_label.text = "◇  ⬡ Tensión de la Torre: %d%%" % int(strain_pct * 100.0)

# Localization & Diagnostics
func tr_ui(key: String) -> String: return Localization.translate_key(key, current_language)
func get_language() -> String: return current_language
func set_language(lang: String, persist: bool = true) -> String:
	current_language = Localization.set_language(lang, persist, SAVE_FILE_PATH)
	_refresh_localized_ui()
	language_changed.emit(current_language)
	return current_language

func cycle_language(persist: bool = true) -> String:
	return set_language("es" if current_language == "en" else "en", persist)

func _on_external_language_changed(new_lang: String) -> void:
	if current_language != new_lang:
		current_language = new_lang
		_refresh_localized_ui()
		language_changed.emit(current_language)

func _refresh_localized_ui() -> void:
	if settings_modal_title != null:
		settings_modal_title.text = tr_ui("SETTINGS_TITLE")
	if btn_close_settings != null:
		btn_close_settings.text = tr_ui("SETTINGS_CLOSE")
	_vitals_widget.refresh_top_center_header()
	_revolver_widget.refresh_control_legend_visuals()
	_pause_toast_ctrl.refresh_death_screen_text()

func toggle_perf_telemetry() -> void:
	if perf_telemetry_label != null:
		perf_telemetry_label.visible = not perf_telemetry_label.visible

func _update_perf_telemetry_readout(_delta: float) -> void:
	if perf_telemetry_label != null and perf_telemetry_label.visible:
		var fps := Engine.get_frames_per_second()
		perf_telemetry_label.text = "FPS: %d | MEM: %.1f MB" % [fps, OS.get_static_memory_usage() / 1048576.0]

func _connect_siege_telemetry() -> void:
	var siege_mgr = get_node_or_null("/root/WastelandSiegeManager")
	if siege_mgr != null and not siege_mgr.siege_started.is_connected(_on_siege_started):
		siege_mgr.siege_started.connect(_on_siege_started)

func _on_siege_started(basin_id: String, total_waves: int) -> void:
	_is_under_siege = true
	_active_siege_basin = basin_id
	_active_siege_max_waves = total_waves
	show_notification(tr_ui("NOTIF_SIEGE_ALERT"), 4.0)

# Procedural tick drawing & style delegates
func _draw_revolver_cylinder() -> void: if _revolver_widget != null: _revolver_widget.draw_revolver_cylinder()
func _draw_cylinder_indicator() -> void: if _revolver_widget != null: _revolver_widget.draw_cylinder_indicator()
func _draw_health_bar_ticks() -> void: if _vitals_widget != null: _vitals_widget.draw_health_bar_ticks()
func _draw_stamina_bar_ticks() -> void: if _vitals_widget != null: _vitals_widget.draw_stamina_bar_ticks()
func _draw_grit_bar_ticks() -> void: if _vitals_widget != null: _vitals_widget.draw_grit_bar_ticks()
func _update_bottom_left_panel_border() -> void: if _revolver_widget != null: _revolver_widget.update_bottom_left_panel_border()

func _enforce_hud_mouse_filters(node: Node) -> void:
	if node == null: return
	if node is Control:
		var is_interactive: bool = (node is Button or node is OptionButton or node is HSlider or node is CheckButton)
		if not is_interactive and node.name != "MapModal" and node.name != "SettingsModal" and node.name != "InspectionModal":
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child.name != "SettingsModal" and child.name != "InspectionModal" and child.name != "MapModal":
			_enforce_hud_mouse_filters(child)
