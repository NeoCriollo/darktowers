class_name WeaponSystem
extends Node3D

const RevolverBallistics = preload("res://weapons/revolver_ballistics_and_wear.gd")

## Tactical Weapon Mechanics, Cylinder State Machine & Firearm Controller (Godot 4 3D)
## Implements mechanical friction, cylinder sequencing, and diegetic firearm mechanics.
## Ballistics, raymarching, and drag are delegated to RevolverBallisticsAndWear.

# --- SIGNALS ---
signal weapon_fired(data: Dictionary)
signal weapon_dry_fired(reason: String)
signal weapon_jammed(jam_state: ChamberState, description: String)
signal hammer_cocked()
signal action_cycled(extracted_state: ChamberState, new_state: ChamberState)
signal round_loaded(current_rounds: int, max_capacity: int)
signal jam_cleared(previous_jam: ChamberState)
signal maintenance_performed(grit_removed: float, fouling_removed: float)
signal chamber_state_changed(new_state: ChamberState)
signal grit_level_changed(new_grit: float)
signal holster_state_changed(is_holstered: bool)
signal target_hit(hit_info: Dictionary)

# --- ENUMS ---
enum ChamberState {
	EMPTY, CHAMBERED_LIVE, CHAMBERED_SPENT, JAMMED_STOVEPIPE,
	JAMMED_FAILURE_TO_FEED, JAMMED_FAILURE_TO_EXTRACT, OUT_OF_BATTERY
}
enum HammerState { DECOCKED, HALF_COCK, COCKED }
enum ActionType { SINGLE_ACTION_REVOLVER, LEVER_ACTION, BOLT_ACTION }

# --- EXPORTED CONFIGURATION ---
@export_group("Firearm Specification")
@export var weapon_name: String = "Sandalwood-Grip Frontier Revolver"
@export var caliber_name: String = ".45 Long Colt"
@export var action_type: ActionType = ActionType.SINGLE_ACTION_REVOLVER
@export var magazine_capacity: int = 6
@export var base_muzzle_velocity_mps: float = 275.0
@export var base_damage: float = 48.0
@export var effective_range_meters: float = 85.0
@export var recoil_impulse: float = 0.042

@export_group("External Ballistics")
@export var desert_air_density: float = 1.085
@export var bullet_mass_kg: float = 0.0162
@export var bullet_diameter_m: float = 0.01148
@export var drag_coefficient_g1: float = 0.190
@export var ballistic_gravity: float = 9.80665

@export_group("Mechanical State")
@export var chamber_state: ChamberState = ChamberState.CHAMBERED_LIVE:
	set(value):
		var changed: bool = (chamber_state != value)
		chamber_state = value
		if changed: chamber_state_changed.emit(chamber_state)

@export var hammer_state: HammerState = HammerState.COCKED:
	set(value):
		hammer_state = value
		_update_revolver_visual_pose()

@export var current_magazine_rounds: int = 5
@export var is_holstered: bool = false:
	set(value):
		var changed: bool = (is_holstered != value)
		is_holstered = value
		_update_revolver_visual_pose()
		if changed: holster_state_changed.emit(is_holstered)

@export_group("Physical Wear & Contamination")
@export_range(0.0, 1.0, 0.01) var grit_index: float = 0.0:
	set(value):
		grit_index = clampf(value, 0.0, 1.0)
		grit_level_changed.emit(grit_index)
@export_range(0.0, 1.0, 0.01) var fouling_index: float = 0.0
@export_range(0.0, 1.0, 0.01) var corrosion_index: float = 0.0
@export_range(0.0, 1.0, 0.01) var lubrication: float = 0.85

@export_group("Tolerances & Jam Thresholds")
@export var jam_threshold: float = 0.45
@export var jam_logistic_steepness: float = 8.5
@export var holster_protection_factor: float = 0.94

@export_group("Node References")
@export var muzzle_point: Marker3D
@export var aim_raycast: RayCast3D
@export var gunshot_audio: AudioStreamPlayer3D
@export var muzzle_flash: CPUParticles3D
@export var gunshot_stream: AudioStream

# --- RUNTIME STATE ---
var ambient_wind_vector: Vector3 = Vector3.ZERO
var _muzzle_flash_light: OmniLight3D = null
var _muzzle_flash_timer: float = 0.0
var _revolver_visual_root: Node3D = null
var _hammer_mesh_pivot: Node3D = null
var _cylinder_mesh: MeshInstance3D = null
var _char_skeleton: Skeleton3D = null
var _right_hand_bone_idx: int = -1
var _hips_bone_idx: int = -1
var _excluded_rids: Array[RID] = []
const COLT_GLB_PATH: String = "res://assets/weapons/revolvers/sambar_45lc/colt_single_action_pistol.glb"

var is_loaded: bool:
	get: return chamber_state == ChamberState.CHAMBERED_LIVE
var is_jammed: bool:
	get: return chamber_state in [ChamberState.JAMMED_STOVEPIPE, ChamberState.JAMMED_FAILURE_TO_FEED, ChamberState.JAMMED_FAILURE_TO_EXTRACT, ChamberState.OUT_OF_BATTERY]

func _ready() -> void:
	_resolve_references()
	_build_procedural_revolver_model()
	_update_revolver_visual_pose()

func _process(delta: float) -> void:
	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer -= delta
		if _muzzle_flash_light != null:
			_muzzle_flash_light.light_energy = maxf(0.0, (_muzzle_flash_timer / 0.065) * 6.5)
			if _muzzle_flash_timer <= 0.0: _muzzle_flash_light.visible = false
	_sync_revolver_to_hand_bone()

func _resolve_references() -> void:
	if muzzle_point == null: muzzle_point = get_node_or_null("MuzzlePoint") as Marker3D
	if aim_raycast == null: aim_raycast = get_node_or_null("AimRayCast") as RayCast3D
	_muzzle_flash_light = get_node_or_null("MuzzleFlashLight") as OmniLight3D
	if _muzzle_flash_light == null:
		_muzzle_flash_light = OmniLight3D.new(); _muzzle_flash_light.name = "MuzzleFlashLight"
		_muzzle_flash_light.light_color = Color(1.0, 0.72, 0.32); _muzzle_flash_light.omni_range = 9.0
		_muzzle_flash_light.light_energy = 0.0; _muzzle_flash_light.visible = false
		add_child(_muzzle_flash_light)
		if muzzle_point != null: _muzzle_flash_light.position = muzzle_point.position
	if muzzle_flash == null: muzzle_flash = get_node_or_null("MuzzleFlash") as CPUParticles3D
	if muzzle_flash == null:
		muzzle_flash = CPUParticles3D.new(); muzzle_flash.name = "MuzzleFlash"
		muzzle_flash.emitting = false; muzzle_flash.one_shot = true
		muzzle_flash.lifetime = 0.07; muzzle_flash.explosiveness = 1.0; muzzle_flash.amount = 12
		add_child(muzzle_flash)
		if muzzle_point != null: muzzle_flash.position = muzzle_point.position
	if gunshot_audio == null: gunshot_audio = get_node_or_null("GunshotAudio") as AudioStreamPlayer3D
	if gunshot_audio == null:
		gunshot_audio = AudioStreamPlayer3D.new(); gunshot_audio.name = "GunshotAudio"
		gunshot_audio.unit_size = 14.0; gunshot_audio.max_distance = 150.0
		add_child(gunshot_audio)
		if muzzle_point != null: gunshot_audio.position = muzzle_point.position
	if gunshot_stream == null and ResourceLoader.exists("res://assets/audio/gunshot.wav"):
		gunshot_stream = load("res://assets/audio/gunshot.wav")
	if gunshot_audio.stream == null and gunshot_stream != null:
		gunshot_audio.stream = gunshot_stream
	var p := get_parent()
	while p != null:
		if p is CollisionObject3D:
			var rid := (p as CollisionObject3D).get_rid()
			if rid.is_valid() and not _excluded_rids.has(rid): _excluded_rids.append(rid)
			if aim_raycast != null: aim_raycast.add_exception(p as CollisionObject3D)
		p = p.get_parent()

func _build_procedural_revolver_model() -> void:
	if get_node_or_null("RevolverModel") != null:
		_revolver_visual_root = get_node("RevolverModel") as Node3D; return
	_revolver_visual_root = Node3D.new(); _revolver_visual_root.name = "RevolverModel"
	add_child(_revolver_visual_root)

	if ResourceLoader.exists(COLT_GLB_PATH):
		var colt_packed := load(COLT_GLB_PATH) as PackedScene
		if colt_packed != null:
			var colt_inst := colt_packed.instantiate() as Node3D
			if colt_inst != null:
				colt_inst.name = "ColtSingleActionMesh"
				colt_inst.scale = Vector3(0.01, 0.01, 0.01)
				_revolver_visual_root.add_child(colt_inst)
				_cylinder_mesh = colt_inst.find_child("cylinder_low_colt_singleAction_0", true, false) as MeshInstance3D
				return

	var blued_steel := StandardMaterial3D.new(); blued_steel.albedo_color = Color(0.16, 0.17, 0.19); blued_steel.metallic = 0.88; blued_steel.roughness = 0.32
	var worn_brass := StandardMaterial3D.new(); worn_brass.albedo_color = Color(0.68, 0.54, 0.26); worn_brass.metallic = 0.75; worn_brass.roughness = 0.42
	var sandalwood := StandardMaterial3D.new(); sandalwood.albedo_color = Color(0.42, 0.25, 0.14); sandalwood.metallic = 0.05; sandalwood.roughness = 0.78

	var barrel := MeshInstance3D.new(); barrel.name = "Barrel"
	var b_mesh := CylinderMesh.new(); b_mesh.top_radius = 0.016; b_mesh.bottom_radius = 0.018; b_mesh.height = 0.22; b_mesh.material = blued_steel
	barrel.mesh = b_mesh; barrel.rotation.x = PI * 0.5; barrel.position = Vector3(0.0, 0.035, -0.14); _revolver_visual_root.add_child(barrel)
	var ejector := MeshInstance3D.new(); var e_mesh := CylinderMesh.new(); e_mesh.top_radius = 0.009; e_mesh.bottom_radius = 0.009; e_mesh.height = 0.18; e_mesh.material = blued_steel
	ejector.mesh = e_mesh; ejector.rotation.x = PI * 0.5; ejector.position = Vector3(0.008, 0.018, -0.12); _revolver_visual_root.add_child(ejector)
	_cylinder_mesh = MeshInstance3D.new(); _cylinder_mesh.name = "CylinderDrum"
	var c_mesh := CylinderMesh.new(); c_mesh.top_radius = 0.028; c_mesh.bottom_radius = 0.028; c_mesh.height = 0.055; c_mesh.radial_segments = 12; c_mesh.material = blued_steel
	_cylinder_mesh.mesh = c_mesh; _cylinder_mesh.rotation.x = PI * 0.5; _cylinder_mesh.position = Vector3(0.0, 0.025, -0.005); _revolver_visual_root.add_child(_cylinder_mesh)
	var frame := MeshInstance3D.new(); var f_mesh := BoxMesh.new(); f_mesh.size = Vector3(0.034, 0.068, 0.095); f_mesh.material = worn_brass
	frame.mesh = f_mesh; frame.position = Vector3(0.0, 0.018, 0.005); _revolver_visual_root.add_child(frame)
	var grip := MeshInstance3D.new(); var g_mesh := BoxMesh.new(); g_mesh.size = Vector3(0.032, 0.11, 0.042); g_mesh.material = sandalwood
	grip.mesh = g_mesh; grip.position = Vector3(0.0, -0.045, 0.055); grip.rotation.x = deg_to_rad(22.0); _revolver_visual_root.add_child(grip)
	_hammer_mesh_pivot = Node3D.new(); _hammer_mesh_pivot.name = "HammerPivot"; _hammer_mesh_pivot.position = Vector3(0.0, 0.045, 0.038); _revolver_visual_root.add_child(_hammer_mesh_pivot)
	var hammer_spur := MeshInstance3D.new(); var h_mesh := BoxMesh.new(); h_mesh.size = Vector3(0.012, 0.032, 0.018); h_mesh.material = blued_steel
	hammer_spur.mesh = h_mesh; hammer_spur.position = Vector3(0.0, 0.014, 0.006); _hammer_mesh_pivot.add_child(hammer_spur)

func _sync_revolver_to_hand_bone() -> void:
	if _revolver_visual_root == null or not is_inside_tree():
		return
	if _char_skeleton == null and get_parent() != null:
		var char_model := get_parent().get_node_or_null("CharacterModel")
		if char_model != null:
			_char_skeleton = char_model.find_child("Skeleton3D", true, false) as Skeleton3D
			if _char_skeleton != null:
				_right_hand_bone_idx = _char_skeleton.find_bone("mixamorig_RightHand")
				if _right_hand_bone_idx == -1: _right_hand_bone_idx = _char_skeleton.find_bone("mixamorig:RightHand")
				_hips_bone_idx = _char_skeleton.find_bone("mixamorig_Hips")
				if _hips_bone_idx == -1: _hips_bone_idx = _char_skeleton.find_bone("mixamorig:Hips")
	if _char_skeleton == null or not _char_skeleton.is_inside_tree():
		return
	if not is_holstered and _right_hand_bone_idx >= 0:
		var bw: Transform3D = _char_skeleton.global_transform * _char_skeleton.get_bone_global_pose(_right_hand_bone_idx)
		var hx: Vector3 = bw.basis.x.normalized()
		var hy: Vector3 = bw.basis.y.normalized()
		var hz: Vector3 = bw.basis.z.normalized()
		var bz: Vector3 = -hx
		var by: Vector3 = (-hy - bz * (-hy).dot(bz)).normalized()
		var bx: Vector3 = by.cross(bz).normalized()
		var palm_pos: Vector3 = bw.origin + hy * 0.075 + hz * 0.022 + hx * 0.015
		_revolver_visual_root.global_transform = Transform3D(Basis(bx, by, bz), palm_pos)
	elif is_holstered and _hips_bone_idx >= 0:
		var hw: Transform3D = _char_skeleton.global_transform * _char_skeleton.get_bone_global_pose(_hips_bone_idx)
		var rx: Vector3 = hw.basis.x.normalized()
		var ry: Vector3 = hw.basis.y.normalized()
		var rz: Vector3 = hw.basis.z.normalized()
		_revolver_visual_root.global_transform = Transform3D(Basis(rx, -rz, ry), hw.origin - rx * 0.19 - rz * 0.08)

func _update_revolver_visual_pose() -> void:
	if _revolver_visual_root != null:
		if is_holstered:
			_revolver_visual_root.position = Vector3(0.0, -0.35, 0.18); _revolver_visual_root.rotation = Vector3(deg_to_rad(-75.0), 0.0, 0.0)
		else:
			_revolver_visual_root.position = Vector3.ZERO; _revolver_visual_root.rotation = Vector3.ZERO
	if _hammer_mesh_pivot != null:
		match hammer_state:
			HammerState.COCKED: _hammer_mesh_pivot.rotation.x = deg_to_rad(-42.0)
			HammerState.HALF_COCK: _hammer_mesh_pivot.rotation.x = deg_to_rad(-18.0)
			_: _hammer_mesh_pivot.rotation.x = deg_to_rad(4.0)

# --- PUBLIC DEGRADATION & BALLISTICS APIS ---
func get_composite_degradation() -> float:
	return RevolverBallistics.get_composite_degradation(grit_index, fouling_index, corrosion_index, lubrication)

func compute_actual_muzzle_velocity() -> float:
	return RevolverBallistics.compute_actual_muzzle_velocity(base_muzzle_velocity_mps, grit_index, fouling_index, corrosion_index)

func compute_jam_probability() -> float:
	return RevolverBallistics.compute_jam_probability(get_composite_degradation(), jam_threshold, jam_logistic_steepness)

func toggle_holster() -> bool:
	is_holstered = not is_holstered
	return is_holstered

# --- FIRING & CYLINDER STATE MACHINE ---
func fire() -> Dictionary:
	var result: Dictionary = {
		"success": false, "discharged": false, "jammed": false, "casing_extracted": false,
		"muzzle_velocity_mps": 0.0, "impact_velocity_mps": 0.0, "damage": 0.0,
		"hit_collider": null, "hit_position": Vector3.ZERO, "hit_normal": Vector3.UP,
		"distance_m": 0.0, "flight_time_s": 0.0, "gravity_drop_m": 0.0, "wind_drift_m": 0.0,
		"material_type": "NONE", "recoil_impulse": recoil_impulse, "message": ""
	}
	if is_holstered:
		result["message"] = "Weapon is holstered. Press [H] to draw."; weapon_dry_fired.emit("HOLSTERED"); return result
	if hammer_state != HammerState.COCKED:
		result["message"] = "Hammer is decocked. Press [F] to cock the hammer."; weapon_dry_fired.emit("HAMMER_NOT_COCKED"); return result
	if is_jammed:
		result["message"] = "Action is jammed! Press [V] to clear the chamber."; result["jammed"] = true; weapon_dry_fired.emit("ACTION_SEIZED"); return result

	match chamber_state:
		ChamberState.EMPTY:
			result["message"] = "Chamber is empty."; hammer_state = HammerState.DECOCKED; weapon_dry_fired.emit("DRY_FIRE_EMPTY"); return result
		ChamberState.CHAMBERED_SPENT:
			result["message"] = "Hammer dropped on an already-fired spent primer. Cock [F] to index cylinder."; hammer_state = HammerState.DECOCKED; weapon_dry_fired.emit("SPENT_PRIMER_CLICK"); return result
		ChamberState.CHAMBERED_LIVE:
			var jam_prob := compute_jam_probability()
			if randf() < jam_prob:
				chamber_state = RevolverBallistics.determine_jam_type(grit_index, fouling_index) as ChamberState
				hammer_state = HammerState.DECOCKED; result["jammed"] = true
				result["message"] = "Weapon jammed! Particulate grit seized the mechanism."; weapon_jammed.emit(chamber_state, result["message"]); return result

			hammer_state = HammerState.DECOCKED
			var actual_velocity := compute_actual_muzzle_velocity()
			var velocity_ratio := actual_velocity / base_muzzle_velocity_mps
			fouling_index = minf(1.0, fouling_index + 0.022); lubrication = maxf(0.0, lubrication - 0.008)
			if grit_index > 0.05: corrosion_index = minf(1.0, corrosion_index + 0.002)
			chamber_state = ChamberState.CHAMBERED_SPENT
			_trigger_muzzle_flash()
			_play_gunshot_audio()

			var b_cfg: Dictionary = {
				"muzzle_velocity": actual_velocity, "muzzle_point": muzzle_point, "aim_raycast": aim_raycast,
				"effective_range_meters": effective_range_meters, "excluded_rids": _excluded_rids,
				"ambient_wind_vector": ambient_wind_vector, "ballistic_gravity": ballistic_gravity,
				"bullet_diameter_m": bullet_diameter_m, "desert_air_density": desert_air_density,
				"drag_coefficient_g1": drag_coefficient_g1, "bullet_mass_kg": bullet_mass_kg
			}
			var hit_info := RevolverBallistics.perform_ballistic_raycast(self, b_cfg)
			var impact_vel: float = float(hit_info.get("impact_velocity_mps", actual_velocity))
			var final_damage: float = base_damage * (impact_vel / base_muzzle_velocity_mps)

			result["success"] = true; result["discharged"] = true
			result["muzzle_velocity_mps"] = actual_velocity; result["impact_velocity_mps"] = impact_vel
			result["damage"] = final_damage; result["hit_collider"] = hit_info.get("collider")
			result["hit_position"] = hit_info.get("position", Vector3.ZERO); result["hit_normal"] = hit_info.get("normal", Vector3.UP)
			result["distance_m"] = hit_info.get("distance_m", 0.0); result["flight_time_s"] = hit_info.get("flight_time_s", 0.0)
			result["gravity_drop_m"] = hit_info.get("gravity_drop_m", 0.0); result["wind_drift_m"] = hit_info.get("wind_drift_m", 0.0)
			result["material_type"] = hit_info.get("material_type", "NONE")
			result["recoil_impulse"] = recoil_impulse * (0.8 + 0.4 * velocity_ratio)
			result["message"] = "Round discharged at %d m/s." % int(actual_velocity)

			if result["hit_collider"] != null:
				var hit_obj: Object = result["hit_collider"]
				if hit_obj.has_method("take_damage"): hit_obj.call("take_damage", final_damage, result["hit_position"])
				elif hit_obj is Node and (hit_obj as Node).get_parent() != null and (hit_obj as Node).get_parent().has_method("take_damage"):
					(hit_obj as Node).get_parent().call("take_damage", final_damage, result["hit_position"])
				target_hit.emit(result)

			weapon_fired.emit(result)
			return result
		_:
			result["message"] = "Invalid chamber state."; return result

func cock_hammer() -> bool:
	if is_holstered: weapon_dry_fired.emit("HOLSTERED"); return false
	if is_jammed: weapon_dry_fired.emit("CANNOT_COCK_JAMMED"); return false
	if hammer_state == HammerState.COCKED: return false
	if grit_index > 0.75 and randf() < 0.25:
		hammer_state = HammerState.HALF_COCK; weapon_dry_fired.emit("HAMMER_SLIPPED_HALF_COCK"); return false
	hammer_state = HammerState.COCKED
	if action_type == ActionType.SINGLE_ACTION_REVOLVER:
		_advance_cylinder()
		if _cylinder_mesh != null: _cylinder_mesh.rotate_object_local(Vector3.UP, TAU / float(max(1, magazine_capacity)))
	hammer_cocked.emit()
	return true

func _advance_cylinder() -> void:
	if chamber_state == ChamberState.CHAMBERED_SPENT or chamber_state == ChamberState.EMPTY:
		if current_magazine_rounds > 0:
			current_magazine_rounds -= 1; chamber_state = ChamberState.CHAMBERED_LIVE
		else: chamber_state = ChamberState.EMPTY

func cycle_action() -> bool:
	if is_jammed: weapon_dry_fired.emit("CANNOT_CYCLE_JAMMED"); return false
	var extracted: ChamberState = chamber_state
	if extracted == ChamberState.CHAMBERED_SPENT: RevolverBallistics.spawn_spent_brass_casing(self)
	if current_magazine_rounds > 0:
		current_magazine_rounds -= 1; chamber_state = ChamberState.CHAMBERED_LIVE
	else: chamber_state = ChamberState.EMPTY
	hammer_state = HammerState.COCKED
	action_cycled.emit(extracted, chamber_state)
	return true

func reload_single_round() -> bool:
	if is_holstered: weapon_dry_fired.emit("HOLSTERED"); return false
	if is_jammed: weapon_dry_fired.emit("CANNOT_RELOAD_JAMMED"); return false
	var total_rounds: int = current_magazine_rounds + (1 if is_loaded else 0)
	if total_rounds >= magazine_capacity: return false
	if chamber_state == ChamberState.CHAMBERED_SPENT:
		RevolverBallistics.spawn_spent_brass_casing(self); chamber_state = ChamberState.CHAMBERED_LIVE
	elif chamber_state == ChamberState.EMPTY: chamber_state = ChamberState.CHAMBERED_LIVE
	else: current_magazine_rounds = mini(magazine_capacity, current_magazine_rounds + 1)
	round_loaded.emit(current_magazine_rounds + (1 if is_loaded else 0), magazine_capacity)
	return true

func clear_jam() -> bool:
	if not is_jammed: return false
	var old_jam: ChamberState = chamber_state
	if randf() <= (1.0 - grit_index * 0.45):
		RevolverBallistics.spawn_spent_brass_casing(self)
		chamber_state = ChamberState.EMPTY; hammer_state = HammerState.DECOCKED
		jam_cleared.emit(old_jam); return true
	weapon_dry_fired.emit("CLEAR_ATTEMPT_STUBBORN")
	return false

# --- MAINTENANCE & EXPOSURE APIS ---
func clean_bore(patch_q: float = 0.9, solvent_q: float = 0.95) -> Dictionary:
	var r := RevolverBallistics.clean_bore(fouling_index, grit_index, lubrication, patch_q, solvent_q)
	fouling_index = r.new_fouling; grit_index = r.new_grit; lubrication = r.new_lubrication
	return { "fouling_removed": r.fouling_removed, "grit_removed": r.grit_removed }

func brush_action_and_rails(brush_q: float = 0.95) -> Dictionary:
	var r := RevolverBallistics.brush_action_and_rails(grit_index, brush_q)
	grit_index = r.new_grit
	return { "grit_removed": r.grit_removed }

func lubricate(oil_q: float = 0.85) -> Dictionary:
	var r := RevolverBallistics.lubricate(lubrication, corrosion_index, oil_q)
	lubrication = r.new_lubrication; corrosion_index = r.new_corrosion
	return { "current_lubrication": lubrication }

func field_clean(solvent_amt: float = 0.5) -> Dictionary:
	var grit_before := grit_index; var foul_before := fouling_index
	var r := RevolverBallistics.field_clean(grit_index, fouling_index, corrosion_index, lubrication, solvent_amt)
	grit_index = r.remaining_grit; fouling_index = r.remaining_fouling
	corrosion_index = r.current_corrosion; lubrication = r.current_lubrication
	maintenance_performed.emit(grit_before - grit_index, foul_before - fouling_index)
	return r

func foul_from_ground_contact(severity: float = 0.05) -> void:
	var r := RevolverBallistics.calculate_ground_contact_foul(grit_index, lubrication, severity, is_holstered, holster_protection_factor)
	grit_index = r.new_grit; lubrication = r.new_lubrication

func expose_to_ambient_grit(delta_s: float, density: float) -> void:
	var r := RevolverBallistics.calculate_ambient_grit(grit_index, lubrication, delta_s, density, is_holstered, holster_protection_factor)
	grit_index = r.new_grit; lubrication = r.new_lubrication

func expose_to_salt_corrosion(delta_s: float, mult: float = 1.0) -> void:
	var r := RevolverBallistics.calculate_salt_corrosion(corrosion_index, lubrication, delta_s, mult, is_holstered, holster_protection_factor)
	corrosion_index = r.new_corrosion; lubrication = r.new_lubrication

func _trigger_muzzle_flash() -> void:
	if _muzzle_flash_light != null:
		if muzzle_point != null: _muzzle_flash_light.position = muzzle_point.position
		_muzzle_flash_light.light_energy = 6.5; _muzzle_flash_light.visible = true; _muzzle_flash_timer = 0.065
	if muzzle_flash != null:
		if muzzle_point != null: muzzle_flash.position = muzzle_point.position
		muzzle_flash.restart()
		muzzle_flash.emitting = true

func _play_gunshot_audio() -> void:
	if gunshot_audio != null:
		if gunshot_audio.stream == null:
			gunshot_audio.stream = gunshot_stream if gunshot_stream != null else _build_procedural_gunshot_stream()
		gunshot_audio.pitch_scale = randf_range(0.96, 1.04)
		gunshot_audio.play()

func _build_procedural_gunshot_stream() -> AudioStreamWAV:
	var rate: int = 22050; var dur: float = 0.45; var n: int = int(dur * float(rate))
	var data := PackedByteArray(); data.resize(n * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 0x4B415745; var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(rate)
		var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 180.0)
		var freq := 140.0 * exp(-t * 24.0) + 50.0
		phase += TAU * freq / float(rate)
		var punch := sin(phase) * exp(-t * 22.0)
		var tail := rng.randf_range(-1.0, 1.0) * exp(-t * 8.0) * 0.3
		var s: float = clampf(crack * 1.5 + punch * 1.2 + tail, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 28000.0))
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate; wav.stereo = false; wav.data = data
	return wav

func inspect_weapon() -> Dictionary:
	return RevolverBallistics.build_inspection_report(
		weapon_name, grit_index, fouling_index, corrosion_index, lubrication,
		is_jammed, is_loaded, is_holstered, current_magazine_rounds, magazine_capacity,
		hammer_state == HammerState.COCKED, hammer_state == HammerState.HALF_COCK,
		base_muzzle_velocity_mps, jam_threshold, jam_logistic_steepness
	)
