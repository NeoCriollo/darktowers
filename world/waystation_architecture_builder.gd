class_name WaystationArchitectureBuilder
extends RefCounted

## Procedural Bunker Architecture & 3D Prop Builder for Node 0
## Extracted from WaystationSanctuary to maintain granular file architecture.

const BUNKER_CENTER := Vector2(-1180.0, -1180.0)
const THRESHOLD_GATE := Vector2(-1060.0, -1060.0)
const BUNKER_MODEL_PATH: String = "res://assets/architecture/landmarks/waystation_bunker/bunker.glb"
const BUNKER_MODEL_SCALE := Vector3(28.0, 26.0, 28.0)
const BUNKER_MODEL_ROTATION_DEG := Vector3(0.0, 45.0, 0.0)

static func build_bunker_architecture(parent: Node3D) -> Dictionary:
	var bunker_root: Node3D = parent.get_node_or_null("BunkerStructure") as Node3D
	if bunker_root == null:
		bunker_root = Node3D.new()
		bunker_root.name = "BunkerStructure"
		parent.add_child(bunker_root)

	var sb: StaticBody3D = bunker_root.get_node_or_null("BunkerColliders") as StaticBody3D
	if sb == null:
		sb = StaticBody3D.new()
		sb.name = "BunkerColliders"
		sb.collision_layer = 1
		sb.collision_mask = 0
		bunker_root.add_child(sb)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.38, 0.35, 0.32)
	floor_mat.roughness = 0.88
	var floor_mi := add_solid_box(sb, floor_mat, Vector3(0.0, 0.175, 0.0), Vector3(26.0, 0.35, 26.0))
	floor_mi.name = "FoundationSlab"

	var model_inst: Node3D = bunker_root.get_node_or_null("CustomBunkerModel") as Node3D
	if model_inst == null:
		model_inst = parent.get_node_or_null("CustomBunkerModel") as Node3D

	if model_inst == null and ResourceLoader.exists(BUNKER_MODEL_PATH):
		var glb_scene: PackedScene = load(BUNKER_MODEL_PATH) as PackedScene
		if glb_scene != null:
			model_inst = glb_scene.instantiate() as Node3D
			model_inst.name = "CustomBunkerModel"
			model_inst.scale = BUNKER_MODEL_SCALE
			model_inst.rotation_degrees = BUNKER_MODEL_ROTATION_DEG
			bunker_root.add_child(model_inst)
		elif FileAccess.file_exists(BUNKER_MODEL_PATH):
			var gltf := GLTFDocument.new()
			var state := GLTFState.new()
			if gltf.append_from_file(BUNKER_MODEL_PATH, state) == OK:
				model_inst = gltf.generate_scene(state) as Node3D
				if model_inst != null:
					model_inst.name = "CustomBunkerModel"
					model_inst.scale = BUNKER_MODEL_SCALE
					model_inst.rotation_degrees = BUNKER_MODEL_ROTATION_DEG
					bunker_root.add_child(model_inst)

	if model_inst != null:
		build_mesh_collisions(model_inst)
	else:
		build_procedural_fallback_walls(sb)

	var interior_lantern := OmniLight3D.new()
	interior_lantern.name = "InteriorKeroseneLantern"
	interior_lantern.position = Vector3(-4.0, 5.0, 0.0)
	interior_lantern.light_color = Color(0.98, 0.74, 0.45)
	interior_lantern.light_energy = 2.6
	interior_lantern.omni_range = 18.0
	interior_lantern.shadow_enabled = true
	bunker_root.add_child(interior_lantern)

	var breezeway_lantern := OmniLight3D.new()
	breezeway_lantern.name = "BreezewayLantern"
	breezeway_lantern.position = Vector3(3.0, 5.0, 0.0)
	breezeway_lantern.light_color = Color(0.98, 0.70, 0.40)
	breezeway_lantern.light_energy = 2.2
	breezeway_lantern.omni_range = 14.0
	breezeway_lantern.shadow_enabled = true
	bunker_root.add_child(breezeway_lantern)

	return {"interior_lantern": interior_lantern, "breezeway_lantern": breezeway_lantern}

static func build_mesh_collisions(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.get_node_or_null(mi.name + "_col") == null:
			mi.create_trimesh_collision()
			for child in mi.get_children():
				if child is StaticBody3D:
					var sb := child as StaticBody3D
					sb.collision_layer = 1
					sb.collision_mask = 0
	for child in node.get_children():
		build_mesh_collisions(child)

static func build_procedural_fallback_walls(sb: StaticBody3D) -> void:
	var adobe_mat := StandardMaterial3D.new()
	adobe_mat.albedo_color = Color(0.48, 0.42, 0.35); adobe_mat.roughness = 0.94
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.32, 0.25, 0.20); roof_mat.roughness = 0.85; roof_mat.metallic = 0.45

	add_solid_box(sb, adobe_mat, Vector3(-5.7, 1.8, 0.0), Vector3(0.6, 3.6, 9.2))
	add_solid_box(sb, adobe_mat, Vector3(0.0, 1.8, -4.5), Vector3(12.0, 3.6, 0.6))
	add_solid_box(sb, adobe_mat, Vector3(0.0, 1.8, 4.5), Vector3(12.0, 3.6, 0.6))
	add_solid_box(sb, adobe_mat, Vector3(5.7, 1.8, -3.5), Vector3(0.6, 3.6, 3.0))
	add_solid_box(sb, adobe_mat, Vector3(5.7, 1.8, 3.5), Vector3(0.6, 3.6, 3.0))
	add_solid_box(sb, adobe_mat, Vector3(5.7, 3.2, 0.0), Vector3(0.7, 0.8, 4.2))
	var roof_box := add_solid_box(sb, roof_mat, Vector3(0.0, 3.75, 0.0), Vector3(12.8, 0.35, 9.8))
	roof_box.rotation_degrees.z = 2.5

static func add_solid_box(parent: Node, mat: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := create_mesh_box(parent, mat, pos, size)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size; cs.shape = shape; cs.position = pos
	parent.add_child(cs)
	return mi

static func create_mesh_box(parent: Node, mat: Material, pos: Vector3, size: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size; box.material = mat
	mi.mesh = box; mi.position = pos
	if rot_deg != Vector3.ZERO: mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func create_mesh_cylinder(parent: Node, mat: Material, pos: Vector3, top_r: float, bot_r: float, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top_r; cyl.bottom_radius = bot_r; cyl.height = h; cyl.material = mat
	mi.mesh = cyl; mi.position = pos
	parent.add_child(mi)
	return mi

static func create_interaction_area(parent: Node, area_name: String, radius: float, pos: Vector3, on_enter: Callable, on_exit: Callable) -> Area3D:
	var area := Area3D.new()
	area.name = area_name; area.collision_layer = 0; area.collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius; cs.shape = sphere; cs.position = pos
	area.add_child(cs)
	area.body_entered.connect(on_enter)
	area.body_exited.connect(on_exit)
	parent.add_child(area)
	return area

static func build_shelter_volume(parent: WaystationSanctuary) -> Area3D:
	var shelter_area := Area3D.new()
	shelter_area.name = "BunkerShelterZone"; shelter_area.collision_layer = 0; shelter_area.collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 16.0, 18.0); cs.shape = box; cs.position = Vector3(0.0, 8.0, 0.0)
	shelter_area.add_child(cs)
	shelter_area.body_entered.connect(parent._on_shelter_body_entered)
	shelter_area.body_exited.connect(parent._on_shelter_body_exited)
	parent.add_child(shelter_area)
	return shelter_area

static func build_gun_cleaning_workbench(parent: WaystationSanctuary) -> Area3D:
	var root := Node3D.new(); root.name = "WorkbenchStation"; root.position = Vector3(2.0, 0.0, -6.8)
	parent.add_child(root)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.24, 0.17, 0.13); wood_mat.roughness = 0.92
	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.20, 0.20, 0.22); metal_mat.roughness = 0.75; metal_mat.metallic = 0.85

	create_mesh_box(root, wood_mat, Vector3(0.0, 0.85, 0.0), Vector3(2.0, 0.12, 0.85))
	for lx in [-0.85, 0.85]:
		for lz in [-0.32, 0.32]:
			create_mesh_box(root, metal_mat, Vector3(lx, 0.425, lz), Vector3(0.08, 0.85, 0.08))

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(2.1, 0.9, 0.9); cs.shape = shape; cs.position = Vector3(0.0, 0.45, 0.0)
	sb.add_child(cs); root.add_child(sb)

	# Vise, solvent bottle, gun oil can
	create_mesh_box(root, metal_mat, Vector3(-0.75, 0.98, 0.15), Vector3(0.24, 0.22, 0.28))
	var solvent_mat := StandardMaterial3D.new()
	solvent_mat.albedo_color = Color(0.85, 0.55, 0.15, 0.85); solvent_mat.roughness = 0.2
	solvent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	create_mesh_cylinder(root, solvent_mat, Vector3(0.55, 0.98, -0.15), 0.04, 0.06, 0.22)
	var oil_mat := StandardMaterial3D.new()
	oil_mat.albedo_color = Color(0.72, 0.65, 0.45); oil_mat.metallic = 0.8; oil_mat.roughness = 0.4
	create_mesh_cylinder(root, oil_mat, Vector3(0.72, 0.96, -0.12), 0.05, 0.05, 0.18)

	return create_interaction_area(root, "WorkbenchArea", 2.4, Vector3(0.0, 0.8, 0.0),
		func(b):
			if b.is_in_group("player") or b is CharacterBody3D:
				parent._near_workbench = true
				parent._show_hud_prompt("WORKBENCH: PRESS [E] TO STRIP & OIL FIREARM"),
		func(b):
			if b.is_in_group("player") or b is CharacterBody3D:
				parent._near_workbench = false
				parent._clear_hud_prompt()
	)

static func build_ncp_atomic_logbook(parent: WaystationSanctuary) -> Dictionary:
	var root := Node3D.new(); root.name = "NCPAtomicLogbook"
	root.position = Vector3(-2.2, 0.0, 0.5); root.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	parent.add_child(root)

	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.18, 0.22, 0.20); steel_mat.roughness = 0.75; steel_mat.metallic = 0.65
	var crt_mat := StandardMaterial3D.new()
	crt_mat.albedo_color = Color(0.12, 0.35, 0.18); crt_mat.emission_enabled = true
	crt_mat.emission = Color(0.25, 0.95, 0.42); crt_mat.emission_energy_multiplier = 1.2; crt_mat.roughness = 0.25

	create_mesh_box(root, steel_mat, Vector3(0.0, 0.675, 0.0), Vector3(0.9, 1.35, 0.7))
	create_mesh_box(root, crt_mat, Vector3(0.0, 1.05, 0.33), Vector3(0.55, 0.42, 0.1), Vector3(-15.0, 0.0, 0.0))

	var terminal_light := OmniLight3D.new()
	terminal_light.name = "CRTPhosphorGlow"; terminal_light.position = Vector3(0.0, 1.15, 0.55)
	terminal_light.light_color = Color(0.25, 0.95, 0.42); terminal_light.light_energy = 1.5; terminal_light.omni_range = 4.0
	root.add_child(terminal_light)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var col_box := BoxShape3D.new(); col_box.size = Vector3(1.0, 1.4, 0.8); cs.shape = col_box; cs.position = Vector3(0.0, 0.7, 0.0)
	sb.add_child(cs); root.add_child(sb)

	var terminal_area := create_interaction_area(root, "TerminalArea", 2.4, Vector3(0.0, 0.9, 0.4),
		func(b):
			if b.is_in_group("player") or b is CharacterBody3D:
				parent._near_terminal = true
				parent._show_hud_prompt("NCP TERMINAL: PRESS [E] TO RECORD CHRONICLE (SAVE)"),
		func(b):
			if b.is_in_group("player") or b is CharacterBody3D:
				parent._near_terminal = false
				parent._clear_hud_prompt()
	)
	return {"area": terminal_area, "light": terminal_light}

static func build_heavy_iron_footlocker(parent: WaystationSanctuary) -> Area3D:
	var root := Node3D.new(); root.name = "HeavyIronFootlocker"
	root.position = Vector3(-1.0, 0.0, 6.8); root.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	parent.add_child(root)

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.17, 0.16); iron_mat.roughness = 0.8; iron_mat.metallic = 0.85
	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.78, 0.62, 0.28); brass_mat.roughness = 0.5; brass_mat.metallic = 0.9

	create_mesh_box(root, iron_mat, Vector3(0.0, 0.325, 0.0), Vector3(1.4, 0.65, 0.85))
	for bx in [-0.68, 0.68]:
		create_mesh_box(root, brass_mat, Vector3(bx, 0.33, 0.0), Vector3(0.08, 0.68, 0.88))

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(1.5, 0.7, 0.9); cs.shape = shape; cs.position = Vector3(0.0, 0.35, 0.0)
	sb.add_child(cs); root.add_child(sb)

	return create_interaction_area(root, "FootlockerArea", 2.2, Vector3(0.0, 0.4, 0.0),
		func(b):
			if b.is_in_group("player") or b is CharacterBody3D:
				parent._near_footlocker = true
				if not parent._footlocker_looted:
					parent._show_hud_prompt("WAY-BUNKER STASH: PRESS [E] TO COLLECT STARTER SUPPLIES")
				else:
					parent._show_hud_prompt("WAY-BUNKER STASH (EMPTY)"),
		func(b):
			if b.is_in_group("player") or b is CharacterBody3D:
				parent._near_footlocker = false
				parent._clear_hud_prompt()
	)

static func build_artesian_hand_pump(parent: WaystationSanctuary) -> Area3D:
	var root := Node3D.new(); root.name = "ArtesianHandPump"; root.position = Vector3(5.5, 0.0, -6.5)
	parent.add_child(root)

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.16, 0.16, 0.18); iron_mat.roughness = 0.7; iron_mat.metallic = 0.85
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.42, 0.38, 0.35); stone_mat.roughness = 0.95

	create_mesh_cylinder(root, stone_mat, Vector3(0.0, 0.225, 0.0), 0.55, 0.65, 0.45)
	create_mesh_cylinder(root, iron_mat, Vector3(0.0, 1.0, 0.0), 0.14, 0.18, 1.1)
	create_mesh_box(root, iron_mat, Vector3(-0.35, 1.35, 0.0), Vector3(0.06, 0.75, 0.06), Vector3(0.0, 0.0, 45.0))

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var col_shape := CylinderShape3D.new(); col_shape.radius = 0.65; col_shape.height = 1.6
	cs.shape = col_shape; cs.position = Vector3(0.0, 0.8, 0.0)
	sb.add_child(cs); root.add_child(sb)

	return create_interaction_area(root, "PumpArea", 2.2, Vector3(0.0, 0.8, 0.0),
		func(b):
			if b.is_in_group("player") or b is CharacterBody3D:
				parent._near_pump = true
				parent._show_hud_prompt("ARTESIAN WELL: PRESS [E] TO DRINK & RECOVER STAMINA"),
		func(b):
			if b.is_in_group("player") or b is CharacterBody3D:
				parent._near_pump = false
				parent._clear_hud_prompt()
	)

static func build_threshold_warning_gate(parent: WaystationSanctuary) -> Array[OmniLight3D]:
	var gate_root := Node3D.new(); gate_root.name = "ThresholdWarningGate"
	var rel_x := THRESHOLD_GATE.x - BUNKER_CENTER.x
	var rel_z := THRESHOLD_GATE.y - BUNKER_CENTER.y
	var gate_ground_y := TerrainCollisionGenerator.sample_height(THRESHOLD_GATE.x, THRESHOLD_GATE.y)
	gate_root.position = Vector3(rel_x, gate_ground_y - parent.position.y, rel_z)
	gate_root.rotation_degrees = Vector3(0.0, -45.0, 0.0)
	parent.add_child(gate_root)

	var pylon_mat := StandardMaterial3D.new()
	pylon_mat.albedo_color = Color(0.28, 0.28, 0.26); pylon_mat.roughness = 0.9
	var hazard_mat := StandardMaterial3D.new()
	hazard_mat.albedo_color = Color(0.85, 0.65, 0.12); hazard_mat.roughness = 0.7

	var sb := StaticBody3D.new()
	gate_root.add_child(sb)

	var pylon_lights: Array[OmniLight3D] = []
	for pz in [-7.5, 7.5]:
		create_mesh_box(gate_root, pylon_mat, Vector3(0.0, 2.25, pz), Vector3(1.4, 4.5, 1.4))
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new(); shape.size = Vector3(1.5, 4.6, 1.5); cs.shape = shape; cs.position = Vector3(0.0, 2.25, pz)
		sb.add_child(cs)

		create_mesh_box(gate_root, hazard_mat, Vector3(0.0, 2.6, pz), Vector3(1.45, 0.75, 1.45))
		var strobe := OmniLight3D.new()
		strobe.light_color = Color(1.0, 0.65, 0.15); strobe.light_energy = 2.5; strobe.omni_range = 14.0
		strobe.position = Vector3(0.0, 4.8, pz)
		gate_root.add_child(strobe)
		pylon_lights.append(strobe)

	create_mesh_box(gate_root, pylon_mat, Vector3(0.0, 4.2, 0.0), Vector3(0.8, 0.9, 15.0))
	var header_cs := CollisionShape3D.new()
	var header_shape := BoxShape3D.new(); header_shape.size = Vector3(0.9, 1.0, 15.0); header_cs.shape = header_shape; header_cs.position = Vector3(0.0, 4.2, 0.0)
	sb.add_child(header_cs)

	return pylon_lights
