@tool
class_name BakeArchitectEdits
extends EditorScript

## BakeArchitectEdits: EditorScript Developer Tool
## Bakes dynamic Architect Mode JSON layout overrides permanently into res://scenes/world.tscn.
## Eliminates runtime deserialization overhead and stabilizes level design assets.
##
## Usage:
## In Godot Editor -> Script tab -> File -> Run (or Ctrl+Shift+X) while this file is open,
## or right-click res://tools/bake_architect_edits.gd in FileSystem -> Run.

const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const OVERRIDES_PATH := "res://world/data/world_layout_overrides.json"
const OVERRIDES_BACKUP_NAME := "world_layout_overrides.json.baked"
const CONTAINER_NAME := "BakedArchitectEdits"

func _run() -> void:
	print("=================================================================")
	print("[BakeArchitectEdits] Starting Architect Mode Scene Bake Pipeline...")
	print("=================================================================")

	# 1. Load the Target Scene
	var world_scene := load(WORLD_SCENE_PATH) as PackedScene
	if world_scene == null:
		printerr("[BakeArchitectEdits] ERROR: Failed to load target scene: ", WORLD_SCENE_PATH)
		return

	var scene_root := world_scene.instantiate() as Node
	if scene_root == null:
		printerr("[BakeArchitectEdits] ERROR: Failed to instantiate target scene: ", WORLD_SCENE_PATH)
		return

	var container := _ensure_baked_container(scene_root)

	# 2. Parse the JSON overrides
	if not FileAccess.file_exists(OVERRIDES_PATH):
		print("[BakeArchitectEdits] NOTICE: No layout overrides file found at %s. Nothing to bake." % OVERRIDES_PATH)
		scene_root.free()
		return

	var file := FileAccess.open(OVERRIDES_PATH, FileAccess.READ)
	if file == null:
		printerr("[BakeArchitectEdits] ERROR: Failed to open %s for reading." % OVERRIDES_PATH)
		scene_root.free()
		return

	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("[BakeArchitectEdits] ERROR: Overrides file does not contain a valid JSON dictionary.")
		scene_root.free()
		return

	var data: Dictionary = parsed
	var raw_deletions: Array = data.get("deletions", [])
	var modifications: Dictionary = data.get("modifications", {})
	var raw_spawned: Array = data.get("spawned", [])

	print("[BakeArchitectEdits] Input JSON parsed: %d deletions, %d modifications, %d spawned props." % [
		raw_deletions.size(), modifications.size(), raw_spawned.size()
	])

	# 3. Process 'deletions'
	var count_deleted := _process_deletions(scene_root, raw_deletions)

	# 4. Process 'modifications'
	var count_modified := _process_modifications(scene_root, modifications)

	# 5. Process 'spawned'
	var count_spawned := _process_spawned(scene_root, container, raw_spawned)

	# 6. Pack and Save to res://scenes/world.tscn
	var save_success := _pack_and_save_scene(scene_root)
	scene_root.free()

	if not save_success:
		printerr("[BakeArchitectEdits] ERROR: Failed to save updated scene. Overrides file was NOT cleared.")
		return

	# 7. Clean Up overrides JSON to prevent double application at runtime
	_archive_overrides_file()

	# 8. Print Detailed Summary
	print("=================================================================")
	print("[BakeArchitectEdits] Bake Complete: %d spawned, %d modified, %d deleted. %s updated." % [
		count_spawned, count_modified, count_deleted, WORLD_SCENE_PATH
	])
	print("=================================================================")

## Finds or instantiates the container Node3D for baked editor props.
func _ensure_baked_container(scene_root: Node) -> Node3D:
	var container := scene_root.get_node_or_null(CONTAINER_NAME) as Node3D
	if container == null:
		container = Node3D.new()
		container.name = CONTAINER_NAME
		scene_root.add_child(container)
		container.owner = scene_root
		print("[BakeArchitectEdits] Created new '%s' container node." % CONTAINER_NAME)
	return container

## Deletes matching nodes by instance ID.
func _process_deletions(scene_root: Node, deletions: Array) -> int:
	var count := 0
	for del_id_raw in deletions:
		var del_id := str(del_id_raw)
		if del_id.is_empty():
			continue

		var target := _find_node_by_instance_id(scene_root, del_id)
		if target != null:
			var parent := target.get_parent()
			if parent != null:
				parent.remove_child(target)
			target.queue_free()
			count += 1
		else:
			push_warning("[BakeArchitectEdits] Deletion target '%s' not found in scene." % del_id)
	return count

## Modifies transform values on existing nodes.
func _process_modifications(scene_root: Node, modifications: Dictionary) -> int:
	var count := 0
	for mod_id_raw in modifications:
		var mod_id := str(mod_id_raw)
		var target := _find_node_by_instance_id(scene_root, mod_id)
		if target == null:
			push_warning("[BakeArchitectEdits] Modification target '%s' not found in scene." % mod_id)
			continue

		var mod_data: Dictionary = modifications[mod_id_raw]
		_apply_transform_record(target, mod_data)
		count += 1
	return count

## Instantiates new props and nests them under the baked container.
func _process_spawned(scene_root: Node, container: Node3D, spawned_list: Array) -> int:
	var count := 0
	for item_raw in spawned_list:
		if typeof(item_raw) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = item_raw
		var asset_id: String = item.get("asset_id", "")
		var inst_id: String = item.get("instance_id", "")
		var asset_path: String = item.get("asset_path", "")

		var spawned_node: Node3D = null

		# Custom imported GLB prop
		if not asset_path.is_empty():
			spawned_node = CustomPropPreviewer.instantiate_custom_prop(asset_path, container)
		else:
			spawned_node = EditorAssetCatalog.spawn_asset(asset_id)
			if spawned_node == null:
				spawned_node = _resolve_fallback_spawn(asset_id, inst_id)

		if spawned_node == null:
			printerr("[BakeArchitectEdits] Failed to spawn asset '%s' (inst: '%s')" % [asset_id, inst_id])
			continue

		if not inst_id.is_empty():
			spawned_node.name = inst_id
			spawned_node.set_meta("instance_id", inst_id)

		if spawned_node.get_parent() != container:
			if spawned_node.get_parent() != null:
				spawned_node.get_parent().remove_child(spawned_node)
			container.add_child(spawned_node)

		_apply_transform_record(spawned_node, item)
		_set_owner_recursive(spawned_node, scene_root)
		count += 1

	return count

## Applies position, rotation degrees, and scale from a dictionary record.
func _apply_transform_record(target: Node3D, data: Dictionary) -> void:
	if data.has("position"):
		var p: Array = data["position"]
		target.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if data.has("rotation"):
		var r: Array = data["rotation"]
		target.rotation_degrees = Vector3(float(r[0]), float(r[1]), float(r[2]))
	if data.has("scale"):
		var s: Array = data["scale"]
		target.scale = Vector3(float(s[0]), float(s[1]), float(s[2]))

## Searches for a node by name or by "instance_id" metadata.
func _find_node_by_instance_id(root_node: Node, inst_id: String) -> Node3D:
	var direct_match := root_node.find_child(inst_id, true, false) as Node3D
	if direct_match != null:
		return direct_match
	return _search_by_meta_recursive(root_node, inst_id)

func _search_by_meta_recursive(node: Node, inst_id: String) -> Node3D:
	if node is Node3D and node.has_meta("instance_id"):
		if str(node.get_meta("instance_id")) == inst_id:
			return node as Node3D
	for child in node.get_children():
		var found := _search_by_meta_recursive(child, inst_id)
		if found != null:
			return found
	return null

## Recursively assigns the owner of a node and all descendants to the scene root.
func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)

## Fallback resolver for copied props or legacy IDs.
func _resolve_fallback_spawn(asset_id: String, inst_id: String) -> Node3D:
	var lower_id := (asset_id + "_" + inst_id).to_lower()
	for cat_id in EditorAssetCatalog.CATALOG:
		if cat_id in lower_id or cat_id.replace("_", "") in lower_id:
			var candidate := EditorAssetCatalog.spawn_asset(cat_id)
			if candidate != null:
				return candidate
	return null

## Packs the modified node hierarchy into a PackedScene and saves to disk.
func _pack_and_save_scene(scene_root: Node) -> bool:
	var packed_scene := PackedScene.new()
	var pack_err := packed_scene.pack(scene_root)
	if pack_err != OK:
		printerr("[BakeArchitectEdits] ERROR: Failed to pack scene. Code: ", pack_err)
		return false

	var save_err := ResourceSaver.save(packed_scene, WORLD_SCENE_PATH)
	if save_err != OK:
		printerr("[BakeArchitectEdits] ERROR: Failed to save scene file. Code: ", save_err)
		return false

	return true

## Archives or clears the overrides JSON so runtime serializer does not re-apply.
func _archive_overrides_file() -> void:
	var dir := DirAccess.open("res://world/data")
	if dir != null and FileAccess.file_exists(OVERRIDES_PATH):
		if dir.file_exists(OVERRIDES_BACKUP_NAME):
			dir.remove(OVERRIDES_BACKUP_NAME)
		var err := dir.rename("world_layout_overrides.json", OVERRIDES_BACKUP_NAME)
		if err == OK:
			print("[BakeArchitectEdits] Archived %s -> %s" % [OVERRIDES_PATH, OVERRIDES_BACKUP_NAME])
		else:
			# Fallback: empty the file if rename is blocked
			var clear_file := FileAccess.open(OVERRIDES_PATH, FileAccess.WRITE)
			if clear_file != null:
				clear_file.store_string("{\n\t\"version\": \"1.0.0\",\n\t\"deletions\": [],\n\t\"modifications\": {},\n\t\"spawned\": []\n}\n")
				clear_file.close()
			print("[BakeArchitectEdits] Cleared %s." % OVERRIDES_PATH)

