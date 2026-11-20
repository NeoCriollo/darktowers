class_name LootCrateManager
extends Node3D

const SupplyCrate3D = preload("res://world/supply_crate.gd")

## Manages dynamic supply crates across Mid-World:
## - Spawns tiered caches near POIs (Caravans, Highway Overpasses, Outposts, Waystations)
## - Handles automatic Ka-cycle refills and dust storm (Haboob) resupply triggers
## - Exposes crate coordinates to TacticalRadar2D for real-time radar pinging

@export var standard_crates_count: int = 8
@export var positronics_crates_count: int = 4

var _spawned_crates: Array[SupplyCrate3D] = []

func _ready() -> void:
	call_deferred("_populate_supply_caches")

func _populate_supply_caches() -> void:
	var crate_script = load("res://world/supply_crate.gd")
	if crate_script == null:
		return

	# Hand-crafted tactical cache sites aligned with regional basins & POIs
	var standard_locations: Array[Vector2] = [
		Vector2(-1015.0, -815.0), # Node 0 Way-Bunker Armory
		Vector2(-540.0, -890.0),  # Southwest Desolation Outpost
		Vector2(-140.0, -540.0),  # Dead-Creek Salt Flats Dry Wash
		Vector2(-20.0, 35.0),     # Caliche Cradle Nexus Depot
		Vector2(-640.0, 45.0),    # Rust-Gorge Defile Chokepoint
		Vector2(-655.0, 18.0),    # Overpass Rubble Cache
		Vector2(10.0, 640.0),     # Bleached Alkali Flat Cache
		Vector2(640.0, 60.0),     # Great Shifting Erg Dune Cache
		Vector2(635.0, 645.0)     # Threshold of the Dark Tower Sentinel Cache
	]

	var positronics_locations: Array[Vector2] = [
		Vector2(-48.0, -88.0),   # Near Freestanding Doorway
		Vector2(88.0, -36.0),    # At NCP Facility 19 Subterranean Hatch
		Vector2(675.0, -15.0),   # Monolithic Pillar Ruins Vault
		Vector2(685.0, 685.0)    # Threshold Spire Vault
	]

	# Spawn Standard Footlockers
	for i in range(standard_locations.size()):
		var loc: Vector2 = standard_locations[i]
		var crate: SupplyCrate3D = crate_script.new()
		crate.name = "StandardSupplyCrate_%d" % i
		crate.tier = SupplyCrate3D.CrateTier.STANDARD_FOOTLOCKER
		var y := TerrainCollisionGenerator.sample_height(loc.x, loc.y)
		crate.position = Vector3(loc.x, y, loc.y)
		crate.rotation.y = randf_range(0.0, TAU)
		add_child(crate)
		_spawned_crates.append(crate)

	# Spawn Rare Positronics Reliquaries
	for i in range(positronics_locations.size()):
		var loc: Vector2 = positronics_locations[i]
		var crate: SupplyCrate3D = crate_script.new()
		crate.name = "PositronicsReliquary_%d" % i
		crate.tier = SupplyCrate3D.CrateTier.POSITRONICS_RELIQUARY
		var y := TerrainCollisionGenerator.sample_height(loc.x, loc.y)
		crate.position = Vector3(loc.x, y, loc.y)
		crate.rotation.y = randf_range(0.0, TAU)
		add_child(crate)
		_spawned_crates.append(crate)

## Weather event trigger: Shifting sands of the Severe Haboob uncover and refill caches
func on_severe_haboob_occurred() -> void:
	for crate in _spawned_crates:
		if is_instance_valid(crate) and crate.current_state == SupplyCrate3D.CrateState.DEPLETED:
			crate.refill_crate()

## Returns positions and states of crates for TacticalRadar2D blip drawing
func get_radar_crate_blips() -> Array[Dictionary]:
	var blips: Array[Dictionary] = []
	for crate in _spawned_crates:
		if is_instance_valid(crate):
			blips.append({
				"pos": Vector2(crate.global_position.x, crate.global_position.z),
				"ready": (crate.current_state == SupplyCrate3D.CrateState.READY),
				"is_rare": (crate.tier == SupplyCrate3D.CrateTier.POSITRONICS_RELIQUARY)
			})
	return blips

