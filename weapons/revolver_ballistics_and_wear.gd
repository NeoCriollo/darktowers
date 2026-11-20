class_name RevolverBallisticsAndWear
extends RefCounted

## RevolverBallisticsAndWear — Ballistic Raymarching, Friction Degrade & Maintenance
##
## Decoupled domain helper for WeaponSystem managing:
## - Stepped Euler-Cromer external ballistics with G1 aerodynamic drag & wind drift
## - Internal bore friction calculations and degraded muzzle velocity derivation
## - Contamination accumulation (grit, soot fouling, salt-crust corrosion, and lubrication decay)
## - Logistic jam probability curve and malfunction state determination
## - Manual jam clearing routines (Tap-rack / rod casing extraction)
## - Multi-step field maintenance (bore patch swab, brass brush scraping, mineral oil lubrication)
## - Diegetic visual effects (tracer line-mesh, impact dust/sparks puff, spent brass ejection)
## - Zero-floating-numbers diegetic physical weapon inspection report

# =============================================================================
# --- BALLISTICS & FRICTION MATH ---
# =============================================================================

## Composite degradation metric D in [0.0, 1.0]
static func get_composite_degradation(grit: float, fouling: float, corrosion: float, lubrication: float) -> float:
	var raw_degradation: float = (
		0.55 * grit +
		0.35 * fouling +
		0.10 * corrosion -
		0.15 * lubrication
	)
	return clampf(raw_degradation, 0.0, 1.0)

## Internal ballistics: Barrel friction calculates degraded muzzle velocity.
static func compute_actual_muzzle_velocity(base_velocity: float, grit: float, fouling: float, corrosion: float) -> float:
	var friction_penalty: float = 0.38 * grit + 0.22 * fouling + 0.30 * corrosion
	var friction_ratio: float = sqrt(maxf(0.15, 1.0 - friction_penalty))
	return base_velocity * friction_ratio

## Jam probability modeled via logistic curve centered around threshold
static func compute_jam_probability(d: float, threshold: float, steepness: float) -> float:
	return 1.0 / (1.0 + exp(-steepness * (d - threshold)))

## Aerodynamic drag acceleration vector
static func compute_drag_acceleration(
	vel: Vector3, wind_vel: Vector3, bullet_diameter_m: float,
	air_density: float, drag_coeff_g1: float, bullet_mass_kg: float
) -> Vector3:
	var rel_vel: Vector3 = vel - wind_vel
	var speed: float = rel_vel.length()
	if speed < 0.001: return Vector3.ZERO
	var cross_area: float = PI * pow(bullet_diameter_m * 0.5, 2.0)
	var drag_force: float = 0.5 * air_density * drag_coeff_g1 * cross_area * (speed * speed)
	var drag_accel_mag: float = drag_force / maxf(0.001, bullet_mass_kg)
	return -rel_vel.normalized() * drag_accel_mag

## Determines which malfunction occurred based on predominant contaminant
static func determine_jam_type(grit: float, fouling: float) -> int:
	if grit > 0.6: return 5 # JAMMED_FAILURE_TO_EXTRACT
	elif fouling > 0.5: return 3 # JAMMED_STOVEPIPE
	return 4 # JAMMED_FAILURE_TO_FEED

# =============================================================================
# --- MAINTENANCE & CONTAMINATION WEAR ---
# =============================================================================

static func clean_bore(fouling: float, grit: float, lub: float, patch_q: float, solvent_q: float) -> Dictionary:
	var power: float = patch_q * 0.45 + solvent_q * 0.55
	var foul_removed: float = minf(fouling, fouling * power * 0.85 + 0.15)
	var grit_removed: float = minf(grit, grit * power * 0.35)
	return {
		"fouling_removed": foul_removed,
		"grit_removed": grit_removed,
		"new_fouling": maxf(0.0, fouling - foul_removed),
		"new_grit": maxf(0.0, grit - grit_removed),
		"new_lubrication": maxf(0.05, lub - 0.25)
	}

static func brush_action_and_rails(grit: float, brush_q: float) -> Dictionary:
	var grit_removed: float = minf(grit, grit * brush_q * 0.75 + 0.10)
	return {
		"grit_removed": grit_removed,
		"new_grit": maxf(0.0, grit - grit_removed)
	}

static func lubricate(lub: float, corrosion: float, oil_q: float) -> Dictionary:
	return {
		"new_lubrication": clampf(lub + oil_q * 0.8, 0.0, 1.0),
		"new_corrosion": maxf(0.0, corrosion - oil_q * 0.15)
	}

static func field_clean(grit: float, fouling: float, corrosion: float, lub: float, solvent_amt: float) -> Dictionary:
	var grit_cleaned: float = grit * minf(1.0, 0.65 + solvent_amt * 0.35)
	var fouling_cleaned: float = fouling * minf(1.0, 0.50 + solvent_amt * 0.40)
	var new_grit: float = maxf(0.0, grit - grit_cleaned)
	var new_fouling: float = maxf(0.0, fouling - fouling_cleaned)
	var new_corrosion: float = maxf(0.0, corrosion - solvent_amt * 0.15)
	var new_lub: float = clampf(lub + solvent_amt * 0.4, 0.0, 1.0)
	return {
		"grit_removed": grit_cleaned,
		"fouling_removed": fouling_cleaned,
		"remaining_grit": new_grit,
		"remaining_fouling": new_fouling,
		"current_lubrication": new_lub,
		"current_corrosion": new_corrosion
	}

static func calculate_ambient_grit(grit: float, lub: float, delta_s: float, density: float, is_holstered: bool, prot: float) -> Dictionary:
	var factor: float = prot if is_holstered else 0.0
	var added_grit: float = (1.0 - factor) * (density / 100.0) * delta_s * 0.008
	return {
		"new_grit": minf(1.0, grit + added_grit),
		"new_lubrication": maxf(0.0, lub - added_grit * 0.4) if added_grit > 0.0 else lub
	}

static func calculate_salt_corrosion(corrosion: float, lub: float, delta_s: float, mult: float, is_holstered: bool, prot: float) -> Dictionary:
	var factor: float = prot if is_holstered else 0.0
	var added: float = (1.0 - factor) * delta_s * 0.005 * mult
	return {
		"new_corrosion": minf(1.0, corrosion + added),
		"new_lubrication": maxf(0.0, lub - added * 0.8) if added > 0.0 else lub
	}

static func calculate_ground_contact_foul(grit: float, lub: float, severity: float, is_holstered: bool, prot: float) -> Dictionary:
	var factor: float = prot if is_holstered else 0.0
	var added: float = severity * (1.0 - factor)
	return {
		"new_grit": minf(1.0, grit + added),
		"new_lubrication": maxf(0.0, lub - added * 0.5)
	}

# =============================================================================
# --- BALLISTIC RAYMARCHING & IMPACT DETECTION ---
# =============================================================================

static func perform_ballistic_raycast(host: Node3D, config: Dictionary) -> Dictionary:
	var launch_speed: float = float(config.get("muzzle_velocity", 260.0))
	var hit: Dictionary = {
		"impact_velocity_mps": launch_speed,
		"distance_m": 0.0,
		"flight_time_s": 0.0,
		"gravity_drop_m": 0.0,
		"wind_drift_m": 0.0,
		"material_type": "NONE"
	}
	var aim_ray: RayCast3D = config.get("aim_raycast")
	var eff_range: float = float(config.get("effective_range_meters", 85.0))
	if aim_ray != null and aim_ray.is_inside_tree():
		aim_ray.target_position = Vector3(0.0, 0.0, -eff_range)
		aim_ray.force_raycast_update()

	if host == null or not host.is_inside_tree() or host.get_world_3d() == null:
		return hit

	var mp: Marker3D = config.get("muzzle_point")
	var origin: Vector3 = mp.global_position if (mp != null and mp.is_inside_tree()) else host.global_position
	var forward: Vector3 = resolve_aim_direction(host, origin, eff_range, config.get("excluded_rids", []))
	var space_state := host.get_world_3d().direct_space_state
	if space_state == null: return hit

	var dt: float = 1.0 / 120.0
	var pos: Vector3 = origin
	var vel: Vector3 = forward * launch_speed
	var time_alive: float = 0.0; var total_dist: float = 0.0
	var max_dist: float = maxf(eff_range * 1.6, 140.0)
	var grav_vec := Vector3(0.0, -float(config.get("ballistic_gravity", 9.80665)), 0.0)
	var wind_vec: Vector3 = config.get("ambient_wind_vector", Vector3.ZERO)
	var excluded: Array[RID] = config.get("excluded_rids", [])

	for _step in range(180):
		var drag_accel: Vector3 = compute_drag_acceleration(
			vel, wind_vec, float(config.get("bullet_diameter_m", 0.01148)),
			float(config.get("desert_air_density", 1.085)), float(config.get("drag_coefficient_g1", 0.19)), float(config.get("bullet_mass_kg", 0.0162))
		)
		vel += (grav_vec + drag_accel) * dt
		var next_pos: Vector3 = pos + vel * dt
		var step_len: float = pos.distance_to(next_pos)
		var query := PhysicsRayQueryParameters3D.create(pos, next_pos)
		query.collide_with_areas = false; query.collide_with_bodies = true; query.exclude = excluded
		var raw_hit := space_state.intersect_ray(query)
		if not raw_hit.is_empty():
			var hit_pos: Vector3 = raw_hit.get("position", next_pos)
			var hit_norm: Vector3 = raw_hit.get("normal", Vector3.UP)
			var collider: Object = raw_hit.get("collider")
			total_dist += pos.distance_to(hit_pos)
			time_alive += dt * (pos.distance_to(hit_pos) / maxf(0.0001, step_len))
			var displacement := hit_pos - (origin + forward * total_dist)
			var mat_type := classify_hit_material(collider)
			hit["collider"] = collider; hit["position"] = hit_pos; hit["normal"] = hit_norm
			hit["distance_m"] = total_dist; hit["flight_time_s"] = time_alive
			hit["impact_velocity_mps"] = vel.length()
			hit["gravity_drop_m"] = maxf(0.0, -displacement.y)
			hit["wind_drift_m"] = Vector2(displacement.x, displacement.z).length()
			hit["material_type"] = mat_type
			spawn_ballistic_tracer(host, origin, hit_pos)
			spawn_impact_effect(host, hit_pos, hit_norm, mat_type, vel.normalized(), collider)
			return hit
		pos = next_pos; total_dist += step_len; time_alive += dt
		if total_dist >= max_dist: break

	if aim_ray != null and aim_ray.is_inside_tree() and aim_ray.is_colliding():
		var rc_collider := aim_ray.get_collider()
		if rc_collider != null:
			var rc_pos := aim_ray.get_collision_point(); var rc_norm := aim_ray.get_collision_normal()
			var rc_dist := origin.distance_to(rc_pos); var rc_mat := classify_hit_material(rc_collider)
			hit["collider"] = rc_collider; hit["position"] = rc_pos; hit["normal"] = rc_norm
			hit["distance_m"] = rc_dist; hit["flight_time_s"] = rc_dist / maxf(1.0, launch_speed)
			hit["impact_velocity_mps"] = launch_speed; hit["material_type"] = rc_mat
			spawn_ballistic_tracer(host, origin, rc_pos)
			spawn_impact_effect(host, rc_pos, rc_norm, rc_mat, forward, rc_collider)
			return hit

	spawn_ballistic_tracer(host, origin, pos)
	return hit

static func resolve_aim_direction(host: Node3D, origin: Vector3, range_m: float, excluded: Array[RID]) -> Vector3:
	var vp := host.get_viewport()
	if vp != null:
		var cam := vp.get_camera_3d()
		if cam != null and cam.is_inside_tree():
			var cam_origin: Vector3 = cam.global_position
			var cam_fwd: Vector3 = -cam.global_transform.basis.z.normalized()
			var focal: Vector3 = cam_origin + cam_fwd * range_m
			var space_state := host.get_world_3d().direct_space_state
			if space_state != null:
				var q := PhysicsRayQueryParameters3D.create(cam_origin, focal)
				q.exclude = excluded
				var cam_hit := space_state.intersect_ray(q)
				if not cam_hit.is_empty():
					var p: Vector3 = cam_hit.get("position", focal)
					if p.distance_to(origin) > 1.2: focal = p
			return (focal - origin).normalized()
	return -host.global_transform.basis.z.normalized()

static func classify_hit_material(collider: Object) -> String:
	if collider == null: return "SAND"
	if collider is Node:
		var n := collider as Node
		if n.has_meta("ballistic_material"): return String(n.get_meta("ballistic_material"))
		var p := n.get_parent()
		if p != null and p.has_meta("ballistic_material"): return String(p.get_meta("ballistic_material"))
		var combined := (String(n.name) + "_" + (String(p.name) if p else "")).to_upper()
		if "TANK" in combined or "PIPE" in combined or "VEHICLE" in combined or "BARREL" in combined or "GONG" in combined or "BUNKER" in combined:
			return "STEEL"
		elif "CRATE" in combined or "WAGON" in combined: return "WOOD"
		elif "PILLAR" in combined or "SLAB" in combined or "OBELISK" in combined: return "CONCRETE"
		elif "SKELETON" in combined: return "BONE"
	return "SAND"

# =============================================================================
# --- DIEGETIC FX & CASING SPAWNING ---
# =============================================================================

static func spawn_ballistic_tracer(host: Node3D, from_pos: Vector3, to_pos: Vector3) -> void:
	if host == null or not host.is_inside_tree() or host.get_tree() == null or host.get_tree().current_scene == null: return
	var dist := from_pos.distance_to(to_pos)
	if dist < 0.5: return
	var tracer := MeshInstance3D.new(); tracer.name = "BallisticTracer"
	var cyl := CylinderMesh.new(); cyl.top_radius = 0.008; cyl.bottom_radius = 0.014; cyl.height = minf(dist, 18.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.78, 0.35, 0.75); cyl.material = mat
	tracer.mesh = cyl; tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.get_tree().current_scene.add_child(tracer)
	tracer.global_position = from_pos.lerp(to_pos, 0.65)
	tracer.look_at(to_pos, Vector3.UP); tracer.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := tracer.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14); tw.tween_callback(tracer.queue_free)

static func spawn_impact_effect(host: Node3D, hit_pos: Vector3, hit_norm: Vector3, mat_type: String, shot_dir: Vector3, collider: Object) -> void:
	if host == null or not host.is_inside_tree() or host.get_tree() == null or host.get_tree().current_scene == null: return
	var fx_root := Node3D.new(); fx_root.name = "BallisticImpactFX"
	host.get_tree().current_scene.add_child(fx_root)
	fx_root.global_position = hit_pos + hit_norm * 0.03

	if collider is Node:
		var target := (collider as Node).get_parent() as Node3D
		if target != null and (target.has_meta("reactive_target") or mat_type in ["STEEL", "WOOD", "BONE"]):
			var orig_rot := target.rotation; var jtw := target.create_tween()
			jtw.tween_property(target, "rotation", orig_rot + Vector3(shot_dir.z * 0.08, 0.0, -shot_dir.x * 0.08), 0.04)
			jtw.tween_property(target, "rotation", orig_rot, 0.18).set_trans(Tween.TRANS_ELASTIC)

	var is_steel := (mat_type == "STEEL")
	var puff_color := Color(1.0, 0.65, 0.18, 0.95) if is_steel else (
		Color(0.55, 0.42, 0.26, 0.80) if mat_type == "WOOD" else Color(0.72, 0.62, 0.48, 0.75)
	)
	var puff := MeshInstance3D.new(); var sm := SphereMesh.new()
	sm.radius = 0.14 if is_steel else 0.24; sm.height = sm.radius * 2.0
	var p_mat := StandardMaterial3D.new(); p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; p_mat.albedo_color = puff_color
	if is_steel:
		p_mat.emission_enabled = true; p_mat.emission = Color(1.0, 0.55, 0.12); p_mat.emission_energy_multiplier = 6.0
	sm.material = p_mat; puff.mesh = sm; puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(puff)
	var tw := fx_root.create_tween(); tw.set_parallel(true)
	tw.tween_property(puff, "scale", Vector3.ONE * (2.2 if is_steel else 3.2), 0.28)
	tw.tween_property(p_mat, "albedo_color:a", 0.0, 0.28); tw.chain().tween_callback(fx_root.queue_free)

static func spawn_spent_brass_casing(host: Node3D) -> void:
	if host == null or not host.is_inside_tree() or host.get_tree() == null or host.get_tree().current_scene == null: return
	var casing := MeshInstance3D.new(); casing.name = "SpentBrassCasing"
	var cm := CylinderMesh.new(); cm.top_radius = 0.006; cm.bottom_radius = 0.006; cm.height = 0.032
	var b_mat := StandardMaterial3D.new(); b_mat.albedo_color = Color(0.76, 0.58, 0.22); b_mat.metallic = 0.85; b_mat.roughness = 0.35
	cm.material = b_mat; casing.mesh = cm
	host.get_tree().current_scene.add_child(casing)
	casing.global_position = host.global_position + host.global_transform.basis.x * 0.12
	var drop_pos := casing.global_position + host.global_transform.basis.x * randf_range(0.35, 0.65) + Vector3(0.0, -1.1, 0.0)
	var tw := casing.create_tween(); tw.set_parallel(true)
	tw.tween_property(casing, "global_position", drop_pos, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(casing, "rotation", Vector3(randf() * TAU, randf() * TAU, randf() * TAU), 0.38)
	tw.chain().tween_interval(12.0); tw.tween_callback(casing.queue_free)

# =============================================================================
# --- DIEGETIC INSPECTION ---
# =============================================================================

static func build_inspection_report(
	w_name: String, grit: float, fouling: float, corrosion: float, lub: float,
	is_jammed: bool, is_loaded: bool, is_holstered: bool, cur_rounds: int, cap: int,
	hammer_cocked: bool, hammer_half: bool, base_vel: float, threshold: float, steepness: float
) -> Dictionary:
	var action_feel: String; var severity: String = "PRISTINE"
	if is_jammed: action_feel = "Seized tight. An obstructed casing is wedged against the frame."; severity = "SEIZED"
	elif grit > 0.7: action_feel = "Grinding heavily with coarse silica sand in the cylinder ratchet."; severity = "SEIZED"
	elif grit > 0.35: action_feel = "Noticeable friction and gravelly drag when cycling."; severity = "GRATING"
	elif grit > 0.10: action_feel = "Faint gritty vibration through the steel frame."; severity = "FAINT"
	else: action_feel = "Smooth and positive mechanical engagement."; severity = "PRISTINE"

	var bore: String
	if fouling > 0.7: bore = "Choked with thick black powder soot and lead residue."
	elif fouling > 0.3: bore = "Dull finish with visible carbon rings around the lands."
	else: bore = "Bright rifling lands with clean metallic sheen."

	var surface: String
	if corrosion > 0.4: surface = "Heavy reddish rust scale bites into the receiver walls."
	elif corrosion > 0.1: surface = "Fine orange freckling has begun to pit the cylinder frame."
	elif lub > 0.4: surface = "Deep blued steel protected by a thin film of mineral gun oil."
	else: surface = "Blued steel is dry and matte to the touch."

	var total_loaded: int = cur_rounds + (1 if is_loaded else 0)
	var cyl_report := "%d of %d chambers loaded." % [total_loaded, cap]
	var ham_report := "Hammer is cocked and under spring tension." if hammer_cocked else (
		"Hammer is caught on half-cock safety notch." if hammer_half else "Hammer is resting forward."
	)
	var deg := get_composite_degradation(grit, fouling, corrosion, lub)
	return {
		"weapon_name": w_name, "action_feel": action_feel, "bore_condition": bore,
		"surface_finish": surface, "cylinder_report": cyl_report, "hammer_report": ham_report,
		"tactile_severity": severity, "muzzle_velocity_mps": compute_actual_muzzle_velocity(base_vel, grit, fouling, corrosion),
		"jam_risk_pct": compute_jam_probability(deg, threshold, steepness) * 100.0,
		"is_loaded": is_loaded, "is_jammed": is_jammed, "is_holstered": is_holstered
	}

