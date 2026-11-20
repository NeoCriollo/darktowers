class_name PlayerCharacter
extends CharacterBody3D

const TerrainCollision = preload("res://terrain_collision.gd")
const PlayerAnimationControllerScript = preload("res://player/player_animation_controller.gd")

## Tactical Third-Person Character Controller (Godot 4 3D)
## Weighty locomotion, third-person camera rig, firearm handling, and stamina.

signal stamina_changed(current: float, max_value: float)
signal state_changed(old_state: int, new_state: int)
signal aim_state_changed(is_aiming: bool, spread_factor: float)
signal shoulder_changed(is_right_shoulder: bool)
signal health_changed(current: float, max_value: float)
signal damaged(amount: float, attacker_position: Vector3, direction_key: String)
signal low_health_entered(current: float, max_value: float)
signal player_died(death_position: Vector3, respawn_region_name: String, respawn_delay_seconds: float)
signal player_respawned(respawn_position: Vector3, region_name: String)

enum MovementState { IDLE, WALKING, SPRINTING, CROUCHING, AIRBORNE, EXHAUSTED }
enum Shoulder { SHOULDER_LEFT, SHOULDER_RIGHT }

const SHOULDER_RIGHT: int = Shoulder.SHOULDER_RIGHT
const SHOULDER_LEFT: int = Shoulder.SHOULDER_LEFT
const RIGHT_OFFSET: Vector3 = Vector3(0.75, 0.0, 0.0)
const LEFT_OFFSET: Vector3 = Vector3(-0.75, 0.0, 0.0)
const RIGHT_WEAPON_OFFSET_X: float = 0.32
const LEFT_WEAPON_OFFSET_X: float = -0.32

@export_group("Locomotion Speeds")
@export var walk_speed: float = 4.0; @export var sprint_speed: float = 7.5; @export var crouch_speed: float = 2.2
@export var exhausted_speed: float = 2.5; @export var aim_walk_speed: float = 2.6; @export var acceleration: float = 12.0
@export var friction: float = 14.0; @export var jump_velocity: float = 4.5
@export var ground_offset: float = 0.0; @export var max_slope_angle: float = 0.75

@export_group("Survival Vitals")
@export var max_stamina: float = 100.0; @export var stamina_drain_rate: float = 25.0
@export var stamina_recovery_rate: float = 20.0; @export var exhaustion_recovery_threshold: float = 25.0

@export_group("Camera & Aiming Controls")
@export var mouse_sensitivity: float = 0.003; @export var aim_mouse_sensitivity_scale: float = 0.58
@export var min_pitch_deg: float = -70.0; @export var max_pitch_deg: float = 60.0
@export var hip_fov: float = 75.0; @export var aim_fov: float = 48.0
@export var hip_spring_length: float = 3.0; @export var aim_spring_length: float = 1.85; @export var shoulder_swap_duration: float = 0.22

@export_group("Subsystem References")
@export var weapon_system: WeaponSystem; @export var gunslinger_progression: GunslingerProgression

@export_group("Health & Survivability")
@export var max_health: float = 100.0; @export var current_health: float = 100.0
@export_range(0.05, 0.9, 0.01) var low_health_threshold: float = 0.30
@export var damage_stamina_ratio: float = 0.45; @export var damage_grit_exposure: float = 0.18; @export var invulnerability_window: float = 0.25
@export var health_regen_delay: float = 9.0; @export_range(0.0, 1.0, 0.01) var health_regen_cap: float = 0.60; @export var health_regen_rate: float = 1.5

@export_group("Death & Respawn")
@export var death_fade_duration: float = 3.2; @export var respawn_delay: float = 6.0; @export_range(0.1, 1.0, 0.01) var respawn_health_ratio: float = 1.0

@export_group("Camera Trauma")
@export var trauma_decay: float = 1.6; @export var max_shake_offset: float = 0.12; @export var max_shake_roll_deg: float = 2.4

var stamina: float = 100.0; var current_state: MovementState = MovementState.IDLE
var is_aiming: bool = false; var is_right_shoulder: bool = true; var current_shoulder: int = SHOULDER_RIGHT
var shoulder_changed_callback: Callable = Callable()
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var is_dead: bool = false; var is_frozen: bool = false; var respawn_point_provider: Callable = Callable()
var _is_exhausted_locked: bool = false; var _invuln_timer: float = 0.0; var _time_since_damage: float = 999.0
var _was_low_health: bool = false; var _last_emitted_health_int: int = -1
var _pending_respawn_target: Dictionary = {}; var _respawn_generation: int = 0
var _visual_rest_position: Vector3 = Vector3.ZERO; var _visual_rest_rotation: Vector3 = Vector3.ZERO

var _camera_rig: PlayerCameraRig = null
var _hazard_effects: PlayerHazardEffects = null
var _anim_controller: RefCounted = null

@onready var visual_model: Node3D = get_node_or_null("Visuals")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var ground_raycast: RayCast3D = get_node_or_null("RayCast3D")
@onready var spring_arm: SpringArm3D = get_node_or_null("SpringArm3D")
@onready var offset_node: Node3D = get_node_or_null("SpringArm3D/OffsetNode")
@onready var camera: Camera3D = get_node_or_null("SpringArm3D/OffsetNode/Camera3D")

func _init() -> void:
	_camera_rig = PlayerCameraRig.new()
	_hazard_effects = PlayerHazardEffects.new()
	_anim_controller = PlayerAnimationControllerScript.new()

# Biome Hazard Forwarding API
func apply_anomaly_sway(v: float) -> void: _hazard_effects.apply_anomaly_sway(v)
func apply_thinny_distortion(v: float) -> void: _hazard_effects.apply_thinny_distortion(v)
func get_thinny_distortion() -> float: return _hazard_effects.get_thinny_distortion()
func apply_glare_penalty(v: float) -> void: _hazard_effects.apply_glare_penalty(v)
func apply_ka_resonance(v: float) -> void: _hazard_effects.apply_ka_resonance(v)
func get_ka_resonance() -> float: return _hazard_effects.get_ka_resonance()
func apply_stamina_drain_multiplier(v: float) -> void: _hazard_effects.apply_stamina_drain_multiplier(v)
func get_stamina_drain_multiplier() -> float: return _hazard_effects.get_stamina_drain_multiplier()
func apply_tower_nexus_strain(v: float) -> void: _hazard_effects.apply_tower_nexus_strain(v)
func get_tower_nexus_strain() -> float: return _hazard_effects.get_tower_nexus_strain()

func _ready() -> void:
	_camera_rig.ensure_input_actions(); _camera_rig.resolve_camera_rig(self)
	_sync_camera_rig_references(); _resolve_weapon_system()
	floor_snap_length = 0.6; floor_max_angle = max_slope_angle; floor_constant_speed = true
	floor_block_on_wall = true; safe_margin = 0.15; collision_layer = collision_layer | 2
	if not has_node("RayCast3D"):
		var rc := RayCast3D.new(); rc.name = "RayCast3D"; rc.position = Vector3(0.0, 1.8, 0.0); rc.target_position = Vector3(0.0, -4.0, 0.0); add_child(rc)
	$RayCast3D.position = Vector3(0.0, 1.8, 0.0); $RayCast3D.hit_from_inside = true; $RayCast3D.hit_back_faces = true; $RayCast3D.add_exception(self)
	if _anim_controller != null: _anim_controller.setup(self)
	if not WorldSaveData.is_editor_active(): _camera_rig.capture_mouse(); call_deferred("_capture_mouse")
	if spring_arm: spring_arm.add_excluded_object(get_rid())
	if gunslinger_progression == null: gunslinger_progression = GunslingerProgression.new()
	current_shoulder = SHOULDER_RIGHT; is_right_shoulder = true
	if camera != null: camera.position = RIGHT_OFFSET
	if weapon_system != null: weapon_system.position.x = RIGHT_WEAPON_OFFSET_X
	shoulder_changed.connect(func(active: bool) -> void: _camera_rig.on_shoulder_changed_hud_feedback(self, active))
	shoulder_changed.emit(is_right_shoulder); _update_weapon_aim_alignment()
	stamina = max_stamina; stamina_changed.emit(stamina, max_stamina)
	current_health = clampf(current_health, 0.0, maxf(1.0, max_health)); if current_health <= 0.0: current_health = max_health
	if visual_model != null: _visual_rest_position = visual_model.position; _visual_rest_rotation = visual_model.rotation

	if not _hazard_effects.has_checkpoint:
		var init_cp := _hazard_effects.resolve_initial_checkpoint(global_position if is_inside_tree() else position)
		_hazard_effects.register_checkpoint(init_cp.position, init_cp.name)
	add_to_group("player"); _hazard_effects.setup_pain_audio(self); health_changed.emit(current_health, max_health)
	if WorldSaveData != null and not WorldSaveData.editor_mode_toggled.is_connected(_on_editor_mode_toggled): WorldSaveData.editor_mode_toggled.connect(_on_editor_mode_toggled)
	_on_editor_mode_toggled(WorldSaveData.is_editor_active())

func _exit_tree() -> void:
	if WorldSaveData != null and WorldSaveData.editor_mode_toggled.is_connected(_on_editor_mode_toggled): WorldSaveData.editor_mode_toggled.disconnect(_on_editor_mode_toggled)

func _on_editor_mode_toggled(active: bool) -> void:
	if collision_shape == null: collision_shape = (get_node_or_null("CollisionShape3D") if get_node_or_null("CollisionShape3D") != null else find_child("CollisionShape3D", true, false)) as CollisionShape3D
	if ground_raycast == null: ground_raycast = (get_node_or_null("RayCast3D") if get_node_or_null("RayCast3D") != null else find_child("RayCast3D", true, false)) as RayCast3D
	if visual_model == null: visual_model = (get_node_or_null("Visuals") if get_node_or_null("Visuals") != null else find_child("Visuals", true, false)) as Node3D
	if weapon_system == null: weapon_system = find_child("WeaponSystem", true, false) as WeaponSystem
	if spring_arm == null: spring_arm = (get_node_or_null("SpringArm3D") if get_node_or_null("SpringArm3D") != null else find_child("SpringArm3D", true, false)) as SpringArm3D
	if camera == null: camera = get_node_or_null("SpringArm3D/OffsetNode/Camera3D") as Camera3D
	if camera == null and _camera_rig != null: camera = _camera_rig.camera
	if camera == null: camera = find_child("Camera3D", true, false) as Camera3D

	if collision_shape != null: collision_shape.disabled = active
	if ground_raycast != null: ground_raycast.enabled = not active
	if visual_model != null: visual_model.visible = not active
	if weapon_system != null: weapon_system.visible = not active and not weapon_system.is_holstered

	if active:
		is_frozen = true; velocity = Vector3.ZERO; is_aiming = false
		if spring_arm != null: spring_arm.spring_length = 0.0; spring_arm.rotation = Vector3.ZERO
		if camera != null: camera.position = Vector3.ZERO; camera.rotation = Vector3.ZERO
		set_physics_process(false); set_process_input(false); set_process_unhandled_input(false)
	else:
		is_frozen = false; velocity = Vector3.ZERO
		if spring_arm != null: spring_arm.spring_length = hip_spring_length; spring_arm.rotation = Vector3.ZERO
		if camera != null:
			camera.position = RIGHT_OFFSET if is_right_shoulder else LEFT_OFFSET
			camera.rotation = Vector3.ZERO; camera.current = true
		set_physics_process(true); set_process(true); set_process_input(true); set_process_unhandled_input(true)
		call_deferred("_capture_mouse")

func _sync_camera_rig_references() -> void:
	if spring_arm == null: spring_arm = _camera_rig.spring_arm
	if offset_node == null: offset_node = _camera_rig.offset_node
	if camera == null: camera = _camera_rig.camera
	_camera_rig.mouse_sensitivity = mouse_sensitivity; _camera_rig.aim_mouse_sensitivity_scale = aim_mouse_sensitivity_scale; _camera_rig.min_pitch_deg = min_pitch_deg; _camera_rig.max_pitch_deg = max_pitch_deg
	_camera_rig.hip_fov = hip_fov; _camera_rig.aim_fov = aim_fov; _camera_rig.hip_spring_length = hip_spring_length; _camera_rig.aim_spring_length = aim_spring_length
	_camera_rig.shoulder_swap_duration = shoulder_swap_duration; _camera_rig.trauma_decay = trauma_decay; _camera_rig.max_shake_offset = max_shake_offset; _camera_rig.max_shake_roll_deg = max_shake_roll_deg

func _resolve_weapon_system() -> void:
	if weapon_system == null: weapon_system = find_child("WeaponSystem", true, false) as WeaponSystem
	if weapon_system == null:
		weapon_system = WeaponSystem.new(); weapon_system.name = "WeaponSystem"; weapon_system.position = Vector3(0.32, 1.15, -0.38)
		var muzzle := Marker3D.new(); muzzle.name = "MuzzlePoint"; muzzle.position = Vector3(0.0, 0.035, -0.28); weapon_system.add_child(muzzle); weapon_system.muzzle_point = muzzle
		var ray := RayCast3D.new(); ray.name = "AimRayCast"; ray.target_position = Vector3(0.0, 0.0, -85.0); weapon_system.add_child(ray); weapon_system.aim_raycast = ray
		if visual_model != null: visual_model.add_child(weapon_system)
		else: add_child(weapon_system)
	if not weapon_system.weapon_fired.is_connected(_on_weapon_fired_recoil): weapon_system.weapon_fired.connect(_on_weapon_fired_recoil)

func _capture_mouse() -> void: if not WorldSaveData.is_editor_active(): _camera_rig.capture_mouse()

func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN) and not is_dead and not _camera_rig.is_modal_active(self) and not WorldSaveData.is_editor_active(): call_deferred("_capture_mouse")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_editor_mode") or (event is InputEventKey and not event.is_echo() and event.is_pressed() and (event.keycode == KEY_F6 or event.physical_keycode == KEY_F6)):
		WorldSaveData.toggle_editor_mode()
		if get_viewport() != null: get_viewport().set_input_as_handled()
		return
	if is_dead or is_frozen or WorldSaveData.is_editor_active(): return
	if event is InputEventMouseButton and event.is_pressed() and not _camera_rig.is_modal_active(self) and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse()
		if get_viewport() != null: get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and not _camera_rig.is_modal_active(self): _capture_mouse()
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_camera_rig.handle_mouse_look(event.relative, is_aiming)
			if get_viewport() != null: get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or is_frozen or WorldSaveData.is_editor_active(): return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_camera_rig.handle_mouse_look(event.relative, is_aiming); return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var iek := event as InputEventKey
		if iek.keycode == KEY_ESCAPE or iek.physical_keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED); return
		if iek.keycode == KEY_M or iek.physical_keycode == KEY_M or event.is_action_pressed("toggle_recon_map") or event.is_action_pressed("map") or event.is_action_pressed("ui_map") or event.is_action_pressed("toggle_map"):
			_toggle_tactical_chart(); return
	if event is InputEventMouseButton and event.is_pressed() and DisplayServer.get_name() != "headless" and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and not _camera_rig.is_modal_active(self):
		_capture_mouse()
		if get_viewport() != null: get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tactical_shoulder_swap"):
		_update_camera_shoulder(); if get_viewport() != null: get_viewport().set_input_as_handled()
		return
	_handle_firearm_tactile_input(event)

func _toggle_tactical_chart() -> void:
	var hud_node: Node = get_parent().get_node_or_null("HUD") if get_parent() != null else (get_tree().current_scene.find_child("HUD", true, false) if (is_inside_tree() and get_tree().current_scene != null) else null)
	if hud_node != null and hud_node.has_method("toggle_chart"): hud_node.call("toggle_chart")
	elif hud_node != null and hud_node.has_method("toggle_map_modal"): hud_node.call("toggle_map_modal")
	if get_viewport() != null: get_viewport().set_input_as_handled()

func _handle_firearm_tactile_input(event: InputEvent) -> void:
	if weapon_system == null: return
	if event.is_action_pressed("fire") or (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and not _camera_rig.is_modal_active(self)): weapon_system.fire()
	elif event.is_action_pressed("cock_hammer") and weapon_system.cock_hammer(): _camera_rig.recoil_pitch -= 0.012
	elif event.is_action_pressed("reload"): weapon_system.reload_single_round()
	elif event.is_action_pressed("clear_jam"): weapon_system.clear_jam(); _camera_rig.recoil_pitch -= 0.025
	elif event.is_action_pressed("clean_weapon"): weapon_system.field_clean(0.75)
	elif event.is_action_pressed("holster_weapon"): weapon_system.toggle_holster()
	elif event.is_action_pressed("cycle_action"): weapon_system.cycle_action()
	elif event.is_action_pressed("field_gunsmith_inspect") or event.is_action_pressed("inspect_weapon"):
		var hud_node: Node = get_parent().get_node_or_null("HUD") if get_parent() != null else (get_tree().current_scene.find_child("HUD", true, false) if (is_inside_tree() and get_tree().current_scene != null) else null)
		if hud_node != null and hud_node.has_method("toggle_inspection"): hud_node.call("toggle_inspection", weapon_system.call("inspect_weapon") if weapon_system.has_method("inspect_weapon") else {})
	else: return
	get_viewport().set_input_as_handled()

func _update_camera_shoulder() -> void:
	is_right_shoulder = _camera_rig.update_camera_shoulder(self, weapon_system); current_shoulder = _camera_rig.current_shoulder
	if shoulder_changed_callback.is_valid(): shoulder_changed_callback.call(is_right_shoulder)
	shoulder_changed.emit(is_right_shoulder)

func _on_weapon_fired_recoil(data: Dictionary) -> void:
	velocity = _camera_rig.apply_recoil_impulse(float(data.get("recoil_impulse", 0.042)), visual_model, velocity)
	if _anim_controller != null and _anim_controller.has_method("play_action_clip"):
		_anim_controller.call("play_action_clip", "pistol_shoot", 0.35, 1.35)

func _physics_process(delta: float) -> void:
	if is_frozen: velocity = Vector3.ZERO; return
	if WorldSaveData.is_editor_active(): velocity = Vector3.ZERO; return
	_camera_rig.update_camera_trauma(delta, is_dead)
	if is_dead: _process_dead_physics(delta); return
	if _invuln_timer > 0.0: _invuln_timer = maxf(0.0, _invuln_timer - delta)
	_process_health_regen(delta)
	var was_airborne := not is_on_floor()
	if not is_on_floor(): velocity.y -= gravity * delta; _set_movement_state(MovementState.AIRBORNE)
	var want_aim: bool = (Input.is_action_pressed("aim") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and (weapon_system == null or not weapon_system.is_holstered)
	var aim_changed: bool = (want_aim != is_aiming); is_aiming = want_aim
	_update_camera_ads_and_recoil(delta, aim_changed)
	var input_dir := _get_movement_vector()
	var direction := _camera_rig.resolve_movement_direction(input_dir, self)
	var is_jumping := Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SPACE)
	var on_steep_slope := (not is_on_floor() and is_on_wall()) or (is_on_floor() and get_floor_normal().angle_to(Vector3.UP) > floor_max_angle)
	if is_jumping and is_on_floor() and not on_steep_slope and not _is_exhausted_locked and current_state != MovementState.EXHAUSTED:
		velocity.y = jump_velocity; _set_movement_state(MovementState.AIRBORNE)
	if Input.is_action_just_pressed("cycle_action") or Input.is_physical_key_pressed(KEY_E): _hazard_effects.check_crate_interaction(self)
	if is_on_floor() and was_airborne and weapon_system != null and velocity.y < -4.0: weapon_system.foul_from_ground_contact(0.04)
	var is_crouching := Input.is_action_pressed("crouch") or Input.is_action_pressed("crouch_or_center_map") or Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)
	var is_sprinting := (Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)) and not is_crouching and not is_aiming and not _is_exhausted_locked
	var target_speed := _process_stamina_and_state(delta, direction, is_crouching, is_sprinting)
	stamina_changed.emit(stamina, max_stamina)
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta); velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta); velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	_update_body_orientation(delta, direction); _update_weapon_aim_alignment(); _apply_steep_slope_slide(delta, direction); move_and_slide()
	if _anim_controller != null: _anim_controller.update_locomotion(Vector2(velocity.x, velocity.z).length(), is_on_floor(), is_sprinting, input_dir, is_crouching, is_aiming or (weapon_system == null or not weapon_system.is_holstered), is_jumping)

	# Continuous ground snapping & terrain elevation check
	var ground_height: float = TerrainCollision.get_height_at(global_position.x, global_position.z)
	if $RayCast3D.is_colliding() and $RayCast3D.get_collision_normal().angle_to(Vector3.UP) <= floor_max_angle:
		var hit_point: Vector3 = $RayCast3D.get_collision_point()
		if hit_point.y <= global_position.y + 1.75: ground_height = maxf(ground_height, hit_point.y)
	if global_position.y < ground_height + ground_offset:
		global_position.y = ground_height + ground_offset
		if velocity.y < 0.0: velocity.y = 0.0

func _apply_steep_slope_slide(_delta: float, direction: Vector3) -> void:
	if is_on_floor() and get_floor_normal().angle_to(Vector3.UP) <= floor_max_angle: return
	if not is_on_wall() and not is_on_floor(): return
	var slope_norm: Vector3 = get_wall_normal() if is_on_wall() else get_floor_normal()
	if slope_norm.length_squared() < 0.001: return
	slope_norm = slope_norm.normalized()
	var slide_dir: Vector3 = Vector3.DOWN - Vector3.DOWN.project(slope_norm)
	if slope_norm.y < 0.2: slide_dir += Vector3(slope_norm.x, 0.0, slope_norm.z).normalized() * 0.4
	if slide_dir.length_squared() < 0.001: return
	var slide_vel: Vector3 = slide_dir.normalized() * maxf(sprint_speed, 8.5)
	if direction.dot(slope_norm) < 0.1:
		velocity.x = slide_vel.x; velocity.z = slide_vel.z; velocity.y = minf(velocity.y, slide_vel.y)
	else: velocity.y = minf(velocity.y, slide_vel.y)

func _process_stamina_and_state(delta: float, direction: Vector3, is_crouching: bool, is_sprinting: bool) -> float:
	var target_speed := walk_speed
	if _is_exhausted_locked:
		stamina = minf(max_stamina, stamina + _get_effective_stamina_recovery() * 0.75 * delta)
		target_speed = exhausted_speed if direction != Vector3.ZERO else 0.0
		_set_movement_state(MovementState.EXHAUSTED)
		if stamina >= exhaustion_recovery_threshold: _is_exhausted_locked = false
	elif is_on_floor():
		if direction != Vector3.ZERO:
			if is_crouching:
				target_speed = crouch_speed; _set_movement_state(MovementState.CROUCHING)
			elif is_sprinting and stamina > 0.0:
				var metabolics := _hazard_effects.calculate_slope_metabolics(get_floor_normal(), direction)
				target_speed = sprint_speed / float(metabolics.speed_divisor)
				stamina = maxf(0.0, stamina - stamina_drain_rate * float(metabolics.effective_drain_multiplier) * delta)
				_set_movement_state(MovementState.SPRINTING)
				if stamina <= 0.0: _is_exhausted_locked = true; _set_movement_state(MovementState.EXHAUSTED)
			else:
				target_speed = aim_walk_speed if is_aiming else walk_speed; _set_movement_state(MovementState.WALKING)
			if not is_sprinting or stamina <= 0.0: stamina = minf(max_stamina, stamina + _get_effective_stamina_recovery() * delta)
		else:
			_set_movement_state(MovementState.IDLE)
			stamina = minf(max_stamina, stamina + _get_effective_stamina_recovery() * delta)
	return target_speed

func _update_body_orientation(delta: float, direction: Vector3) -> void:
	if visual_model == null: return
	var weapon_drawn: bool = (weapon_system == null or not weapon_system.is_holstered)
	if (is_aiming or weapon_drawn) and spring_arm != null: visual_model.rotation.y = lerp_angle(visual_model.rotation.y, spring_arm.rotation.y, 18.0 * delta)
	elif direction != Vector3.ZERO: visual_model.rotation.y = lerp_angle(visual_model.rotation.y, atan2(-direction.x, -direction.z) + deg_to_rad(6.0), 12.0 * delta)

func get_camera_aim_point() -> Vector3:
	return _camera_rig.get_camera_aim_point(self, weapon_system.effective_range_meters if weapon_system != null else 85.0)

func _update_weapon_aim_alignment() -> void: _camera_rig.update_weapon_aim_alignment(self, weapon_system)

func _update_camera_ads_and_recoil(delta: float, force_emit: bool) -> void:
	var fatigue := clampf(1.0 - (stamina / maxf(1.0, max_stamina)), 0.0, 1.0)
	var prog_sway := gunslinger_progression.aim_sway_multiplier if gunslinger_progression != null else 1.0
	_camera_rig.update_camera_ads_and_recoil(delta, is_aiming, fatigue, current_state == MovementState.CROUCHING, get_injury_ratio(), _hazard_effects.anomaly_sway_intensity, _hazard_effects.glare_visibility_penalty, prog_sway)
	var move_spd := clampf(Vector2(velocity.x, velocity.z).length() / sprint_speed, 0.0, 1.0)
	var spread := (0.25 if is_aiming else 1.0) + move_spd * 0.8 + fatigue * 0.6 + absf(_camera_rig.recoil_pitch) * 6.0
	if force_emit or Engine.get_physics_frames() % 3 == 0: aim_state_changed.emit(is_aiming, spread)

func _set_movement_state(new_state: MovementState) -> void:
	if current_state != new_state: var old := current_state; current_state = new_state; state_changed.emit(old, current_state)

func get_health_ratio() -> float: return clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
func get_injury_ratio() -> float: return 1.0 - get_health_ratio()
func is_low_health() -> bool: return get_health_ratio() <= low_health_threshold and current_health > 0.0
func _get_effective_stamina_recovery() -> float: return stamina_recovery_rate * lerpf(1.0, 0.45, get_injury_ratio())
func add_camera_trauma(amount: float) -> void: _camera_rig.add_camera_trauma(amount)
func get_camera_trauma() -> float: return _camera_rig.get_camera_trauma()

func take_damage(amount: float, attacker_pos: Vector3 = Vector3.ZERO, ignore_invuln: bool = false) -> void:
	if is_dead or amount <= 0.0 or (_invuln_timer > 0.0 and not ignore_invuln): return
	_invuln_timer = invulnerability_window; _time_since_damage = 0.0
	current_health = maxf(0.0, current_health - amount); var severity: float = clampf(amount / maxf(1.0, max_health), 0.0, 1.0)
	add_camera_trauma(clampf(0.28 + severity * 1.8, 0.0, 1.0)); _camera_rig.recoil_pitch += 0.015 + severity * 0.05
	stamina = maxf(0.0, stamina - amount * damage_stamina_ratio)
	if stamina <= 0.0: _is_exhausted_locked = true
	stamina_changed.emit(stamina, max_stamina)
	if weapon_system != null and damage_grit_exposure > 0.0: weapon_system.expose_to_ambient_grit(amount * damage_grit_exposure, 60.0)
	var dir_key: String = _hazard_effects.resolve_hit_direction_key(attacker_pos, global_position, spring_arm if spring_arm != null else self)
	if attacker_pos != Vector3.ZERO:
		var push := Vector3(global_position.x - attacker_pos.x, 0.0, global_position.z - attacker_pos.z)
		if push.length_squared() > 0.0001: velocity += push.normalized() * (1.6 + severity * 4.0)
	_hazard_effects.play_pain_cue(false, severity, get_injury_ratio())
	damaged.emit(amount, attacker_pos, dir_key)
	_emit_health_changed(true)
	if current_health <= 0.0: _die(); return
	if _anim_controller != null and _anim_controller.has_method("play_action_clip"):
		var hit_anim: String = "hit_reaction" if (weapon_system != null and not weapon_system.is_holstered) else "hit_reaction_idle"
		_anim_controller.call("play_action_clip", hit_anim, 0.45, 1.2)
	if get_health_ratio() <= low_health_threshold and not _was_low_health:
		_was_low_health = true; low_health_entered.emit(current_health, max_health)

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0: return
	current_health = minf(max_health, current_health + amount)
	if get_health_ratio() > low_health_threshold + 0.05: _was_low_health = false
	_emit_health_changed(true)

func register_checkpoint(world_position: Vector3, region_name: String = "") -> void: _hazard_effects.register_checkpoint(world_position, region_name)
func get_last_checkpoint() -> Dictionary: return _hazard_effects.get_last_checkpoint()

func _emit_health_changed(force: bool) -> void:
	var as_int: int = int(round(current_health))
	if force or as_int != _last_emitted_health_int:
		_last_emitted_health_int = as_int; health_changed.emit(current_health, max_health)

func _process_health_regen(delta: float) -> void:
	_time_since_damage += delta
	var prev_hp := current_health
	current_health = _hazard_effects.process_health_regen(delta, current_health, max_health, _time_since_damage, health_regen_delay, health_regen_rate, health_regen_cap)
	if current_health != prev_hp:
		if _was_low_health and get_health_ratio() > low_health_threshold + 0.05: _was_low_health = false
		_emit_health_changed(false)

func _process_dead_physics(delta: float) -> void:
	if not is_on_floor(): velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, friction * delta); velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	move_and_slide()
	var ground_height: float = TerrainCollision.get_height_at(global_position.x, global_position.z)
	if $RayCast3D.is_colliding(): ground_height = $RayCast3D.get_collision_point().y
	if global_position.y < ground_height + ground_offset:
		global_position.y = ground_height + ground_offset
		if velocity.y < 0.0: velocity.y = 0.0

func _die() -> void:
	if is_dead: return
	is_dead = true; current_health = 0.0; is_aiming = false; velocity = Vector3.ZERO
	if _anim_controller != null and _anim_controller.has_method("play_action_clip"):
		_anim_controller.call("play_action_clip", "standing_react_death", death_fade_duration, 1.0, true)
	_hazard_effects.play_pain_cue(true, 1.0, 1.0)
	_camera_rig.start_death_camera(self, visual_model, death_fade_duration, _visual_rest_position)
	var death_pos: Vector3 = global_position
	_pending_respawn_target = _hazard_effects.resolve_respawn_target(death_pos, respawn_point_provider)
	_respawn_generation += 1; var gen: int = _respawn_generation
	player_died.emit(death_pos, String(_pending_respawn_target.get("name", _hazard_effects.last_checkpoint_name)), respawn_delay)
	aim_state_changed.emit(false, 1.0)
	if is_inside_tree() and respawn_delay >= 0.0:
		get_tree().create_timer(respawn_delay, false).timeout.connect(func() -> void: if gen == _respawn_generation and is_dead and is_instance_valid(self): respawn())

func respawn() -> void:
	if not is_dead: return
	_respawn_generation += 1; var target: Dictionary = _pending_respawn_target
	if target.is_empty() or not target.has("position"): target = _hazard_effects.resolve_respawn_target(global_position, respawn_point_provider)
	var spawn_pos: Vector3 = target.get("position", _hazard_effects.last_checkpoint_position); var region: String = String(target.get("name", _hazard_effects.last_checkpoint_name))
	_pending_respawn_target = {}; global_position = spawn_pos; velocity = Vector3.ZERO
	current_health = max_health * respawn_health_ratio; stamina = max_stamina
	_is_exhausted_locked = false; _was_low_health = false; _time_since_damage = 999.0; _invuln_timer = 1.5
	_camera_rig.reset_camera_for_respawn(visual_model, _visual_rest_position, _visual_rest_rotation)
	if _anim_controller != null and _anim_controller.has_method("reset_death_state"):
		_anim_controller.call("reset_death_state")
	register_checkpoint(spawn_pos, region); is_dead = false; _set_movement_state(MovementState.IDLE)
	stamina_changed.emit(stamina, max_stamina); _emit_health_changed(true); player_respawned.emit(spawn_pos, region)

func _get_movement_vector() -> Vector2:
	var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if dir == Vector2.ZERO:
		var rx := (1.0 if (Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) else 0.0) - (1.0 if (Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)) else 0.0)
		var ry := (1.0 if (Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0) - (1.0 if (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0)
		if rx != 0.0 or ry != 0.0: dir = Vector2(rx, ry).normalized()
	return dir
