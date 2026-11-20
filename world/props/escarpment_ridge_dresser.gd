class_name EscarpmentRidgeDresser
extends RefCounted

## Escarpment Ridge Dresser (Option C)
## Places procedural/GLB sheer yardang cliffs and monolithic rock fins along
## both flanks of the 5 Escarpment Barrier Chains, sunk 4m into the terrain,
## skipping canyon defile passes (d_pass < 36m) to prevent player slope-climbing.
## Along Chain 1 and Chain 2, pulls photogrammetry rock meshes from RockPackLibrary.
## Registers every dressed static body to WorldCullingAndBounds.CullUnit.

const YARDANG_GLB_PATHS: Array[String] = [
	"res://assets/environment/terrain_geomorphology/yardangs_spires/yardang_cluster.glb",
	"res://assets/models/yardang_cluster.glb"
]

const CHAIN12_ROCKS: Array[String] = ["Rock5a (37K)", "Rock5c (23K)", "Rock1 (38K)"]

const SAMPLE_STEP: float = 28.0
const MIN_LATERAL_OFFSET: float = 22.0
const MAX_LATERAL_OFFSET: float = 48.0
const PASS_CLEARANCE_RADIUS: float = 36.0
const SANCTUARY_CLEARANCE_RADIUS: float = 56.0
const SINK_DEPTH: float = 4.0
const MIN_SCALE: float = 1.4
const MAX_SCALE: float = 2.6

var scatter: PropScatter
var rock_library: RockPackLibrary = null
var _cached_glb_scene: PackedScene = null
var _bubbles_dict: Dictionary = {}
var spawned_units: Array[WorldCullingAndBounds.CullUnit] = []

func _init(p_scatter: PropScatter = null, p_library: RockPackLibrary = null) -> void:
	scatter = p_scatter
	if p_library != null:
		rock_library = p_library
	else:
		rock_library = RockPackLibrary.new()
	_init_bubbles()
	_try_load_glb()

func _init_bubbles() -> void:
	var passes_dummy: Array = []
	WorldCullingAndBounds.build_topological_graph(_bubbles_dict, passes_dummy)

func _try_load_glb() -> void:
	for path in YARDANG_GLB_PATHS:
		if ResourceLoader.exists(path):
			_cached_glb_scene = load(path) as PackedScene
			if _cached_glb_scene != null:
				break

func dress_escarpment_ridges(parent_node: Node3D = null) -> int:
	var target_parent: Node3D = parent_node
	if target_parent == null and scatter != null:
		target_parent = scatter

	var group := Node3D.new()
	group.name = "Vignettes_Escarpment_Ridges"
	if target_parent != null:
		target_parent.add_child(group)

	var total_spawned := 0
	var seg_index := 0

	for seg in TerrainCollisionGenerator.BARRIER_SEGMENTS:
		seg_index += 1
		var is_chain_1_or_2: bool = (seg_index <= 4)
		var a := Vector2(float(seg[0]), float(seg[1]))
		var b := Vector2(float(seg[2]), float(seg[3]))
		var diff := b - a
		var len_seg := diff.length()
		if len_seg < 1.0:
			continue

		var dir := diff / len_seg
		var norm := Vector2(-dir.y, dir.x)
		var steps := int(len_seg / SAMPLE_STEP)

		for s in range(1, steps + 1):
			var center_pt := a + dir * (float(s) * SAMPLE_STEP)

			for flank in [-1.0, 1.0]:
				var flank_f := float(flank)
				var seed_val := float(seg_index * 1000 + s * 10 + (1 if flank_f > 0.0 else 2))
				var rng_val := fposmod(sin(seed_val * 12.9898) * 43758.5453, 1.0)
				var lat_offset := lerpf(MIN_LATERAL_OFFSET, MAX_LATERAL_OFFSET, rng_val)
				var sample_pos: Vector2 = center_pt + norm * (flank_f * lat_offset)

				# Skip inner horseshoe flank and sanctuary spawn clearance zone
				if seg_index <= 2 and flank_f > 0.0:
					continue
				if sample_pos.distance_to(Vector2(-1180.0, -1180.0)) < SANCTUARY_CLEARANCE_RADIUS or sample_pos.distance_to(Vector2(-1156.0, -1156.0)) < SANCTUARY_CLEARANCE_RADIUS:
					continue

				# Skip if inside active canyon defile corridor
				var d_pass := _get_min_defile_distance(sample_pos.x, sample_pos.y)
				if d_pass < PASS_CLEARANCE_RADIUS:
					continue

				var ground_y := TerrainCollisionGenerator.sample_height(sample_pos.x, sample_pos.y)
				var dress_node := _create_ridge_rock_node(sample_pos, ground_y, norm * flank, seed_val, is_chain_1_or_2)
				group.add_child(dress_node)

				var unit := WorldCullingAndBounds.CullUnit.new()
				unit.node = dress_node
				unit.pos = sample_pos
				unit.radius = 24.0 if is_chain_1_or_2 else 16.0
				unit.bubble_id = WorldCullingAndBounds.nearest_bubble_id(sample_pos, _bubbles_dict)
				unit.applied_visible = true
				unit.target_visible = true
				spawned_units.append(unit)

				if scatter != null:
					scatter._placed_xz.append(sample_pos)
					scatter._placed_radii.append(8.0)

				total_spawned += 1

	return total_spawned

func _get_min_defile_distance(px: float, pz: float) -> float:
	var min_d := 99999.0
	for p in TerrainCollisionGenerator.DEFILE_PASSES:
		var d: float = TerrainCollisionGenerator.segment_distance_2d(px, pz, float(p[0]), float(p[1]), float(p[2]), float(p[3]))
		if d < min_d:
			min_d = d
	return min_d

func _create_ridge_rock_node(pos: Vector2, ground_y: float, outward_dir: Vector2, seed_val: float, is_chain_1_or_2: bool = false) -> Node3D:
	var rng_scale := fposmod(sin(seed_val * 45.123) * 23421.631, 1.0)
	var yaw := atan2(outward_dir.x, outward_dir.y) + lerpf(-0.25, 0.25, rng_scale)
	var overhang_pitch := deg_to_rad(lerpf(8.0, 16.0, rng_scale))

	# Pull photogrammetry rocks for Chain 1 & 2
	if is_chain_1_or_2 and rock_library != null:
		var rock_name := CHAIN12_ROCKS[abs(int(seed_val)) % CHAIN12_ROCKS.size()]
		var sc := lerpf(25.0, 45.0, rng_scale)
		var rock_node := rock_library.create_rock_node(rock_name, Vector3(sc, sc * 1.25, sc), true, RockPackLibrary.TIER_BC_VISIBILITY_END)
		var prop_uuid := "EscarpmentRock_%d" % int(seed_val)
		rock_node.name = prop_uuid
		rock_node.set_meta("prop_uuid", prop_uuid)
		rock_node.set_meta("instance_id", prop_uuid)
		rock_node.position = Vector3(pos.x, ground_y - SINK_DEPTH, pos.y)
		rock_node.rotation = Vector3(overhang_pitch, yaw, 0.0)
		return rock_node

	var root := Node3D.new()
	var prop_uuid := "EscarpmentCliff_%d" % int(seed_val)
	root.name = prop_uuid
	root.set_meta("prop_uuid", prop_uuid)
	root.set_meta("instance_id", prop_uuid)
	root.position = Vector3(pos.x, ground_y - SINK_DEPTH, pos.y)
	var sc := lerpf(MIN_SCALE, MAX_SCALE, rng_scale)
	root.scale = Vector3(sc, sc * 1.35, sc)
	root.rotation = Vector3(overhang_pitch, yaw, 0.0)

	if _cached_glb_scene != null:
		var glb_inst := _cached_glb_scene.instantiate() as Node3D
		root.add_child(glb_inst)
		_setup_mesh_colliders(glb_inst)
	else:
		_build_procedural_cliff_fin(root, sc)

	root.set_meta("ballistic_material", "STONE")
	root.set_meta("reactive_target", true)
	return root

func _build_procedural_cliff_fin(parent: Node3D, _scale_factor: float) -> void:
	var mat := PropMeshFactory.make_mat(Color(0.44, 0.35, 0.26), 0.94, 0.08)

	var fin_mesh := PrismMesh.new()
	fin_mesh.size = Vector3(14.0, 22.0, 6.0)
	fin_mesh.material = mat

	var fin_inst := MeshInstance3D.new()
	fin_inst.name = "SheerRockFin"
	fin_inst.mesh = fin_mesh
	fin_inst.position = Vector3(0.0, 10.0, 0.0)
	fin_inst.rotation = Vector3(0.0, 0.0, deg_to_rad(90.0))
	fin_inst.set_meta("ballistic_material", "STONE")
	fin_inst.set_meta("reactive_target", true)
	parent.add_child(fin_inst)

	var talus_mesh := BoxMesh.new()
	talus_mesh.size = Vector3(16.0, 8.0, 10.0)
	talus_mesh.material = mat

	var talus_inst := MeshInstance3D.new()
	talus_inst.name = "TalusBasalSlab"
	talus_inst.mesh = talus_mesh
	talus_inst.position = Vector3(0.0, 3.5, -1.5)
	talus_inst.set_meta("ballistic_material", "STONE")
	talus_inst.set_meta("reactive_target", true)
	parent.add_child(talus_inst)

	var sb := StaticBody3D.new()
	sb.name = "CliffStaticBody"
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta("ballistic_material", "STONE")
	sb.set_meta("reactive_target", true)

	var cs1 := CollisionShape3D.new()
	var box1 := BoxShape3D.new()
	box1.size = Vector3(14.0, 22.0, 7.0)
	cs1.shape = box1
	cs1.position = Vector3(0.0, 10.0, 0.0)
	sb.add_child(cs1)

	var cs2 := CollisionShape3D.new()
	var box2 := BoxShape3D.new()
	box2.size = Vector3(16.0, 8.0, 10.0)
	cs2.shape = box2
	cs2.position = Vector3(0.0, 3.5, -1.5)
	sb.add_child(cs2)

	parent.add_child(sb)

func _setup_mesh_colliders(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.set_meta("ballistic_material", "STONE")
		mi.set_meta("reactive_target", true)
		if mi.mesh != null and mi.get_node_or_null(mi.name + "_col") == null:
			mi.create_trimesh_collision()
			for child in mi.get_children():
				if child is StaticBody3D:
					var sb := child as StaticBody3D
					sb.collision_layer = 1
					sb.collision_mask = 0
					sb.set_meta("ballistic_material", "STONE")
					sb.set_meta("reactive_target", true)
	for child in node.get_children():
		_setup_mesh_colliders(child)
