class_name WorldManager
extends Node3D

## World Partitioning & Occlusion Management — "Dark Towers: The Path of Ka"
##
## Treats the wasteland as topological 'bubbles' (basins) linked by narrow
## canyon passes / wind-choked defiles, and keeps the renderer from drawing the
## whole expanse at once:
## 1. Terrain Chunking + 3-ring LOD system with skirted boundaries
## 2. Bubble Graph Culling with hysteresis margins and transition defiles
## 3. Fog-Synced culling scaling dynamically with weather (haboob collapses to ~45m)
## 4. Small-Prop distance ranges for tiny debris/props
## Boundary tables, graph structure, and mesh builders are in WorldCullingAndBounds.

signal bubble_entered(bubble_id: String, bubble_name: String)
signal bubble_exited(bubble_id: String)
signal transit_corridor_unlocked(pass_id: String, from_bubble: String, to_bubble: String)
signal corridor_entered(corridor_id: String, corridor_name: String, hazard_mult: float)
signal corridor_exited(corridor_id: String)
signal choke_point_passed(corridor_id: String, choke_point: Vector2)

@export_group("Scene References")
@export var player_target: Node3D
@export var prop_scatter_node: PropScatter
@export var terrain_source: MeshInstance3D
@export var environment_node: WorldEnvironment

@export_group("Bubble Culling")
@export var update_interval_seconds: float = 0.15
@export var bubble_hysteresis_margin: float = 25.0
@export var min_hide_distance: float = 280.0
@export var max_node_ops_per_frame: int = 48

@export_group("Fog-Synced Culling")
@export var enable_fog_cull_sync: bool = true
@export_range(0.001, 0.1, 0.001) var fog_cutoff_transmittance: float = 0.015
@export var min_fog_cull_distance: float = 60.0
@export var max_terrain_visibility_distance: float = 650.0

@export_group("Terrain Chunking & LOD")
@export var enable_terrain_chunking: bool = true
@export var terrain_world_size: float = 2500.0
@export var chunks_per_side: int = 20
@export var lod0_subdivisions: int = 48
@export var lod1_subdivisions: int = 24
@export var lod2_subdivisions: int = 12
@export var lod0_end_distance: float = 160.0
@export var lod1_end_distance: float = 380.0

@export_group("Small Prop Distance Ranges")
@export var small_prop_max_size: float = 1.0
@export var small_prop_visibility_end: float = 80.0
@export var medium_prop_max_size: float = 2.0
@export var medium_prop_visibility_end: float = 130.0

# Bubble graph & spatial state
var _bubbles: Dictionary = {}
var _canyon_passes: Array[WorldCullingAndBounds.CanyonPass] = []
var _units: Array[WorldCullingAndBounds.CullUnit] = []
var _global_landmarks: Array[Node3D] = []
var _reveal_queue: Array[WorldCullingAndBounds.CullUnit] = []
var _hide_queue: Array[WorldCullingAndBounds.CullUnit] = []

var _current_bubble_id: String = ""
var _current_pass_id: String = ""
var _active_corridor: Dictionary = {}
var _in_choke_point: bool = false
var _visible_bubbles: Dictionary = {}
var _time_since_last_update: float = 0.0
var _is_initialized: bool = false

var _fog_cull_distance: float = INF
var _lod0_chunks: Array[MeshInstance3D] = []
var _lod1_chunks: Array[MeshInstance3D] = []
var _far_lod_chunks: Array[MeshInstance3D] = []
var _applied_far_lod_end: float = -1.0

const BASIN_NODE_INDICES: Dictionary = {
	"waystation_sanctuary": 0, "sw_desolation": 1, "south_salt": 2, "cradle": 3,
	"west_gorge": 4, "north_alkali": 5, "east_dunes": 6, "monolith_pass": 7
}

func _ready() -> void:
	if not is_in_group("world_manager"):
		add_to_group("world_manager")
	WorldCullingAndBounds.build_topological_graph(_bubbles, _canyon_passes)
	_resolve_references()
	_connect_territorial_persistence()
	if prop_scatter_node != null and not prop_scatter_node.is_scatter_complete:
		prop_scatter_node.scatter_complete.connect(_on_scatter_complete, CONNECT_ONE_SHOT)
	else:
		call_deferred("_initialize")

func _on_scatter_complete(_total: int) -> void:
	_initialize()

func _initialize() -> void:
	if _is_initialized: return
	_is_initialized = true
	if enable_terrain_chunking and terrain_source != null:
		WorldCullingAndBounds.build_terrain_chunks(
			self, terrain_source, terrain_world_size, chunks_per_side,
			[lod0_subdivisions, lod1_subdivisions, lod2_subdivisions],
			[lod0_end_distance, lod1_end_distance, max_terrain_visibility_distance],
			_lod0_chunks, _lod1_chunks, _far_lod_chunks
		)
	_register_world_nodes()
	_update_fog_cull_distance()
	_evaluate(true)
	_flush_all_queued()

func _process(delta: float) -> void:
	if not _is_initialized: return
	_time_since_last_update += delta
	if _time_since_last_update >= update_interval_seconds:
		_time_since_last_update = 0.0
		_update_fog_cull_distance()
		_evaluate(false)
	_drain_queues(max_node_ops_per_frame)

func _resolve_references() -> void:
	var parent := get_parent()
	if parent == null: return
	if player_target == null: player_target = parent.get_node_or_null("Player") as Node3D
	if prop_scatter_node == null: prop_scatter_node = parent.get_node_or_null("PropScatter") as PropScatter
	if terrain_source == null: terrain_source = parent.get_node_or_null("DesertTerrain") as MeshInstance3D
	if environment_node == null: environment_node = parent.get_node_or_null("WorldEnvironment") as WorldEnvironment

func _connect_territorial_persistence() -> void:
	if not is_inside_tree(): return
	var save_mgr = get_node_or_null("/root/WorldSaveData")
	if save_mgr != null and save_mgr.has_signal("sector_unlocked"):
		if not save_mgr.sector_unlocked.is_connected(_on_sector_unlocked):
			save_mgr.sector_unlocked.connect(_on_sector_unlocked)

func _on_sector_unlocked(sector_id: String) -> void:
	for pass_obj in _canyon_passes:
		if pass_obj.from_bubble_id == sector_id or pass_obj.to_bubble_id == sector_id:
			transit_corridor_unlocked.emit(pass_obj.id, pass_obj.from_bubble_id, pass_obj.to_bubble_id)

func _register_world_nodes() -> void:
	if prop_scatter_node == null: return
	var cluster_radius := prop_scatter_node.vignette_radius
	for group in prop_scatter_node.get_children():
		if not (group is Node3D): continue
		if group.name == "HorizonLandmark_DarkTower":
			_global_landmarks.append(group as Node3D); continue
		var is_vignette := String(group.name).begins_with("Vignettes_")
		for child in group.get_children():
			if child is Node3D:
				var unit := WorldCullingAndBounds.CullUnit.new()
				unit.node = child as Node3D
				unit.pos = Vector2(unit.node.global_position.x, unit.node.global_position.z)
				unit.radius = cluster_radius if is_vignette else 2.0
				unit.bubble_id = WorldCullingAndBounds.nearest_bubble_id(unit.pos, _bubbles)
				unit.applied_visible = unit.node.visible; unit.target_visible = unit.node.visible
				_units.append(unit)
	WorldCullingAndBounds.apply_small_prop_ranges(prop_scatter_node, small_prop_max_size, small_prop_visibility_end, medium_prop_max_size, medium_prop_visibility_end)

func _update_fog_cull_distance() -> void:
	var new_dist := INF
	if enable_fog_cull_sync and environment_node != null and environment_node.environment != null:
		var env := environment_node.environment
		if env.fog_enabled:
			var fog_mode: Variant = env.get("fog_mode")
			if fog_mode != null and int(fog_mode) == 1:
				new_dist = float(env.get("fog_depth_end"))
			elif env.fog_density > 0.0:
				new_dist = -log(fog_cutoff_transmittance) / env.fog_density
			new_dist = maxf(new_dist, min_fog_cull_distance)
	_fog_cull_distance = new_dist

	var chunk_half_diag := (terrain_world_size / float(chunks_per_side)) * 0.71
	var effective_cull := minf(_fog_cull_distance, max_terrain_visibility_distance)
	var far_end := effective_cull + chunk_half_diag
	if absf(far_end - _applied_far_lod_end) > 5.0 or (_applied_far_lod_end < 0.0):
		_applied_far_lod_end = far_end
		var lod0_end := minf(lod0_end_distance, far_end)
		var lod1_end := minf(lod1_end_distance, far_end)
		for mi in _lod0_chunks: mi.visibility_range_end = lod0_end
		for mi in _lod1_chunks:
			mi.visible = far_end > lod0_end_distance
			if mi.visible:
				mi.visibility_range_begin = lod0_end_distance; mi.visibility_range_end = lod1_end
		for mi in _far_lod_chunks:
			mi.visible = far_end > lod1_end_distance
			if mi.visible:
				mi.visibility_range_begin = lod1_end_distance; mi.visibility_range_end = far_end

func _evaluate(force: bool) -> void:
	if player_target == null: return
	var player_xz := Vector2(player_target.global_position.x, player_target.global_position.z)
	var raw_bubble_id := WorldCullingAndBounds.resolve_active_bubble(player_xz, _bubbles, _current_bubble_id, bubble_hysteresis_margin)
	var pass_id := WorldCullingAndBounds.resolve_active_pass(player_xz, _canyon_passes)
	var current_corridor := WorldNodeGraph.resolve_active_corridor(player_xz)

	var cur_c_id := String(current_corridor.get("id", ""))
	var prev_c_id := String(_active_corridor.get("id", ""))
	if cur_c_id != prev_c_id:
		if not prev_c_id.is_empty(): corridor_exited.emit(prev_c_id)
		_active_corridor = current_corridor
		if not cur_c_id.is_empty():
			corridor_entered.emit(cur_c_id, String(_active_corridor.get("name", cur_c_id)), float(_active_corridor.get("hazard_mult", 1.0)))

	if not _active_corridor.is_empty() and _active_corridor.has("choke"):
		var choke_pt: Vector2 = _active_corridor["choke"]
		var d_choke: float = player_xz.distance_to(choke_pt)
		if d_choke <= 24.0:
			if not _in_choke_point:
				_in_choke_point = true
				choke_point_passed.emit(cur_c_id, choke_pt)
		elif d_choke > 32.0:
			_in_choke_point = false
	else:
		_in_choke_point = false

	var bubble_id := _current_bubble_id
	if raw_bubble_id != _current_bubble_id:
		var can_transition := _current_bubble_id.is_empty() or WorldNodeGraph.can_traverse_directly(_current_bubble_id, raw_bubble_id)
		if not can_transition and not _active_corridor.is_empty():
			var c_from: String = String(_active_corridor.get("from", ""))
			var c_to: String = String(_active_corridor.get("to", ""))
			can_transition = (c_from == _current_bubble_id and c_to == raw_bubble_id) or (c_to == _current_bubble_id and c_from == raw_bubble_id)
		if can_transition:
			bubble_id = raw_bubble_id
		else:
			bubble_id = _current_bubble_id

	var graph_changed := force or bubble_id != _current_bubble_id or pass_id != _current_pass_id or cur_c_id != prev_c_id

	if bubble_id != _current_bubble_id:
		if not _current_bubble_id.is_empty(): bubble_exited.emit(_current_bubble_id)
		_current_bubble_id = bubble_id
		var b_obj: WorldCullingAndBounds.WastelandBubble = _bubbles[bubble_id]
		bubble_entered.emit(bubble_id, b_obj.name)
	_current_pass_id = pass_id

	if graph_changed:
		_visible_bubbles = { bubble_id: true }
		for conn_id in (_bubbles[bubble_id] as WorldCullingAndBounds.WastelandBubble).connected_bubble_ids:
			_visible_bubbles[conn_id] = true
		for p in _canyon_passes:
			if p.id == pass_id:
				_visible_bubbles[p.from_bubble_id] = true; _visible_bubbles[p.to_bubble_id] = true
		if not _active_corridor.is_empty():
			var cf: String = String(_active_corridor.get("from", ""))
			var ct: String = String(_active_corridor.get("to", ""))
			if not cf.is_empty(): _visible_bubbles[cf] = true
			if not ct.is_empty(): _visible_bubbles[ct] = true

	for unit in _units:
		if not is_instance_valid(unit.node): continue
		var edge_dist := maxf(0.0, player_xz.distance_to(unit.pos) - unit.radius)
		var want_visible: bool
		if edge_dist > _fog_cull_distance:
			want_visible = false
		elif _visible_bubbles.has(unit.bubble_id):
			want_visible = true
		else:
			want_visible = edge_dist < min_hide_distance
		_request_state(unit, want_visible)

	for landmark in _global_landmarks:
		if is_instance_valid(landmark) and not landmark.visible: landmark.visible = true

func _request_state(unit: WorldCullingAndBounds.CullUnit, want_visible: bool) -> void:
	unit.target_visible = want_visible
	if unit.target_visible == unit.applied_visible or unit.queued: return
	unit.queued = true
	if want_visible: _reveal_queue.append(unit)
	else: _hide_queue.append(unit)

func _drain_queues(budget: int) -> void:
	while budget > 0 and not _reveal_queue.is_empty():
		WorldCullingAndBounds.apply_unit(_reveal_queue.pop_back())
		budget -= 1
	while budget > 0 and not _hide_queue.is_empty():
		WorldCullingAndBounds.apply_unit(_hide_queue.pop_back())
		budget -= 1

func _flush_all_queued() -> void:
	_drain_queues(_reveal_queue.size() + _hide_queue.size())

# ─── Public API ───────────────────────────────────────────────────────────────

func is_safe_zone(bubble_id: String) -> bool:
	return WorldCullingAndBounds.is_safe_zone(bubble_id, _bubbles)

func is_position_in_safe_zone(pos_2d: Vector2) -> bool:
	return WorldCullingAndBounds.is_position_in_safe_zone(pos_2d, _bubbles)

func is_player_in_safe_zone() -> bool:
	if player_target == null: return false
	return is_position_in_safe_zone(Vector2(player_target.global_position.x, player_target.global_position.z))

func get_current_basin(pos: Variant = null) -> Dictionary:
	var p2: Vector2; var has_explicit := false
	if pos is Vector3: p2 = Vector2(pos.x, pos.z); has_explicit = true
	elif pos is Vector2: p2 = pos; has_explicit = true
	elif player_target != null: p2 = Vector2(player_target.global_position.x, player_target.global_position.z)
	else:
		var cur_id: String = _current_bubble_id if not _current_bubble_id.is_empty() else "waystation_sanctuary"
		var b_obj: WorldCullingAndBounds.WastelandBubble = _bubbles.get(cur_id, null)
		var c_v2: Vector2 = b_obj.center if b_obj else Vector2(-1000.0, -800.0)
		var c_rad: float = b_obj.radius if b_obj else 150.0
		var c_name: String = b_obj.name if b_obj else "The Mohaine Way-Bunker"
		return {
			"id": cur_id, "name": c_name, "localized_name": Localization.translate_region_name(c_name),
			"node_index": BASIN_NODE_INDICES.get(cur_id, 0), "is_safe_zone": is_safe_zone(cur_id),
			"center": c_v2, "radius": c_rad
		}

	var bubble_id: String = ""
	if not has_explicit and _bubbles.has(_current_bubble_id):
		var cur: WorldCullingAndBounds.WastelandBubble = _bubbles[_current_bubble_id]
		if p2.distance_to(cur.center) <= cur.radius + bubble_hysteresis_margin:
			bubble_id = _current_bubble_id

	if bubble_id.is_empty():
		for b_id in _bubbles:
			var b: WorldCullingAndBounds.WastelandBubble = _bubbles[b_id]
			if p2.distance_to(b.center) <= b.radius:
				bubble_id = b_id; break

	if bubble_id.is_empty():
		bubble_id = WorldCullingAndBounds.nearest_bubble_id(p2, _bubbles)
	if bubble_id.is_empty():
		bubble_id = "waystation_sanctuary"

	var b_name := "Uncharted Wasteland"; var safe := false
	var b_center := Vector2.ZERO; var b_radius := 250.0
	if _bubbles.has(bubble_id):
		var b: WorldCullingAndBounds.WastelandBubble = _bubbles[bubble_id]
		b_name = b.name; safe = b.is_safe_zone; b_center = b.center; b_radius = b.radius

	return {
		"id": bubble_id, "name": b_name, "localized_name": Localization.translate_region_name(b_name),
		"node_index": BASIN_NODE_INDICES.get(bubble_id, 0), "is_safe_zone": safe,
		"center": b_center, "radius": b_radius
	}

func get_current_basin_id(pos: Variant = null) -> String:
	return String(get_current_basin(pos).get("id", ""))

func get_current_bubble_id() -> String:
	return _current_bubble_id

func get_current_bubble_name() -> String:
	if _bubbles.has(_current_bubble_id):
		return (_bubbles[_current_bubble_id] as WorldCullingAndBounds.WastelandBubble).name
	return "Uncharted Wasteland"

func get_current_pass_id() -> String:
	return _current_pass_id

func get_fog_cull_distance() -> float:
	return _fog_cull_distance

func is_bubble_visible(bubble_id: String) -> bool:
	return _visible_bubbles.has(bubble_id)

func get_cull_stats() -> Dictionary:
	var vis := 0
	for u in _units:
		if u.applied_visible: vis += 1
	return {
		"units": _units.size(), "visible_units": vis,
		"queued": _reveal_queue.size() + _hide_queue.size(),
		"fog_cull_distance": _fog_cull_distance,
	}

func get_active_corridor() -> Dictionary:
	return _active_corridor

func get_active_corridor_id() -> String:
	return String(_active_corridor.get("id", _current_pass_id))

func get_corridor_hazard_multiplier() -> float:
	return float(_active_corridor.get("hazard_mult", 1.0))

func is_in_choke_point() -> bool:
	return _in_choke_point

func get_active_choke_point() -> Vector2:
	if not _active_corridor.is_empty() and _active_corridor.has("choke"):
		return _active_corridor["choke"]
	return Vector2.ZERO

func can_transition_to(target_bubble_id: String) -> bool:
	return WorldNodeGraph.can_traverse_directly(_current_bubble_id, target_bubble_id)
