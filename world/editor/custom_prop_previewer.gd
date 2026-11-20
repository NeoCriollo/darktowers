class_name CustomPropPreviewer
extends RefCounted

## CustomPropPreviewer: AABB Normalizer & Holo-Ghost Pre-Visualizer (Phase 5)
## Dynamically loads external .glb / .gltf 3D assets, calculates combined AABB extents,
## corrects off-center origin pivots, normalizes erratic scales to human scale (~2.5m),
## and manages semi-transparent amber holo-ghost previews before permanent stamping.

const TARGET_DEFAULT_SIZE: float = 2.5
const MAX_RAW_DIM_THRESHOLD: float = 50.0
const MIN_RAW_DIM_THRESHOLD: float = 0.15
const COLLISION_LAYER_WORLD: int = 1
const FLOOR_SHADER_PATH: String = "res://shaders/wasteland_flatfloor.gdshader"
const FLOOR_ALBEDO_PATH: String = "res://assets/textures/ground/mat.018_baseColor.jpg"
const FLOOR_NORMAL_PATH: String = "res://assets/textures/ground/mat.018_normal.jpg"
const FLOOR_ROUGH_PATH: String = "res://assets/textures/ground/mat.018_occlusion.png"

static var _ghost_material: StandardMaterial3D = null
static var _wasteland_floor_material: Material = null

static func get_ghost_material() -> StandardMaterial3D:
	if _ghost_material == null:
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_material.albedo_color = Color(0.92, 0.68, 0.22, 0.45)
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _ghost_material

static func get_wasteland_floor_material() -> Material:
	if _wasteland_floor_material == null:
		if ResourceLoader.exists(FLOOR_SHADER_PATH):
			var shader := load(FLOOR_SHADER_PATH) as Shader
			if shader != null:
				var smat := ShaderMaterial.new()
				smat.shader = shader
				if ResourceLoader.exists(FLOOR_ALBEDO_PATH):
					smat.set_shader_parameter("texture_gravel_albedo", load(FLOOR_ALBEDO_PATH))
				if ResourceLoader.exists(FLOOR_NORMAL_PATH):
					smat.set_shader_parameter("texture_gravel_normal", load(FLOOR_NORMAL_PATH))
				if ResourceLoader.exists(FLOOR_ROUGH_PATH):
					smat.set_shader_parameter("texture_gravel_roughness", load(FLOOR_ROUGH_PATH))
				_wasteland_floor_material = smat
				return _wasteland_floor_material

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.76, 0.63, 0.46, 1.0)
		mat.roughness = 0.88
		mat.metallic = 0.0
		mat.metallic_specular = 0.14
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 4.0
		mat.uv1_scale = Vector3(0.15, 0.15, 0.15)
		if ResourceLoader.exists(FLOOR_ALBEDO_PATH):
			mat.albedo_texture = load(FLOOR_ALBEDO_PATH) as Texture2D
		if ResourceLoader.exists(FLOOR_NORMAL_PATH):
			mat.normal_enabled = true
			mat.normal_texture = load(FLOOR_NORMAL_PATH) as Texture2D
		if ResourceLoader.exists(FLOOR_ROUGH_PATH):
			mat.roughness_texture = load(FLOOR_ROUGH_PATH) as Texture2D
		_wasteland_floor_material = mat
	return _wasteland_floor_material

static func apply_custom_prop_materials(root_node: Node, asset_path: String) -> void:
	if root_node == null:
		return
	var stem := asset_path.get_file().get_basename().to_lower()
	if stem.contains("flatfloor"):
		var floor_mat := get_wasteland_floor_material()
		var meshes: Array[MeshInstance3D] = []
		_gather_mesh_instances(root_node, meshes)
		for mi in meshes:
			mi.material_override = floor_mat

static func load_raw_scene(asset_path: String) -> Node3D:
	var raw_node: Node3D = null
	if ResourceLoader.exists(asset_path):
		var packed := load(asset_path) as PackedScene
		if packed != null:
			raw_node = packed.instantiate() as Node3D

	# Fallback runtime glTF document loading
	if raw_node == null and FileAccess.file_exists(asset_path):
		var gltf_doc := GLTFDocument.new()
		var gltf_state := GLTFState.new()
		var err := gltf_doc.append_from_file(asset_path, gltf_state)
		if err == OK:
			raw_node = gltf_doc.generate_scene(gltf_state) as Node3D
			_convert_importer_meshes(raw_node)

	# Headless or missing file procedural primitive fallback
	if raw_node == null:
		raw_node = _build_fallback_primitive(asset_path)

	# Execute automatic collision generation and material pass on newly instantiated .glb scene
	apply_custom_prop_materials(raw_node, asset_path)
	var stem := asset_path.get_file().get_basename()
	var mat_tag := EditorFolderScanner.infer_material_from_name(stem)
	generate_mesh_collisions(raw_node, COLLISION_LAYER_WORLD, mat_tag)

	return raw_node

static func calculate_combined_aabb(root_node: Node3D) -> AABB:
	var mesh_instances: Array[MeshInstance3D] = []
	_gather_mesh_instances(root_node, mesh_instances)

	if mesh_instances.is_empty():
		return AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 2.0, 2.0))

	var min_bound := Vector3(INF, INF, INF)
	var max_bound := Vector3(-INF, -INF, -INF)

	for mi in mesh_instances:
		if mi.mesh == null:
			continue
		var raw_aabb := mi.mesh.get_aabb()
		var rel_xform := (root_node.global_transform.affine_inverse() * mi.global_transform) if (root_node.is_inside_tree() and mi.is_inside_tree()) else _compute_relative_transform(root_node, mi)

		# Transform all 8 bounding box corners
		for i in range(8):
			var corner := Vector3(
				raw_aabb.position.x + (raw_aabb.size.x if (i & 1) else 0.0),
				raw_aabb.position.y + (raw_aabb.size.y if (i & 2) else 0.0),
				raw_aabb.position.z + (raw_aabb.size.z if (i & 4) else 0.0)
			)
			var pt := rel_xform * corner
			min_bound = min_bound.min(pt)
			max_bound = max_bound.max(pt)

	var size := (max_bound - min_bound).max(Vector3(0.1, 0.1, 0.1))
	return AABB(min_bound, size)

static func compute_normalization(aabb: AABB, target_size: float = TARGET_DEFAULT_SIZE) -> Dictionary:
	var max_dim: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var scale_factor: float = 1.0

	if max_dim > MAX_RAW_DIM_THRESHOLD or max_dim < MIN_RAW_DIM_THRESHOLD:
		scale_factor = target_size / max_dim

	# Pivot offset to align bottom of bounding box at Y=0 and center X/Z at 0
	var bottom_center := Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5
	)
	var pivot_offset := -bottom_center

	return {
		"scale_factor": scale_factor,
		"pivot_offset": pivot_offset,
		"max_dimension": max_dim,
		"normalized_size": aabb.size * scale_factor
	}

static func instantiate_custom_prop(asset_path: String, world_root: Node = null) -> Node3D:
	var raw_model := load_raw_scene(asset_path)
	var stem := asset_path.get_file().get_basename()
	var mat_tag := EditorFolderScanner.infer_material_from_name(stem)

	# Ensure collision pass is applied (idempotent if already run in load_raw_scene)
	generate_mesh_collisions(raw_model, COLLISION_LAYER_WORLD, mat_tag)

	var aabb := calculate_combined_aabb(raw_model)
	var norm := compute_normalization(aabb)

	var container := Node3D.new()
	container.name = "CustomProp_%s" % stem

	# Reparent and center raw model inside container
	var model_anchor := Node3D.new()
	model_anchor.name = "ModelPivot"
	model_anchor.position = norm["pivot_offset"]
	model_anchor.add_child(raw_model)
	container.add_child(model_anchor)

	var s_fac: float = norm["scale_factor"]
	container.scale = Vector3(s_fac, s_fac, s_fac)

	# Fallback collision body only if model has zero mesh colliders
	if not _has_any_collision(raw_model):
		var sb := StaticBody3D.new()
		sb.name = "ColBody"
		sb.collision_layer = COLLISION_LAYER_WORLD
		sb.collision_mask = 0
		sb.set_meta("ballistic_material", mat_tag)
		sb.set_meta("reactive_target", true)

		var cs := CollisionShape3D.new()
		cs.name = "BoxCol"
		var box := BoxShape3D.new()
		box.size = aabb.size
		cs.shape = box
		cs.position = aabb.position + aabb.size * 0.5
		sb.add_child(cs)
		model_anchor.add_child(sb)

	# Metadata tags
	container.set_meta("asset_path", asset_path)
	container.set_meta("ballistic_material", mat_tag)
	container.set_meta("reactive_target", true)
	container.set_meta("normalized_scale_factor", s_fac)

	if world_root != null:
		world_root.add_child(container)

	return container

static func create_holo_ghost(asset_path: String) -> Node3D:
	var prop := instantiate_custom_prop(asset_path, null)
	prop.name = "HoloGhost_" + prop.name

	# Disable all collisions on ghost preview
	disable_all_collisions(prop)

	# Apply amber unshaded ghost overlay
	var ghost_mat := get_ghost_material()
	var meshes: Array[MeshInstance3D] = []
	_gather_mesh_instances(prop, meshes)
	for mi in meshes:
		mi.material_override = ghost_mat

	return prop

static func update_holo_ghost_placement(
	ghost: Node3D,
	camera: Camera3D,
	distance: float = 16.0,
	sink_depth: float = 0.0
) -> void:
	if ghost == null or camera == null:
		return
	var cam_pos := camera.global_position
	var forward := -camera.global_transform.basis.z
	var target_pos := cam_pos + forward * distance
	var ground_y := TerrainCollisionGenerator.sample_height(target_pos.x, target_pos.z)
	target_pos.y = ground_y - sink_depth
	ghost.global_position = target_pos

static func _gather_mesh_instances(node: Node, out_list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_list.append(node as MeshInstance3D)
	for child in node.get_children():
		_gather_mesh_instances(child, out_list)

static func _convert_importer_meshes(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		_convert_importer_meshes(child)
		if child.get_class() == "ImporterMeshInstance3D":
			var imp_mesh: Variant = child.get("mesh")
			var arr_mesh: ArrayMesh = imp_mesh.call("get_mesh") if (imp_mesh != null and imp_mesh.has_method("get_mesh")) else null
			var mi := MeshInstance3D.new()
			mi.name = child.name
			if child is Node3D:
				mi.transform = (child as Node3D).transform
			mi.mesh = arr_mesh
			for grand in child.get_children():
				child.remove_child(grand)
				mi.add_child(grand)
			var idx := child.get_index()
			node.remove_child(child)
			node.add_child(mi)
			node.move_child(mi, idx)
			child.free()

static func _compute_relative_transform(root_node: Node3D, target_node: Node3D) -> Transform3D:
	var rel := Transform3D.IDENTITY
	var curr: Node = target_node
	while curr != null and curr != root_node:
		if curr is Node3D:
			rel = (curr as Node3D).transform * rel
		curr = curr.get_parent()
	return rel

static func _build_fallback_primitive(asset_path: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "FallbackMesh"
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 3.0, 2.0)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.40, 0.32)
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = Vector3(0.0, 1.5, 0.0)
	root.add_child(mi)
	return root

## Automatically generates collision for any MeshInstance3D lacking collision in the hierarchy.
## Uses Godot's create_convex_collision() (or create_trimesh_collision() if use_trimesh is true)
## and assigns the generated StaticBody3D to the specified collision layer (Environment/World layer 1).
static func generate_mesh_collisions(
	root_node: Node,
	collision_layer: int = COLLISION_LAYER_WORLD,
	ballistic_material: String = "",
	use_trimesh: bool = true
) -> int:
	if root_node == null:
		return 0

	var mesh_instances: Array[MeshInstance3D] = []
	_gather_mesh_instances(root_node, mesh_instances)

	var generated_count: int = 0
	for mi in mesh_instances:
		if mi.mesh == null:
			continue
		if _mesh_has_collision(mi):
			_ensure_existing_collision_layer(mi, collision_layer, ballistic_material)
			continue

		if use_trimesh:
			mi.create_trimesh_collision()
		else:
			mi.create_convex_collision()

		_configure_generated_static_bodies(mi, collision_layer, ballistic_material)
		generated_count += 1

	return generated_count

static func _mesh_has_collision(mi: MeshInstance3D) -> bool:
	# 1. Direct children of the MeshInstance3D
	for child in mi.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			return true

	# 2. Direct parent or ancestor CollisionObject3D
	var parent := mi.get_parent()
	while parent != null:
		if parent is CollisionObject3D:
			return true
		if parent.name == "ModelPivot" or parent.name.begins_with("CustomProp_"):
			break
		parent = parent.get_parent()

	# 3. Siblings under same parent with collision shapes or dedicated static body
	if mi.get_parent() != null:
		for sib in mi.get_parent().get_children():
			if sib == mi:
				continue
			if sib is CollisionShape3D:
				return true
			if sib is CollisionObject3D:
				var s_name := sib.name.to_lower()
				var m_name := mi.name.to_lower()
				if not m_name.is_empty() and s_name.begins_with(m_name):
					return true

	return false

static func _configure_generated_static_bodies(
	mi: MeshInstance3D,
	collision_layer: int,
	ballistic_material: String
) -> void:
	for child in mi.get_children():
		if child is StaticBody3D:
			var sb := child as StaticBody3D
			sb.collision_layer = collision_layer
			sb.collision_mask = 0
			if not ballistic_material.is_empty():
				sb.set_meta("ballistic_material", ballistic_material)
			sb.set_meta("reactive_target", true)
			_enable_backface_collision(sb)

	var parent := mi.get_parent()
	if parent != null:
		for sib in parent.get_children():
			if sib is StaticBody3D and sib != mi:
				var sb := sib as StaticBody3D
				var s_name := sb.name.to_lower()
				var m_name := mi.name.to_lower()
				if not m_name.is_empty() and s_name.begins_with(m_name):
					sb.collision_layer = collision_layer
					sb.collision_mask = 0
					if not ballistic_material.is_empty():
						sb.set_meta("ballistic_material", ballistic_material)
					sb.set_meta("reactive_target", true)
					_enable_backface_collision(sb)

static func _enable_backface_collision(sb: Node) -> void:
	for ch in sb.get_children():
		if ch is CollisionShape3D and (ch as CollisionShape3D).shape is ConcavePolygonShape3D:
			((ch as CollisionShape3D).shape as ConcavePolygonShape3D).backface_collision = true

static func _ensure_existing_collision_layer(
	mi: MeshInstance3D,
	collision_layer: int,
	ballistic_material: String
) -> void:
	for child in mi.get_children():
		if child is CollisionObject3D:
			var co := child as CollisionObject3D
			if co.collision_layer == 0:
				co.collision_layer = collision_layer
			if not ballistic_material.is_empty() and not co.has_meta("ballistic_material"):
				co.set_meta("ballistic_material", ballistic_material)
			co.set_meta("reactive_target", true)

	var parent := mi.get_parent()
	if parent != null and parent is CollisionObject3D:
		var co := parent as CollisionObject3D
		if co.collision_layer == 0:
			co.collision_layer = collision_layer
		if not ballistic_material.is_empty() and not co.has_meta("ballistic_material"):
			co.set_meta("ballistic_material", ballistic_material)
		co.set_meta("reactive_target", true)

static func _has_any_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _has_any_collision(child):
			return true
	return false

static func disable_all_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		var co := node as CollisionObject3D
		co.collision_layer = 0
		co.collision_mask = 0
	for child in node.get_children():
		disable_all_collisions(child)

