class_name TerrainCollisionGenerator
extends Node

## Dynamically generates and syncs physics collision for the displaced procedural terrain.
## Matches the mathematical displacement formula from wasteland_terrain.gdshader:
## - displacement_scale: 2.5
## - dune_scale: 0.008, wind_direction: 0.78 rad, playa_flatten: 0.55
## - yardang_scale: 0.012, yardang_strength: 0.65 (wind-carved yardangs & stepped mesas)
## - gravel_scale: 0.024
## - 8 macro basins (waystation_sanctuary R=150m, 7 biomes R=250m)
## - 9 canyon pass defiles carving corridors through perimeter ridges
## - thinny_beam_abyss chasm at (+325.0, +325.0) R=160m (depth -28.0m)

# Basin definitions: Vector3(center_x, center_z, radius)
const BASINS: Array[Vector3] = [
	Vector3(-1000.0, -800.0, 150.0), # Node 0: waystation_sanctuary
	Vector3(-550.0, -900.0, 250.0),  # Node 1: sw_desolation
	Vector3(-150.0, -550.0, 250.0),  # Node 2: south_salt
	Vector3(0.0, 0.0, 250.0),        # Node 3: cradle
	Vector3(-650.0, 50.0, 250.0),    # Node 4: west_gorge
	Vector3(0.0, 650.0, 250.0),      # Node 5: north_alkali
	Vector3(650.0, 50.0, 250.0),     # Node 6: east_dunes
	Vector3(650.0, 650.0, 250.0)     # Node 7: monolith_pass
]

# Pass data: [ax, az, bx, bz, half_width]
const PASSES: Array = [
	[-900.0, -820.0, -650.0, -880.0, 18.0], # pass_sanctuary_to_sw
	[-450.0, -800.0, -250.0, -650.0, 18.0], # pass_sw_to_salt
	[-100.0, -420.0, -30.0, -150.0, 18.0],  # pass_salt_to_cradle
	[-150.0, 15.0, -500.0, 40.0, 16.0],     # pass_cradle_to_gorge
	[0.0, 150.0, 0.0, 500.0, 18.0],         # pass_cradle_to_north
	[150.0, 15.0, 500.0, 40.0, 18.0],       # pass_cradle_to_east
	[-500.0, 180.0, -150.0, 520.0, 16.0],   # pass_gorge_to_north
	[150.0, 650.0, 500.0, 650.0, 18.0],     # pass_north_to_monolith
	[650.0, 150.0, 650.0, 500.0, 18.0]      # pass_east_to_monolith
]

# Escarpment Barrier Chains (14 Segments across 6 Chains)
const BARRIER_SEGMENTS: Array = [
	[-1250.0, -1100.0, -1225.0, -1225.0], # Chain 0 Horseshoe West Wing
	[-1225.0, -1225.0, -1100.0, -1250.0], # Chain 0 Horseshoe South Wing
	[-1250.0, -650.0, -750.0, -600.0], # Chain 1 Mohaine North Rim
	[-750.0, -600.0, -650.0, -660.0],
	[-450.0, -1250.0, -400.0, -900.0], # Chain 2 SW Desolation East Wall
	[-400.0, -900.0, -450.0, -650.0],
	[-780.0, -100.0, 0.0, -100.0],     # Chain 3 Central Great Divide
	[0.0, -100.0, 420.0, -100.0],
	[420.0, -100.0, 750.0, -60.0],
	[750.0, -60.0, 950.0, -100.0],
	[420.0, -100.0, 420.0, -650.0],    # Chain 4 SE Meridian Wall
	[-1250.0, 500.0, -780.0, 500.0],   # Chain 5A Rust-Gorge North Spur
	[150.0, 1250.0, 150.0, 500.0],     # Chain 5B Citadel L-Bastion West
	[150.0, 500.0, 620.0, 500.0]       # Chain 5B Citadel L-Bastion South
]

# Crossing canyon defiles for barrier carving (Nodes 1->2, 2->3, 3->4, 3->6, 5->7)
const DEFILE_PASSES: Array = [
	[-450.0, -800.0, -250.0, -650.0], # Node 1 -> 2 (pass_sw_to_salt)
	[-100.0, -420.0, -30.0, -150.0],  # Node 2 -> 3 (pass_salt_to_cradle)
	[-150.0, 15.0, -500.0, 40.0],     # Node 3 -> 4 (pass_cradle_to_gorge)
	[150.0, 15.0, 500.0, 40.0],       # Node 3 -> 6 (pass_cradle_to_east)
	[150.0, 650.0, 500.0, 650.0]      # Node 5 -> 7 (pass_north_to_monolith)
]

static func _dist_to_segment(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	var dx := bx - ax
	var dz := bz - az
	var l2 := dx * dx + dz * dz
	if l2 == 0.0:
		return Vector2(px - ax, pz - az).length()
	var t := clampf(((px - ax) * dx + (pz - az) * dz) / l2, 0.0, 1.0)
	return Vector2(px - (ax + t * dx), pz - (az + t * dz)).length()

static func segment_distance_2d(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	return _dist_to_segment(px, pz, ax, az, bx, bz)

static func calculate_barrier_elevation(world_x: float, world_z: float) -> float:
	var d_barrier := 99999.0
	for seg in BARRIER_SEGMENTS:
		var d: float = _dist_to_segment(world_x, world_z, float(seg[0]), float(seg[1]), float(seg[2]), float(seg[3]))
		if d < d_barrier:
			d_barrier = d

	if d_barrier >= 82.0:
		return 0.0

	var mesa_profile := 1.0 - smoothstep(26.0, 82.0, d_barrier)
	var ridge_noise := absf(_fbm(Vector2(world_x * 0.014, world_z * 0.014), 2) * 2.0 - 1.0)
	var erosion := 1.0 - 0.10 * ridge_noise
	var h_barrier := 52.0 * mesa_profile * erosion

	var d_pass := 99999.0
	for p in DEFILE_PASSES:
		var pd: float = _dist_to_segment(world_x, world_z, float(p[0]), float(p[1]), float(p[2]), float(p[3]))
		if pd < d_pass:
			d_pass = pd

	var carve_mask := smoothstep(16.0, 40.0, d_pass)

	# Node 0 Sanctuary Clearing Mask at (-1180.0, -1180.0): inner 28m = 0.0, outer 48m = 1.0
	var d_sanctuary := Vector2(world_x - (-1180.0), world_z - (-1180.0)).length()
	var sanctuary_mask := smoothstep(28.0, 48.0, d_sanctuary)
	return h_barrier * carve_mask * sanctuary_mask

static func get_height_at(world_x: float, world_z: float) -> float:
	return sample_height(world_x, world_z)

static func sample_height(world_x: float, world_z: float) -> float:
	var wind_dir := 3.93
	var wx := cos(wind_dir)
	var wz := sin(wind_dir)
	var wind_u := world_x * wx + world_z * wz
	var wind_v := -world_x * wz + world_z * wx

	# 1. Large-scale dune roll (2 octaves) + Playa / Salt-Sink basin flattening
	var dune_h := _fbm(Vector2(wind_u, wind_v) * 0.008, 2) * 2.0 - 1.0
	if dune_h < -0.15:
		dune_h = lerpf(dune_h, -0.22, 0.55)

	# 2. Wind-carved yardang & stepped mesa ripples zeroed out
	var yardang_h := 0.0

	# 3. Mid-scale gravel washboard ripples zeroed out
	var gravel_h := 0.0

	# 3b. Specialized Directional Noise Transform for SW Desolation Quadrant (X: -800 to -400, Z: -1000 to -600)
	# Carves asymmetric wind-swept sand dunes and low hardpan bedrock ridges.
	# Smoothly blends to zero where it meets the Mohaine Way-Bunker threshold at (-1020, -820).
	var sw_x_mask := smoothstep(-850.0, -700.0, world_x) * (1.0 - smoothstep(-450.0, -350.0, world_x))
	var sw_z_mask := smoothstep(-1050.0, -950.0, world_z) * (1.0 - smoothstep(-650.0, -550.0, world_z))
	var dist_to_bunker := Vector2(world_x - (-1000.0), world_z - (-800.0)).length()
	var bunker_clearance := smoothstep(140.0, 190.0, dist_to_bunker)
	var sw_mask := sw_x_mask * sw_z_mask * bunker_clearance

	var sw_sculpt := 0.0
	if sw_mask > 0.001:
		var dune_coord := wind_u * 0.018 + _fbm(Vector2(wind_u * 0.008, wind_v * 0.022), 2) * 0.75
		var asym_dune := sin(dune_coord) + 0.38 * sin(2.0 * dune_coord - 0.4)
		var hardpan_noise := _fbm(Vector2(wind_u * 0.008, wind_v * 0.038), 3)
		var hardpan_ridge := smoothstep(0.44, 0.72, hardpan_noise)
		var stepped_hardpan := floorf(hardpan_ridge * 2.5) / 2.5
		var hardpan_h := lerpf(hardpan_ridge, stepped_hardpan, 0.5) * 1.85
		sw_sculpt = (asym_dune * 2.4 + hardpan_h) * sw_mask

	# 3c. Specialized Playa Flattening for Node 2 (Dead-Creek Salt Flats: X in [-400, 0], Z in [-800, -300])
	# Flattens and clamps the terrain to a dead-level, low-elevation salt pan (-0.45m playa floor).
	var salt_x_mask := smoothstep(-440.0, -360.0, world_x) * (1.0 - smoothstep(-40.0, 40.0, world_x))
	var salt_z_mask := smoothstep(-840.0, -760.0, world_z) * (1.0 - smoothstep(-340.0, -260.0, world_z))
	var salt_playa_mask := salt_x_mask * salt_z_mask

	# 3d. Specialized Caliche Cradle & Thinny Overlook Sculpting (Node 3: X in [-200, 200], Z in [-200, 200])
	# Terraced caliche limestone plateaus, dry arroyo erosion trenches, and NE scenic overlook (+140, +140)
	# with dramatic cliff drop-off into the Thinny chasm (+325, +325). Safe navigable crossroads at (0, 0).
	var cradle_x_mask := smoothstep(-250.0, -170.0, world_x) * (1.0 - smoothstep(190.0, 260.0, world_x))
	var cradle_z_mask := smoothstep(-250.0, -170.0, world_z) * (1.0 - smoothstep(190.0, 260.0, world_z))
	var cradle_mask := cradle_x_mask * cradle_z_mask

	var cradle_sculpt := 0.0
	if cradle_mask > 0.001:
		var d_cradle_center := Vector2(world_x, world_z).length()
		var crossroads_smooth := 1.0 - smoothstep(28.0, 62.0, d_cradle_center)

		# Arroyo trenching: ridged noise forming dry erosion gullies
		var arroyo_noise := absf(_fbm(Vector2(world_x, world_z) * 0.016, 3) * 2.0 - 1.0)
		var arroyo_trench := (1.0 - smoothstep(0.04, 0.22, arroyo_noise)) * 3.4

		# Terraced limestone plateaus: quantized steps
		var plateau_raw := _fbm(Vector2(world_x * 0.012, world_z * 0.012), 3)
		var terrace_quant := floorf(plateau_raw * 3.0) / 3.0
		var plateau_h := lerpf(plateau_raw, terrace_quant, 0.75) * 4.2

		# NE Overlook promontory at (+140, +140) bordering Thinny Abyss (+325, +325)
		var d_overlook := Vector2(world_x - 140.0, world_z - 140.0).length()
		var overlook_promontory := (1.0 - smoothstep(0.0, 48.0, d_overlook)) * 4.8

		# Chasm cliff drop-off past the overlook towards the Thinny Abyss
		var abyss_dir_dot := (world_x - 140.0) + (world_z - 140.0)
		var chasm_cliff_drop := smoothstep(8.0, 60.0, abyss_dir_dot) * 16.5

		var raw_cradle := (plateau_h - arroyo_trench + overlook_promontory - chasm_cliff_drop)
		# Smoothly blend down to safe, navigable crossroads basin near (0, 0)
		cradle_sculpt = lerpf(raw_cradle, 0.0, crossroads_smooth) * cradle_mask

	# 3e. Specialized Rust-Gorge Defile Canyon Sculpting (Node 4: X in [-800, -400], Z in [-100, +400])
	# Claustrophobic vertical oxidized sandstone canyon walls (+14m to +20m) flanking a winding,
	# navigable canyon floor (-1.5m to +1.0m) with rocky talus undulations.
	var gorge_x_mask := smoothstep(-850.0, -750.0, world_x) * (1.0 - smoothstep(-450.0, -350.0, world_x))
	var gorge_z_mask := smoothstep(-150.0, -50.0, world_z) * (1.0 - smoothstep(350.0, 450.0, world_z))
	var west_gorge_mask := gorge_x_mask * gorge_z_mask

	var gorge_sculpt := 0.0
	if west_gorge_mask > 0.001:
		var corridor_x := -650.0 + 45.0 * sin(world_z * 0.018) + 20.0 * cos(world_z * 0.040)
		var lat_dist := absf(world_x - corridor_x)

		# Winding canyon floor (-1.5m to +1.0m with rocky talus undulations)
		var floor_talus := (_fbm(Vector2(world_x, world_z) * 0.045, 3) * 2.0 - 1.0) * 0.85
		var floor_h := -0.65 + floor_talus

		# Steep vertical sandstone cliff walls (+14m to +20m) with stepped sedimentary ledges
		var wall_t := clampf((lat_dist - 24.0) / 44.0, 0.0, 1.0)
		var wall_smooth := wall_t * wall_t * (3.0 - 2.0 * wall_t)
		var ledge_step := floorf(wall_smooth * 4.0) / 4.0
		var cliff_h := lerpf(wall_smooth, ledge_step, 0.40) * 18.5

		var raw_gorge := floor_h + cliff_h
		var pass_east := smoothstep(-480.0, -410.0, world_x)
		gorge_sculpt = (raw_gorge * (1.0 - pass_east * 0.55)) * west_gorge_mask

	# 3f. Specialized Bleached Alkali Sink Saucer Sculpting (Node 5: X in [-300, 300], Z in [400, 900])
	# Concave saucer-shaped depression dipping to -1.8m across the central alkali pan (r < 160m around (0, 650)),
	# ringed by badland hills rising +5.5m to +8.5m (r in [160m, 280m]).
	# Level foundation pad at (+45, +680) for the Ka Beacon Monolith.
	var alkali_x_mask := smoothstep(-350.0, -250.0, world_x) * (1.0 - smoothstep(250.0, 350.0, world_x))
	var alkali_z_mask := smoothstep(350.0, 450.0, world_z) * (1.0 - smoothstep(850.0, 950.0, world_z))
	var north_alkali_mask := alkali_x_mask * alkali_z_mask

	var alkali_sculpt := 0.0
	if north_alkali_mask > 0.001:
		var d_basin := Vector2(world_x, world_z - 650.0).length()
		var pan_dip := (1.0 - smoothstep(0.0, 160.0, d_basin)) * -1.8
		var rim_t := smoothstep(140.0, 220.0, d_basin) * (1.0 - smoothstep(250.0, 320.0, d_basin))
		var gully_n := absf(_fbm(Vector2(world_x, world_z) * 0.022, 3) * 2.0 - 1.0)
		var badland_hills := rim_t * (5.5 + gully_n * 3.0)

		var d_monolith := Vector2(world_x - 45.0, world_z - 680.0).length()
		var pad_smooth := 1.0 - smoothstep(8.0, 22.0, d_monolith)
		var raw_alkali := pan_dip + badland_hills
		alkali_sculpt = lerpf(raw_alkali, -1.2, pad_smooth) * north_alkali_mask

	# 3g. Specialized The Great Shifting Erg Mega-Dune Sculpting (Node 6: X in [400, 900], Z in [-300, 300])
	# High-amplitude asymmetrical mega-dunes with razor-sharp ridged crests (1.0 - abs(sin(...))) rising +8.0m to +15.5m
	# above deep interdune troughs (-2.0m). Partial wind-scoop pocket around (+680, -20) to seat Old-Ones megastructure ruin.
	var east_x_mask := smoothstep(350.0, 450.0, world_x) * (1.0 - smoothstep(850.0, 950.0, world_x))
	var east_z_mask := smoothstep(-350.0, -250.0, world_z) * (1.0 - smoothstep(250.0, 350.0, world_z))
	var east_dunes_mask := east_x_mask * east_z_mask

	var east_sculpt := 0.0
	if east_dunes_mask > 0.001:
		var dune_phase := wind_u * 0.024 + _fbm(Vector2(wind_u * 0.006, wind_v * 0.016), 2) * 1.2
		var sharp_crest := 1.0 - absf(sin(dune_phase))
		var asym_crest := pow(sharp_crest, 1.35) * (1.0 + 0.25 * cos(dune_phase))
		var ridge_n := _fbm(Vector2(wind_u * 0.012, wind_v * 0.024), 2)
		var mega_dune_h := lerpf(-2.0, 14.5 + ridge_n * 2.0, clampf(asym_crest, 0.0, 1.0))

		# Wind-scoop pocket around (+680, -20) to seat Old-Ones megastructure ruin
		var d_ruin := Vector2(world_x - 680.0, world_z - (-20.0)).length()
		var scoop_factor := 1.0 - smoothstep(12.0, 44.0, d_ruin)
		var seated_dune := lerpf(mega_dune_h, 1.8, scoop_factor * 0.70)
		east_sculpt = seated_dune * east_dunes_mask

	# 3h. Specialized Tower Threshold Stepped Basalt Terraces (Node 7: X in [400, 900], Z in [400, 900])
	# Quantized stepped volcanic basalt terraces ascending from +2.0m at outer approach (r in [110m, 220m])
	# up to +9.0m commanding citadel foundation plateau at (+700, +700), dissected by cooling fissures dipping to -2.2m.
	var tower_x_mask := smoothstep(350.0, 450.0, world_x) * (1.0 - smoothstep(850.0, 950.0, world_x))
	var tower_z_mask := smoothstep(350.0, 450.0, world_z) * (1.0 - smoothstep(850.0, 950.0, world_z))
	var tower_threshold_mask := tower_x_mask * tower_z_mask

	var tower_sculpt := 0.0
	if tower_threshold_mask > 0.001:
		var d_tower := Vector2(world_x - 700.0, world_z - 700.0).length()
		var ascent_t := clampf((240.0 - d_tower) / 200.0, 0.0, 1.0)
		var raw_ascent := lerpf(2.0, 9.0, ascent_t)
		var stepped_ascent := floorf(raw_ascent * 4.0) / 4.0
		var terrace_h := lerpf(raw_ascent, stepped_ascent, 0.75)

		# Cooling-fissure cracks dipping to -2.2m
		var fissure_n := absf(_fbm(Vector2(world_x, world_z) * 0.035, 3) * 2.0 - 1.0)
		var fissure_dip := (1.0 - smoothstep(0.04, 0.16, fissure_n)) * 4.2

		# Citadel foundation plateau pad at (+700, +700)
		var pad_smooth := 1.0 - smoothstep(22.0, 52.0, d_tower)
		var raw_tower := lerpf(terrace_h - fissure_dip, 9.0, pad_smooth)
		tower_sculpt = raw_tower * tower_threshold_mask

	var base_h := (dune_h + yardang_h + gravel_h) * 2.5 + sw_sculpt + cradle_sculpt + gorge_sculpt + alkali_sculpt + east_sculpt + tower_sculpt

	# 4. Basin Floor Flattening & Perimeter Ridge Rings (8-Node Registry)
	var floor_factor := 0.0
	var max_ridge := 0.0
	for b in BASINS:
		var d := Vector2(world_x - b.x, world_z - b.y).length()
		var ratio := d / b.z
		if ratio < 0.75:
			var f := (0.75 - ratio) / 0.75
			if f > floor_factor:
				floor_factor = f
		# Circular crater / perimeter ridge rings zeroed out

	# Maintain towering cliff wall prominence inside the gorge defile
	if west_gorge_mask > 0.001:
		floor_factor *= (1.0 - west_gorge_mask * 0.65)

	# Preserve concave saucer dip inside the bleached alkali sink
	if north_alkali_mask > 0.001:
		floor_factor *= (1.0 - north_alkali_mask * 0.50)

	# Preserve towering mega-dune amplitude inside The Great Shifting Erg
	if east_dunes_mask > 0.001:
		floor_factor *= (1.0 - east_dunes_mask * 0.70)
		max_ridge *= (1.0 - east_dunes_mask * 0.60)

	# Preserve stepped basalt terrace prominence inside Tower Threshold
	if tower_threshold_mask > 0.001:
		floor_factor *= (1.0 - tower_threshold_mask * 0.65)
		max_ridge *= (1.0 - tower_threshold_mask * 0.50)

	# Suppress perimeter ridges in interior of the dead-level salt playa
	if salt_playa_mask > 0.001:
		max_ridge *= (1.0 - salt_playa_mask * 0.90)

	# 5. Canyon Defile Pass Carving (9 Connections)
	var min_pass_ratio := 999.0
	var pass_carve := 0.0
	for p in PASSES:
		var pd: float = _dist_to_segment(world_x, world_z, float(p[0]), float(p[1]), float(p[2]), float(p[3]))
		var hw: float = float(p[4])
		var pr: float = pd / (hw * 2.0)
		if pr < min_pass_ratio:
			min_pass_ratio = pr
		if pd < hw:
			var c: float = (hw - pd) / hw
			if c > pass_carve:
				pass_carve = c

	if min_pass_ratio < 1.0:
		max_ridge *= min_pass_ratio

	# 6. Thinny Beam Abyss (+325.0, +325.0, R=160.0m)
	var d_abyss := Vector2(world_x - 325.0, world_z - 325.0).length()
	var abyss_disp := 0.0
	if d_abyss < 160.0:
		var t_abyss := clampf((160.0 - d_abyss) / 50.0, 0.0, 1.0)
		abyss_disp = -28.0 * (t_abyss * t_abyss * (3.0 - 2.0 * t_abyss))

	# Return combined procedural height clamped to dead-level playa inside Dead-Creek Salt Flats,
	# plus the deterministic hybrid terrain escarpment barrier elevation.
	var raw_h := lerpf(base_h, -0.35, floor_factor * 0.60) + max_ridge - pass_carve * 0.35 + abyss_disp
	var base_ground := lerpf(raw_h, -0.45, salt_playa_mask * 0.95)
	return base_ground + calculate_barrier_elevation(world_x, world_z)

## Exact port of hash2() in wasteland_terrain.gdshader:
##   p = fract(p * vec2(127.1, 311.7)); p += dot(p, p + 19.31); return fract(p.x * p.y);
static func _hash2(p: Vector2) -> float:
	var q := Vector2(fposmod(p.x * 127.1, 1.0), fposmod(p.y * 311.7, 1.0))
	var d := q.dot(q + Vector2(19.31, 19.31))
	q += Vector2(d, d)
	return fposmod(q.x * q.y, 1.0)

static func _value_noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash2(i)
	var b := _hash2(i + Vector2(1.0, 0.0))
	var c := _hash2(i + Vector2(0.0, 1.0))
	var d := _hash2(i + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)

static func _fbm(p: Vector2, octaves: int) -> float:
	var v := 0.0
	var amp := 0.5
	var freq := 1.0
	for _i in range(octaves):
		v += _value_noise(p * freq) * amp
		amp *= 0.5
		freq *= 2.1
	return v

## World-space distance between heightmap samples. HeightMapShape3D always spaces
## samples 1 unit apart in local coordinates, so the owning CollisionShape3D must be
## scaled horizontally by this value: Vector3(spacing, 1.0, spacing) to span the 2500x2500 world.
static func heightmap_spacing(resolution: int = 626, world_size: float = 2500.0) -> float:
	return world_size / float(resolution - 1)

## Builds a square heightmap covering world_size x world_size, centered on the origin.
## Heights are stored directly in world-space meters (1.0 = 1m). The owning CollisionShape3D
## applies scale = Vector3(spacing, 1.0, spacing) to map local X/Z samples to world coordinates.
static func generate_heightmap(resolution: int = 626, world_size: float = 2500.0) -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = resolution
	shape.map_depth = resolution

	var data := PackedFloat32Array()
	data.resize(resolution * resolution)

	var spacing := heightmap_spacing(resolution, world_size)
	var half_size := world_size * 0.5

	for z in range(resolution):
		var world_z := (z * spacing) - half_size
		for x in range(resolution):
			var world_x := (x * spacing) - half_size
			data[z * resolution + x] = sample_height(world_x, world_z)

	shape.map_data = data
	return shape
