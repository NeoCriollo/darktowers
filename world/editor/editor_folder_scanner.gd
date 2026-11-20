class_name EditorFolderScanner
extends RefCounted

## EditorFolderScanner: Custom .glb Folder Scanner & Dynamic Registry (Phase 5)
## Scans res://assets/custom_props/ and additional asset directories at runtime
## for raw .glb / .gltf 3D assets.
## Formats human-readable display names, generates unique catalog IDs,
## validates file signatures, caches discovered assets, and registers them
## dynamically into the EditorAssetCatalog.

const PRIMARY_CUSTOM_DIR: String = "res://assets/custom_props/"
const SECONDARY_MODELS_DIR: String = "res://assets/models/"
const GRANULAR_ASSET_DIRS: Array[String] = [
	"res://assets/architecture/",
	"res://assets/environment/",
	"res://assets/interactables/",
	"res://assets/weapons/",
	"res://assets/characters/"
]
const VALID_EXTENSIONS: Array[String] = ["glb", "gltf"]
const GLTF_BINARY_MAGIC: int = 0x46546C67 # "glTF" in little-endian ASCII

static var _cached_entries: Array[Dictionary] = []
static var _last_scan_timestamp: float = 0.0
static var _id_lookup: Dictionary = {}

static func get_desktop_glb_dir() -> String:
	var desktop := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	if not desktop.is_empty():
		var candidate := desktop.path_join("glb")
		if DirAccess.dir_exists_absolute(candidate):
			return candidate
	return ""

static func scan_custom_folder(dir_path: String = PRIMARY_CUSTOM_DIR, include_models: bool = false) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_id_lookup.clear()

	_scan_single_directory(dir_path, results)

	if dir_path == PRIMARY_CUSTOM_DIR:
		for g_dir in GRANULAR_ASSET_DIRS:
			_scan_single_directory(g_dir, results)

	var desk_dir := get_desktop_glb_dir()
	if not desk_dir.is_empty() and desk_dir != dir_path:
		_scan_single_directory(desk_dir, results)

	if include_models:
		_scan_single_directory(SECONDARY_MODELS_DIR, results)

	# Deterministic alphabetical sort by display name
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)

	_cached_entries = results
	_last_scan_timestamp = Time.get_ticks_msec() / 1000.0
	return results

static func get_cached_entries() -> Array[Dictionary]:
	if _cached_entries.is_empty():
		return scan_custom_folder()
	return _cached_entries

static func get_entry_by_id(custom_id: String) -> Dictionary:
	if _id_lookup.is_empty() and not _cached_entries.is_empty():
		for item in _cached_entries:
			_id_lookup[item.get("id", "")] = item
	return _id_lookup.get(custom_id, {})

static func _scan_single_directory(dir_path: String, out_results: Array[Dictionary]) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	var subdirs: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if not file_name.begins_with("."):
			if dir.current_is_dir():
				if file_name != "animations":
					subdirs.append(dir_path.path_join(file_name))
			elif is_valid_3d_file(file_name):
				var full_path := dir_path.path_join(file_name)
				if verify_file_readable(full_path):
					var clean_entry := build_prop_entry(dir_path, file_name)
					if not clean_entry.is_empty():
						var cid: String = clean_entry.get("id", "")
						if not _id_lookup.has(cid):
							out_results.append(clean_entry)
							_id_lookup[cid] = clean_entry
		file_name = dir.get_next()
	dir.list_dir_end()

	for subdir in subdirs:
		_scan_single_directory(subdir, out_results)

static func is_valid_3d_file(file_name: String) -> bool:
	var lower := file_name.to_lower()
	if lower.ends_with(".import") or lower.ends_with(".png") or lower.ends_with(".jpg"):
		return false
	for ext in VALID_EXTENSIONS:
		if lower.ends_with("." + ext):
			return true
	return false

static func verify_file_readable(full_path: String) -> bool:
	if full_path.begins_with("res://"):
		if ResourceLoader.exists(full_path):
			return true
	if not FileAccess.file_exists(full_path):
		return false
	var f := FileAccess.open(full_path, FileAccess.READ)
	if f == null:
		return false
	var len_bytes := f.get_length()
	if len_bytes < 12: # Minimum glTF binary header is 12 bytes
		f.close()
		return false

	# If .glb, check for 4-byte magic "glTF"
	if full_path.to_lower().ends_with(".glb"):
		var magic := f.get_32()
		f.close()
		return magic == GLTF_BINARY_MAGIC

	f.close()
	return true

static func build_prop_entry(dir_path: String, file_name: String) -> Dictionary:
	var base_stem := file_name.get_basename()
	var clean_id := "custom_" + base_stem.to_lower().replace(" ", "_").replace("-", "_")
	var display_name := format_display_name(base_stem)
	var full_path := dir_path.path_join(file_name)
	var estimated_mat := infer_material_from_name(base_stem)

	return {
		"id": clean_id,
		"category": "custom",
		"name": display_name,
		"glb_name": file_name,
		"asset_path": full_path,
		"tier_badge": "[CUSTOM GLB]",
		"scale": Vector3(1.0, 1.0, 1.0),
		"sink": 0.1,
		"material": estimated_mat
	}

static func format_display_name(raw_stem: String) -> String:
	# Check for hex hash names (e.g. Sketchfab hashes like 074d356a225ad34654973c865953d42a)
	var stripped := raw_stem.replace("-", "").replace("_", "").strip_edges()
	if stripped.length() >= 24 and stripped.is_valid_hex_number(false):
		return "Model #" + stripped.left(8).to_upper()

	var cleaned := raw_stem.replace("_", " ").replace("-", " ")
	cleaned = cleaned.replace("assets", "").replace("asset", "")
	cleaned = cleaned.replace("free", "")
	var words := cleaned.split(" ", false)
	var capitalized: Array[String] = []
	for word in words:
		if word.length() > 0:
			capitalized.append(word.left(1).to_upper() + word.substr(1))
	var result := " ".join(capitalized).strip_edges()
	return result if not result.is_empty() else raw_stem

static func infer_material_from_name(name_stem: String) -> String:
	var lower := name_stem.to_lower()
	if lower.contains("metal") or lower.contains("iron") or lower.contains("steel") or lower.contains("beam") or lower.contains("bunker"):
		return "STEEL"
	elif lower.contains("wood") or lower.contains("plank") or lower.contains("door") or lower.contains("pole"):
		return "WOOD"
	elif lower.contains("bone") or lower.contains("skull") or lower.contains("rib"):
		return "BONE"
	elif lower.contains("energy") or lower.contains("plasma") or lower.contains("thinny"):
		return "ENERGY"
	return "STONE"

static func refresh_cache() -> Array[Dictionary]:
	return scan_custom_folder(PRIMARY_CUSTOM_DIR, false)

static func is_custom_asset(asset_id: String) -> bool:
	return asset_id.begins_with("custom_") or _id_lookup.has(asset_id)

static func get_custom_asset_path(asset_id: String) -> String:
	var entry := get_entry_by_id(asset_id)
	return str(entry.get("asset_path", ""))

static func filter_entries_by_keyword(query: String) -> Array[Dictionary]:
	var entries := get_cached_entries()
	if query.strip_edges().is_empty():
		return entries
	var q := query.to_lower()
	var matched: Array[Dictionary] = []
	for item in entries:
		var name_str := str(item.get("name", "")).to_lower()
		var id_str := str(item.get("id", "")).to_lower()
		if name_str.contains(q) or id_str.contains(q):
			matched.append(item)
	return matched

