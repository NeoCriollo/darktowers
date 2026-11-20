class_name PropMeshFactory
extends RefCounted

## PropMeshFactory: Pre-baked materials and geometry/physics collision helpers
## for modular wasteland prop scatterers in "Dark Towers: The Path of Ka".

# ─── 14 Pre-Baked StandardMaterial3D Definitions ──────────────────────────────
static var MAT_SANDSTONE: StandardMaterial3D = null
static var MAT_WEATHERED_CONCRETE: StandardMaterial3D = null
static var MAT_BRUTALIST_CONCRETE: StandardMaterial3D = null
static var MAT_RUSTED_STEEL: StandardMaterial3D = null
static var MAT_CARBON_STEEL: StandardMaterial3D = null
static var MAT_SALT_CRUST: StandardMaterial3D = null
static var MAT_CORRODED_BRONZE: StandardMaterial3D = null
static var MAT_OLD_ONES_ALLOY: StandardMaterial3D = null
static var MAT_ANCIENT_BONE: StandardMaterial3D = null
static var MAT_DESERT_WOOD: StandardMaterial3D = null
static var MAT_CANVAS_TARP: StandardMaterial3D = null
static var MAT_OBSIDIAN_GLASS: StandardMaterial3D = null
static var MAT_SCORCHED_BASALT: StandardMaterial3D = null
static var MAT_CONDUIT_IRON: StandardMaterial3D = null

static func _static_init() -> void:
	MAT_SANDSTONE = make_mat(Color(0.60, 0.50, 0.36), 0.62, 0.0)
	MAT_WEATHERED_CONCRETE = make_mat(Color(0.36, 0.35, 0.32), 0.98, 0.0)
	MAT_BRUTALIST_CONCRETE = make_mat(Color(0.34, 0.33, 0.30), 0.96, 0.05)
	MAT_RUSTED_STEEL = make_mat(Color(0.25, 0.18, 0.14), 0.88, 0.40)
	MAT_CARBON_STEEL = make_mat(Color(0.13, 0.14, 0.16), 0.42, 0.88)
	MAT_SALT_CRUST = make_mat(Color(0.80, 0.86, 0.82), 0.35, 0.15)
	MAT_CORRODED_BRONZE = make_mat(Color(0.48, 0.24, 0.16), 0.85, 0.72)
	MAT_OLD_ONES_ALLOY = make_mat(Color(0.20, 0.16, 0.14), 0.82, 0.70)
	MAT_ANCIENT_BONE = make_mat(Color(0.88, 0.86, 0.80), 0.88, 0.02)
	MAT_DESERT_WOOD = make_mat(Color(0.24, 0.20, 0.16), 0.88, 0.05)
	MAT_CANVAS_TARP = make_mat(Color(0.66, 0.60, 0.49), 0.95, 0.0)
	MAT_OBSIDIAN_GLASS = make_mat(Color(0.06, 0.06, 0.07), 0.22, 0.90)
	MAT_SCORCHED_BASALT = make_mat(Color(0.06, 0.05, 0.07), 0.22, 0.90)
	MAT_CONDUIT_IRON = make_mat(Color(0.10, 0.11, 0.13), 0.35, 0.90)

# ─── Dynamic Material Generator ───────────────────────────────────────────────
static func make_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

# ─── Terrain Height & Snapping Helpers ─────────────────────────────────────────
static func sample_terrain_y(x: float, z: float) -> float:
	if ClassDB.class_exists("TerrainCollisionGenerator") or ResourceLoader.exists("res://terrain_collision.gd"):
		return TerrainCollisionGenerator.sample_height(x, z)
	return 0.0

static func snap_to_terrain(node: Node3D, y_offset: float = 0.0) -> void:
	var g := node.global_position
	node.position.y = sample_terrain_y(g.x, g.z) + y_offset

# ─── Collision Body Helpers ───────────────────────────────────────────────────
static func add_box_collision(parent: Node3D, size: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "StaticCollision_Box"
	parent.set_meta("reactive_target", true)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	parent.add_child(sb)
	return sb

static func add_cylinder_collision(parent: Node3D, radius: float, height: float) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "StaticCollision_Cylinder"
	parent.set_meta("reactive_target", true)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	sb.add_child(cs)
	parent.add_child(sb)
	return sb

static func create_collision_box(parent: Node3D, size: Vector3) -> StaticBody3D:
	return add_box_collision(parent, size)

static func create_collision_cylinder(parent: Node3D, radius: float, height: float) -> StaticBody3D:
	return add_cylinder_collision(parent, radius, height)

# ─── Procedural Mesh Helpers ──────────────────────────────────────────────────
static func build_procedural_box_mesh(name_tag: String, size: Vector3, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_tag
	var bm := BoxMesh.new()
	bm.size = size
	if mat != null:
		bm.material = mat
	mi.mesh = bm
	return mi

static func build_ambient_debris(rng: RandomNumberGenerator, su: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Debris"
	var bm := BoxMesh.new()
	bm.size = Vector3(su, su * rng.randf_range(0.15, 0.5), su * rng.randf_range(0.5, 1.2))
	bm.material = make_mat(Color(rng.randf_range(0.24, 0.40), rng.randf_range(0.22, 0.35), rng.randf_range(0.18, 0.28)), 0.95, 0.0)
	mi.mesh = bm
	return mi

static func build_ambient_skeleton(rng: RandomNumberGenerator, su: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Skeleton"
	var cm := CapsuleMesh.new()
	cm.radius = su * 0.12
	cm.height = su * 0.88
	cm.material = make_mat(Color(rng.randf_range(0.72, 0.82), rng.randf_range(0.68, 0.78), rng.randf_range(0.58, 0.68)), 0.88, 0.0)
	mi.mesh = cm
	return mi

static func build_ambient_structure(rng: RandomNumberGenerator, su: float, sv: float, sw: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Structure"
	var form := rng.randi() % 5
	match form:
		0:
			var bm := BoxMesh.new()
			bm.size = Vector3(su * 0.55, sv * 2.2, sw * 0.55)
			bm.material = make_mat(Color(0.38, 0.36, 0.33), 0.96, 0.0)
			mi.set_meta("ballistic_material", "CONCRETE")
			mi.mesh = bm
		1:
			var bm := BoxMesh.new()
			bm.size = Vector3(su * 2.8, sv * 0.12, sw * 1.4)
			bm.material = make_mat(Color(0.30, 0.28, 0.24), 0.90, 0.25)
			mi.set_meta("ballistic_material", "CONCRETE")
			mi.mesh = bm
		2:
			var bm := BoxMesh.new()
			bm.size = Vector3(su * 0.42, sv * 2.6, sw * 2.2)
			bm.material = make_mat(Color(0.44, 0.33, 0.26), 0.92, 0.0)
			mi.set_meta("ballistic_material", "CONCRETE")
			mi.mesh = bm
		3:
			var bm := BoxMesh.new()
			bm.size = Vector3(su * 0.18, sv * 3.1, sw * 0.28)
			bm.material = make_mat(Color(0.24, 0.16, 0.12), 0.75, 0.78)
			mi.set_meta("ballistic_material", "STEEL")
			mi.mesh = bm
		_:
			var cyl := CylinderMesh.new()
			cyl.top_radius = su * 0.55
			cyl.bottom_radius = su * 0.55
			cyl.height = sv * 1.6
			cyl.material = make_mat(Color(0.26, 0.28, 0.24), 0.78, 0.35)
			mi.set_meta("ballistic_material", "STEEL")
			mi.mesh = cyl
	return mi
