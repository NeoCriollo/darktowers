class_name SectorSWDesolation
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
func _add_windward_sand_drift(p: Node3D, t: Vector3, h: float, w: float) -> int:
	return scatter._add_windward_sand_drift(p, t, h, w)

func _spawn_sw_desolation_scrap_nodes() -> int:
	var group := Node3D.new()
	group.name = "Vignettes_SWDesolation_Scrap"
	scatter.add_child(group)

	# 6 Strategic scrap sites situated along the base of hardpan bedrock ridges in Node 1 (SW Desolation)
	# (X from -800 to -400, Z from -1000 to -600)
	var ridge_base_positions: Array[Vector2] = [
		Vector2(-720.0, -850.0), # Western bedrock footwall near defile pass
		Vector2(-640.0, -920.0), # Southwest trough under yardang ridge
		Vector2(-580.0, -780.0), # Northwest hardpan wash depression
		Vector2(-520.0, -940.0), # Southern ridge base in wind shadow
		Vector2(-480.0, -860.0), # Eastern hardpan ridge foot towards salt flat
		Vector2(-610.0, -680.0)  # Northern bedrock ridge terrace base
	]

	var total_placed := 0
	for i in range(min(scatter.sw_desolation_scrap_count, ridge_base_positions.size())):
		var site := ridge_base_positions[i]
		var cluster_root := Node3D.new()
		cluster_root.name = "ScrapNode_%d" % (i + 1)
		var base_y := _sample_terrain_y(site.x, site.y)
		cluster_root.position = Vector3(site.x, base_y, site.y)
		cluster_root.rotation.y = scatter.valley_axis_rad + scatter._rng.randf_range(-0.35, 0.35)
		group.add_child(cluster_root)

		scatter._placed_xz.append(site)
		scatter._placed_radii.append(scatter.vignette_radius)

		total_placed += _generate_sw_scrap_cluster(cluster_root)

	return total_placed

func _generate_sw_scrap_cluster(parent: Node3D) -> int:
	var placed := 0

	# 1. Old Containers (Heavy pre-break freight container + weathered footlocker + barrels)
	# A. Pre-Break Corrugated Shipping Container
	var c_size := Vector3(scatter._rng.randf_range(2.4, 2.8), scatter._rng.randf_range(2.1, 2.5), scatter._rng.randf_range(4.6, 5.6))
	var container := MeshInstance3D.new()
	container.name = "OldFreightContainer"
	container.set_meta("ballistic_material", "STEEL")
	container.set_meta("scavenge_node", true)
	var cm := BoxMesh.new()
	cm.size = c_size
	cm.material = _make_mat(Color(scatter._rng.randf_range(0.32, 0.40), scatter._rng.randf_range(0.18, 0.24), scatter._rng.randf_range(0.11, 0.16)), 0.88, 0.65)
	container.mesh = cm
	var c_offset := Vector3(scatter._rng.randf_range(-1.2, 1.2), c_size.y * 0.44, scatter._rng.randf_range(-1.2, 1.2))
	container.position = c_offset
	# Canted into the sand drift along the base of the hardpan ridge
	container.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(-7.0, 14.0)), scatter._rng.randf() * TAU, deg_to_rad(scatter._rng.randf_range(-6.0, 9.0)))
	_add_box_collision(container, c_size)
	parent.add_child(container)
	placed += 1

	# Windward sand drift banked against the container
	placed += _add_windward_sand_drift(parent, c_offset, c_size.y * 0.55, c_size.x * 0.95)

	# B. Weathered Metal Cargo Footlocker / Armored Trunk
	var l_size := Vector3(scatter._rng.randf_range(1.2, 1.5), scatter._rng.randf_range(0.8, 1.0), scatter._rng.randf_range(1.6, 2.0))
	var locker := MeshInstance3D.new()
	locker.name = "WeatheredStorageTrunk"
	locker.set_meta("ballistic_material", "STEEL")
	locker.set_meta("scavenge_node", true)
	var lm := BoxMesh.new()
	lm.size = l_size
	lm.material = _make_mat(Color(0.26, 0.23, 0.19), 0.92, 0.52)
	locker.mesh = lm
	var l_pos := Vector3(c_offset.x + scatter._rng.randf_range(2.6, 3.8), l_size.y * 0.46, c_offset.z + scatter._rng.randf_range(-1.8, 1.8))
	locker.position = l_pos
	locker.rotation.y = scatter._rng.randf() * TAU
	_add_box_collision(locker, l_size)
	parent.add_child(locker)
	placed += 1

	# C. Corroded Industrial Storage Drums (1 to 2)
	for d_idx in range(scatter._rng.randi_range(1, 2)):
		var drum := MeshInstance3D.new()
		drum.name = "CorrodedDrum_%d" % (d_idx + 1)
		drum.set_meta("ballistic_material", "STEEL")
		var dm := CylinderMesh.new()
		var d_rad := 0.36
		var d_h := 0.95
		dm.top_radius = d_rad
		dm.bottom_radius = d_rad
		dm.height = d_h
		dm.material = _make_mat(Color(0.32, 0.20, 0.14), 0.92, 0.42)
		drum.mesh = dm
		var d_pos := Vector3(c_offset.x + scatter._rng.randf_range(-3.2, -1.8), d_h * 0.45, c_offset.z + scatter._rng.randf_range(1.5, 3.2))
		drum.position = d_pos
		if d_idx == 0:
			drum.rotation = Vector3(PI * 0.5, scatter._rng.randf() * TAU, deg_to_rad(12.0))
		else:
			drum.rotation.y = scatter._rng.randf() * TAU
		_add_cylinder_collision(drum, d_rad, d_h)
		parent.add_child(drum)
		placed += 1

	# 2. Rusted Metal Scraps (Twisted corrugated panels, bent girders, detritus shards)
	# A. Twisted Corrugated Sheet Metal Panels (2 to 3 panels)
	for p_idx in range(scatter._rng.randi_range(2, 3)):
		var panel := MeshInstance3D.new()
		panel.name = "RustedCorrugatedPanel_%d" % (p_idx + 1)
		panel.set_meta("ballistic_material", "STEEL")
		panel.set_meta("scavenge_node", true)
		var pm := BoxMesh.new()
		var p_sz := Vector3(scatter._rng.randf_range(1.7, 2.5), 0.06, scatter._rng.randf_range(1.0, 1.4))
		pm.size = p_sz
		pm.material = _make_mat(Color(0.42, 0.23, 0.14), 0.86, 0.72)
		panel.mesh = pm
		var p_pos := Vector3(c_offset.x + scatter._rng.randf_range(-2.8, 2.8), p_sz.y * 0.5 + 0.3, c_offset.z + scatter._rng.randf_range(-3.0, 3.0))
		panel.position = p_pos
		panel.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(22.0, 55.0)), scatter._rng.randf() * TAU, deg_to_rad(scatter._rng.randf_range(-18.0, 18.0)))
		_add_box_collision(panel, p_sz)
		parent.add_child(panel)
		placed += 1

	# B. Bent Structural Steel Girders / Rebar Ribs (2 girders)
	for g_idx in range(2):
		var girder := MeshInstance3D.new()
		girder.name = "BentSteelGirder_%d" % (g_idx + 1)
		girder.set_meta("ballistic_material", "STEEL")
		girder.set_meta("scavenge_node", true)
		var gm := BoxMesh.new()
		var g_len := scatter._rng.randf_range(3.0, 4.2)
		var g_sz := Vector3(0.18, 0.18, g_len)
		gm.size = g_sz
		gm.material = _make_mat(Color(0.20, 0.18, 0.16), 0.78, 0.82)
		girder.mesh = gm
		var g_pos := Vector3(c_offset.x + scatter._rng.randf_range(-3.5, 3.5), g_len * 0.32, c_offset.z + scatter._rng.randf_range(-3.5, 3.5))
		girder.position = g_pos
		girder.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(35.0, 60.0)), scatter._rng.randf() * TAU, deg_to_rad(scatter._rng.randf_range(-25.0, 25.0)))
		_add_box_collision(girder, g_sz)
		parent.add_child(girder)
		placed += 1

	# C. Scattered Scrap Metal Shards & Detritus (3 to 5 pieces)
	for s_idx in range(scatter._rng.randi_range(3, 5)):
		var scrap := MeshInstance3D.new()
		scrap.name = "ScrapDetritus_%d" % (s_idx + 1)
		scrap.set_meta("ballistic_material", "STEEL")
		scrap.set_meta("scavenge_node", true)
		var sm := BoxMesh.new()
		var s_sz := Vector3(scatter._rng.randf_range(0.45, 0.85), scatter._rng.randf_range(0.08, 0.16), scatter._rng.randf_range(0.55, 1.1))
		sm.size = s_sz
		sm.material = _make_mat(Color(scatter._rng.randf_range(0.32, 0.44), scatter._rng.randf_range(0.19, 0.27), scatter._rng.randf_range(0.12, 0.18)), 0.94, 0.50)
		scrap.mesh = sm
		scrap.position = Vector3(c_offset.x + scatter._rng.randf_range(-4.5, 4.5), s_sz.y * 0.48, c_offset.z + scatter._rng.randf_range(-4.5, 4.5))
		scrap.rotation.y = scatter._rng.randf() * TAU
		_add_box_collision(scrap, s_sz)
		parent.add_child(scrap)
		placed += 1

	return placed


## Builds a wind-sculpted sand drift banked against the windward side of a structure,
## allowing the player to walk seamlessly off the desert ridge onto an upper tier/roof.
# ─── Node 2 Dead-Creek Salt Flats Landmarks ──────────────────────────────────
## Spawns landmark props unique to the salt flats:
## 1. "The Dead-Creek Wire": 6 weathered/broken telegraph poles tracing a historic
##    route across the blinding playa ($X \in [-400, 0], Z \in [-800, -300]$).
## 2. 4 megafauna sun-bleached skeletal clusters embedded in the salt crust.
