class_name RockPackLibrary
extends RefCounted

## RockPackLibrary: Photogrammetry Rock Pack (.glb) Extractor & Resource Cache
## Extracts and manages the 7 photogrammetry rock meshes and PBR materials
## from THREE.GLTFExporter r183, categorized into Tier A, B, and C with
## analytic BoxShape3D bounding colliders and Mid-World desert albedo tinting.

const GLB_PATHS: Array[String] = [
	"res://assets/environment/geology_and_rocks/megascan_formations/rock_formation.glb",
	"res://assets/rock_formation.glb",
	"res://assets/models/rock_formation.glb"
]

const TIER_A_ROCKS: Array[String] = ["Rock3 (5K)", "Rock5b (11K)"]
const TIER_B_ROCKS: Array[String] = ["Rock5c (23K)", "Rock5a (37K)"]
const TIER_C_ROCKS: Array[String] = ["Rock1 (38K)", "Rock2 (41K)", "Rock4 (60K)"]

const DESERT_TINT: Color = Color(0.88, 0.80, 0.72, 1.0)
const TIER_A_VISIBILITY_END: float = 350.0
const TIER_BC_VISIBILITY_END: float = 900.0

# Exact raw GLTF accessor extents in normalized unit space [-0.5, 0.5]
const ROCK_EXTENTS: Dictionary = {
	"Rock3 (5K)": {
		"min": Vector3(-0.500013, -0.241794, -0.313261),
		"max": Vector3(0.500013, 0.241792, 0.313260),
		"tier": "TierA"
	},
	"Rock1 (38K)": {
		"min": Vector3(-0.478779, -0.212692, -0.500028),
		"max": Vector3(0.478779, 0.212692, 0.500028),
		"tier": "TierC"
	},
	"Rock2 (41K)": {
		"min": Vector3(-0.500003, -0.215991, -0.360493),
		"max": Vector3(0.500003, 0.215991, 0.360493),
		"tier": "TierC"
	},
	"Rock4 (60K)": {
		"min": Vector3(-0.351002, -0.499981, -0.219056),
		"max": Vector3(0.351002, 0.499981, 0.219056),
		"tier": "TierC"
	},
	"Rock5a (37K)": {
		"min": Vector3(-0.500095, -0.455214, -0.274273),
		"max": Vector3(0.500095, 0.455214, 0.274273),
		"tier": "TierB"
	},
	"Rock5c (23K)": {
		"min": Vector3(-0.434741, -0.500020, -0.279218),
		"max": Vector3(0.434741, 0.500020, 0.279218),
		"tier": "TierB"
	},
	"Rock5b (11K)": {
		"min": Vector3(-0.378313, -0.127112, -0.500018),
		"max": Vector3(0.378313, 0.127112, 0.500018),
		"tier": "TierA"
	}
}

var _cached_meshes: Dictionary = {}
var _cached_materials: Dictionary = {}
var _is_loaded: bool = false
var _use_fallback: bool = false

func _init() -> void:
	load_library()

func load_library() -> bool:
	if _is_loaded:
		return true

	var loaded_scene: PackedScene = null
	for path in GLB_PATHS:
		if ResourceLoader.exists(path):
			loaded_scene = load(path) as PackedScene
			if loaded_scene != null:
				break

	if loaded_scene != null:
		_extract_from_glb(loaded_scene)
		_use_fallback = false
	else:
		_build_fallback_primitives()
		_use_fallback = true

	_is_loaded = true
	return true

func _extract_from_glb(scene: PackedScene) -> void:
	var inst := scene.instantiate()
	for child in inst.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var rock_name := mi.name
			if mi.mesh != null:
				_cached_meshes[rock_name] = mi.mesh
				var mat: Material = mi.get_surface_override_material(0)
				if mat == null:
					mat = mi.mesh.surface_get_material(0)
				if mat != null:
					var tinted: StandardMaterial3D = null
					if mat is StandardMaterial3D:
						tinted = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					elif mat is BaseMaterial3D:
						tinted = StandardMaterial3D.new()
						var base_mat := mat as BaseMaterial3D
						tinted.albedo_texture = base_mat.albedo_texture
						tinted.normal_enabled = base_mat.normal_enabled
						tinted.normal_texture = base_mat.normal_texture
					else:
						tinted = StandardMaterial3D.new()

					if tinted != null:
						tinted.albedo_color = DESERT_TINT * tinted.albedo_color
						tinted.roughness = 0.95
						tinted.metallic = 0.0
						_cached_materials[rock_name] = tinted
	inst.free()

func _build_fallback_primitives() -> void:
	var fallback_mat := StandardMaterial3D.new()
	fallback_mat.albedo_color = Color(0.48, 0.38, 0.28)
	fallback_mat.roughness = 0.95
	fallback_mat.metallic = 0.0

	for rock_name in ROCK_EXTENTS:
		var ext: Dictionary = ROCK_EXTENTS[rock_name]
		var mn: Vector3 = ext["min"]
		var mx: Vector3 = ext["max"]
		var sz := mx - mn

		var box := BoxMesh.new()
		box.size = sz
		box.material = fallback_mat
		_cached_meshes[rock_name] = box
		_cached_materials[rock_name] = fallback_mat

func get_rock_names_for_tier(tier: String) -> Array[String]:
	match tier:
		"TierA": return TIER_A_ROCKS
		"TierB": return TIER_B_ROCKS
		"TierC": return TIER_C_ROCKS
		_: return TIER_A_ROCKS

func get_aabb(rock_name: String) -> AABB:
	if ROCK_EXTENTS.has(rock_name):
		var mn: Vector3 = ROCK_EXTENTS[rock_name]["min"]
		var mx: Vector3 = ROCK_EXTENTS[rock_name]["max"]
		return AABB(mn, mx - mn)
	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1.0, 1.0, 1.0))

func get_mesh(rock_name: String) -> Mesh:
	if _cached_meshes.has(rock_name):
		return _cached_meshes[rock_name] as Mesh
	return null

func get_material(rock_name: String) -> Material:
	if _cached_materials.has(rock_name):
		return _cached_materials[rock_name] as Material
	return null

func get_visibility_end_for_tier(tier: String) -> float:
	return TIER_A_VISIBILITY_END if tier == "TierA" else TIER_BC_VISIBILITY_END

func create_rock_node(rock_name: String, scale_vec: Vector3, with_collider: bool = true, visibility_end: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = rock_name.replace(" ", "_").replace("(", "").replace(")", "")

	var mesh_obj := get_mesh(rock_name)
	var mat_obj := get_material(rock_name)
	var raw_aabb := get_aabb(rock_name)

	var mi := MeshInstance3D.new()
	mi.name = "RockMesh"
	mi.mesh = mesh_obj
	if mat_obj != null:
		mi.material_override = mat_obj
	mi.scale = scale_vec

	# Set distance culling if specified
	var vis_end := visibility_end
	if vis_end <= 0.0 and ROCK_EXTENTS.has(rock_name):
		var tier_str: String = ROCK_EXTENTS[rock_name]["tier"]
		vis_end = get_visibility_end_for_tier(tier_str)

	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = vis_end * 0.15
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	mi.set_meta("ballistic_material", "STONE")
	mi.set_meta("reactive_target", true)
	root.add_child(mi)

	if with_collider:
		var sb := StaticBody3D.new()
		sb.name = "RockStaticBody"
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.set_meta("ballistic_material", "STONE")
		sb.set_meta("reactive_target", true)

		var cs := CollisionShape3D.new()
		cs.name = "AnalyticBoxCol"
		var box := BoxShape3D.new()
		box.size = raw_aabb.size * scale_vec
		cs.shape = box
		cs.position = (raw_aabb.position + raw_aabb.size * 0.5) * scale_vec
		sb.add_child(cs)
		root.add_child(sb)

	root.set_meta("ballistic_material", "STONE")
	root.set_meta("reactive_target", true)
	return root

func create_tier_rock_node(tier: String, scale_vec: Vector3, seed_idx: int = 0, with_collider: bool = true) -> Node3D:
	var names := get_rock_names_for_tier(tier)
	var chosen_name := names[abs(seed_idx) % names.size()]
	var vis_end := get_visibility_end_for_tier(tier)
	return create_rock_node(chosen_name, scale_vec, with_collider, vis_end)

