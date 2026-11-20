class_name SectorNorthAlkali
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
func _add_cylinder_collision(p: Node3D, r: float, h: float) -> StaticBody3D:
	return scatter._add_cylinder_collision(p, r, h)

func _spawn_north_alkali_landmarks() -> int:
	var group := Node3D.new()
	group.name = "Vignettes_NorthAlkali_Sink"
	scatter.add_child(group)

	var total_placed := 0

	# 1. Ka Survey Beacon Monolith at (+45.0, +680.0)
	var beacon_pos := Vector2(45.0, 680.0)
	var beacon_root := Node3D.new()
	beacon_root.name = "KaSurveyBeacon_Monolith"
	var beacon_y := _sample_terrain_y(beacon_pos.x, beacon_pos.y)
	beacon_root.position = Vector3(beacon_pos.x, beacon_y, beacon_pos.y)
	group.add_child(beacon_root)

	scatter._placed_xz.append(beacon_pos)
	scatter._placed_radii.append(18.0)

	total_placed += _generate_ka_beacon_monolith(beacon_root)

	# 2. Armored Power Conduits
	var conduit_sites: Array[Vector2] = [
		Vector2(35.0, 665.0),
		Vector2(55.0, 695.0)
	]
	for idx in range(conduit_sites.size()):
		var c_site := conduit_sites[idx]
		var c_root := Node3D.new()
		c_root.name = "ArmoredPowerConduit_%d" % (idx + 1)
		var c_y := _sample_terrain_y(c_site.x, c_site.y)
		c_root.position = Vector3(c_site.x, c_y, c_site.y)
		group.add_child(c_root)

		scatter._placed_xz.append(c_site)
		scatter._placed_radii.append(8.0)
		total_placed += _generate_armored_conduit(c_root, idx)

	# 3. Crusty Alkali Mineral Mounds
	var mound_sites: Array[Vector2] = [
		Vector2(-40.0, 640.0),
		Vector2(70.0, 630.0)
	]
	for idx in range(mound_sites.size()):
		var m_site := mound_sites[idx]
		var m_root := Node3D.new()
		m_root.name = "AlkaliMineralMound_%d" % (idx + 1)
		var m_y := _sample_terrain_y(m_site.x, m_site.y)
		m_root.position = Vector3(m_site.x, m_y, m_site.y)
		group.add_child(m_root)

		scatter._placed_xz.append(m_site)
		scatter._placed_radii.append(6.0)
		total_placed += _generate_mineral_mound(m_root, idx)

	return total_placed

func _generate_ka_beacon_monolith(parent: Node3D) -> int:
	var placed := 0

	# 1. Stepped Hexagonal Foundation Plinth
	var plinth_mat := _make_mat(Color(0.25, 0.24, 0.22), 0.92, 0.15)
	for p_step in range(2):
		var plinth := MeshInstance3D.new()
		plinth.name = "HexagonalPlinthStep_%d" % (p_step + 1)
		plinth.set_meta("ballistic_material", "CONCRETE")
		plinth.set_meta("landmark_type", "MONOLITH_PLINTH")
		var cyl := CylinderMesh.new()
		var p_rad := 5.2 - float(p_step) * 1.4
		cyl.top_radius = p_rad
		cyl.bottom_radius = p_rad + 0.3
		cyl.height = 0.55
		cyl.radial_segments = 6
		cyl.material = plinth_mat
		plinth.mesh = cyl
		plinth.position = Vector3(0.0, 0.28 + float(p_step) * 0.52, 0.0)
		_add_cylinder_collision(plinth, p_rad, 0.55)
		parent.add_child(plinth)
		placed += 1

	# 2. Brutalist Split Dark-Iron Pylon Monument (~8.5m tall)
	var iron_mat := _make_mat(Color(0.10, 0.11, 0.13), 0.35, 0.90)
	var pylon_h := 8.5
	var pylon_w := 1.35
	var pylon_d := 1.85
	var split_gap := 0.75

	for side in [-1.0, 1.0]:
		var pylon := MeshInstance3D.new()
		var s_name := "Left" if side < 0 else "Right"
		pylon.name = "SplitPylon_%s" % s_name
		pylon.set_meta("ballistic_material", "STEEL")
		pylon.set_meta("landmark_type", "KA_BEACON_MONOLITH")

		var bm := BoxMesh.new()
		bm.size = Vector3(pylon_w, pylon_h, pylon_d)
		bm.material = iron_mat
		pylon.mesh = bm
		var side_f: float = float(side)
		var x_pos: float = side_f * (pylon_w * 0.5 + split_gap * 0.5)
		pylon.position = Vector3(x_pos, 1.0 + pylon_h * 0.5, 0.0)
		_add_box_collision(pylon, bm.size)
		parent.add_child(pylon)
		placed += 1

		# Cyan Positronic Rune Inlays along the vertical edge
		var rune_strip := MeshInstance3D.new()
		rune_strip.name = "CyanRuneInlay_%s" % s_name
		rune_strip.set_meta("ballistic_material", "STEEL")
		var r_mesh := BoxMesh.new()
		r_mesh.size = Vector3(0.08, pylon_h * 0.75, 0.12)
		var rune_mat := StandardMaterial3D.new()
		rune_mat.albedo_color = Color(0.12, 0.85, 0.95, 1.0)
		rune_mat.emission_enabled = true
		rune_mat.emission = Color(0.15, 0.88, 1.0, 1.0)
		rune_mat.emission_energy_multiplier = 4.5
		rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		r_mesh.material = rune_mat
		rune_strip.mesh = r_mesh
		rune_strip.position = Vector3(-side * (pylon_w * 0.48), 0.0, pylon_d * 0.48)
		pylon.add_child(rune_strip)
		placed += 1

	# 3. Central Vertical Aperture Glowing Electric-Blue Energy Core
	var core_node := MeshInstance3D.new()
	core_node.name = "ElectricBlueEnergyCore"
	core_node.set_meta("ballistic_material", "STEEL")
	core_node.set_meta("landmark_type", "KA_BEACON_MONOLITH")
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.55
	core_mesh.height = 1.6
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.15, 0.75, 1.0, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.20, 0.85, 1.0, 1.0)
	core_mat.emission_energy_multiplier = 16.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mesh.material = core_mat
	core_node.mesh = core_mesh
	core_node.position = Vector3(0.0, 1.0 + pylon_h * 0.52, 0.0)

	var core_light := OmniLight3D.new()
	core_light.name = "BeaconCoreLight"
	core_light.light_color = Color(0.18, 0.82, 1.0)
	core_light.light_energy = 9.5
	core_light.omni_range = 75.0
	core_light.omni_attenuation = 1.15
	core_node.add_child(core_light)

	parent.add_child(core_node)
	placed += 1

	return placed

func _generate_armored_conduit(parent: Node3D, idx: int) -> int:
	var placed := 0
	var conduit_mat := _make_mat(Color(0.22, 0.20, 0.18), 0.65, 0.80)

	var pipe := MeshInstance3D.new()
	pipe.name = "ArmoredConduitTrunk"
	pipe.set_meta("ballistic_material", "STEEL")
	pipe.set_meta("landmark_type", "POWER_CONDUIT")

	var pm := CylinderMesh.new()
	var p_rad := 0.38
	var p_len := 8.0
	pm.top_radius = p_rad
	pm.bottom_radius = p_rad
	pm.height = p_len
	pm.material = conduit_mat
	pipe.mesh = pm

	pipe.position = Vector3(0.0, p_rad * 0.7, 0.0)
	pipe.rotation = Vector3(PI * 0.5, deg_to_rad(float(idx) * 45.0 + 20.0), 0.0)
	_add_cylinder_collision(pipe, p_rad, p_len)
	parent.add_child(pipe)
	placed += 1

	# Metal collar clamp
	var collar := MeshInstance3D.new()
	collar.name = "ConduitCollarClamp"
	collar.set_meta("ballistic_material", "STEEL")
	var cm := CylinderMesh.new()
	cm.top_radius = p_rad * 1.35
	cm.bottom_radius = p_rad * 1.35
	cm.height = 0.4
	cm.material = _make_mat(Color(0.28, 0.26, 0.24), 0.75, 0.60)
	collar.mesh = cm
	collar.position = Vector3(0.0, 0.0, 1.5)
	_add_cylinder_collision(collar, p_rad * 1.35, 0.4)
	pipe.add_child(collar)
	placed += 1

	return placed

func _generate_mineral_mound(parent: Node3D, idx: int) -> int:
	var placed := 0
	var mound_mat := _make_mat(Color(0.88, 0.84, 0.68), 0.32, 0.10)

	var mound := MeshInstance3D.new()
	mound.name = "SulfurAlkaliMound"
	mound.set_meta("ballistic_material", "CONCRETE")
	mound.set_meta("landmark_type", "MINERAL_MOUND")

	var bm := SphereMesh.new()
	var m_rad := 2.2
	bm.radius = m_rad
	bm.height = 1.4
	bm.material = mound_mat
	mound.mesh = bm
	mound.position = Vector3(0.0, 0.35, 0.0)
	_add_box_collision(mound, Vector3(m_rad * 1.8, 1.4, m_rad * 1.8))
	parent.add_child(mound)
	placed += 1

	return placed

# ─── Node 6 The Great Shifting Erg Landmarks ─────────────────────────────────
## Populates landmark props unique to The Great Shifting Erg (Node 6):
## 1. Tilted Old-Ones Brutalist Ruin Superstructure at (+680.0, -20.0):
##    A massive, canted (~32° tilt) reinforced dark-concrete and rusted structural-steel
##    girder superstructure (~22m x 16m x 15m) half-buried in the mega-dune slope,
##    featuring external steel I-beam trusses, recessed brutalist paneling, and half-buried
##    hexagonal obsidian obelisk ribs.
## 2. Protruding Half-Buried Gantry Struts in neighbouring dune troughs.
## 3. Wind-Scoured Obsidian Boundary Pylons along the dune crest approaches.
