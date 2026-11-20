class_name BasinSpawner
extends Node3D

## Tactical Basin Perimeter Spawner — "Dark Towers: The Path of Ka"
##
## Deploys incoming raiders and mutant fauna along basin choke points:
## - Snaps coordinates to NavigationServer3D & TerrainCollisionGenerator
## - Staggers spawn cadence across small time slices to prevent frame drops
## - Registers spawned units directly into WastelandSiegeManager
## - Applies tactical elite modifiers on late-tier waves (Waves 4+)

@export_group("Basin & Spatial Targeting")
@export var basin_id: String = ""
@export var spawn_radius: float = 38.0
@export var min_spawn_distance_from_player: float = 18.0
@export var spawn_cadence_delay: float = 0.35

@export_group("Enemy Configuration")
@export var enemy_scene: PackedScene = preload("res://scenes/enemy_base.tscn")

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if not is_in_group("basin_spawners"):
		add_to_group("basin_spawners")
	_rng.randomize()

func spawn_raider_wave(total_count: int, wave_intensity: int) -> void:
	if enemy_scene == null or total_count <= 0:
		return

	# Run asynchronous staggered spawn loop
	_spawn_wave_staggered(total_count, wave_intensity)

func _spawn_wave_staggered(total_count: int, wave_intensity: int) -> void:
	var player = get_tree().get_first_node_in_group("player") as Node3D
	var parent_container = _resolve_spawn_container()

	for i in range(total_count):
		# Break loop if siege was aborted while spawning
		var siege_mgr = get_node_or_null("/root/WastelandSiegeManager")
		if siege_mgr != null and not siege_mgr.is_siege_active:
			break

		var spawn_pos: Vector3 = _calculate_valid_spawn_point(player)

		var enemy_instance = enemy_scene.instantiate() as CharacterBody3D
		if enemy_instance != null:
			enemy_instance.position = spawn_pos
			parent_container.add_child(enemy_instance)

			# Register as siege unit immediately
			enemy_instance.set_meta("is_siege_unit", true)
			if siege_mgr != null and siege_mgr.has_method("register_siege_enemy"):
				siege_mgr.register_siege_enemy(enemy_instance)

			# Scale attributes based on wave intensity
			if wave_intensity >= 4 and enemy_instance.has_method("apply_elite_modifier"):
				enemy_instance.apply_elite_modifier(wave_intensity)

			# Direct enemy towards player
			if player != null and enemy_instance.has_method("force_chase_target"):
				enemy_instance.force_chase_target(player)

		# Stagger every 2-3 units to prevent CPU/GPU hitches
		if i < total_count - 1 and spawn_cadence_delay > 0.0:
			if (i + 1) % 2 == 0:
				await get_tree().create_timer(spawn_cadence_delay).timeout

func _calculate_valid_spawn_point(player_node: Node3D) -> Vector3:
	var center: Vector3 = global_position
	if player_node != null:
		center = player_node.global_position

	var angle: float = _rng.randf_range(0.0, TAU)
	var dist: float = _rng.randf_range(min_spawn_distance_from_player, spawn_radius)

	var spawn_pos := Vector3(
		center.x + cos(angle) * dist,
		center.y,
		center.z + sin(angle) * dist
	)

	# 1. Sample terrain height formula from TerrainCollisionGenerator
	spawn_pos.y = TerrainCollisionGenerator.sample_height(spawn_pos.x, spawn_pos.z) + 0.5

	# 2. Snap to valid Navigation Mesh if available
	if is_inside_tree():
		var world_3d = get_world_3d()
		if world_3d != null:
			var nav_map = world_3d.navigation_map
			if nav_map.is_valid():
				var closest_nav_point = NavigationServer3D.map_get_closest_point(nav_map, spawn_pos)
				# Only snap if within reasonable distance (avoids snapping to an unintended ledge)
				if spawn_pos.distance_to(closest_nav_point) < 8.0:
					spawn_pos = closest_nav_point

	return spawn_pos

func _resolve_spawn_container() -> Node:
	var enemies_root = get_tree().get_first_node_in_group("enemies_container")
	if enemies_root != null:
		return enemies_root
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_parent() if get_parent() != null else self

