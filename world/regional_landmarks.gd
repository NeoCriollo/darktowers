class_name RegionalLandmarks
extends Node3D

## Signature Regional Macro-Biomes Landmarks & Sightlines — "Dark Towers: The Path of Ka"
##
## 1. Cradle Nexus Overlook Cliff (+140.0, +140.0):
##    Scenic observation point on the NE ridge looking directly across Thinny Beam Abyss (+325, +325)
##    towards The Dark Tower at (+700, +700).
## 2. Rust-Gorge Highway Overpass (-650.0, +15.0):
##    Collapsed brutalist interstate highway with tilted road deck, massive piers, and sniper perches.
## 3. Erg Monolithic Pillar Ruins (+680.0, -20.0):
##    Towering pre-break stone obelisks half-buried in shifting sand dunes.
## 4. Dark Tower Outer Fortress Perimeter (+650.0, +650.0):
##    Fortified security blast walls, dragon's teeth caltrops, and searchlights guarding the Tower approach.

const CRADLE_OVERLOOK_POS := Vector2(140.0, 140.0)
const HIGHWAY_OVERPASS_POS := Vector2(-650.0, 15.0)
const ERG_MONOLITH_POS := Vector2(680.0, -20.0)
const MONOLITH_DEFENSE_POS := Vector2(650.0, 650.0)

func _ready() -> void:
	_build_cradle_overlook()
	_build_highway_overpass()
	_build_erg_monolith_ruins()
	_build_dark_tower_fortress_perimeter()

# ─── 1. Cradle Nexus Overlook Cliff (+140.0, +140.0) ─────────────────────────

func _build_cradle_overlook() -> void:
	var root := Node3D.new()
	root.name = "Landmark_CradleOverlook"
	var gy := TerrainCollisionGenerator.sample_height(CRADLE_OVERLOOK_POS.x, CRADLE_OVERLOOK_POS.y)
	root.position = Vector3(CRADLE_OVERLOOK_POS.x, gy, CRADLE_OVERLOOK_POS.y)
	# Face northeast (0.785 rad / 45 deg) along the Beam towards The Dark Tower
	root.rotation.y = 0.785
	add_child(root)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.38, 0.32, 0.28)
	stone_mat.roughness = 0.95

	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.22, 0.22, 0.24)
	rail_mat.metallic = 0.85
	rail_mat.roughness = 0.7

	var sb := StaticBody3D.new()
	root.add_child(sb)

	# Overlook Cantilever Stone Platform (8m x 1m x 12m)
	var platform := MeshInstance3D.new()
	var plat_box := BoxMesh.new()
	plat_box.size = Vector3(8.0, 0.8, 12.0)
	plat_box.material = stone_mat
	platform.mesh = plat_box
	platform.position = Vector3(0.0, 0.4, 0.0)
	root.add_child(platform)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.2, 1.0, 12.2)
	cs.shape = shape
	cs.position = Vector3(0.0, 0.4, 0.0)
	sb.add_child(cs)

	# Safety Railings on NE Overlook Rim
	var rail := MeshInstance3D.new()
	var rail_box := BoxMesh.new()
	rail_box.size = Vector3(8.0, 1.1, 0.15)
	rail_box.material = rail_mat
	rail.mesh = rail_box
	rail.position = Vector3(0.0, 1.35, -5.9)
	root.add_child(rail)

	# Surveyor Transit / Telescope Tripod Stand
	var tripod := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.45
	cyl.height = 1.3
	cyl.material = rail_mat
	tripod.mesh = cyl
	tripod.position = Vector3(0.0, 1.45, -5.2)
	root.add_child(tripod)

# ─── 2. Rust-Gorge Highway Overpass (-650.0, +15.0) ──────────────────────────

func _build_highway_overpass() -> void:
	var root := Node3D.new()
	root.name = "Landmark_HighwayOverpass"
	var gy := TerrainCollisionGenerator.sample_height(HIGHWAY_OVERPASS_POS.x, HIGHWAY_OVERPASS_POS.y)
	root.position = Vector3(HIGHWAY_OVERPASS_POS.x, gy, HIGHWAY_OVERPASS_POS.y)
	root.rotation.y = -0.35
	add_child(root)

	var concrete_mat := StandardMaterial3D.new()
	concrete_mat.albedo_color = Color(0.32, 0.30, 0.28)
	concrete_mat.roughness = 0.92

	var rusted_rebar_mat := StandardMaterial3D.new()
	rusted_rebar_mat.albedo_color = Color(0.35, 0.18, 0.12)
	rusted_rebar_mat.metallic = 0.7
	rusted_rebar_mat.roughness = 0.8

	var sb := StaticBody3D.new()
	root.add_child(sb)

	# Massive Brutalist Support Piers (Left & Right)
	for px in [-9.0, 9.0]:
		var pier := MeshInstance3D.new()
		var pier_box := BoxMesh.new()
		pier_box.size = Vector3(2.5, 9.0, 3.5)
		pier_box.material = concrete_mat
		pier.mesh = pier_box
		pier.position = Vector3(px, 4.5, 0.0)
		root.add_child(pier)

		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(2.6, 9.2, 3.6)
		cs.shape = s
		cs.position = Vector3(px, 4.5, 0.0)
		sb.add_child(cs)

	# Tilted Collapsed Road Deck Slab (32m x 1.2m x 8m, tilted at 18 degrees)
	var deck := MeshInstance3D.new()
	var deck_box := BoxMesh.new()
	deck_box.size = Vector3(28.0, 1.2, 8.5)
	deck_box.material = concrete_mat
	deck.mesh = deck_box
	deck.position = Vector3(0.0, 5.2, 0.0)
	deck.rotation_degrees.z = -14.0
	root.add_child(deck)

	var deck_cs := CollisionShape3D.new()
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(28.2, 1.3, 8.7)
	deck_cs.shape = deck_shape
	deck_cs.position = Vector3(0.0, 5.2, 0.0)
	deck_cs.rotation_degrees.z = -14.0
	sb.add_child(deck_cs)

	# Twisted Rebars & Rubble Cluster
	for rx in [-4.0, 0.0, 4.0]:
		var rebar := MeshInstance3D.new()
		var rebar_mesh := CylinderMesh.new()
		rebar_mesh.top_radius = 0.03
		rebar_mesh.bottom_radius = 0.03
		rebar_mesh.height = 3.5
		rebar_mesh.material = rusted_rebar_mat
		rebar.mesh = rebar_mesh
		rebar.position = Vector3(rx, 6.2, 4.0)
		rebar.rotation_degrees.x = 35.0
		root.add_child(rebar)

# ─── 3. Erg Monolithic Pillar Ruins (+680.0, -20.0) ──────────────────────────

func _build_erg_monolith_ruins() -> void:
	var root := Node3D.new()
	root.name = "Landmark_ErgMonolithRuins"
	var gy := TerrainCollisionGenerator.sample_height(ERG_MONOLITH_POS.x, ERG_MONOLITH_POS.y)
	root.position = Vector3(ERG_MONOLITH_POS.x, gy, ERG_MONOLITH_POS.y)
	add_child(root)

	var obsidian_mat := StandardMaterial3D.new()
	obsidian_mat.albedo_color = Color(0.12, 0.11, 0.14)
	obsidian_mat.roughness = 0.35
	obsidian_mat.metallic = 0.25

	var glyph_mat := StandardMaterial3D.new()
	glyph_mat.albedo_color = Color(0.15, 0.12, 0.18)
	glyph_mat.emission_enabled = true
	glyph_mat.emission = Color(0.85, 0.45, 0.15)
	glyph_mat.emission_energy_multiplier = 0.6

	var sb := StaticBody3D.new()
	root.add_child(sb)

	# Cluster of 4 Towering Tilted Hexagonal Obelisks
	var pillar_offsets := [
		{"pos": Vector3(0.0, 8.0, 0.0),   "scale": Vector3(2.4, 18.0, 2.4), "tilt": Vector3(6.0, 22.0, -4.0)},
		{"pos": Vector3(-6.5, 6.0, 5.0),  "scale": Vector3(1.8, 14.0, 1.8), "tilt": Vector3(-8.0, 45.0, 8.0)},
		{"pos": Vector3(7.2, 5.5, -4.5),  "scale": Vector3(1.6, 12.0, 1.6), "tilt": Vector3(12.0, -15.0, -10.0)},
		{"pos": Vector3(2.5, 4.0, 8.0),   "scale": Vector3(2.0, 9.0, 2.0),  "tilt": Vector3(-15.0, 90.0, 0.0)}
	]

	for p_data in pillar_offsets:
		var p_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.radial_segments = 6 # Hexagonal monolith
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.95
		cyl.height = 1.0
		cyl.material = obsidian_mat
		p_mesh.mesh = cyl
		p_mesh.position = p_data["pos"]
		p_mesh.scale = p_data["scale"]
		p_mesh.rotation_degrees = p_data["tilt"]
		root.add_child(p_mesh)

		var cs := CollisionShape3D.new()
		var col := CylinderShape3D.new()
		col.radius = p_data["scale"].x * 0.8
		col.height = p_data["scale"].y
		cs.shape = col
		cs.position = p_data["pos"]
		cs.rotation_degrees = p_data["tilt"]
		sb.add_child(cs)

# ─── 4. Dark Tower Outer Fortress Perimeter (+650.0, +650.0) ──────────────────

func _build_dark_tower_fortress_perimeter() -> void:
	var root := Node3D.new()
	root.name = "Landmark_TowerFortressPerimeter"
	var gy := TerrainCollisionGenerator.sample_height(MONOLITH_DEFENSE_POS.x, MONOLITH_DEFENSE_POS.y)
	root.position = Vector3(MONOLITH_DEFENSE_POS.x, gy, MONOLITH_DEFENSE_POS.y)
	root.rotation.y = 0.785
	add_child(root)

	var basalt_mat := StandardMaterial3D.new()
	basalt_mat.albedo_color = Color(0.10, 0.09, 0.11)
	basalt_mat.roughness = 0.82

	var rusted_iron_mat := StandardMaterial3D.new()
	rusted_iron_mat.albedo_color = Color(0.24, 0.14, 0.10)
	rusted_iron_mat.metallic = 0.8
	rusted_iron_mat.roughness = 0.7

	var sb := StaticBody3D.new()
	root.add_child(sb)

	# Angular Vitrified Basalt Blast Barriers (Flanking Left and Right)
	for bx in [-12.0, 12.0]:
		var barrier := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(8.0, 3.5, 1.8)
		b_box.material = basalt_mat
		barrier.mesh = b_box
		barrier.position = Vector3(bx, 1.75, 0.0)
		barrier.rotation_degrees.y = 15.0 if bx < 0 else -15.0
		root.add_child(barrier)

		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(8.2, 3.6, 2.0)
		cs.shape = s
		cs.position = barrier.position
		cs.rotation = barrier.rotation
		sb.add_child(cs)

	# Anti-Vehicle / Anti-Personnel Dragon's Teeth Caltrops
	for tx in range(-8, 9, 4):
		var tooth := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(1.2, 1.6, 1.2)
		prism.material = rusted_iron_mat
		tooth.mesh = prism
		tooth.position = Vector3(float(tx), 0.8, -4.0)
		root.add_child(tooth)

		var cs := CollisionShape3D.new()
		var box_s := BoxShape3D.new()
		box_s.size = Vector3(1.2, 1.6, 1.2)
		cs.shape = box_s
		cs.position = tooth.position
		sb.add_child(cs)

	# Crimson Surveillance Warning Beacon Light
	var warn_light := OmniLight3D.new()
	warn_light.name = "PerimeterBeacon"
	warn_light.position = Vector3(0.0, 4.5, 0.0)
	warn_light.light_color = Color(1.0, 0.22, 0.10)
	warn_light.light_energy = 3.0
	warn_light.omni_range = 18.0
	root.add_child(warn_light)

