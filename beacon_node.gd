class_name BeaconNode
extends Node3D

## Pre-Break Survey Monolith / Ka Beacon Control Node — "Dark Towers: The Path of Ka"
##
## Physical in-world 3D interactable landmark anchored inside regional basins:
## - Interacting initiates the territorial siege sequence for that basin.
## - Visualizes defense perimeter radius with tactical amber/crimson ground boundary rings.
## - Enforces perimeter confinement: leaving the radius triggers a 10s retreat countdown.
## - Once cleared, permanently remains ONLINE, dispelling the fog of war in that sector.

signal interaction_available(beacon: BeaconNode, prompt_text: String)
signal interaction_unavailable(beacon: BeaconNode)
signal siege_triggered(basin_id: String)
signal perimeter_exited(time_remaining: float)
signal perimeter_reentered()
signal beacon_state_changed(new_state: int)

enum BeaconState {
	DORMANT,
	ACTIVE_SIEGE,
	ONLINE_CLEARED
}

@export_group("Basin & Territorial Identity")
@export var basin_id: String = "north_alkali"
@export var localized_name_key: String = "BEACON_NORTH_ALKALI"
@export var defense_radius: float = 45.0
@export var interaction_radius: float = 3.5
@export var perimeter_abandon_timeout: float = 10.0

@export_group("Visual & Audio")
@export var pylon_height: float = 8.5
@export var pylon_color_dormant: Color = Color(0.92, 0.72, 0.38, 0.5)
@export var pylon_color_active: Color = Color(1.0, 0.32, 0.15, 1.0)
@export var pylon_color_cleared: Color = Color(0.98, 0.84, 0.48, 1.0)

var current_state: BeaconState = BeaconState.DORMANT
var is_player_in_interaction_zone: bool = false
var is_player_in_perimeter: bool = true
var _player_node: CharacterBody3D = null

var _perimeter_countdown: float = 0.0
var _is_counting_down: bool = false
var _time_alive: float = 0.0

var _interaction_area: Area3D = null
var _monolith_mesh: MeshInstance3D = null
var _perimeter_visual: MeshInstance3D = null
var _beacon_light: OmniLight3D = null
var _pylon_material: StandardMaterial3D = null
var _ring_material: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("beacon_nodes")
	_build_components()
	_sync_state_from_save()

	# Connect to siege manager signals if already initialized
	if is_inside_tree():
		var siege_mgr = get_node_or_null("/root/WastelandSiegeManager")
		if siege_mgr != null:
			if siege_mgr.has_signal("siege_completed") and not siege_mgr.siege_completed.is_connected(_on_siege_completed):
				siege_mgr.siege_completed.connect(_on_siege_completed)
			if siege_mgr.has_signal("siege_failed") and not siege_mgr.siege_failed.is_connected(_on_siege_failed):
				siege_mgr.siege_failed.connect(_on_siege_failed)

func _physics_process(delta: float) -> void:
	_time_alive += delta

	# Subtle harmonic pylon respiration
	if _beacon_light != null:
		match current_state:
			BeaconState.DORMANT:
				_beacon_light.light_energy = 1.2 + sin(_time_alive * 2.0) * 0.3
			BeaconState.ACTIVE_SIEGE:
				# High-urgency alert strobe
				_beacon_light.light_energy = 2.5 + sin(_time_alive * 8.0) * 1.5
			BeaconState.ONLINE_CLEARED:
				_beacon_light.light_energy = 2.0 + sin(_time_alive * 1.2) * 0.2

	# Monitor player distance if siege is currently underway
	if current_state == BeaconState.ACTIVE_SIEGE:
		_monitor_siege_perimeter(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_interaction_zone:
		return
	if current_state != BeaconState.DORMANT:
		return

	# Support 'cycle_action' (E), 'ui_accept' (Space/Enter), or F key
	var is_interact_pressed: bool = false
	if event.is_action_pressed("cycle_action"):
		is_interact_pressed = true
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var iek := event as InputEventKey
		if iek.keycode == KEY_E or iek.physical_keycode == KEY_E:
			is_interact_pressed = true

	if is_interact_pressed:
		get_viewport().set_input_as_handled()
		interact()

func interact() -> void:
	if current_state == BeaconState.DORMANT:
		initiate_siege()

func initiate_siege() -> void:
	if current_state == BeaconState.ACTIVE_SIEGE:
		return

	current_state = BeaconState.ACTIVE_SIEGE
	beacon_state_changed.emit(current_state)
	_update_visuals_for_state()

	siege_triggered.emit(basin_id)

	if is_inside_tree():
		var siege_mgr = get_node_or_null("/root/WastelandSiegeManager")
		if siege_mgr != null and siege_mgr.has_method("start_sector_siege"):
			siege_mgr.start_sector_siege(basin_id, self)

		# Notify HUD
		var hud = get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("show_notification"):
			var title: String = Localization.t(localized_name_key) if Localization != null else basin_id.to_upper()
			hud.show_notification("[ BEACON ACTIVATED ] " + title + " · DEFEND THE PERIMETER")

func _monitor_siege_perimeter(delta: float) -> void:
	if _player_node == null:
		_player_node = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player_node == null:
			return

	var dist: float = global_position.distance_to(_player_node.global_position)
	if dist > defense_radius:
		if not _is_counting_down:
			_is_counting_down = true
			_perimeter_countdown = perimeter_abandon_timeout
		else:
			_perimeter_countdown -= delta
			perimeter_exited.emit(maxf(0.0, _perimeter_countdown))

			# Show warning banner periodically
			var hud = get_tree().get_first_node_in_group("hud")
			if hud != null and hud.has_method("show_notification") and int(_perimeter_countdown * 2.0) % 2 == 0:
				hud.show_notification("WARNING: PERIMETER ABANDONED · RETURN IN %.1fs" % maxf(0.0, _perimeter_countdown))

			if _perimeter_countdown <= 0.0:
				_is_counting_down = false
				_abort_due_to_perimeter_leave()
	else:
		if _is_counting_down:
			_is_counting_down = false
			_perimeter_countdown = 0.0
			perimeter_reentered.emit()
			var hud = get_tree().get_first_node_in_group("hud")
			if hud != null and hud.has_method("show_notification"):
				hud.show_notification("PERIMETER RE-ESTABLISHED · BEACON ONLINE")

func _abort_due_to_perimeter_leave() -> void:
	var siege_mgr = get_node_or_null("/root/WastelandSiegeManager")
	if siege_mgr != null and siege_mgr.has_method("abort_siege"):
		siege_mgr.abort_siege("PERIMETER_ABANDONED")
	else:
		_on_siege_failed(basin_id, "PERIMETER_ABANDONED")

func _on_siege_completed(cleared_basin: String) -> void:
	if cleared_basin == basin_id or cleared_basin.is_empty():
		current_state = BeaconState.ONLINE_CLEARED
		_is_counting_down = false
		beacon_state_changed.emit(current_state)
		_update_visuals_for_state()

		if is_inside_tree():
			var save_mgr = get_node_or_null("/root/WorldSaveData")
			if save_mgr != null and save_mgr.has_method("mark_beacon_activated"):
				save_mgr.mark_beacon_activated("beacon_" + basin_id)

func _on_siege_failed(failed_basin: String, _reason: String) -> void:
	if failed_basin == basin_id or failed_basin.is_empty():
		current_state = BeaconState.DORMANT
		_is_counting_down = false
		beacon_state_changed.emit(current_state)
		_update_visuals_for_state()

func _sync_state_from_save() -> void:
	if is_inside_tree():
		var save_mgr = get_node_or_null("/root/WorldSaveData")
		if save_mgr != null and save_mgr.has_method("is_sector_cleared"):
			if save_mgr.is_sector_cleared(basin_id):
				current_state = BeaconState.ONLINE_CLEARED
				_update_visuals_for_state()
				return

	current_state = BeaconState.DORMANT
	_update_visuals_for_state()

# ─── Visual & Geometry Construction ──────────────────────────────────────────

func _build_components() -> void:
	# 1. Monolith Central Column
	_monolith_mesh = MeshInstance3D.new()
	_monolith_mesh.name = "MonolithPylon"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.4
	cylinder.bottom_radius = 0.95
	cylinder.height = pylon_height
	cylinder.radial_segments = 6 # Brutalist hexagonal geometry

	_pylon_material = StandardMaterial3D.new()
	_pylon_material.albedo_color = Color(0.24, 0.22, 0.20)
	_pylon_material.roughness = 0.88
	_pylon_material.emission_enabled = true
	_pylon_material.emission = pylon_color_dormant
	_pylon_material.emission_energy_multiplier = 0.6
	cylinder.material = _pylon_material
	_monolith_mesh.mesh = cylinder
	_monolith_mesh.position.y = pylon_height * 0.5
	add_child(_monolith_mesh)

	# 2. Survey Console
	var console := MeshInstance3D.new()
	console.name = "SurveyTerminalConsole"
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.1, 0.6)
	var console_mat := StandardMaterial3D.new()
	console_mat.albedo_color = Color(0.18, 0.16, 0.15)
	console_mat.roughness = 0.95
	box.material = console_mat
	console.mesh = box
	console.position = Vector3(0, 0.55, 1.2)
	add_child(console)

	# 3. Interaction Area
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 1
	_interaction_area.collision_mask = 1
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interaction_radius
	col_shape.shape = sphere
	_interaction_area.add_child(col_shape)
	add_child(_interaction_area)

	_interaction_area.body_entered.connect(_on_interaction_body_entered)
	_interaction_area.body_exited.connect(_on_interaction_body_exited)

	# 4. Perimeter Boundary Ring Visual
	_perimeter_visual = MeshInstance3D.new()
	_perimeter_visual.name = "PerimeterBoundaryRing"
	var ring_torus := TorusMesh.new()
	ring_torus.inner_radius = defense_radius - 0.25
	ring_torus.outer_radius = defense_radius + 0.25
	ring_torus.rings = 48
	ring_torus.ring_segments = 6

	_ring_material = StandardMaterial3D.new()
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color = Color(0.92, 0.72, 0.38, 0.25)
	_ring_material.emission_enabled = true
	_ring_material.emission = pylon_color_dormant
	_ring_material.emission_energy_multiplier = 0.4
	ring_torus.material = _ring_material

	_perimeter_visual.mesh = ring_torus
	_perimeter_visual.position.y = 0.12 # Skims terrain crust
	add_child(_perimeter_visual)

	# 5. Omnidirectional Beacon Light
	_beacon_light = OmniLight3D.new()
	_beacon_light.name = "BeaconLight"
	_beacon_light.omni_range = 14.0
	_beacon_light.light_color = pylon_color_dormant
	_beacon_light.light_energy = 1.2
	_beacon_light.position.y = pylon_height + 0.4
	add_child(_beacon_light)

func _update_visuals_for_state() -> void:
	if _pylon_material == null or _ring_material == null or _beacon_light == null:
		return

	match current_state:
		BeaconState.DORMANT:
			_pylon_material.emission = pylon_color_dormant
			_pylon_material.emission_energy_multiplier = 0.6
			_ring_material.albedo_color = Color(0.92, 0.72, 0.38, 0.18)
			_ring_material.emission = pylon_color_dormant
			_beacon_light.light_color = pylon_color_dormant
			if _perimeter_visual != null:
				_perimeter_visual.visible = is_player_in_interaction_zone
		BeaconState.ACTIVE_SIEGE:
			_pylon_material.emission = pylon_color_active
			_pylon_material.emission_energy_multiplier = 2.4
			_ring_material.albedo_color = Color(1.0, 0.32, 0.15, 0.65)
			_ring_material.emission = pylon_color_active
			_beacon_light.light_color = pylon_color_active
			if _perimeter_visual != null:
				_perimeter_visual.visible = true
		BeaconState.ONLINE_CLEARED:
			_pylon_material.emission = pylon_color_cleared
			_pylon_material.emission_energy_multiplier = 1.5
			_ring_material.albedo_color = Color(0.98, 0.84, 0.48, 0.35)
			_ring_material.emission = pylon_color_cleared
			_beacon_light.light_color = pylon_color_cleared
			if _perimeter_visual != null:
				_perimeter_visual.visible = false

func _on_interaction_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_in_interaction_zone = true
		_player_node = body as CharacterBody3D
		if _perimeter_visual != null and current_state == BeaconState.DORMANT:
			_perimeter_visual.visible = true

		var prompt: String = ""
		match current_state:
			BeaconState.DORMANT:
				prompt = "[E] " + Localization.t("PROMPT_ACTIVATE_BEACON") if Localization != null else "[E] ACTIVATE SURVEY BEACON"
			BeaconState.ACTIVE_SIEGE:
				prompt = Localization.t("PROMPT_BEACON_DEFENDING") if Localization != null else "BEACON TRANSMITTING · DEFEND PERIMETER"
			BeaconState.ONLINE_CLEARED:
				prompt = Localization.t("PROMPT_BEACON_CLEARED") if Localization != null else "SURVEY NODE ONLINE · SECTOR SECURED"

		interaction_available.emit(self, prompt)
		var hud = get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("show_notification"):
			hud.show_notification(prompt)

func _on_interaction_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_in_interaction_zone = false
		if _perimeter_visual != null and current_state == BeaconState.DORMANT:
			_perimeter_visual.visible = false
		interaction_unavailable.emit(self)
