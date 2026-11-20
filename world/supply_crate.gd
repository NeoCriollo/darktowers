class_name SupplyCrate3D
extends Node3D

const GunslingerProgression = preload("res://world/gunslinger_progression.gd")

## Warzone-Style Dynamic Loot Supply Crate — "The Path of Ka"
## Emits a spatial audio hum and beacon glow when ready.
## When opened by player interaction (E), smoothly swings its lid open,
## dispenses ammunition, scrap, brass, and gun oil, and enters a cooldown
## state until refilled (via timer or Severe Haboob dust storms).

signal crate_opened(loot_payload: Dictionary)
signal crate_refilled

enum CrateTier {
	STANDARD_FOOTLOCKER,       ## Frontier iron box: basic ammo, scrap, water
	POSITRONICS_RELIQUARY      ## High-tech NCP capsule: rare components, brass, refined oil
}

enum CrateState {
	READY,
	OPENING,
	DEPLETED
}

@export var tier: CrateTier = CrateTier.STANDARD_FOOTLOCKER
@export var refill_duration_seconds: float = 240.0  ## Automatic Ka-cycle refill timer
@export var interaction_radius: float = 3.2

var current_state: CrateState = CrateState.READY
var _refill_timer: float = 0.0

var _lid_pivot: Node3D
var _light_beacon: OmniLight3D
var _audio_hum: AudioStreamPlayer3D
var _interact_area: Area3D

const COLOR_READY_STD := Color(0.92, 0.72, 0.38)     # Warm Amber phosphor
const COLOR_READY_RARE := Color(0.25, 0.85, 0.95)    # NCP Electric Cyan
const COLOR_DEPLETED := Color(0.35, 0.15, 0.10)      # Dull burnt red

func _ready() -> void:
	_build_crate_geometry()
	_build_interaction_volume()
	_build_audio_beacon()
	_update_beacon_visuals()

func _process(delta: float) -> void:
	if current_state == CrateState.DEPLETED:
		_refill_timer += delta
		if _refill_timer >= refill_duration_seconds:
			refill_crate()

func _build_crate_geometry() -> void:
	# 1. Base Container Box
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.4, 0.75, 0.9)

	var base_inst := MeshInstance3D.new()
	base_inst.name = "CrateBase"
	base_inst.mesh = base_mesh
	base_inst.position.y = 0.375

	var mat := StandardMaterial3D.new()
	if tier == CrateTier.STANDARD_FOOTLOCKER:
		mat.albedo_color = Color(0.28, 0.24, 0.19) # Weathered rusted olive/iron
		mat.roughness = 0.88
		mat.metallic = 0.45
	else:
		mat.albedo_color = Color(0.18, 0.20, 0.24) # NCP High-tech brushed titanium
		mat.roughness = 0.55
		mat.metallic = 0.85

	base_inst.material_override = mat
	add_child(base_inst)

	# 2. Articulated Lid on Pivot (Rear hinge)
	_lid_pivot = Node3D.new()
	_lid_pivot.name = "LidPivot"
	_lid_pivot.position = Vector3(0.0, 0.75, -0.45)
	add_child(_lid_pivot)

	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.44, 0.15, 0.94)

	var lid_inst := MeshInstance3D.new()
	lid_inst.name = "CrateLid"
	lid_inst.mesh = lid_mesh
	lid_inst.position = Vector3(0.0, 0.075, 0.45)
	lid_inst.material_override = mat
	_lid_pivot.add_child(lid_inst)

	# 3. Status Light Beacon
	_light_beacon = OmniLight3D.new()
	_light_beacon.name = "StatusBeacon"
	_light_beacon.position = Vector3(0.0, 0.85, 0.45)
	_light_beacon.omni_range = 5.5
	_light_beacon.light_energy = 1.4
	add_child(_light_beacon)

	# 4. Physical Collision Box
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 0.9, 1.0)
	col.shape = shape
	col.position.y = 0.45
	body.add_child(col)
	add_child(body)

func _build_interaction_volume() -> void:
	_interact_area = Area3D.new()
	_interact_area.name = "InteractionArea"
	_interact_area.collision_layer = 0
	_interact_area.collision_mask = 2 # Player layer

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interaction_radius
	col.shape = sphere
	col.position.y = 0.5
	_interact_area.add_child(col)
	add_child(_interact_area)

func _build_audio_beacon() -> void:
	# Subtle beacon sound setup (uses placeholder/silent until standard stream assigned)
	_audio_hum = AudioStreamPlayer3D.new()
	_audio_hum.name = "CrateHumAudio"
	_audio_hum.unit_size = 6.0
	_audio_hum.max_distance = 28.0
	_audio_hum.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_audio_hum.bus = "Master"
	add_child(_audio_hum)

func _fill_audio_hum() -> void:
	pass

func _update_beacon_visuals() -> void:
	if _light_beacon == null:
		return
	if current_state == CrateState.READY:
		_light_beacon.light_color = COLOR_READY_STD if tier == CrateTier.STANDARD_FOOTLOCKER else COLOR_READY_RARE
		_light_beacon.light_energy = 1.6
	else:
		_light_beacon.light_color = COLOR_DEPLETED
		_light_beacon.light_energy = 0.3
		_light_beacon.light_energy = 0.3
		if _audio_hum != null:
			_audio_hum.stop()

## Called when the player presses [E] in range
func interact_open(player: CharacterBody3D) -> Dictionary:
	if current_state != CrateState.READY:
		return {}

	current_state = CrateState.OPENING

	# Smoothly swing lid back 105 degrees with a heavy metallic clunk
	var tw := create_tween()
	tw.tween_property(_lid_pivot, "rotation_degrees:x", -105.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): current_state = CrateState.DEPLETED)

	_update_beacon_visuals()
	_refill_timer = 0.0

	var payload := _generate_loot_payload()
	_apply_loot_to_player(player, payload)
	crate_opened.emit(payload)
	return payload

func _generate_loot_payload() -> Dictionary:
	var payload: Dictionary = {}
	if tier == CrateTier.STANDARD_FOOTLOCKER:
		payload["ammo_45lc"] = randi_range(6, 12)
		payload["scrap"] = randi_range(8, 16)
		payload["water_liters"] = snappedf(randf_range(0.4, 0.8), 0.1)
		payload["brass"] = randi_range(2, 4)
		payload["tier_name"] = "FRONTIER AMMO CACHE"
	else:
		payload["ammo_45lc"] = randi_range(12, 18)
		payload["scrap"] = randi_range(20, 35)
		payload["brass"] = randi_range(6, 12)
		payload["gun_oil_fl_oz"] = snappedf(randf_range(1.2, 2.5), 0.1)
		payload["tier_name"] = "NCP RELIQUARY CAPSULE"
	return payload

func _apply_loot_to_player(player: CharacterBody3D, payload: Dictionary) -> void:
	if player == null:
		return

	# 1. Add Ammunition into WeaponSystem
	var ws = player.get("weapon_system")
	if ws != null:
		var ammo_count: int = payload.get("ammo_45lc", 0)
		var cur_mag: int = ws.get("current_magazine_rounds")
		var max_mag: int = ws.get("magazine_capacity")
		ws.set("current_magazine_rounds", mini(max_mag, cur_mag + ammo_count))

	# 2. Add Scrap, Brass, and Oil into GunslingerProgression
	var prog = player.get("gunslinger_progression") as GunslingerProgression
	if prog != null:
		prog.scrap_count += int(payload.get("scrap", 0))
		prog.brass_count += int(payload.get("brass", 0))
		prog.gun_oil_fl_oz += float(payload.get("gun_oil_fl_oz", 0.0))

## Restores the crate, closes the lid, and re-arms status lights and audio hum
func refill_crate() -> void:
	if current_state == CrateState.READY:
		return

	var tw := create_tween()
	tw.tween_property(_lid_pivot, "rotation_degrees:x", 0.0, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		current_state = CrateState.READY
		_update_beacon_visuals()
		_fill_audio_hum()
		crate_refilled.emit()
	)

