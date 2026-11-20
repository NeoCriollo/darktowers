extends Node

## Wasteland Siege Manager Autoload — "Dark Towers: The Path of Ka"
##
## Central coordinator for territorial sieges across regional basins:
## - Manages wave escalation, enemy tracking registries, and intermission pacing
## - Dispatches spawn requests to local BasinSpawner nodes
## - Enforces failsafes against orphan coroutines, physics desyncs, and lost mobs
## - Connects victory directly to WorldSaveData persistence and telemetry signals

signal siege_started(basin_id: String, total_waves: int)
signal wave_started(wave_number: int, total_enemies: int)
signal enemy_count_updated(remaining: int, total: int)
signal wave_completed(wave_number: int)
signal siege_completed(basin_id: String)
signal siege_failed(basin_id: String, reason: String)
signal telemetry_updated(status_text: String)

@export var default_max_waves: int = 5
@export var intermission_delay: float = 3.5
@export var wave_stalemate_timeout: float = 90.0

var current_target_basin: String = ""
var is_siege_active: bool = false
var current_wave: int = 0
var max_waves_for_basin: int = 5

var active_enemies_remaining: int = 0
var total_enemies_in_wave: int = 0
var active_beacon: Node = null

## Registry of tracked enemy instance IDs -> weakref / reference
var _tracked_enemies: Dictionary = {}
var _intermission_in_progress: bool = false
var _wave_elapsed_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _physics_process(delta: float) -> void:
	if not is_siege_active or _intermission_in_progress:
		return

	_wave_elapsed_time += delta

	# Stalemate safeguard: if wave drags on with 1 enemy remaining, force proximity ping or check
	if active_enemies_remaining == 1 and _wave_elapsed_time > wave_stalemate_timeout:
		_resolve_stalemate_target()

func start_sector_siege(basin_name: String, beacon_node: Node = null) -> void:
	if is_siege_active:
		push_warning("WastelandSiegeManager: Siege already active in %s" % current_target_basin)
		return

	current_target_basin = basin_name.strip_edges().to_lower()
	if current_target_basin == "waystation_sanctuary":
		push_warning("WastelandSiegeManager: waystation_sanctuary is a designated safe zone; sieges cannot occur here.")
		return
	active_beacon = beacon_node
	is_siege_active = true
	current_wave = 0
	_intermission_in_progress = false

	# The Threshold of the Dark Tower requires a full 8-wave Apex Siege
	if current_target_basin == "monolith_pass":
		max_waves_for_basin = 8
	else:
		max_waves_for_basin = default_max_waves

	siege_started.emit(current_target_basin, max_waves_for_basin)
	telemetry_updated.emit("SECTOR STATUS: UNDER SIEGE")
	_advance_to_next_wave()

func _advance_to_next_wave() -> void:
	if not is_siege_active:
		return

	_intermission_in_progress = false
	current_wave += 1
	_wave_elapsed_time = 0.0

	if current_wave > max_waves_for_basin:
		_complete_sector_siege()
		return

	# Calculate wave composition curve
	total_enemies_in_wave = _calculate_wave_enemy_count(current_wave)
	active_enemies_remaining = total_enemies_in_wave
	_tracked_enemies.clear()

	wave_started.emit(current_wave, total_enemies_in_wave)
	enemy_count_updated.emit(active_enemies_remaining, total_enemies_in_wave)

	_trigger_basin_spawners(total_enemies_in_wave, current_wave)

func _calculate_wave_enemy_count(wave_idx: int) -> int:
	match wave_idx:
		1: return 3   ## Wave 1: Scout skirmishers
		2: return 5   ## Wave 2: Recon vanguard
		3: return 7   ## Wave 3: Heavy line assault
		4: return 8   ## Wave 4: Suppressive raid squad
		5: return 10  ## Wave 5: Basin Breachers / First Warden
		6: return 12  ## Wave 6: Fortified raider core
		7: return 13  ## Wave 7: Elite vanguard
		8: return 15  ## Wave 8: Apex Breach / The Warden
		_: return 3 + (wave_idx * 2)

func _trigger_basin_spawners(count: int, wave_intensity: int) -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	var spawners = get_tree().get_nodes_in_group("basin_spawners")
	if spawners.is_empty():
		push_warning("WastelandSiegeManager: No basin spawners found in tree! Auto-resolving wave.")
		call_deferred("_auto_complete_empty_wave")
		return

	# Filter spawners that match current basin if configured, or distribute evenly
	var target_spawners: Array[Node] = []
	for s in spawners:
		var s_basin = s.get("basin_id") if "basin_id" in s else ""
		if s_basin.is_empty() or s_basin == current_target_basin:
			target_spawners.append(s)

	if target_spawners.is_empty():
		target_spawners = spawners

	var per_spawner: int = maxi(1, int(ceil(float(count) / float(target_spawners.size()))))
	var remaining_to_assign: int = count

	for spawner in target_spawners:
		if remaining_to_assign <= 0:
			break
		var assign_count: int = mini(remaining_to_assign, per_spawner)
		if spawner.has_method("spawn_raider_wave"):
			spawner.spawn_raider_wave(assign_count, wave_intensity)
		remaining_to_assign -= assign_count

func register_siege_enemy(enemy: CharacterBody3D) -> void:
	if not is_siege_active or enemy == null:
		return

	var id: int = enemy.get_instance_id()
	if not _tracked_enemies.has(id):
		_tracked_enemies[id] = enemy
		enemy.set_meta("is_siege_unit", true)

		# Auto-cleanup if enemy is freed without reporting death
		if not enemy.tree_exited.is_connected(_on_tracked_enemy_tree_exited.bind(id)):
			enemy.tree_exited.connect(_on_tracked_enemy_tree_exited.bind(id))

func report_enemy_defeated(enemy: CharacterBody3D = null) -> void:
	if not is_siege_active or _intermission_in_progress:
		return

	if enemy != null:
		var id: int = enemy.get_instance_id()
		if _tracked_enemies.has(id):
			_tracked_enemies.erase(id)

	active_enemies_remaining = maxi(0, active_enemies_remaining - 1)
	enemy_count_updated.emit(active_enemies_remaining, total_enemies_in_wave)

	if active_enemies_remaining == 0:
		_on_wave_cleared()

func _on_tracked_enemy_tree_exited(enemy_id: int) -> void:
	if not is_siege_active:
		return
	if _tracked_enemies.has(enemy_id):
		_tracked_enemies.erase(enemy_id)
		# Decrement if still expecting enemies
		if active_enemies_remaining > _tracked_enemies.size():
			active_enemies_remaining = _tracked_enemies.size()
			enemy_count_updated.emit(active_enemies_remaining, total_enemies_in_wave)
			if active_enemies_remaining == 0:
				_on_wave_cleared()

func _on_wave_cleared() -> void:
	_intermission_in_progress = true
	wave_completed.emit(current_wave)

	if current_wave >= max_waves_for_basin:
		_complete_sector_siege()
		return

	# Intermission breathing room
	if is_inside_tree() and get_tree() != null:
		await get_tree().create_timer(intermission_delay).timeout
	if not is_siege_active:
		return

	_advance_to_next_wave()

func _auto_complete_empty_wave() -> void:
	active_enemies_remaining = 0
	_on_wave_cleared()

func abort_siege(reason: String = "ABORTED") -> void:
	if not is_siege_active:
		return

	is_siege_active = false
	_intermission_in_progress = false

	# Clean up remaining tracked enemies
	for enemy in _tracked_enemies.values():
		if is_instance_valid(enemy):
			enemy.queue_free()
	_tracked_enemies.clear()

	siege_failed.emit(current_target_basin, reason)
	telemetry_updated.emit("SECTOR STATUS: CONTESTED · SIEGE ABORTED")

	if is_inside_tree() and get_tree() != null:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("show_notification"):
			hud.show_notification("BEACON SIGNAL SEVERED · SECTOR CONTESTED")

func _complete_sector_siege() -> void:
	is_siege_active = false
	_intermission_in_progress = false
	_tracked_enemies.clear()

	# 1. Persist territorial unlock
	if is_inside_tree():
		var save_mgr = get_node_or_null("/root/WorldSaveData")
		if save_mgr != null and save_mgr.has_method("mark_sector_cleared"):
			save_mgr.mark_sector_cleared(current_target_basin)
			save_mgr.mark_beacon_activated("beacon_" + current_target_basin)

	# 2. Emit completion
	siege_completed.emit(current_target_basin)
	telemetry_updated.emit("SECTOR STATUS: SECURED · CORRIDOR OPENED")

	# 3. HUD celebratory notification
	if is_inside_tree() and get_tree() != null:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("show_notification"):
			hud.show_notification("SECTOR LIBERATED: TRANSIT CORRIDOR TO DARK TOWER OPENED")

func _resolve_stalemate_target() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	# Alert player or ping the location of the final lingering hostile
	for enemy in _tracked_enemies.values():
		if is_instance_valid(enemy) and enemy is CharacterBody3D:
			var player = get_tree().get_first_node_in_group("player")
			if player != null and enemy.has_method("force_chase_target"):
				enemy.force_chase_target(player)
			break
