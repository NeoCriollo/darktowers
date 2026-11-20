@tool
class_name WastelandEnvironment
extends WorldEnvironment

## Desolate Wasteland Atmospheric Environment & Lighting Controller (Godot 4 3D)
##
## Establishes the bleak, dusty visual tone for "The Path of Ka" tactical survival setting:
## - Muted neutral gray-brown color palette (desaturated earth, bleached sky, silt horizon)
## - Volumetric and depth fog simulating airborne silica dust
## - Low-angle directional sunlight casting long, dramatic wasteland shadows
## - Filmic tone-mapping with contrast enhancement and desaturation
## - Dynamic weather state machine (Clear Arid, Heat Haze, Dust Devil, Severe Haboob, Cold Desert Night)
## - Smooth runtime transitions between atmospheric states
## - GPUParticles3D wind-particulate system (silica fog, grit streams, haboob wall)
## Preset data dictionaries and static atmospheric tables are in SectorAtmospherePresets.

signal weather_transition_started(from_preset: String, to_preset: String, duration: float)
signal weather_transition_completed(current_preset: String)

enum WeatherPreset {
	CLEAR_ARID,
	HEAT_HAZE,
	DUST_DEVIL,
	SEVERE_HABOOB,
	COLD_DESERT_NIGHT
}

const SECTOR_ATMOSPHERES: Dictionary = SectorAtmospherePresets.SECTOR_ATMOSPHERES

@export_group("Active Atmosphere")
@export var active_preset: WeatherPreset = WeatherPreset.CLEAR_ARID:
	set(value):
		active_preset = value
		if Engine.is_editor_hint() or is_node_ready():
			_apply_current_atmospheric_state()

@export var auto_configure_on_ready: bool = true

@export_group("Palette & Colors (Hopeful Desolation)")
@export var sky_top_color: Color = Color(0.24, 0.28, 0.38, 1.0)
@export var sky_horizon_color: Color = Color(0.88, 0.54, 0.28, 1.0)
@export var ground_bottom_color: Color = Color(0.12, 0.09, 0.08, 1.0)
@export var ground_horizon_color: Color = Color(0.68, 0.42, 0.24, 1.0)
@export var fog_color: Color = Color(0.72, 0.48, 0.32, 1.0)

@export_group("Fog & Atmosphere")
@export_range(0.001, 0.15, 0.001) var fog_density: float = 0.012
@export var enable_volumetric_fog: bool = true
@export_range(0.001, 0.2, 0.001) var volumetric_fog_density: float = 0.020
@export_range(0.0, 1.0, 0.05) var volumetric_anisotropy: float = 0.55

@export_group("Low Sun Directional Light")
@export var sun_node: DirectionalLight3D
@export_range(-89.0, 89.0, 0.5) var sun_pitch_deg: float = -14.0
@export_range(0.0, 360.0, 0.5) var sun_yaw_deg: float = 48.0
@export var sun_color: Color = Color(1.0, 0.78, 0.52, 1.0)
@export_range(0.1, 5.0, 0.05) var sun_energy: float = 1.95
@export var cast_shadows: bool = true

@export_group("Color Grading & Tonemapping")
@export_range(0.0, 2.0, 0.02) var saturation: float = 0.95
@export_range(0.5, 2.0, 0.02) var contrast: float = 1.28

@export_group("Wind & Particulate Particles")
@export var particles_root: Node3D
@export_range(0.0, 180.0, 1.0) var wind_direction_deg: float = 42.0
@export_range(0.0, 1.0, 0.05) var particle_master_scale: float = 1.0

var active_sector_id: String = ""
var sector_override_weight: float = 0.0

var _is_transitioning: bool = false
var _transition_progress: float = 0.0
var _transition_duration: float = 1.0

var _src_sun_color: Color; var _src_sun_energy: float; var _src_fog_color: Color
var _src_fog_density: float; var _src_volumetric_density: float; var _src_sun_pitch: float
var _src_wind_velocity: float; var _src_particle_density: float; var _src_glow_intensity: float; var _src_glow_bloom: float

var _tgt_sun_color: Color; var _tgt_sun_energy: float; var _tgt_fog_color: Color
var _tgt_fog_density: float; var _tgt_volumetric_density: float; var _tgt_sun_pitch: float
var _tgt_wind_velocity: float; var _tgt_particle_density: float; var _tgt_glow_intensity: float; var _tgt_glow_bloom: float

var _cur_wind_velocity: float = 2.0
var _cur_particle_density: float = 0.1

var _particles_drift: GPUParticles3D
var _particles_stream: GPUParticles3D
var _particles_haboob: GPUParticles3D

func _ready() -> void:
	_resolve_particle_nodes()
	if auto_configure_on_ready:
		setup_wasteland_environment()

func _process(delta: float) -> void:
	if _is_transitioning:
		_process_weather_transition(delta)

func _resolve_particle_nodes() -> void:
	if particles_root == null:
		var parent := get_parent()
		if parent: particles_root = parent.get_node_or_null("WastelandParticles") as Node3D
	if particles_root == null: return
	_particles_drift = particles_root.get_node_or_null("SilicaDrift") as GPUParticles3D
	_particles_stream = particles_root.get_node_or_null("GritStream") as GPUParticles3D
	_particles_haboob = particles_root.get_node_or_null("HaboobWall") as GPUParticles3D
	_ensure_particle_draw_passes()

func _ensure_particle_draw_passes() -> void:
	_configure_particle_mesh(_particles_drift, Vector2(0.08, 0.08), Vector3(45.0, 8.0, 45.0), 300)
	_configure_particle_mesh(_particles_stream, Vector2(0.22, 0.06), Vector3(55.0, 10.0, 55.0), 600)
	_configure_particle_mesh(_particles_haboob, Vector2(1.6, 1.2), Vector3(75.0, 22.0, 75.0), 1200)

func _configure_particle_mesh(gp: GPUParticles3D, quad_size: Vector2, box_extents: Vector3, max_capacity: int = 300) -> void:
	if gp == null: return
	if gp.amount != max_capacity: gp.amount = max_capacity
	if gp.draw_pass_1 == null:
		var qm := QuadMesh.new(); qm.size = quad_size
		var p_mat := StandardMaterial3D.new()
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; p_mat.vertex_color_use_as_albedo = true
		p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; p_mat.billboard_keep_scale = true
		p_mat.roughness = 0.95; p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		qm.material = p_mat; gp.draw_pass_1 = qm
	if gp.process_material is ParticleProcessMaterial:
		var ppm := gp.process_material as ParticleProcessMaterial
		ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; ppm.emission_box_extents = box_extents

func setup_wasteland_environment() -> void:
	if environment == null: environment = Environment.new()
	var env: Environment = environment

	env.background_mode = Environment.BG_SKY
	if env.sky == null: env.sky = Sky.new()

	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material if (env.sky.sky_material is ProceduralSkyMaterial) else ProceduralSkyMaterial.new()
	env.sky.sky_material = sky_mat
	sky_mat.sky_top_color = sky_top_color; sky_mat.sky_horizon_color = sky_horizon_color; sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = ground_bottom_color; sky_mat.ground_horizon_color = ground_horizon_color; sky_mat.ground_curve = 0.06
	sky_mat.sun_angle_max = 3.5; sky_mat.sun_curve = 0.22

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.38, 0.42, 0.50); env.ambient_light_sky_contribution = 0.35; env.ambient_light_energy = 0.65

	env.fog_enabled = true; env.fog_light_color = fog_color; env.fog_density = fog_density
	env.fog_aerial_perspective = 0.75; env.fog_sky_affect = 0.45

	env.volumetric_fog_enabled = enable_volumetric_fog
	if enable_volumetric_fog:
		env.volumetric_fog_density = volumetric_fog_density; env.volumetric_fog_albedo = fog_color
		env.volumetric_fog_emission = Color(0.08, 0.04, 0.02); env.volumetric_fog_anisotropy = volumetric_anisotropy
		env.volumetric_fog_length = 85.0; env.volumetric_fog_ambient_inject = 0.15

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 1.18; env.tonemap_white = 1.45
	env.adjustment_enabled = true; env.adjustment_brightness = 1.02; env.adjustment_contrast = contrast; env.adjustment_saturation = saturation

	env.ssao_enabled = true; env.ssao_radius = 1.35; env.ssao_intensity = 2.2; env.ssao_power = 1.8; env.ssao_sharpness = 0.96; env.ssil_enabled = false
	env.ssr_enabled = true; env.ssr_max_steps = 64; env.ssr_fade_in = 0.15; env.ssr_fade_out = 2.0; env.ssr_depth_tolerance = 0.2
	env.sdfgi_enabled = true; env.sdfgi_use_occlusion = true; env.sdfgi_read_sky_light = true; env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_cascades = 4; env.sdfgi_min_cell_size = 0.2; env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT; env.sdfgi_energy = 1.0

	env.glow_enabled = true; env.glow_normalized = false; env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 0.85); env.set_glow_level(2, 0.55); env.set_glow_level(3, 0.35); env.set_glow_level(5, 0.12)

	_setup_directional_sun()
	apply_weather_preset(active_preset)

func _setup_directional_sun() -> void:
	if sun_node == null:
		var parent_node: Node = get_parent()
		if parent_node != null:
			sun_node = parent_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
			if sun_node == null:
				for child in parent_node.get_children():
					if child is DirectionalLight3D:
						sun_node = child as DirectionalLight3D; break

	if sun_node == null and get_parent() != null:
		sun_node = DirectionalLight3D.new(); sun_node.name = "WastelandSun"
		get_parent().add_child(sun_node)
		if Engine.is_editor_hint(): sun_node.owner = get_tree().edited_scene_root

	if sun_node != null:
		sun_node.light_color = sun_color; sun_node.light_energy = sun_energy; sun_node.shadow_enabled = cast_shadows
		sun_node.shadow_bias = 0.05; sun_node.shadow_normal_bias = 1.5; sun_node.shadow_blur = 1.2
		sun_node.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun_node.directional_shadow_blend_splits = true; sun_node.directional_shadow_max_distance = 180.0
		sun_node.directional_shadow_split_1 = 0.07; sun_node.directional_shadow_split_2 = 0.22; sun_node.directional_shadow_split_3 = 0.48
		sun_node.light_volumetric_fog_energy = 1.6
		_orient_sun(sun_pitch_deg, sun_yaw_deg)

func _orient_sun(pitch_deg: float, yaw_deg: float) -> void:
	if sun_node == null: return
	sun_node.rotation = Vector3.ZERO
	sun_node.rotate_y(deg_to_rad(yaw_deg))
	sun_node.rotate_object_local(Vector3.RIGHT, deg_to_rad(pitch_deg))

func set_sector_environment_override(sector_id: String, weight: float = 1.0) -> void:
	active_sector_id = sector_id; sector_override_weight = clampf(weight, 0.0, 1.0)
	_apply_current_atmospheric_state()

func get_sector_environment_config(sector_id: String) -> Dictionary:
	return SectorAtmospherePresets.get_sector_config(sector_id)

func _get_sector_scalar(sector_id: String, key: String, default_val: float, is_penalty: bool = false) -> float:
	var target := sector_id if not sector_id.is_empty() else active_sector_id
	if SECTOR_ATMOSPHERES.has(target):
		var base_val: float = float(SECTOR_ATMOSPHERES[target].get(key, default_val))
		return base_val * sector_override_weight if is_penalty else lerpf(default_val, base_val, sector_override_weight)
	return 0.0 if is_penalty else default_val

func get_sector_silica_multiplier(sector_id: String = "") -> float:
	return _get_sector_scalar(sector_id, "silica_multiplier", 1.0)

func get_sector_glare_penalty(sector_id: String = "") -> float:
	return _get_sector_scalar(sector_id, "glare_visibility_penalty", 0.0, true)

func get_sector_corrosion_multiplier(sector_id: String = "") -> float:
	return _get_sector_scalar(sector_id, "salt_corrosion_rate", 1.0)

func get_sector_thinny_distortion(sector_id: String = "") -> float:
	return _get_sector_scalar(sector_id, "thinny_distortion_rate", 0.0, true)

func get_sector_iron_oxide_multiplier(sector_id: String = "") -> float:
	return _get_sector_scalar(sector_id, "iron_oxide_multiplier", 1.0)

func get_sector_ka_resonance(sector_id: String = "") -> float:
	return _get_sector_scalar(sector_id, "ka_resonance_rate", 0.0, true)

func get_sector_stamina_drain_multiplier(sector_id: String = "") -> float:
	return _get_sector_scalar(sector_id, "stamina_drain_multiplier", 1.0)

func get_sector_tower_nexus_strain(sector_id: String = "") -> float:
	return _get_sector_scalar(sector_id, "tower_nexus_strain_rate", 0.0, true)

func apply_weather_preset(preset: WeatherPreset) -> void:
	active_preset = preset; _apply_current_atmospheric_state()

var is_sunny_day: bool = false
var _saved_env_state: Dictionary = {}

func _apply_current_atmospheric_state() -> void:
	if is_sunny_day: return
	var cfg: Dictionary = _get_preset_config(active_preset)
	var cur_fog_color: Color = cfg["fog_color"]
	var cur_fog_density: float = cfg["fog_density"]
	var cur_vol_density: float = cfg["volumetric_fog_density"]
	var cur_sun_color: Color = cfg["sun_color"]
	var cur_sun_energy: float = cfg["sun_energy"]
	var cur_sun_pitch: float = cfg["sun_pitch_deg"]
	var cur_sky_horizon: Color = cfg["sky_horizon"]
	var cur_ground_horizon: Color = cfg["ground_horizon"]
	var cur_wind_vel: float = cfg["wind_velocity"]
	var cur_part_density: float = cfg["particle_density"]
	var cur_glow_intensity: float = cfg.get("glow_intensity", 0.45)
	var cur_glow_bloom: float = cfg.get("glow_bloom", 0.12)

	if sector_override_weight > 0.001 and SECTOR_ATMOSPHERES.has(active_sector_id):
		var s_cfg: Dictionary = SECTOR_ATMOSPHERES[active_sector_id]
		var w: float = sector_override_weight
		cur_fog_color = cur_fog_color.lerp(s_cfg["fog_color"], w)
		cur_fog_density = lerpf(cur_fog_density, s_cfg["fog_density"], w)
		cur_vol_density = lerpf(cur_vol_density, s_cfg["volumetric_fog_density"], w)
		cur_sun_color = cur_sun_color.lerp(s_cfg["sun_color"], w)
		cur_sun_energy = lerpf(cur_sun_energy, s_cfg["sun_energy"], w)
		cur_sky_horizon = cur_sky_horizon.lerp(s_cfg["sky_horizon"], w)
		cur_ground_horizon = cur_ground_horizon.lerp(s_cfg["ground_horizon"], w)
		if s_cfg.has("sun_pitch_deg"): cur_sun_pitch = lerpf(cur_sun_pitch, s_cfg["sun_pitch_deg"], w)
		if s_cfg.has("glow_intensity"): cur_glow_intensity = lerpf(cur_glow_intensity, s_cfg["glow_intensity"], w)
		if s_cfg.has("glow_bloom"): cur_glow_bloom = lerpf(cur_glow_bloom, s_cfg["glow_bloom"], w)
		var s_wind: float = 6.5 if active_sector_id == "south_salt" else 14.5
		var s_part: float = 0.12 if active_sector_id == "south_salt" else 0.65
		cur_wind_vel = lerpf(cur_wind_vel, s_wind, w); cur_part_density = lerpf(cur_part_density, s_part, w)

	sun_color = cur_sun_color; sun_energy = cur_sun_energy; sun_pitch_deg = cur_sun_pitch
	fog_color = cur_fog_color; fog_density = cur_fog_density; volumetric_fog_density = cur_vol_density

	if sun_node != null:
		sun_node.light_color = sun_color; sun_node.light_energy = sun_energy
		_orient_sun(sun_pitch_deg, sun_yaw_deg)

	if environment != null:
		environment.fog_light_color = fog_color; environment.fog_density = fog_density
		if environment.sky and environment.sky.sky_material is ProceduralSkyMaterial:
			var mat: ProceduralSkyMaterial = environment.sky.sky_material as ProceduralSkyMaterial
			mat.sky_horizon_color = cur_sky_horizon; mat.ground_horizon_color = cur_ground_horizon
		if enable_volumetric_fog:
			environment.volumetric_fog_albedo = fog_color; environment.volumetric_fog_density = volumetric_fog_density
		environment.glow_intensity = cur_glow_intensity; environment.glow_bloom = cur_glow_bloom

	_cur_wind_velocity = cur_wind_vel; _cur_particle_density = cur_part_density
	_apply_particle_state(_cur_wind_velocity, _cur_particle_density, fog_color)

func transition_to_weather(preset: WeatherPreset, duration_seconds: float = 4.0) -> void:
	if active_preset == preset and not _is_transitioning: return
	var old_preset_name: String = WeatherPreset.keys()[active_preset]
	var new_preset_name: String = WeatherPreset.keys()[preset]
	weather_transition_started.emit(old_preset_name, new_preset_name, duration_seconds)

	active_preset = preset
	var cfg: Dictionary = _get_preset_config(preset)

	_src_sun_color = sun_node.light_color if sun_node else sun_color
	_src_sun_energy = sun_node.light_energy if sun_node else sun_energy
	_src_sun_pitch = sun_pitch_deg
	_src_fog_color = environment.fog_light_color if environment else fog_color
	_src_fog_density = environment.fog_density if environment else fog_density
	_src_volumetric_density = environment.volumetric_fog_density if (environment and enable_volumetric_fog) else volumetric_fog_density
	_src_wind_velocity = _cur_wind_velocity; _src_particle_density = _cur_particle_density
	_src_glow_intensity = environment.glow_intensity if environment else 0.4
	_src_glow_bloom = environment.glow_bloom if environment else 0.0

	_tgt_sun_color = cfg["sun_color"]; _tgt_sun_energy = cfg["sun_energy"]; _tgt_sun_pitch = cfg["sun_pitch_deg"]
	_tgt_fog_color = cfg["fog_color"]; _tgt_fog_density = cfg["fog_density"]; _tgt_volumetric_density = cfg["volumetric_fog_density"]
	_tgt_wind_velocity = cfg["wind_velocity"]; _tgt_particle_density = cfg["particle_density"]
	_tgt_glow_intensity = cfg["glow_intensity"]; _tgt_glow_bloom = cfg["glow_bloom"]

	_transition_duration = maxf(0.1, duration_seconds); _transition_progress = 0.0; _is_transitioning = true

func _process_weather_transition(delta: float) -> void:
	_transition_progress += delta / _transition_duration
	var t: float = clampf(_transition_progress, 0.0, 1.0)
	var smooth_t: float = smoothstep(0.0, 1.0, t)

	var cur_sun_color: Color = _src_sun_color.lerp(_tgt_sun_color, smooth_t)
	var cur_sun_energy: float = lerpf(_src_sun_energy, _tgt_sun_energy, smooth_t)
	var cur_sun_pitch: float = lerpf(_src_sun_pitch, _tgt_sun_pitch, smooth_t)
	var cur_fog_color: Color = _src_fog_color.lerp(_tgt_fog_color, smooth_t)
	var cur_fog_density: float = lerpf(_src_fog_density, _tgt_fog_density, smooth_t)
	var cur_vol_density: float = lerpf(_src_volumetric_density, _tgt_volumetric_density, smooth_t)
	_cur_wind_velocity = lerpf(_src_wind_velocity, _tgt_wind_velocity, smooth_t)
	_cur_particle_density = lerpf(_src_particle_density, _tgt_particle_density, smooth_t)

	if sun_node != null:
		sun_node.light_color = cur_sun_color; sun_node.light_energy = cur_sun_energy
		_orient_sun(cur_sun_pitch, sun_yaw_deg)

	if environment != null:
		environment.fog_light_color = cur_fog_color; environment.fog_density = cur_fog_density
		if enable_volumetric_fog:
			environment.volumetric_fog_albedo = cur_fog_color; environment.volumetric_fog_density = cur_vol_density
		environment.glow_intensity = lerpf(_src_glow_intensity, _tgt_glow_intensity, smooth_t)
		environment.glow_bloom = lerpf(_src_glow_bloom, _tgt_glow_bloom, smooth_t)

	_apply_particle_state(_cur_wind_velocity, _cur_particle_density, cur_fog_color)
	if t >= 1.0:
		_is_transitioning = false
		weather_transition_completed.emit(WeatherPreset.keys()[active_preset])

func _apply_particle_state(wind_ms: float, density_n: float, dust_color: Color) -> void:
	if Engine.is_editor_hint(): return
	var wind_rad := deg_to_rad(wind_direction_deg)
	var wind_dir := Vector3(sin(wind_rad), 0.0, cos(wind_rad))
	var scaled_density := density_n * particle_master_scale

	if _particles_drift != null:
		_particles_drift.emitting = density_n > 0.01
		_set_particle_emission(_particles_drift, int(400 * scaled_density), wind_ms * 0.35, wind_dir, dust_color, 0.85)

	if _particles_stream != null:
		_particles_stream.emitting = density_n > 0.08
		_set_particle_emission(_particles_stream, int(900 * scaled_density), wind_ms * 1.2, wind_dir, dust_color, 0.55)

	if _particles_haboob != null:
		var haboob_active := density_n > 0.65
		_particles_haboob.emitting = haboob_active
		if haboob_active:
			_set_particle_emission(_particles_haboob, int(1800 * scaled_density), wind_ms * 2.2, wind_dir, dust_color, 0.40)

func _set_particle_emission(gp: GPUParticles3D, emit_count: int, speed: float, wind_dir: Vector3, color: Color, alpha: float) -> void:
	var max_cap: float = float(max(1, gp.amount))
	gp.amount_ratio = clampf(float(emit_count) / max_cap, 0.02, 1.0)
	var mat: ParticleProcessMaterial = gp.process_material if (gp.process_material is ParticleProcessMaterial) else ParticleProcessMaterial.new()
	gp.process_material = mat
	mat.direction = wind_dir.normalized(); mat.initial_velocity_min = speed * 0.6; mat.initial_velocity_max = speed * 1.4
	mat.spread = lerpf(12.0, 55.0, clamp(speed / 20.0, 0.0, 1.0))
	mat.damping_min = speed * 0.08; mat.damping_max = speed * 0.14
	mat.color = Color(color.r, color.g, color.b, alpha); mat.gravity = Vector3(0.0, -0.4, 0.0)

func get_current_wind_velocity() -> float: return _cur_wind_velocity
func get_current_wind_vector() -> Vector3:
	var wind_rad := deg_to_rad(wind_direction_deg)
	return Vector3(sin(wind_rad), 0.0, cos(wind_rad)) * _cur_wind_velocity
func get_current_particle_density() -> float: return _cur_particle_density
func _get_preset_config(preset: WeatherPreset) -> Dictionary:
	return SectorAtmospherePresets.get_preset_config(int(preset))

func set_sunny_day_override(enabled: bool) -> void:
	is_sunny_day = enabled
	if is_sunny_day:
		_saved_env_state = {
			"sun_energy": sun_energy,
			"sun_color": sun_color,
			"sun_pitch": sun_pitch_deg,
			"fog_enabled": environment.fog_enabled if environment else true,
			"vol_fog_enabled": environment.volumetric_fog_enabled if environment else true,
			"ambient_color": environment.ambient_light_color if environment else Color(0.38, 0.42, 0.50),
			"ambient_energy": environment.ambient_light_energy if environment else 0.65,
			"ambient_source": environment.ambient_light_source if environment else Environment.AMBIENT_SOURCE_SKY,
			"cast_shadows": sun_node.shadow_enabled if sun_node else true
		}
		if sun_node != null:
			sun_node.light_energy = 3.5
			sun_node.light_color = Color(1.0, 0.98, 0.95)
			sun_node.shadow_enabled = false
			_orient_sun(55.0, 45.0)
		if environment != null:
			environment.fog_enabled = false
			environment.volumetric_fog_enabled = false
			environment.ambient_light_color = Color(1.0, 1.0, 1.0)
			environment.ambient_light_energy = 1.2
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_apply_particle_state(0.0, 0.0, Color.WHITE)
	else:
		if not _saved_env_state.is_empty():
			if sun_node != null:
				sun_node.light_energy = _saved_env_state.get("sun_energy", 1.95)
				sun_node.light_color = _saved_env_state.get("sun_color", Color(1.0, 0.78, 0.52))
				sun_node.shadow_enabled = _saved_env_state.get("cast_shadows", true)
				_orient_sun(_saved_env_state.get("sun_pitch", -14.0), sun_yaw_deg)
			if environment != null:
				environment.fog_enabled = _saved_env_state.get("fog_enabled", true)
				environment.volumetric_fog_enabled = _saved_env_state.get("vol_fog_enabled", true)
				environment.ambient_light_color = _saved_env_state.get("ambient_color", Color(0.38, 0.42, 0.50))
				environment.ambient_light_energy = _saved_env_state.get("ambient_energy", 0.65)
				environment.ambient_light_source = _saved_env_state.get("ambient_source", Environment.AMBIENT_SOURCE_SKY)
		_apply_current_atmospheric_state()

func toggle_sunny_day_override() -> bool:
	set_sunny_day_override(not is_sunny_day)
	return is_sunny_day
