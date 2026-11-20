class_name PlayerCameraRig
extends RefCounted

## PlayerCameraRig — OTS Third-Person Camera, Aim Interpolation & Weapon Alignment
##
## Decoupled domain helper for PlayerCharacter managing:
## - SpringArm3D and Camera3D boom resolution and initialization
## - Input actions registration and mouse capture mode synchronization
## - Tactical over-the-shoulder (OTS) dual-shoulder transitions with Tween smoothing
## - Mouse-look yaw/pitch clamping and dynamic ADS sensitivity scaling
## - Aim Down Sights (ADS) FOV zoom, camera boom retract, and respiratory aim sway
## - Trauma-squared camera shake and recoil recovery dynamics
## - Central view raycasting and physical weapon barrel focal point alignment
## - Cinematic death camera crane-up and wasteland collapse transitions

enum Shoulder { SHOULDER_LEFT, SHOULDER_RIGHT }
const SHOULDER_RIGHT: int = Shoulder.SHOULDER_RIGHT
const SHOULDER_LEFT: int = Shoulder.SHOULDER_LEFT

const RIGHT_OFFSET: Vector3 = Vector3(0.75, 0.0, 0.0)
const LEFT_OFFSET: Vector3 = Vector3(-0.75, 0.0, 0.0)
const RIGHT_WEAPON_OFFSET_X: float = 0.32
const LEFT_WEAPON_OFFSET_X: float = -0.32

var mouse_sensitivity: float = 0.003
var aim_mouse_sensitivity_scale: float = 0.58
var min_pitch_deg: float = -70.0
var max_pitch_deg: float = 60.0
var hip_fov: float = 75.0
var aim_fov: float = 48.0
var hip_spring_length: float = 3.0
var aim_spring_length: float = 1.85
var shoulder_swap_duration: float = 0.22
var trauma_decay: float = 1.6
var max_shake_offset: float = 0.12
var max_shake_roll_deg: float = 2.4

var spring_arm: SpringArm3D = null
var offset_node: Node3D = null
var camera: Camera3D = null

var is_right_shoulder: bool = true
var current_shoulder: int = SHOULDER_RIGHT
var shoulder_changed_callback: Callable = Callable()

var recoil_pitch: float = 0.0
var recoil_yaw: float = 0.0
var sway_time: float = 0.0
var trauma: float = 0.0
var shake_time: float = 0.0

var shoulder_tween: Tween = null
var death_tween: Tween = null

# =============================================================================
# --- INITIALIZATION & SETUP ---
# =============================================================================

func resolve_camera_rig(host: CharacterBody3D) -> void:
	if host == null: return
	if spring_arm == null:
		spring_arm = host.get_node_or_null("SpringArm3D") as SpringArm3D
		if spring_arm == null: spring_arm = host.get_node_or_null("CameraBoom") as SpringArm3D
	if spring_arm != null:
		if offset_node == null: offset_node = spring_arm.get_node_or_null("OffsetNode") as Node3D
		if offset_node == null:
			offset_node = Node3D.new()
			offset_node.name = "OffsetNode"
			spring_arm.add_child(offset_node)
		if camera == null: camera = offset_node.get_node_or_null("Camera3D") as Camera3D
		if camera == null:
			var legacy_cam := spring_arm.get_node_or_null("Camera3D") as Camera3D
			if legacy_cam != null:
				spring_arm.remove_child(legacy_cam)
				offset_node.add_child(legacy_cam)
				camera = legacy_cam

func capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func is_modal_active(host: Node) -> bool:
	var hud_node: Node = null
	if host.get_parent() != null: hud_node = host.get_parent().get_node_or_null("HUD")
	if hud_node == null and host.is_inside_tree() and host.get_tree() != null and host.get_tree().current_scene != null:
		hud_node = host.get_tree().current_scene.find_child("HUD", true, false)
	if hud_node != null:
		var mm = hud_node.get("map_modal")
		if mm != null and "visible" in mm and mm.visible: return true
		var sm = hud_node.get("settings_modal")
		if sm != null and "visible" in sm and sm.visible: return true
		var im = hud_node.get("inspection_modal")
		if im != null and "visible" in im and im.visible: return true
	if host.is_inside_tree() and host.get_tree() != null and host.get_tree().root != null:
		var gunslinger_tab = host.get_tree().root.find_child("GunslingerTab", true, false)
		if gunslinger_tab != null and gunslinger_tab.visible: return true
	return false

func ensure_input_actions() -> void:
	_ensure_action_keys("move_left", [KEY_A, KEY_LEFT])
	_ensure_action_keys("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action_keys("move_forward", [KEY_W, KEY_UP])
	_ensure_action_keys("move_backward", [KEY_S, KEY_DOWN])
	_ensure_action_keys("jump", [KEY_SPACE])
	_ensure_action_keys("sprint", [KEY_SHIFT])
	_ensure_action_keys("crouch", [KEY_CTRL, KEY_C])
	_ensure_action_keys("crouch_or_center_map", [KEY_C])
	_ensure_action_keys("cock_hammer", [KEY_F])
	_ensure_action_keys("reload", [KEY_R])
	_ensure_action_keys("clear_jam", [KEY_V])
	_set_action_exclusive_keys("tactical_shoulder_swap", [KEY_Q])
	_ensure_action_keys("clean_weapon", [KEY_B])
	_ensure_action_keys("holster_weapon", [KEY_H])
	_ensure_action_keys("cycle_action", [KEY_E])
	_set_action_exclusive_keys("toggle_recon_map", [KEY_M])
	_set_action_exclusive_keys("toggle_map", [KEY_M])
	_set_action_exclusive_keys("map", [KEY_M])
	_set_action_exclusive_keys("ui_map", [KEY_M])
	_set_action_exclusive_keys("toggle_editor_catalog", [KEY_TAB])
	_ensure_action_keys("field_gunsmith_inspect", [KEY_I])
	_ensure_action_keys("inspect_weapon", [KEY_I])
	_ensure_action_mouse("fire", MOUSE_BUTTON_LEFT)
	_ensure_action_mouse("aim", MOUSE_BUTTON_RIGHT)

func _set_action_exclusive_keys(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name): InputMap.add_action(action_name)
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey:
			var code: int = (ev as InputEventKey).physical_keycode if (ev as InputEventKey).physical_keycode != 0 else (ev as InputEventKey).keycode
			if not (code in keycodes):
				InputMap.action_erase_event(action_name, ev)
	_ensure_action_keys(action_name, keycodes)

func _ensure_action_keys(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name): InputMap.add_action(action_name)
	for code in keycodes:
		var has_key := false
		for ev in InputMap.action_get_events(action_name):
			if ev is InputEventKey and ((ev as InputEventKey).physical_keycode == code or (ev as InputEventKey).keycode == code) and (ev as InputEventKey).device == -1:
				has_key = true; break
		if not has_key:
			var new_ev := InputEventKey.new()
			new_ev.physical_keycode = code
			new_ev.device = -1
			InputMap.action_add_event(action_name, new_ev)

func _ensure_action_mouse(action_name: String, button_idx: MouseButton) -> void:
	if not InputMap.has_action(action_name): InputMap.add_action(action_name)
	var has_btn := false
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == button_idx:
			has_btn = true; break
	if not has_btn:
		var mb := InputEventMouseButton.new()
		mb.button_index = button_idx
		mb.device = -1
		InputMap.action_add_event(action_name, mb)

# =============================================================================
# --- MOUSE LOOK & SHOULDER SWAP ---
# =============================================================================

func handle_mouse_look(relative: Vector2, is_aiming: bool) -> void:
	if spring_arm == null: return
	var sens: float = mouse_sensitivity * (aim_mouse_sensitivity_scale if is_aiming else 1.0)
	spring_arm.rotation.y -= relative.x * sens
	spring_arm.rotation.x -= relative.y * sens
	spring_arm.rotation.x = clampf(spring_arm.rotation.x, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))

func update_camera_shoulder(host: CharacterBody3D, weapon_system: Node3D) -> bool:
	is_right_shoulder = not is_right_shoulder
	current_shoulder = SHOULDER_RIGHT if is_right_shoulder else SHOULDER_LEFT
	var target_offset: Vector3 = RIGHT_OFFSET if is_right_shoulder else LEFT_OFFSET
	var target_weapon_x: float = RIGHT_WEAPON_OFFSET_X if is_right_shoulder else LEFT_WEAPON_OFFSET_X

	if shoulder_tween != null and shoulder_tween.is_valid(): shoulder_tween.kill()
	if camera != null:
		if host != null and host.is_inside_tree():
			shoulder_tween = host.create_tween()
			shoulder_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			shoulder_tween.tween_property(camera, "position", target_offset, shoulder_swap_duration)
			if weapon_system != null:
				shoulder_tween.parallel().tween_property(weapon_system, "position:x", target_weapon_x, shoulder_swap_duration)
			shoulder_tween.finished.connect(func() -> void: update_weapon_aim_alignment(host, weapon_system))
		else:
			camera.position = target_offset
			if weapon_system != null: weapon_system.position.x = target_weapon_x
	elif weapon_system != null:
		weapon_system.position.x = target_weapon_x

	update_weapon_aim_alignment(host, weapon_system)
	if shoulder_changed_callback.is_valid(): shoulder_changed_callback.call(is_right_shoulder)
	return is_right_shoulder

func on_shoulder_changed_hud_feedback(host: Node, right_active: bool) -> void:
	var hud_node: Node = null
	var p := host.get_parent() if host != null else null
	if p != null: hud_node = p.get_node_or_null("HUD")
	if hud_node == null and host != null and host.is_inside_tree() and host.get_tree() != null and host.get_tree().current_scene != null:
		hud_node = host.get_tree().current_scene.find_child("HUD", true, false)
	if hud_node != null:
		if hud_node.has_method("set_shoulder_state"): hud_node.call("set_shoulder_state", right_active)
		else:
			var shoulder_lbl := hud_node.get_node_or_null("Root/BottomRight/VBox/ShoulderStatusLabel") as Label
			if shoulder_lbl != null:
				shoulder_lbl.text = "SHOULDER: [◄|►] %s" % ("RIGHT (►)" if right_active else "LEFT (◄)")

func resolve_movement_direction(input_dir: Vector2, host: Node3D) -> Vector3:
	if input_dir == Vector2.ZERO or host == null: return Vector3.ZERO
	if spring_arm != null:
		var yaw: float = spring_arm.global_rotation.y
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		return (right * input_dir.x + forward * (-input_dir.y)).normalized()
	return (host.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

# =============================================================================
# --- RECOIL & CAMERA TRAUMA DYNAMICS ---
# =============================================================================

func apply_recoil_impulse(impulse: float, visual_model: Node3D, current_velocity: Vector3) -> Vector3:
	recoil_pitch += impulse * 1.45
	recoil_yaw += randf_range(-impulse * 0.45, impulse * 0.45)
	if visual_model != null:
		var back_dir: Vector3 = visual_model.global_transform.basis.z.normalized()
		return current_velocity + Vector3(back_dir.x, 0.0, back_dir.z) * (impulse * 8.0)
	return current_velocity

func add_camera_trauma(amount: float) -> void: trauma = clampf(trauma + amount, 0.0, 1.0)
func get_camera_trauma() -> float: return trauma

func update_camera_trauma(delta: float, is_dead: bool) -> void:
	if camera == null: return
	if trauma > 0.0:
		var decay: float = trauma_decay * (0.35 if is_dead else 1.0)
		trauma = maxf(0.0, trauma - decay * delta)
	var shake: float = trauma * trauma
	if shake <= 0.00001:
		if camera.h_offset != 0.0 or camera.v_offset != 0.0 or camera.rotation.z != 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
			camera.rotation.z = 0.0
		return
	shake_time += delta * 26.0
	camera.h_offset = max_shake_offset * shake * (sin(shake_time * 1.7 + 0.3) * 0.7 + sin(shake_time * 3.9) * 0.3)
	camera.v_offset = max_shake_offset * shake * (sin(shake_time * 2.3 + 1.1) * 0.7 + sin(shake_time * 4.7 + 0.5) * 0.3)
	camera.rotation.z = deg_to_rad(max_shake_roll_deg) * shake * sin(shake_time * 1.3 + 2.0)

func update_camera_ads_and_recoil(
	delta: float, is_aiming: bool, fatigue_ratio: float, is_crouching: bool,
	injury_ratio: float, anomaly_sway: float, glare_penalty: float, prog_sway_mult: float
) -> void:
	sway_time += delta
	if spring_arm != null:
		if absf(recoil_pitch) > 0.0001 or absf(recoil_yaw) > 0.0001:
			var step_p := recoil_pitch * minf(1.0, delta * 18.0)
			var step_y := recoil_yaw * minf(1.0, delta * 18.0)
			spring_arm.rotation.x = clampf(spring_arm.rotation.x + step_p, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
			spring_arm.rotation.y += step_y
			recoil_pitch = move_toward(recoil_pitch, 0.0, delta * 0.45)
			recoil_yaw = move_toward(recoil_yaw, 0.0, delta * 0.45)

		if is_aiming:
			var crouch_factor: float = 0.5 if is_crouching else 1.0
			var sway_amp: float = (0.00025 + fatigue_ratio * 0.0018 + injury_ratio * 0.0022 + anomaly_sway * 0.006 + glare_penalty * 0.0035) * crouch_factor * prog_sway_mult
			spring_arm.rotation.x += sin(sway_time * (2.4 + fatigue_ratio * 4.5 + anomaly_sway * 8.0 + glare_penalty * 3.5)) * sway_amp
			spring_arm.rotation.y += cos(sway_time * (1.7 + fatigue_ratio * 3.2 + anomaly_sway * 6.0 + glare_penalty * 2.8)) * sway_amp * 0.7

		var tgt_len: float = aim_spring_length if is_aiming else hip_spring_length
		spring_arm.spring_length = lerpf(spring_arm.spring_length, tgt_len, minf(1.0, delta * 12.0))

	if camera != null:
		var tgt_fov: float = aim_fov if is_aiming else hip_fov
		camera.fov = lerpf(camera.fov, tgt_fov, minf(1.0, delta * 12.0))

# =============================================================================
# --- AIM POINT RESOLUTION & BARREL ALIGNMENT ---
# =============================================================================

func get_camera_aim_point(host: CharacterBody3D, range_m: float) -> Vector3:
	if host == null: return Vector3.FORWARD * range_m
	if camera != null and camera.is_inside_tree():
		var cam_origin: Vector3 = camera.global_position
		var cam_forward: Vector3 = -camera.global_transform.basis.z.normalized()
		var focal_target: Vector3 = cam_origin + cam_forward * range_m
		if host.get_world_3d() != null and host.get_world_3d().direct_space_state != null:
			var query := PhysicsRayQueryParameters3D.create(cam_origin, focal_target)
			query.exclude = [host.get_rid()]
			var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				var hit_pos: Vector3 = hit.get("position", focal_target)
				if hit_pos.distance_to(cam_origin) > 1.2: focal_target = hit_pos
		return focal_target
	elif spring_arm != null and spring_arm.is_inside_tree():
		return spring_arm.global_position + (-spring_arm.global_transform.basis.z.normalized()) * range_m
	return host.global_position + (-host.global_transform.basis.z.normalized()) * range_m

func update_weapon_aim_alignment(host: CharacterBody3D, weapon_system: Node3D) -> void:
	if host == null or weapon_system == null or not weapon_system.is_inside_tree(): return
	if "is_holstered" in weapon_system and weapon_system.get("is_holstered"):
		weapon_system.rotation = Vector3.ZERO; return
	var eff_range: float = float(weapon_system.get("effective_range_meters")) if "effective_range_meters" in weapon_system else 85.0
	var focal_target: Vector3 = get_camera_aim_point(host, eff_range)
	var origin_pos: Vector3 = weapon_system.global_position
	if focal_target.distance_squared_to(origin_pos) > 0.04: weapon_system.look_at(focal_target, Vector3.UP)

# =============================================================================
# --- DEATH & RESPAWN CAMERA SEQUENCES ---
# =============================================================================

func start_death_camera(host: CharacterBody3D, visual_model: Node3D, duration: float, visual_rest_pos: Vector3) -> void:
	if host == null or not host.is_inside_tree(): return
	if death_tween != null and death_tween.is_valid(): death_tween.kill()
	death_tween = host.create_tween()
	death_tween.set_parallel(true)
	death_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var dur: float = maxf(0.5, duration)
	if spring_arm != null:
		death_tween.tween_property(spring_arm, "rotation:x", deg_to_rad(-48.0), dur)
		death_tween.tween_property(spring_arm, "spring_length", hip_spring_length * 1.8, dur)
	if camera != null:
		death_tween.tween_property(camera, "fov", hip_fov * 0.82, dur)
	if visual_model != null:
		death_tween.tween_property(visual_model, "rotation:x", deg_to_rad(-84.0), dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visual_model, "position:y", visual_rest_pos.y + 0.25, dur * 0.35)

func reset_camera_for_respawn(visual_model: Node3D, visual_rest_pos: Vector3, visual_rest_rot: Vector3) -> void:
	if death_tween != null and death_tween.is_valid(): death_tween.kill()
	trauma = 0.0
	recoil_pitch = 0.0
	recoil_yaw = 0.0
	if visual_model != null:
		visual_model.position = visual_rest_pos
		visual_model.rotation = Vector3(visual_rest_rot.x, visual_model.rotation.y, visual_rest_rot.z)
	if spring_arm != null:
		spring_arm.rotation.x = deg_to_rad(-10.0)
		spring_arm.spring_length = hip_spring_length
	if camera != null:
		camera.fov = hip_fov
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.rotation.z = 0.0
