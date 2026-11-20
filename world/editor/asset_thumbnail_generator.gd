class_name AssetThumbnailGenerator
extends RefCounted

## AssetThumbnailGenerator: Production-Grade SubViewport Asset Thumbnail Baker (Metal/Vulkan)
## Two-tier caching (RAM + user://thumbnail_cache/*.png), Frame-Post-Draw Synchronization,
## Automatic AABB Camera Framing, and procedural visual fallback generation.

const EditorAssetCatalogScript = preload("res://world/editor/editor_asset_catalog.gd")
const EditorFolderScannerScript = preload("res://world/editor/editor_folder_scanner.gd")
const RockPackLibraryScript = preload("res://world/props/rock_pack_library.gd")

const AMBER_GOLD := Color(0.88, 0.65, 0.28, 1.0) # #E1A647
const OBSIDIAN_BG := Color(0.08, 0.07, 0.06, 1.0)
const DISK_CACHE_DIR := "user://thumbnail_cache/"
const DEFAULT_FOV := 38.0
const DEFAULT_MARGIN := 1.35
const DEFAULT_SPIN_SPEED := 0.8

static var _texture_cache: Dictionary = {}
static var _placeholder_cache: Dictionary = {}
static var _rock_lib: RefCounted = null
static var _baker_viewport: SubViewport = null
static var _baker_pivot: Node3D = null
static var _baker_camera: Camera3D = null
static var _disk_dir_ensured: bool = false

# ─── Two-Tier Texture Cache Management ───────────────────────────────────────

static func get_cache_key(asset_id: String, resolution: int = 128) -> String:
	var clean_id := asset_id.to_lower().replace("/", "_").replace(".", "_").replace(":", "_").replace("-", "_")
	return "thumb_%s_%d" % [clean_id, resolution]

static func has_cached_texture(cache_key: String) -> bool:
	if _texture_cache.has(cache_key) and _texture_cache[cache_key] != null:
		return true
	return _has_disk_thumbnail(cache_key)

static func get_cached_texture(cache_key: String) -> Texture2D:
	if _texture_cache.has(cache_key) and _texture_cache[cache_key] != null:
		return _texture_cache[cache_key]
	var disk_tex := _load_disk_thumbnail(cache_key)
	if disk_tex != null:
		_texture_cache[cache_key] = disk_tex
		return disk_tex
	return null

static func store_cached_texture(cache_key: String, texture: Texture2D) -> void:
	if texture != null:
		_texture_cache[cache_key] = texture
		_save_disk_thumbnail(cache_key, texture)

static func clear_texture_cache() -> void:
	_texture_cache.clear()

static func get_cache_size() -> int:
	return _texture_cache.size()

static func _ensure_disk_cache_dir() -> void:
	if _disk_dir_ensured:
		return
	if not DirAccess.dir_exists_absolute(DISK_CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(DISK_CACHE_DIR)
	_disk_dir_ensured = true

static func _has_disk_thumbnail(cache_key: String) -> bool:
	_ensure_disk_cache_dir()
	var path := DISK_CACHE_DIR.path_join(cache_key + ".png")
	return FileAccess.file_exists(path)

static func _load_disk_thumbnail(cache_key: String) -> Texture2D:
	_ensure_disk_cache_dir()
	var path := DISK_CACHE_DIR.path_join(cache_key + ".png")
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	return null

static func _save_disk_thumbnail(cache_key: String, texture: Texture2D) -> void:
	_ensure_disk_cache_dir()
	var path := DISK_CACHE_DIR.path_join(cache_key + ".png")
	if FileAccess.file_exists(path):
		return
	var img: Image = texture.get_image() if texture != null else null
	if img != null and not img.is_empty():
		img.save_png(path)

# ─── Procedural Placeholder Texture ──────────────────────────────────────────

static func get_procedural_placeholder(asset_id: String, resolution: int = 128) -> Texture2D:
	var key := "ph_%d" % resolution
	if _placeholder_cache.has(key) and _placeholder_cache[key] != null:
		return _placeholder_cache[key]

	var img := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	img.fill(OBSIDIAN_BG)
	var border_col := Color(0.35, 0.28, 0.16, 0.9)
	var cross_col := Color(0.55, 0.40, 0.18, 0.4)

	for x in range(resolution):
		img.set_pixel(x, 0, border_col)
		img.set_pixel(x, resolution - 1, border_col)
		img.set_pixel(x, x, cross_col)
		img.set_pixel(x, resolution - 1 - x, cross_col)
	for y in range(resolution):
		img.set_pixel(0, y, border_col)
		img.set_pixel(resolution - 1, y, border_col)

	var tex := ImageTexture.create_from_image(img)
	_placeholder_cache[key] = tex
	return tex

# ─── Bounding Box & Camera Framing Mathematics ───────────────────────────────

static func compute_hierarchy_aabb(root_node: Node3D) -> AABB:
	if root_node == null:
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1.0, 1.0, 1.0))

	var meshes: Array[MeshInstance3D] = []
	_gather_meshes_recursive(root_node, meshes)

	if meshes.is_empty():
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1.0, 1.0, 1.0))

	var inv_root := root_node.global_transform.affine_inverse()
	var total_aabb := AABB()
	var is_first := true

	for mi in meshes:
		if mi.mesh == null:
			continue
		var raw_mesh_aabb := mi.mesh.get_aabb()
		var rel_xform := inv_root * mi.global_transform
		var mi_aabb := rel_xform * raw_mesh_aabb
		if is_first:
			total_aabb = mi_aabb
			is_first = false
		else:
			total_aabb = total_aabb.merge(mi_aabb)

	if is_first:
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1.0, 1.0, 1.0))

	var sz := total_aabb.size
	sz.x = maxf(sz.x, 0.2)
	sz.y = maxf(sz.y, 0.2)
	sz.z = maxf(sz.z, 0.2)
	total_aabb.size = sz
	return total_aabb

static func _gather_meshes_recursive(node: Node, out_list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_list.append(node)
	for child in node.get_children():
		_gather_meshes_recursive(child, out_list)

static func frame_camera_to_aabb(camera: Camera3D, aabb: AABB, fov_degrees: float = DEFAULT_FOV, margin: float = DEFAULT_MARGIN) -> void:
	if camera == null:
		return
	var center := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	var half_fov_rad := deg_to_rad(fov_degrees * 0.5)
	var sin_fov := maxf(0.02, sin(half_fov_rad))
	var distance := maxf(0.8, (radius / sin_fov) * margin)

	var offset_dir := Vector3(0.65, 0.45, 0.85).normalized()
	camera.fov = fov_degrees
	camera.position = center + offset_dir * distance
	camera.look_at(center, Vector3.UP)

# ─── Preview Mesh Factory & Safe Fallbacks ───────────────────────────────────

static func create_fallback_mesh() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackPlaceholder"
	var mi := MeshInstance3D.new()
	mi.name = "PlaceholderCube"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 1.4, 1.4)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.10, 0.08)
	mat.metallic = 0.5
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = AMBER_GOLD
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	root.add_child(mi)
	return root

static func instantiate_asset_preview_mesh(asset_id: String, asset_entry: Dictionary = {}) -> Node3D:
	if asset_id.is_empty() and asset_entry.is_empty():
		return create_fallback_mesh()
	var entry: Dictionary = asset_entry
	if entry.is_empty():
		entry = EditorAssetCatalogScript.get_asset_info(asset_id)
	if entry.is_empty():
		return create_fallback_mesh()

	var cat: String = entry.get("category", "")
	if cat == "rocks":
		return _build_rock_preview(entry)
	elif cat == "custom":
		return _build_custom_preview(entry)
	elif cat == "architecture":
		return _build_architecture_preview(entry)
	elif cat == "props":
		return _build_prop_preview(entry)
	return create_fallback_mesh()

static func _build_rock_preview(entry: Dictionary) -> Node3D:
	if _rock_lib == null:
		_rock_lib = RockPackLibraryScript.new()
		_rock_lib.load_library()
	var glb_name: String = entry.get("glb_name", "")
	var s_vec: Vector3 = entry.get("scale", Vector3.ONE)
	var max_dim := maxf(s_vec.x, maxf(s_vec.y, s_vec.z))
	var norm_scale := Vector3.ONE
	if max_dim > 0.001:
		norm_scale = s_vec / max_dim * 2.0
	var rock_node: Node3D = _rock_lib.create_rock_node(glb_name, norm_scale, false)
	return rock_node if rock_node != null else create_fallback_mesh()

static func _build_custom_preview(entry: Dictionary) -> Node3D:
	var path: String = entry.get("asset_path", "")
	if path.is_empty():
		return create_fallback_mesh()

	var inst: Node3D = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var scene_res := load(path) as PackedScene
		if scene_res != null:
			inst = scene_res.instantiate() as Node3D
	elif FileAccess.file_exists(path):
		var gltf_doc := GLTFDocument.new()
		var gltf_state := GLTFState.new()
		var err := gltf_doc.append_from_file(path, gltf_state)
		if err == OK:
			inst = gltf_doc.generate_scene(gltf_state) as Node3D

	if inst == null:
		return create_fallback_mesh()
	CustomPropPreviewer.apply_custom_prop_materials(inst, path)
	_strip_colliders(inst)
	return inst

static func _build_architecture_preview(entry: Dictionary) -> Node3D:
	var id: String = entry.get("id", "")
	match id:
		"monolith_pylon":
			var pylon_path := "res://assets/architecture/landmarks/dark_tower/dark_tower_beacon_monolith_pylon.glb"
			if ResourceLoader.exists(pylon_path):
				var p_res := load(pylon_path) as PackedScene
				if p_res != null:
					var inst := p_res.instantiate() as Node3D
					_strip_colliders(inst)
					return inst
			return _build_box_primitive(Vector3(1.2, 4.0, 1.2), Color(0.15, 0.15, 0.18))
		"bunker_slab":
			return _build_box_primitive(Vector3(4.0, 0.4, 4.0), Color(0.25, 0.23, 0.20))
		"highway_pillar":
			return _build_box_primitive(Vector3(1.5, 4.5, 1.5), Color(0.28, 0.26, 0.24))
		"midworld_door":
			return _build_box_primitive(Vector3(1.4, 2.6, 0.15), Color(0.35, 0.25, 0.18))
	return create_fallback_mesh()

static func _build_prop_preview(entry: Dictionary) -> Node3D:
	var id: String = entry.get("id", "")
	match id:
		"supply_crate":
			return _build_box_primitive(Vector3(1.5, 1.2, 1.5), Color(0.32, 0.35, 0.30))
		"thinny_anomaly":
			var sphere := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0; sm.height = 2.0; sphere.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.1, 0.7, 0.9, 0.8)
			mat.emission_enabled = true; mat.emission = Color(0.2, 0.8, 1.0); mat.emission_energy_multiplier = 0.8
			sphere.material_override = mat
			var root := Node3D.new(); root.add_child(sphere); return root
		"telegraph_pole":
			return _build_box_primitive(Vector3(0.3, 4.0, 0.3), Color(0.28, 0.22, 0.16))
		"skeleton_debris":
			return _build_box_primitive(Vector3(2.2, 0.4, 1.5), Color(0.75, 0.72, 0.65))
	return create_fallback_mesh()

static func _build_box_primitive(size: Vector3, albedo: Color) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = albedo; mat.roughness = 0.8
	mi.material_override = mat
	mi.position = Vector3(0.0, size.y * 0.5, 0.0)
	root.add_child(mi)
	return root

static func _strip_colliders(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape3D or child is CollisionPolygon3D or child is StaticBody3D:
			child.queue_free()
		else:
			_strip_colliders(child)

# ─── Staging Viewport Rigging ────────────────────────────────────────────────

static func setup_preview_rig(viewport: SubViewport, asset_id: String, asset_entry: Dictionary = {}) -> Dictionary:
	if viewport == null:
		return {}

	for child in viewport.get_children():
		child.queue_free()

	viewport.own_world_3d = true
	viewport.transparent_bg = false

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = OBSIDIAN_BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.32, 0.25)
	env.ambient_light_energy = 1.1
	env_node.environment = env
	viewport.add_child(env_node)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_color = Color(1.0, 0.95, 0.85)
	key_light.light_energy = 1.4
	key_light.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	viewport.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_color = Color(0.45, 0.50, 0.60)
	fill_light.light_energy = 0.7
	fill_light.rotation_degrees = Vector3(25.0, -135.0, 0.0)
	viewport.add_child(fill_light)

	var pivot := Node3D.new(); pivot.name = "PreviewPivot"; viewport.add_child(pivot)
	var model := instantiate_asset_preview_mesh(asset_id, asset_entry)
	pivot.add_child(model)

	var aabb := compute_hierarchy_aabb(model)
	var center := aabb.get_center()
	model.position = -center

	var camera := Camera3D.new(); camera.name = "PreviewCamera"; viewport.add_child(camera)
	var centered_aabb := AABB(-aabb.size * 0.5, aabb.size)
	frame_camera_to_aabb(camera, centered_aabb, DEFAULT_FOV, DEFAULT_MARGIN)

	return { "pivot": pivot, "camera": camera, "model": model, "aabb": aabb }

static func apply_spin_step(pivot: Node3D, delta: float, speed_rad: float = DEFAULT_SPIN_SPEED) -> void:
	if is_instance_valid(pivot):
		pivot.rotate_y(speed_rad * delta)

# ─── Frame-Post-Draw Asynchronous Baker ──────────────────────────────────────

static func bake_static_thumbnail_async(caller: Node, asset_id: String, asset_entry: Dictionary = {}, resolution: int = 128) -> Texture2D:
	var cache_key := get_cache_key(asset_id, resolution)
	if has_cached_texture(cache_key):
		return get_cached_texture(cache_key)

	var tree := caller.get_tree() if caller != null else null
	if tree == null or tree.root == null:
		return get_procedural_placeholder(asset_id, resolution)

	var vp := SubViewport.new()
	vp.size = Vector2i(resolution, resolution)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	setup_preview_rig(vp, asset_id, asset_entry)
	tree.root.add_child(vp)

	await tree.process_frame
	await RenderingServer.frame_post_draw

	var img: Image = vp.get_texture().get_image()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.queue_free()

	if img != null and not img.is_empty():
		var tex := ImageTexture.create_from_image(img)
		store_cached_texture(cache_key, tex)
		return tex

	return get_procedural_placeholder(asset_id, resolution)
