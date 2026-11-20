class_name WaystationSanctuary
extends Node3D

## Node 0: "The Mohaine Way-Bunker" (waystation_sanctuary)
##
## Pre-Break North Central Positronics (NCP) / Reinforced Way-Bunker Safe House:
## - Positioned at compound center (-1015.0, -815.0) with player spawn at (-1020.0, -820.0).
## - Upgraded with custom 3D .glb architectural model (res://assets/architecture/landmarks/waystation_bunker/bunker.glb).
## - BunkerShelterZone (Area3D): Completely blocks desert grit, halts temperature/stamina drain,
##   and accelerates metabolic recovery.
## - Diegetic Safe-House Interactables:
##   1. Tactile Gun-Cleaning Workbench (strips carbon soot, removes silica grit, oils firearm)
##   2. NCP Atomic Logbook / Terminal (diegetic save station)
##   3. Heavy Iron Footlocker (persistent starter supply cache)
##   4. Artesian Hand-Pump (stamina & health recovery)
## - The Threshold Walk Warning Gate at (-900.0, -820.0) leading into Southwest Desolation.
## Procedural architecture building is delegated to WaystationArchitectureBuilder.

signal player_shelter_changed(is_sheltered: bool)
signal weapon_serviced_at_workbench
signal chronicle_saved
signal well_water_consumed

const BUNKER_CENTER := Vector2(-1180.0, -1180.0)
const THRESHOLD_GATE := Vector2(-1060.0, -1060.0)
const BUNKER_SPAWN_BASE := Vector2(-1180.0, -1180.0)
const BUNKER_SPAWN_OFFSET := Vector2(24.0, 24.0)

const BUNKER_MODEL_PATH: String = "res://assets/architecture/landmarks/waystation_bunker/bunker.glb"
const BUNKER_MODEL_SCALE := Vector3(28.0, 26.0, 28.0)
const BUNKER_MODEL_ROTATION_DEG := Vector3(0.0, 45.0, 0.0)

var is_player_sheltered: bool = false
var _player_ref: CharacterBody3D = null

# Interactable stations
var _workbench_area: Area3D = null
var _terminal_area: Area3D = null
var _footlocker_area: Area3D = null
var _pump_area: Area3D = null

# Visual elements
var _terminal_light: OmniLight3D = null
var _interior_lantern: OmniLight3D = null
var _breezeway_lantern: OmniLight3D = null
var _pylon_lights: Array[OmniLight3D] = []

var _time_alive: float = 0.0
var _footlocker_looted: bool = false

# Player proximity tracking per station
var _near_workbench: bool = false
var _near_terminal: bool = false
var _near_footlocker: bool = false
var _near_pump: bool = false

const BUNKER_FOUNDATION_EMBED_Y: float = 0.32

func _ready() -> void:
	var ground_y := TerrainCollisionGenerator.sample_height(BUNKER_CENTER.x, BUNKER_CENTER.y)
	position = Vector3(BUNKER_CENTER.x, ground_y - BUNKER_FOUNDATION_EMBED_Y, BUNKER_CENTER.y)

	_build_bunker_architecture()
	_build_shelter_volume()
	_build_gun_cleaning_workbench()
	_build_ncp_atomic_logbook()
	_build_heavy_iron_footlocker()
	_build_artesian_hand_pump()
	_build_threshold_warning_gate()

func _physics_process(delta: float) -> void:
	_time_alive += delta

	# Flickering warm lantern glow inside bunker
	if _interior_lantern != null:
		_interior_lantern.light_energy = 2.4 + sin(_time_alive * 4.5) * 0.18 + cos(_time_alive * 11.2) * 0.08
	if _breezeway_lantern != null:
		_breezeway_lantern.light_energy = 2.0 + sin(_time_alive * 3.8) * 0.15

	# Glowing green phosphor CRT pulsation on NCP terminal
	if _terminal_light != null:
		_terminal_light.light_energy = 1.4 + sin(_time_alive * 3.0) * 0.25

	# Blinking amber warning beacons at threshold gate
	for light in _pylon_lights:
		if light != null:
			light.light_energy = 2.8 if fmod(_time_alive, 1.2) < 0.6 else 0.4

	# If player is sheltered, accelerate stamina recovery
	if is_player_sheltered and _player_ref != null:
		if _player_ref.has_method("get") and "stamina" in _player_ref:
			var max_s: float = float(_player_ref.get("max_stamina"))
			var cur_s: float = float(_player_ref.get("stamina"))
			if cur_s < max_s:
				var new_s := minf(max_s, cur_s + 35.0 * delta)
				_player_ref.set("stamina", new_s)
				if _player_ref.has_signal("stamina_changed"):
					_player_ref.emit_signal("stamina_changed", new_s, max_s)

func _unhandled_input(event: InputEvent) -> void:
	var is_interact_pressed: bool = false
	if event.is_action_pressed("cycle_action"):
		is_interact_pressed = true
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var iek := event as InputEventKey
		if iek.keycode == KEY_E or iek.physical_keycode == KEY_E:
			is_interact_pressed = true

	if not is_interact_pressed:
		return

	if _near_workbench:
		get_viewport().set_input_as_handled()
		interact_workbench()
	elif _near_terminal:
		get_viewport().set_input_as_handled()
		interact_terminal()
	elif _near_footlocker:
		get_viewport().set_input_as_handled()
		interact_footlocker()
	elif _near_pump:
		get_viewport().set_input_as_handled()
		interact_pump()

# ─── Architecture Delegation ──────────────────────────────────────────────────

func _build_bunker_architecture() -> void:
	var lights := WaystationArchitectureBuilder.build_bunker_architecture(self)
	_interior_lantern = lights.get("interior_lantern")
	_breezeway_lantern = lights.get("breezeway_lantern")

func _build_shelter_volume() -> void:
	WaystationArchitectureBuilder.build_shelter_volume(self)

func _build_gun_cleaning_workbench() -> void:
	_workbench_area = WaystationArchitectureBuilder.build_gun_cleaning_workbench(self)

func _build_ncp_atomic_logbook() -> void:
	var data := WaystationArchitectureBuilder.build_ncp_atomic_logbook(self)
	_terminal_area = data.get("area")
	_terminal_light = data.get("light")

func _build_heavy_iron_footlocker() -> void:
	_footlocker_area = WaystationArchitectureBuilder.build_heavy_iron_footlocker(self)

func _build_artesian_hand_pump() -> void:
	_pump_area = WaystationArchitectureBuilder.build_artesian_hand_pump(self)

func _build_threshold_warning_gate() -> void:
	_pylon_lights = WaystationArchitectureBuilder.build_threshold_warning_gate(self)

# ─── Shelter Zone Callbacks ───────────────────────────────────────────────────

func _on_shelter_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		_player_ref = body as CharacterBody3D
		is_player_sheltered = true
		player_shelter_changed.emit(true)
		var hud = get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("show_notification"):
			hud.show_notification("[ WAY-BUNKER SANCTUARY · PROTECTED FROM AIRBORNE SILICA ]")

func _on_shelter_body_exited(body: Node3D) -> void:
	if body == _player_ref or body.is_in_group("player"):
		is_player_sheltered = false
		player_shelter_changed.emit(false)

# ─── Station Interactions ─────────────────────────────────────────────────────

func interact_workbench() -> void:
	var player = _get_player()
	if player == null:
		return

	var ws = null
	if "weapon_system" in player and player.weapon_system != null:
		ws = player.weapon_system
	else:
		ws = player.find_child("WeaponSystem", true, false)

	if ws != null:
		if ws.has_method("field_clean"):
			ws.call("field_clean", 1.0)
		if "grit_index" in ws:
			ws.set("grit_index", 0.0)
		if "fouling_index" in ws:
			ws.set("fouling_index", 0.0)
		if "corrosion_index" in ws:
			ws.set("corrosion_index", 0.0)
		if "lubrication" in ws:
			ws.set("lubrication", 1.0)
		if "is_jammed" in ws:
			ws.set("is_jammed", false)

		weapon_serviced_at_workbench.emit()
		var hud = get_tree().get_first_node_in_group("hud")
		if hud != null:
			if hud.has_method("set_grit_fouling"):
				hud.call("set_grit_fouling", 0.0, 0.0)
			if hud.has_method("show_notification"):
				hud.show_notification("MAINTENANCE COMPLETE · BORE SCRUBBED & ACTION LUBRICATED")

func interact_terminal() -> void:
	var player = _get_player()
	var save_mgr = get_node_or_null("/root/WorldSaveData")
	if save_mgr != null:
		if save_mgr.has_method("record_checkpoint") and player != null:
			save_mgr.record_checkpoint(player.global_position, "The Mohaine Way-Bunker", "waystation_sanctuary", false, true)
		elif save_mgr.has_method("save_to_disk"):
			save_mgr.save_to_disk()

	if player != null and player.has_method("register_checkpoint"):
		player.call("register_checkpoint", player.global_position, "The Mohaine Way-Bunker")

	if _terminal_light != null:
		var tw := create_tween()
		tw.tween_property(_terminal_light, "light_energy", 4.0, 0.15)
		tw.tween_property(_terminal_light, "light_energy", 1.5, 0.5)

	chronicle_saved.emit()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_notification"):
		hud.show_notification("CHRONICLE COMMITTED · KA RECORD PRESERVED IN ATOMIC LOGBOOK")

func interact_footlocker() -> void:
	if _footlocker_looted:
		return
	_footlocker_looted = true

	var player = _get_player()
	if player != null and "gunslinger_progression" in player and player.gunslinger_progression != null:
		var prog = player.gunslinger_progression
		if prog.has_method("add_revolver_ammo"):
			prog.add_revolver_ammo(18)
		if prog.has_method("add_currency"):
			prog.add_currency(35)

	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_notification"):
		hud.show_notification("STASH CLAIMED: +18 .45 LC | +35 SCRAP | BORE PATCHES & OIL")

func interact_pump() -> void:
	var player = _get_player()
	if player == null:
		return

	if "stamina" in player and "max_stamina" in player:
		var max_s: float = float(player.get("max_stamina"))
		player.set("stamina", max_s)
		if player.has_signal("stamina_changed"):
			player.emit_signal("stamina_changed", max_s, max_s)

	if player.has_method("heal"):
		player.call("heal", 100.0)
	elif "current_health" in player and "max_health" in player:
		var max_h: float = float(player.get("max_health"))
		player.set("current_health", max_h)
		if player.has_signal("health_changed"):
			player.emit_signal("health_changed", max_h, max_h)

	well_water_consumed.emit()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_notification"):
		hud.show_notification("COOL DEEP WATER · HYDRATION, STAMINA & HEALTH RESTORED")

# ─── Helper Functions ─────────────────────────────────────────────────────────

func _get_player() -> CharacterBody3D:
	if _player_ref != null and is_instance_valid(_player_ref):
		return _player_ref
	_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody3D
	return _player_ref

func _show_hud_prompt(text: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_interaction_prompt"):
		hud.call("show_interaction_prompt", text)

func _clear_hud_prompt() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("hide_interaction_prompt"):
		hud.call("hide_interaction_prompt")
