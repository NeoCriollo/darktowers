class_name WorldSectorSync
extends RefCounted

## World Sector Environment, Biome Hazard & Atmospheric Simulation Sub-Controller.
## Dynamically blends local sector atmosphere, calculates concentric threat scaling
## towards the Dark Tower, simulates weapon grit exposure, and resolves safe respawn points.

var world: World = null

var sw_desolation_blend_weight: float = 0.0
var south_salt_blend_weight: float = 0.0
var cradle_blend_weight: float = 0.0
var west_gorge_blend_weight: float = 0.0
var north_alkali_blend_weight: float = 0.0
var east_dunes_blend_weight: float = 0.0
var tower_threshold_blend_weight: float = 0.0

const SAFE_RESPAWN_BASINS: Array[Dictionary] = [
	{"name": "The Mohaine Way-Bunker", "coord": Vector2(-1018.0, -820.0)},
	{"name": "Southwest Desolation", "coord": Vector2(-550.0, -900.0)},
	{"name": "Dead-Creek Salt Flats", "coord": Vector2(-150.0, -550.0)},
	{"name": "Caliche Cradle Nexus", "coord": Vector2(0.0, 0.0)},
	{"name": "Rust-Gorge Defile", "coord": Vector2(-650.0, 50.0)},
	{"name": "Bleached Alkali Sink", "coord": Vector2(0.0, 650.0)},
	{"name": "The Great Shifting Erg", "coord": Vector2(650.0, 50.0)},
	{"name": "Threshold of the Dark Tower", "coord": Vector2(650.0, 650.0)}
]

func _init(p_world: World = null) -> void:
	world = p_world

# ─── Sector Environment Blending ─────────────────────────────────────────────

func sync_sector_environment(delta: float) -> void:
	if world.player == null or world.environment_node == null: return
	if world.environment_node.get("is_sunny_day"): return

	var px: float = world.player.global_position.x
	var pz: float = world.player.global_position.z

	var in_sw := (px >= -800.0 and px <= -400.0 and pz >= -1000.0 and pz <= -600.0) or (Vector2(px - (-550.0), pz - (-900.0)).length() <= 250.0)
	var in_salt := (px >= -400.0 and px <= 0.0 and pz >= -800.0 and pz <= -300.0) or (Vector2(px - (-150.0), pz - (-550.0)).length() <= 250.0)
	var in_cradle := (px >= -200.0 and px <= 200.0 and pz >= -200.0 and pz <= 200.0) or (Vector2(px, pz).length() <= 250.0)
	var in_gorge := (px >= -800.0 and px <= -400.0 and pz >= -100.0 and pz <= 400.0) or (Vector2(px - (-650.0), pz - 50.0).length() <= 250.0)
	var in_alkali := (px >= -300.0 and px <= 300.0 and pz >= 400.0 and pz <= 900.0) or (Vector2(px, pz - 650.0).length() <= 250.0)
	var in_east := (px >= 400.0 and px <= 900.0 and pz >= -300.0 and pz <= 300.0) or (Vector2(px - 650.0, pz - 50.0).length() <= 250.0)
	var in_tower := (px >= 400.0 and px <= 900.0 and pz >= 400.0 and pz <= 900.0) or (Vector2(px - 700.0, pz - 700.0).length() <= 250.0)

	sw_desolation_blend_weight = move_toward(sw_desolation_blend_weight, 1.0 if in_sw else 0.0, delta * 0.75)
	south_salt_blend_weight = move_toward(south_salt_blend_weight, 1.0 if in_salt else 0.0, delta * 0.75)
	cradle_blend_weight = move_toward(cradle_blend_weight, 1.0 if in_cradle else 0.0, delta * 0.75)
	west_gorge_blend_weight = move_toward(west_gorge_blend_weight, 1.0 if in_gorge else 0.0, delta * 0.75)
	north_alkali_blend_weight = move_toward(north_alkali_blend_weight, 1.0 if in_alkali else 0.0, delta * 0.75)
	east_dunes_blend_weight = move_toward(east_dunes_blend_weight, 1.0 if in_east else 0.0, delta * 0.75)
	tower_threshold_blend_weight = move_toward(tower_threshold_blend_weight, 1.0 if in_tower else 0.0, delta * 0.75)

	if tower_threshold_blend_weight > 0.001:
		world.environment_node.set_sector_environment_override("tower_threshold", tower_threshold_blend_weight)
		_dispatch_player_hazards(0.0, 0.0, 0.0, 1.2)
		var d_spire := Vector2(px - 700.0, pz - 700.0).length()
		var tower_strain := clampf((220.0 - d_spire) / 220.0, 0.0, 1.0) if d_spire <= 220.0 else 0.0
		if world.player.has_method("apply_tower_nexus_strain"):
			world.player.call("apply_tower_nexus_strain", tower_strain * tower_threshold_blend_weight)
	elif east_dunes_blend_weight > 0.001:
		world.environment_node.set_sector_environment_override("east_dunes", east_dunes_blend_weight)
		_dispatch_player_hazards(0.0, 0.0, 0.0, lerpf(1.0, 1.6, east_dunes_blend_weight), 0.0)
	elif north_alkali_blend_weight > 0.001:
		world.environment_node.set_sector_environment_override("north_alkali", north_alkali_blend_weight)
		_dispatch_player_hazards(0.0, 0.0, 0.0, 1.0, 0.0)
		var d_beacon := Vector2(px - 45.0, pz - 680.0).length()
		var beacon_resonance := clampf((120.0 - d_beacon) / 120.0, 0.0, 1.0) if d_beacon <= 120.0 else 0.0
		if world.player.has_method("apply_ka_resonance"):
			world.player.call("apply_ka_resonance", beacon_resonance * north_alkali_blend_weight)
	elif west_gorge_blend_weight > 0.001:
		world.environment_node.set_sector_environment_override("west_gorge", west_gorge_blend_weight)
		_dispatch_player_hazards(0.0, 0.0, 0.0, 1.0, 0.0)
	elif cradle_blend_weight > 0.001:
		world.environment_node.set_sector_environment_override("cradle", cradle_blend_weight)
		_dispatch_player_hazards(0.0, 0.0, 0.0, 1.0, 0.0)
		var d_abyss := Vector2(px - 325.0, pz - 325.0).length()
		var d_overlook := Vector2(px - 140.0, pz - 140.0).length()
		var overlook_factor := clampf((60.0 - d_overlook) / 60.0 * 0.35, 0.0, 0.35) if d_overlook <= 60.0 else 0.0
		var abyss_factor := clampf((265.0 - d_abyss) / 110.0, 0.0, 1.0) if d_abyss <= 265.0 else 0.0
		var thinny_distort := maxf(overlook_factor, abyss_factor)
		if world.player.has_method("apply_thinny_distortion"):
			world.player.call("apply_thinny_distortion", thinny_distort * cradle_blend_weight)
	elif south_salt_blend_weight > 0.001:
		world.environment_node.set_sector_environment_override("south_salt", south_salt_blend_weight)
		_dispatch_player_hazards(south_salt_blend_weight * 0.45, 0.0, 0.0, 1.0, 0.0)
	elif sw_desolation_blend_weight > 0.001:
		world.environment_node.set_sector_environment_override("sw_desolation", sw_desolation_blend_weight)
		_dispatch_player_hazards(0.0, 0.0, 0.0, 1.0, 0.0)
	elif world.environment_node.active_sector_id in ["sw_desolation", "south_salt", "cradle", "west_gorge", "north_alkali", "east_dunes", "tower_threshold", "monolith_pass"]:
		world.environment_node.set_sector_environment_override("", 0.0)
		_dispatch_player_hazards(0.0, 0.0, 0.0, 1.0, 0.0)

func _dispatch_player_hazards(glare: float, thinny: float, ka: float, stamina_mult: float, tower_strain: float = -1.0) -> void:
	if world.player.has_method("apply_glare_penalty"): world.player.call("apply_glare_penalty", glare)
	if world.player.has_method("apply_thinny_distortion"): world.player.call("apply_thinny_distortion", thinny)
	if world.player.has_method("apply_ka_resonance"): world.player.call("apply_ka_resonance", ka)
	if world.player.has_method("apply_stamina_drain_multiplier"): world.player.call("apply_stamina_drain_multiplier", stamina_mult)
	if tower_strain >= 0.0 and world.player.has_method("apply_tower_nexus_strain"):
		world.player.call("apply_tower_nexus_strain", tower_strain)

# ─── Environmental Grit & Threat Gate Simulation ─────────────────────────────

func process_environmental_grit_exposure(delta: float) -> void:
	if world._cached_weapon_system == null or world.environment_node == null: return

	var active_p: int = world.environment_node.active_preset
	var density: float = World.GRIT_DENSITIES.get(active_p, 4.0)

	var wind_scale := 1.0
	if world.environment_node.has_method("get_current_wind_velocity"):
		wind_scale = clampf(world.environment_node.get_current_wind_velocity() / 5.0, 0.1, 4.0)

	if world.environment_node.has_method("get_current_wind_vector") and "ambient_wind_vector" in world._cached_weapon_system:
		world._cached_weapon_system.set("ambient_wind_vector", world.environment_node.get_current_wind_vector())

	if world._cached_weapon_system.has_method("expose_to_ambient_grit"):
		var wm: WorldManager = world.get_node_or_null("WorldManager") as WorldManager
		var is_in_safe_bunker := false
		var waystation := world.get_node_or_null("WaystationSanctuary") as WaystationSanctuary
		if waystation != null and waystation.is_player_sheltered:
			is_in_safe_bunker = true
		elif wm != null and wm.has_method("is_player_in_safe_zone"):
			is_in_safe_bunker = wm.is_player_in_safe_zone()
		elif world.player != null:
			is_in_safe_bunker = Vector2(world.player.global_position.x, world.player.global_position.z).distance_to(Vector2(-1000.0, -800.0)) <= 150.0

		var tower_pos := Vector2(700.0, 700.0)
		var p_pos := Vector2(world.player.global_position.x, world.player.global_position.z) if world.player != null else Vector2.ZERO
		var dist_tower := p_pos.distance_to(tower_pos)

		var proximity_scale := 1.0 + pow(maxf(0.0, (1000.0 - dist_tower) / 200.0), 2.0)
		var net_density: float = 0.0 if is_in_safe_bunker else (density * proximity_scale)

		if "gunslinger_progression" in world.player and world.player.gunslinger_progression != null:
			var seal_tier: int = world.player.gunslinger_progression.cylinder_crane_seal_tier
			net_density *= maxf(0.1, 1.0 - (float(seal_tier) * 0.30))

		var sector_silica_multiplier := 1.0
		if west_gorge_blend_weight > 0.001:
			if world.environment_node.has_method("get_sector_iron_oxide_multiplier"):
				sector_silica_multiplier = world.environment_node.get_sector_iron_oxide_multiplier("west_gorge")
			else: sector_silica_multiplier = lerpf(1.0, 1.8, west_gorge_blend_weight)
		elif south_salt_blend_weight > 0.001:
			sector_silica_multiplier = lerpf(1.0, 0.5, south_salt_blend_weight)
		elif sw_desolation_blend_weight > 0.001:
			if world.environment_node.has_method("get_sector_silica_multiplier"):
				sector_silica_multiplier = world.environment_node.get_sector_silica_multiplier("sw_desolation")
			else: sector_silica_multiplier = lerpf(1.0, 2.5, sw_desolation_blend_weight)

		world._cached_weapon_system.call("expose_to_ambient_grit", delta * world.dust_exposure_multiplier * wind_scale * sector_silica_multiplier, net_density)

		if world._cached_weapon_system.has_method("expose_to_salt_corrosion") and not is_in_safe_bunker and south_salt_blend_weight > 0.001:
			var corrosion_mult := 1.0
			if world.environment_node.has_method("get_sector_corrosion_multiplier"):
				corrosion_mult = world.environment_node.get_sector_corrosion_multiplier("south_salt")
			else:
				corrosion_mult = lerpf(1.0, 2.5, south_salt_blend_weight)
			world._cached_weapon_system.call("expose_to_salt_corrosion", delta, corrosion_mult)

		if dist_tower < 500.0 and world.player != null:
			var psychic_strain := clampf((500.0 - dist_tower) / 350.0, 0.0, 1.0)
			if "gunslinger_progression" in world.player and world.player.gunslinger_progression != null:
				psychic_strain *= (1.0 - world.player.gunslinger_progression.todash_damping)
			if world.player.has_method("apply_anomaly_sway"):
				world.player.call("apply_anomaly_sway", psychic_strain)

	if world.hud != null and world.hud.has_method("set_grit_fouling") and "grit_index" in world._cached_weapon_system and "fouling_index" in world._cached_weapon_system:
		world.hud.call("set_grit_fouling", float(world._cached_weapon_system.grit_index), float(world._cached_weapon_system.fouling_index))

# ─── Particle Volume & Telemetry ─────────────────────────────────────────────

func sync_particle_volume_to_player() -> void:
	if world.player == null or world.environment_node == null or world.environment_node.particles_root == null: return
	var waystation := world.get_node_or_null("WaystationSanctuary") as WaystationSanctuary
	world.environment_node.particles_root.visible = not (waystation != null and waystation.is_player_sheltered)
	var p_pos := world.player.global_position
	world.environment_node.particles_root.global_position = Vector3(p_pos.x, p_pos.y + 4.0, p_pos.z)

func sync_map_telemetry() -> void:
	if world.player == null or world.hud == null: return
	if world.hud.has_method("update_map_player_telemetry"):
		var yaw: float = world.player.rotation.y
		var arm := world.player.get_node_or_null("SpringArm3D") as Node3D
		if arm != null: yaw = arm.rotation.y
		world.hud.call("update_map_player_telemetry", world.player.global_position, yaw)

# ─── Safe Respawn Point Resolution ───────────────────────────────────────────

func resolve_safe_respawn_point(death_position: Vector3) -> Dictionary:
	var best_name: String = "The Mohaine Way-Bunker"
	var best_coord: Vector2 = WorldBootstrapBuilder.INITIAL_PLAYER_SPAWN_XZ + WorldBootstrapBuilder.BUNKER_SPAWN_OFFSET
	var best_dist_sq: float = INF

	var death_xz := Vector2(death_position.x, death_position.z)
	for basin in SAFE_RESPAWN_BASINS:
		var pt: Vector2 = basin["coord"]
		var d2: float = death_xz.distance_squared_to(pt)
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best_name = String(basin["name"])
			best_coord = pt

	var ground_y: float = TerrainCollisionGenerator.sample_height(best_coord.x, best_coord.y)
	var spawn_y_offset: float = 0.05 if best_coord.distance_to(WorldBootstrapBuilder.INITIAL_PLAYER_SPAWN_XZ + WorldBootstrapBuilder.BUNKER_SPAWN_OFFSET) < 1.0 else 1.0
	return {
		"position": Vector3(best_coord.x, ground_y + spawn_y_offset, best_coord.y),
		"name": best_name
	}
