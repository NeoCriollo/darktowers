class_name WorldBootstrapBuilder
extends RefCounted

## World Bootstrap & Subsystem Spawning Builder.
## Constructs terrain collision, navigation meshes, regional beacons, landmarks,
## sanctuaries, and narrative relics across the 2500m × 2500m wasteland.

var world: World = null

const INITIAL_PLAYER_SPAWN_XZ := Vector2(-1180.0, -1180.0)
const BUNKER_SPAWN_OFFSET := Vector2(24.0, 24.0)

func _init(p_world: World = null) -> void:
	world = p_world

func execute_staged_bootstrap(loading_callback: Callable = Callable()) -> void:
	# Stage 1: Terrain collision & player placement
	if loading_callback.is_valid(): loading_callback.call("SURVEYING ALKALI FLATS & COLLISION", 0.15)
	setup_terrain_collision()
	if world != null and world.get_tree() != null: await world.get_tree().process_frame

	# Stage 2: Navigation mesh & raider patrols
	if loading_callback.is_valid(): loading_callback.call("MAPPING BASIN NAVIGATION & RAIDER PATROLS", 0.30)
	setup_basin_navigation_and_enemies()
	if world != null and world.get_tree() != null: await world.get_tree().process_frame

	# Stage 3: Waystation sanctuary & regional beacons
	if loading_callback.is_valid(): loading_callback.call("INDEXING WAYSTATION SANCTUARY & BEACONS", 0.48)
	setup_waystation_sanctuary()
	setup_regional_beacons_and_spawners()
	setup_regional_landmarks()
	if world != null and world.get_tree() != null: await world.get_tree().process_frame

	# Stage 4: Anomalies, clipmap & relics
	if loading_callback.is_valid(): loading_callback.call("CALIBRATING THINNY ANOMALIES & RELICS", 0.65)
	setup_thinny_anomalies()
	setup_horizon_clipmap()
	setup_narrative_relics()
	setup_loot_crate_system()
	if world != null and world.get_tree() != null: await world.get_tree().process_frame

	# Stage 5: Landmark alignment, prop scatter & rock pack warming
	if loading_callback.is_valid(): loading_callback.call("WARMING ROCK PACK CACHE & SCATTER", 0.82)
	align_landmark_and_props()
	_warm_rock_pack_cache()
	world._run_procedural_prop_generation()
	if world != null and world.get_tree() != null: await world.get_tree().process_frame

	# Stage 6: Graphics quality, layout overrides & editor catalog pre-init
	if loading_callback.is_valid(): loading_callback.call("APPLYING WORLD OVERRIDES & SETTINGS", 0.95)
	configure_graphics_quality()
	world._apply_world_layout_overrides()
	world._setup_pause_menu()
	world._check_and_init_editor_mode()
	if loading_callback.is_valid(): loading_callback.call("BATTERY FULL — THE PATH OF KA AWAITS", 1.0)

func _warm_rock_pack_cache() -> void:
	var rpl_script = load("res://world/props/rock_pack_library.gd")
	if rpl_script != null:
		var lib = rpl_script.new()
		if lib != null and lib.has_method("load_library"):
			lib.load_library()

func align_landmark_and_props() -> void:
	if world != null and world.prop_scatter != null and world.terrain_mesh != null:
		var mat := world.terrain_mesh.get_surface_override_material(0)
		if mat == null and world.terrain_mesh.mesh != null:
			mat = world.terrain_mesh.mesh.material
		if mat is ShaderMaterial:
			var wind_dir: Variant = mat.get_shader_parameter("wind_direction")
			if wind_dir != null and wind_dir is float:
				world.prop_scatter.valley_axis_rad = float(wind_dir)

func setup_terrain_collision() -> void:
	if world.terrain_mesh == null: return
	var col_shape: CollisionShape3D = world.terrain_mesh.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	if col_shape != null:
		const RES := 626
		const SIZE := 2500.0
		col_shape.shape = TerrainCollisionGenerator.generate_heightmap(RES, SIZE)
		var spacing := TerrainCollisionGenerator.heightmap_spacing(RES, SIZE)
		col_shape.transform = Transform3D(Basis.from_scale(Vector3(spacing, 1.0, spacing)), Vector3.ZERO)

		var static_body := col_shape.get_parent() as StaticBody3D
		if static_body != null:
			var abyss_floor := static_body.get_node_or_null("FallbackAbyssFloor") as CollisionShape3D
			if abyss_floor == null:
				var abyss_shape := BoxShape3D.new()
				abyss_shape.size = Vector3(2500.0, 2.0, 2500.0)
				abyss_floor = CollisionShape3D.new()
				abyss_floor.name = "FallbackAbyssFloor"
				abyss_floor.shape = abyss_shape
				static_body.add_child(abyss_floor)
			abyss_floor.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -45.0, 0.0))

	if world.player != null:
		var spawn_pos: Vector3 = Vector3.ZERO
		var cp_name: String = "The Mohaine Way-Bunker"
		var save_mgr = world.get_node_or_null("/root/WorldSaveData")
		if save_mgr == null and WorldSaveData != null and "instance" in WorldSaveData:
			save_mgr = WorldSaveData.instance

		var has_explicit_outside: bool = false
		if save_mgr != null and save_mgr.has_method("has_explicit_outside_save"):
			has_explicit_outside = save_mgr.has_explicit_outside_save()

		if has_explicit_outside and save_mgr != null and save_mgr.has_method("get_saved_player_position"):
			spawn_pos = save_mgr.get_saved_player_position()
			if save_mgr.has_method("get_saved_checkpoint"):
				var cp_dict: Dictionary = save_mgr.get_saved_checkpoint()
				cp_name = String(cp_dict.get("name", "The Mohaine Way-Bunker"))
		else:
			var spawn_xz := INITIAL_PLAYER_SPAWN_XZ + BUNKER_SPAWN_OFFSET
			var ground := TerrainCollisionGenerator.sample_height(spawn_xz.x, spawn_xz.y)
			spawn_pos = Vector3(spawn_xz.x, ground + 0.15, spawn_xz.y)
			cp_name = "The Mohaine Way-Bunker"

		var dist_to_bunker: float = Vector2(spawn_pos.x - INITIAL_PLAYER_SPAWN_XZ.x, spawn_pos.z - INITIAL_PLAYER_SPAWN_XZ.y).length()
		if dist_to_bunker < 20.0:
			var outside_xz := INITIAL_PLAYER_SPAWN_XZ + BUNKER_SPAWN_OFFSET
			var ground_y := TerrainCollisionGenerator.sample_height(outside_xz.x, outside_xz.y)
			spawn_pos = Vector3(outside_xz.x, ground_y + 0.15, outside_xz.y)

		world.player.global_position = spawn_pos
		world.player.velocity = Vector3.ZERO
		world.player.rotation_degrees.y = 45.0
		if world.player.has_method("register_checkpoint"):
			world.player.call("register_checkpoint", spawn_pos, cp_name)

func resolve_safe_player_spawn(p: CharacterBody3D) -> void:
	if p == null: return
	var px := p.global_position.x
	var pz := p.global_position.z
	var base_y := TerrainCollisionGenerator.sample_height(px, pz) + 0.15
	if world != null and world.is_inside_tree() and world.get_world_3d() != null:
		var space := world.get_world_3d().direct_space_state
		if space != null:
			var excl: Array[RID] = [p.get_rid()]
			if _is_spawn_column_obstructed(space, px, pz, excl):
				for r_step in range(1, 25):
					var radius := float(r_step) * 4.0
					var found := false
					for a_step in range(16):
						var ang := PI * 0.25 + float(a_step) * (TAU / 16.0)
						var cx := clampf(px + cos(ang) * radius, -1220.0, 1220.0)
						var cz := clampf(pz + sin(ang) * radius, -1220.0, 1220.0)
						if not _is_spawn_column_obstructed(space, cx, cz, excl):
							px = cx; pz = cz
							base_y = TerrainCollisionGenerator.sample_height(px, pz) + 0.15
							found = true
							break
					if found: break
	p.global_position = Vector3(px, base_y, pz)
	p.velocity = Vector3.ZERO
	if p.has_method("register_checkpoint"):
		p.call("register_checkpoint", p.global_position, "The Mohaine Way-Bunker")

func _is_spawn_column_obstructed(space: PhysicsDirectSpaceState3D, x: float, z: float, excl: Array[RID]) -> bool:
	var ty := TerrainCollisionGenerator.sample_height(x, z)
	var q_down := PhysicsRayQueryParameters3D.create(Vector3(x, ty + 120.0, z), Vector3(x, ty - 2.0, z), 1, excl)
	q_down.hit_from_inside = true; q_down.hit_back_faces = true
	var hit_down := space.intersect_ray(q_down)
	if not hit_down.is_empty():
		var hy: float = (hit_down["position"] as Vector3).y
		var hn: Vector3 = hit_down["normal"] as Vector3
		if hy > ty + 0.45 or hn.angle_to(Vector3.UP) > 0.68: return true
	var q_up := PhysicsRayQueryParameters3D.create(Vector3(x, ty + 0.25, z), Vector3(x, ty + 80.0, z), 1, excl)
	q_up.hit_from_inside = true; q_up.hit_back_faces = true
	if not space.intersect_ray(q_up).is_empty(): return true
	for i in range(8):
		var ang := float(i) * (TAU / 8.0)
		var dir := Vector3(cos(ang), 0.0, sin(ang)) * 2.4
		var q_h := PhysicsRayQueryParameters3D.create(Vector3(x, ty + 0.9, z), Vector3(x, ty + 0.9, z) + dir, 1, excl)
		q_h.hit_from_inside = true; q_h.hit_back_faces = true
		if not space.intersect_ray(q_h).is_empty(): return true
	return false

func setup_basin_navigation_and_enemies() -> void:
	var nav_region := world.get_node_or_null("BasinNavigationRegion") as NavigationRegion3D
	if nav_region == null:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "BasinNavigationRegion"
		var nav_mesh := NavigationMesh.new()
		var half := 1250.0
		var grid_steps := 32
		var step := (half * 2.0) / float(grid_steps)
		var verts := PackedVector3Array()
		for gz in range(grid_steps + 1):
			for gx in range(grid_steps + 1):
				var wx := -half + float(gx) * step
				var wz := -half + float(gz) * step
				var wy := TerrainCollisionGenerator.sample_height(wx, wz)
				verts.append(Vector3(wx, wy, wz))
		nav_mesh.set_vertices(verts)
		var stride := grid_steps + 1
		for gz in range(grid_steps):
			for gx in range(grid_steps):
				var i0 := gz * stride + gx
				var i1 := i0 + 1
				var i2 := i0 + stride
				var i3 := i2 + 1
				nav_mesh.add_polygon(PackedInt32Array([i0, i1, i2]))
				nav_mesh.add_polygon(PackedInt32Array([i1, i3, i2]))
		nav_region.navigation_mesh = nav_mesh
		world.add_child(nav_region)

	if world.get_node_or_null("WastelandRaiders") != null: return
	var raiders_root := Node3D.new()
	raiders_root.name = "WastelandRaiders"
	world.add_child(raiders_root)

	var enemy_scene: PackedScene = null
	if ResourceLoader.exists("res://scenes/enemy_base.tscn"):
		enemy_scene = load("res://scenes/enemy_base.tscn") as PackedScene
	elif ResourceLoader.exists("res://enemy_base.tscn"):
		enemy_scene = load("res://enemy_base.tscn") as PackedScene

	var patrol_coords: Array[Vector2] = [
		Vector2(-500.0, -850.0), Vector2(-580.0, -940.0), Vector2(-120.0, -510.0), Vector2(-180.0, -580.0),
		Vector2(45.0, -50.0), Vector2(-50.0, 45.0), Vector2(-630.0, 30.0), Vector2(-670.0, 75.0),
		Vector2(35.0, 630.0), Vector2(-40.0, 670.0), Vector2(630.0, 40.0), Vector2(675.0, 85.0),
		Vector2(620.0, 620.0), Vector2(660.0, 670.0)
	]

	for i in range(patrol_coords.size()):
		var xz: Vector2 = patrol_coords[i]
		if xz.distance_to(Vector2(-1000.0, -800.0)) < 250.0: continue
		var raider: EnemyBase = null
		if enemy_scene != null: raider = enemy_scene.instantiate() as EnemyBase
		if raider == null: raider = EnemyBase.new()
		raider.name = "WastelandRaider_%d" % (i + 1)
		var gy: float = TerrainCollisionGenerator.sample_height(xz.x, xz.y)
		raider.position = Vector3(xz.x, gy + 0.15, xz.y)
		raiders_root.add_child(raider)

func setup_waystation_sanctuary() -> void:
	if world.get_node_or_null("WaystationSanctuary") != null: return
	for path in ["res://scenes/waystation_sanctuary.tscn", "res://waystation_sanctuary.tscn", "res://world/waystation_sanctuary.tscn"]:
		if ResourceLoader.exists(path):
			var s_scene = load(path) as PackedScene
			if s_scene != null:
				var sanctuary = s_scene.instantiate()
				sanctuary.name = "WaystationSanctuary"
				world.add_child(sanctuary)
				return
	var sanctuary_script = load("res://world/waystation_sanctuary.gd")
	if sanctuary_script != null:
		var sanctuary = sanctuary_script.new()
		sanctuary.name = "WaystationSanctuary"
		world.add_child(sanctuary)

func setup_regional_beacons_and_spawners() -> void:
	if world.get_node_or_null("RegionalBeacons") != null: return
	var beacons_root := Node3D.new()
	beacons_root.name = "RegionalBeacons"
	world.add_child(beacons_root)

	var beacon_scene: PackedScene = null
	if ResourceLoader.exists("res://scenes/beacon_node.tscn"):
		beacon_scene = load("res://scenes/beacon_node.tscn") as PackedScene
	var spawner_script = load("res://basin_spawner.gd")

	var beacon_configs: Array[Dictionary] = [
		{"basin_id": "sw_desolation", "key": "BEACON_SW_DESOLATION", "coord": Vector2(-530.0, -880.0)},
		{"basin_id": "south_salt", "key": "BEACON_SOUTH_SALT", "coord": Vector2(-130.0, -530.0)},
		{"basin_id": "cradle", "key": "BEACON_CALICHE_CRADLE", "coord": Vector2(25.0, -20.0)},
		{"basin_id": "west_gorge", "key": "BEACON_RUST_GORGE", "coord": Vector2(-630.0, 70.0)},
		{"basin_id": "north_alkali", "key": "BEACON_NORTH_ALKALI", "coord": Vector2(45.0, 680.0)},
		{"basin_id": "east_dunes", "key": "BEACON_EAST_DUNES", "coord": Vector2(670.0, 70.0)},
		{"basin_id": "monolith_pass", "key": "BEACON_MONOLITH_PASS", "coord": Vector2(630.0, 630.0)}
	]

	for cfg in beacon_configs:
		var loc: Vector2 = cfg["coord"]
		var b_id: String = cfg["basin_id"]
		var gy := TerrainCollisionGenerator.sample_height(loc.x, loc.y)

		var beacon: BeaconNode = null
		if beacon_scene != null: beacon = beacon_scene.instantiate() as BeaconNode
		if beacon == null: beacon = BeaconNode.new()
		beacon.name = "Beacon_" + b_id
		beacon.basin_id = b_id
		beacon.localized_name_key = cfg["key"]
		beacon.defense_radius = 45.0
		beacon.position = Vector3(loc.x, gy, loc.y)
		beacons_root.add_child(beacon)

		if spawner_script != null:
			var spawner: BasinSpawner = spawner_script.new()
			spawner.name = "Spawner_" + b_id
			spawner.basin_id = b_id
			spawner.spawn_radius = 48.0
			spawner.min_spawn_distance_from_player = 20.0
			spawner.position = Vector3(loc.x, gy, loc.y)
			beacons_root.add_child(spawner)

func setup_regional_landmarks() -> void:
	if world.get_node_or_null("RegionalLandmarks") != null: return
	var landmarks_script = load("res://world/regional_landmarks.gd")
	if landmarks_script != null:
		var landmarks = landmarks_script.new()
		landmarks.name = "RegionalLandmarks"
		world.add_child(landmarks)

func setup_thinny_anomalies() -> void:
	if world.get_node_or_null("ThinnyZones") != null: return
	var zones_root := Node3D.new()
	zones_root.name = "ThinnyZones"
	world.add_child(zones_root)

	var thinny_script = load("res://world/thinny_zone.gd")
	if thinny_script == null: return

	var anomaly_locs: Array[Dictionary] = [
		{"name": "ThinnyAnomaly_BeamAbyss", "loc": Vector2(325.0, 325.0), "radius": 160.0},
		{"name": "ThinnyAnomaly_NWHollow", "loc": Vector2(-650.0, 650.0), "radius": 180.0},
		{"name": "ThinnyAnomaly_SERift", "loc": Vector2(650.0, -650.0), "radius": 180.0}
	]

	for info in anomaly_locs:
		var loc: Vector2 = info["loc"]
		var r: float = float(info["radius"])
		var y: float = TerrainCollisionGenerator.sample_height(loc.x, loc.y)
		var zone: Area3D = thinny_script.new()
		zone.name = String(info["name"])
		zone.anomaly_radius = r
		zone.position = Vector3(loc.x, y, loc.y)
		zones_root.add_child(zone)

func setup_horizon_clipmap() -> void:
	if world.get_node_or_null("HorizonClipmap") != null: return
	var clipmap_script = load("res://world/horizon_clipmap.gd")
	if clipmap_script != null:
		var clipmap = clipmap_script.new()
		clipmap.name = "HorizonClipmap"
		world.add_child(clipmap)

func setup_narrative_relics() -> void:
	if world.get_node_or_null("MidWorldNarrativeRelics") != null: return
	var relics_root := Node3D.new()
	relics_root.name = "MidWorldNarrativeRelics"
	world.add_child(relics_root)

	var doorway_script = load("res://world/midworld_doorway.gd")
	if doorway_script != null:
		var doorway = doorway_script.new()
		doorway.name = "FreestandingDoorway_ThePrisoner"
		var door_pos := Vector2(-45.0, -85.0)
		var door_y := TerrainCollisionGenerator.sample_height(door_pos.x, door_pos.y)
		doorway.position = Vector3(door_pos.x, door_y, door_pos.y)
		doorway.rotation.y = 0.78 + PI * 0.5
		relics_root.add_child(doorway)

	var hatch_script = load("res://world/positronics_vault_hatch.gd")
	if hatch_script != null:
		var hatch = hatch_script.new()
		hatch.name = "PositronicsHatch_19"
		var hatch_pos := Vector2(85.0, -40.0)
		var hatch_y := TerrainCollisionGenerator.sample_height(hatch_pos.x, hatch_pos.y)
		hatch.position = Vector3(hatch_pos.x, hatch_y, hatch_pos.y)
		hatch.rotation_degrees = Vector3(-8.0, 42.0, 5.0)
		relics_root.add_child(hatch)

func setup_loot_crate_system() -> void:
	if world.get_node_or_null("LootCrateManager") != null: return
	var mgr_script = load("res://world/loot_crate_manager.gd")
	if mgr_script != null:
		var mgr = mgr_script.new()
		mgr.name = "LootCrateManager"
		world.add_child(mgr)

# ─── Loading Overlay (moved from world.gd to honour the 450-line ceiling) ────

var _loading_canvas: CanvasLayer = null
var _loading_label: Label = null
var _loading_progress: ProgressBar = null

func create_loading_overlay() -> void:
	_loading_canvas = CanvasLayer.new()
	_loading_canvas.name = "WorldLoadingCanvas"
	_loading_canvas.layer = 120
	world.add_child(_loading_canvas)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.035, 0.03, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_canvas.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_canvas.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(420.0, 80.0)
	center.add_child(vbox)

	_loading_label = Label.new()
	_loading_label.text = "THE PATH OF KA — ALIGNING MONOLITH AXIS..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_color_override("font_color", Color(0.88, 0.65, 0.28, 1.0))
	_loading_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_loading_label)

	_loading_progress = ProgressBar.new()
	_loading_progress.custom_minimum_size = Vector2(420.0, 8.0)
	_loading_progress.max_value = 1.0
	_loading_progress.value = 0.05
	_loading_progress.show_percentage = false
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.88, 0.65, 0.28, 0.9)
	bar_style.set_corner_radius_all(2)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.10, 0.08, 0.8)
	bg_style.set_corner_radius_all(2)
	_loading_progress.add_theme_stylebox_override("fill", bar_style)
	_loading_progress.add_theme_stylebox_override("background", bg_style)
	vbox.add_child(_loading_progress)

func report_stage_progress(stage_title: String, fraction: float) -> void:
	if _loading_label != null: _loading_label.text = "THE PATH OF KA — " + stage_title
	if _loading_progress != null: _loading_progress.value = fraction

func dismiss_loading_overlay() -> void:
	if _loading_canvas == null or world == null or not world.is_inside_tree(): return
	var tween := world.create_tween()
	var bg: Control = _loading_canvas.get_child(0) as Control
	if bg != null:
		tween.tween_property(bg, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		if _loading_canvas != null and is_instance_valid(_loading_canvas):
			_loading_canvas.queue_free()
		_loading_canvas = null
	)

func configure_graphics_quality() -> void:
	var vp := world.get_viewport()
	if vp != null:
		vp.use_taa = false
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

