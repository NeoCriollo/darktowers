class_name EditorSelectionManager
extends Node3D

## EditorSelectionManager (Phase 2)
## Performs camera center-screen raycasts into the wasteland to detect,
## hover-highlight, and select props (rocks, ruins, walls, crates).
## Applies diegetic amber unshaded overlay highlights to targeted meshes.

signal hover_changed(target: Node3D, hit_point: Vector3)
signal selection_changed(target: Node3D)
signal focus_requested(target: Node3D)
signal prop_deleted(target: Node3D)
signal modification_state_changed

const MAX_RAY_DISTANCE: float = 350.0
const COLLISION_MASK: int = 1 # World props and terrain colliders

var _hovered_node: Node3D = null
var _selected_node: Node3D = null
var _selected_nodes: Array[Node3D] = []
var _hover_hit_point: Vector3 = Vector3.ZERO
var _modified_ids: Dictionary = {}

# Overlay highlight materials (amber unshaded)
var _hover_material: StandardMaterial3D = null
var _select_material: StandardMaterial3D = null

func _init() -> void:
	_init_materials()

func _init_materials() -> void:
	_hover_material = StandardMaterial3D.new()
	_hover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_material.albedo_color = Color(0.92, 0.68, 0.22, 0.35)
	_hover_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hover_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_select_material = StandardMaterial3D.new()
	_select_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_select_material.albedo_color = Color(1.0, 0.84, 0.32, 0.65)
	_select_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_select_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func get_selected_node() -> Node3D:
	return _selected_node

func get_selected_nodes() -> Array[Node3D]:
	var valid: Array[Node3D] = []
	for n in _selected_nodes:
		if n != null and is_instance_valid(n):
			valid.append(n)
	return valid

func is_node_selected(node: Node3D) -> bool:
	return _selected_nodes.has(node)

func get_hovered_node() -> Node3D:
	return _hovered_node

func get_hover_hit_point() -> Vector3:
	return _hover_hit_point

func process_raycast(camera: Camera3D, space_state: PhysicsDirectSpaceState3D) -> void:
	if camera == null or space_state == null:
		return

	var cam_pos := camera.global_position
	var forward := -camera.global_transform.basis.z
	var ray_end := cam_pos + forward * MAX_RAY_DISTANCE

	var query := PhysicsRayQueryParameters3D.create(cam_pos, ray_end, COLLISION_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# Exclude selected objects from raycast if carrying to prevent self-intersection
	if not _selected_nodes.is_empty():
		var rids: Array[RID] = []
		for n in _selected_nodes:
			if n != null and is_instance_valid(n):
				_gather_collision_rids(n, rids)
		query.exclude = rids

	var result := space_state.intersect_ray(query)
	var new_hovered: Node3D = null
	var hit_pos := Vector3.ZERO

	if not result.is_empty():
		hit_pos = result.position
		var collider: Object = result.collider
		if collider is Node:
			var root_node := find_selectable_root(collider as Node)
			if root_node != null and not _is_terrain_node(root_node):
				new_hovered = root_node

	_hover_hit_point = hit_pos

	if new_hovered != _hovered_node:
		_set_hovered_node(new_hovered)

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.is_pressed():
		var is_shift := Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT)
		# Left-Click: select hovered prop, or clear if clicking empty wasteland
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _hovered_node != null:
				select_node(_hovered_node, is_shift)
				return true
			elif not is_shift and not _selected_nodes.is_empty():
				clear_selection()
				return true
		# Right-Click: deselect all
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not _selected_nodes.is_empty():
				clear_selection()
				return true

	return false

func select_node(node: Node3D, multi: bool = false) -> void:
	if node == null or not is_instance_valid(node):
		return

	if not multi:
		for n in _selected_nodes:
			if n != null and is_instance_valid(n) and n != node:
				_remove_highlight(n)
		_selected_nodes.clear()
		_selected_nodes.append(node)
		_apply_highlight(node, _select_material)
	else:
		if _selected_nodes.has(node):
			_remove_highlight(node)
			_selected_nodes.erase(node)
		else:
			_selected_nodes.append(node)
			_apply_highlight(node, _select_material)

	_selected_node = _selected_nodes[-1] if not _selected_nodes.is_empty() else null
	selection_changed.emit(_selected_node)

func select_prop(node: Node3D, multi: bool = false) -> void:
	select_node(node, multi)

func request_focus(node: Node3D) -> void:
	if node != null and is_instance_valid(node):
		focus_requested.emit(node)

func mark_prop_modified(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var inst_id := _resolve_node_id(node)
	_modified_ids[inst_id] = true
	modification_state_changed.emit()

func is_prop_modified(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var inst_id := _resolve_node_id(node)
	return _modified_ids.get(inst_id, false)

func is_id_modified(inst_id: String) -> bool:
	return _modified_ids.get(inst_id, false)

func clear_modified_flags() -> void:
	_modified_ids.clear()
	modification_state_changed.emit()

func get_modified_count() -> int:
	return _modified_ids.size()

func _resolve_node_id(node: Node3D) -> String:
	if node.has_meta("prop_uuid"):
		return str(node.get_meta("prop_uuid"))
	if node.has_meta("instance_id"):
		return str(node.get_meta("instance_id"))
	return node.name

func clear_selection() -> void:
	for n in _selected_nodes:
		if n != null and is_instance_valid(n):
			_remove_highlight(n)
	_selected_nodes.clear()
	_selected_node = null
	selection_changed.emit(null)

func notify_node_deleted(node: Node3D) -> void:
	if node != null:
		var inst_id := _resolve_node_id(node)
		_modified_ids.erase(inst_id)
		_remove_highlight(node)
		_selected_nodes.erase(node)
		if _selected_node == node:
			_selected_node = _selected_nodes[-1] if not _selected_nodes.is_empty() else null
			selection_changed.emit(_selected_node)
		prop_deleted.emit(node)
	if _hovered_node == node:
		_remove_highlight(_hovered_node)
		_hovered_node = null
		hover_changed.emit(null, Vector3.ZERO)

func _set_hovered_node(node: Node3D) -> void:
	if _hovered_node != null and not _selected_nodes.has(_hovered_node):
		_remove_highlight(_hovered_node)

	_hovered_node = node
	if _hovered_node != null and not _selected_nodes.has(_hovered_node):
		_apply_highlight(_hovered_node, _hover_material)

	hover_changed.emit(_hovered_node, _hover_hit_point)

func find_selectable_root(node: Node) -> Node3D:
	if node == null or _is_terrain_node(node):
		return null

	var cur: Node = node
	var best_candidate: Node3D = null

	while cur != null:
		if is_inside_tree() and cur == get_tree().current_scene:
			break
		if cur.is_in_group("player") or _is_terrain_node(cur):
			break

		if cur is Node3D:
			# Direct editor or custom spawned prop
			if cur.has_meta("catalog_asset_id") or cur.has_meta("asset_path"):
				return cur as Node3D
			if cur.name.begins_with("EditorProp_") or cur.name.begins_with("CustomProp_"):
				return cur as Node3D

			var p: Node = cur.get_parent()
			if p != null:
				var p_name: String = p.name
				if p_name.begins_with("Vignettes_") or p_name == "PropScatter" or (is_inside_tree() and p == get_tree().current_scene):
					return cur as Node3D

			if cur.has_meta("ballistic_material") or cur.has_meta("reactive_target"):
				best_candidate = cur as Node3D

		cur = cur.get_parent()

	return best_candidate

func _gather_collision_rids(root: Node, out_rids: Array[RID]) -> void:
	if root is CollisionObject3D:
		out_rids.append((root as CollisionObject3D).get_rid())
	for child in root.get_children():
		_gather_collision_rids(child, out_rids)

func _is_terrain_node(node: Node) -> bool:
	if node == null:
		return true
	var n: String = node.name.to_lower()
	return n.contains("terrain") or n.contains("ground") or n.contains("collision_generator")

func _apply_highlight(root: Node3D, mat: Material) -> void:
	if root == null:
		return
	_apply_material_overlay(root, mat)
	var is_select := (mat == _select_material)
	_ensure_selection_cage(root, is_select)

func _remove_highlight(root: Node3D) -> void:
	if root == null:
		return
	_remove_material_overlay(root)
	var cage := root.get_node_or_null("_EditorSelectionCage")
	if cage != null:
		cage.queue_free()

func _apply_material_overlay(root: Node3D, mat: Material) -> void:
	if root is MeshInstance3D and root.name != "_EditorSelectionCage":
		(root as MeshInstance3D).material_overlay = mat
	for child in root.get_children():
		if child is Node3D:
			_apply_material_overlay(child as Node3D, mat)

func _remove_material_overlay(root: Node3D) -> void:
	if root is MeshInstance3D and root.name != "_EditorSelectionCage":
		(root as MeshInstance3D).material_overlay = null
	for child in root.get_children():
		if child is Node3D:
			_remove_material_overlay(child as Node3D)

func _ensure_selection_cage(root: Node3D, is_select: bool) -> void:
	var cage := root.get_node_or_null("_EditorSelectionCage") as MeshInstance3D
	if cage == null:
		cage = MeshInstance3D.new()
		cage.name = "_EditorSelectionCage"
		root.add_child(cage)

	var aabb := _compute_local_aabb(root)
	var im := ImmediateMesh.new()
	var cage_mat := StandardMaterial3D.new()
	cage_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cage_mat.no_depth_test = true
	cage_mat.render_priority = 120
	cage_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cage_mat.albedo_color = Color(1.0, 0.85, 0.22, 0.98) if is_select else Color(0.35, 0.82, 1.0, 0.70)

	im.surface_begin(Mesh.PRIMITIVE_LINES, cage_mat)
	var p0 := aabb.position
	var p1 := aabb.position + aabb.size
	var edges = [
		Vector3(p0.x, p0.y, p0.z), Vector3(p1.x, p0.y, p0.z),
		Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p0.y, p1.z),
		Vector3(p1.x, p0.y, p1.z), Vector3(p0.x, p0.y, p1.z),
		Vector3(p0.x, p0.y, p1.z), Vector3(p0.x, p0.y, p0.z),
		Vector3(p0.x, p1.y, p0.z), Vector3(p1.x, p1.y, p0.z),
		Vector3(p1.x, p1.y, p0.z), Vector3(p1.x, p1.y, p1.z),
		Vector3(p1.x, p1.y, p1.z), Vector3(p0.x, p1.y, p1.z),
		Vector3(p0.x, p1.y, p1.z), Vector3(p0.x, p1.y, p0.z),
		Vector3(p0.x, p0.y, p0.z), Vector3(p0.x, p1.y, p0.z),
		Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p1.y, p0.z),
		Vector3(p1.x, p0.y, p1.z), Vector3(p1.x, p1.y, p1.z),
		Vector3(p0.x, p0.y, p1.z), Vector3(p0.x, p1.y, p1.z)
	]
	for v in edges:
		im.surface_add_vertex(v)
	im.surface_end()
	cage.mesh = im

func _compute_local_aabb(root: Node3D) -> AABB:
	var total_aabb := AABB()
	var found := false
	var meshes: Array[MeshInstance3D] = []
	_gather_meshes(root, meshes)
	for mi in meshes:
		if mi.mesh != null and mi.name != "_EditorSelectionCage":
			var mi_aabb: AABB = mi.mesh.get_aabb()
			var to_root := root.global_transform.affine_inverse() * mi.global_transform
			var x_aabb := to_root * mi_aabb
			if not found:
				total_aabb = x_aabb
				found = true
			else:
				total_aabb = total_aabb.merge(x_aabb)
	if not found or total_aabb.size.length_squared() < 0.001:
		total_aabb = AABB(Vector3(-0.75, 0.0, -0.75), Vector3(1.5, 1.5, 1.5))
	return total_aabb.grow(maxf(0.08, total_aabb.get_longest_axis_size() * 0.04))

func _gather_meshes(root: Node, out_meshes: Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D and root.name != "_EditorSelectionCage":
		out_meshes.append(root as MeshInstance3D)
	for child in root.get_children():
		_gather_meshes(child, out_meshes)

func get_node_metadata_string(node: Node3D) -> String:
	if node == null:
		return ""
	var p: Vector3 = node.global_position
	var s: Vector3 = node.scale
	var node_id: String = node.name
	var asset_label: String = node_id.replace("EscarpmentCliff_", "Cliff ").replace("RockStaticBody", "Rock")
	return "%s  |  POS: (%.1f, %.1f, %.1f)  |  SCALE: (%.2f, %.2f, %.2f)" % [
		asset_label, p.x, p.y, p.z, s.x, s.y, s.z
	]

