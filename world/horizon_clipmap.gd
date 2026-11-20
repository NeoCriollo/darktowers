class_name HorizonClipmap
extends Node3D

## Horizon Distant Clipmap & Distant Vista Generator
## Provides an extended horizon ring around the 2500m playable macro-footprint:
## - Concentric low-poly radial skirt meshes that match the desert horizon
## - Distant silhouettes of North Central Positronics Monorail pylons & towers
## - Fog-integrated low-draw-call horizon mesh for vast scale without FPS drops

@export var inner_radius: float = 1245.0
@export var outer_radius: float = 5000.0
@export var ring_segments: int = 64
@export var pylon_count: int = 24

func _ready() -> void:
	_build_horizon_skirt()
	_scatter_distant_monorail_pylons()

func _build_horizon_skirt() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Ring 1: inner to mid (1245m to 2800m)
	# Ring 2: mid to outer (2800m to 5000m)
	var radii := [inner_radius, 2800.0, outer_radius]
	var heights := [0.0, 25.0, 95.0] # Slowly rises at the edge of the world to meet the skybox

	for r_idx in range(radii.size() - 1):
		var r0: float = radii[r_idx]
		var r1: float = radii[r_idx + 1]
		var h0: float = heights[r_idx]
		var h1: float = heights[r_idx + 1]

		for s in range(ring_segments):
			var a0 := (float(s) / float(ring_segments)) * TAU
			var a1 := (float(s + 1) / float(ring_segments)) * TAU

			var v00 := Vector3(cos(a0) * r0, h0, sin(a0) * r0)
			var v10 := Vector3(cos(a1) * r0, h0, sin(a1) * r0)
			var v01 := Vector3(cos(a0) * r1, h1, sin(a0) * r1)
			var v11 := Vector3(cos(a1) * r1, h1, sin(a1) * r1)

			# Sample terrain height if available for the inner seam
			if r_idx == 0:
				v00.y = TerrainCollisionGenerator.sample_height(v00.x, v00.z)
				v10.y = TerrainCollisionGenerator.sample_height(v10.x, v10.z)

			st.set_color(Color(0.55, 0.42, 0.30, 1.0))
			st.add_vertex(v00)
			st.add_vertex(v10)
			st.add_vertex(v01)

			st.add_vertex(v10)
			st.add_vertex(v11)
			st.add_vertex(v01)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "DistantHorizonSkirt"
	mi.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.42, 0.30)
	mat.roughness = 0.95
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 900.0
	mat.distance_fade_max_distance = 1250.0
	mi.material_override = mat

	add_child(mi)

func _scatter_distant_monorail_pylons() -> void:
	# Monorail line passing along the Path of the Beam across the distant wastes
	var pylon_root := Node3D.new()
	pylon_root.name = "DistantMonorailTrack"
	add_child(pylon_root)

	var pylon_mesh := BoxMesh.new()
	pylon_mesh.size = Vector3(8.0, 85.0, 8.0)

	var track_mat := StandardMaterial3D.new()
	track_mat.albedo_color = Color(0.18, 0.15, 0.14)
	track_mat.roughness = 0.9

	var beam_angle := 0.785 # 0.785 rad (~45° NE) Beam direction
	var cos_b := cos(beam_angle)
	var sin_b := sin(beam_angle)

	for i in range(-pylon_count / 2, pylon_count / 2):
		var dist := float(i) * 220.0
		# Offset outside the 2500m playable basin
		if absf(dist) < 1300.0:
			continue

		var pos := Vector3(cos_b * dist, 25.0, sin_b * dist)
		# Tilted ruined stance
		var pylon := MeshInstance3D.new()
		pylon.mesh = pylon_mesh
		pylon.material_override = track_mat
		pylon.position = pos
		pylon.rotation_degrees = Vector3(randf_range(-6.0, 6.0), randf_range(0.0, 360.0), randf_range(-12.0, 12.0))
		pylon_root.add_child(pylon)

