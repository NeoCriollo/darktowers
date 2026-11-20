class_name MohaineSanctuaryDresser
extends RefCounted

## MohaineSanctuaryDresser (Area 1 / Node 0 Environment Builder)
## Transforms the flat plain outside the Way-Bunker into a rugged, sheltered
## desert basin using photogrammetry rock meshes from RockPackLibrary:
## 1. Concrete bunker perimeter framed with heavy Rock1 & Rock2 outcrop shelves.
## 2. Immediate blast door threshold & entry ramp kept 100% clear (zero colliders).
## 3. Caliche slabs (Rock5b) and tactical crouch cover (Rock3) scattered along
##    the approach toward Node 1 / Pass 0->1.
## 4. Registers all spawned rock clusters to Node 0's CullUnit in WorldCullingAndBounds.

const BUNKER_CENTER := Vector2(-1015.0, -815.0)
const BUNKER_SPAWN := Vector2(-1020.0, -820.0)
const THRESHOLD_GATE := Vector2(-900.0, -820.0)

# Outcrop shelves framing North, West, and South bunker perimeter
const OUTCROP_SHELVES: Array[Dictionary] = [
	{
		"rock": "Rock1 (38K)",
		"pos": Vector2(-1015.0, -788.0),
		"scale": Vector3(20.0, 16.0, 18.0),
		"sink": 2.5,
		"rot_deg": Vector3(5.0, 15.0, 0.0)
	},
	{
		"rock": "Rock2 (41K)",
		"pos": Vector2(-1038.0, -794.0),
		"scale": Vector3(22.0, 18.0, 20.0),
		"sink": 2.5,
		"rot_deg": Vector3(8.0, -30.0, 0.0)
	},
	{
		"rock": "Rock1 (38K)",
		"pos": Vector2(-1045.0, -815.0),
		"scale": Vector3(24.0, 19.0, 18.0),
		"sink": 2.5,
		"rot_deg": Vector3(-4.0, 90.0, 0.0)
	},
	{
		"rock": "Rock2 (41K)",
		"pos": Vector2(-1038.0, -838.0),
		"scale": Vector3(21.0, 17.0, 19.0),
		"sink": 2.5,
		"rot_deg": Vector3(6.0, 45.0, 0.0)
	},
	{
		"rock": "Rock1 (38K)",
		"pos": Vector2(-1015.0, -842.0),
		"scale": Vector3(19.0, 15.0, 17.0),
		"sink": 2.5,
		"rot_deg": Vector3(5.0, -15.0, 0.0)
	}
]

# Caliche slabs (Rock5b) partially buried along approach to Node 1
const CALICHE_SLABS: Array[Dictionary] = [
	{"pos": Vector2(-875.0, -842.0), "scale": Vector3(6.0, 2.5, 6.0), "sink": 0.8, "rot_y": 25.0},
	{"pos": Vector2(-850.0, -805.0), "scale": Vector3(6.5, 2.4, 6.2), "sink": 0.9, "rot_y": -40.0},
	{"pos": Vector2(-815.0, -835.0), "scale": Vector3(6.0, 2.5, 5.8), "sink": 0.8, "rot_y": 15.0},
	{"pos": Vector2(-780.0, -855.0), "scale": Vector3(7.0, 2.6, 6.5), "sink": 0.9, "rot_y": 60.0},
	{"pos": Vector2(-740.0, -840.0), "scale": Vector3(6.2, 2.4, 6.0), "sink": 0.8, "rot_y": -20.0},
	{"pos": Vector2(-695.0, -868.0), "scale": Vector3(6.5, 2.5, 6.5), "sink": 0.85, "rot_y": 35.0},
	{"pos": Vector2(-650.0, -885.0), "scale": Vector3(6.0, 2.5, 6.0), "sink": 0.8, "rot_y": -55.0}
]

# Tactical crouch cover boulders (Rock3) providing physical cover from sandstorms
const CROUCH_BOULDERS: Array[Dictionary] = [
	{"pos": Vector2(-860.0, -836.0), "scale": Vector3(3.2, 3.2, 3.0), "sink": 0.4, "rot_y": 45.0},
	{"pos": Vector2(-825.0, -802.0), "scale": Vector3(3.4, 3.3, 3.2), "sink": 0.4, "rot_y": -70.0},
	{"pos": Vector2(-770.0, -860.0), "scale": Vector3(3.5, 3.5, 3.3), "sink": 0.4, "rot_y": 20.0},
	{"pos": Vector2(-710.0, -838.0), "scale": Vector3(3.3, 3.2, 3.1), "sink": 0.4, "rot_y": -35.0},
	{"pos": Vector2(-660.0, -895.0), "scale": Vector3(3.6, 3.4, 3.4), "sink": 0.4, "rot_y": 80.0}
]

var scatter: PropScatter
var library: RockPackLibrary
var spawned_units: Array[WorldCullingAndBounds.CullUnit] = []

func _init(p_scatter: PropScatter = null, p_library: RockPackLibrary = null) -> void:
	scatter = p_scatter
	if p_library != null:
		library = p_library
	else:
		library = RockPackLibrary.new()

func dress_mohaine_sanctuary(parent_node: Node3D = null) -> int:
	var target_parent: Node3D = parent_node
	if target_parent == null and scatter != null:
		target_parent = scatter

	var group := Node3D.new()
	group.name = "Vignettes_Mohaine_Sanctuary"
	if target_parent != null:
		target_parent.add_child(group)

	var total_spawned := 0

	# 1. Bunker Flank Outcrop Shelves (Hero Monoliths - Tier C)
	for i in range(OUTCROP_SHELVES.size()):
		var shelf: Dictionary = OUTCROP_SHELVES[i]
		var pos_2d: Vector2 = shelf["pos"]
		var rock_name: String = shelf["rock"]
		var sc: Vector3 = shelf["scale"]
		var sink_depth: float = float(shelf["sink"])
		var rot_deg: Vector3 = shelf["rot_deg"]

		var ground_y := TerrainCollisionGenerator.sample_height(pos_2d.x, pos_2d.y)
		var rock_node := library.create_rock_node(rock_name, sc, true, RockPackLibrary.TIER_BC_VISIBILITY_END)
		var prop_uuid := "Mohaine_OutcropShelf_%d" % (i + 1)
		rock_node.name = prop_uuid
		rock_node.set_meta("prop_uuid", prop_uuid)
		rock_node.set_meta("instance_id", prop_uuid)
		rock_node.position = Vector3(pos_2d.x, ground_y - sink_depth, pos_2d.y)
		rock_node.rotation_degrees = rot_deg
		group.add_child(rock_node)

		_register_cull_unit(rock_node, pos_2d, 18.0, "waystation_sanctuary")
		total_spawned += 1

	# 2. Tactical Caliche Slabs (Tier A - Rock5b)
	for i in range(CALICHE_SLABS.size()):
		var slab: Dictionary = CALICHE_SLABS[i]
		var pos_2d: Vector2 = slab["pos"]
		var sc: Vector3 = slab["scale"]
		var sink_depth: float = float(slab["sink"])
		var rot_y: float = float(slab["rot_y"])

		var ground_y := TerrainCollisionGenerator.sample_height(pos_2d.x, pos_2d.y)
		var slab_node := library.create_rock_node("Rock5b (11K)", sc, true, RockPackLibrary.TIER_A_VISIBILITY_END)
		var prop_uuid := "Mohaine_CalicheSlab_%d" % (i + 1)
		slab_node.name = prop_uuid
		slab_node.set_meta("prop_uuid", prop_uuid)
		slab_node.set_meta("instance_id", prop_uuid)
		slab_node.position = Vector3(pos_2d.x, ground_y - sink_depth, pos_2d.y)
		slab_node.rotation_degrees = Vector3(0.0, rot_y, 0.0)
		group.add_child(slab_node)

		var bubble_id := "waystation_sanctuary" if pos_2d.x < -800.0 else "sw_desolation"
		_register_cull_unit(slab_node, pos_2d, 8.0, bubble_id)
		total_spawned += 1

	# 3. Tactical Crouch Cover Boulders (Tier A - Rock3)
	for i in range(CROUCH_BOULDERS.size()):
		var bld: Dictionary = CROUCH_BOULDERS[i]
		var pos_2d: Vector2 = bld["pos"]
		var sc: Vector3 = bld["scale"]
		var sink_depth: float = float(bld["sink"])
		var rot_y: float = float(bld["rot_y"])

		var ground_y := TerrainCollisionGenerator.sample_height(pos_2d.x, pos_2d.y)
		var bld_node := library.create_rock_node("Rock3 (5K)", sc, true, RockPackLibrary.TIER_A_VISIBILITY_END)
		var prop_uuid := "Mohaine_CrouchBoulder_%d" % (i + 1)
		bld_node.name = prop_uuid
		bld_node.set_meta("prop_uuid", prop_uuid)
		bld_node.set_meta("instance_id", prop_uuid)
		bld_node.position = Vector3(pos_2d.x, ground_y - sink_depth, pos_2d.y)
		bld_node.rotation_degrees = Vector3(0.0, rot_y, 0.0)
		group.add_child(bld_node)

		var bubble_id := "waystation_sanctuary" if pos_2d.x < -800.0 else "sw_desolation"
		_register_cull_unit(bld_node, pos_2d, 6.0, bubble_id)
		total_spawned += 1

	return total_spawned

func _register_cull_unit(node: Node3D, pos_2d: Vector2, radius: float, bubble_id: String) -> void:
	var unit := WorldCullingAndBounds.CullUnit.new()
	unit.node = node
	unit.pos = pos_2d
	unit.radius = radius
	unit.bubble_id = bubble_id
	unit.applied_visible = true
	unit.target_visible = true
	spawned_units.append(unit)

	if scatter != null:
		scatter._placed_xz.append(pos_2d)
		scatter._placed_radii.append(radius)

