class_name WorldLayoutSerializer
extends RefCounted

## WorldLayoutSerializer: Live Persistence & JSON World Layout Overrides (Phase 4)
## Serializes modifications, deletions, and editor-spawned assets to
## res://world/data/world_layout_overrides.json (with user:// fallback).
## Automatically applies overrides at game boot ([•] INICIAR VIAJE & [o] ARQUITECTO).

const EditorAssetCatalogScript = preload("res://world/editor/editor_asset_catalog.gd")

const OVERRIDE_PATH_RES: String = "res://world/data/world_layout_overrides.json"
const OVERRIDE_PATH_USER: String = "user://world_layout_overrides.json"
const SCHEMA_VERSION: String = "1.0.0"

var _modifications: Dictionary = {}
var _deletions: Array[String] = []
var _spawned: Array[Dictionary] = []
var _last_saved_path: String = ""

func _init() -> void:
	load_from_json()

func get_last_saved_path() -> String:
	return _last_saved_path

func get_summary() -> Dictionary:
	return {
		"modifications_count": _modifications.size(),
		"deletions_count": _deletions.size(),
		"spawned_count": _spawned.size()
	}

func record_modification(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return

	var inst_id: String = _resolve_instance_id(node)
	var pos := node.global_position
	var rot := node.rotation_degrees
	var sc := node.scale

	# If the node was spawned in this editor session or catalog, update its spawn record
	for item in _spawned:
		if item.get("instance_id", "") == inst_id:
			item["position"] = [pos.x, pos.y, pos.z]
			item["rotation"] = [rot.x, rot.y, rot.z]
			item["scale"] = [sc.x, sc.y, sc.z]
			return

	# Otherwise record in modifications map
	_modifications[inst_id] = {
		"position": [pos.x, pos.y, pos.z],
		"rotation": [rot.x, rot.y, rot.z],
		"scale": [sc.x, sc.y, sc.z]
	}

func record_deletion(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return

	var inst_id: String = _resolve_instance_id(node)

	# If it was a spawned node, remove from spawned list
	var found_idx := -1
	for i in range(_spawned.size()):
		if _spawned[i].get("instance_id", "") == inst_id:
			found_idx = i
			break
	if found_idx >= 0:
		_spawned.remove_at(found_idx)
		return

	# Otherwise add to deletions array and remove from modifications
	if not _deletions.has(inst_id):
		_deletions.append(inst_id)
	if _modifications.has(inst_id):
		_modifications.erase(inst_id)

func record_spawn(node: Node3D, asset_id: String) -> void:
	if node == null or not is_instance_valid(node):
		return

	var inst_id: String = _resolve_instance_id(node)
	var pos := node.global_position
	var rot := node.rotation_degrees
	var sc := node.scale

	# Check if already in spawned list
	for item in _spawned:
		if item.get("instance_id", "") == inst_id:
			item["position"] = [pos.x, pos.y, pos.z]
			item["rotation"] = [rot.x, rot.y, rot.z]
			item["scale"] = [sc.x, sc.y, sc.z]
			return

	var spawn_record := {
		"instance_id": inst_id,
		"asset_id": asset_id,
		"position": [pos.x, pos.y, pos.z],
		"rotation": [rot.x, rot.y, rot.z],
		"scale": [sc.x, sc.y, sc.z]
	}

	if node.has_meta("asset_path"):
		spawn_record["asset_path"] = str(node.get_meta("asset_path"))

	_spawned.append(spawn_record)

func save_to_json(custom_path: String = "") -> bool:
	var payload := {
		"version": SCHEMA_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"modifications": _modifications,
		"deletions": _deletions,
		"spawned": _spawned
	}

	var json_str := JSON.stringify(payload, "\t")
	var target_path := custom_path

	if target_path.is_empty():
		# Try writing to res:// first (editor / git tracking)
		target_path = OVERRIDE_PATH_RES
		var test_file := FileAccess.open(target_path, FileAccess.WRITE)
		if test_file == null:
			# Fallback to user:// for exported non-writable builds
			target_path = OVERRIDE_PATH_USER

	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		push_error("WorldLayoutSerializer: Failed to open file for writing: %s" % target_path)
		return false

	file.store_string(json_str)
	file.close()
	_last_saved_path = target_path
	return true

func load_from_json(custom_path: String = "") -> Dictionary:
	var source_path := custom_path
	if source_path.is_empty():
		var has_res := FileAccess.file_exists(OVERRIDE_PATH_RES)
		var has_user := FileAccess.file_exists(OVERRIDE_PATH_USER)
		if has_res and has_user:
			var t_res := FileAccess.get_modified_time(OVERRIDE_PATH_RES)
			var t_user := FileAccess.get_modified_time(OVERRIDE_PATH_USER)
			source_path = OVERRIDE_PATH_USER if t_user > t_res else OVERRIDE_PATH_RES
		elif has_res:
			source_path = OVERRIDE_PATH_RES
		elif has_user:
			source_path = OVERRIDE_PATH_USER

	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		return {}

	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	var dict: Dictionary = parsed
	_modifications = dict.get("modifications", {})
	var raw_del: Array = dict.get("deletions", [])
	_deletions.clear()
	for d in raw_del:
		_deletions.append(str(d))

	var raw_spawned: Array = dict.get("spawned", [])
	_spawned.clear()
	for s in raw_spawned:
		if typeof(s) == TYPE_DICTIONARY:
			_spawned.append(s as Dictionary)

	_last_saved_path = source_path
	print("[WorldLayoutSerializer] Loaded overrides from '%s' (%d mods, %d dels, %d spawned)" % [source_path, _modifications.size(), _deletions.size(), _spawned.size()])
	return dict

func apply_overrides(world_root: Node) -> int:
	if world_root == null or not is_instance_valid(world_root):
		return 0

	var applied_count: int = 0

	# 1. Apply Deletions
	for del_id in _deletions:
		var target := _find_node_by_identifier(world_root, del_id)
		if target != null:
			if target.get_parent() != null:
				target.get_parent().remove_child(target)
			target.queue_free()
			applied_count += 1

	# 2. Apply Modifications
	for mod_id in _modifications:
		var target := _find_node_by_identifier(world_root, mod_id)
		if target != null:
			var data: Dictionary = _modifications[mod_id]
			if data.has("position"):
				var p: Array = data["position"]
				target.global_position = Vector3(p[0], p[1], p[2])
			if data.has("rotation"):
				var r: Array = data["rotation"]
				target.rotation_degrees = Vector3(r[0], r[1], r[2])
			if data.has("scale"):
				var s: Array = data["scale"]
				target.scale = Vector3(s[0], s[1], s[2])
			applied_count += 1

	# 3. Apply Spawned Props
	for item in _spawned:
		var inst_id: String = item.get("instance_id", "")
		var asset_id: String = item.get("asset_id", "")
		if inst_id.is_empty() or asset_id.is_empty():
			continue

		# Prevent duplicate instantiation if node already exists
		var existing := _find_node_by_identifier(world_root, inst_id)
		if existing != null:
			continue

		var p: Array = item.get("position", [0.0, 0.0, 0.0])
		var r: Array = item.get("rotation", [0.0, 0.0, 0.0])
		var s: Array = item.get("scale", [1.0, 1.0, 1.0])

		var spawn_pos := Vector3(p[0], p[1], p[2])
		var asset_path: String = item.get("asset_path", "")
		var spawned_node: Node3D = null

		if not asset_path.is_empty():
			spawned_node = CustomPropPreviewer.instantiate_custom_prop(asset_path, world_root)
			if spawned_node != null:
				spawned_node.global_position = spawn_pos
		else:
			spawned_node = EditorAssetCatalogScript.spawn_asset(asset_id, spawn_pos, world_root)

		if spawned_node != null:
			spawned_node.name = inst_id
			spawned_node.rotation_degrees = Vector3(r[0], r[1], r[2])
			spawned_node.scale = Vector3(s[0], s[1], s[2])
			spawned_node.set_meta("instance_id", inst_id)
			spawned_node.set_meta("catalog_asset_id", asset_id)
			if not asset_path.is_empty():
				spawned_node.set_meta("asset_path", asset_path)
			applied_count += 1

	return applied_count

func _find_node_by_identifier(root_node: Node, target_id: String) -> Node3D:
	if target_id.is_empty() or root_node == null:
		return null
	var direct := root_node.find_child(target_id, true, false) as Node3D
	if direct != null:
		return direct
	return _search_by_identifier_recursive(root_node, target_id)

func _search_by_identifier_recursive(node: Node, target_id: String) -> Node3D:
	if node is Node3D:
		if node.has_meta("prop_uuid") and str(node.get_meta("prop_uuid")) == target_id:
			return node as Node3D
		if node.has_meta("instance_id") and str(node.get_meta("instance_id")) == target_id:
			return node as Node3D
		if node.name == target_id:
			return node as Node3D
		var sanitized_target := target_id.replace(" ", "_").replace("(", "").replace(")", "")
		var n_sanitized := node.name.replace(" ", "_").replace("(", "").replace(")", "")
		if n_sanitized == sanitized_target:
			return node as Node3D
	for child in node.get_children():
		var found := _search_by_identifier_recursive(child, target_id)
		if found != null:
			return found
	return null

func _resolve_instance_id(node: Node3D) -> String:
	if node.has_meta("prop_uuid"):
		return str(node.get_meta("prop_uuid"))
	if node.has_meta("instance_id"):
		return str(node.get_meta("instance_id"))
	var n_name := node.name
	if not n_name.begins_with("@"):
		return n_name
	return _build_invariant_signature(node)

func _build_invariant_signature(node: Node3D) -> String:
	var parent := node.get_parent()
	var parent_prefix := parent.name.replace("@", "_") if parent != null else "Root"
	var idx := node.get_index()
	var pos := node.position
	var sig := "%s_prop_%d_%d_%d" % [parent_prefix, idx, int(round(pos.x)), int(round(pos.z))]
	node.set_meta("prop_uuid", sig)
	node.set_meta("instance_id", sig)
	return sig

