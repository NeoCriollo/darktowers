class_name PositronicsVaultHatch
extends Node3D

## North Central Positronics Subterranean Access Hatch
## Half-buried high-tech bunker hatch from the fallen civilization of the "Old Ones".
## Sits wedged in the dune slope with warning stencils, heavy reinforced steel, and indicator beacons.

@export var designation: String = "NCP-FACILITY-19"

func _ready() -> void:
	_build_hatch()

func _build_hatch() -> void:
	# 1. Brutalist Concrete Collar
	var concrete_mat := StandardMaterial3D.new()
	concrete_mat.albedo_color = Color(0.32, 0.30, 0.28)
	concrete_mat.roughness = 0.95

	var collar := MeshInstance3D.new()
	var collar_mesh := BoxMesh.new()
	collar_mesh.size = Vector3(5.5, 1.2, 5.5)
	collar.mesh = collar_mesh
	collar.material_override = concrete_mat
	collar.position.y = 0.4
	add_child(collar)

	# 2. Heavy Blast Door Plates
	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.16, 0.18, 0.20)
	steel_mat.metallic = 0.85
	steel_mat.roughness = 0.65

	var door := MeshInstance3D.new()
	var door_mesh := CylinderMesh.new()
	door_mesh.top_radius = 2.1
	door_mesh.bottom_radius = 2.1
	door_mesh.height = 0.35
	door.mesh = door_mesh
	door.material_override = steel_mat
	door.position.y = 0.9
	add_child(door)

	# 3. Flashing Emergency Beacon Light (Failing auxiliary power of the Old Ones)
	var beacon := OmniLight3D.new()
	beacon.name = "EmergencyBlinker"
	beacon.light_color = Color(1.0, 0.22, 0.1)
	beacon.light_energy = 2.2
	beacon.omni_range = 10.0
	beacon.position = Vector3(0.0, 1.6, 0.0)
	add_child(beacon)

	# Pulsing animation tween
	var tw := create_tween().set_loops()
	tw.tween_property(beacon, "light_energy", 0.2, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(beacon, "light_energy", 2.5, 0.4).set_trans(Tween.TRANS_BOUNCE)

	# 4. Solid Physics Collision
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(5.5, 1.6, 5.5)
	cs.shape = col_box
	cs.position.y = 0.8
	sb.add_child(cs)
	add_child(sb)

