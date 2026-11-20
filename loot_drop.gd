class_name LootDropItem
extends Area3D

## Tactile Wasteland Loot Drop & Resource Economy Pickup (Godot 4.3)
##
## Physical 3D item spawned upon an enemy's defeat in "Dark Towers: The Path of Ka".
## Supports three weighted resource categories:
## - AMMO (60%): .45 Long Colt cartridge boxes (replenishes revolver cylinder/reserves)
## - SURVIVAL (30%): Purified alkali water canteens & survival goods (restores respiration/stamina)
## - COMPONENT (10%): Rare gunsmithing components & mineral oil tins (cleans/lubricates firearm)
##
## Routes pickup notifications through Localization.t() to display amber terminal
## readouts on the "Glass & Iron" HUD.

signal item_picked_up(collector: Node3D, item_data: Dictionary)
signal picked_up(item_id: String, amount: int)

enum LootCategory {
	AMMO,
	SURVIVAL,
	COMPONENT
}

@export_group("Loot Specification")
@export var item_id: String = "ammo_45lc"
@export var item_type: String = "AMMO"
@export var item_name_key: String = "LOOT_ITEM_AMMO_45LC"
@export var amount: int = 3
@export var pickup_radius: float = 1.45
@export var auto_pickup_on_contact: bool = true

@export_group("Diegetic Motion")
@export var bob_amplitude: float = 0.05
@export var bob_frequency: float = 2.2
@export var spin_speed_rad: float = 0.85
@export var snap_to_terrain: bool = true

var _is_collected: bool = false
var _time_alive: float = 0.0
var _base_visual_y: float = 0.22
var _visual_root: Node3D = null
var _collision_shape: CollisionShape3D = null
var _beacon_light: OmniLight3D = null

func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 1
	collision_mask = 1

	_ensure_collision_shape()
	_build_visual_mesh()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if snap_to_terrain and is_inside_tree():
		_anchor_to_ground()

func _process(delta: float) -> void:
	if _is_collected:
		return
	_time_alive += delta
	if _visual_root != null:
		_visual_root.position.y = _base_visual_y + sin(_time_alive * bob_frequency) * bob_amplitude
		_visual_root.rotate_y(spin_speed_rad * delta)

func _physics_process(_delta: float) -> void:
	if _is_collected or not auto_pickup_on_contact or not is_inside_tree():
		return
	# Proximity check fallback for immediate player overlap
	for body in get_overlapping_bodies():
		if _is_valid_collector(body):
			collect(body)
			return

## Configures this loot drop instance from a weighted drop dictionary
func configure_loot(config: Dictionary) -> void:
	item_id = String(config.get("id", item_id))
	item_type = String(config.get("type", item_type)).to_upper()
	item_name_key = String(config.get("name_key", item_name_key))
	amount = maxi(1, int(config.get("amount", amount)))
	set_meta("loot_id", item_id)
	set_meta("loot_type", item_type)
	set_meta("loot_amount", amount)
	if is_inside_tree():
		_build_visual_mesh()

func get_loot_data() -> Dictionary:
	return {
		"id": item_id,
		"type": item_type,
		"name_key": item_name_key,
		"localized_name": Localization.t(item_name_key),
		"amount": amount
	}

func _anchor_to_ground() -> void:
	var gp: Vector3 = global_position
	var ground_y: float = TerrainCollisionGenerator.sample_height(gp.x, gp.z)
	if absf(gp.y - ground_y) > 4.0 or gp.y < ground_y:
		global_position = Vector3(gp.x, ground_y + 0.05, gp.z)

func _ensure_collision_shape() -> void:
	_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		add_child(_collision_shape)
	if _collision_shape.shape == null:
		var sphere := SphereShape3D.new()
		sphere.radius = pickup_radius
		_collision_shape.shape = sphere
	_collision_shape.position = Vector3(0.0, 0.35, 0.0)

func _build_visual_mesh() -> void:
	var existing := get_node_or_null("Visuals") as Node3D
	if existing != null:
		existing.queue_free()

	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	_visual_root.position = Vector3(0.0, _base_visual_y, 0.0)
	add_child(_visual_root)

	var upper_type: String = item_type.to_upper()
	var accent_color := Color(0.96, 0.78, 0.36)

	if upper_type == "AMMO" or "AMMO" in item_id.to_upper() or "45" in item_id:
		# .45 Long Colt Cardboard & Brass Cartridge Box
		var box_inst := MeshInstance3D.new()
		box_inst.name = "AmmoCartonMesh"
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.24, 0.14, 0.16)
		var carton_mat := StandardMaterial3D.new()
		carton_mat.albedo_color = Color(0.58, 0.46, 0.30)
		carton_mat.roughness = 0.84
		box_mesh.material = carton_mat
		box_inst.mesh = box_mesh
		_visual_root.add_child(box_inst)

		var brass_band := MeshInstance3D.new()
		brass_band.name = "BrassStrapMesh"
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(0.25, 0.04, 0.17)
		var brass_mat := StandardMaterial3D.new()
		brass_mat.albedo_color = Color(0.88, 0.68, 0.28)
		brass_mat.metallic = 0.85
		brass_mat.roughness = 0.32
		brass_mat.emission_enabled = true
		brass_mat.emission = Color(0.92, 0.68, 0.24)
		brass_mat.emission_energy_multiplier = 0.35
		band_mesh.material = brass_mat
		brass_band.mesh = band_mesh
		_visual_root.add_child(brass_band)
		accent_color = Color(0.98, 0.78, 0.32)

	elif upper_type == "SURVIVAL" or "WATER" in item_id.to_upper():
		# Wasteland Tin Canteen with Burlap Wrap
		var body_inst := MeshInstance3D.new()
		body_inst.name = "CanteenBodyMesh"
		var cyl_mesh := CylinderMesh.new()
		cyl_mesh.top_radius = 0.13
		cyl_mesh.bottom_radius = 0.13
		cyl_mesh.height = 0.22
		var tin_mat := StandardMaterial3D.new()
		tin_mat.albedo_color = Color(0.36, 0.44, 0.42)
		tin_mat.metallic = 0.55
		tin_mat.roughness = 0.52
		tin_mat.emission_enabled = true
		tin_mat.emission = Color(0.35, 0.68, 0.62)
		tin_mat.emission_energy_multiplier = 0.28
		cyl_mesh.material = tin_mat
		body_inst.mesh = cyl_mesh
		_visual_root.add_child(body_inst)

		var cap_inst := MeshInstance3D.new()
		cap_inst.name = "CopperStopperMesh"
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.035
		cap_mesh.bottom_radius = 0.04
		cap_mesh.height = 0.07
		var cop_mat := StandardMaterial3D.new()
		cop_mat.albedo_color = Color(0.78, 0.48, 0.26)
		cop_mat.metallic = 0.80
		cop_mat.roughness = 0.35
		cap_mesh.material = cop_mat
		cap_inst.mesh = cap_mesh
		cap_inst.position = Vector3(0.0, 0.14, 0.0)
		_visual_root.add_child(cap_inst)
		accent_color = Color(0.55, 0.85, 0.76)

	else:
		# Rare Gunsmithing Component / Solvent & Mainspring Tin
		var comp_inst := MeshInstance3D.new()
		comp_inst.name = "RareComponentMesh"
		var comp_mesh := BoxMesh.new()
		comp_mesh.size = Vector3(0.20, 0.18, 0.20)
		var steel_mat := StandardMaterial3D.new()
		steel_mat.albedo_color = Color(0.22, 0.24, 0.28)
		steel_mat.metallic = 0.90
		steel_mat.roughness = 0.26
		steel_mat.emission_enabled = true
		steel_mat.emission = Color(0.96, 0.58, 0.18)
		steel_mat.emission_energy_multiplier = 0.45
		comp_mesh.material = steel_mat
		comp_inst.mesh = comp_mesh
		_visual_root.add_child(comp_inst)
		accent_color = Color(1.0, 0.62, 0.22)

	if _beacon_light == null:
		_beacon_light = OmniLight3D.new()
		_beacon_light.name = "LootBeaconLight"
		_beacon_light.position = Vector3(0.0, 0.45, 0.0)
		_beacon_light.omni_range = 2.8
		_beacon_light.light_energy = 1.15
		add_child(_beacon_light)
	_beacon_light.light_color = accent_color

func _on_body_entered(body: Node3D) -> void:
	if _is_collected or not auto_pickup_on_contact:
		return
	if _is_valid_collector(body):
		collect(body)

func _is_valid_collector(body: Node3D) -> bool:
	if body == null:
		return false
	if body.name == "Player" or body.is_in_group("player"):
		return true
	if "weapon_system" in body and "stamina" in body:
		return true
	return false

## Physically collects the item, applies survival/ammunition effects to the Gunslinger,
## routes the localized notification to the HUD, and frees the pickup node.
func collect(collector: Node3D) -> Dictionary:
	if _is_collected:
		return {}
	_is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var localized_item_name: String = Localization.t(item_name_key)
	var upper_type: String = item_type.to_upper()
	var notification_text: String = ""

	if upper_type == "AMMO" or "AMMO" in item_id.to_upper():
		var rounds_added: int = _apply_ammo_pickup(collector, amount)
		notification_text = Localization.t("NOTIF_PICKUP_AMMO_FMT") % [localized_item_name, maxi(1, rounds_added)]
	elif upper_type == "SURVIVAL" or "WATER" in item_id.to_upper():
		var stam_pct: int = _apply_survival_pickup(collector, 45.0 * float(maxi(1, amount)))
		notification_text = Localization.t("NOTIF_PICKUP_SURVIVAL_FMT") % [localized_item_name, stam_pct]
	else:
		_apply_component_pickup(collector)
		notification_text = Localization.t("NOTIF_PICKUP_COMPONENT_FMT") % localized_item_name

	_notify_hud(collector, notification_text)

	var payload: Dictionary = get_loot_data()
	payload["notification"] = notification_text
	item_picked_up.emit(collector, payload)
	picked_up.emit(item_id, amount)

	queue_free()
	return payload

func _apply_ammo_pickup(collector: Node3D, rounds_to_add: int) -> int:
	if collector == null:
		return rounds_to_add
	var prev_reserves: int = int(collector.get_meta("ammo_reserve_45lc", 0)) if collector.has_meta("ammo_reserve_45lc") else 0
	collector.set_meta("ammo_reserve_45lc", prev_reserves + rounds_to_add)

	var ws: Node = null
	if "weapon_system" in collector and collector.get("weapon_system") != null:
		ws = collector.get("weapon_system") as Node
	elif collector.has_node("Visuals/WeaponSystem"):
		ws = collector.get_node("Visuals/WeaponSystem")

	if ws != null:
		for _i in range(rounds_to_add):
			if ws.has_method("reload_single_round"):
				ws.call("reload_single_round")
	return rounds_to_add

func _apply_survival_pickup(collector: Node3D, stamina_restore: float) -> int:
	if collector == null:
		return int(round(stamina_restore))
	if "stamina" in collector and "max_stamina" in collector:
		var max_s: float = float(collector.get("max_stamina"))
		var cur_s: float = float(collector.get("stamina"))
		var new_s: float = minf(max_s, cur_s + stamina_restore)
		collector.set("stamina", new_s)
		if "_is_exhausted_locked" in collector and new_s >= float(collector.get("exhaustion_recovery_threshold")):
			collector.set("_is_exhausted_locked", false)
		if collector.has_signal("stamina_changed"):
			collector.emit_signal("stamina_changed", new_s, max_s)
	# Clean water also lets the Gunslinger wash and dress light wounds
	if collector.has_method("heal"):
		collector.call("heal", stamina_restore * 0.35)
	return int(round(stamina_restore))

func _apply_component_pickup(collector: Node3D) -> void:
	if collector == null:
		return
	var ws: Node = null
	if "weapon_system" in collector and collector.get("weapon_system") != null:
		ws = collector.get("weapon_system") as Node
	elif collector.has_node("Visuals/WeaponSystem"):
		ws = collector.get_node("Visuals/WeaponSystem")
	if ws != null:
		if ws.has_method("field_clean"):
			ws.call("field_clean", 0.95)
		if ws.has_method("lubricate"):
			ws.call("lubricate", 0.95)
	_apply_survival_pickup(collector, 20.0)

func _notify_hud(collector: Node3D, message: String) -> void:
	if message.is_empty():
		return
	var hud_node: Node = null
	if collector != null and collector.get_parent() != null:
		hud_node = collector.get_parent().get_node_or_null("HUD")
	if hud_node == null and is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		hud_node = get_tree().current_scene.find_child("HUD", true, false)
	if hud_node != null and hud_node.has_method("show_notification"):
		hud_node.call("show_notification", message, 3.2)
