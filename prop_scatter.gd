class_name PropScatter
extends Node3D
signal scatter_complete(total_props: int)

@export_group("Scatter Area")
@export var field_half_extent: float = 1245.0   ## Half-side of the square scatter zone (2500m × 2500m map)
@export var player_clearance: float = 40.0     ## Minimum distance from player spawn clearance zones
@export var spawn_clearance_point: Vector2 = Vector2(-1020.0, -820.0) ## Node 0 sanctuary clearance center
@export var inter_prop_clearance: float = 0.9  ## Minimum gap between ambient props

@export_group("Narrative Vignettes")
@export var caravan_vignette_count: int = 5
@export var overpass_vignette_count: int = 4
@export var outpost_vignette_count: int = 4
@export var monolith_vignette_count: int = 4   ## Multi-tiered Great Old Ones brutalist ruins
@export var vignette_radius: float = 18.0      ## Local radius per cluster

@export_group("Q01 Medieval Ruins")
@export var q01_brick_ruins_count: int = 14

@export_group("SW Desolation Scavenger Debris")
@export var sw_desolation_scrap_count: int = 6  ## Debris & container clusters along hardpan ridge footwalls

@export_group("South Salt Flats Landmarks")
@export var south_salt_landmark_count: int = 10  ## Telegraph poles & megafauna skeletal remains

@export_group("Caliche Cradle Landmarks")
@export var cradle_landmark_count: int = 8  ## Waymarker stelae, abyss overlook survey ruins, desert scrub

@export_group("Rust-Gorge Defile Landmarks")
@export var west_gorge_landmark_count: int = 6  ## Collapsed overpass choke, tangled I-beams, pipeline network

@export_group("North Alkali Sink Landmarks")
@export var north_alkali_landmark_count: int = 6  ## Ka survey beacon monolith, armored conduits, mineral mounds

@export_group("East Dunes Erg Landmarks")
@export var east_dunes_landmark_count: int = 6  ## Tilted Old-Ones megastructure, external trusses, obsidian ribs, gantry struts

@export_group("Tower Threshold & Citadel Landmarks")
@export var tower_threshold_landmark_count: int = 11  ## Dark Tower citadel spire, defense line hedgehogs, razor-wire, armored wrecks

@export_group("Ambient Waste Scatter")
@export var ambient_debris_count: int = 140
@export var ambient_skeleton_count: int = 35
@export var ambient_structure_count: int = 20

@export_group("Monumental Landmark (Weenie)")
@export var enable_landmark: bool = true
@export var landmark_position: Vector2 = Vector2(700.0, 700.0) ## Macro-world Dark Tower position
@export var valley_axis_rad: float = 0.785             ## Axis of the Beam: 0.785 rad (~45 deg NE)
@export var landmark_height: float = 120.0           ## Monumental vertical scale (Tower GLB scaled BIG)
@export var landmark_width: float = 30.0

@export_group("Placement Seed")
@export var rng_seed: int = 0x4B41     ## "KA" in hex — deterministic world

var _rng: RandomNumberGenerator
var _placed_xz: Array[Vector2] = []
var _placed_radii: Array[float] = []
var is_scatter_complete: bool = false
const MAX_PLACEMENT_ATTEMPTS := 40
var _vignettes_builder: VignettesGeneric
var _sw_desolation_builder: SectorSWDesolation
var _south_salt_builder: SectorSouthSalt
var _cradle_nexus_builder: SectorCradleNexus
var _west_gorge_builder: SectorWestGorge
var _north_alkali_builder: SectorNorthAlkali
var _east_tower_builder: SectorEastAndTower
var _q01_ruins_builder: SectorQ01Ruins
var _mohaine_dresser: MohaineSanctuaryDresser
var _ridge_dresser: EscarpmentRidgeDresser

func _ready() -> void:
	if not is_scatter_complete:
		call_deferred("ensure_scatter_completed")

func ensure_scatter_completed() -> void:
	if is_scatter_complete:
		return
	_run_scatter()

func _run_scatter() -> void:
	if is_scatter_complete:
		return
	_rng = RandomNumberGenerator.new()
	_rng.seed = rng_seed
	_vignettes_builder = VignettesGeneric.new(self)
	_sw_desolation_builder = SectorSWDesolation.new(self)
	_south_salt_builder = SectorSouthSalt.new(self)
	_cradle_nexus_builder = SectorCradleNexus.new(self)
	_west_gorge_builder = SectorWestGorge.new(self)
	_north_alkali_builder = SectorNorthAlkali.new(self)
	_east_tower_builder = SectorEastAndTower.new(self)
	_q01_ruins_builder = SectorQ01Ruins.new(self)
	_mohaine_dresser = MohaineSanctuaryDresser.new(self)
	_ridge_dresser = EscarpmentRidgeDresser.new(self)
	var total := _scatter_all()
	is_scatter_complete = true
	scatter_complete.emit(total)

func _scatter_all() -> int:
	var placed := 0
	if enable_landmark:
		_spawn_monumental_landmark()
		placed += 1
	placed += _spawn_waystation_ballistic_range()
	placed += _q01_ruins_builder._spawn_q01_brick_ruins()
	placed += _mohaine_dresser.dress_mohaine_sanctuary()
	placed += _ridge_dresser.dress_escarpment_ridges()
	placed += _vignettes_builder._spawn_vignette_clusters("CaravanAmbush", caravan_vignette_count, _vignettes_builder._generate_caravan_vignette)
	placed += _vignettes_builder._spawn_vignette_clusters("CollapsedOverpass", overpass_vignette_count, _vignettes_builder._generate_overpass_vignette)
	placed += _vignettes_builder._spawn_vignette_clusters("IndustrialOutpost", outpost_vignette_count, _vignettes_builder._generate_outpost_vignette)
	placed += _vignettes_builder._spawn_vignette_clusters("BrutalistMonolith", monolith_vignette_count, _vignettes_builder._generate_brutalist_monolith_vignette)
	placed += _sw_desolation_builder._spawn_sw_desolation_scrap_nodes()
	placed += _south_salt_builder._spawn_south_salt_landmarks()
	placed += _cradle_nexus_builder._spawn_cradle_nexus_landmarks()
	placed += _west_gorge_builder._spawn_west_gorge_landmarks()
	placed += _north_alkali_builder._spawn_north_alkali_landmarks()
	placed += _east_tower_builder._spawn_east_dunes_landmarks()
	placed += _east_tower_builder._spawn_tower_threshold_landmarks()
	placed += _scatter_ambient_layer("Ambient_Debris", ambient_debris_count, 0.15, 0.65, _build_debris_mesh)
	placed += _scatter_ambient_layer("Ambient_Skeleton", ambient_skeleton_count, 0.55, 1.25, _build_skeleton_mesh)
	placed += _scatter_ambient_layer("Ambient_Structure", ambient_structure_count, 1.80, 5.00, _build_structure_mesh)
	return placed

func _spawn_vignette_clusters(g: String, c: int, fn: Callable) -> int:
	return _vignettes_builder._spawn_vignette_clusters(g, c, fn)
func _find_cluster_center(r: float) -> Vector2:
	return _vignettes_builder._find_cluster_center(r)
func _generate_caravan_vignette(p: Node3D) -> int:
	return _vignettes_builder._generate_caravan_vignette(p)
func _generate_overpass_vignette(p: Node3D) -> int:
	return _vignettes_builder._generate_overpass_vignette(p)
func _generate_outpost_vignette(p: Node3D) -> int:
	return _vignettes_builder._generate_outpost_vignette(p)
func _generate_brutalist_monolith_vignette(p: Node3D) -> int:
	return _vignettes_builder._generate_brutalist_monolith_vignette(p)
func _spawn_q01_brick_ruins() -> int:
	return _q01_ruins_builder._spawn_q01_brick_ruins()
func _spawn_sw_desolation_scrap_nodes() -> int:
	return _sw_desolation_builder._spawn_sw_desolation_scrap_nodes()
func _generate_sw_scrap_cluster(p: Node3D) -> int:
	return _sw_desolation_builder._generate_sw_scrap_cluster(p)
func _spawn_south_salt_landmarks() -> int:
	return _south_salt_builder._spawn_south_salt_landmarks()
func _generate_telegraph_pole(p: Node3D, i: int) -> int:
	return _south_salt_builder._generate_telegraph_pole(p, i)
func _generate_salt_skeletal_cluster(p: Node3D, i: int) -> int:
	return _south_salt_builder._generate_salt_skeletal_cluster(p, i)
func _spawn_cradle_nexus_landmarks() -> int:
	return _cradle_nexus_builder._spawn_cradle_nexus_landmarks()
func _generate_stone_waymarker(p: Node3D, i: int) -> int:
	return _cradle_nexus_builder._generate_stone_waymarker(p, i)
func _generate_overlook_ruins(p: Node3D) -> int:
	return _cradle_nexus_builder._generate_overlook_ruins(p)
func _generate_desert_scrub_cluster(p: Node3D, i: int) -> int:
	return _cradle_nexus_builder._generate_desert_scrub_cluster(p, i)
func _spawn_west_gorge_landmarks() -> int:
	return _west_gorge_builder._spawn_west_gorge_landmarks()
func _generate_gorge_overpass_choke(p: Node3D, i: int) -> int:
	return _west_gorge_builder._generate_gorge_overpass_choke(p, i)
func _generate_gorge_pipeline_network(p: Node3D, i: int) -> int:
	return _west_gorge_builder._generate_gorge_pipeline_network(p, i)
func _spawn_north_alkali_landmarks() -> int:
	return _north_alkali_builder._spawn_north_alkali_landmarks()
func _generate_ka_beacon_monolith(p: Node3D) -> int:
	return _north_alkali_builder._generate_ka_beacon_monolith(p)
func _generate_armored_conduit(p: Node3D, i: int) -> int:
	return _north_alkali_builder._generate_armored_conduit(p, i)
func _generate_mineral_mound(p: Node3D, i: int) -> int:
	return _north_alkali_builder._generate_mineral_mound(p, i)
func _spawn_east_dunes_landmarks() -> int:
	return _east_tower_builder._spawn_east_dunes_landmarks()
func _generate_old_ones_megastructure(p: Node3D) -> int:
	return _east_tower_builder._generate_old_ones_megastructure(p)
func _generate_gantry_strut(p: Node3D, i: int) -> int:
	return _east_tower_builder._generate_gantry_strut(p, i)
func _generate_obsidian_pylon(p: Node3D, i: int) -> int:
	return _east_tower_builder._generate_obsidian_pylon(p, i)
func _spawn_tower_threshold_landmarks() -> int:
	return _east_tower_builder._spawn_tower_threshold_landmarks()
func _generate_dark_tower_citadel(p: Node3D) -> int:
	return _east_tower_builder._generate_dark_tower_citadel(p)
func _generate_czech_hedgehog(p: Node3D, i: int) -> int:
	return _east_tower_builder._generate_czech_hedgehog(p, i)
func _generate_concertina_wire(p: Node3D, i: int) -> int:
	return _east_tower_builder._generate_concertina_wire(p, i)
func _generate_armored_wreck(p: Node3D, c: Dictionary) -> int:
	return _east_tower_builder._generate_armored_wreck(p, c)

func _add_windward_sand_drift(p: Node3D, t: Vector3, h: float, w: float) -> int:
	var lwa := valley_axis_rad - p.rotation.y
	var wd := Vector2(-cos(lwa), -sin(lwa)).normalized()
	var rl := maxf(6.5, h * 2.45)
	var sl := sqrt(rl * rl + h * h)
	var d := MeshInstance3D.new()
	d.name = "WindwardSandDriftRamp"
	d.set_meta("ballistic_material", "SAND")
	var dm := BoxMesh.new()
	dm.size = Vector3(w, 0.9, sl)
	dm.material = _make_mat(Color(0.60, 0.50, 0.36), 0.62, 0.0)
	d.mesh = dm
	var mxz := Vector2(t.x, t.z) + wd * (rl * 0.5)
	d.position = Vector3(mxz.x, h * 0.46, mxz.y)
	d.rotation = Vector3(-atan2(h, rl), atan2(-wd.x, -wd.y), 0.0)
	_add_box_collision(d, dm.size)
	p.add_child(d)
	return 1

func _add_fossilized_steel_ribs(p: Node3D, c: Vector2, count: int, sp: float) -> int:
	var rm := _make_mat(Color(0.24, 0.16, 0.12), 0.78, 0.72)
	for i in range(count):
		var s := -1.0 if (i % 2 == 0) else 1.0
		var rib := MeshInstance3D.new()
		rib.name = "FossilizedSteelRib_%d" % (i + 1)
		rib.set_meta("ballistic_material", "STEEL")
		var r_mesh := BoxMesh.new()
		var rh := _rng.randf_range(4.2, 7.5)
		r_mesh.size = Vector3(0.32, rh, 0.48)
		r_mesh.material = rm
		rib.mesh = r_mesh
		var off := Vector2(s * _rng.randf_range(2.8, sp), (float(i) - count * 0.5) * 2.6)
		rib.position = Vector3(c.x + off.x, rh * 0.42, c.y + off.y)
		rib.rotation = Vector3(_rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.3, 0.3), s * _rng.randf_range(0.38, 0.68))
		_add_box_collision(rib, r_mesh.size)
		p.add_child(rib)
	return count

func _scatter_ambient_layer(label: String, count: int, min_s: float, max_s: float, mesh_fn: Callable) -> int:
	var parent := Node3D.new()
	parent.name = label
	add_child(parent)
	var placed := 0
	for _i in range(count):
		var pos := _find_ambient_pos(min_s * 0.5)
		if pos == Vector2.INF:
			continue
		var su := _rng.randf_range(min_s, max_s)
		var sv := _rng.randf_range(min_s, max_s) if "Structure" in label else su
		var sw := _rng.randf_range(min_s, max_s) if "Structure" in label else su
		var mi: MeshInstance3D = mesh_fn.call(label, su, sv, sw)
		var yaw := _rng.randf() * TAU
		var pitch := _rng.randf_range(-0.35, 0.35) if "Debris" in label else (_rng.randf_range(-0.2, 0.2) if "Skeleton" in label else 0.0)
		var roll := _rng.randf_range(-0.35, 0.35) if "Debris" in label else (_rng.randf_range(-0.15, 0.15) if "Skeleton" in label else 0.0)
		mi.transform = Transform3D.IDENTITY.rotated(Vector3.UP, yaw).rotated(Vector3.RIGHT, pitch).rotated(Vector3.FORWARD, roll)
		var gy := _sample_terrain_y(pos.x, pos.y)
		mi.position = Vector3(pos.x, gy + _ground_y_offset(su, label), pos.y)
		_add_static_collision(mi, su, sv, sw, label)
		parent.add_child(mi)
		_placed_xz.append(pos)
		_placed_radii.append(max(su, sv) * 0.5 + inter_prop_clearance)
		placed += 1
	return placed

func _find_ambient_pos(half_extent: float) -> Vector2:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var candidate := Vector2(_rng.randf_range(-field_half_extent, field_half_extent), _rng.randf_range(-field_half_extent, field_half_extent))
		if candidate.length() < player_clearance or candidate.distance_to(spawn_clearance_point) < player_clearance:
			continue
		var overlap := false
		for idx in range(_placed_xz.size()):
			if candidate.distance_to(_placed_xz[idx]) < (_placed_radii[idx] + half_extent):
				overlap = true
				break
		if not overlap:
			return candidate
	return Vector2.INF

func _sample_terrain_y(x: float, z: float) -> float:
	return PropMeshFactory.sample_terrain_y(x, z)

func _spawn_monumental_landmark() -> Node3D:
	var landmark_root := Node3D.new()
	landmark_root.name = "HorizonLandmark_DarkTower"
	add_child(landmark_root)
	var axis_dir := Vector2(cos(valley_axis_rad), sin(valley_axis_rad)).normalized()
	var ground_y := _sample_terrain_y(landmark_position.x, landmark_position.y)
	landmark_root.position = Vector3(landmark_position.x, ground_y, landmark_position.y)
	var face_yaw := atan2(-axis_dir.x, -axis_dir.y)
	landmark_root.rotation = Vector3.ZERO
	landmark_root.rotate_y(face_yaw)
	landmark_root.rotate_object_local(Vector3.RIGHT, deg_to_rad(4.5))
	landmark_root.rotate_object_local(Vector3.FORWARD, deg_to_rad(-2.0))
	var tower_scene: PackedScene = load("res://assets/architecture/landmarks/dark_tower/dark_tower_beacon_monolith_pylon.glb") as PackedScene
	if tower_scene:
		var tower_inst := tower_scene.instantiate() as Node3D
		tower_inst.name = "DarkTowerMesh"
		var s: float = landmark_height / 1.128711
		tower_inst.scale = Vector3(s, s, s)
		landmark_root.add_child(tower_inst)
	else:
		var spine_mesh_inst := MeshInstance3D.new()
		spine_mesh_inst.name = "SpineObelisk"
		var spine_mesh := BoxMesh.new()
		spine_mesh.size = Vector3(landmark_width, landmark_height, landmark_width * 0.75)
		spine_mesh.material = _make_mat(Color(0.08, 0.075, 0.07, 1.0), 0.88, 0.45)
		spine_mesh_inst.mesh = spine_mesh
		spine_mesh_inst.position = Vector3(0.0, landmark_height * 0.5 - 2.0, 0.0)
		landmark_root.add_child(spine_mesh_inst)
	var beacon := MeshInstance3D.new()
	beacon.name = "KaBeacon"
	var b_sphere := SphereMesh.new()
	b_sphere.radius = 3.5
	b_sphere.height = 7.0
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(1.0, 0.35, 0.05, 1.0)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.42, 0.08, 1.0)
	beacon_mat.emission_energy_multiplier = 18.0
	beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_sphere.material = beacon_mat
	beacon.mesh = b_sphere
	beacon.position = Vector3(0.0, landmark_height + 2.0, 0.0)
	landmark_root.add_child(beacon)
	var light := OmniLight3D.new()
	light.name = "BeaconLight"
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 12.0
	light.omni_range = 120.0
	light.omni_attenuation = 1.3
	beacon.add_child(light)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(landmark_width * 1.8, landmark_height, landmark_width * 1.8)
	col.shape = box
	col.position = Vector3(0.0, landmark_height * 0.5, 0.0)
	sb.add_child(col)
	landmark_root.add_child(sb)
	_placed_xz.append(landmark_position)
	_placed_radii.append(landmark_width * 1.6 + 10.0)
	return landmark_root

func _spawn_waystation_ballistic_range() -> int:
	var range_root := Node3D.new()
	range_root.name = "Vignettes_BallisticRange"
	add_child(range_root)
	var cluster := Node3D.new()
	cluster.name = "CalicheRange_1"
	range_root.add_child(cluster)
	var axis_dir := Vector2(cos(valley_axis_rad), sin(valley_axis_rad)).normalized()
	var right_dir := Vector2(-axis_dir.y, axis_dir.x)
	var distances: Array[float] = [28.0, 48.0, 72.0]
	var lateral_offsets: Array[float] = [-3.5, 0.0, 4.2]
	var placed := 0
	for idx in range(distances.size()):
		var d: float = distances[idx]
		var pos_2d: Vector2 = axis_dir * d + right_dir * lateral_offsets[idx]
		var gy := _sample_terrain_y(pos_2d.x, pos_2d.y)
		var gong := MeshInstance3D.new()
		gong.name = "SteelGongTarget_%dm" % int(d)
		gong.set_meta("ballistic_material", "STEEL")
		gong.set_meta("reactive_target", true)
		var gm := CylinderMesh.new()
		gm.top_radius = 0.55
		gm.bottom_radius = 0.55
		gm.height = 0.08
		gm.material = _make_mat(Color(0.58, 0.34, 0.18), 0.55, 0.85)
		gong.mesh = gm
		gong.position = Vector3(pos_2d.x, gy + 1.35, pos_2d.y)
		gong.rotation = Vector3(PI * 0.5, atan2(-axis_dir.x, -axis_dir.y), 0.0)
		var sb := _add_box_collision(gong, Vector3(1.1, 0.14, 1.1))
		sb.set_meta("ballistic_material", "STEEL")
		sb.set_meta("reactive_target", true)
		cluster.add_child(gong)
		placed += 1
	return placed

func _add_box_collision(parent: Node3D, size: Vector3) -> StaticBody3D:
	return PropMeshFactory.add_box_collision(parent, size)

func _add_cylinder_collision(parent: Node3D, radius: float, height: float) -> StaticBody3D:
	return PropMeshFactory.add_cylinder_collision(parent, radius, height)

func _add_static_collision(mesh: MeshInstance3D, su: float, sv: float, sw: float, label: String) -> void:
	var sb := StaticBody3D.new()
	sb.name = "Collision"
	mesh.add_child(sb)
	var cshape := CollisionShape3D.new()
	var shape: Shape3D
	if "DEBRIS" in label or "Debris" in label:
		shape = SphereShape3D.new()
		(shape as SphereShape3D).radius = su * 0.5
	elif "SKELETON" in label or "Skeleton" in label:
		shape = CapsuleShape3D.new()
		(shape as CapsuleShape3D).radius = su * 0.15
		(shape as CapsuleShape3D).height = su * 0.9
	else:
		shape = BoxShape3D.new()
		(shape as BoxShape3D).size = Vector3(su * 0.9, sv * 0.9, sw * 0.9)
	cshape.shape = shape
	sb.add_child(cshape)

func _ground_y_offset(scale_u: float, label: String) -> float:
	if "DEBRIS" in label or "Debris" in label: return scale_u * 0.08
	elif "SKELETON" in label or "Skeleton" in label: return 0.05
	return scale_u * 0.2

func _build_debris_mesh(_label: String, su: float, _sv: float, _sw: float) -> MeshInstance3D:
	return PropMeshFactory.build_ambient_debris(_rng, su)

func _build_skeleton_mesh(_label: String, su: float, _sv: float, _sw: float) -> MeshInstance3D:
	return PropMeshFactory.build_ambient_skeleton(_rng, su)

func _build_structure_mesh(_label: String, su: float, sv: float, sw: float) -> MeshInstance3D:
	return PropMeshFactory.build_ambient_structure(_rng, su, sv, sw)

func _make_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	return PropMeshFactory.make_mat(color, roughness, metallic)
