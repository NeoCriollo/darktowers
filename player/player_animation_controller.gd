class_name PlayerAnimationController
extends RefCounted

## Handles animation state transitions, 8-way directional pistol-aim locomotion,
## crouch/kneel transitions, jumps, in-place root motion stripping, and velocity-scaled stride.

var animation_player: AnimationPlayer = null
var current_anim: String = ""
var walk_anim_name: String = ""
var idle_anim_name: String = "idle_stand"
var _target_node_prefix: String = ""
var _target_bone_subpath: String = ""
var _was_crouching: bool = false
var _transition_anim: String = ""
var _transition_timer: float = 0.0
var _action_anim: String = ""
var _action_timer: float = 0.0
var _is_dead_anim: bool = false

const BLEND_TIME: float = 0.18
const NATURAL_STRIDE_SPEED: float = 2.4
const PISTOL_ANIM_DIR: String = "res://assets/characters/gunslinger/base_rig/animations/pistol_aim/"

const PISTOL_CLIPS: Dictionary = {
	"pistol_idle": {"file": "pistol_idle.glb", "loop": true, "strip_xy": false},
	"pistol_jump": {"file": "pistol_jump.glb", "loop": false, "strip_xy": true},
	"pistol_jump2": {"file": "pistol_jump2.glb", "loop": false, "strip_xy": true},
	"pistol_kneel_to_stand": {"file": "pistol_kneel_to_stand.glb", "loop": false, "strip_xy": true},
	"pistol_kneeling_idle": {"file": "pistol_kneeling_idle.glb", "loop": true, "strip_xy": false},
	"pistol_stand_to_kneel": {"file": "pistol_stand_to_kneel.glb", "loop": false, "strip_xy": true},
	"pistol_walk": {"file": "pistol_walk.glb", "loop": true, "strip_xy": true},
	"pistol_walk_arc": {"file": "pistol_walk_arc.glb", "loop": true, "strip_xy": true},
	"pistol_walk_arc_2": {"file": "pistol_walk_arc_2.glb", "loop": true, "strip_xy": true},
	"pistol_walk_backward": {"file": "pistol_walk_backward.glb", "loop": true, "strip_xy": true},
	"pistol_walk_backward_arc": {"file": "pistol_walk_backward_arc.glb", "loop": true, "strip_xy": true},
	"pistol_walk_backward_arc_2": {"file": "pistol_walk_backward_arc_2.glb", "loop": true, "strip_xy": true},
	"pistol_run": {"file": "pistol_run.glb", "loop": true, "strip_xy": true},
	"pistol_run_arc": {"file": "pistol_run_arc.glb", "loop": true, "strip_xy": true},
	"pistol_run_arc_2": {"file": "pistol_run_arc_2.glb", "loop": true, "strip_xy": true},
	"pistol_run_backward": {"file": "pistol_run_backward.glb", "loop": true, "strip_xy": true},
	"pistol_run_backward_arc": {"file": "pistol_run_backward_arc.glb", "loop": true, "strip_xy": true},
	"pistol_run_backward_arc_2": {"file": "pistol_run_backward_arc_2.glb", "loop": true, "strip_xy": true},
	"pistol_strafe": {"file": "pistol_strafe.glb", "loop": true, "strip_xy": true},
	"pistol_strafe_2": {"file": "pistol_strafe_2.glb", "loop": true, "strip_xy": true},
	"pistol_shoot": {"file": "shooting.glb", "loop": false, "strip_xy": false},
	"pistol_firing": {"file": "firing.glb", "loop": false, "strip_xy": false},
	"hit_reaction": {"file": "hit_reaction.glb", "loop": false, "strip_xy": false},
	"hit_reaction_idle": {"file": "hit_reaction_idle_no_gun.glb", "loop": false, "strip_xy": false},
	"standing_react_death": {"file": "standing_react_death.glb", "loop": false, "strip_xy": true},
	"crouch_walking": {"file": "crouch_walking.glb", "loop": true, "strip_xy": true},
	"unarmed_idle": {"file": "res://assets/characters/gunslinger/base_rig/animations/unarmed/unarmed_idle.glb", "loop": true, "strip_xy": false},
	"unarmed_jump": {"file": "res://assets/characters/gunslinger/base_rig/animations/unarmed/unarmed_jump.glb", "loop": false, "strip_xy": true},
	"unarmed_run": {"file": "res://assets/characters/gunslinger/base_rig/animations/unarmed/unarmed_run.glb", "loop": true, "strip_xy": true}
}

func setup(player_node: Node) -> void:
	if player_node == null:
		return
	var visuals := player_node.get_node_or_null("Visuals")
	if visuals != null:
		var char_model := visuals.get_node_or_null("CharacterModel") as Node3D
		if char_model != null:
			# Mixamo glTF models face +Z; Godot forward is -Z, so rotate 180 deg around Y
			char_model.rotation.y = PI
		animation_player = visuals.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		animation_player = player_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		for child in player_node.find_children("*", "", true, false):
			if child is AnimationPlayer:
				animation_player = child
				break

	if animation_player != null:
		_configure_animation_loop()
		_load_pistol_animation_library()

func _configure_animation_loop() -> void:
	if animation_player == null:
		return
	var anim_list: PackedStringArray = animation_player.get_animation_list()
	for anim_name in anim_list:
		if anim_name != "RESET" and anim_name != idle_anim_name:
			walk_anim_name = anim_name
			break
	if walk_anim_name == "" and anim_list.size() > 0:
		walk_anim_name = anim_list[0]

	if walk_anim_name != "" and animation_player.has_animation(walk_anim_name):
		var anim: Animation = animation_player.get_animation(walk_anim_name)
		if anim != null:
			_capture_target_track_format(anim)
			_remap_animation_tracks_to_player_rig(anim)
			_strip_root_horizontal_drift(anim)
			anim.loop_mode = Animation.LOOP_LINEAR
			_create_idle_pose_animation(anim)

		if animation_player.has_animation(idle_anim_name):
			animation_player.play(idle_anim_name)
			current_anim = idle_anim_name
		else:
			animation_player.play(walk_anim_name)
			animation_player.seek(0.0, true)
			animation_player.pause()

func _capture_target_track_format(base_anim: Animation) -> void:
	for t_idx in range(base_anim.get_track_count()):
		var p: NodePath = base_anim.track_get_path(t_idx)
		var ps: String = String(p)
		if ps.contains("Hips"):
			var colon_idx: int = ps.find(":")
			if colon_idx != -1:
				_target_node_prefix = ps.left(colon_idx)
				_target_bone_subpath = ps.substr(colon_idx + 1)
			else:
				var hips_idx: int = ps.find("mixamorig")
				if hips_idx == -1:
					hips_idx = ps.find("Hips")
				_target_node_prefix = ps.left(hips_idx) if hips_idx > 0 else ""
				_target_bone_subpath = ""
			break

func _remap_animation_tracks_to_player_rig(anim: Animation) -> void:
	if _target_node_prefix == "" and _target_bone_subpath == "":
		return

	var best_tracks: Dictionary = {}
	for t_idx in range(anim.get_track_count()):
		var p: String = String(anim.track_get_path(t_idx))
		var colon_idx: int = p.find(":")
		var bone_part: String = ""
		if colon_idx != -1:
			bone_part = p.substr(colon_idx + 1)
		else:
			var slash_idx: int = p.rfind("/")
			bone_part = p.substr(slash_idx + 1) if slash_idx != -1 else p

		bone_part = _strip_duplicate_armature_bone_suffix(bone_part)
		if _target_bone_subpath != "":
			if _target_bone_subpath.contains("mixamorig_") and bone_part.contains("mixamorig:"):
				bone_part = bone_part.replace("mixamorig:", "mixamorig_")
			elif _target_bone_subpath.contains("mixamorig:") and bone_part.contains("mixamorig_"):
				bone_part = bone_part.replace("mixamorig_", "mixamorig:")
		else:
			var hips_pos: int = p.find("mixamorig")
			if hips_pos == -1: hips_pos = p.find("Hips")
			if hips_pos != -1: bone_part = _strip_duplicate_armature_bone_suffix(p.substr(hips_pos))

		var t_type: int = anim.track_get_type(t_idx)
		if t_type == Animation.TYPE_POSITION_3D and not bone_part.contains("Hips"): continue
		if t_type == Animation.TYPE_SCALE_3D: continue

		var final_path: String = (_target_node_prefix + ":" + bone_part) if _target_bone_subpath != "" else (_target_node_prefix + bone_part)
		var key_count: int = anim.track_get_key_count(t_idx)
		var sig: String = final_path + "|" + str(t_type)

		if not best_tracks.has(sig) or key_count > int(best_tracks[sig]["key_count"]):
			var keys: Array[Dictionary] = []
			for k in range(key_count):
				keys.append({"time": anim.track_get_key_time(t_idx, k), "val": anim.track_get_key_value(t_idx, k), "trans": anim.track_get_key_transition(t_idx, k)})
			best_tracks[sig] = {"path": final_path, "type": t_type, "interp": anim.track_get_interpolation_type(t_idx), "key_count": key_count, "keys": keys}

	anim.clear()
	for sig in best_tracks:
		var info: Dictionary = best_tracks[sig]
		var new_idx: int = anim.add_track(int(info["type"]))
		anim.track_set_path(new_idx, NodePath(String(info["path"])))
		anim.track_set_interpolation_type(new_idx, int(info["interp"]))
		for k_data in (info["keys"] as Array[Dictionary]):
			anim.track_insert_key(new_idx, float(k_data["time"]), k_data["val"], float(k_data["trans"]))

func _strip_duplicate_armature_bone_suffix(bone_name: String) -> String:
	for suffix in ["_2", "_3", "_4", "_5", "_6", "_7", "_8", ".001", ".002", ".003", ".004", ".005", ".006", ".007"]:
		if bone_name.ends_with(suffix):
			return bone_name.left(bone_name.length() - suffix.length())
	return bone_name

func _load_pistol_animation_library() -> void:
	if animation_player == null:
		return
	var lib: AnimationLibrary = _get_default_library()
	if lib == null:
		return

	for clip_key in PISTOL_CLIPS.keys():
		if lib.has_animation(clip_key):
			continue
		var meta: Dictionary = PISTOL_CLIPS[clip_key]
		var file_str: String = String(meta.get("file", ""))
		var full_path: String = file_str if file_str.begins_with("res://") else PISTOL_ANIM_DIR + file_str
		if not ResourceLoader.exists(full_path):
			continue
		var packed := load(full_path) as PackedScene
		if packed == null:
			continue
		var temp_inst: Node = packed.instantiate()
		if temp_inst == null:
			continue
		var src_ap := temp_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if src_ap == null:
			for c in temp_inst.get_children():
				if c is AnimationPlayer:
					src_ap = c
					break
		if src_ap != null:
			var src_list: PackedStringArray = src_ap.get_animation_list()
			var chosen_name: String = ""
			for i in range(src_list.size() - 1, -1, -1):
				if src_list[i] != "RESET":
					chosen_name = src_list[i]
					break
			if chosen_name != "" and src_ap.has_animation(chosen_name):
				var src_anim: Animation = src_ap.get_animation(chosen_name)
				if src_anim != null:
					var dup_anim: Animation = src_anim.duplicate(true) as Animation
					_remap_animation_tracks_to_player_rig(dup_anim)
					var is_loop: bool = bool(meta.get("loop", true))
					if bool(meta.get("strip_xy", true)):
						_strip_root_horizontal_drift(dup_anim, is_loop)
					dup_anim.loop_mode = Animation.LOOP_LINEAR if is_loop else Animation.LOOP_NONE
					lib.add_animation(clip_key, dup_anim)
		temp_inst.free()

	if lib.has_animation("unarmed_idle"):
		idle_anim_name = "unarmed_idle"

	# Start in pistol_idle pose if available so the character never appears in T-pose
	if animation_player.has_animation("pistol_idle"):
		animation_player.play("pistol_idle")
		current_anim = "pistol_idle"

func _get_default_library() -> AnimationLibrary:
	if animation_player == null:
		return null
	var lib_name: StringName = &""
	var libs: Array[StringName] = animation_player.get_animation_library_list()
	if libs.size() > 0:
		lib_name = libs[0]
	return animation_player.get_animation_library(lib_name)

## Strips horizontal X/Y root-motion travel and progressive root-turn drift on the Hips bone.
func _strip_root_horizontal_drift(anim: Animation, strip_rot_drift: bool = true) -> void:
	var track_count: int = anim.get_track_count()
	for t_idx in range(track_count):
		var path_str: String = String(anim.track_get_path(t_idx))
		if not path_str.contains("Hips"):
			continue
		var key_count: int = anim.track_get_key_count(t_idx)
		if key_count < 2:
			continue
		var t_type: int = anim.track_get_type(t_idx)
		if t_type == Animation.TYPE_POSITION_3D:
			var v0: Vector3 = anim.track_get_key_value(t_idx, 0)
			var v_end: Vector3 = anim.track_get_key_value(t_idx, key_count - 1)
			var delta: Vector3 = (v_end - v0).abs()
			for k_idx in range(key_count):
				var val: Vector3 = anim.track_get_key_value(t_idx, k_idx)
				# Mixamo Hips local axes: X = lateral, Y = forward/back, Z = vertical height
				if delta.x > 0.15:
					val.x = v0.x
				if delta.y > 0.15:
					val.y = v0.y
				anim.track_set_key_value(t_idx, k_idx, val)
		elif t_type == Animation.TYPE_ROTATION_3D and strip_rot_drift:
			var q0: Quaternion = anim.track_get_key_value(t_idx, 0)
			var q_end: Quaternion = anim.track_get_key_value(t_idx, key_count - 1)
			if q0.dot(q_end) < 0.0:
				q_end = -q_end
			if q0.angle_to(q_end) > 0.04:
				# In parent space: q_end = delta_p * q0 => delta_p = q_end * q0.inverse()
				var delta_p_inv: Quaternion = (q_end * q0.inverse()).inverse()
				for k_idx in range(key_count):
					var u: float = float(k_idx) / float(key_count - 1)
					var q_val: Quaternion = anim.track_get_key_value(t_idx, k_idx)
					if q0.dot(q_val) < 0.0:
						q_val = -q_val
					var drift_corr: Quaternion = Quaternion.IDENTITY.slerp(delta_p_inv, u)
					# Multiply on the LEFT in parent space to cancel progressive yaw turn without tilting pelvis
					anim.track_set_key_value(t_idx, k_idx, (drift_corr * q_val).normalized())

func _create_idle_pose_animation(walk_anim: Animation) -> void:
	var lib: AnimationLibrary = _get_default_library()
	if lib == null or lib.has_animation(idle_anim_name):
		return
	var idle_anim := Animation.new()
	idle_anim.length = 0.5
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	for t_idx in range(walk_anim.get_track_count()):
		if walk_anim.track_get_key_count(t_idx) == 0:
			continue
		var new_idx: int = idle_anim.add_track(walk_anim.track_get_type(t_idx))
		idle_anim.track_set_path(new_idx, walk_anim.track_get_path(t_idx))
		idle_anim.track_set_interpolation_type(new_idx, walk_anim.track_get_interpolation_type(t_idx))
		var neutral_val: Variant = walk_anim.track_get_key_value(t_idx, 0)
		idle_anim.track_insert_key(new_idx, 0.0, neutral_val)
		idle_anim.track_insert_key(new_idx, 0.5, neutral_val)
	lib.add_animation(idle_anim_name, idle_anim)

## Triggers an expressive action clip (e.g. gunshot recoil, hit flinch, or death reaction).
func play_action_clip(clip_key: String, duration: float = 0.35, speed: float = 1.0, is_fatal: bool = false) -> void:
	if animation_player == null or not animation_player.has_animation(clip_key):
		return
	_action_anim = clip_key
	_action_timer = duration
	_is_dead_anim = is_fatal
	animation_player.speed_scale = speed
	animation_player.play(clip_key, 0.1)
	current_anim = clip_key

func reset_death_state() -> void:
	_is_dead_anim = false
	_action_anim = ""
	_action_timer = 0.0

## Updates locomotion playback state, selecting directional pistol clips or holstered clips.
func update_locomotion(
	velocity_length_2d: float,
	is_on_floor: bool,
	is_sprinting: bool,
	input_dir: Vector2 = Vector2.ZERO,
	is_crouching: bool = false,
	is_weapon_ready: bool = true,
	just_jumped: bool = false
) -> void:
	if animation_player == null or walk_anim_name == "":
		return

	if _is_dead_anim:
		return

	if _action_timer > 0.0:
		_action_timer = maxf(0.0, _action_timer - (1.0 / 60.0))
		if velocity_length_2d < 0.25:
			return

	if _transition_timer > 0.0:
		_transition_timer = maxf(0.0, _transition_timer - (1.0 / 60.0))

	# Handle Jump / Airborne
	if not is_on_floor or just_jumped:
		var jump_clip: String = "pistol_jump2" if velocity_length_2d > 1.5 else "pistol_jump"
		if not is_weapon_ready and animation_player.has_animation("unarmed_jump"):
			jump_clip = "unarmed_jump"
		if animation_player.has_animation(jump_clip):
			animation_player.speed_scale = 1.0
			if current_anim != jump_clip:
				animation_player.play(jump_clip, BLEND_TIME)
				current_anim = jump_clip
			return
		if animation_player.is_playing() and current_anim == walk_anim_name:
			animation_player.speed_scale = 0.25
		return

	# Handle Crouch / Stand Transition Triggers
	if is_crouching != _was_crouching:
		_was_crouching = is_crouching
		var trans_clip: String = "pistol_stand_to_kneel" if is_crouching else "pistol_kneel_to_stand"
		if velocity_length_2d < 0.25 and animation_player.has_animation(trans_clip):
			_transition_anim = trans_clip
			_transition_timer = 0.55
			animation_player.speed_scale = 1.35
			animation_player.play(trans_clip, BLEND_TIME)
			current_anim = trans_clip
			return

	if _transition_timer > 0.0 and velocity_length_2d < 0.25 and current_anim == _transition_anim:
		return

	# Moving on ground
	if velocity_length_2d > 0.15:
		var target_clip: String = _resolve_directional_clip(input_dir, is_sprinting, is_weapon_ready, is_crouching)
		var base_spd: float = 4.2 if is_sprinting else NATURAL_STRIDE_SPEED
		animation_player.speed_scale = clampf(velocity_length_2d / base_spd, 0.55, 2.0)
		if current_anim != target_clip or not animation_player.is_playing():
			animation_player.play(target_clip, BLEND_TIME)
			current_anim = target_clip
		return

	# Idle on ground
	animation_player.speed_scale = 1.0
	var idle_target: String = idle_anim_name
	if is_crouching and animation_player.has_animation("pistol_kneeling_idle"):
		idle_target = "pistol_kneeling_idle"
	elif is_weapon_ready and animation_player.has_animation("pistol_idle"):
		idle_target = "pistol_idle"
	elif not is_weapon_ready and animation_player.has_animation("unarmed_idle"):
		idle_target = "unarmed_idle"

	if animation_player.has_animation(idle_target):
		if current_anim != idle_target or not animation_player.is_playing():
			animation_player.play(idle_target, BLEND_TIME)
			current_anim = idle_target
	elif current_anim != "":
		animation_player.seek(0.0, true)
		animation_player.pause()
		current_anim = ""

func _resolve_directional_clip(input_dir: Vector2, is_sprinting: bool, is_weapon_ready: bool, is_crouching: bool) -> String:
	if is_crouching and animation_player != null and animation_player.has_animation("crouch_walking"):
		return "crouch_walking"
	if not is_weapon_ready and not is_crouching:
		if is_sprinting and animation_player != null and animation_player.has_animation("unarmed_run"):
			return "unarmed_run"
		return walk_anim_name

	var x: float = input_dir.x
	var y: float = input_dir.y # -1 = Forward (W), +1 = Backward (S)
	var use_run: bool = is_sprinting and not is_crouching

	var candidate: String = "pistol_walk"
	if y < -0.25:
		if x < -0.35:
			candidate = "pistol_run_arc_2" if use_run else "pistol_walk_arc_2"
		elif x > 0.35:
			candidate = "pistol_run_arc" if use_run else "pistol_walk_arc"
		else:
			candidate = "pistol_run" if use_run else "pistol_walk"
	elif y > 0.25:
		if x < -0.35:
			candidate = "pistol_run_backward_arc" if use_run else "pistol_walk_backward_arc"
		elif x > 0.35:
			candidate = "pistol_run_backward_arc_2" if use_run else "pistol_walk_backward_arc_2"
		else:
			candidate = "pistol_run_backward" if use_run else "pistol_walk_backward"
	else:
		if x < -0.2:
			candidate = "pistol_strafe"
		elif x > 0.2:
			candidate = "pistol_strafe_2"
		else:
			candidate = "pistol_run" if use_run else "pistol_walk"

	if animation_player != null and animation_player.has_animation(candidate):
		return candidate
	return walk_anim_name



