class_name EditorManipulator
extends Node3D

## EditorManipulator: Halo-Forge Style Grab & Carry Tool (Phase 2 & 5)
## Manipulates selected wasteland props in real-time with surface clamping
## to TerrainCollisionGenerator.sample_height(x, z) - sink_depth.
## Provides yaw snap rotation (Q/E), smooth rotation (R), uniform scaling
## (Shift+Wheel / [ ]), cloning (Ctrl+D), grab carry mode (G), and deletion (Del/X).
## Supports multi-selection manipulation with relative offset preservation.

signal object_transformed(target: Node3D)
signal object_cloned(new_instance: Node3D)
signal object_deleted(deleted_node: Node3D)

const MIN_TETHER_DIST: float = 3.0
const MAX_TETHER_DIST: float = 250.0
const MIN_SCALE: float = 0.1
const MAX_SCALE: float = 30.0
const YAW_SNAP_RAD: float = deg_to_rad(15.0)

var _target_nodes: Array[Node3D] = []
var _grabbed_node: Node3D = null
var _is_grabbing: bool = false
var _tether_distance: float = 25.0
var _sink_depth: float = 0.0
var _height_offset: float = 0.0
var _is_free_rotation: bool = false
var _rotation_sensitivity: float = 0.004
var _relative_offsets: Dictionary = {} # Node3D -> Vector3

func get_grabbed_node() -> Node3D:
	return _grabbed_node

func get_target_nodes() -> Array[Node3D]:
	var valid: Array[Node3D] = []
	for n in _target_nodes:
		if n != null and is_instance_valid(n):
			valid.append(n)
	return valid

func is_grabbing() -> bool:
	return _is_grabbing and _grabbed_node != null and is_instance_valid(_grabbed_node)

func get_tether_distance() -> float:
	return _tether_distance

func has_targets() -> bool:
	return not get_target_nodes().is_empty()

func set_targets(nodes: Array[Node3D]) -> void:
	_target_nodes = nodes
	_grabbed_node = _target_nodes[0] if not _target_nodes.is_empty() else null
	_is_grabbing = false
	_is_free_rotation = false
	_height_offset = 0.0

func start_grab(target: Node3D, camera: Camera3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not _target_nodes.has(target):
		_target_nodes = [target]
	_grabbed_node = target
	_is_grabbing = true
	_is_free_rotation = false
	_height_offset = 0.0

	if camera != null:
		var dist := camera.global_position.distance_to(_grabbed_node.global_position)
		_tether_distance = clampf(dist, MIN_TETHER_DIST, MAX_TETHER_DIST)

	var p := _grabbed_node.global_position
	var ground_y := TerrainCollisionGenerator.sample_height(p.x, p.z)
	_sink_depth = ground_y - p.y

	_relative_offsets.clear()
	for n in _target_nodes:
		if n != null and is_instance_valid(n):
			_relative_offsets[n] = n.global_position - _grabbed_node.global_position

func stop_grab() -> void:
	if _is_grabbing:
		_is_grabbing = false
		for n in get_target_nodes():
			object_transformed.emit(n)
	_is_free_rotation = false

func toggle_grab(camera: Camera3D) -> void:
	if _is_grabbing:
		stop_grab()
	elif has_targets():
		start_grab(_grabbed_node if _grabbed_node != null else _target_nodes[0], camera)

func update_manipulation(camera: Camera3D, _delta: float) -> void:
	if not is_grabbing() or camera == null or _grabbed_node == null:
		return

	var cam_pos := camera.global_position
	var cam_forward := -camera.global_transform.basis.z

	var ray_target := cam_pos + cam_forward * _tether_distance
	var ground_y := TerrainCollisionGenerator.sample_height(ray_target.x, ray_target.z)

	var target_y: float
	if Input.is_key_pressed(KEY_ALT) or Input.is_physical_key_pressed(KEY_ALT):
		target_y = ray_target.y + _height_offset
	else:
		target_y = ground_y - _sink_depth + _height_offset

	var new_anchor_pos := Vector3(ray_target.x, target_y, ray_target.z)
	var move_delta := new_anchor_pos - _grabbed_node.global_position
	_grabbed_node.global_position = new_anchor_pos

	for n in _target_nodes:
		if n != null and is_instance_valid(n) and n != _grabbed_node:
			if _relative_offsets.has(n):
				n.global_position = new_anchor_pos + _relative_offsets[n]
			else:
				n.global_position += move_delta

func handle_input(event: InputEvent, camera: Camera3D) -> bool:
	if not has_targets():
		return false

	# 1. Grab Toggle (G key: classic 3D editor grab mode)
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_G:
		toggle_grab(camera)
		return true

	# When grabbing, Left-Click confirms placement and stops grabbing
	if _is_grabbing and event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			stop_grab()
			return true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			stop_grab()
			return true

	# 2. Free Rotation Mouse Motion (when R mode is active)
	if _is_free_rotation and event is InputEventMouseMotion:
		for n in get_target_nodes():
			n.rotate_y(-event.relative.x * _rotation_sensitivity)
			n.rotate_object_local(Vector3.RIGHT, -event.relative.y * _rotation_sensitivity)
			object_transformed.emit(n)
		return true

	# 3. Mouse Wheel: Distance Tether (if grabbing) or Uniform Scaling (Shift + Wheel)
	if event is InputEventMouseButton and event.is_pressed():
		var is_shift := Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if is_shift:
				scale_targets(1.10)
				return true
			elif _is_grabbing:
				adjust_tether(2.5)
				return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if is_shift:
				scale_targets(1.0 / 1.10)
				return true
			elif _is_grabbing:
				adjust_tether(-2.5)
				return true

	# 4. Arrow Keys: Multi-Axis Elevation (Y), Yaw (Y), and Pitch/Roll
	if event is InputEventKey and event.is_pressed():
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if code == KEY_UP:
			if event.shift_pressed and _is_grabbing:
				adjust_tether(1.5)
			elif event.alt_pressed:
				rotate_pitch_roll(Vector3.RIGHT, -deg_to_rad(15.0))
			else:
				adjust_elevation(0.35)
			return true
		elif code == KEY_DOWN:
			if event.shift_pressed and _is_grabbing:
				adjust_tether(-1.5)
			elif event.alt_pressed:
				rotate_pitch_roll(Vector3.RIGHT, deg_to_rad(15.0))
			else:
				adjust_elevation(-0.35)
			return true
		elif code == KEY_LEFT:
			if event.shift_pressed:
				rotate_pitch_roll(Vector3.FORWARD, deg_to_rad(15.0))
			else:
				rotate_yaw(-YAW_SNAP_RAD)
			return true
		elif code == KEY_RIGHT:
			if event.shift_pressed:
				rotate_pitch_roll(Vector3.FORWARD, -deg_to_rad(15.0))
			else:
				rotate_yaw(YAW_SNAP_RAD)
			return true

	# 5. Keyboard Hotkeys (non-echo)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if code == KEY_Q:
			rotate_yaw(-YAW_SNAP_RAD)
			return true
		elif code == KEY_E:
			rotate_yaw(YAW_SNAP_RAD)
			return true
		elif code == KEY_R:
			_is_free_rotation = not _is_free_rotation
			return true
		elif code == KEY_BRACKETLEFT:
			scale_targets(0.90)
			return true
		elif code == KEY_BRACKETRIGHT:
			scale_targets(1.10)
			return true
		elif code == KEY_D and (event.ctrl_pressed or event.meta_pressed or event.is_command_or_control_pressed() or Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL)):
			duplicate_targets(camera)
			return true
		elif code == KEY_DELETE or code == KEY_X or code == KEY_BACKSPACE:
			delete_targets()
			return true

	return false

func adjust_tether(amount: float) -> void:
	_tether_distance = clampf(_tether_distance + amount, MIN_TETHER_DIST, MAX_TETHER_DIST)

func adjust_elevation(amount: float) -> void:
	_height_offset += amount
	for n in get_target_nodes():
		n.global_position.y += amount
		object_transformed.emit(n)

func rotate_yaw(angle_rad: float) -> void:
	for n in get_target_nodes():
		n.rotate_y(angle_rad)
		object_transformed.emit(n)

func rotate_pitch_roll(axis: Vector3, angle_rad: float) -> void:
	for n in get_target_nodes():
		n.rotate_object_local(axis, angle_rad)
		object_transformed.emit(n)

func scale_targets(factor: float) -> void:
	for n in get_target_nodes():
		var cur_scale := n.scale
		var new_scale := cur_scale * factor
		var max_comp := maxf(new_scale.x, maxf(new_scale.y, new_scale.z))
		var min_comp := minf(new_scale.x, minf(new_scale.y, new_scale.z))
		if max_comp <= MAX_SCALE and min_comp >= MIN_SCALE:
			n.scale = new_scale
			object_transformed.emit(n)

func scale_grabbed(factor: float) -> void:
	scale_targets(factor)

func duplicate_targets(camera: Camera3D) -> Array[Node3D]:
	var current := get_target_nodes()
	if current.is_empty():
		return []

	var new_clones: Array[Node3D] = []
	for source in current:
		var parent: Node = source.get_parent()
		if parent == null:
			continue
		var clone := source.duplicate() as Node3D
		clone.name = "%s_Copy" % source.name
		parent.add_child(clone)
		clone.global_transform = source.global_transform
		new_clones.append(clone)
		object_cloned.emit(clone)

	# Select the new clones
	set_targets(new_clones)
	if new_clones.size() == 1 and camera != null and _is_grabbing:
		start_grab(new_clones[0], camera)

	return new_clones

func duplicate_grabbed(camera: Camera3D) -> Node3D:
	var clones := duplicate_targets(camera)
	return clones[0] if not clones.is_empty() else null

func delete_targets() -> void:
	var to_delete := get_target_nodes()
	_target_nodes.clear()
	_grabbed_node = null
	_is_grabbing = false
	for doomed in to_delete:
		object_deleted.emit(doomed)
		doomed.queue_free()

func delete_grabbed() -> void:
	delete_targets()
