class_name VignettesGeneric
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
func _build_skeleton_mesh(label: String, su: float, sv: float, sw: float) -> MeshInstance3D:
	return scatter._build_skeleton_mesh(label, su, sv, sw)
func _build_debris_mesh(label: String, su: float, sv: float, sw: float) -> MeshInstance3D:
	return scatter._build_debris_mesh(label, su, sv, sw)
func _add_windward_sand_drift(p: Node3D, t: Vector3, h: float, w: float) -> int:
	return scatter._add_windward_sand_drift(p, t, h, w)
func _add_fossilized_steel_ribs(p: Node3D, c: Vector2, count: int, sp: float) -> int:
	return scatter._add_fossilized_steel_ribs(p, c, count, sp)

func _spawn_vignette_clusters(group_name: String, count: int, generator_fn: Callable) -> int:
	var group_root := Node3D.new()
	group_root.name = "Vignettes_" + group_name
	scatter.add_child(group_root)
	var total_placed := 0
	for _i in range(count):
		var cluster_center := _find_cluster_center(scatter.vignette_radius + 6.0)
		if cluster_center == Vector2.INF:
			continue
		scatter._placed_xz.append(cluster_center)
		scatter._placed_radii.append(scatter.vignette_radius)
		var cluster_node := Node3D.new()
		cluster_node.name = group_name + "_" + str(_i + 1)
		var center_y := _sample_terrain_y(cluster_center.x, cluster_center.y)
		cluster_node.position = Vector3(cluster_center.x, center_y, cluster_center.y)
		group_root.add_child(cluster_node)
		var cluster_yaw := scatter._rng.randf() * TAU
		cluster_node.rotate_y(cluster_yaw)
		total_placed += generator_fn.call(cluster_node)
		for child in cluster_node.get_children():
			if child is Node3D:
				var g := (child as Node3D).global_position
				(child as Node3D).position.y += _sample_terrain_y(g.x, g.z) - center_y
	return total_placed
func _find_cluster_center(clearance_radius: float) -> Vector2:
	for _attempt in range(scatter.MAX_PLACEMENT_ATTEMPTS):
		var x := scatter._rng.randf_range(-scatter.field_half_extent * 0.85, scatter.field_half_extent * 0.85)
		var z := scatter._rng.randf_range(-scatter.field_half_extent * 0.85, scatter.field_half_extent * 0.85)
		var candidate := Vector2(x, z)
		if candidate.length() < (scatter.player_clearance + clearance_radius):
			continue
		if candidate.distance_to(scatter.spawn_clearance_point) < (scatter.player_clearance + clearance_radius):
			continue
		var conflict := false
		for idx in range(scatter._placed_xz.size()):
			if candidate.distance_to(scatter._placed_xz[idx]) < (scatter._placed_radii[idx] + clearance_radius):
				conflict = true
				break
		if not conflict:
			return candidate
	return Vector2.INF
func _generate_caravan_vignette(parent: Node3D) -> int:
	var placed := 0
	var wagon_count := scatter._rng.randi_range(2, 4)
	for i in range(wagon_count):
		var angle := (float(i) / float(wagon_count)) * TAU + scatter._rng.randf_range(-0.25, 0.25)
		var dist := scatter._rng.randf_range(3.5, 6.5)
		var local_pos := Vector2(cos(angle), sin(angle)) * dist
		var wagon := MeshInstance3D.new()
		wagon.name = "WagonHulk_" + str(i)
		var w_mesh := BoxMesh.new()
		var w_size := Vector3(scatter._rng.randf_range(4.2, 5.5), scatter._rng.randf_range(1.6, 2.2), scatter._rng.randf_range(2.0, 2.6))
		w_mesh.size = w_size
		w_mesh.material = _make_mat(Color(0.24, 0.22, 0.18), 0.92, 0.2)
		wagon.mesh = w_mesh
		wagon.position = Vector3(local_pos.x, w_size.y * 0.45, local_pos.y)
		wagon.rotation = Vector3(
			scatter._rng.randf_range(-0.2, 0.2),
			angle + PI * 0.5 + scatter._rng.randf_range(-0.3, 0.3),
			scatter._rng.randf_range(-0.35, 0.35)
		)
		_add_box_collision(wagon, w_size)
		parent.add_child(wagon)
		placed += 1
		var crate_count := scatter._rng.randi_range(2, 4)
		for c in range(crate_count):
			var crate := MeshInstance3D.new()
			crate.name = "CargoCrate_" + str(i) + "_" + str(c)
			var c_mesh := BoxMesh.new()
			var c_dim := scatter._rng.randf_range(0.8, 1.4)
			var c_size := Vector3(c_dim, c_dim * scatter._rng.randf_range(0.8, 1.2), c_dim)
			c_mesh.size = c_size
			c_mesh.material = _make_mat(Color(0.35, 0.30, 0.23), 0.95, 0.0)
			crate.mesh = c_mesh
			var c_offset := Vector2(scatter._rng.randf_range(-2.0, 2.0), scatter._rng.randf_range(-2.0, 2.0))
			crate.position = Vector3(local_pos.x + c_offset.x, c_size.y * 0.5, local_pos.y + c_offset.y)
			crate.rotation.y = scatter._rng.randf() * TAU
			_add_box_collision(crate, c_size)
			parent.add_child(crate)
			placed += 1
	var skeleton_count := scatter._rng.randi_range(6, 11)
	for s in range(skeleton_count):
		var s_angle := scatter._rng.randf() * TAU
		var s_dist := scatter._rng.randf_range(7.5, 14.0)
		var s_pos := Vector2(cos(s_angle), sin(s_angle)) * s_dist
		var skel := _build_skeleton_mesh("SKELETON", scatter._rng.randf_range(0.8, 1.5), 1.0, 1.0)
		skel.position = Vector3(s_pos.x, 0.1, s_pos.y)
		skel.rotation = Vector3(scatter._rng.randf_range(-0.2, 0.2), scatter._rng.randf() * TAU, scatter._rng.randf_range(-0.2, 0.2))
		scatter._add_static_collision(skel, 1.0, 1.0, 1.0, "SKELETON")
		parent.add_child(skel)
		placed += 1
	for d in range(scatter._rng.randi_range(6, 12)):
		var d_pos := Vector2(scatter._rng.randf_range(-6.0, 6.0), scatter._rng.randf_range(-6.0, 6.0))
		var debris := _build_debris_mesh("DEBRIS", scatter._rng.randf_range(0.2, 0.5), 1.0, 1.0)
		debris.position = Vector3(d_pos.x, 0.05, d_pos.y)
		debris.rotation.y = scatter._rng.randf() * TAU
		parent.add_child(debris)
		placed += 1
	return placed
func _generate_overpass_vignette(parent: Node3D) -> int:
	var placed := 0
	var span_axis := scatter._rng.randf() * TAU
	var dir := Vector2(cos(span_axis), sin(span_axis))
	var normal := Vector2(-dir.y, dir.x)
	var pillar_spacing := 9.0
	for p_idx in range(-1, 2):
		var p_pos := dir * (p_idx * pillar_spacing)
		var plinth := MeshInstance3D.new()
		plinth.name = "OverpassSteelPlinth_" + str(p_idx + 1)
		plinth.set_meta("ballistic_material", "STEEL")
		var pl_mesh := BoxMesh.new()
		var p_w := scatter._rng.randf_range(2.2, 3.2)
		pl_mesh.size = Vector3(p_w * 1.35, 1.4, p_w * 1.35)
		pl_mesh.material = _make_mat(Color(0.14, 0.15, 0.17), 0.45, 0.85)
		plinth.mesh = pl_mesh
		plinth.position = Vector3(p_pos.x, 0.45, p_pos.y)
		_add_box_collision(plinth, pl_mesh.size)
		parent.add_child(plinth)
		placed += 1
		var pillar := MeshInstance3D.new()
		pillar.name = "OverpassPillar_" + str(p_idx + 1)
		var p_mesh := BoxMesh.new()
		var p_h := scatter._rng.randf_range(7.5, 12.5)
		p_mesh.size = Vector3(p_w, p_h, p_w)
		p_mesh.material = _make_mat(Color(0.36, 0.35, 0.32), 0.98, 0.0) # Bleached cracked concrete
		pillar.mesh = p_mesh
		pillar.position = Vector3(p_pos.x, p_h * 0.45, p_pos.y)
		pillar.rotation = Vector3(scatter._rng.randf_range(-0.15, 0.15), scatter._rng.randf() * TAU, scatter._rng.randf_range(-0.22, 0.22))
		_add_box_collision(pillar, p_mesh.size)
		parent.add_child(pillar)
		placed += 1
	for s_idx in range(2):
		var slab := MeshInstance3D.new()
		slab.name = "CollapsedDeckSlab_" + str(s_idx + 1)
		var s_mesh := BoxMesh.new()
		var s_len := scatter._rng.randf_range(9.0, 13.0)
		var s_width := scatter._rng.randf_range(4.8, 6.2)
		s_mesh.size = Vector3(s_width, 0.65, s_len)
		s_mesh.material = _make_mat(Color(0.32, 0.31, 0.29), 0.95, 0.1)
		slab.mesh = s_mesh
		var offset_dist := (s_idx - 0.5) * 8.5
		var s_pos := dir * offset_dist + normal * scatter._rng.randf_range(-2.0, 2.0)
		var deck_y := 3.1 if s_idx == 0 else scatter._rng.randf_range(1.2, 2.2)
		slab.position = Vector3(s_pos.x, deck_y, s_pos.y)
		slab.rotation = Vector3(
			0.08 if s_idx == 0 else scatter._rng.randf_range(0.25, 0.42),
			span_axis + scatter._rng.randf_range(-0.15, 0.15),
			scatter._rng.randf_range(-0.06, 0.06)
		)
		_add_box_collision(slab, s_mesh.size)
		parent.add_child(slab)
		placed += 1
		if s_idx == 0:
			placed += _add_windward_sand_drift(parent, Vector3(s_pos.x, 0.0, s_pos.y), deck_y, s_width * 1.15)
			var shield := MeshInstance3D.new()
			shield.name = "ScavengerDeckWindbreak"
			shield.set_meta("ballistic_material", "STEEL")
			var sh_m := BoxMesh.new()
			sh_m.size = Vector3(s_width * 0.75, 1.15, 0.14)
			sh_m.material = _make_mat(Color(0.42, 0.27, 0.18), 0.88, 0.55)
			shield.mesh = sh_m
			shield.position = Vector3(s_pos.x, deck_y + 0.85, s_pos.y)
			shield.rotation.y = span_axis
			_add_box_collision(shield, sh_m.size)
			parent.add_child(shield)
			placed += 1
	placed += _add_fossilized_steel_ribs(parent, Vector2.ZERO, 4, 8.5)
	var vehicle_count := scatter._rng.randi_range(2, 4)
	for v in range(vehicle_count):
		var v_pos := dir * scatter._rng.randf_range(-12.0, 12.0) + normal * scatter._rng.randf_range(-5.0, 5.0)
		var veh := MeshInstance3D.new()
		veh.name = "VehicleHusk_" + str(v + 1)
		var v_mesh := BoxMesh.new()
		var v_size := Vector3(scatter._rng.randf_range(2.0, 2.4), scatter._rng.randf_range(1.1, 1.4), scatter._rng.randf_range(3.8, 4.6))
		v_mesh.size = v_size
		v_mesh.material = _make_mat(Color(0.25, 0.18, 0.14), 0.88, 0.4) # Rusted metal oxide
		veh.mesh = v_mesh
		veh.position = Vector3(v_pos.x, v_size.y * 0.45, v_pos.y)
		veh.rotation = Vector3(scatter._rng.randf_range(-0.15, 0.15), scatter._rng.randf() * TAU, scatter._rng.randf_range(-0.3, 0.3))
		_add_box_collision(veh, v_size)
		parent.add_child(veh)
		placed += 1
	for r in range(scatter._rng.randi_range(8, 14)):
		var r_pos := dir * scatter._rng.randf_range(-14.0, 14.0) + normal * scatter._rng.randf_range(-6.0, 6.0)
		var r_mesh := _build_debris_mesh("DEBRIS", scatter._rng.randf_range(0.4, 0.9), 1.0, 1.0)
		r_mesh.position = Vector3(r_pos.x, 0.1, r_pos.y)
		parent.add_child(r_mesh)
		placed += 1
	return placed
func _generate_outpost_vignette(parent: Node3D) -> int:
	var placed := 0
	for t_idx in range(2):
		var tank := MeshInstance3D.new()
		tank.name = "StorageTank_" + str(t_idx + 1)
		var t_mesh := CylinderMesh.new()
		var t_radius := scatter._rng.randf_range(2.4, 3.3)
		var t_height := scatter._rng.randf_range(5.0, 6.8)
		t_mesh.top_radius = t_radius
		t_mesh.bottom_radius = t_radius
		t_mesh.height = t_height
		t_mesh.material = _make_mat(Color(0.22, 0.24, 0.22), 0.80, 0.45)
		tank.mesh = t_mesh
		var t_offset := Vector2((t_idx - 0.5) * 7.8, scatter._rng.randf_range(-1.8, 1.8))
		if t_idx == 1:
			tank.position = Vector3(t_offset.x, t_height * 0.26, t_offset.y)
			tank.rotation = Vector3(deg_to_rad(22.0), scatter._rng.randf() * TAU, deg_to_rad(-14.0))
		else:
			tank.position = Vector3(t_offset.x, t_height * 0.5, t_offset.y)
			tank.rotation.y = scatter._rng.randf() * TAU
		_add_cylinder_collision(tank, t_radius, t_height)
		parent.add_child(tank)
		placed += 1
	var sh_size := Vector3(scatter._rng.randf_range(5.2, 6.8), scatter._rng.randf_range(3.0, 3.6), scatter._rng.randf_range(5.2, 6.8))
	var shed_pos := Vector3(scatter._rng.randf_range(-2.5, 2.5), sh_size.y * 0.48, scatter._rng.randf_range(5.5, 7.8))
	var shed_yaw := scatter._rng.randf() * TAU
	var base_plate := MeshInstance3D.new()
	base_plate.name = "BunkerSteelFoundation"
	base_plate.set_meta("ballistic_material", "STEEL")
	var bp_mesh := BoxMesh.new()
	bp_mesh.size = Vector3(sh_size.x + 0.8, 0.7, sh_size.z + 0.8)
	bp_mesh.material = _make_mat(Color(0.14, 0.15, 0.17), 0.45, 0.85)
	base_plate.mesh = bp_mesh
	base_plate.position = Vector3(shed_pos.x, 0.35, shed_pos.z)
	base_plate.rotation.y = shed_yaw
	_add_box_collision(base_plate, bp_mesh.size)
	parent.add_child(base_plate)
	placed += 1
	var shed := MeshInstance3D.new()
	shed.name = "GeneratorBunker"
	var sh_mesh := BoxMesh.new()
	sh_mesh.size = sh_size
	sh_mesh.material = _make_mat(Color(0.32, 0.30, 0.27), 0.94, 0.1)
	shed.mesh = sh_mesh
	shed.position = shed_pos
	shed.rotation.y = shed_yaw
	_add_box_collision(shed, sh_size)
	parent.add_child(shed)
	placed += 1
	var roof_y := sh_size.y * 0.96
	placed += _add_windward_sand_drift(parent, Vector3(shed_pos.x, 0.0, shed_pos.z), roof_y, sh_size.x * 0.9)
	for w_side in [-1.0, 1.0]:
		var tin_wall := MeshInstance3D.new()
		tin_wall.name = "RoofScavengerTin_" + ("L" if w_side < 0.0 else "R")
		tin_wall.set_meta("ballistic_material", "STEEL")
		var tw_mesh := BoxMesh.new()
		tw_mesh.size = Vector3(sh_size.x * 0.65, 1.1, 0.12)
		tw_mesh.material = _make_mat(Color(0.40, 0.26, 0.17), 0.86, 0.58)
		tin_wall.mesh = tw_mesh
		tin_wall.position = Vector3(shed_pos.x + w_side * 0.8, roof_y + 0.55, shed_pos.z + w_side * (sh_size.z * 0.38))
		tin_wall.rotation.y = shed_yaw + w_side * 0.25
		_add_box_collision(tin_wall, tw_mesh.size)
		parent.add_child(tin_wall)
		placed += 1
	var gantry := MeshInstance3D.new()
	gantry.name = "UpperGantryWalkway"
	gantry.set_meta("ballistic_material", "STEEL")
	var g_mesh := BoxMesh.new()
	g_mesh.size = Vector3(1.8, 0.22, 6.2)
	g_mesh.material = _make_mat(Color(0.20, 0.19, 0.18), 0.72, 0.78)
	gantry.mesh = g_mesh
	gantry.position = Vector3(shed_pos.x * 0.5, roof_y - 0.1, shed_pos.z * 0.45)
	_add_box_collision(gantry, g_mesh.size)
	parent.add_child(gantry)
	placed += 1
	for p_idx in range(scatter._rng.randi_range(3, 5)):
		var pipe := MeshInstance3D.new()
		pipe.name = "PipeStack_" + str(p_idx + 1)
		var pi_mesh := CylinderMesh.new()
		var r := scatter._rng.randf_range(0.4, 0.7)
		var l := scatter._rng.randf_range(4.0, 7.0)
		pi_mesh.top_radius = r
		pi_mesh.bottom_radius = r
		pi_mesh.height = l
		pi_mesh.material = _make_mat(Color(0.18, 0.17, 0.16), 0.75, 0.6)
		pipe.mesh = pi_mesh
		var p_pos := Vector2(scatter._rng.randf_range(-7.0, 7.0), scatter._rng.randf_range(-7.0, 7.0))
		pipe.position = Vector3(p_pos.x, r, p_pos.y)
		pipe.rotation = Vector3(PI * 0.5, scatter._rng.randf() * TAU, 0.0)
		_add_cylinder_collision(pipe, r, l)
		parent.add_child(pipe)
		placed += 1
	for b in range(scatter._rng.randi_range(6, 10)):
		var b_pos := Vector2(scatter._rng.randf_range(-8.0, 8.0), scatter._rng.randf_range(-8.0, 8.0))
		var barrel := MeshInstance3D.new()
		var b_mesh := CylinderMesh.new()
		b_mesh.top_radius = 0.35
		b_mesh.bottom_radius = 0.35
		b_mesh.height = 0.95
		b_mesh.material = _make_mat(Color(0.35, 0.20, 0.12), 0.92, 0.3)
		barrel.mesh = b_mesh
		barrel.position = Vector3(b_pos.x, 0.48, b_pos.y)
		_add_cylinder_collision(barrel, 0.35, 0.95)
		parent.add_child(barrel)
		placed += 1
	return placed
func _generate_brutalist_monolith_vignette(parent: Node3D) -> int:
	var placed := 0
	var carbon_steel_mat := _make_mat(Color(0.13, 0.14, 0.16), 0.42, 0.88)
	var brutalist_concrete_mat := _make_mat(Color(0.34, 0.33, 0.30), 0.96, 0.05)
	var rusted_tin_mat := _make_mat(Color(0.41, 0.25, 0.16), 0.86, 0.55)
	var canvas_tarp_mat := _make_mat(Color(0.66, 0.60, 0.49), 0.95, 0.0)
	for side in [-1.0, 1.0]:
		var plinth := MeshInstance3D.new()
		plinth.name = "CarbonSteelFoundation_" + ("W" if side < 0.0 else "E")
		plinth.set_meta("ballistic_material", "STEEL")
		var pl_mesh := BoxMesh.new()
		pl_mesh.size = Vector3(3.4, 1.2, 13.5)
		pl_mesh.material = carbon_steel_mat
		plinth.mesh = pl_mesh
		plinth.position = Vector3(side * 5.6, 0.45, 0.0)
		_add_box_collision(plinth, pl_mesh.size)
		parent.add_child(plinth)
		placed += 1
	for side in [-1.0, 1.0]:
		for z_idx in [-1, 1]:
			var p_h := scatter._rng.randf_range(9.5, 14.0)
			var pillar := MeshInstance3D.new()
			pillar.name = "RibbedMonolithPillar_%s_%d" % [("L" if side < 0.0 else "R"), z_idx]
			pillar.set_meta("ballistic_material", "CONCRETE")
			var p_mesh := BoxMesh.new()
			p_mesh.size = Vector3(2.4, p_h, 2.6)
			p_mesh.material = brutalist_concrete_mat
			pillar.mesh = p_mesh
			pillar.position = Vector3(side * 5.6, p_h * 0.48, z_idx * 4.4)
			pillar.rotation = Vector3(scatter._rng.randf_range(-0.04, 0.04), 0.0, deg_to_rad(side * -3.5))
			_add_box_collision(pillar, p_mesh.size)
			parent.add_child(pillar)
			placed += 1
			for r_step in [0.28, 0.58, 0.84]:
				var rib := MeshInstance3D.new()
				rib.name = "PillarSteelRib_%d" % int(r_step * 100)
				rib.set_meta("ballistic_material", "STEEL")
				var r_mesh := BoxMesh.new()
				r_mesh.size = Vector3(2.75, 0.35, 2.95)
				r_mesh.material = carbon_steel_mat
				rib.mesh = r_mesh
				rib.position = Vector3(side * 5.6, p_h * r_step, z_idx * 4.4)
				parent.add_child(rib)
				placed += 1
		var wall := MeshInstance3D.new()
		wall.name = "BrutalistCourtyardWall_" + ("L" if side < 0.0 else "R")
		wall.set_meta("ballistic_material", "CONCRETE")
		var w_mesh := BoxMesh.new()
		w_mesh.size = Vector3(1.5, 3.4, 8.8)
		w_mesh.material = brutalist_concrete_mat
		wall.mesh = w_mesh
		wall.position = Vector3(side * 5.6, 1.7, 0.0)
		_add_box_collision(wall, w_mesh.size)
		parent.add_child(wall)
		placed += 1
	var arch_span := MeshInstance3D.new()
	arch_span.name = "BrutalistArchSpan"
	arch_span.set_meta("ballistic_material", "CONCRETE")
	var a_mesh := BoxMesh.new()
	a_mesh.size = Vector3(13.8, 1.6, 2.8)
	a_mesh.material = brutalist_concrete_mat
	arch_span.mesh = a_mesh
	arch_span.position = Vector3(0.0, 8.8, -4.4)
	_add_box_collision(arch_span, a_mesh.size)
	parent.add_child(arch_span)
	placed += 1
	var walkway_y := 3.25
	var walkway := MeshInstance3D.new()
	walkway.name = "UpperTacticalWalkway"
	walkway.set_meta("ballistic_material", "CONCRETE")
	var wk_mesh := BoxMesh.new()
	wk_mesh.size = Vector3(11.6, 0.45, 3.8)
	wk_mesh.material = brutalist_concrete_mat
	walkway.mesh = wk_mesh
	walkway.position = Vector3(0.0, walkway_y, 4.2)
	_add_box_collision(walkway, wk_mesh.size)
	parent.add_child(walkway)
	placed += 1
	var parapet := MeshInstance3D.new()
	parapet.name = "WalkwayParapetCover"
	parapet.set_meta("ballistic_material", "CONCRETE")
	var pp_mesh := BoxMesh.new()
	pp_mesh.size = Vector3(8.4, 1.05, 0.4)
	pp_mesh.material = brutalist_concrete_mat
	parapet.mesh = pp_mesh
	parapet.position = Vector3(0.0, walkway_y + 0.72, 2.45)
	_add_box_collision(parapet, pp_mesh.size)
	parent.add_child(parapet)
	placed += 1
	placed += _add_windward_sand_drift(parent, Vector3(0.0, 0.0, 4.2), walkway_y, 5.2)
	for s_idx in [-1, 1]:
		var tin := MeshInstance3D.new()
		tin.name = "ScavengerTinWindbreak_%d" % s_idx
		tin.set_meta("ballistic_material", "STEEL")
		var t_mesh := BoxMesh.new()
		t_mesh.size = Vector3(3.2, 1.45, 0.12)
		t_mesh.material = rusted_tin_mat
		tin.mesh = t_mesh
		tin.position = Vector3(s_idx * 3.4, walkway_y + 0.9, 5.85)
		tin.rotation = Vector3(deg_to_rad(-8.0), s_idx * 0.18, 0.0)
		_add_box_collision(tin, t_mesh.size)
		parent.add_child(tin)
		placed += 1
	var canopy := MeshInstance3D.new()
	canopy.name = "ScavengerCanvasAwning"
	canopy.set_meta("ballistic_material", "WOOD")
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(5.4, 0.08, 3.2)
	c_mesh.material = canvas_tarp_mat
	canopy.mesh = c_mesh
	canopy.position = Vector3(0.0, walkway_y + 2.45, 4.4)
	canopy.rotation = Vector3(deg_to_rad(7.0), 0.0, deg_to_rad(-3.0))
	parent.add_child(canopy)
	placed += 1
	for c_idx in range(3):
		var block := MeshInstance3D.new()
		block.name = "CourtyardFallenMonolith_%d" % (c_idx + 1)
		block.set_meta("ballistic_material", "CONCRETE")
		var b_mesh := BoxMesh.new()
		var b_sz := Vector3(scatter._rng.randf_range(1.6, 2.5), scatter._rng.randf_range(1.1, 1.6), scatter._rng.randf_range(1.2, 2.0))
		b_mesh.size = b_sz
		b_mesh.material = brutalist_concrete_mat
		block.mesh = b_mesh
		block.position = Vector3(scatter._rng.randf_range(-3.2, 3.2), b_sz.y * 0.45, scatter._rng.randf_range(-3.5, 1.0))
		block.rotation.y = scatter._rng.randf() * TAU
		_add_box_collision(block, b_sz)
		parent.add_child(block)
		placed += 1
	placed += _add_fossilized_steel_ribs(parent, Vector2(0.0, -2.5), 4, 6.5)
	return placed