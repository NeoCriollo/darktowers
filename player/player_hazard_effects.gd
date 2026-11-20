class_name PlayerHazardEffects
extends RefCounted

const SupplyCrate3D = preload("res://world/supply_crate.gd")

## PlayerHazardEffects — Environmental Strain, Biome Hazards & Procedural Respiration
##
## Decoupled domain helper for PlayerCharacter managing:
## - Environmental biome hazard reactions (thinny distortion, glare penalty, Ka resonance, nexus strain)
## - Metabolic slope-dependent stamina drain modifiers
## - Combat damage severity, direction telemetry and localized pain audio cues
## - Procedural 16-bit PCM pain and death-rattle audio synthesis and playback
## - Checkpoint state, safe respawn targets, natural health regeneration and crate interactions

var anomaly_sway_intensity: float = 0.0
var glare_visibility_penalty: float = 0.0
var ka_resonance_intensity: float = 0.0
var loose_sand_stamina_drain_multiplier: float = 1.0
var tower_nexus_strain: float = 0.0

var pain_audio: AudioStreamPlayer3D = null
var pain_stream: AudioStreamWAV = null
var death_stream: AudioStreamWAV = null

var last_checkpoint_position: Vector3 = Vector3.ZERO
var last_checkpoint_name: String = "The Mohaine Way-Bunker"
var has_checkpoint: bool = false

# =============================================================================
# --- BIOME HAZARD & STRAIN API ---
# =============================================================================

func apply_anomaly_sway(intensity: float) -> void:
	anomaly_sway_intensity = clampf(intensity, 0.0, 1.0)

func apply_thinny_distortion(intensity: float) -> void:
	apply_anomaly_sway(intensity)

func get_thinny_distortion() -> float:
	return anomaly_sway_intensity

func apply_glare_penalty(penalty: float) -> void:
	glare_visibility_penalty = clampf(penalty, 0.0, 1.0)

func get_glare_penalty() -> float:
	return glare_visibility_penalty

func apply_ka_resonance(intensity: float) -> void:
	ka_resonance_intensity = clampf(intensity, 0.0, 1.0)

func get_ka_resonance() -> float:
	return ka_resonance_intensity

func apply_stamina_drain_multiplier(multiplier: float) -> void:
	loose_sand_stamina_drain_multiplier = maxf(0.5, multiplier)

func get_stamina_drain_multiplier() -> float:
	return loose_sand_stamina_drain_multiplier

func apply_tower_nexus_strain(strain: float) -> void:
	tower_nexus_strain = clampf(strain, 0.0, 1.0)
	apply_anomaly_sway(maxf(anomaly_sway_intensity, tower_nexus_strain * 0.75))

func get_tower_nexus_strain() -> float:
	return tower_nexus_strain

# =============================================================================
# --- TERRAIN LOCOMOTION METABOLICS ---
# =============================================================================

func calculate_slope_metabolics(floor_normal: Vector3, move_direction: Vector3) -> Dictionary:
	var slope_cost_mult: float = 1.0
	if floor_normal.y < 0.92:
		if move_direction.dot(Vector3(floor_normal.x, 0.0, floor_normal.z)) < -0.2:
			slope_cost_mult = 1.65
	var speed_divisor: float = 1.0 + (slope_cost_mult - 1.0) * 0.35
	return {
		"slope_cost_mult": slope_cost_mult,
		"speed_divisor": speed_divisor,
		"effective_drain_multiplier": slope_cost_mult * loose_sand_stamina_drain_multiplier
	}

# =============================================================================
# --- COMBAT TELEMETRY & HEALTH REGEN ---
# =============================================================================

func resolve_hit_direction_key(attacker_position: Vector3, victim_global_pos: Vector3, basis_node: Node3D) -> String:
	if attacker_position == Vector3.ZERO or basis_node == null or not basis_node.is_inside_tree():
		return "DIR_UNKNOWN"
	var to_attacker := Vector3(attacker_position.x - victim_global_pos.x, 0.0, attacker_position.z - victim_global_pos.z)
	if to_attacker.length_squared() < 0.0001: return "DIR_FRONT"
	var fwd: Vector3 = -basis_node.global_transform.basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z)
	if fwd.length_squared() < 0.0001: fwd = Vector3.FORWARD
	var angle: float = fwd.normalized().signed_angle_to(to_attacker.normalized(), Vector3.UP)
	var deg: float = rad_to_deg(angle)
	if absf(deg) <= 45.0: return "DIR_FRONT"
	elif absf(deg) >= 135.0: return "DIR_REAR"
	elif deg > 0.0: return "DIR_LEFT"
	return "DIR_RIGHT"

func process_health_regen(delta: float, cur_hp: float, max_hp: float, time_since_dmg: float, delay: float, rate: float, cap_ratio: float) -> float:
	if time_since_dmg < delay or rate <= 0.0: return cur_hp
	var cap: float = max_hp * cap_ratio
	if cur_hp >= cap: return cur_hp
	return minf(cap, cur_hp + rate * delta)

# =============================================================================
# --- SAFE CHECKPOINT & RESPAWN RESOLUTION ---
# =============================================================================

func register_checkpoint(world_position: Vector3, region_name: String = "") -> void:
	last_checkpoint_position = world_position
	if not region_name.is_empty(): last_checkpoint_name = region_name
	has_checkpoint = true

func get_last_checkpoint() -> Dictionary:
	return {"position": last_checkpoint_position, "name": last_checkpoint_name}

func resolve_initial_checkpoint(current_pos: Vector3) -> Dictionary:
	var p_xz := Vector2(current_pos.x, current_pos.z)
	if p_xz.length_squared() < 400.0 or p_xz.distance_to(Vector2(-230.0, -230.0)) < 5.0:
		var gy: float = TerrainCollisionGenerator.sample_height(-1020.0, -820.0)
		return {"position": Vector3(-1020.0, gy + 0.05, -820.0), "name": "The Mohaine Way-Bunker"}
	return {"position": current_pos, "name": "Wasteland Waypoint"}

func resolve_respawn_target(death_pos: Vector3, provider: Callable) -> Dictionary:
	if provider.is_valid():
		var result: Variant = provider.call(death_pos)
		if result is Dictionary and (result as Dictionary).has("position"):
			return result
	return {"position": last_checkpoint_position, "name": last_checkpoint_name}

# =============================================================================
# --- CRATE PROXIMITY INTERACTION ---
# =============================================================================

func check_crate_interaction(player: CharacterBody3D) -> void:
	if player == null or not player.is_inside_tree(): return
	var loot_mgr = player.get_tree().root.find_child("LootCrateManager", true, false)
	if loot_mgr == null: return
	for child in loot_mgr.get_children():
		if child is SupplyCrate3D:
			var crate := child as SupplyCrate3D
			if crate.current_state == SupplyCrate3D.CrateState.READY and player.global_position.distance_to(crate.global_position) <= crate.interaction_radius:
				var payload := crate.interact_open(player)
				var raw_tier: String = payload.get("tier_name", "")
				var tier_label: String = Localization.t(raw_tier, raw_tier) if not raw_tier.is_empty() else Localization.t("LOOT_SUPPLY_CACHE")
				var notif_text: String = Localization.t("HAZARD_LOOT_NOTIFICATION") % [tier_label, payload.get("ammo_45lc", 0), payload.get("scrap", 0)]
				var ui := player.get_tree().root.find_child("UI", true, false)
				if ui != null and ui.has_method("notify_region_change"):
					ui.call("notify_region_change", notif_text)
				break

# =============================================================================
# --- PROCEDURAL PAIN & RESPIRATION AUDIO ---
# =============================================================================

func setup_pain_audio(host: Node3D) -> void:
	if host == null: return
	pain_audio = host.get_node_or_null("PainRespirationAudio") as AudioStreamPlayer3D
	if pain_audio == null:
		pain_audio = AudioStreamPlayer3D.new()
		pain_audio.name = "PainRespirationAudio"
		pain_audio.position = Vector3(0.0, 1.6, 0.0)
		pain_audio.unit_size = 6.0
		pain_audio.max_distance = 30.0
		host.add_child(pain_audio)
	if pain_stream == null: pain_stream = _build_respiration_stream(0.55, false)
	if death_stream == null: death_stream = _build_respiration_stream(2.2, true)

func _build_respiration_stream(duration: float, is_death: bool) -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(duration * float(rate))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4B41 + (7 if is_death else 0)
	var noise_lp: float = 0.0
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(rate)
		var norm_t: float = t / duration
		var env: float = minf(1.0, t / 0.03) * exp(-norm_t * (2.2 if is_death else 4.5))
		if is_death: env *= 0.55 + 0.45 * sin(TAU * lerpf(2.0, 0.7, norm_t) * t)
		noise_lp += 0.16 * (rng.randf_range(-1.0, 1.0) - noise_lp)
		var f0: float = lerpf(185.0, 105.0, norm_t) if not is_death else lerpf(130.0, 70.0, norm_t)
		phase += TAU * f0 / float(rate)
		var tone: float = sin(phase) * 0.6 + sin(phase * 2.0) * 0.25 + sin(phase * 3.0) * 0.1
		var tone_amt: float = (0.55 * exp(-norm_t * 6.0)) if not is_death else (0.3 * exp(-norm_t * 3.0))
		var s: float = clampf((noise_lp * 1.4 + tone * tone_amt) * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func play_pain_cue(is_death: bool, intensity: float, injury_ratio: float) -> void:
	if pain_audio == null or not pain_audio.is_inside_tree(): return
	pain_audio.stream = death_stream if is_death else pain_stream
	pain_audio.pitch_scale = randf_range(0.92, 1.06) * (1.0 + injury_ratio * 0.08) if not is_death else 0.9
	pain_audio.volume_db = lerpf(-8.0, 0.0, clampf(intensity * 2.0, 0.0, 1.0))
	pain_audio.play()
