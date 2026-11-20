class_name EnemyBase
extends CharacterBody3D

const EnemySensors = preload("res://enemies/enemy_sensors_and_loot.gd")

## Modular Tactical Enemy System & State Machine Controller (Godot 4.3)
##
## Implements hostile wasteland scavengers and Low-Men raiders:
## - Match-based AI State Machine: IDLE, CHASE, ATTACK, DEAD
## - NavigationAgent3D pathing and obstacle avoidance across terrain
## - Line-of-sight raycasts and proximity tracking (delegated to EnemySensorsAndLoot)
## - Combat damage handling for .45 Long Colt hits and tactical death collapse
## - Economy loot drop rolling and world instantiation (delegated to EnemySensorsAndLoot)

# --- SIGNALS ---
signal state_changed(old_state: int, new_state: int)
signal player_detected(player_node: Node3D)
signal player_lost(player_node: Node3D)
signal attacked_target(target_node: Node3D, damage_amount: float)
signal damaged(amount: float, remaining_health: float, hit_position: Vector3)
signal health_changed(current_health: float, max_health: float)
signal loot_dropped(item_instance: Node3D, loot_data: Dictionary)
signal enemy_defeated(enemy: EnemyBase, defeat_position: Vector3)
signal died(enemy: EnemyBase)

# --- STATE MACHINE ENUM ---
enum State { IDLE, CHASE, ATTACK, DEAD }
const IDLE: int = State.IDLE
const CHASE: int = State.CHASE
const ATTACK: int = State.ATTACK
const DEAD: int = State.DEAD

# --- EXPORTED CONFIGURATION ---
@export_group("Enemy Identity & Vitals")
@export var enemy_title_key: String = "ENEMY_WASTELAND_RAIDER"
@export var max_health: float = 90.0
@export var health: float = 90.0

@export_group("Tactical AI & Locomotion")
@export var chase_speed: float = 3.8
@export var acceleration: float = 11.0
@export var friction: float = 14.0
@export var rotation_speed: float = 10.0
@export var detection_radius: float = 28.0
@export var lose_interest_radius: float = 42.0
@export var require_line_of_sight: bool = true
@export var eye_height_offset: float = 1.45

@export_group("Combat & Attack Parameters")
@export var attack_range: float = 2.6
@export var attack_damage: float = 18.0
@export var attack_cooldown: float = 1.35

@export_group("Loot Drop & Resource Economy")
@export var enable_loot_drop: bool = true
@export var loot_drop_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0
@export var weight_ammo_45lc: float = 60.0
@export var weight_survival_water: float = 30.0
@export var weight_rare_components: float = 10.0
@export var drop_table: Array[Dictionary] = [
	{ "id": "ammo_45lc", "type": "AMMO", "name_key": "LOOT_ITEM_AMMO_45LC", "weight": 60.0, "min_amount": 2, "max_amount": 6 },
	{ "id": "survival_water", "type": "SURVIVAL", "name_key": "LOOT_ITEM_SURVIVAL_WATER", "weight": 30.0, "min_amount": 1, "max_amount": 1 },
	{ "id": "rare_components", "type": "COMPONENT", "name_key": "LOOT_ITEM_RARE_COMPONENT", "weight": 10.0, "min_amount": 1, "max_amount": 1 }
]

@export_group("Component References")
@export var collision_shape: CollisionShape3D
@export var navigation_agent: NavigationAgent3D
@export var detection_area: Area3D
@export var los_raycast: RayCast3D
@export var visual_model: Node3D

# --- RUNTIME STATE ---
var current_state: State = State.IDLE:
	set(value):
		if current_state != value:
			var prev: State = current_state; current_state = value
			state_changed.emit(prev, current_state)

var state: State:
	get: return current_state
	set(value): current_state = value

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var target_player: Node3D = null
var last_spawned_loot: Node3D = null
var last_rolled_loot_data: Dictionary = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _player_in_detection_zone: bool = false
var _attack_timer: float = 0.0
var _los_lost_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _is_dying: bool = false
var _safe_velocity: Vector3 = Vector3.ZERO
var _body_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	_rng.randomize(); set_meta("ballistic_material", "FLESH"); set_meta("reactive_target", true); add_to_group("enemies")
	floor_snap_length = 0.5; floor_max_angle = deg_to_rad(55.0); floor_constant_speed = true
	health = clampf(health, 1.0, maxf(1.0, max_health))
	_ensure_components()
	_build_procedural_enemy_visuals()
	_load_default_loot_scene()

func _ensure_components() -> void:
	if collision_shape == null: collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new(); collision_shape.name = "CollisionShape3D"
		collision_shape.position = Vector3(0.0, 0.9, 0.0); add_child(collision_shape)
	if collision_shape.shape == null:
		var cap := CapsuleShape3D.new(); cap.radius = 0.42; cap.height = 1.8; collision_shape.shape = cap

	if navigation_agent == null: navigation_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if navigation_agent == null:
		navigation_agent = NavigationAgent3D.new(); navigation_agent.name = "NavigationAgent3D"; add_child(navigation_agent)
	navigation_agent.path_desired_distance = 0.85; navigation_agent.target_desired_distance = maxf(1.2, attack_range * 0.75)
	navigation_agent.avoidance_enabled = true; navigation_agent.radius = 0.48; navigation_agent.max_speed = chase_speed
	if not navigation_agent.velocity_computed.is_connected(_on_navigation_velocity_computed):
		navigation_agent.velocity_computed.connect(_on_navigation_velocity_computed)

	if detection_area == null: detection_area = get_node_or_null("DetectionArea") as Area3D
	if detection_area == null: detection_area = get_node_or_null("DetectionRadius") as Area3D
	if detection_area == null:
		detection_area = Area3D.new(); detection_area.name = "DetectionArea"; add_child(detection_area)
	detection_area.monitoring = true; detection_area.monitorable = false; detection_area.collision_layer = 0; detection_area.collision_mask = 1
	var det_col := detection_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if det_col == null:
		det_col = CollisionShape3D.new(); det_col.name = "CollisionShape3D"; detection_area.add_child(det_col)
	if det_col.shape == null or not (det_col.shape is SphereShape3D):
		var sphere := SphereShape3D.new(); sphere.radius = detection_radius; det_col.shape = sphere
	else: (det_col.shape as SphereShape3D).radius = detection_radius
	if not detection_area.body_entered.is_connected(_on_detection_area_body_entered): detection_area.body_entered.connect(_on_detection_area_body_entered)
	if not detection_area.body_exited.is_connected(_on_detection_area_body_exited): detection_area.body_exited.connect(_on_detection_area_body_exited)

	if los_raycast == null: los_raycast = get_node_or_null("LineOfSightRay") as RayCast3D
	if los_raycast == null:
		los_raycast = RayCast3D.new(); los_raycast.name = "LineOfSightRay"; los_raycast.position = Vector3(0.0, eye_height_offset, 0.0)
		los_raycast.target_position = Vector3(0.0, 0.0, -detection_radius); los_raycast.enabled = true; add_child(los_raycast)
	los_raycast.add_exception(self)

	if visual_model == null: visual_model = get_node_or_null("Visuals") as Node3D
	if visual_model == null:
		visual_model = Node3D.new(); visual_model.name = "Visuals"; add_child(visual_model)

func _load_default_loot_scene() -> void:
	if loot_drop_scene != null: return
	if ResourceLoader.exists("res://scenes/loot_drop.tscn"): loot_drop_scene = load("res://scenes/loot_drop.tscn") as PackedScene
	elif ResourceLoader.exists("res://loot_drop.tscn"): loot_drop_scene = load("res://loot_drop.tscn") as PackedScene

func _build_procedural_enemy_visuals() -> void:
	if visual_model == null or visual_model.get_node_or_null("RaiderRig") != null: return
	var rig := Node3D.new(); rig.name = "RaiderRig"; visual_model.add_child(rig)
	var duster_mat := StandardMaterial3D.new(); duster_mat.albedo_color = Color(0.28, 0.21, 0.16); duster_mat.roughness = 0.88; _body_materials.append(duster_mat)
	var rust_mat := StandardMaterial3D.new(); rust_mat.albedo_color = Color(0.36, 0.22, 0.15); rust_mat.metallic = 0.72; rust_mat.roughness = 0.48; _body_materials.append(rust_mat)
	var visor_mat := StandardMaterial3D.new(); visor_mat.albedo_color = Color(0.95, 0.42, 0.14); visor_mat.emission_enabled = true; visor_mat.emission = Color(0.98, 0.45, 0.12); visor_mat.emission_energy_multiplier = 2.2

	var torso := MeshInstance3D.new(); torso.name = "TorsoMesh"; var t_mesh := CapsuleMesh.new(); t_mesh.radius = 0.36; t_mesh.height = 1.45; t_mesh.material = duster_mat; torso.mesh = t_mesh; torso.position = Vector3(0.0, 0.78, 0.0); rig.add_child(torso)
	var head := MeshInstance3D.new(); head.name = "HeadMesh"; var h_mesh := SphereMesh.new(); h_mesh.radius = 0.21; h_mesh.height = 0.42; h_mesh.material = duster_mat; head.mesh = h_mesh; head.position = Vector3(0.0, 1.58, 0.0); rig.add_child(head)
	var visor := MeshInstance3D.new(); visor.name = "GoggleVisor"; var v_mesh := BoxMesh.new(); v_mesh.size = Vector3(0.24, 0.07, 0.08); v_mesh.material = visor_mat; visor.mesh = v_mesh; visor.position = Vector3(0.0, 1.59, -0.17); rig.add_child(visor)
	var pauldron := MeshInstance3D.new(); pauldron.name = "IronPauldron"; var p_mesh := BoxMesh.new(); p_mesh.size = Vector3(0.32, 0.18, 0.34); p_mesh.material = rust_mat; pauldron.mesh = p_mesh; pauldron.position = Vector3(0.34, 1.28, 0.0); pauldron.rotation.z = deg_to_rad(-14.0); rig.add_child(pauldron)
	var weapon_mesh := MeshInstance3D.new(); weapon_mesh.name = "ScrapCarbine"; var w_box := BoxMesh.new(); w_box.size = Vector3(0.08, 0.12, 0.72); w_box.material = rust_mat; weapon_mesh.mesh = w_box; weapon_mesh.position = Vector3(0.28, 1.02, -0.28); rig.add_child(weapon_mesh)

func _physics_process(delta: float) -> void:
	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		if _hit_flash_timer <= 0.0: _restore_visual_materials()
	if _attack_timer > 0.0: _attack_timer = maxf(0.0, _attack_timer - delta)
	if current_state != State.DEAD and not is_on_floor(): velocity.y -= gravity * delta

	match current_state:
		State.IDLE: _process_idle_state(delta)
		State.CHASE: _process_chase_state(delta)
		State.ATTACK: _process_attack_state(delta)
		State.DEAD: _process_dead_state(delta)

	if current_state != State.DEAD:
		move_and_slide()
		var terrain_h := TerrainCollisionGenerator.sample_height(global_position.x, global_position.z)
		if global_position.y < terrain_h:
			global_position.y = terrain_h
			if velocity.y < 0.0: velocity.y = 0.0

func _process_idle_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta); velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	var candidate := EnemySensors.resolve_candidate_player(detection_area, self, target_player)
	if candidate != null and _is_target_alive(candidate):
		var dist := global_position.distance_to(candidate.global_position)
		if _player_in_detection_zone or dist <= detection_radius:
			if not require_line_of_sight or has_line_of_sight(candidate):
				target_player = candidate; _los_lost_timer = 0.0
				player_detected.emit(target_player); EnemySensors.notify_hud_detection(self, enemy_title_key)
				current_state = State.ATTACK if dist <= attack_range else State.CHASE

func _process_chase_state(delta: float) -> void:
	if target_player == null or not is_instance_valid(target_player):
		target_player = EnemySensors.resolve_candidate_player(detection_area, self, target_player)
		if target_player == null: current_state = State.IDLE; return
	if not _is_target_alive(target_player): reset_aggro(); return

	var target_pos := target_player.global_position
	var dist := global_position.distance_to(target_pos)
	var has_los := has_line_of_sight(target_player)
	if has_los: _los_lost_timer = 0.0
	else: _los_lost_timer += delta

	if dist > lose_interest_radius and _los_lost_timer > 3.0:
		var lost: Node3D = target_player; target_player = null
		player_lost.emit(lost); current_state = State.IDLE; return
	if dist <= attack_range and (has_los or not require_line_of_sight):
		current_state = State.ATTACK; return

	var next_pos := target_pos
	if navigation_agent != null and is_inside_tree():
		navigation_agent.target_position = target_pos
		var nav_next := navigation_agent.get_next_path_position()
		if Vector2(nav_next.x - global_position.x, nav_next.z - global_position.z).length_squared() > 0.01: next_pos = nav_next

	var move_dir := Vector3(next_pos.x - global_position.x, 0.0, next_pos.z - global_position.z)
	move_dir = EnemySensors.apply_local_obstacle_avoidance(self, move_dir.normalized(), target_player) if move_dir.length_squared() > 0.0001 else Vector3.ZERO
	var desired_vel := move_dir * chase_speed
	if navigation_agent != null and navigation_agent.avoidance_enabled and is_inside_tree(): navigation_agent.set_velocity(desired_vel)
	velocity.x = move_toward(velocity.x, desired_vel.x, acceleration * delta); velocity.z = move_toward(velocity.z, desired_vel.z, acceleration * delta)
	_orient_visuals_toward(target_pos if move_dir == Vector3.ZERO else (global_position + move_dir), delta)

func _process_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta); velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	if target_player == null or not is_instance_valid(target_player):
		target_player = EnemySensors.resolve_candidate_player(detection_area, self, target_player)
		if target_player == null: current_state = State.IDLE; return
	if not _is_target_alive(target_player): reset_aggro(); return

	var target_pos := target_player.global_position
	var dist := global_position.distance_to(target_pos)
	var has_los := has_line_of_sight(target_player)
	_orient_visuals_toward(target_pos, delta)

	if dist > attack_range * 1.18 or (require_line_of_sight and not has_los):
		current_state = State.CHASE; return
	if _attack_timer <= 0.0:
		_perform_attack(target_player); _attack_timer = attack_cooldown

func _process_dead_state(_delta: float) -> void:
	velocity = Vector3.ZERO

func _on_navigation_velocity_computed(safe_vel: Vector3) -> void:
	_safe_velocity = safe_vel
	if current_state == State.CHASE and safe_vel.length_squared() > 0.01:
		velocity.x = safe_vel.x; velocity.z = safe_vel.z

func _on_detection_area_body_entered(body: Node3D) -> void:
	if current_state == State.DEAD: return
	if EnemySensors.is_player_node(body) and _is_target_alive(body):
		_player_in_detection_zone = true; target_player = body
		if current_state == State.IDLE and (not require_line_of_sight or has_line_of_sight(body)):
			player_detected.emit(body); EnemySensors.notify_hud_detection(self, enemy_title_key)
			current_state = State.ATTACK if global_position.distance_to(body.global_position) <= attack_range else State.CHASE

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body == target_player or EnemySensors.is_player_node(body): _player_in_detection_zone = false

func has_line_of_sight(target: Node3D = null) -> bool:
	var tgt := target if target != null else target_player
	return EnemySensors.has_line_of_sight(self, tgt, los_raycast, eye_height_offset)

func _orient_visuals_toward(world_target: Vector3, delta: float) -> void:
	if visual_model == null: return
	var flat_delta := Vector3(world_target.x - global_position.x, 0.0, world_target.z - global_position.z)
	if flat_delta.length_squared() < 0.001: return
	visual_model.rotation.y = lerp_angle(visual_model.rotation.y, atan2(-flat_delta.x, -flat_delta.z), minf(1.0, rotation_speed * delta))

func _perform_attack(target: Node3D) -> void:
	if target == null or not is_instance_valid(target) or current_state == State.DEAD: return
	if visual_model != null and is_inside_tree():
		var tw := create_tween(); tw.tween_property(visual_model, "position:z", -0.22, 0.08); tw.tween_property(visual_model, "position:z", 0.0, 0.18)
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage, global_position); attacked_target.emit(target, attack_damage); return
	if "stamina" in target and "max_stamina" in target:
		var max_s: float = float(target.get("max_stamina")); var new_s: float = maxf(0.0, float(target.get("stamina")) - attack_damage)
		target.set("stamina", new_s)
		if target.has_signal("stamina_changed"): target.emit_signal("stamina_changed", new_s, max_s)
	if "weapon_system" in target and target.get("weapon_system") != null:
		var ws: Node = target.get("weapon_system") as Node
		if ws.has_method("expose_to_ambient_grit"): ws.call("expose_to_ambient_grit", 0.25, 35.0)
	attacked_target.emit(target, attack_damage)
	var hud := EnemySensors.find_hud(self)
	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", Localization.t("NOTIF_ENEMY_ATTACK_FMT") % [Localization.t(enemy_title_key), int(round(attack_damage))], 2.2)

func _is_target_alive(target: Node3D) -> bool:
	return target != null and is_instance_valid(target) and not ("is_dead" in target and bool(target.get("is_dead")))

func reset_aggro() -> void:
	if current_state == State.DEAD: return
	target_player = null; _player_in_detection_zone = false; _los_lost_timer = 0.0; _attack_timer = attack_cooldown; current_state = State.IDLE

func force_chase_target(target: Node3D) -> void:
	if current_state == State.DEAD or _is_dying or target == null: return
	target_player = target; _player_in_detection_zone = true; _los_lost_timer = 0.0; current_state = State.CHASE

func apply_elite_modifier(wave_intensity: int) -> void:
	if current_state == State.DEAD or _is_dying: return
	var mult: float = 1.0 + (float(wave_intensity - 3) * 0.22)
	max_health = round(max_health * mult); health = max_health
	attack_damage = round(attack_damage * (1.0 + (float(wave_intensity - 3) * 0.12)))
	chase_speed = minf(chase_speed * 1.15, 5.0)
	for mat in _body_materials:
		if mat != null: mat.albedo_color = mat.albedo_color.lerp(Color(0.42, 0.36, 0.30), 0.5); mat.roughness = 0.98
	drop_chance = 1.0; weight_ammo_45lc += 20.0; weight_rare_components += 15.0

func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD or _is_dying: return
	health = maxf(0.0, health - maxf(0.0, amount))
	_trigger_hit_feedback(hit_position)
	damaged.emit(amount, health, hit_position); health_changed.emit(health, max_health)
	if health <= 0.0: _die()
	elif current_state == State.IDLE:
		var c := EnemySensors.resolve_candidate_player(detection_area, self, target_player)
		if c != null: target_player = c
		current_state = State.CHASE

func _trigger_hit_feedback(hit_position: Vector3) -> void:
	_hit_flash_timer = 0.12
	for mat in _body_materials:
		if mat != null: mat.emission_enabled = true; mat.emission = Color(0.95, 0.45, 0.18); mat.emission_energy_multiplier = 1.6
	if hit_position != Vector3.ZERO:
		var push := Vector3(global_position.x - hit_position.x, 0.0, global_position.z - hit_position.z)
		if push.length_squared() > 0.001: velocity += push.normalized() * 2.2

func _restore_visual_materials() -> void:
	for mat in _body_materials:
		if mat != null: mat.emission_enabled = false; mat.emission_energy_multiplier = 0.0

func _die() -> void:
	if _is_dying or current_state == State.DEAD: return
	_is_dying = true; current_state = State.DEAD; velocity = Vector3.ZERO
	collision_layer = 0; collision_mask = 0
	if collision_shape != null: collision_shape.disabled = true; collision_shape.set_deferred("disabled", true)
	if detection_area != null:
		detection_area.monitoring = false; detection_area.monitorable = false
		detection_area.collision_layer = 0; detection_area.collision_mask = 0

	_play_tactical_collapse()
	var dropped_item: Node3D = null
	if enable_loot_drop:
		var spawn_res := EnemySensors.spawn_loot_drop(self, drop_chance, loot_drop_scene, get_effective_drop_table(), _rng)
		dropped_item = spawn_res.instance; last_spawned_loot = dropped_item; last_rolled_loot_data = spawn_res.data
		if dropped_item != null: loot_dropped.emit(dropped_item, last_rolled_loot_data)

	EnemySensors.notify_hud_defeat(self, enemy_title_key, dropped_item, last_rolled_loot_data)
	if has_meta("is_siege_unit") and bool(get_meta("is_siege_unit")):
		var siege_mgr = get_node_or_null("/root/WastelandSiegeManager")
		if siege_mgr != null and siege_mgr.has_method("report_enemy_defeated"): siege_mgr.report_enemy_defeated(self)

	enemy_defeated.emit(self, global_position); died.emit(self)
	queue_free()

func _play_tactical_collapse() -> void:
	if visual_model != null:
		visual_model.rotation.x = deg_to_rad(-86.0); visual_model.position.y = 0.18
	EnemySensors.spawn_collapse_remnant(self, visual_model)

func set_rng_seed(seed_value: int) -> void: _rng.seed = seed_value
func get_effective_drop_table() -> Array[Dictionary]:
	return EnemySensors.build_effective_drop_table(drop_table, weight_ammo_45lc, weight_survival_water, weight_rare_components)
func roll_loot_drop() -> Dictionary: return EnemySensors.roll_loot_drop(get_effective_drop_table(), _rng)
