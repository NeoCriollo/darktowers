# ==============================================================================
# Dark Towers - Performance Diagnostic Logger
# File: res://performance_logger.gd
# Description: Global diagnostic monitor designed to capture runtime engine
#              and rendering performance metrics at regular intervals.
#              Serializes diagnostics to 'user://performance_diag_log.json'
#              and mirrors to 'res://performance_diag_log.json' for live inspection.
# ==============================================================================

class_name PerformanceLogger
extends Node

## File path where the performance diagnostic snapshots will be dumped.
const LOG_FILE_PATH: String = "user://performance_diag_log.json"

## Workspace mirror path enabling real-time AI and tool inspection during gameplay.
const WORKSPACE_FILE_PATH: String = "res://performance_diag_log.json"

## Sampling interval in seconds for runtime performance metrics.
const SAMPLE_INTERVAL: float = 1.0

## Periodic interval (seconds) to sync the latest snapshot to the workspace file.
const LIVE_SYNC_INTERVAL: float = 2.0

## FPS threshold below which an emergency diagnostic dump is triggered.
const LOW_FPS_THRESHOLD: float = 15.0

## Minimum interval between successive low-FPS disk writes to avoid IO lag.
const LOW_FPS_SAVE_COOLDOWN: float = 2.0

## Initial delay (seconds) before low-FPS checks activate to ignore load spikes.
const STARTUP_GRACE_PERIOD: float = 3.0

## Maximum number of historical records to keep in memory (avoids unbounded growth).
const MAX_SNAPSHOT_HISTORY: int = 3600

## Whether to print a clean one-line ticker to Godot's Output console every second.
const PRINT_TICKER_TO_CONSOLE: bool = true

# ------------------------------------------------------------------------------
# State Variables
# ------------------------------------------------------------------------------

var _sample_timer: float = 0.0
var _live_sync_timer: float = 0.0
var _elapsed_time: float = 0.0
var _last_low_fps_dump_time: float = -100.0
var _total_dumps_written: int = 0
var _is_saving: bool = false

## Growing collection of captured metric snapshots.
var _snapshots: Array[Dictionary] = []

# ------------------------------------------------------------------------------
# Engine Lifecycle
# ------------------------------------------------------------------------------

func _ready() -> void:
	# Set process mode to always run, even if the scene tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var user_dir: String = OS.get_user_data_dir()
	print("[PerformanceLogger] Initialized. Primary output: %s" % LOG_FILE_PATH)
	print("[PerformanceLogger] Live workspace output: %s" % WORKSPACE_FILE_PATH)
	print("[PerformanceLogger] OS user data directory: %s" % user_dir)
	print("[PerformanceLogger] Sampling every %.1fs (Emergency dump trigger: < %.0f FPS)" % [
		SAMPLE_INTERVAL,
		LOW_FPS_THRESHOLD
	])


func _process(delta: float) -> void:
	_elapsed_time += delta
	_sample_timer += delta
	_live_sync_timer += delta

	# 1. Periodic snapshot capture every 1.0 second
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer -= SAMPLE_INTERVAL
		var snapshot: Dictionary = _capture_snapshot()
		_snapshots.append(snapshot)
		
		# FIFO pruning if history exceeds safety ceiling
		if _snapshots.size() > MAX_SNAPSHOT_HISTORY:
			_snapshots.pop_front()

		# Print live one-line ticker to Godot Output
		if PRINT_TICKER_TO_CONSOLE:
			_print_ticker_line(snapshot)

	# 2. Live sync to workspace file so AI/developer can read live while playing
	if _live_sync_timer >= LIVE_SYNC_INTERVAL:
		_live_sync_timer -= LIVE_SYNC_INTERVAL
		save_log_to_file("live_stream", false)

	# 3. Dynamic low-FPS degradation trigger (< 15 FPS)
	if _elapsed_time >= STARTUP_GRACE_PERIOD:
		var current_fps: float = Performance.get_monitor(Performance.TIME_FPS)
		# Ensure valid non-zero FPS reading before assessing threshold
		if current_fps > 0.0 and current_fps < LOW_FPS_THRESHOLD:
			if (_elapsed_time - _last_low_fps_dump_time) >= LOW_FPS_SAVE_COOLDOWN:
				_last_low_fps_dump_time = _elapsed_time
				push_warning(
					"[PerformanceLogger] Severe performance drop detected: %.1f FPS. Writing emergency dump..." % current_fps
				)
				save_log_to_file("low_fps_drop (%.1f FPS)" % current_fps, true)


func _notification(what: int) -> void:
	# Handle application close requests (Alt+F4, OS window close, kill signals)
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[PerformanceLogger] NOTIFICATION_WM_CLOSE_REQUEST received. Flushing logs...")
		save_log_to_file("wm_close_request", true)


# ------------------------------------------------------------------------------
# Metric Sampling & Display
# ------------------------------------------------------------------------------

## Queries the Godot Performance singleton and builds a structured snapshot.
func _capture_snapshot() -> Dictionary:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var vram_bytes: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var static_mem_bytes: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var active_physics_3d: float = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)

	var snapshot: Dictionary = {
		"timestamp_sec": snappedf(_elapsed_time, 0.01),
		"datetime_iso": Time.get_datetime_string_from_system(false, true),
		"fps": fps,
		"render_total_draw_calls": int(draw_calls),
		"render_total_primitives": int(primitives),
		"render_video_mem_bytes": int(vram_bytes),
		"render_video_mem_mb": snappedf(vram_bytes / (1024.0 * 1024.0), 0.01),
		"memory_static_bytes": int(static_mem_bytes),
		"memory_static_mb": snappedf(static_mem_bytes / (1024.0 * 1024.0), 0.01),
		"physics_3d_active_objects": int(active_physics_3d)
	}

	return snapshot


## Prints a compact, readable diagnostic telemetry ticker to the output panel.
func _print_ticker_line(s: Dictionary) -> void:
	print(
		"[PerfTicker] FPS: %5.1f | DrawCalls: %4d | Prims: %6d | VRAM: %6.1f MB | RAM: %6.1f MB | Phys3D: %3d" % [
			float(s.get("fps", 0.0)),
			int(s.get("render_total_draw_calls", 0)),
			int(s.get("render_total_primitives", 0)),
			float(s.get("render_video_mem_mb", 0.0)),
			float(s.get("memory_static_mb", 0.0)),
			int(s.get("physics_3d_active_objects", 0))
		]
	)


# ------------------------------------------------------------------------------
# File Serialization & Persistence
# ------------------------------------------------------------------------------

## Serializes accumulated snapshots into user:// and res:// log files.
func save_log_to_file(trigger_reason: String = "manual", log_to_console: bool = true) -> bool:
	if _is_saving:
		return false

	_is_saving = true
	var write_start_time: int = Time.get_ticks_msec()

	# If no snapshots have been taken yet, take one immediately
	if _snapshots.is_empty():
		_snapshots.append(_capture_snapshot())

	# Update newest snapshot with the trigger reason
	if not _snapshots.is_empty():
		_snapshots[_snapshots.size() - 1]["dump_trigger_reason"] = trigger_reason

	var json_output: String = JSON.stringify(_snapshots, "\t")
	
	# 1. Primary write to user://
	var file := FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(json_output)
		file.close()
	else:
		var err := FileAccess.get_open_error()
		push_error("[PerformanceLogger] Failed to open %s. Error: %d" % [LOG_FILE_PATH, err])

	# 2. Mirror write to workspace res:// (enables live AI and terminal reading)
	var ws_file := FileAccess.open(WORKSPACE_FILE_PATH, FileAccess.WRITE)
	if ws_file != null:
		ws_file.store_string(json_output)
		ws_file.close()

	_total_dumps_written += 1
	var write_duration: int = Time.get_ticks_msec() - write_start_time
	
	if log_to_console:
		print(
			"[PerformanceLogger] Dumped %d record(s) to %s & %s (Reason: %s, Time: %d ms)" % [
				_snapshots.size(),
				LOG_FILE_PATH,
				WORKSPACE_FILE_PATH,
				trigger_reason,
				write_duration
			]
		)

	_is_saving = false
	return true


# ------------------------------------------------------------------------------
# Public Diagnostic Inspection API
# ------------------------------------------------------------------------------

## Returns the complete list of captured snapshot records.
func get_all_snapshots() -> Array[Dictionary]:
	return _snapshots


## Returns the most recently captured metric snapshot.
func get_latest_snapshot() -> Dictionary:
	if _snapshots.is_empty():
		return {}
	return _snapshots[_snapshots.size() - 1]


## Clears stored historical snapshots in memory.
func clear_snapshots() -> void:
	_snapshots.clear()


## Manually triggers an immediate dump of current records to disk.
func flush_now(reason: String = "manual_flush") -> bool:
	return save_log_to_file(reason, true)


## Returns diagnostic summary information as a formatted string.
func get_summary_string() -> String:
	var latest: Dictionary = get_latest_snapshot()
	if latest.is_empty():
		return "No diagnostic records captured yet."
	
	return (
		"Diagnostic Summary:\n" +
		"- Snapshots Recorded: %d\n" % _snapshots.size() +
		"- Current FPS: %.1f\n" % float(latest.get("fps", 0.0)) +
		"- Draw Calls: %d\n" % int(latest.get("render_total_draw_calls", 0)) +
		"- Primitives: %d\n" % int(latest.get("render_total_primitives", 0)) +
		"- VRAM: %.2f MB\n" % float(latest.get("render_video_mem_mb", 0.0)) +
		"- Static Mem: %.2f MB\n" % float(latest.get("memory_static_mb", 0.0)) +
		"- 3D Physics Objects: %d\n" % int(latest.get("physics_3d_active_objects", 0)) +
		"- Total Dumps Written: %d\n" % _total_dumps_written
	)
