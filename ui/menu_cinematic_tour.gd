class_name MenuCinematicTour
extends RefCounted

## Menu Cinematic Tour Sub-Controller — "Dark Towers: The Path of Ka"
## Coordinates the 8-zone "Attract Mode" cinematic tour for the Main Menu,
## transitioning smoothly between iconic wasteland landmarks with atmospheric fades.

var menu: MainMenu = null

const HOLD_DURATION: float = 8.5
const FADE_DURATION: float = 1.3
const TOTAL_CYCLE: float = 11.1

const BASE_FOV: float = 36.0
const DOLLY_FOV_MAX: float = 65.0
const TARGET_WIDTH: float = 45.0
const OMEGA: float = 0.025
const K_R: float = 1.4
const K_H: float = 0.65
const RADIUS_MULTIPLIER: float = 1.9

const VISTAS: Array[Dictionary] = [
	{
		"id": "vista_0_bunker",
		"poi_center": Vector3(-1180.0, 1.8, -1180.0),
		"r_start": 95.0 * RADIUS_MULTIPLIER,
		"h_start": 48.0,
		"theta_0": 3.93,
		"dolly_zoom": false,
		"loc_en": "0 · THE MOHAINE WAY-BUNKER  |  SECTOR: PILGRIMAGE THRESHOLD",
		"loc_es": "0 · REFUGIO MOHAINE  |  SECTOR: UMBRAL DE LA PEREGRINACIÓN",
		"atm_en": "ATMOSPHERE: COPPER TWILIGHT  |  AIRBORNE SILICA: 11.4 mg/m³",
		"atm_es": "ATMÓSFERA: CREPÚSCULO COBRIZO  |  SÍLICE EN SUSPENSIÓN: 11.4 mg/m³",
		"sun_energy": 1.4,
		"sun_color": Color(0.98, 0.52, 0.24),
		"fog_density": 0.012,
		"fog_color": Color(0.56, 0.30, 0.16)
	},
	{
		"id": "vista_1_sw_desolation",
		"poi_center": Vector3(-530.0, 6.0, -840.0),
		"r_start": 110.0 * RADIUS_MULTIPLIER,
		"h_start": 55.0,
		"theta_0": 3.50,
		"dolly_zoom": false,
		"loc_en": "I · SOUTHWEST DESOLATION  |  SECTOR: YARDANG RIDGES",
		"loc_es": "I · DESOLACIÓN DEL SUROESTE  |  SECTOR: CRESTAS DE YARDANG",
		"atm_en": "ATMOSPHERE: GALE DRIFT  |  AIRBORNE SILICA: 28.5 mg/m³",
		"atm_es": "ATMÓSFERA: BORRASCA DE POLVO  |  SÍLICE EN SUSPENSIÓN: 28.5 mg/m³",
		"sun_energy": 0.9,
		"sun_color": Color(0.96, 0.62, 0.32),
		"fog_density": 0.028,
		"fog_color": Color(0.86, 0.54, 0.22)
	},
	{
		"id": "vista_2_south_salt",
		"poi_center": Vector3(-130.0, 3.0, -510.0),
		"r_start": 130.0 * RADIUS_MULTIPLIER,
		"h_start": 60.0,
		"theta_0": 2.80,
		"dolly_zoom": false,
		"loc_en": "II · DEAD-CREEK SALT FLATS  |  SECTOR: BLEACHED PLAYA",
		"loc_es": "II · SALAR DE DEAD-CREEK  |  SECTOR: PLAYA DE ÁLCALI BLANQUEADO",
		"atm_en": "ATMOSPHERE: HIGH GLARE  |  AIRBORNE SILICA: 5.7 mg/m³",
		"atm_es": "ATMÓSFERA: RESPLANDOR CEGADOR  |  SÍLICE EN SUSPENSIÓN: 5.7 mg/m³",
		"sun_energy": 2.8,
		"sun_color": Color(1.0, 0.98, 0.88),
		"fog_density": 0.006,
		"fog_color": Color(0.92, 0.90, 0.84)
	},
	{
		"id": "vista_3_cradle_thinny",
		"poi_center": Vector3(140.0, 10.0, 140.0),
		"r_start": 120.0 * RADIUS_MULTIPLIER,
		"h_start": 65.0,
		"theta_0": 4.20,
		"dolly_zoom": true,
		"loc_en": "III · CALICHE CRADLE  |  SECTOR: THINNY OVERLOOK",
		"loc_es": "III · CUNA DE CALICHE  |  SECTOR: MIRADOR DE LA GRIETA THINNY",
		"atm_en": "ATMOSPHERE: BEAM WARP  |  KA RESONANCE: 432.0 Hz",
		"atm_es": "ATMÓSFERA: DISTORSIÓN DEL HAZ  |  RESONANCIA: 432.0 Hz",
		"sun_energy": 2.0,
		"sun_color": Color(0.85, 0.92, 0.98),
		"fog_density": 0.008,
		"fog_color": Color(0.68, 0.74, 0.82)
	},
	{
		"id": "vista_4_west_gorge",
		"poi_center": Vector3(-650.0, 12.0, 25.0),
		"r_start": 100.0 * RADIUS_MULTIPLIER,
		"h_start": 58.0,
		"theta_0": 1.60,
		"dolly_zoom": false,
		"loc_en": "IV · RUST-GORGE DEFILE  |  SECTOR: COLLAPSED HIGHWAY SPAN",
		"loc_es": "IV · DESFILADERO DE HERRUMBRE  |  SECTOR: VIADUCTO COLAPSADO",
		"atm_en": "ATMOSPHERE: IRON-OXIDE DUST  |  AIRBORNE SILICA: 32.1 mg/m³",
		"atm_es": "ATMÓSFERA: POLVO DE ÓXIDO FÉRREO  |  SÍLICE EN SUSPENSIÓN: 32.1 mg/m³",
		"sun_energy": 1.2,
		"sun_color": Color(0.92, 0.80, 0.68),
		"fog_density": 0.022,
		"fog_color": Color(0.28, 0.22, 0.20)
	},
	{
		"id": "vista_5_north_alkali",
		"poi_center": Vector3(45.0, 8.0, 680.0),
		"r_start": 95.0 * RADIUS_MULTIPLIER,
		"h_start": 52.0,
		"theta_0": 3.14,
		"dolly_zoom": false,
		"loc_en": "V · ALKALI SINK BASIN  |  SECTOR: KA BEACON MONOLITH",
		"loc_es": "V · CUENCA ALCALINA  |  SECTOR: MONOLITO DEL HAZ DE KA",
		"atm_en": "ATMOSPHERE: COPPER TWILIGHT  |  AIRBORNE SILICA: 14.2 mg/m³",
		"atm_es": "ATMÓSFERA: CREPÚSCULO DE COBRE  |  SÍLICE EN SUSPENSIÓN: 14.2 mg/m³",
		"sun_energy": 2.2,
		"sun_color": Color(0.98, 0.96, 0.88),
		"fog_density": 0.015,
		"fog_color": Color(0.88, 0.86, 0.76)
	},
	{
		"id": "vista_6_east_dunes",
		"poi_center": Vector3(680.0, 12.0, -20.0),
		"r_start": 140.0 * RADIUS_MULTIPLIER,
		"h_start": 70.0,
		"theta_0": 0.80,
		"dolly_zoom": false,
		"loc_en": "VI · THE GREAT SHIFTING ERG  |  SECTOR: OLD-ONES RUINS",
		"loc_es": "VI · EL GRAN ERG MÓVIL  |  SECTOR: RUINAS DE LOS ANTIGUOS",
		"atm_en": "ATMOSPHERE: SILICA GALE  |  AIRBORNE SILICA: 39.4 mg/m³",
		"atm_es": "ATMÓSFERA: VENTISCA DE SÍLICE  |  SÍLICE EN SUSPENSIÓN: 39.4 mg/m³",
		"sun_energy": 2.5,
		"sun_color": Color(1.0, 0.95, 0.85),
		"fog_density": 0.010,
		"fog_color": Color(0.75, 0.62, 0.45)
	},
	{
		"id": "vista_7_dark_tower",
		"poi_center": Vector3(700.0, 42.0, 700.0),
		"r_start": 160.0 * RADIUS_MULTIPLIER,
		"h_start": 85.0,
		"theta_0": 3.93,
		"dolly_zoom": true,
		"loc_en": "VII · THE DARK TOWER CITADEL  |  SECTOR: PINNACLE OF KA",
		"loc_es": "VII · CIUDADELA DE LA TORRE OSCURA  |  SECTOR: CÚSPIDE DEL HAZ",
		"atm_en": "ATMOSPHERE: HABOOB TEMPEST  |  AIRBORNE SILICA: 68.0 mg/m³",
		"atm_es": "ATMÓSFERA: TEMPESTAD DE HABOOB  |  SÍLICE EN SUSPENSIÓN: 68.0 mg/m³",
		"sun_energy": 1.8,
		"sun_color": Color(0.95, 0.16, 0.14),
		"fog_density": 0.020,
		"fog_color": Color(0.28, 0.03, 0.04)
	}
]

var active_vista_index: int = 0
var tour_elapsed_time: float = 0.0
var _haboob_emitter: GPUParticles3D = null
var _haboob_veil: MeshInstance3D = null
var _haboob_mat: StandardMaterial3D = null
var _is_tour_active: bool = true
var _manual_pause_timer: float = 0.0

func _init(p_menu: MainMenu = null) -> void:
	menu = p_menu

func setup_tour() -> void:
	if menu == null:
		return
	if menu.preview_camera != null:
		menu.preview_camera.fov = BASE_FOV
	_ensure_haboob_emitter()
	_apply_vista_instant(0)

func _ensure_haboob_emitter() -> void:
	if menu == null or menu.preview_camera == null:
		return
	if menu.crossroads_overlay != null:
		var old_curtain := menu.crossroads_overlay.get_node_or_null("TourFadeCurtain")
		if old_curtain != null:
			old_curtain.queue_free()

	_haboob_emitter = menu.preview_camera.get_node_or_null("HaboobDustWipe") as GPUParticles3D
	if _haboob_emitter == null:
		_haboob_emitter = GPUParticles3D.new()
		_haboob_emitter.name = "HaboobDustWipe"
		_haboob_emitter.transform.origin = Vector3(0.0, 0.0, -0.5)
		_haboob_emitter.amount = 80
		_haboob_emitter.lifetime = 1.2
		_haboob_emitter.explosiveness = 0.85
		_haboob_emitter.emitting = false

		var proc_mat := ParticleProcessMaterial.new()
		proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		proc_mat.emission_box_extents = Vector3(0.5, 0.35, 0.05)
		proc_mat.direction = Vector3(1.0, 0.2, -0.1)
		proc_mat.spread = 50.0
		proc_mat.initial_velocity_min = 1.8
		proc_mat.initial_velocity_max = 3.6
		proc_mat.gravity = Vector3(0.0, -0.15, 0.0)
		proc_mat.scale_min = 1.6
		proc_mat.scale_max = 3.2
		proc_mat.color = Color("#c2b280")
		_haboob_emitter.process_material = proc_mat

		var qmesh := QuadMesh.new()
		qmesh.size = Vector2(2.4, 2.4)
		_haboob_mat = StandardMaterial3D.new()
		_haboob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_haboob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_haboob_mat.albedo_color = Color(0.761, 0.698, 0.502, 0.0)
		_haboob_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_haboob_mat.billboard_keep_scale = true
		_haboob_mat.vertex_color_use_as_albedo = true
		qmesh.material = _haboob_mat
		_haboob_emitter.draw_pass_1 = qmesh

		_haboob_veil = MeshInstance3D.new()
		_haboob_veil.name = "HaboobVeilQuad"
		_haboob_veil.transform.origin = Vector3(0.0, 0.0, 0.02)
		var vmesh := QuadMesh.new()
		vmesh.size = Vector2(3.5, 3.5)
		var vmat := StandardMaterial3D.new()
		vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vmat.albedo_color = Color(0.761, 0.698, 0.502, 0.0)
		_haboob_veil.mesh = vmesh
		_haboob_veil.material_override = vmat
		_haboob_emitter.add_child(_haboob_veil)

		menu.preview_camera.add_child(_haboob_emitter)

func _set_haboob_density(alpha: float, emit: bool) -> void:
	if _haboob_emitter != null:
		_haboob_emitter.emitting = emit
	if _haboob_mat != null:
		_haboob_mat.albedo_color.a = clampf(alpha * 0.95, 0.0, 0.95)
	if _haboob_veil != null and _haboob_veil.material_override != null:
		var vmat := _haboob_veil.material_override as StandardMaterial3D
		if vmat != null:
			vmat.albedo_color.a = clampf(alpha, 0.0, 1.0)

func process_tour(delta: float) -> void:
	if not _is_tour_active or menu == null or menu.preview_camera == null:
		return
	if _manual_pause_timer > 0.0:
		_manual_pause_timer -= delta
		return

	tour_elapsed_time += delta
	var grand_duration: float = TOTAL_CYCLE * VISTAS.size()
	var looped_time: float = fmod(tour_elapsed_time, grand_duration)
	var raw_idx: int = int(looped_time / TOTAL_CYCLE)
	var time_in_vista: float = looped_time - (raw_idx * TOTAL_CYCLE)

	var cur_vista: Dictionary = VISTAS[active_vista_index]

	if time_in_vista < HOLD_DURATION:
		# HOLD vista with clean view (descending spiral / selective dolly zoom)
		_set_haboob_density(0.0, false)
		_apply_camera_drift(cur_vista, time_in_vista)
	else:
		var transition_time: float = time_in_vista - HOLD_DURATION
		if transition_time < 0.9:
			# Surge onset: Haboob dust storm rapidly kicks up
			var t: float = transition_time / 0.9
			var alpha: float = t * t * (3.0 - 2.0 * t)
			_set_haboob_density(alpha, true)
			_apply_camera_drift(cur_vista, HOLD_DURATION + transition_time)
		elif transition_time < 1.3:
			# Peak occlusion window (~0.4s): 100% occluded by howling silica dust
			_set_haboob_density(1.0, true)
			var next_idx: int = (raw_idx + 1) % VISTAS.size()
			if active_vista_index != next_idx:
				active_vista_index = next_idx
				_apply_vista_instant(active_vista_index)
		else:
			# Dispersal: emission ceases, dust clears to reveal new zone
			var next_idx: int = (raw_idx + 1) % VISTAS.size()
			if active_vista_index != next_idx:
				active_vista_index = next_idx
				_apply_vista_instant(active_vista_index)
			var t: float = (transition_time - 1.3) / 1.3
			var alpha: float = 1.0 - (t * t * (3.0 - 2.0 * t))
			_set_haboob_density(maxf(0.0, alpha), false)
			_apply_camera_drift(VISTAS[active_vista_index], transition_time - 1.3)

func _apply_camera_drift(vista: Dictionary, drift_time: float) -> void:
	if menu.preview_camera == null:
		return

	var is_dolly: bool = bool(vista.get("dolly_zoom", false)) or active_vista_index == 3 or active_vista_index == 7
	var h: float = vista["h_start"] - (K_H * drift_time)
	var angle: float = vista["theta_0"] + (OMEGA * drift_time)
	var poi: Vector3 = vista["poi_center"]

	var r: float = vista["r_start"] - (K_R * drift_time)
	var current_fov: float = BASE_FOV

	if is_dolly:
		var progress: float = clampf(drift_time / HOLD_DURATION, 0.0, 1.0)
		current_fov = lerpf(BASE_FOV, DOLLY_FOV_MAX, progress)
		var half_fov_rad: float = deg_to_rad(current_fov) * 0.5
		r = TARGET_WIDTH / (2.0 * tan(half_fov_rad))

	menu.preview_camera.fov = current_fov
	menu.preview_camera.position = Vector3(
		poi.x + r * cos(angle),
		poi.y + h,
		poi.z + r * sin(angle)
	)
	menu.preview_camera.look_at(poi, Vector3.UP)

func _apply_vista_instant(idx: int) -> void:
	active_vista_index = idx
	var vista: Dictionary = VISTAS[idx]
	if menu.preview_camera != null:
		var is_dolly: bool = bool(vista.get("dolly_zoom", false)) or idx == 3 or idx == 7
		var current_fov: float = BASE_FOV
		var r: float = vista["r_start"]
		if is_dolly:
			var half_fov_rad: float = deg_to_rad(current_fov) * 0.5
			r = TARGET_WIDTH / (2.0 * tan(half_fov_rad))
		menu.preview_camera.fov = current_fov
		var h: float = vista["h_start"]
		var angle: float = vista["theta_0"]
		var poi: Vector3 = vista["poi_center"]
		menu.preview_camera.position = Vector3(
			poi.x + r * cos(angle),
			poi.y + h,
			poi.z + r * sin(angle)
		)
		menu.preview_camera.look_at(poi, Vector3.UP)

	# Update environmental atmosphere and lighting
	if menu.twilight_sun != null:
		menu.twilight_sun.light_energy = vista["sun_energy"]
		menu.twilight_sun.light_color = vista["sun_color"]

	var env_node := menu.get_node_or_null("CrossroadsBackdrop/TwilightEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		env_node.environment.fog_density = vista["fog_density"]
		env_node.environment.fog_light_color = vista["fog_color"]

	# Refresh localized headers
	refresh_telemetry_labels()

func refresh_telemetry_labels() -> void:
	if active_vista_index < 0 or active_vista_index >= VISTAS.size():
		return
	var vista: Dictionary = VISTAS[active_vista_index]
	var is_es: bool = menu.get_language() == "es" if menu.has_method("get_language") else false

	if menu.location_tag_label != null:
		menu.location_tag_label.text = vista["loc_es"] if is_es else vista["loc_en"]
	if menu.atmosphere_tag_label != null:
		menu.atmosphere_tag_label.text = vista["atm_es"] if is_es else vista["atm_en"]

func step_vista(direction: int) -> void:
	var next_idx := (active_vista_index + direction + VISTAS.size()) % VISTAS.size()
	tour_elapsed_time = float(next_idx) * TOTAL_CYCLE
	_apply_vista_instant(next_idx)
	_set_haboob_density(0.0, false)
	_manual_pause_timer = 4.0 # Give user 4s pause before resuming auto-tour

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_E or event.keycode == KEY_RIGHT:
			step_vista(1)
			return true
		elif event.keycode == KEY_Q or event.keycode == KEY_LEFT:
			step_vista(-1)
			return true
	return false

