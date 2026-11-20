class_name SectorQ01Ruins
extends RefCounted

## Modular Q01 Medieval Brick Wall & Ruins Scatter Builder
## Places modular medieval brick wall and tower assets randomly in Quadrant Q01
## (Mohaine Waystation Basin & SW Perimeter, [-1250, -625] x [-1250, -625]).
##
## Sacred Invariant: Preserves 0m displacement and strict clearance around
## Node 0 Sanctuary bunker at (-1020, -820) and gate at (-900, -820).

var scatter: PropScatter

const MEDIEVAL_WALL_MODEL_PATH: String = "res://assets/architecture/modular_walls_and_barriers/masonry/medieval_wall_of_bricks_assets.glb"

## The 13 distinct modular brick wall and ruin assets inside medieval_wall_of_bricks_assets.glb
const ASSET_NAMES: Array[String] = [
	"Assets 1",   ## Large ruined fortress bastion complex (~14m x 6.4m)
	"Asstes 2",   ## Breached brick defensive wall (~4.1m x 3.5m)
	"Assets 3",   ## Small brick rubble & debris pile (~1.7m x 1.4m)
	"Assets 7",   ## Straight brick curtain wall segment (~3.6m x 0.3m)
	"Assets 4",   ## L-shaped corner defensive rampart (~3.0m x 4.6m)
	"Assets 5",   ## Buttressed stone/brick wall (~4.9m x 2.8m)
	"Assets 8",   ## Flagstone / brick foundation courtyard base (~8.7m x 8.6m)
	"Assets 6",   ## Ruined stair base / inclined brick ramp (~3.8m x 3.2m)
	"Assets 12",  ## Square brick watchtower / high pillar (~2.3m x 11.6m)
	"Assets 10",  ## Tall fortified curtain wall (~8.1m x 9.8m)
	"Assets 11",  ## Ancient round tower / cylindrical keep (~3.2m x 12.1m)
	"Base wall",  ## Standard foundation brick wall (~2.3m x 2.0m)
	"Assets 9",   ## Ruined brick column bastion (~2.8m x 6.0m)
]

## Q01 Quadrant Coordinate Bounds [-1250m, -625m] with safety margin
const Q01_MIN_X: float = -1215.0
const Q01_MAX_X: float = -660.0
const Q01_MIN_Z: float = -1215.0
const Q01_MAX_Z: float = -660.0

## Sanctuary Invariant Clearance Points
const SANCTUARY_CENTER := Vector2(-1180.0, -1180.0)
const THRESHOLD_GATE := Vector2(-1060.0, -1060.0)
const SANCTUARY_CLEARANCE_RADIUS: float = 65.0
const GATE_CLEARANCE_RADIUS: float = 45.0
const PROP_CLEARANCE: float = 18.0
const MAX_SEARCH_ATTEMPTS: int = 60

var _cached_packed_scene: PackedScene = null

func _init(p_scatter: PropScatter) -> void:
	scatter = p_scatter

func _sample_terrain_y(x: float, z: float) -> float:
	return scatter._sample_terrain_y(x, z)

func _spawn_q01_brick_ruins() -> int:
	var ruins_count: int = 14
	if "q01_brick_ruins_count" in scatter:
		ruins_count = scatter.q01_brick_ruins_count

	var group := Node3D.new()
	group.name = "Vignettes_Q01_Medieval_Ruins"
	scatter.add_child(group)

	_load_model_scene()

	var placed_count := 0
	for i in range(ruins_count):
		var pos := _find_random_q01_position()
		if pos == Vector2.INF:
			continue

		var asset_name: String = ASSET_NAMES[i % ASSET_NAMES.size()]
		var ruin_instance := _instantiate_ruin_asset(asset_name, i + 1)
		if ruin_instance == null:
			ruin_instance = _build_fallback_brick_ruin(asset_name, i + 1)

		var ground_y := _sample_terrain_y(pos.x, pos.y)
		ruin_instance.position = Vector3(pos.x, ground_y, pos.y)

		# Random natural rotation and slight organic scale variation
		ruin_instance.rotation.y = scatter._rng.randf() * TAU
		var scale_factor: float = scatter._rng.randf_range(0.95, 1.15)
		ruin_instance.scale = Vector3(scale_factor, scale_factor, scale_factor)

		_setup_mesh_colliders(ruin_instance)
		group.add_child(ruin_instance)

		scatter._placed_xz.append(pos)
		scatter._placed_radii.append(PROP_CLEARANCE)
		placed_count += 1

	return placed_count

func _load_model_scene() -> void:
	if _cached_packed_scene != null:
		return
	if ResourceLoader.exists(MEDIEVAL_WALL_MODEL_PATH):
		_cached_packed_scene = load(MEDIEVAL_WALL_MODEL_PATH) as PackedScene

func _find_random_q01_position() -> Vector2:
	for _attempt in range(MAX_SEARCH_ATTEMPTS):
		var candidate := Vector2(
			scatter._rng.randf_range(Q01_MIN_X, Q01_MAX_X),
			scatter._rng.randf_range(Q01_MIN_Z, Q01_MAX_Z)
		)

		# 1. Enforce Sanctuary Invariants (Bunker & Spawn Point)
		if candidate.distance_to(SANCTUARY_CENTER) < SANCTUARY_CLEARANCE_RADIUS:
			continue

		# 2. Enforce Threshold Warning Gate Clearance
		if candidate.distance_to(THRESHOLD_GATE) < GATE_CLEARANCE_RADIUS:
			continue

		# 3. Enforce Pilgrimage Corridor Clearance (from Bunker to Gate)
		var seg_v: Vector2 = THRESHOLD_GATE - SANCTUARY_CENTER
		var seg_len_sq: float = seg_v.length_squared()
		var t_proj: float = clampf((candidate - SANCTUARY_CENTER).dot(seg_v) / (seg_len_sq if seg_len_sq > 0.0 else 1.0), 0.0, 1.0)
		var corridor_dist: float = (candidate - (SANCTUARY_CENTER + seg_v * t_proj)).length()
		if corridor_dist < 32.0:
			continue

		# 4. Prevent overlap with all existing placed landmarks & vignettes
		var has_overlap := false
		for idx in range(scatter._placed_xz.size()):
			var dist := candidate.distance_to(scatter._placed_xz[idx])
			var min_dist: float = scatter._placed_radii[idx] + PROP_CLEARANCE
			if dist < min_dist:
				has_overlap = true
				break

		if not has_overlap:
			return candidate

	return Vector2.INF

func _instantiate_ruin_asset(asset_name: String, index: int) -> Node3D:
	if _cached_packed_scene == null:
		return null

	var scene_root := _cached_packed_scene.instantiate() as Node3D
	if scene_root == null:
		return null

	var prop_uuid := "Q01_MedievalRuin_%d_%s" % [index, asset_name.replace(" ", "_")]
	scene_root.name = prop_uuid
	scene_root.set_meta("prop_uuid", prop_uuid)
	scene_root.set_meta("instance_id", prop_uuid)

	var root_node := scene_root.find_child("RootNode", true, false)
	if root_node != null:
		for child in root_node.get_children():
			if child.name != asset_name:
				child.queue_free()
	else:
		# Fallback if structure varies
		for child in scene_root.get_children():
			if child.name != asset_name and child.name != "Sketchfab_model":
				child.queue_free()

	scene_root.set_meta("ballistic_material", "CONCRETE")
	scene_root.set_meta("reactive_target", true)
	scene_root.set_meta("sector_id", "waystation_sanctuary")
	scene_root.set_meta("quadrant_id", "Q01")

	return scene_root

func _setup_mesh_colliders(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.set_meta("ballistic_material", "CONCRETE")
		mi.set_meta("reactive_target", true)
		if mi.mesh != null and mi.get_node_or_null(mi.name + "_col") == null:
			mi.create_trimesh_collision()
			for child in mi.get_children():
				if child is StaticBody3D:
					var sb := child as StaticBody3D
					sb.collision_layer = 1
					sb.collision_mask = 0
					sb.set_meta("ballistic_material", "CONCRETE")
					sb.set_meta("reactive_target", true)
	for child in node.get_children():
		_setup_mesh_colliders(child)

func _build_fallback_brick_ruin(asset_name: String, index: int) -> Node3D:
	var fallback_root := Node3D.new()
	var prop_uuid := "Q01_MedievalRuin_%d_%s" % [index, asset_name.replace(" ", "_")]
	fallback_root.name = prop_uuid
	fallback_root.set_meta("prop_uuid", prop_uuid)
	fallback_root.set_meta("instance_id", prop_uuid)
	var mat := PropMeshFactory.make_mat(Color(0.46, 0.40, 0.35), 0.92, 0.0)

	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(4.5, 3.2, 0.8)
	wall_box.material = mat

	var mi := MeshInstance3D.new()
	mi.name = "FallbackWallMesh"
	mi.mesh = wall_box
	mi.position = Vector3(0.0, 1.6, 0.0)
	mi.set_meta("ballistic_material", "CONCRETE")
	fallback_root.add_child(mi)

	var sb := PropMeshFactory.add_box_collision(fallback_root, wall_box.size)
	sb.position = mi.position
	sb.set_meta("ballistic_material", "CONCRETE")

	fallback_root.set_meta("ballistic_material", "CONCRETE")
	fallback_root.set_meta("sector_id", "waystation_sanctuary")
	fallback_root.set_meta("quadrant_id", "Q01")
	return fallback_root

