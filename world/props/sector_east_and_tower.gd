class_name SectorEastAndTower
extends RefCounted
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
# Aliases for contract specification compatibility
func _generate_half_buried_megastructure(parent: Node3D) -> int:
	return _generate_old_ones_megastructure(parent)

func _generate_dune_derelict(parent: Node3D, idx: int) -> int:
	return _generate_gantry_strut(parent, idx)

func _spawn_monolith_pass_landmarks() -> int:
	return _spawn_tower_threshold_landmarks()

func _generate_dark_tower_perimeter_fortress(parent: Node3D) -> int:
	return _generate_dark_tower_citadel(parent)

func _generate_ancient_defense_turret(parent: Node3D, idx: int) -> int:
	return _generate_czech_hedgehog(parent, idx)

func _generate_radiation_bunker_hatch(parent: Node3D, idx: int) -> int:
	return _generate_concertina_wire(parent, idx)

func _spawn_east_dunes_landmarks() -> int:
	var group := Node3D.new()
	group.name = "Vignettes_EastDunes_Erg"
	scatter.add_child(group)
	var total_placed := 0
	var ruin_pos := Vector2(680.0, -20.0)
	var ruin_root := Node3D.new()
	ruin_root.name = "OldOnesMegastructureRuin"
	var ruin_y := _sample_terrain_y(ruin_pos.x, ruin_pos.y)
	ruin_root.position = Vector3(ruin_pos.x, ruin_y, ruin_pos.y)
	group.add_child(ruin_root)
	scatter._placed_xz.append(ruin_pos)
	scatter._placed_radii.append(26.0)
	total_placed += _generate_old_ones_megastructure(ruin_root)
	var gantry_sites: Array[Vector2] = [
		Vector2(655.0, 15.0),
		Vector2(635.0, -45.0)
	]
	for idx in range(gantry_sites.size()):
		var g_site := gantry_sites[idx]
		var g_root := Node3D.new()
		g_root.name = "GantryStrutCluster_%d" % (idx + 1)
		var g_y := _sample_terrain_y(g_site.x, g_site.y)
		g_root.position = Vector3(g_site.x, g_y, g_site.y)
		group.add_child(g_root)
		scatter._placed_xz.append(g_site)
		scatter._placed_radii.append(10.0)
		total_placed += _generate_gantry_strut(g_root, idx)
	var pylon_sites: Array[Vector2] = [
		Vector2(715.0, 65.0)
	]
	for idx in range(pylon_sites.size()):
		var p_site := pylon_sites[idx]
		var p_root := Node3D.new()
		p_root.name = "ObsidianBoundaryPylon_%d" % (idx + 1)
		var p_y := _sample_terrain_y(p_site.x, p_site.y)
		p_root.position = Vector3(p_site.x, p_y, p_site.y)
		group.add_child(p_root)
		scatter._placed_xz.append(p_site)
		scatter._placed_radii.append(8.0)
		total_placed += _generate_obsidian_pylon(p_root, idx)
	return total_placed

func _generate_old_ones_megastructure(parent: Node3D) -> int:
	var placed := 0
	var concrete_mat := _make_mat(Color(0.22, 0.21, 0.20), 0.92, 0.12)
	var steel_mat := _make_mat(Color(0.28, 0.18, 0.12), 0.74, 0.82)
	var obsidian_mat := _make_mat(Color(0.06, 0.06, 0.07), 0.22, 0.90)
	var canted_rig := Node3D.new()
	canted_rig.name = "CantedSuperstructureRig"
	canted_rig.rotation = Vector3(deg_to_rad(-26.0), deg_to_rad(18.0), deg_to_rad(14.0))
	parent.add_child(canted_rig)
	var main_block := MeshInstance3D.new()
	main_block.name = "MonolithicConcreteHull"
	main_block.set_meta("ballistic_material", "CONCRETE")
	main_block.set_meta("landmark_type", "OLD_ONES_MEGASTRUCTURE")
	var bm := BoxMesh.new()
	bm.size = Vector3(22.0, 15.0, 16.0)
	bm.material = concrete_mat
	main_block.mesh = bm
	main_block.position = Vector3(0.0, 7.5, 0.0)
	_add_box_collision(main_block, bm.size)
	canted_rig.add_child(main_block)
	placed += 1
	for i in range(2):
		var panel := MeshInstance3D.new()
		panel.name = "RecessedBrutalistPanel_%d" % (i + 1)
		panel.set_meta("ballistic_material", "CONCRETE")
		var pm := BoxMesh.new()
		pm.size = Vector3(18.0, 4.5, 0.6)
		pm.material = _make_mat(Color(0.16, 0.15, 0.14), 0.95, 0.05)
		panel.mesh = pm
		var z_offset := 8.1 if i == 0 else -8.1
		panel.position = Vector3(0.0, 7.5 + (float(i) - 0.5) * 3.0, z_offset)
		_add_box_collision(panel, pm.size)
		canted_rig.add_child(panel)
		placed += 1
	for t_idx in range(3):
		var truss := MeshInstance3D.new()
		truss.name = "ExternalSteelTruss_%d" % (t_idx + 1)
		truss.set_meta("ballistic_material", "STEEL")
		truss.set_meta("landmark_type", "OLD_ONES_MEGASTRUCTURE")
		var tm := BoxMesh.new()
		tm.size = Vector3(0.85, 17.5, 1.2)
		tm.material = steel_mat
		truss.mesh = tm
		truss.position = Vector3((float(t_idx) - 1.0) * 8.5, 8.2, 8.4)
		_add_box_collision(truss, tm.size)
		canted_rig.add_child(truss)
		placed += 1
	for r_idx in range(2):
		var rib := MeshInstance3D.new()
		rib.name = "ObsidianObeliskRib_%d" % (r_idx + 1)
		rib.set_meta("ballistic_material", "STEEL")
		rib.set_meta("landmark_type", "OLD_ONES_MEGASTRUCTURE")
		var cm := CylinderMesh.new()
		cm.top_radius = 1.1
		cm.bottom_radius = 1.8
		cm.height = 11.5
		cm.radial_segments = 6
		cm.material = obsidian_mat
		rib.mesh = cm
		var rib_x := -10.0 + float(r_idx) * 20.0
		rib.position = Vector3(rib_x, 4.5, -9.5)
		rib.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(float(r_idx) * 60.0), deg_to_rad(24.0))
		_add_cylinder_collision(rib, 1.5, 11.5)
		parent.add_child(rib)
		placed += 1
	return placed

func _generate_gantry_strut(parent: Node3D, idx: int) -> int:
	var placed := 0
	var steel_mat := _make_mat(Color(0.26, 0.17, 0.12), 0.76, 0.80)
	var gantry := MeshInstance3D.new()
	gantry.name = "ProtrudingGantryStrut"
	gantry.set_meta("ballistic_material", "STEEL")
	gantry.set_meta("landmark_type", "GANTRY_STRUT")
	var gm := BoxMesh.new()
	var g_len := 9.5
	gm.size = Vector3(0.65, g_len, 0.85)
	gm.material = steel_mat
	gantry.mesh = gm
	gantry.position = Vector3(0.0, g_len * 0.4, 0.0)
	gantry.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(float(idx) * 45.0 + 30.0), deg_to_rad(15.0))
	_add_box_collision(gantry, gm.size)
	parent.add_child(gantry)
	placed += 1
	var brace := MeshInstance3D.new()
	brace.name = "GantryCrossBrace"
	brace.set_meta("ballistic_material", "STEEL")
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 5.5, 0.45)
	bm.material = steel_mat
	brace.mesh = bm
	brace.position = Vector3(1.2, 2.5, 0.0)
	brace.rotation = Vector3(deg_to_rad(45.0), 0.0, deg_to_rad(-30.0))
	_add_box_collision(brace, bm.size)
	gantry.add_child(brace)
	placed += 1
	return placed

func _generate_obsidian_pylon(parent: Node3D, idx: int) -> int:
	var placed := 0
	var obs_mat := _make_mat(Color(0.07, 0.07, 0.08), 0.25, 0.85)
	var pylon := MeshInstance3D.new()
	pylon.name = "ObsidianBoundaryPylon"
	pylon.set_meta("ballistic_material", "STEEL")
	pylon.set_meta("landmark_type", "OBSIDIAN_PYLON")
	var cm := CylinderMesh.new()
	cm.top_radius = 0.65
	cm.bottom_radius = 1.25
	cm.height = 7.5
	cm.radial_segments = 6
	cm.material = obs_mat
	pylon.mesh = cm
	pylon.position = Vector3(0.0, 3.2, 0.0)
	pylon.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(float(idx) * 30.0), deg_to_rad(12.0))
	_add_cylinder_collision(pylon, 1.0, 7.5)
	parent.add_child(pylon)
	placed += 1
	return placed

func _spawn_tower_threshold_landmarks() -> int:
	var group := Node3D.new()
	group.name = "Vignettes_TowerThreshold_Citadel"
	scatter.add_child(group)
	var total_placed := 0
	var tower_pos := Vector2(700.0, 700.0)
	var tower_root := Node3D.new()
	tower_root.name = "DarkTowerCitadelSpire"
	var tower_y := _sample_terrain_y(tower_pos.x, tower_pos.y)
	tower_root.position = Vector3(tower_pos.x, tower_y, tower_pos.y)
	group.add_child(tower_root)
	scatter._placed_xz.append(tower_pos)
	scatter._placed_radii.append(32.0)
	total_placed += _generate_dark_tower_citadel(tower_root)
	var hedgehog_coords: Array[Vector2] = [
		Vector2(568.0, 565.0),
		Vector2(574.0, 572.0),
		Vector2(580.0, 578.0),
		Vector2(586.0, 584.0),
		Vector2(594.0, 592.0),
		Vector2(600.0, 598.0),
		Vector2(606.0, 604.0),
		Vector2(612.0, 612.0)
	]
	for idx in range(hedgehog_coords.size()):
		var h_pos := hedgehog_coords[idx]
		var h_root := Node3D.new()
		h_root.name = "CzechHedgehog_%d" % (idx + 1)
		var h_y := _sample_terrain_y(h_pos.x, h_pos.y)
		h_root.position = Vector3(h_pos.x, h_y, h_pos.y)
		group.add_child(h_root)
		scatter._placed_xz.append(h_pos)
		scatter._placed_radii.append(2.5)
		total_placed += _generate_czech_hedgehog(h_root, idx)
	var wire_coords: Array[Vector2] = [
		Vector2(577.0, 575.0),
		Vector2(590.0, 588.0),
		Vector2(603.0, 601.0)
	]
	for idx in range(wire_coords.size()):
		var w_pos := wire_coords[idx]
		var w_root := Node3D.new()
		w_root.name = "ConcertinaWireBarrier_%d" % (idx + 1)
		var w_y := _sample_terrain_y(w_pos.x, w_pos.y)
		w_root.position = Vector3(w_pos.x, w_y, w_pos.y)
		group.add_child(w_root)
		scatter._placed_xz.append(w_pos)
		scatter._placed_radii.append(3.0)
		total_placed += _generate_concertina_wire(w_root, idx)
	var wreck_configs: Array[Dictionary] = [
		{
			"pos": Vector2(565.0, 575.0),
			"name": "ArmoredWreck_MainBattleTank",
			"type": "ARMORED_WRECK",
			"size": Vector3(4.8, 2.6, 7.8),
			"yaw": 35.0
		},
		{
			"pos": Vector2(615.0, 605.0),
			"name": "ArmoredWreck_APC",
			"type": "ARMORED_WRECK",
			"size": Vector3(3.8, 2.4, 6.5),
			"yaw": -50.0
		}
	]
	for idx in range(wreck_configs.size()):
		var wc: Dictionary = wreck_configs[idx]
		var w_pos: Vector2 = wc["pos"]
		var wreck_root := Node3D.new()
		wreck_root.name = wc["name"]
		var wreck_y := _sample_terrain_y(w_pos.x, w_pos.y)
		wreck_root.position = Vector3(w_pos.x, wreck_y, w_pos.y)
		wreck_root.rotation.y = deg_to_rad(wc["yaw"])
		group.add_child(wreck_root)
		scatter._placed_xz.append(w_pos)
		scatter._placed_radii.append(5.0)
		total_placed += _generate_armored_wreck(wreck_root, wc)
	return total_placed

func _generate_dark_tower_citadel(parent: Node3D) -> int:
	var placed := 0
	var basalt_mat := _make_mat(Color(0.06, 0.05, 0.07), 0.22, 0.90)
	var iron_mat := _make_mat(Color(0.12, 0.10, 0.11), 0.38, 0.85)
	var crimson_em := StandardMaterial3D.new()
	crimson_em.albedo_color = Color(0.95, 0.12, 0.10, 1.0)
	crimson_em.emission_enabled = true
	crimson_em.emission = Color(0.95, 0.12, 0.10, 1.0)
	crimson_em.emission_energy_multiplier = 4.0
	crimson_em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for t_idx in range(4):
		var angle := float(t_idx) * (PI * 0.5) + (PI * 0.25)
		var tooth := MeshInstance3D.new()
		tooth.name = "BasalMonolithTooth_%d" % (t_idx + 1)
		tooth.set_meta("ballistic_material", "STEEL")
		tooth.set_meta("landmark_type", "DARK_TOWER_SPIRE")
		var tm := CylinderMesh.new()
		tm.top_radius = 2.0
		tm.bottom_radius = 3.8
		tm.height = 14.0
		tm.radial_segments = 6
		tm.material = basalt_mat
		tooth.mesh = tm
		var rad_dist := 12.5
		tooth.position = Vector3(cos(angle) * rad_dist, 6.0, sin(angle) * rad_dist)
		tooth.rotation = Vector3(sin(angle) * 0.15, -angle, cos(angle) * 0.15)
		_add_cylinder_collision(tooth, 3.2, 14.0)
		parent.add_child(tooth)
		placed += 1
	var tiers: Array[Dictionary] = [
		{ "radius": 9.0, "height": 24.0, "y": 12.0, "name": "CitadelSpire_Tier1_Base" },
		{ "radius": 6.8, "height": 26.0, "y": 37.0, "name": "CitadelSpire_Tier2_Mid" },
		{ "radius": 4.5, "height": 22.0, "y": 61.0, "name": "CitadelSpire_Tier3_Crown" }
	]
	for tier_idx in range(tiers.size()):
		var t_info: Dictionary = tiers[tier_idx]
		var tier_mesh := MeshInstance3D.new()
		tier_mesh.name = t_info["name"]
		tier_mesh.set_meta("ballistic_material", "STEEL")
		tier_mesh.set_meta("landmark_type", "DARK_TOWER_SPIRE")
		var cyl := CylinderMesh.new()
		cyl.top_radius = t_info["radius"] * 0.88
		cyl.bottom_radius = t_info["radius"]
		cyl.height = t_info["height"]
		cyl.radial_segments = 8
		cyl.material = basalt_mat
		tier_mesh.mesh = cyl
		tier_mesh.position = Vector3(0.0, t_info["y"], 0.0)
		_add_cylinder_collision(tier_mesh, t_info["radius"], t_info["height"])
		parent.add_child(tier_mesh)
		placed += 1
	for r_idx in range(4):
		var r_angle := float(r_idx) * (PI * 0.5)
		var rib := MeshInstance3D.new()
		rib.name = "CitadelButtressRib_%d" % (r_idx + 1)
		rib.set_meta("ballistic_material", "STEEL")
		rib.set_meta("landmark_type", "DARK_TOWER_SPIRE")
		var rm := BoxMesh.new()
		rm.size = Vector3(1.4, 46.0, 3.2)
		rm.material = iron_mat
		rib.mesh = rm
		var r_dist := 8.2
		rib.position = Vector3(cos(r_angle) * r_dist, 23.0, sin(r_angle) * r_dist)
		rib.rotation.y = -r_angle
		_add_box_collision(rib, rm.size)
		parent.add_child(rib)
		placed += 1
	for a_idx in range(4):
		var a_angle := float(a_idx) * (PI * 0.5) + (PI * 0.25)
		var slit := MeshInstance3D.new()
		slit.name = "CrimsonSlitAperture_%d" % (a_idx + 1)
		slit.set_meta("ballistic_material", "STEEL")
		slit.set_meta("landmark_type", "DARK_TOWER_SPIRE")
		var sm := BoxMesh.new()
		sm.size = Vector3(0.35, 14.0, 0.25)
		sm.material = crimson_em
		slit.mesh = sm
		var a_dist := 6.7
		slit.position = Vector3(cos(a_angle) * a_dist, 36.0, sin(a_angle) * a_dist)
		slit.rotation.y = -a_angle
		parent.add_child(slit)
		placed += 1
	return placed

func _generate_czech_hedgehog(parent: Node3D, idx: int) -> int:
	var placed := 0
	var steel_mat := _make_mat(Color(0.24, 0.22, 0.21), 0.75, 0.85)
	var beam_len := 2.6
	var beam_thick := 0.22
	var angles: Array[Vector3] = [
		Vector3(deg_to_rad(35.0), deg_to_rad(float(idx) * 25.0), deg_to_rad(20.0)),
		Vector3(deg_to_rad(-35.0), deg_to_rad(float(idx) * 25.0 + 90.0), deg_to_rad(20.0)),
		Vector3(deg_to_rad(0.0), deg_to_rad(float(idx) * 25.0 + 45.0), deg_to_rad(70.0))
	]
	for b_idx in range(angles.size()):
		var beam := MeshInstance3D.new()
		beam.name = "HedgehogBeam_%d" % (b_idx + 1)
		beam.set_meta("ballistic_material", "STEEL")
		beam.set_meta("landmark_type", "CZECH_HEDGEHOG")
		var bm := BoxMesh.new()
		bm.size = Vector3(beam_thick, beam_thick, beam_len)
		bm.material = steel_mat
		beam.mesh = bm
		beam.position = Vector3(0.0, 1.1, 0.0)
		beam.rotation = angles[b_idx]
		_add_box_collision(beam, bm.size)
		parent.add_child(beam)
		placed += 1
	return placed

func _generate_concertina_wire(parent: Node3D, idx: int) -> int:
	var placed := 0
	var wire_mat := _make_mat(Color(0.30, 0.28, 0.27), 0.65, 0.90)
	var wire := MeshInstance3D.new()
	wire.name = "ConcertinaWireCoil"
	wire.set_meta("ballistic_material", "STEEL")
	wire.set_meta("landmark_type", "CONCERTINA_WIRE")
	var cm := CylinderMesh.new()
	cm.top_radius = 0.65
	cm.bottom_radius = 0.65
	cm.height = 4.5
	cm.radial_segments = 8
	cm.material = wire_mat
	wire.mesh = cm
	wire.position = Vector3(0.0, 0.65, 0.0)
	wire.rotation = Vector3(0.0, deg_to_rad(float(idx) * 35.0 + 45.0), deg_to_rad(90.0))
	_add_cylinder_collision(wire, 0.65, 4.5)
	parent.add_child(wire)
	placed += 1
	return placed

func _generate_armored_wreck(parent: Node3D, config: Dictionary) -> int:
	var placed := 0
	var armor_mat := _make_mat(Color(0.20, 0.16, 0.14), 0.82, 0.70)
	var rusted_hull_mat := _make_mat(Color(0.16, 0.12, 0.11), 0.90, 0.40)
	var sz: Vector3 = config["size"]
	var hull := MeshInstance3D.new()
	hull.name = "ArmoredHull"
	hull.set_meta("ballistic_material", "STEEL")
	hull.set_meta("landmark_type", config["type"])
	var hm := BoxMesh.new()
	hm.size = sz
	hm.material = armor_mat
	hull.mesh = hm
	hull.position = Vector3(0.0, sz.y * 0.5, 0.0)
	_add_box_collision(hull, hm.size)
	parent.add_child(hull)
	placed += 1
	var turret := MeshInstance3D.new()
	turret.name = "ShatteredTurret"
	turret.set_meta("ballistic_material", "STEEL")
	turret.set_meta("landmark_type", config["type"])
	var tm := BoxMesh.new()
	tm.size = Vector3(sz.x * 0.65, sz.y * 0.55, sz.z * 0.5)
	tm.material = rusted_hull_mat
	turret.mesh = tm
	turret.position = Vector3(0.15, sz.y + sz.y * 0.25, -sz.z * 0.08)
	turret.rotation = Vector3(deg_to_rad(4.0), deg_to_rad(18.0), deg_to_rad(-6.0))
	_add_box_collision(turret, tm.size)
	parent.add_child(turret)
	placed += 1
	return placed