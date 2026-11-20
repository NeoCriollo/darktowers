class_name WorldCullingAndBounds
extends RefCounted

## Topological Bubble Graph, Sector Geometry Tables, and Chunk Culling Helpers
## Extracted from WorldManager to maintain modular architectural boundaries.

class WastelandBubble:
	var id: String
	var name: String
	var center: Vector2
	var radius: float
	var connected_bubble_ids: Array[String] = []
	var is_safe_zone: bool = false

	func _init(p_id: String, p_name: String, p_center: Vector2, p_radius: float, p_connections: Array[String], p_safe_zone: bool = false) -> void:
		id = p_id; name = p_name; center = p_center; radius = p_radius
		connected_bubble_ids = p_connections; is_safe_zone = p_safe_zone

class CanyonPass:
	var id: String
	var from_bubble_id: String
	var to_bubble_id: String
	var waypoint_a: Vector2
	var waypoint_b: Vector2
	var half_width: float

	func _init(p_id: String, p_from: String, p_to: String, p_a: Vector2, p_b: Vector2, p_half_width: float) -> void:
		id = p_id; from_bubble_id = p_from; to_bubble_id = p_to
		waypoint_a = p_a; waypoint_b = p_b; half_width = p_half_width

class CullUnit:
	var node: Node3D
	var pos: Vector2
	var radius: float
	var bubble_id: String
	var applied_visible: bool = true
	var target_visible: bool = true
	var queued: bool = false

static func build_topological_graph(bubbles: Dictionary, passes: Array) -> void:
	bubbles["waystation_sanctuary"] = WastelandBubble.new("waystation_sanctuary", "The Mohaine Way-Bunker", Vector2(-1000.0, -800.0), 150.0, ["sw_desolation", "south_salt"], true)
	bubbles["sw_desolation"] = WastelandBubble.new("sw_desolation", "Southwest Desolation", Vector2(-550.0, -900.0), 250.0, ["waystation_sanctuary", "south_salt"])
	bubbles["south_salt"] = WastelandBubble.new("south_salt", "Dead-Creek Salt Flats", Vector2(-150.0, -550.0), 250.0, ["waystation_sanctuary", "sw_desolation", "cradle"])
	bubbles["cradle"] = WastelandBubble.new("cradle", "Caliche Cradle Nexus", Vector2(0.0, 0.0), 250.0, ["south_salt", "west_gorge", "north_alkali", "east_dunes"])
	bubbles["west_gorge"] = WastelandBubble.new("west_gorge", "Rust-Gorge Defile", Vector2(-650.0, 50.0), 250.0, ["cradle", "north_alkali"])
	bubbles["north_alkali"] = WastelandBubble.new("north_alkali", "Bleached Alkali Sink", Vector2(0.0, 650.0), 250.0, ["cradle", "west_gorge", "monolith_pass"])
	bubbles["east_dunes"] = WastelandBubble.new("east_dunes", "The Great Shifting Erg", Vector2(650.0, 50.0), 250.0, ["cradle", "monolith_pass"])
	bubbles["monolith_pass"] = WastelandBubble.new("monolith_pass", "Threshold of the Dark Tower", Vector2(650.0, 650.0), 250.0, ["north_alkali", "east_dunes"])

	passes.append(CanyonPass.new("pass_sanctuary_to_sw", "waystation_sanctuary", "sw_desolation", Vector2(-900.0, -820.0), Vector2(-650.0, -880.0), 18.0))
	passes.append(CanyonPass.new("pass_sanctuary_to_salt", "waystation_sanctuary", "south_salt", Vector2(-950.0, -780.0), Vector2(-280.0, -650.0), 14.0))
	passes.append(CanyonPass.new("pass_sw_to_salt", "sw_desolation", "south_salt", Vector2(-450.0, -800.0), Vector2(-250.0, -650.0), 18.0))
	passes.append(CanyonPass.new("pass_salt_to_cradle", "south_salt", "cradle", Vector2(-100.0, -420.0), Vector2(-30.0, -150.0), 18.0))
	passes.append(CanyonPass.new("pass_cradle_to_gorge", "cradle", "west_gorge", Vector2(-150.0, 15.0), Vector2(-500.0, 40.0), 16.0))
	passes.append(CanyonPass.new("pass_cradle_to_north", "cradle", "north_alkali", Vector2(0.0, 150.0), Vector2(0.0, 500.0), 18.0))
	passes.append(CanyonPass.new("pass_cradle_to_east", "cradle", "east_dunes", Vector2(150.0, 15.0), Vector2(500.0, 40.0), 18.0))
	passes.append(CanyonPass.new("pass_gorge_to_north", "west_gorge", "north_alkali", Vector2(-500.0, 180.0), Vector2(-150.0, 520.0), 16.0))
	passes.append(CanyonPass.new("pass_north_to_monolith", "north_alkali", "monolith_pass", Vector2(150.0, 650.0), Vector2(500.0, 650.0), 18.0))
	passes.append(CanyonPass.new("pass_east_to_monolith", "east_dunes", "monolith_pass", Vector2(650.0, 150.0), Vector2(650.0, 500.0), 18.0))

static func distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func nearest_bubble_id(p: Vector2, bubbles: Dictionary) -> String:
	var best := ""
	var best_d := INF
	for id in bubbles:
		var d := p.distance_squared_to((bubbles[id] as WastelandBubble).center)
		if d < best_d:
			best_d = d
			best = id
	return best

static func resolve_active_bubble(player_xz: Vector2, bubbles: Dictionary, current_id: String, hysteresis: float) -> String:
	if bubbles.has(current_id):
		var cur: WastelandBubble = bubbles[current_id]
		if player_xz.distance_to(cur.center) <= cur.radius + hysteresis:
			return current_id
	return nearest_bubble_id(player_xz, bubbles)

static func resolve_active_pass(player_xz: Vector2, passes: Array) -> String:
	for p in passes:
		if distance_to_segment_2d(player_xz, p.waypoint_a, p.waypoint_b) <= p.half_width:
			return p.id
	return ""

static func is_safe_zone(bubble_id: String, bubbles: Dictionary) -> bool:
	if bubbles.has(bubble_id):
		return (bubbles[bubble_id] as WastelandBubble).is_safe_zone
	return false

static func is_position_in_safe_zone(pos_2d: Vector2, bubbles: Dictionary) -> bool:
	for id in bubbles:
		var b: WastelandBubble = bubbles[id]
		if b.is_safe_zone and pos_2d.distance_to(b.center) <= b.radius:
			return true
	return false

static func build_terrain_chunks(
		parent: Node3D,
		terrain_source: MeshInstance3D,
		world_size: float,
		chunks_per_side: int,
		lod_subdivs: Array,
		lod_dists: Array,
		lod0_chunks: Array[MeshInstance3D],
		lod1_chunks: Array[MeshInstance3D],
		far_lod_chunks: Array[MeshInstance3D]) -> void:

	if terrain_source == null or terrain_source.mesh == null:
		return
	var mat := terrain_source.get_active_material(0)
	if mat == null:
		push_warning("WorldCullingAndBounds: terrain has no material, chunking skipped")
		return

	var max_elevation := 16.0; var min_elevation := -32.0; var skirt_depth := 4.0
	var chunk_size := world_size / float(chunks_per_side)
	var lod_meshes: Array[ArrayMesh] = [
		build_chunk_mesh(chunk_size, int(lod_subdivs[0]), skirt_depth, max_elevation, min_elevation),
		build_chunk_mesh(chunk_size, int(lod_subdivs[1]), skirt_depth, max_elevation, min_elevation),
		build_chunk_mesh(chunk_size, int(lod_subdivs[2]), skirt_depth, max_elevation, min_elevation),
	]
	var lod_begin: Array[float] = [0.0, float(lod_dists[0]), float(lod_dists[1])]
	var lod_end: Array[float] = [float(lod_dists[0]), float(lod_dists[1]), float(lod_dists[2])]

	var root := Node3D.new()
	root.name = "TerrainChunks"
	parent.add_child(root)
	root.global_transform = terrain_source.global_transform

	var half := world_size * 0.5
	for cz in range(chunks_per_side):
		for cx in range(chunks_per_side):
			var center := Vector3(-half + chunk_size * (cx + 0.5), 0.0, -half + chunk_size * (cz + 0.5))
			for lod in range(3):
				var mi := MeshInstance3D.new()
				mi.name = "Chunk_%d_%d_LOD%d" % [cx, cz, lod]
				mi.mesh = lod_meshes[lod]
				mi.material_override = mat
				mi.position = center
				mi.visibility_range_begin = lod_begin[lod]
				mi.visibility_range_end = lod_end[lod]
				if lod >= 1:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if lod == 0:
					lod0_chunks.append(mi)
				elif lod == 1:
					lod1_chunks.append(mi)
				elif lod == 2:
					far_lod_chunks.append(mi)
				root.add_child(mi)

	terrain_source.visible = false

static func build_chunk_mesh(size: float, subdiv: int, skirt_depth: float, max_elevation: float, min_elevation: float) -> ArrayMesh:
	var n := subdiv + 1
	var step := size / float(subdiv)
	var half := size * 0.5
	var verts := PackedVector3Array(); var normals := PackedVector3Array()
	var tangents := PackedFloat32Array(); var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for z in range(n):
		for x in range(n):
			verts.append(Vector3(-half + x * step, 0.0, -half + z * step))
			normals.append(Vector3.UP)
			tangents.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
			uvs.append(Vector2(float(x) / subdiv, float(z) / subdiv))

	for z in range(subdiv):
		for x in range(subdiv):
			var a := z * n + x; var b := a + 1; var c := a + n; var d := c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))

	var edge_zmin := PackedInt32Array(); var edge_zmax := PackedInt32Array()
	var edge_xmin := PackedInt32Array(); var edge_xmax := PackedInt32Array()
	for i in range(n):
		edge_zmin.append(i); edge_zmax.append((n - 1) * n + i)
		edge_xmin.append(i * n); edge_xmax.append(i * n + (n - 1))
	var edges: Array[PackedInt32Array] = [edge_zmin, edge_zmax, edge_xmin, edge_xmax]

	for edge in edges:
		var bottom_start := verts.size()
		for top_idx in edge:
			var tv := verts[top_idx]
			verts.append(Vector3(tv.x, -skirt_depth, tv.z))
			normals.append(Vector3.UP)
			tangents.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
			uvs.append(uvs[top_idx])
		for k in range(edge.size() - 1):
			var t0 := edge[k]; var t1 := edge[k + 1]
			var b0 := bottom_start + k; var b1 := bottom_start + k + 1
			indices.append_array(PackedInt32Array([t0, t1, b0, t1, b1, b0, t0, b0, t1, t1, b0, b1]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents; arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(
		Vector3(-half, min_elevation - skirt_depth, -half),
		Vector3(size, (max_elevation - min_elevation) + skirt_depth * 2.0, size))
	return mesh

static func apply_small_prop_ranges(root: Node, small_max: float, small_end: float, med_max: float, med_end: float) -> void:
	for child in root.get_children():
		if child.name == "HorizonLandmark_DarkTower":
			continue
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh != null:
				var size := mi.mesh.get_aabb().size
				var longest := maxf(size.x, maxf(size.y, size.z))
				var end_dist := 0.0
				if longest <= small_max:
					end_dist = small_end
				elif longest <= med_max:
					end_dist = med_end
				if end_dist > 0.0:
					mi.visibility_range_end = end_dist
					mi.visibility_range_end_margin = end_dist * 0.15
					mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		apply_small_prop_ranges(child, small_max, small_end, med_max, med_end)

static func apply_unit(unit: CullUnit) -> void:
	unit.queued = false
	if not is_instance_valid(unit.node) or unit.target_visible == unit.applied_visible:
		return
	unit.applied_visible = unit.target_visible
	unit.node.visible = unit.target_visible
	unit.node.process_mode = Node.PROCESS_MODE_INHERIT if unit.target_visible else Node.PROCESS_MODE_DISABLED

