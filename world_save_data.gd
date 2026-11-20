extends Node

## Persistent Regional State & Territorial Unlock Tracker — "Dark Towers: The Path of Ka"
##
## Tracks and persists the player's territorial conquest across the wasteland:
## - Unlocked sectors / regional basins (e.g., "cradle", "north_alkali", "west_gorge")
## - Activated pre-break beacon monoliths / survey nodes
## - Synchronizes with user://path_of_ka_save.cfg using ConfigFile
## - Emits signals when territory is liberated so MapModal and HUD react instantly.

signal sector_unlocked(sector_id: String)
signal beacon_activated(beacon_id: String)
signal progress_reset()
signal data_loaded()
signal data_saved()
signal editor_mode_toggled(active: bool)

const SAVE_FILE_PATH: String = "user://path_of_ka_save.cfg"
const SECTION_TERRITORY: String = "territory"
const KEY_UNLOCKED_SECTORS: String = "unlocked_sectors"
const KEY_ACTIVATED_BEACONS: String = "activated_beacons"

const INITIAL_PLAYER_SPAWN_XZ := Vector2(-1020.0, -820.0)
const BUNKER_SPAWN_OFFSET := Vector2(2.0, 0.0)

const SECTION_CHECKPOINT: String = "checkpoint"
const KEY_CHECKPOINT_POS: String = "checkpoint_position"
const KEY_CHECKPOINT_NAME: String = "checkpoint_name"
const KEY_CHECKPOINT_SECTOR: String = "checkpoint_sector"
const KEY_EXPLICIT_SAVE: String = "has_explicit_save"

const DEFAULT_CHECKPOINT_NAME: String = "The Mohaine Way-Bunker"
const DEFAULT_CHECKPOINT_SECTOR: String = "waystation_sanctuary"

const BUNKER_CENTER_XZ := Vector2(-1015.0, -815.0)
const BUNKER_SAFE_RADIUS: float = 160.0

## Starting region (Waystation Sanctuary Bunker, Southwest Desolation & Caliche Cradle are always available)
const DEFAULT_UNLOCKED_SECTORS: Array[String] = ["waystation_sanctuary", "sw_desolation", "cradle"]

static var instance: WorldSaveData = null

var unlocked_sectors: Array[String] = ["waystation_sanctuary", "sw_desolation", "cradle"]
var activated_beacons: Array[String] = []

var current_checkpoint_position: Vector3 = Vector3.ZERO
var current_checkpoint_name: String = DEFAULT_CHECKPOINT_NAME
var current_checkpoint_sector: String = DEFAULT_CHECKPOINT_SECTOR
var has_explicit_outside_save_flag: bool = false
var _is_editor_mode_active: bool = false

static func set_editor_mode_active(active: bool, auto_save: bool = false) -> void:
	if instance != null:
		var changed: bool = (instance._is_editor_mode_active != active)
		instance._is_editor_mode_active = active
		if changed:
			instance.editor_mode_toggled.emit(active)
			if auto_save:
				instance.save_to_disk()

static func toggle_editor_mode(auto_save: bool = false) -> bool:
	if instance != null:
		set_editor_mode_active(not instance._is_editor_mode_active, auto_save)
		return instance._is_editor_mode_active
	return false

static func is_editor_active() -> bool:
	return instance != null and instance._is_editor_mode_active

static func is_editor_mode_active() -> bool:
	return is_editor_active()

func _init() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	load_from_disk()

# ─── Player Spawn & Checkpoint Management ─────────────────────────────────────

static func get_default_spawn_position() -> Vector3:
	var spawn_xz := INITIAL_PLAYER_SPAWN_XZ + BUNKER_SPAWN_OFFSET
	var gy: float = TerrainCollisionGenerator.sample_height(spawn_xz.x, spawn_xz.y)
	return Vector3(spawn_xz.x, gy + 0.05, spawn_xz.y)

static func is_inside_refuge_area(pos_xz: Vector2) -> bool:
	return pos_xz.distance_to(BUNKER_CENTER_XZ) <= BUNKER_SAFE_RADIUS or pos_xz.distance_to(Vector2(-1000.0, -800.0)) <= 150.0

func has_explicit_outside_save() -> bool:
	return has_explicit_outside_save_flag

func is_new_game() -> bool:
	return not FileAccess.file_exists(SAVE_FILE_PATH) or not has_explicit_outside_save_flag

func get_saved_player_position() -> Vector3:
	if has_explicit_outside_save_flag and current_checkpoint_position != Vector3.ZERO:
		return current_checkpoint_position
	return get_default_spawn_position()

func get_saved_checkpoint() -> Dictionary:
	var pos: Vector3 = current_checkpoint_position if (has_explicit_outside_save_flag and current_checkpoint_position != Vector3.ZERO) else get_default_spawn_position()
	var c_name: String = current_checkpoint_name if has_explicit_outside_save_flag else DEFAULT_CHECKPOINT_NAME
	var c_sector: String = current_checkpoint_sector if has_explicit_outside_save_flag else DEFAULT_CHECKPOINT_SECTOR
	return {
		"position": pos,
		"name": c_name,
		"sector": c_sector
	}

func record_checkpoint(pos: Vector3, region_name: String = "", sector_id: String = "", is_explicit: bool = false, auto_save: bool = true) -> void:
	current_checkpoint_position = pos
	current_checkpoint_name = region_name if not region_name.is_empty() else DEFAULT_CHECKPOINT_NAME
	current_checkpoint_sector = sector_id if not sector_id.is_empty() else DEFAULT_CHECKPOINT_SECTOR

	var pos_xz := Vector2(pos.x, pos.z)
	var in_refuge := is_inside_refuge_area(pos_xz) or current_checkpoint_sector == DEFAULT_CHECKPOINT_SECTOR

	if in_refuge:
		has_explicit_outside_save_flag = false
	else:
		has_explicit_outside_save_flag = is_explicit

	if auto_save:
		save_to_disk()

# ─── Sector & Territory Queries ───────────────────────────────────────────────

func is_sector_cleared(sector_id: String) -> bool:
	var clean_id: String = sector_id.strip_edges().to_lower()
	return unlocked_sectors.has(clean_id)

func mark_sector_cleared(sector_id: String, auto_save: bool = true) -> bool:
	var clean_id: String = sector_id.strip_edges().to_lower()
	if clean_id.is_empty():
		return false
	if not unlocked_sectors.has(clean_id):
		unlocked_sectors.append(clean_id)
		sector_unlocked.emit(clean_id)
		if auto_save:
			save_to_disk()
		return true
	return false

func get_unlocked_sectors() -> Array[String]:
	return unlocked_sectors.duplicate()


# ─── Beacon Queries ───────────────────────────────────────────────────────────

func is_beacon_activated(beacon_id: String) -> bool:
	var clean_id: String = beacon_id.strip_edges().to_lower()
	return activated_beacons.has(clean_id)

func mark_beacon_activated(beacon_id: String, auto_save: bool = true) -> bool:
	var clean_id: String = beacon_id.strip_edges().to_lower()
	if clean_id.is_empty():
		return false
	if not activated_beacons.has(clean_id):
		activated_beacons.append(clean_id)
		beacon_activated.emit(clean_id)
		if auto_save:
			save_to_disk()
		return true
	return false

func get_activated_beacons() -> Array[String]:
	return activated_beacons.duplicate()

# ─── Disk Persistence ─────────────────────────────────────────────────────────

func save_to_disk(save_path: String = SAVE_FILE_PATH) -> Error:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(save_path):
		var load_err: Error = cfg.load(save_path)
		if load_err != OK and load_err != ERR_FILE_NOT_FOUND:
			push_warning("WorldSaveData: existing save file read returned error %d, creating anew" % load_err)

	cfg.set_value(SECTION_TERRITORY, KEY_UNLOCKED_SECTORS, unlocked_sectors)
	cfg.set_value(SECTION_TERRITORY, KEY_ACTIVATED_BEACONS, activated_beacons)

	# Persist checkpoint & spawn state
	cfg.set_value(SECTION_CHECKPOINT, KEY_CHECKPOINT_POS, current_checkpoint_position)
	cfg.set_value(SECTION_CHECKPOINT, KEY_CHECKPOINT_NAME, current_checkpoint_name)
	cfg.set_value(SECTION_CHECKPOINT, KEY_CHECKPOINT_SECTOR, current_checkpoint_sector)
	cfg.set_value(SECTION_CHECKPOINT, KEY_EXPLICIT_SAVE, has_explicit_outside_save_flag)
	# Editor mode is a transient runtime-only state — never persist it so the
	# player always boots into play mode regardless of how they last exited.
	cfg.erase_section_key("game_mode", "is_editor_mode_active")

	var save_err: Error = cfg.save(save_path)
	if save_err == OK:
		data_saved.emit()
	else:
		push_error("WorldSaveData: Failed to save territorial data to %s (Error: %d)" % [save_path, save_err])
	return save_err

func load_from_disk(save_path: String = SAVE_FILE_PATH) -> Error:
	if not FileAccess.file_exists(save_path):
		unlocked_sectors = DEFAULT_UNLOCKED_SECTORS.duplicate()
		activated_beacons = []
		current_checkpoint_position = get_default_spawn_position()
		current_checkpoint_name = DEFAULT_CHECKPOINT_NAME
		current_checkpoint_sector = DEFAULT_CHECKPOINT_SECTOR
		has_explicit_outside_save_flag = false
		_is_editor_mode_active = false
		data_loaded.emit()
		return OK

	var cfg := ConfigFile.new()
	var err: Error = cfg.load(save_path)
	if err != OK:
		push_warning("WorldSaveData: Failed to parse %s, keeping default territory state" % save_path)
		current_checkpoint_position = get_default_spawn_position()
		current_checkpoint_name = DEFAULT_CHECKPOINT_NAME
		current_checkpoint_sector = DEFAULT_CHECKPOINT_SECTOR
		has_explicit_outside_save_flag = false
		return err

	var raw_sectors = cfg.get_value(SECTION_TERRITORY, KEY_UNLOCKED_SECTORS, DEFAULT_UNLOCKED_SECTORS)
	if raw_sectors is Array:
		unlocked_sectors.clear()
		for item in raw_sectors:
			var s_id: String = String(item).strip_edges().to_lower()
			if not s_id.is_empty() and not unlocked_sectors.has(s_id):
				unlocked_sectors.append(s_id)
	else:
		unlocked_sectors = DEFAULT_UNLOCKED_SECTORS.duplicate()

	# Ensure starting sectors are always unlocked
	if not unlocked_sectors.has("waystation_sanctuary"):
		unlocked_sectors.push_front("waystation_sanctuary")
	if not unlocked_sectors.has("sw_desolation"):
		unlocked_sectors.append("sw_desolation")
	if not unlocked_sectors.has("cradle"):
		unlocked_sectors.append("cradle")

	var raw_beacons = cfg.get_value(SECTION_TERRITORY, KEY_ACTIVATED_BEACONS, [])
	if raw_beacons is Array:
		activated_beacons.clear()
		for item in raw_beacons:
			var b_id: String = String(item).strip_edges().to_lower()
			if not b_id.is_empty() and not activated_beacons.has(b_id):
				activated_beacons.append(b_id)
	else:
		activated_beacons = []

	# Load checkpoint telemetry
	var saved_pos = cfg.get_value(SECTION_CHECKPOINT, KEY_CHECKPOINT_POS, null)
	if saved_pos is Vector3:
		current_checkpoint_position = saved_pos
	elif cfg.has_section_key(SECTION_CHECKPOINT, "position_x") and cfg.has_section_key(SECTION_CHECKPOINT, "position_z"):
		var px: float = float(cfg.get_value(SECTION_CHECKPOINT, "position_x", INITIAL_PLAYER_SPAWN_XZ.x))
		var pz: float = float(cfg.get_value(SECTION_CHECKPOINT, "position_z", INITIAL_PLAYER_SPAWN_XZ.y))
		var py: float = float(cfg.get_value(SECTION_CHECKPOINT, "position_y", TerrainCollisionGenerator.sample_height(px, pz) + 0.05))
		current_checkpoint_position = Vector3(px, py, pz)
	else:
		current_checkpoint_position = Vector3.ZERO

	current_checkpoint_name = String(cfg.get_value(SECTION_CHECKPOINT, KEY_CHECKPOINT_NAME, DEFAULT_CHECKPOINT_NAME))
	current_checkpoint_sector = String(cfg.get_value(SECTION_CHECKPOINT, KEY_CHECKPOINT_SECTOR, DEFAULT_CHECKPOINT_SECTOR))

	var is_explicit: bool = bool(cfg.get_value(SECTION_CHECKPOINT, KEY_EXPLICIT_SAVE, false))

	# Validate if the saved position is genuinely outside the refuge
	var pos_xz := Vector2(current_checkpoint_position.x, current_checkpoint_position.z)
	var in_refuge := is_inside_refuge_area(pos_xz) or current_checkpoint_sector == DEFAULT_CHECKPOINT_SECTOR or current_checkpoint_position == Vector3.ZERO

	# Prevent legacy / unverified / default saves from spawning outside the refuge
	if in_refuge or not is_explicit:
		has_explicit_outside_save_flag = false
		current_checkpoint_position = get_default_spawn_position()
		current_checkpoint_name = DEFAULT_CHECKPOINT_NAME
		current_checkpoint_sector = DEFAULT_CHECKPOINT_SECTOR
	else:
		has_explicit_outside_save_flag = true

	# Editor mode is never restored from disk — always boot into play mode.
	_is_editor_mode_active = false
	data_loaded.emit()
	return OK

func reset_sector_progress(auto_save: bool = true) -> void:
	unlocked_sectors = DEFAULT_UNLOCKED_SECTORS.duplicate()
	activated_beacons = []
	current_checkpoint_position = get_default_spawn_position()
	current_checkpoint_name = DEFAULT_CHECKPOINT_NAME
	current_checkpoint_sector = DEFAULT_CHECKPOINT_SECTOR
	has_explicit_outside_save_flag = false
	progress_reset.emit()
	if auto_save:
		save_to_disk()

# ─── Static Convenience Helpers ───────────────────────────────────────────────

static func is_sector_unlocked(sector_id: String) -> bool:
	if instance != null:
		return instance.is_sector_cleared(sector_id)
	var clean: String = sector_id.strip_edges().to_lower()
	return clean == "waystation_sanctuary" or clean == "sw_desolation" or clean == "cradle"

static func unlock_sector(sector_id: String) -> bool:
	if instance != null:
		return instance.mark_sector_cleared(sector_id)
	return false

static func get_initial_spawn_xz() -> Vector2:
	return INITIAL_PLAYER_SPAWN_XZ

static func get_initial_spawn_position() -> Vector3:
	return get_default_spawn_position()
