class_name SectorSouthSalt
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
func _add_static_collision(m: MeshInstance3D, su: float, sv: float, sw: float, label: String) -> void:
	scatter._add_static_collision(m, su, sv, sw, label)

func _spawn_south_salt_landmarks() -> int:
	var group := Node3D.new()
	group.name = "Vignettes_SouthSalt_Playa"
	scatter.add_child(group)

	var total_placed := 0

	# 1. "The Dead-Creek Wire" — 6 canted telegraph poles along historic route
	var telegraph_coords: Array[Vector2] = [
		Vector2(-340.0, -680.0),
		Vector2(-284.0, -628.0),
		Vector2(-228.0, -576.0),
		Vector2(-172.0, -524.0),
		Vector2(-116.0, -472.0),
		Vector2(-60.0, -420.0)
	]

	for i in range(telegraph_coords.size()):
		var coord := telegraph_coords[i]
		var pole_root := Node3D.new()
		pole_root.name = "DeadCreekPole_%d" % (i + 1)
		var base_y := _sample_terrain_y(coord.x, coord.y)
		pole_root.position = Vector3(coord.x, base_y, coord.y)
		group.add_child(pole_root)

		scatter._placed_xz.append(coord)
		scatter._placed_radii.append(6.0)

		total_placed += _generate_telegraph_pole(pole_root, i)

	# 2. Megafauna Sun-Bleached Skeletal Clusters embedded in the flat salt crust
	var skeletal_coords: Array[Vector2] = [
		Vector2(-220.0, -580.0), # Megafauna ribcage
		Vector2(-140.0, -480.0), # Desiccated steed remains
		Vector2(-280.0, -460.0), # Salt-crusted titan vertebrae
		Vector2(-100.0, -640.0)  # Bleached horned beast skull
	]

	for j in range(skeletal_coords.size()):
		var sk_coord := skeletal_coords[j]
		var sk_root := Node3D.new()
		sk_root.name = "SaltSkeletonCluster_%d" % (j + 1)
		var base_y := _sample_terrain_y(sk_coord.x, sk_coord.y)
		sk_root.position = Vector3(sk_coord.x, base_y, sk_coord.y)
		group.add_child(sk_root)

		scatter._placed_xz.append(sk_coord)
		scatter._placed_radii.append(8.0)

		total_placed += _generate_salt_skeletal_cluster(sk_root, j)

	return total_placed

func _generate_telegraph_pole(parent: Node3D, pole_index: int) -> int:
	var placed := 0

	# Main creosote timber pole
	var pole_h := scatter._rng.randf_range(5.2, 5.8)
	var pole_rad := 0.13
	var pole := MeshInstance3D.new()
	pole.name = "CreosotePole"
	pole.set_meta("ballistic_material", "WOOD")
	pole.set_meta("landmark_type", "TELEGRAPH_POLE")

	var pm := CylinderMesh.new()
	pm.top_radius = pole_rad * 0.85
	pm.bottom_radius = pole_rad
	pm.height = pole_h
	# Dark weathered creosote-treated timber material
	pm.material = _make_mat(Color(0.24, 0.20, 0.16), 0.88, 0.05)
	pole.mesh = pm

	# Position vertically rooted into the playa floor
	pole.position = Vector3(0.0, pole_h * 0.48, 0.0)
	# Weathered cant / tilt from desert winds
	var tilt_x := deg_to_rad(scatter._rng.randf_range(-7.0, 7.0))
	var tilt_z := deg_to_rad(scatter._rng.randf_range(-6.0, 6.0))
	pole.rotation = Vector3(tilt_x, scatter._rng.randf() * TAU, tilt_z)

	_add_cylinder_collision(pole, pole_rad, pole_h)
	parent.add_child(pole)
	placed += 1

	# Crossarm near top of the pole
	var crossarm := MeshInstance3D.new()
	crossarm.name = "TelegraphCrossarm"
	crossarm.set_meta("ballistic_material", "WOOD")
	var cm := BoxMesh.new()
	var arm_w := scatter._rng.randf_range(1.3, 1.6)
	cm.size = Vector3(arm_w, 0.11, 0.11)
	cm.material = _make_mat(Color(0.28, 0.23, 0.18), 0.86, 0.04)
	crossarm.mesh = cm
	crossarm.position = Vector3(0.0, pole_h * 0.40, 0.0)
	crossarm.rotation = Vector3(0.0, deg_to_rad(65.0), deg_to_rad(scatter._rng.randf_range(-8.0, 8.0)))
	_add_box_collision(crossarm, cm.size)
	pole.add_child(crossarm)
	placed += 1

	# Ceramic Insulator Knobs (2 to 3 weathered insulators on the crossarm)
	for ins_i in range(2):
		var ins_x: float = (ins_i - 0.5) * (arm_w * 0.72)
		var insulator := MeshInstance3D.new()
		insulator.name = "CeramicInsulator_%d" % (ins_i + 1)
		var im := CylinderMesh.new()
		im.top_radius = 0.04
		im.bottom_radius = 0.055
		im.height = 0.14
		# Pale seafoam bleached ceramic insulator porcelain
		im.material = _make_mat(Color(0.80, 0.86, 0.82), 0.35, 0.15)
		insulator.mesh = im
		insulator.position = Vector3(ins_x, 0.10, 0.0)
		crossarm.add_child(insulator)
		placed += 1

	# Snapped dangling telegraph wire detritus (on some poles)
	if pole_index % 2 == 0:
		var wire := MeshInstance3D.new()
		wire.name = "DanglingWire"
		wire.set_meta("ballistic_material", "STEEL")
		var wm := BoxMesh.new()
		var wire_len := scatter._rng.randf_range(1.8, 3.2)
		wm.size = Vector3(0.02, wire_len, 0.02)
		wm.material = _make_mat(Color(0.18, 0.16, 0.15), 0.72, 0.80)
		wire.mesh = wm
		wire.position = Vector3(arm_w * 0.35, pole_h * 0.40 - wire_len * 0.45, 0.05)
		wire.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(5.0, 15.0)), 0.0, deg_to_rad(scatter._rng.randf_range(-10.0, 10.0)))
		pole.add_child(wire)
		placed += 1

	return placed

func _generate_salt_skeletal_cluster(parent: Node3D, cluster_index: int) -> int:
	var placed := 0

	# Sun-bleached calcified bone material
	var bone_mat := _make_mat(Color(0.88, 0.86, 0.80), 0.88, 0.02)

	# 1. Main Spine / Vertebral Column half embedded in the salt crust
	var vert_count := scatter._rng.randi_range(4, 6)
	var spine_dir := Vector2(cos(scatter._rng.randf() * TAU), sin(scatter._rng.randf() * TAU))

	for v_idx in range(vert_count):
		var vert := MeshInstance3D.new()
		vert.name = "TitanVertebra_%d" % (v_idx + 1)
		vert.set_meta("ballistic_material", "BONE")
		vert.set_meta("landmark_type", "BLEACHED_SKELETON")

		var vm := BoxMesh.new()
		var v_sz := Vector3(scatter._rng.randf_range(0.48, 0.72), scatter._rng.randf_range(0.42, 0.65), scatter._rng.randf_range(0.55, 0.80))
		vm.size = v_sz
		vm.material = bone_mat
		vert.mesh = vm

		var dist: float = (v_idx - vert_count * 0.5) * 0.95
		vert.position = Vector3(spine_dir.x * dist, v_sz.y * 0.28, spine_dir.y * dist)
		vert.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(-8.0, 8.0)), atan2(spine_dir.x, spine_dir.y), deg_to_rad(scatter._rng.randf_range(-8.0, 8.0)))
		_add_box_collision(vert, v_sz)
		parent.add_child(vert)
		placed += 1

	# 2. Arched Ribs clawing out of the salt crust (2 to 4 pairs)
	var rib_pairs := scatter._rng.randi_range(2, 4)
	for r_idx in range(rib_pairs):
		var r_offset: float = (r_idx - rib_pairs * 0.5) * 1.1
		for side in [-1.0, 1.0]:
			var rib := MeshInstance3D.new()
			rib.name = "TitanRib_%d_%s" % [r_idx + 1, "L" if side < 0.0 else "R"]
			rib.set_meta("ballistic_material", "BONE")
			rib.set_meta("landmark_type", "BLEACHED_SKELETON")

			var rm := CapsuleMesh.new()
			var r_len := scatter._rng.randf_range(1.6, 2.4)
			rm.radius = 0.08
			rm.height = r_len
			rm.material = bone_mat
			rib.mesh = rm

			var side_f: float = float(side)
			var lateral: Vector2 = Vector2(-spine_dir.y, spine_dir.x) * side_f * scatter._rng.randf_range(0.65, 1.1)
			var r_pos: Vector2 = Vector2(spine_dir.x * r_offset, spine_dir.y * r_offset) + lateral
			rib.position = Vector3(r_pos.x, r_len * 0.38, r_pos.y)
			# Arching upward and slightly inward toward the spine
			var arch_tilt := deg_to_rad(side * scatter._rng.randf_range(25.0, 42.0))
			rib.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(-12.0, 12.0)), atan2(spine_dir.x, spine_dir.y), arch_tilt)
			_add_static_collision(rib, r_len, r_len, r_len, "SKELETON")
			parent.add_child(rib)
			placed += 1

	# 3. Massive Desiccated Beast Cranium / Skull (at head of the spine)
	var skull := MeshInstance3D.new()
	skull.name = "TitanBeastSkull"
	skull.set_meta("ballistic_material", "BONE")
	skull.set_meta("landmark_type", "BLEACHED_SKELETON")

	var sm := BoxMesh.new()
	var s_sz := Vector3(0.85, 0.70, 1.35)
	sm.size = s_sz
	sm.material = bone_mat
	skull.mesh = sm

	var skull_pos := spine_dir * (vert_count * 0.55)
	skull.position = Vector3(skull_pos.x, s_sz.y * 0.35, skull_pos.y)
	skull.rotation = Vector3(deg_to_rad(scatter._rng.randf_range(10.0, 22.0)), atan2(spine_dir.x, spine_dir.y) + PI, deg_to_rad(scatter._rng.randf_range(-10.0, 10.0)))
	_add_box_collision(skull, s_sz)
	parent.add_child(skull)
	placed += 1

	# Bleached Horns / Tusks on the cranium (for clusters 0 and 3)
	if cluster_index == 0 or cluster_index == 3:
		for h_side in [-1.0, 1.0]:
			var horn := MeshInstance3D.new()
			horn.name = "CranialHorn_" + ("L" if h_side < 0.0 else "R")
			horn.set_meta("ballistic_material", "BONE")
			var hm := CylinderMesh.new()
			hm.top_radius = 0.03
			hm.bottom_radius = 0.12
			hm.height = 1.1
			hm.material = bone_mat
			horn.mesh = hm
			horn.position = Vector3(h_side * 0.42, 0.25, 0.45)
			horn.rotation = Vector3(deg_to_rad(28.0), deg_to_rad(h_side * 35.0), deg_to_rad(h_side * 22.0))
			_add_cylinder_collision(horn, 0.10, 1.1)
			skull.add_child(horn)
			placed += 1

	return placed

# ─── Node 3 Caliche Cradle & Thinny Overlook Landmarks ───────────────────────
## Populates landmark props unique to Caliche Cradle:
## 1. Weathered Stone Waymarkers at the central (0, 0) crossroads nexus.
## 2. Ruined Survey Tripod & Precipice Barricade at the NE Scenic Overlook (+140, +140).
## 3. Desiccated Desert Scrub clusters in limestone fissures.
