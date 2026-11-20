class_name World
extends Node3D

const LootCrateManager = preload("res://world/loot_crate_manager.gd")

## Tactical Survival RPG World Controller (Godot 4 3D)
## Central orchestrator for "The Path of Ka" wasteland simulation.
## Delegates scene bootstrap to WorldBootstrapBuilder and sector hazards to WorldSectorSync.

# --- NODE REFERENCES ---
@export_group("Scene Entities")
@export var environment_node: WastelandEnvironment
@export var sun_light: DirectionalLight3D
@export var terrain_mesh: MeshInstance3D
@export var player: CharacterBody3D
@export var hud: CanvasLayer
@export var prop_scatter: PropScatter

# --- WEATHER & SURVIVAL CONFIGURATION ---
@export_group("Atmospheric Simulation")
@export var enable_natural_weather_cycle: bool = true
@export var weather_epoch_duration: float = 120.0
@export var weather_transition_duration: float = 5.0
@export var dust_exposure_multiplier: float = 1.0

@export_group("Debug & Tactical Controls")
@export var enable_weather_hotkeys: bool = true

# --- RUNTIME STATE ---
var _weather_timer: float = 0.0
var _current_preset_index: int = 0
var _cached_weapon_system: Node3D = null

# Sub-Controllers
var _bootstrap: WorldBootstrapBuilder = null
var _sector_sync: WorldSectorSync = null
var pause_menu: PauseMenu = null
var editor_flight_controller: EditorFlightController = null
var _editor_boot: WorldEditorBootstrap = null

# Sector blend weight accessors for backwards compatibility.
# NOTE: Godot 4.7 rejects single-line `var x: T: get: return ...` declarations
# ("Property with inline code must go to an indented block"), which stopped
# world.gd from loading at all and took the whole editor suite down with it.
# Keep each getter in an indented block.
var _sw_desolation_blend_weight: float:
	get: return _sector_sync.sw_desolation_blend_weight if _sector_sync else 0.0
var _south_salt_blend_weight: float:
	get: return _sector_sync.south_salt_blend_weight if _sector_sync else 0.0
var _cradle_blend_weight: float:
	get: return _sector_sync.cradle_blend_weight if _sector_sync else 0.0
var _west_gorge_blend_weight: float:
	get: return _sector_sync.west_gorge_blend_weight if _sector_sync else 0.0
var _north_alkali_blend_weight: float:
	get: return _sector_sync.north_alkali_blend_weight if _sector_sync else 0.0
var _east_dunes_blend_weight: float:
	get: return _sector_sync.east_dunes_blend_weight if _sector_sync else 0.0
var _tower_threshold_blend_weight: float:
	get: return _sector_sync.tower_threshold_blend_weight if _sector_sync else 0.0

const INITIAL_PLAYER_SPAWN_XZ := Vector2(-1020.0, -820.0)
const BUNKER_SPAWN_OFFSET := Vector2(2.0, 0.0)

const WEATHER_SEQUENCE: Array[int] = [
	WastelandEnvironment.WeatherPreset.CLEAR_ARID, WastelandEnvironment.WeatherPreset.HEAT_HAZE,
	WastelandEnvironment.WeatherPreset.DUST_DEVIL, WastelandEnvironment.WeatherPreset.SEVERE_HABOOB,
	WastelandEnvironment.WeatherPreset.COLD_DESERT_NIGHT
]

const GRIT_DENSITIES: Dictionary = {
	WastelandEnvironment.WeatherPreset.CLEAR_ARID: 4.0, WastelandEnvironment.WeatherPreset.HEAT_HAZE: 8.5,
	WastelandEnvironment.WeatherPreset.DUST_DEVIL: 45.0, WastelandEnvironment.WeatherPreset.SEVERE_HABOOB: 180.0,
	WastelandEnvironment.WeatherPreset.COLD_DESERT_NIGHT: 2.0
}

const PRESET_NAMES: Dictionary = {
	WastelandEnvironment.WeatherPreset.CLEAR_ARID: "CLEAR ARID", WastelandEnvironment.WeatherPreset.HEAT_HAZE: "HEAT HAZE",
	WastelandEnvironment.WeatherPreset.DUST_DEVIL: "DUST DEVIL", WastelandEnvironment.WeatherPreset.SEVERE_HABOOB: "SEVERE HABOOB",
	WastelandEnvironment.WeatherPreset.COLD_DESERT_NIGHT: "COLD DESERT NIGHT"
}

func _init() -> void:
	_bootstrap = WorldBootstrapBuilder.new(self)
	_sector_sync = WorldSectorSync.new(self)
	_editor_boot = WorldEditorBootstrap.new(self)

func _ready() -> void:
	_resolve_scene_nodes()
	_initialize_atmosphere()
	_create_loading_overlay()
	_freeze_player_for_bootstrap()
	_connect_subsystems()
	_push_initial_telemetry()
	await _bootstrap.execute_staged_bootstrap(Callable(self, "_on_bootstrap_stage_progress"))
	await _ground_and_restore_player()
	_on_bootstrap_completed()

func _create_loading_overlay() -> void: _bootstrap.create_loading_overlay()

func _freeze_player_for_bootstrap() -> void:
	if player == null: return
	player.velocity = Vector3.ZERO; player.set_physics_process(false)
	player.set_process_input(false); player.set_process_unhandled_input(false)

func _ground_and_restore_player() -> void:
	if player == null: return
	if get_tree() != null:
		await get_tree().physics_frame
		await get_tree().physics_frame
	_bootstrap.resolve_safe_player_spawn(player)
	player.velocity = Vector3.ZERO; player.set_process_input(true); player.set_process_unhandled_input(true)
	if not WorldSaveData.is_editor_active(): player.set_physics_process(true)

func _on_bootstrap_stage_progress(stage_title: String, fraction: float) -> void:
	_bootstrap.report_stage_progress(stage_title, fraction)

func _on_bootstrap_completed() -> void:
	# Re-assert the editor suite after the player is grounded/restored so the
	# flight cam, HUD overlay and input ownership survive the bootstrap unfreeze.
	_editor_boot.finalize_after_bootstrap()
	call_deferred("_ensure_initial_window_and_input_capture")
	_bootstrap.dismiss_loading_overlay()

func _run_procedural_prop_generation() -> void:
	if prop_scatter != null and prop_scatter.has_method("ensure_scatter_completed"):
		prop_scatter.ensure_scatter_completed()
	elif prop_scatter != null and not prop_scatter.is_scatter_complete:
		prop_scatter.call("_run_scatter")

func _setup_pause_menu() -> void:
	pause_menu = find_child("PauseMenu", true, false) as PauseMenu
	if pause_menu == null:
		if ResourceLoader.exists("res://scenes/pause_menu.tscn"):
			var scn := load("res://scenes/pause_menu.tscn") as PackedScene
			if scn != null:
				pause_menu = scn.instantiate() as PauseMenu
		if pause_menu == null:
			pause_menu = PauseMenu.new()
		pause_menu.name = "PauseMenu"
		add_child(pause_menu)

func _apply_world_layout_overrides() -> void:
	var serializer := WorldLayoutSerializer.new()
	var applied := serializer.apply_overrides(self)
	if applied > 0:
		print("[WorldLayoutSerializer] Applied %d world layout overrides from JSON" % applied)

# ─── Editor Suite (delegated to world/world_editor_bootstrap.gd) ─────────────

## Unconditionally instantiates, parents and initializes the editor tool suite.
func _check_and_init_editor_mode() -> void: _editor_boot.ensure_editor_suite()
func ensure_editor_suite() -> EditorFlightController: return _editor_boot.ensure_editor_suite()
func get_editor_boot_report() -> Dictionary: return _editor_boot.build_boot_report()
func _on_editor_mode_toggled(active: bool) -> void: _editor_boot.on_editor_mode_toggled(active)

func _ensure_initial_window_and_input_capture() -> void:
	var win := get_window()
	if win != null: win.grab_focus()
	_do_capture_mouse()
	# Timer fallback: re-apply after one frame so the OS window is fully focused
	if get_tree() != null:
		get_tree().create_timer(0.15).timeout.connect(_do_capture_mouse)

func _do_capture_mouse() -> void:
	if WorldSaveData.is_editor_active():
		if editor_flight_controller != null and editor_flight_controller.has_method("_capture_mouse"):
			editor_flight_controller.call("_capture_mouse")
	else:
		if player != null and player.has_method("_capture_mouse"):
			player.call("_capture_mouse")

func _process(delta: float) -> void:
	_process_weather_cycle(delta)
	_sync_sector_environment(delta)
	_process_environmental_grit_exposure(delta)
	_sync_particle_volume_to_player()
	_sync_map_telemetry()

# ─── Delegated Bootstrap Helpers ─────────────────────────────────────────────

func _align_landmark_and_props() -> void: _bootstrap.align_landmark_and_props()
func _setup_terrain_collision() -> void: _bootstrap.setup_terrain_collision()
func _setup_waystation_sanctuary() -> void: _bootstrap.setup_waystation_sanctuary()
func _setup_regional_beacons_and_spawners() -> void: _bootstrap.setup_regional_beacons_and_spawners()
func _setup_regional_landmarks() -> void: _bootstrap.setup_regional_landmarks()
func _setup_basin_navigation_and_enemies() -> void: _bootstrap.setup_basin_navigation_and_enemies()
func _setup_thinny_anomalies() -> void: _bootstrap.setup_thinny_anomalies()
func _setup_horizon_clipmap() -> void: _bootstrap.setup_horizon_clipmap()
func _setup_narrative_relics() -> void: _bootstrap.setup_narrative_relics()
func _setup_loot_crate_system() -> void: _bootstrap.setup_loot_crate_system()
func _configure_graphics_quality() -> void: _bootstrap.configure_graphics_quality()

# ─── Delegated Sector Sync Helpers ───────────────────────────────────────────

func _sync_sector_environment(delta: float) -> void: _sector_sync.sync_sector_environment(delta)
func _process_environmental_grit_exposure(delta: float) -> void: _sector_sync.process_environmental_grit_exposure(delta)
func _sync_particle_volume_to_player() -> void: _sector_sync.sync_particle_volume_to_player()
func _sync_map_telemetry() -> void: _sector_sync.sync_map_telemetry()
func _resolve_safe_respawn_point(death_position: Vector3) -> Dictionary: return _sector_sync.resolve_safe_respawn_point(death_position)

# ─── Initialization & Atmosphere ─────────────────────────────────────────────

func _resolve_scene_nodes() -> void:
	if environment_node == null: environment_node = get_node_or_null("WorldEnvironment") as WastelandEnvironment
	if sun_light == null: sun_light = (get_node_or_null("DirectionalLight3D") if get_node_or_null("DirectionalLight3D") != null else get_node_or_null("WastelandSun")) as DirectionalLight3D
	if terrain_mesh == null: terrain_mesh = (get_node_or_null("DesertTerrain") if get_node_or_null("DesertTerrain") != null else get_node_or_null("DesertGround/GroundMesh")) as MeshInstance3D
	if player == null: player = get_node_or_null("Player") as CharacterBody3D
	if hud == null: hud = get_node_or_null("HUD") as CanvasLayer
	if prop_scatter == null: prop_scatter = get_node_or_null("PropScatter") as PropScatter
	if player != null:
		_cached_weapon_system = player.weapon_system as Node3D if ("weapon_system" in player and player.weapon_system != null) else player.find_child("WeaponSystem", true, false) as Node3D

func _initialize_atmosphere() -> void:
	if environment_node != null:
		if sun_light != null and environment_node.sun_node == null: environment_node.sun_node = sun_light
		environment_node.active_preset = WastelandEnvironment.WeatherPreset.CLEAR_ARID
		_current_preset_index = 0

func _connect_subsystems() -> void:
	if player != null and hud != null:
		var p_sigs := [
			["stamina_changed", _on_player_stamina_changed], ["health_changed", _on_player_health_changed],
			["damaged", _on_player_damaged], ["low_health_entered", _on_player_low_health_entered],
			["player_died", _on_player_died], ["player_respawned", _on_player_respawned],
			["state_changed", _on_player_state_changed], ["aim_state_changed", _on_player_aim_state_changed],
			["shoulder_changed", _on_player_shoulder_changed]
		]
		for s in p_sigs:
			if player.has_signal(s[0]) and not player.is_connected(s[0], s[1]): player.connect(s[0], s[1])
		if "respawn_point_provider" in player: player.respawn_point_provider = Callable(self, "_resolve_safe_respawn_point")

	if _cached_weapon_system != null and hud != null:
		var ws: Node3D = _cached_weapon_system
		var w_sigs := [
			["weapon_fired", _on_weapon_fired], ["weapon_dry_fired", _on_weapon_dry_fired],
			["weapon_jammed", _on_weapon_jammed], ["jam_cleared", _on_jam_cleared],
			["hammer_cocked", _on_hammer_cocked], ["action_cycled", _on_action_cycled],
			["round_loaded", _on_round_loaded], ["chamber_state_changed", _on_chamber_state_changed],
			["grit_level_changed", _on_grit_level_changed], ["maintenance_performed", _on_maintenance_performed],
			["holster_state_changed", _on_holster_state_changed], ["target_hit", _on_weapon_target_hit]
		]
		for s in w_sigs:
			if ws.has_signal(s[0]) and not ws.is_connected(s[0], s[1]): ws.connect(s[0], s[1])

	if environment_node != null:
		if environment_node.has_signal("weather_transition_started") and not environment_node.weather_transition_started.is_connected(_on_weather_transition_started):
			environment_node.weather_transition_started.connect(_on_weather_transition_started)
		if environment_node.has_signal("weather_transition_completed") and not environment_node.weather_transition_completed.is_connected(_on_weather_transition_completed):
			environment_node.weather_transition_completed.connect(_on_weather_transition_completed)

	var world_manager := get_node_or_null("WorldManager") as WorldManager
	if world_manager == null:
		world_manager = WorldManager.new(); world_manager.name = "WorldManager"; world_manager.player_target = player
		world_manager.prop_scatter_node = prop_scatter; world_manager.terrain_source = terrain_mesh; world_manager.environment_node = environment_node
		add_child(world_manager)
	if world_manager != null and not world_manager.bubble_entered.is_connected(_on_bubble_entered):
		world_manager.bubble_entered.connect(_on_bubble_entered)

	if hud != null and "map_modal" in hud and hud.map_modal != null:
		hud.map_modal.bind_world_context(player, world_manager, prop_scatter, hud)
	if prop_scatter != null and not prop_scatter.scatter_complete.is_connected(_on_prop_scatter_completed_for_map):
		prop_scatter.scatter_complete.connect(_on_prop_scatter_completed_for_map)

func _on_prop_scatter_completed_for_map(_total_props: int) -> void:
	if hud != null and "map_modal" in hud and hud.map_modal != null:
		hud.map_modal.bind_world_context(player, get_node_or_null("WorldManager"), prop_scatter, hud)

func _on_bubble_entered(_bubble_id: String, bubble_name: String) -> void:
	if player != null and player.has_method("register_checkpoint"): player.call("register_checkpoint", player.global_position, bubble_name)
	if hud != null:
		if hud.has_method("set_region_name"): hud.call("set_region_name", bubble_name)
		if hud.has_method("show_notification"): hud.call("show_notification", Localization.t("NOTIF_ENTERING_FMT") % Localization.translate_region_name(bubble_name), 3.0)

func _push_initial_telemetry() -> void:
	if hud == null: return
	if player != null:
		if "current_health" in player and "max_health" in player and hud.has_method("set_health"): hud.call("set_health", player.current_health, player.max_health)
		if "stamina" in player and "max_stamina" in player and hud.has_method("set_stamina"): hud.call("set_stamina", player.stamina, player.max_stamina)
		if "is_right_shoulder" in player and hud.has_method("set_shoulder_state"): hud.call("set_shoulder_state", bool(player.is_right_shoulder))
		var wm: WorldManager = get_node_or_null("WorldManager") as WorldManager
		var r_name: String = wm.get_current_basin(player.global_position).get("name", "The Mohaine Way-Bunker") if (wm != null and wm.has_method("get_current_basin")) else "The Mohaine Way-Bunker"
		if hud.has_method("set_region_name"): hud.call("set_region_name", r_name)
		if hud.has_method("set_player_coordinates"): hud.call("set_player_coordinates", player.global_position)

	if _cached_weapon_system != null:
		var ws: Node3D = _cached_weapon_system
		if hud.has_method("set_weapon_identity") and "weapon_name" in ws and "caliber_name" in ws: hud.call("set_weapon_identity", ws.weapon_name, ws.caliber_name)
		if hud.has_method("set_cylinder_count") and "current_magazine_rounds" in ws and "magazine_capacity" in ws:
			hud.call("set_cylinder_count", int(ws.current_magazine_rounds) + (1 if bool(ws.get("is_loaded")) else 0), int(ws.magazine_capacity))
		if hud.has_method("set_weapon_chamber") and "chamber_state" in ws: hud.call("set_weapon_chamber", _format_chamber_name(int(ws.chamber_state)), bool(ws.get("is_jammed")))
		if hud.has_method("set_grit_fouling") and "grit_index" in ws and "fouling_index" in ws: hud.call("set_grit_fouling", float(ws.grit_index), float(ws.fouling_index))

	var active_preset: int = environment_node.active_preset if environment_node else WastelandEnvironment.WeatherPreset.CLEAR_ARID
	if hud.has_method("set_weather_telemetry"): hud.call("set_weather_telemetry", PRESET_NAMES.get(active_preset, "CLEAR ARID"), GRIT_DENSITIES.get(active_preset, 4.0))

# ─── Weather Cycle API ───────────────────────────────────────────────────────

func _process_weather_cycle(delta: float) -> void:
	if not enable_natural_weather_cycle or environment_node == null: return
	_weather_timer += delta
	if _weather_timer >= weather_epoch_duration:
		_weather_timer = 0.0
		advance_weather_state()

func advance_weather_state() -> void:
	_current_preset_index = (_current_preset_index + 1) % WEATHER_SEQUENCE.size()
	set_weather_preset(WEATHER_SEQUENCE[_current_preset_index], weather_transition_duration)

func set_weather_preset(preset: int, duration_seconds: float = 4.0) -> void:
	if environment_node == null: return
	for i in range(WEATHER_SEQUENCE.size()):
		if WEATHER_SEQUENCE[i] == preset: _current_preset_index = i; break
	environment_node.transition_to_weather(preset as WastelandEnvironment.WeatherPreset, duration_seconds)
	if preset == WastelandEnvironment.WeatherPreset.SEVERE_HABOOB:
		var loot_mgr := get_node_or_null("LootCrateManager") as LootCrateManager
		if loot_mgr != null: loot_mgr.on_severe_haboob_occurred()

# ─── Input & Hotkeys ─────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo(): return
	var key_event: InputEventKey = event as InputEventKey

	if event.is_action_pressed("toggle_recon_map") or event.is_action_pressed("map") or event.is_action_pressed("ui_map") or event.is_action_pressed("toggle_map") or key_event.physical_keycode == KEY_M or key_event.keycode == KEY_M:
		if WorldSaveData != null and WorldSaveData.is_editor_active(): return
		if hud != null:
			if hud.has_method("toggle_chart"):
				hud.call("toggle_chart"); get_viewport().set_input_as_handled(); return
			elif hud.has_method("toggle_map_modal"):
				hud.call("toggle_map_modal"); get_viewport().set_input_as_handled(); return

	# Survival-only hotkeys: weapon inspection, weather debug, 1-5 presets
	# Editor mode has exclusive ownership of 1-5 for sector teleport (editor_flight_controller.gd)
	if WorldSaveData != null and WorldSaveData.is_editor_active(): return

	if event.is_action_pressed("field_gunsmith_inspect") or event.is_action_pressed("inspect_weapon") or key_event.physical_keycode == KEY_I or key_event.keycode == KEY_I:
		_toggle_weapon_inspection(); get_viewport().set_input_as_handled(); return

	if not enable_weather_hotkeys: return
	if key_event.physical_keycode == KEY_T or key_event.keycode == KEY_T:
		advance_weather_state(); get_viewport().set_input_as_handled(); return

	var key_presets := {
		KEY_1: WastelandEnvironment.WeatherPreset.CLEAR_ARID, KEY_2: WastelandEnvironment.WeatherPreset.HEAT_HAZE,
		KEY_3: WastelandEnvironment.WeatherPreset.DUST_DEVIL, KEY_4: WastelandEnvironment.WeatherPreset.SEVERE_HABOOB,
		KEY_5: WastelandEnvironment.WeatherPreset.COLD_DESERT_NIGHT
	}
	if key_presets.has(key_event.physical_keycode):
		set_weather_preset(key_presets[key_event.physical_keycode], 2.5); get_viewport().set_input_as_handled()

func _toggle_weapon_inspection() -> void:
	if hud != null and _cached_weapon_system != null and _cached_weapon_system.has_method("inspect_weapon"):
		if hud.has_method("toggle_inspection"): hud.call("toggle_inspection", _cached_weapon_system.call("inspect_weapon"))

# ─── Signal Callbacks ────────────────────────────────────────────────────────

func _on_player_health_changed(cur: float, max_v: float) -> void: if hud != null and hud.has_method("set_health"): hud.call("set_health", cur, max_v)
func _on_player_damaged(amt: float, pos: Vector3, dir: String) -> void: if hud != null and hud.has_method("trigger_damage_feedback"): hud.call("trigger_damage_feedback", amt, pos, dir)
func _on_player_low_health_entered(_c: float, _m: float) -> void: if hud != null and hud.has_method("trigger_low_health_warning"): hud.call("trigger_low_health_warning")
func _on_player_died(_pos: Vector3, r_name: String, dur: float) -> void:
	if hud != null and hud.has_method("show_death_screen"): hud.call("show_death_screen", r_name, dur)
	var raiders := get_node_or_null("WastelandRaiders")
	if raiders != null:
		for c in raiders.get_children(): if c.has_method("reset_aggro"): c.call("reset_aggro")
func _on_player_respawned(_pos: Vector3, r_name: String) -> void:
	if hud != null:
		if hud.has_method("hide_death_screen"): hud.call("hide_death_screen")
		if hud.has_method("show_notification"): hud.call("show_notification", Localization.t("NOTIF_PLAYER_RESPAWNED_FMT") % Localization.translate_region_name(r_name), 4.0)
func _on_player_stamina_changed(cur: float, max_v: float) -> void: if hud != null and hud.has_method("set_stamina"): hud.call("set_stamina", cur, max_v)
func _on_player_state_changed(_o: int, n: int) -> void:
	if hud != null and hud.has_method("set_locomotion_state"):
		var states := ["IDLE", "WALKING", "SPRINTING", "CROUCHING", "AIRBORNE", "EXHAUSTED"]
		hud.call("set_locomotion_state", states[clampi(n, 0, states.size() - 1)])
func _on_player_aim_state_changed(aim: bool, spread: float) -> void: if hud != null and hud.has_method("set_crosshair_spread"): hud.call("set_crosshair_spread", aim, spread)
func _on_player_shoulder_changed(is_r: bool) -> void: if hud != null and hud.has_method("set_shoulder_state"): hud.call("set_shoulder_state", is_r)

func _on_weapon_fired(_data: Dictionary) -> void:
	if hud != null and hud.has_method("animate_cylinder_advance"): hud.call("animate_cylinder_advance")
	_refresh_weapon_ui()
func _on_action_cycled(_e: int, _s: int) -> void: _refresh_weapon_ui()
func _on_weapon_dry_fired(r: String) -> void:
	if hud != null and hud.has_method("show_notification"): hud.call("show_notification", Localization.t("NOTIF_DRY_FIRE_FMT") % r.to_upper(), 2.0)
	_refresh_weapon_ui()
func _on_weapon_jammed(st: int, desc: String) -> void:
	if hud != null and hud.has_method("set_weapon_chamber"): hud.call("set_weapon_chamber", _format_chamber_name(st), true)
	if hud != null and hud.has_method("show_notification"): hud.call("show_notification", Localization.t("NOTIF_JAM_FMT") % desc.to_upper(), 3.5)
func _on_jam_cleared(_p: int) -> void:
	if hud != null and hud.has_method("show_notification"): hud.call("show_notification", Localization.t("NOTIF_CHAMBER_CLEARED"), 2.0)
	_refresh_weapon_ui()
func _on_hammer_cocked() -> void: if hud != null and hud.has_method("set_hammer_state"): hud.call("set_hammer_state", "COCKED")
func _on_round_loaded(loaded: int, cap: int) -> void:
	if hud != null and hud.has_method("set_cylinder_count"): hud.call("set_cylinder_count", loaded, cap)
	_refresh_weapon_ui()
func _on_chamber_state_changed(st: int) -> void:
	if hud != null and hud.has_method("set_weapon_chamber"): hud.call("set_weapon_chamber", _format_chamber_name(st), st in [3, 4, 5])
func _on_grit_level_changed(_g: float) -> void:
	if _cached_weapon_system != null and hud != null and hud.has_method("set_grit_fouling"):
		hud.call("set_grit_fouling", float(_cached_weapon_system.get("grit_index")), float(_cached_weapon_system.get("fouling_index")))
func _on_maintenance_performed(g: float, f: float) -> void:
	if hud != null and hud.has_method("show_notification"): hud.call("show_notification", Localization.t("NOTIF_CLEANED_BORE_FMT") % [int(g * 100), int(f * 100)], 2.5)
	_refresh_weapon_ui()
func _on_holster_state_changed(h: bool) -> void:
	if hud != null:
		if hud.has_method("set_holster_state"): hud.call("set_holster_state", h)
		if hud.has_method("show_notification"): hud.call("show_notification", Localization.t("NOTIF_REVOLVER_HOLSTERED") if h else Localization.t("NOTIF_REVOLVER_DRAWN"), 2.0)
	_refresh_weapon_ui()
func _on_weapon_target_hit(hit: Dictionary) -> void:
	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", Localization.t("NOTIF_IMPACT_FMT") % [
			String(hit.get("material_type", "SAND")), int(round(float(hit.get("distance_m", 0.0)))),
			int(round(float(hit.get("impact_velocity_mps", 0.0)))), float(hit.get("gravity_drop_m", 0.0)),
			float(hit.get("wind_drift_m", 0.0))
		], 2.8)

func _resolve_weather_density(p_name: String) -> float:
	for p_enum in PRESET_NAMES:
		if PRESET_NAMES[p_enum] == p_name or WastelandEnvironment.WeatherPreset.keys()[p_enum] == p_name:
			return GRIT_DENSITIES.get(p_enum, 4.0)
	return 4.0

func _on_weather_transition_started(_from: String, to_p: String, _dur: float) -> void:
	var density := _resolve_weather_density(to_p)
	if hud != null:
		if hud.has_method("set_weather_telemetry"): hud.call("set_weather_telemetry", to_p, density)
		if hud.has_method("show_notification"): hud.call("show_notification", Localization.t("NOTIF_WEATHER_SHIFT_FMT") % Localization.translate_weather_preset(to_p), 3.0)

func _on_weather_transition_completed(curr_p: String) -> void:
	if hud != null and hud.has_method("set_weather_telemetry"): hud.call("set_weather_telemetry", curr_p, _resolve_weather_density(curr_p))

func _refresh_weapon_ui() -> void:
	if _cached_weapon_system == null or hud == null: return
	var ws: Node3D = _cached_weapon_system
	if hud.has_method("set_cylinder_count") and "current_magazine_rounds" in ws and "magazine_capacity" in ws:
		hud.call("set_cylinder_count", int(ws.current_magazine_rounds) + (1 if bool(ws.get("is_loaded")) else 0), int(ws.magazine_capacity))
	if hud.has_method("set_weapon_chamber") and "chamber_state" in ws:
		hud.call("set_weapon_chamber", _format_chamber_name(int(ws.chamber_state)), bool(ws.get("is_jammed")))
	if hud.has_method("set_hammer_state") and "hammer_state" in ws:
		hud.call("set_hammer_state", "COCKED" if int(ws.hammer_state) == 2 else "RESTING")
	if hud.has_method("set_grit_fouling") and "grit_index" in ws and "fouling_index" in ws:
		hud.call("set_grit_fouling", float(ws.grit_index), float(ws.fouling_index))

func _format_chamber_name(st: int) -> String:
	var names := ["EMPTY", "LIVE ROUND", "SPENT CASING", "STOVEPIPE JAM", "FAILURE TO FEED", "FAILURE TO EXTRACT", "OUT OF BATTERY"]
	return names[st] if st >= 0 and st < names.size() else "UNKNOWN"
