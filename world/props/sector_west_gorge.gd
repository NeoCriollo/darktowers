class_name SectorWestGorge
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

func _spawn_west_gorge_landmarks() -> int:
	var group := Node3D.new()
	group.name = "Vignettes_WestGorge_Defile"
	scatter.add_child(group)

	var total_placed := 0

	# 1. Collapsed Overpass Choke clusters spanning along the defile floor
	var overpass_sites: Array[Vector2] = [
		Vector2(-650.0, 20.0),
		Vector2(-648.0, 50.0)
	]

	for i in range(overpass_sites.size()):
		var op_site := overpass_sites[i]
		var op_root := Node3D.new()
		op_root.name = "CollapsedOverpassChoke_%d" % (i + 1)
		var base_y := _sample_terrain_y(op_site.x, op_site.y)
		op_root.position = Vector3(op_site.x, base_y, op_site.y)
		group.add_child(op_root)

		scatter._placed_xz.append(op_site)
		scatter._placed_radii.append(14.0)

		total_placed += _generate_gorge_overpass_choke(op_root, i)

	# 2. Corroded Industrial Pipelines running along canyon floor into talus rockfalls
	var pipeline_sites: Array[Vector2] = [
		Vector2(-638.0, 75.0),
		Vector2(-660.0, 95.0),
		Vector2(-642.0, 125.0)
	]

	for j in range(pipeline_sites.size()):
		var pl_site := pipeline_sites[j]
		var pl_root := Node3D.new()
		pl_root.name = "IndustrialPipeline_%d" % (j + 1)
		var pl_y := _sample_terrain_y(pl_site.x, pl_site.y)
		pl_root.position = Vector3(pl_site.x, pl_y, pl_site.y)
		group.add_child(pl_root)

		scatter._placed_xz.append(pl_site)
		scatter._placed_radii.append(10.0)

		total_placed += _generate_gorge_pipeline_network(pl_root, j)

	return total_placed

func _generate_gorge_overpass_choke(parent: Node3D, idx: int) -> int:
	var placed := 0

	# Concrete material for broken highway slabs
	var conc_mat := _make_mat(Color(0.32, 0.30, 0.28), 0.94, 0.05)
	# Rusted oxidized structural steel material
	var steel_mat := _make_mat(Color(0.24, 0.16, 0.13), 0.78, 0.75)

	# 1. Massive Fractured Highway Concrete Roadbed Slab
	var slab := MeshInstance3D.new()
	slab.name = "FracturedHighwaySlab"
	slab.set_meta("ballistic_material", "CONCRETE")
	slab.set_meta("landmark_type", "COLLAPSED_OVERPASS")
	var sm := BoxMesh.new()
	var s_sz := Vector3(scatter._rng.randf_range(7.5, 9.2), 0.45, scatter._rng.randf_range(3.8, 4.6))
	sm.size = s_sz
	sm.material = conc_mat
	slab.mesh = sm
	slab.position = Vector3(0.0, s_sz.y * 0.5 + 0.3, 0.0)
	slab.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(-14.0, 22.0)), scatter._rng.randf() * TAU, deg_to_rad(scatter._rng.randf_range(-18.0, 12.0)))
	_add_box_collision(slab, s_sz)
	parent.add_child(slab)
	placed += 1

	# 2. Heavy Angled Steel I-Beams wedged across canyon floor and walls
	for b_i in range(scatter._rng.randi_range(2, 3)):
		var beam := MeshInstance3D.new()
		beam.name = "AngledSteelIBeam_%d" % (b_i + 1)
		beam.set_meta("ballistic_material", "STEEL")
		beam.set_meta("landmark_type", "COLLAPSED_OVERPASS")
		var bm := BoxMesh.new()
		var beam_len := scatter._rng.randf_range(11.0, 15.5)
		var b_sz := Vector3(0.38, 0.38, beam_len)
		bm.size = b_sz
		bm.material = steel_mat
		beam.mesh = bm

		var b_yaw := scatter._rng.randf() * TAU
		beam.position = Vector3(scatter._rng.randf_range(-2.5, 2.5), beam_len * 0.28, scatter._rng.randf_range(-2.5, 2.5))
		beam.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(25.0, 48.0)), b_yaw, deg_to_rad(scatter._rng.randf_range(-20.0, 20.0)))
		_add_box_collision(beam, b_sz)
		parent.add_child(beam)
		placed += 1

	# 3. Twisted Exposed Rebar Ribs protruding from concrete fracture
	for r_i in range(3):
		var rebar := MeshInstance3D.new()
		rebar.name = "ExposedRebar_%d" % (r_i + 1)
		rebar.set_meta("ballistic_material", "STEEL")
		var rm := CylinderMesh.new()
		rm.top_radius = 0.025
		rm.bottom_radius = 0.035
		var r_h := scatter._rng.randf_range(2.0, 3.4)
		rm.height = r_h
		rm.material = steel_mat
		rebar.mesh = rm
		rebar.position = Vector3((r_i - 1.0) * 1.8, r_h * 0.45, s_sz.z * 0.48)
		rebar.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(30.0, 65.0)), scatter._rng.randf_range(-0.5, 0.5), deg_to_rad(scatter._rng.randf_range(-25.0, 25.0)))
		_add_cylinder_collision(rebar, 0.04, r_h)
		parent.add_child(rebar)
		placed += 1

	return placed

func _generate_gorge_pipeline_network(parent: Node3D, idx: int) -> int:
	var placed := 0
	var pipe_mat := _make_mat(Color(0.22, 0.15, 0.12), 0.72, 0.82)

	# 1. Main Pipeline Segment running along gorge floor
	var main_pipe := MeshInstance3D.new()
	main_pipe.name = "GorgePipelineTrunk"
	main_pipe.set_meta("ballistic_material", "STEEL")
	main_pipe.set_meta("landmark_type", "CORRODED_PIPELINE")

	var pm := CylinderMesh.new()
	var p_rad := scatter._rng.randf_range(0.45, 0.65)
	var p_len := scatter._rng.randf_range(7.5, 10.5)
	pm.top_radius = p_rad
	pm.bottom_radius = p_rad
	pm.height = p_len
	pm.material = pipe_mat
	main_pipe.mesh = pm

	# Horizontal pipeline running along canyon axis
	main_pipe.position = Vector3(0.0, p_rad * 0.95, 0.0)
	main_pipe.rotation = Vector3(PI * 0.5 + deg_to_rad(scatter._rng.randf_range(-8.0, 8.0)), scatter._rng.randf_range(-0.25, 0.25), 0.0)
	_add_cylinder_collision(main_pipe, p_rad, p_len)
	parent.add_child(main_pipe)
	placed += 1

	# 2. Heavy Pipeline Flange Ring Joint / Support Collar
	var collar := MeshInstance3D.new()
	collar.name = "PipelineFlangeCollar"
	collar.set_meta("ballistic_material", "STEEL")
	var cm := CylinderMesh.new()
	cm.top_radius = p_rad * 1.3
	cm.bottom_radius = p_rad * 1.3
	cm.height = 0.35
	cm.material = _make_mat(Color(0.28, 0.18, 0.14), 0.85, 0.65)
	collar.mesh = cm
	collar.position = Vector3(0.0, 0.0, scatter._rng.randf_range(-p_len * 0.25, p_len * 0.25))
	_add_cylinder_collision(collar, p_rad * 1.3, 0.35)
	main_pipe.add_child(collar)
	placed += 1

	# 3. Angled Branch Feeder diving into talus rockfall
	var branch_pipe := MeshInstance3D.new()
	branch_pipe.name = "TalusFeederPipe"
	branch_pipe.set_meta("ballistic_material", "STEEL")
	branch_pipe.set_meta("landmark_type", "CORRODED_PIPELINE")
	var bpm := CylinderMesh.new()
	var bp_rad := p_rad * 0.65
	var bp_len := scatter._rng.randf_range(4.5, 6.2)
	bpm.top_radius = bp_rad
	bpm.bottom_radius = bp_rad
	bpm.height = bp_len
	bpm.material = pipe_mat
	branch_pipe.mesh = bpm
	branch_pipe.position = Vector3(scatter._rng.randf_range(1.5, 2.8), bp_len * 0.32, scatter._rng.randf_range(-1.5, 1.5))
	branch_pipe.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(35.0, 60.0)), deg_to_rad(scatter._rng.randf_range(45.0, 90.0)), 0.0)
	_add_cylinder_collision(branch_pipe, bp_rad, bp_len)
	parent.add_child(branch_pipe)
	placed += 1

	return placed

# ─── Node 5 Bleached Alkali Sink Landmarks ───────────────────────────────────
## Populates landmark props unique to Bleached Alkali Sink (Node 5):
## 1. Ka Survey Beacon Monolith at (+45.0, +680.0):
##    A brutalist dark-iron/obsidian split-pylon monument (~8.5m tall) with central vertical
##    aperture housing a glowing electric-blue energy core (OmniLight3D + emissive sphere),
##    cyan positronic rune inlays, and stepped hexagonal base plinth.
## 2. NCP Armored Power Conduits: half-buried armored power conduits radiating across
##    the basin floor.
## 3. Alkali Mineral Mounds: crusty sulfur/alkali mounds protruding from the cracked pan.
