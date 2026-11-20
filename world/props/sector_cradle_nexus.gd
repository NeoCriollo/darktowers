class_name SectorCradleNexus
extends RefCounted

## Modular prop and landmark builder for "Dark Towers: The Path of Ka".

var scatter: PropScatter

func _init(p_scatter: PropScatter) -> void:
	scatter = p_scatter

func _sample_terrain_y(x: float, z: float) -> float:
	return scatter._sample_terrain_y(x, z)
func _make_mat(c: Color, r: float, m: float) -> StandardMaterial3D:
	return scatter._make_mat(c, r, m)
func _add_box_collision(p: Node3D, s: Vector3) -> StaticBody3D:
	return scatter._add_box_collision(p, s)

func _spawn_cradle_nexus_landmarks() -> int:
	var group := Node3D.new()
	group.name = "Vignettes_Cradle_Nexus"
	scatter.add_child(group)

	var total_placed := 0

	# 1. Central Nexus Crossroads Stone Waymarkers (near 0, 0)
	var waymarker_coords: Array[Vector2] = [
		Vector2(0.0, 6.0),
		Vector2(0.0, -6.0),
		Vector2(6.0, 0.0)
	]

	for i in range(waymarker_coords.size()):
		var coord := waymarker_coords[i]
		var wm_root := Node3D.new()
		wm_root.name = "CradleWaymarker_%d" % (i + 1)
		var base_y := _sample_terrain_y(coord.x, coord.y)
		wm_root.position = Vector3(coord.x, base_y, coord.y)
		group.add_child(wm_root)

		scatter._placed_xz.append(coord)
		scatter._placed_radii.append(5.0)

		total_placed += _generate_stone_waymarker(wm_root, i)

	# 2. Ruined Survey Tripod & Warning Barricade at NE Scenic Overlook (+140, +140)
	var overlook_site := Vector2(140.0, 140.0)
	var ov_root := Node3D.new()
	ov_root.name = "ThinnyScenicOverlook"
	var ov_y := _sample_terrain_y(overlook_site.x, overlook_site.y)
	ov_root.position = Vector3(overlook_site.x, ov_y, overlook_site.y)
	group.add_child(ov_root)

	scatter._placed_xz.append(overlook_site)
	scatter._placed_radii.append(12.0)

	total_placed += _generate_overlook_ruins(ov_root)

	# 3. Dead Twisted Desert Scrub Clusters in limestone crevices
	var scrub_coords: Array[Vector2] = [
		Vector2(-65.0, -45.0),
		Vector2(75.0, -60.0),
		Vector2(120.0, 110.0)
	]

	for k in range(scrub_coords.size()):
		var sc_coord := scrub_coords[k]
		var sc_root := Node3D.new()
		sc_root.name = "DesertScrub_%d" % (k + 1)
		var sc_y := _sample_terrain_y(sc_coord.x, sc_coord.y)
		sc_root.position = Vector3(sc_coord.x, sc_y, sc_coord.y)
		group.add_child(sc_root)

		scatter._placed_xz.append(sc_coord)
		scatter._placed_radii.append(4.0)

		total_placed += _generate_desert_scrub_cluster(sc_root, k)

	return total_placed

func _generate_stone_waymarker(parent: Node3D, index: int) -> int:
	var placed := 0

	# Heavy limestone plinth base
	var plinth := MeshInstance3D.new()
	plinth.name = "WaymarkerPlinth"
	plinth.set_meta("ballistic_material", "CONCRETE")
	var pl_mesh := BoxMesh.new()
	var pl_sz := Vector3(0.95, 0.35, 0.85)
	pl_mesh.size = pl_sz
	pl_mesh.material = _make_mat(Color(0.76, 0.72, 0.62), 0.94, 0.02)
	plinth.mesh = pl_mesh
	plinth.position = Vector3(0.0, pl_sz.y * 0.5, 0.0)
	_add_box_collision(plinth, pl_sz)
	parent.add_child(plinth)
	placed += 1

	# Upright carved stone stele / obelisk
	var stele := MeshInstance3D.new()
	stele.name = "StoneStele"
	stele.set_meta("ballistic_material", "CONCRETE")
	stele.set_meta("landmark_type", "STONE_WAYMARKER")
	var st_mesh := BoxMesh.new()
	var st_sz := Vector3(0.48, scatter._rng.randf_range(2.2, 2.7), 0.38)
	st_mesh.size = st_sz
	st_mesh.material = _make_mat(Color(0.82, 0.78, 0.68), 0.92, 0.0)
	stele.mesh = st_mesh
	stele.position = Vector3(0.0, pl_sz.y + st_sz.y * 0.48, 0.0)
	stele.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(-4.0, 4.0)), scatter._rng.randf() * TAU, deg_to_rad(scatter._rng.randf_range(-4.0, 4.0)))
	_add_box_collision(stele, st_sz)
	parent.add_child(stele)
	placed += 1

	return placed

func _generate_overlook_ruins(parent: Node3D) -> int:
	var placed := 0

	# 1. Ruined surveyor brass/iron tripod station looking NE toward Dark Tower & Abyss
	var tripod_root := Node3D.new()
	tripod_root.name = "SurveyTripodStation"
	tripod_root.position = Vector3(-1.0, 0.0, 1.0)
	parent.add_child(tripod_root)

	var metal_mat := _make_mat(Color(0.32, 0.28, 0.22), 0.75, 0.65)
	# 3 angled tripod legs
	for leg_i in range(3):
		var leg_yaw: float = float(leg_i) * (TAU / 3.0) + deg_to_rad(15.0)
		var leg := MeshInstance3D.new()
		leg.name = "TripodLeg_%d" % (leg_i + 1)
		leg.set_meta("ballistic_material", "STEEL")
		var lm := CylinderMesh.new()
		lm.top_radius = 0.025
		lm.bottom_radius = 0.035
		lm.height = 1.35
		lm.material = metal_mat
		leg.mesh = lm
		leg.position = Vector3(cos(leg_yaw) * 0.32, 0.62, sin(leg_yaw) * 0.32)
		leg.rotation = Vector3(deg_to_rad(22.0) * sin(leg_yaw), 0.0, deg_to_rad(22.0) * cos(leg_yaw))
		tripod_root.add_child(leg)
		placed += 1

	# Broken optic housing on top
	var optic := MeshInstance3D.new()
	optic.name = "BrokenTheodoliteOptic"
	optic.set_meta("ballistic_material", "STEEL")
	optic.set_meta("landmark_type", "SURVEY_OVERLOOK")
	var om := BoxMesh.new()
	om.size = Vector3(0.32, 0.28, 0.42)
	om.material = metal_mat
	optic.mesh = om
	optic.position = Vector3(0.0, 1.35, 0.0)
	# Pointing toward Dark Tower (+45 deg NE)
	optic.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(45.0), deg_to_rad(6.0))
	_add_box_collision(optic, om.size)
	tripod_root.add_child(optic)
	placed += 1

	# 2. Precipice Warning Barricade Rail along cliff edge
	var barricade := MeshInstance3D.new()
	barricade.name = "OverlookWarningBarricade"
	barricade.set_meta("ballistic_material", "STEEL")
	barricade.set_meta("landmark_type", "SURVEY_OVERLOOK")
	var bm := BoxMesh.new()
	var b_sz := Vector3(3.2, 0.95, 0.15)
	bm.size = b_sz
	bm.material = _make_mat(Color(0.48, 0.24, 0.16), 0.85, 0.72)
	barricade.mesh = bm
	barricade.position = Vector3(2.5, 0.55, 2.5)
	barricade.rotation.y = deg_to_rad(-45.0) # Perpendicular to NE drop-off
	_add_box_collision(barricade, b_sz)
	parent.add_child(barricade)
	placed += 1

	return placed

func _generate_desert_scrub_cluster(parent: Node3D, cluster_idx: int) -> int:
	var placed := 0
	var wood_mat := _make_mat(Color(0.26, 0.22, 0.18), 0.92, 0.0)

	var branch_count := scatter._rng.randi_range(3, 5)
	for b_idx in range(branch_count):
		var branch := MeshInstance3D.new()
		branch.name = "ScrubBranch_%d" % (b_idx + 1)
		branch.set_meta("ballistic_material", "WOOD")
		branch.set_meta("landmark_type", "DESERT_SCRUB")

		var b_mesh := CapsuleMesh.new()
		var b_len := scatter._rng.randf_range(0.65, 1.1)
		b_mesh.radius = 0.05
		b_mesh.height = b_len
		b_mesh.material = wood_mat
		branch.mesh = b_mesh

		var b_yaw := float(b_idx) * (TAU / float(branch_count)) + scatter._rng.randf_range(-0.3, 0.3)
		var b_spread := scatter._rng.randf_range(0.25, 0.6)
		branch.position = Vector3(cos(b_yaw) * b_spread, b_len * 0.45, sin(b_yaw) * b_spread)
		branch.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(25.0, 50.0)), b_yaw, deg_to_rad(scatter._rng.randf_range(-15.0, 15.0)))
		_add_box_collision(branch, Vector3(0.18, b_len, 0.18))
		parent.add_child(branch)
		placed += 1

	return placed

# ─── Node 4 Rust-Gorge Defile Landmarks ──────────────────────────────────────
## Populates landmark props unique to Rust-Gorge Defile (Node 4):
## 1. Collapsed Overpass & Girder Tangled Choke: massive rusted steel I-beams wedged
##    diagonally across the canyon floor, fractured highway concrete slabs, and twisted rebar.
## 2. Corroded Industrial Pipelines: tangled networks of rusted steel pipes running
##    along the rocky floor and half-buried in talus rockfalls.
