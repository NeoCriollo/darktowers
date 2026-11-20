class_name MidWorldDoorway
extends Node3D

## Freestanding Dimensional Doorway — Inspired by Stephen King's "The Drawing of the Three"
## An impossible freestanding weathered wooden door standing upright on the desolate sands.
## Has physical collision, interactive doorway frame, and an active spatial portal vista.

signal doorway_approached(doorway_name: String)
signal doorway_exited()
signal doorway_state_changed(is_open: bool)

@export var localization_key: String = "MIDWORLD_DOORWAY_PRISONER"
@export var doorway_name: String = ""
@export var is_door_open: bool = true
@export var interaction_distance: float = 3.5
@export var portal_energy_base: float = 1.4
@export var pulse_speed: float = 1.8

var _frame_mesh: MeshInstance3D
var _door_panel: MeshInstance3D
var _door_pivot: Node3D
var _portal_plane: MeshInstance3D
var _light: OmniLight3D
var _interaction_area: Area3D
var _pulse_timer: float = 0.0
var _is_player_near: bool = false

func _ready() -> void:
	if doorway_name.is_empty():
		doorway_name = get_localized_name()
	_build_doorway_geometry()
	_build_door_panel()
	_build_portal_interior()
	_setup_interaction_trigger()
	_update_door_state(false)

func _process(delta: float) -> void:
	_pulse_timer += delta * pulse_speed
	_update_portal_vfx()

## Returns the localized name of this dimensional threshold.
func get_localized_name() -> String:
	if not localization_key.is_empty():
		return Localization.t(localization_key, Localization.t("MIDWORLD_DOORWAY_PRISONER"))
	return Localization.t("MIDWORLD_DOORWAY_PRISONER")

## Toggles the physical wooden door slab between open and closed positions.
func toggle_door() -> void:
	set_door_open(not is_door_open)

## Sets the physical door state and updates pivot orientation.
func set_door_open(p_open: bool) -> void:
	if is_door_open == p_open:
		return
	is_door_open = p_open
	_update_door_state(true)
	doorway_state_changed.emit(is_door_open)

func _update_door_state(animate: bool) -> void:
	if _door_pivot == null:
		return
	var target_rot_y := deg_to_rad(-105.0) if is_door_open else 0.0
	if animate:
		var tween := create_tween()
		tween.tween_property(_door_pivot, "rotation:y", target_rot_y, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_door_pivot.rotation.y = target_rot_y

func _update_portal_vfx() -> void:
	if _light != null:
		var jitter := sin(_pulse_timer) * 0.25 + cos(_pulse_timer * 2.3) * 0.1
		_light.light_energy = maxf(0.5, portal_energy_base + jitter)
	if _portal_plane != null and _portal_plane.material_override is StandardMaterial3D:
		var mat := _portal_plane.material_override as StandardMaterial3D
		var glow := 1.2 + sin(_pulse_timer * 1.4) * 0.35
		mat.emission_energy_multiplier = glow

func _build_doorway_geometry() -> void:
	# Heavy weathered timber frame
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.18, 0.14, 0.12)
	frame_mat.roughness = 0.92

	# Left Jamb
	var left_jamb := MeshInstance3D.new()
	var jamb_mesh := BoxMesh.new()
	jamb_mesh.size = Vector3(0.25, 3.2, 0.35)
	left_jamb.mesh = jamb_mesh
	left_jamb.material_override = frame_mat
	left_jamb.position = Vector3(-0.9, 1.6, 0.0)
	add_child(left_jamb)

	# Right Jamb
	var right_jamb := MeshInstance3D.new()
	right_jamb.mesh = jamb_mesh
	right_jamb.material_override = frame_mat
	right_jamb.position = Vector3(0.9, 1.6, 0.0)
	add_child(right_jamb)

	# Lintel (Top)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(2.05, 0.3, 0.35)
	lintel.mesh = lintel_mesh
	lintel.material_override = frame_mat
	lintel.position = Vector3(0.0, 3.2, 0.0)
	add_child(lintel)

	# Threshold Sill (Bottom)
	var sill := MeshInstance3D.new()
	var sill_mesh := BoxMesh.new()
	sill_mesh.size = Vector3(2.05, 0.15, 0.45)
	sill.mesh = sill_mesh
	sill.material_override = frame_mat
	sill.position = Vector3(0.0, 0.08, 0.0)
	add_child(sill)

	# Static collision so it's a solid physical structure
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 3.4, 0.4)
	col.shape = shape
	col.position = Vector3(0.0, 1.6, 0.0)
	body.add_child(col)
	add_child(body)

func _build_door_panel() -> void:
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-0.78, 1.6, 0.0)
	add_child(_door_pivot)

	_door_panel = MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(1.54, 2.9, 0.08)
	_door_panel.mesh = panel_mesh

	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.24, 0.18, 0.13)
	panel_mat.roughness = 0.88
	_door_panel.material_override = panel_mat
	_door_panel.position = Vector3(0.77, 0.0, 0.0)
	_door_pivot.add_child(_door_panel)

func _build_portal_interior() -> void:
	# The Impossible Portal Interior: A doorway looking into another time/dimension
	_portal_plane = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.55, 3.0)
	_portal_plane.mesh = quad
	_portal_plane.position = Vector3(0.0, 1.6, 0.0)

	var portal_mat := StandardMaterial3D.new()
	# Pale electric blue/cyan dimensional glow
	portal_mat.albedo_color = Color(0.05, 0.15, 0.25)
	portal_mat.emission_enabled = true
	portal_mat.emission = Color(0.2, 0.65, 0.95)
	portal_mat.emission_energy_multiplier = portal_energy_base
	portal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_portal_plane.material_override = portal_mat
	add_child(_portal_plane)

	# Subtle ambient point light illuminating the surrounding sand
	_light = OmniLight3D.new()
	_light.light_color = Color(0.3, 0.7, 1.0)
	_light.light_energy = 1.8
	_light.omni_range = 8.0
	_light.position = Vector3(0.0, 1.6, 0.5)
	add_child(_light)

func _setup_interaction_trigger() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "DoorwayProximityArea"
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 1 # Player layer

	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interaction_distance
	col_shape.shape = sphere
	col_shape.position = Vector3(0.0, 1.6, 0.0)
	_interaction_area.add_child(col_shape)

	_interaction_area.body_entered.connect(_on_proximity_body_entered)
	_interaction_area.body_exited.connect(_on_proximity_body_exited)
	add_child(_interaction_area)

func _on_proximity_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_is_player_near = true
		doorway_approached.emit(get_localized_name())

func _on_proximity_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_is_player_near = false
		doorway_exited.emit()
