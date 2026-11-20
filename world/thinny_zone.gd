class_name ThinnyZone
extends Area3D

## Stephen King "Thinny" Spatial Anomaly Zone — "Dark Towers: The Path of Ka"
##
## An eerie dimensional tear where the fabric of reality has worn translucent and thin:
## - Emits a synthetic high-pitched "todash" musical hum like an out-of-tune harmonica
## - Applies screen refraction and chromatic aberration shaders across its planar pool
## - Transmits localized anomaly sway to the player's weapon aiming and camera rig
## - Notifies the diegetic HUD with localized region anomaly alerts via Localization.t()
##
## Sacred Invariant:
## All player-facing warnings and banners must route through Localization.t("THINNY_ZONE_BANNER").

signal player_entered_thinny(player: CharacterBody3D, initial_intensity: float)
signal player_exited_thinny(player: CharacterBody3D)
signal anomaly_intensity_changed(current_intensity: float)

@export_group("Spatial Anomaly Dimensions")
@export var anomaly_radius: float = 30.0
@export var todash_hum_pitch: float = 1.0
@export var max_sway_intensity: float = 0.85

@export_group("Visual & Shader Parameters")
@export var pool_vertical_offset: float = 0.15
@export var pool_subdivisions: int = 16
@export var shader_refraction_scale: float = 1.0

@export_group("Localization & Identity")
@export var banner_localization_key: String = "THINNY_ZONE_BANNER"

var _audio_player: AudioStreamPlayer3D
var _pool_mesh: MeshInstance3D
var _shader_mat: ShaderMaterial
var _player_inside: bool = false
var _player_ref: CharacterBody3D = null
var _current_intensity: float = 0.0

func _ready() -> void:
	# Configure collision trigger volume
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # Player collision layer (layer 2)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = anomaly_radius
	col.shape = sphere
	add_child(col)

	_create_visual_pool()
	_create_audio_hum()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _create_visual_pool() -> void:
	_pool_mesh = MeshInstance3D.new()
	_pool_mesh.name = "ThinnyPoolSurface"
	
	var quad := PlaneMesh.new()
	quad.size = Vector2(anomaly_radius * 1.8, anomaly_radius * 1.8)
	quad.subdivide_width = pool_subdivisions
	quad.subdivide_depth = pool_subdivisions
	_pool_mesh.mesh = quad

	_shader_mat = ShaderMaterial.new()
	var shader := load("res://shaders/thinny_anomaly.gdshader") as Shader
	if shader != null:
		_shader_mat.shader = shader
		_shader_mat.set_shader_parameter("distortion_power", 0.04 * shader_refraction_scale)
	_pool_mesh.material_override = _shader_mat
	_pool_mesh.position.y = pool_vertical_offset
	add_child(_pool_mesh)

func _create_audio_hum() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "TodashHum"
	_audio_player.unit_size = anomaly_radius * 0.8
	_audio_player.max_distance = anomaly_radius * 2.2
	_audio_player.pitch_scale = todash_hum_pitch
	_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_audio_player.bus = "Master"
	add_child(_audio_player)

func _process(_delta: float) -> void:
	if not _player_inside or _player_ref == null or not is_instance_valid(_player_ref):
		return

	var dist := global_position.distance_to(_player_ref.global_position)
	var raw_intensity := clampf(1.0 - (dist / anomaly_radius), 0.0, 1.0)
	var intensity := raw_intensity * max_sway_intensity

	if absf(intensity - _current_intensity) > 0.01:
		_current_intensity = intensity
		anomaly_intensity_changed.emit(_current_intensity)

	# Forward anomaly distortion to player camera and ballistics rig
	if _player_ref.has_method("apply_thinny_distortion"):
		_player_ref.call("apply_thinny_distortion", intensity)
	elif _player_ref.has_method("apply_anomaly_sway"):
		_player_ref.call("apply_anomaly_sway", intensity)

	_update_pool_shader_intensity(raw_intensity)

func _update_pool_shader_intensity(intensity: float) -> void:
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("intensity", intensity)
	if _audio_player != null and _audio_player.playing:
		_audio_player.volume_db = linear_to_db(clampf(intensity * 1.2, 0.05, 1.0))

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("player"):
		_player_inside = true
		_player_ref = body as CharacterBody3D
		_current_intensity = max_sway_intensity * 0.1
		player_entered_thinny.emit(_player_ref, _current_intensity)

		# Push localized tactical warning to diegetic HUD
		_dispatch_hud_warning()

func _dispatch_hud_warning() -> void:
	var hud_target := _resolve_hud_node()
	if hud_target != null:
		var localized_banner: String = Localization.t(banner_localization_key)
		if hud_target.has_method("notify_region_change"):
			hud_target.call("notify_region_change", localized_banner)
		elif hud_target.has_method("show_notification"):
			hud_target.call("show_notification", localized_banner, 3.5)

func _resolve_hud_node() -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		var candidate := get_tree().root.find_child("UI", true, false)
		if candidate != null:
			return candidate
		candidate = get_tree().root.find_child("HUD", true, false)
		if candidate != null:
			return candidate
	return null

func _on_body_exited(body: Node3D) -> void:
	if body == _player_ref:
		_player_inside = false
		if _player_ref.has_method("apply_thinny_distortion"):
			_player_ref.call("apply_thinny_distortion", 0.0)
		elif _player_ref.has_method("apply_anomaly_sway"):
			_player_ref.call("apply_anomaly_sway", 0.0)
		player_exited_thinny.emit(_player_ref)
		_player_ref = null
		_current_intensity = 0.0

func get_current_intensity() -> float:
	return _current_intensity

func is_player_affected() -> bool:
	return _player_inside
