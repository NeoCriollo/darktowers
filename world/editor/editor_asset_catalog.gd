class_name EditorAssetCatalog
extends RefCounted

## EditorAssetCatalog: Asset Palette Registry & Spawner (Phase 3)
## Catalogs photogrammetry rocks, NCP / Old-Ones architecture, and wasteland
## props/hazards for instant stamp-spawning in Editor Mode.
## Provides structured metadata, category filtering, and procedural spawn builders.

const RockPackLibraryScript = preload("res://world/props/rock_pack_library.gd")
const MidWorldDoorwayScript = preload("res://world/midworld_doorway.gd")
const SupplyCrateScript = preload("res://world/supply_crate.gd")
const ThinnyZoneScript = preload("res://world/thinny_zone.gd")

static var _rock_lib: RefCounted = null
static var _spawn_counter: int = 0

const CATEGORIES: Array[Dictionary] = [
	{ "id": "rocks", "name": "ROCAS FOTOGRAMÉTRICAS", "code": "ROCKS", "badge": "7 ASSETS" },
	{ "id": "architecture", "name": "ARQUITECTURA NCP", "code": "ARCH", "badge": "4 ASSETS" },
	{ "id": "props", "name": "PELIGROS Y PERTRECHOS", "code": "PROPS", "badge": "4 ASSETS" },
	{ "id": "custom", "name": "PROPIOS / CUSTOM 3D", "code": "CUSTOM", "badge": "CUSTOM GLB" }
]

const CATALOG: Dictionary = {
	"rock_3": {
		"id": "rock_3", "category": "rocks", "name": "Rock3 (5K) — Tier A Scatter",
		"glb_name": "Rock3 (5K)", "tier_badge": "[TIER A - 5K]",
		"scale": Vector3(2.5, 2.5, 2.5), "sink": 0.35, "material": "STONE"
	},
	"rock_5b": {
		"id": "rock_5b", "category": "rocks", "name": "Rock5b (11K) — Caliche Ground Slab",
		"glb_name": "Rock5b (11K)", "tier_badge": "[TIER A - 11K]",
		"scale": Vector3(3.5, 1.8, 3.5), "sink": 0.45, "material": "STONE"
	},
	"rock_5c": {
		"id": "rock_5c", "category": "rocks", "name": "Rock5c (23K) — Vertical Crag",
		"glb_name": "Rock5c (23K)", "tier_badge": "[TIER B - 23K]",
		"scale": Vector3(4.0, 6.0, 4.0), "sink": 0.60, "material": "STONE"
	},
	"rock_1": {
		"id": "rock_1", "category": "rocks", "name": "Rock1 (38K) — Outcrop Shelf",
		"glb_name": "Rock1 (38K)", "tier_badge": "[TIER B - 38K]",
		"scale": Vector3(5.0, 3.5, 5.0), "sink": 0.50, "material": "STONE"
	},
	"rock_5a": {
		"id": "rock_5a", "category": "rocks", "name": "Rock5a (37K) — Escarpment Face",
		"glb_name": "Rock5a (37K)", "tier_badge": "[TIER B - 37K]",
		"scale": Vector3(6.0, 9.0, 5.0), "sink": 0.80, "material": "STONE"
	},
	"rock_2": {
		"id": "rock_2", "category": "rocks", "name": "Rock2 (41K) — Talus Monolith",
		"glb_name": "Rock2 (41K)", "tier_badge": "[HERO - 41K]",
		"scale": Vector3(7.0, 7.0, 7.0), "sink": 1.00, "material": "STONE"
	},
	"rock_4": {
		"id": "rock_4", "category": "rocks", "name": "Rock4 (60K) — Horizon Spire",
		"glb_name": "Rock4 (60K)", "tier_badge": "[HERO - 60K]",
		"scale": Vector3(10.0, 16.0, 10.0), "sink": 1.50, "material": "STONE"
	},
	"monolith_pylon": {
		"id": "monolith_pylon", "category": "architecture", "name": "Ka Survey Beacon Pylon",
		"glb_name": "dark_tower_beacon_monolith_pylon.glb", "tier_badge": "[NCP BEACON]",
		"scale": Vector3(1.0, 1.0, 1.0), "sink": 0.50, "material": "STEEL"
	},
	"bunker_slab": {
		"id": "bunker_slab", "category": "architecture", "name": "Way-Bunker Blast Foundation",
		"glb_name": "procedural_bunker_slab", "tier_badge": "[CONCRETE]",
		"scale": Vector3(1.0, 1.0, 1.0), "sink": 0.20, "material": "STONE"
	},
	"highway_pillar": {
		"id": "highway_pillar", "category": "architecture", "name": "Overpass Support Pillar",
		"glb_name": "procedural_highway_pillar", "tier_badge": "[OLD-ONES INFRA]",
		"scale": Vector3(1.0, 1.0, 1.0), "sink": 0.80, "material": "STONE"
	},
	"midworld_door": {
		"id": "midworld_door", "category": "architecture", "name": "Freestanding Mid-World Door",
		"glb_name": "midworld_doorway", "tier_badge": "[TODASH GATE]",
		"scale": Vector3(1.0, 1.0, 1.0), "sink": 0.00, "material": "WOOD"
	},
	"supply_crate": {
		"id": "supply_crate", "category": "props", "name": "Frontier Footlocker Crate",
		"glb_name": "supply_crate", "tier_badge": "[LOOT CACHE]",
		"scale": Vector3(1.0, 1.0, 1.0), "sink": 0.00, "material": "STEEL"
	},
	"thinny_anomaly": {
		"id": "thinny_anomaly", "category": "props", "name": "Thinny Spatial Anomaly Tear",
		"glb_name": "thinny_zone", "tier_badge": "[HAZARD FX]",
		"scale": Vector3(1.0, 1.0, 1.0), "sink": 0.00, "material": "ENERGY"
	},
	"telegraph_pole": {
		"id": "telegraph_pole", "category": "props", "name": "Dead-Creek Telegraph Pole",
		"glb_name": "procedural_telegraph_pole", "tier_badge": "[FRONTIER WIRE]",
		"scale": Vector3(1.0, 1.0, 1.0), "sink": 0.50, "material": "WOOD"
	},
	"skeleton_debris": {
		"id": "skeleton_debris", "category": "props", "name": "Sun-Bleached Skeleton & Wreck",
		"glb_name": "procedural_skeleton_debris", "tier_badge": "[SCATTER]",
		"scale": Vector3(1.0, 1.0, 1.0), "sink": 0.10, "material": "BONE"
	}
}

static func get_categories() -> Array[Dictionary]:
	return CATEGORIES

static func get_assets_in_category(category_id: String) -> Array[Dictionary]:
	if category_id == "custom":
		return EditorFolderScanner.get_cached_entries()
	var result: Array[Dictionary] = []
	for asset_id in CATALOG:
		var entry: Dictionary = CATALOG[asset_id]
		if entry.get("category", "") == category_id:
			result.append(entry)
	return result

static func get_asset_info(asset_id: String) -> Dictionary:
	if CATALOG.has(asset_id):
		return CATALOG[asset_id]
	return EditorFolderScanner.get_entry_by_id(asset_id)

static func _ensure_rock_library() -> RefCounted:
	if _rock_lib == null:
		_rock_lib = RockPackLibraryScript.new()
		_rock_lib.load_library()
	return _rock_lib

static func spawn_asset(asset_id: String, world_pos: Vector3 = Vector3.ZERO, parent: Node = null) -> Node3D:
	if EditorFolderScanner.is_custom_asset(asset_id):
		var custom_entry := EditorFolderScanner.get_entry_by_id(asset_id)
		var custom_path: String = custom_entry.get("asset_path", "")
		var spawned_custom := CustomPropPreviewer.instantiate_custom_prop(custom_path, parent)
		if spawned_custom != null:
			_spawn_counter += 1
			spawned_custom.name = "CustomProp_%s_%03d" % [custom_entry.get("id", "prop"), _spawn_counter]
			spawned_custom.set_meta("catalog_asset_id", custom_entry.get("id", asset_id))
			var sink_val: float = custom_entry.get("sink", 0.1)
			var final_custom_pos := world_pos
			final_custom_pos.y -= sink_val
			spawned_custom.global_position = final_custom_pos
		return spawned_custom

	if not CATALOG.has(asset_id):
		push_warning("EditorAssetCatalog: Unknown asset ID: %s" % asset_id)
		return null

	var entry: Dictionary = CATALOG[asset_id]
	var cat: String = entry["category"]
	var spawned: Node3D = null

	match cat:
		"rocks":
			spawned = _spawn_rock(entry)
		"architecture":
			spawned = _spawn_architecture(entry)
		"props":
			spawned = _spawn_prop(entry)

	if spawned == null:
		return null

	_spawn_counter += 1
	spawned.name = "EditorProp_%s_%03d" % [entry["id"], _spawn_counter]
	spawned.set_meta("catalog_asset_id", entry["id"])
	spawned.set_meta("ballistic_material", entry["material"])
	spawned.set_meta("reactive_target", true)

	var sink: float = entry.get("sink", 0.0)
	var final_pos := world_pos
	final_pos.y -= sink
	spawned.global_position = final_pos

	if parent != null:
		parent.add_child(spawned)
	return spawned

static func _spawn_rock(entry: Dictionary) -> Node3D:
	var lib := _ensure_rock_library()
	var glb_name: String = entry["glb_name"]
	var s_vec: Vector3 = entry["scale"]
	return lib.create_rock_node(glb_name, s_vec, true)

static func _spawn_architecture(entry: Dictionary) -> Node3D:
	var id: String = entry["id"]
	match id:
		"monolith_pylon":
			return _build_monolith_pylon(entry)
		"bunker_slab":
			return _build_bunker_slab(entry)
		"highway_pillar":
			return _build_highway_pillar(entry)
		"midworld_door":
			return MidWorldDoorwayScript.new()
	return null

static func _spawn_prop(entry: Dictionary) -> Node3D:
	var id: String = entry["id"]
	match id:
		"supply_crate":
			return SupplyCrateScript.new()
		"thinny_anomaly":
			return ThinnyZoneScript.new()
		"telegraph_pole":
			return _build_telegraph_pole(entry)
		"skeleton_debris":
			return _build_skeleton_debris(entry)
	return null

static func _build_monolith_pylon(_entry: Dictionary) -> Node3D:
	var pylon_scene_path := "res://assets/architecture/landmarks/dark_tower/dark_tower_beacon_monolith_pylon.glb"
	if ResourceLoader.exists(pylon_scene_path):
		var p_res := load(pylon_scene_path) as PackedScene
		if p_res != null:
			var inst := p_res.instantiate() as Node3D
			_add_box_col(inst, Vector3(2.5, 9.0, 2.5), Vector3(0.0, 4.5, 0.0), "STEEL")
			return inst

	# Procedural fallback split pylon
	var root := Node3D.new()
	var pylon := MeshInstance3D.new()
	pylon.name = "MonolithPylonMesh"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 8.5, 2.0)
	pylon.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14)
	mat.metallic = 0.8
	mat.roughness = 0.35
	pylon.material_override = mat
	pylon.position = Vector3(0.0, 4.25, 0.0)
	root.add_child(pylon)
	_add_box_col(root, bm.size, pylon.position, "STEEL")
	return root

static func _build_bunker_slab(_entry: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "BunkerSlabMesh"
	var bm := BoxMesh.new()
	bm.size = Vector3(12.0, 0.8, 12.0)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.22, 0.20)
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.4, 0.0)
	root.add_child(mi)
	_add_box_col(root, bm.size, mi.position, "STONE")
	return root

static func _build_highway_pillar(_entry: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "HighwayPillarMesh"
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 14.0, 2.4)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.26, 0.24)
	mat.roughness = 0.92
	mi.material_override = mat
	mi.position = Vector3(0.0, 7.0, 0.0)
	root.add_child(mi)
	_add_box_col(root, bm.size, mi.position, "STONE")
	return root

static func _build_telegraph_pole(_entry: Dictionary) -> Node3D:
	var root := Node3D.new()
	var pole := MeshInstance3D.new()
	pole.name = "TelegraphPoleMesh"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.18
	cm.height = 7.5
	pole.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.18, 0.14)
	mat.roughness = 0.96
	pole.material_override = mat
	pole.position = Vector3(0.0, 3.75, 0.0)
	root.add_child(pole)

	# Crossarm
	var arm := MeshInstance3D.new()
	var arm_m := BoxMesh.new()
	arm_m.size = Vector3(1.8, 0.15, 0.15)
	arm.mesh = arm_m
	arm.material_override = mat
	arm.position = Vector3(0.0, 6.8, 0.0)
	root.add_child(arm)

	_add_cylinder_col(root, 0.2, 7.5, pole.position, "WOOD")
	return root

static func _build_skeleton_debris(_entry: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "SkeletonBonesMesh"
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.35, 1.4)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.74, 0.65)
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.175, 0.0)
	root.add_child(mi)
	_add_box_col(root, bm.size, mi.position, "BONE")
	return root

static func _add_box_col(parent: Node3D, size: Vector3, pos: Vector3, mat_tag: String) -> void:
	var sb := StaticBody3D.new()
	sb.name = "ColBody"
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta("ballistic_material", mat_tag)
	sb.set_meta("reactive_target", true)
	var cs := CollisionShape3D.new()
	cs.name = "BoxCol"
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	sb.add_child(cs)
	parent.add_child(sb)

static func _add_cylinder_col(parent: Node3D, radius: float, height: float, pos: Vector3, mat_tag: String) -> void:
	var sb := StaticBody3D.new()
	sb.name = "ColBody"
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta("ballistic_material", mat_tag)
	sb.set_meta("reactive_target", true)
	var cs := CollisionShape3D.new()
	cs.name = "CylCol"
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	cs.position = pos
	sb.add_child(cs)
	parent.add_child(sb)

