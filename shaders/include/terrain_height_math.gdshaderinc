// terrain_height_math.gdshaderinc
// Procedural noise functions, basin/ridge topography, and sample_terrain_height()
// Provides 1:1 mathematical parity with TerrainCollisionGenerator (terrain_collision.gd)

// ─── Noise Helpers ─────────────────────────────────────────────────────────

// Pseudo-random 2D hash matching GDScript _hash2
float hash2(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.31);
	return fract(p.x * p.y);
}

// Smooth bilinear value noise [0..1]
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Multi-octave FBM
float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < octaves; i++) {
		v += value_noise(p * freq) * amp;
		amp *= 0.5;
		freq *= 2.1;
	}
	return v;
}

// Craze / crack pattern: Worley-style cell distance
float craze_pattern(vec2 p) {
	vec2 i = floor(p);
	float min_d = 10.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = neighbor + vec2(hash2(i + neighbor), hash2(i + neighbor + vec2(17.0)));
			float d = length(p - i - point);
			min_d = min(min_d, d);
		}
	}
	return min_d;
}

// Procedural Voronoi polygonal cell pattern: x = center dist (F1), y = edge dist (F2 - F1)
vec2 voronoi_polygons(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = neighbor + vec2(hash2(i + neighbor), hash2(i + neighbor + vec2(17.0)));
			float d = length(neighbor + point - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d1, d2 - d1);
}

// ─── Topography Modifiers ──────────────────────────────────────────────────

void check_basin(vec2 p, vec2 center, float radius, inout float floor_f, inout float ridge_h) {
	float d = length(p - center);
	float ratio = d / radius;
	if (ratio < 0.75) {
		float f = (0.75 - ratio) / 0.75;
		floor_f = max(floor_f, f);
	}
	// Circular crater / perimeter ridge rings zeroed out
}

float segment_distance_2d(vec2 p, vec2 a, vec2 b) {
	vec2 ba = b - a;
	vec2 pa = p - a;
	float l2 = dot(ba, ba);
	float t = clamp(dot(pa, ba) / (l2 > 0.0 ? l2 : 1.0), 0.0, 1.0);
	return length(pa - ba * t);
}

void check_pass(vec2 p, vec2 a, vec2 b, float hw, inout float min_pass_r, inout float carve) {
	float pd = segment_distance_2d(p, a, b);
	float pr = pd / (hw * 2.0);
	min_pass_r = min(min_pass_r, pr);
	if (pd < hw) {
		carve = max(carve, (hw - pd) / hw);
	}
}

// ─── 6 Escarpment Barrier Chains (14 Segments) & Canyon Defiles ────────────
const vec4 BARRIER_SEG_H0 = vec4(-1250.0, -1100.0, -1225.0, -1225.0);
const vec4 BARRIER_SEG_H1 = vec4(-1225.0, -1225.0, -1100.0, -1250.0);
const vec4 BARRIER_SEG_0 = vec4(-1250.0, -650.0, -750.0, -600.0);
const vec4 BARRIER_SEG_1 = vec4(-750.0, -600.0, -650.0, -660.0);
const vec4 BARRIER_SEG_2 = vec4(-450.0, -1250.0, -400.0, -900.0);
const vec4 BARRIER_SEG_3 = vec4(-400.0, -900.0, -450.0, -650.0);
const vec4 BARRIER_SEG_4 = vec4(-780.0, -100.0, 0.0, -100.0);
const vec4 BARRIER_SEG_5 = vec4(0.0, -100.0, 420.0, -100.0);
const vec4 BARRIER_SEG_6 = vec4(420.0, -100.0, 750.0, -60.0);
const vec4 BARRIER_SEG_7 = vec4(750.0, -60.0, 950.0, -100.0);
const vec4 BARRIER_SEG_8 = vec4(420.0, -100.0, 420.0, -650.0);
const vec4 BARRIER_SEG_9 = vec4(-1250.0, 500.0, -780.0, 500.0);
const vec4 BARRIER_SEG_10 = vec4(150.0, 1250.0, 150.0, 500.0);
const vec4 BARRIER_SEG_11 = vec4(150.0, 500.0, 620.0, 500.0);

const vec4 DEFILE_PASS_0 = vec4(-450.0, -800.0, -250.0, -650.0);
const vec4 DEFILE_PASS_1 = vec4(-100.0, -420.0, -30.0, -150.0);
const vec4 DEFILE_PASS_2 = vec4(-150.0, 15.0, -500.0, 40.0);
const vec4 DEFILE_PASS_3 = vec4(150.0, 15.0, 500.0, 40.0);
const vec4 DEFILE_PASS_4 = vec4(150.0, 650.0, 500.0, 650.0);

float calculate_barrier_elevation(vec2 p) {
	float d_barrier = segment_distance_2d(p, BARRIER_SEG_H0.xy, BARRIER_SEG_H0.zw);
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_H1.xy, BARRIER_SEG_H1.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_0.xy, BARRIER_SEG_0.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_1.xy, BARRIER_SEG_1.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_2.xy, BARRIER_SEG_2.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_3.xy, BARRIER_SEG_3.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_4.xy, BARRIER_SEG_4.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_5.xy, BARRIER_SEG_5.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_6.xy, BARRIER_SEG_6.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_7.xy, BARRIER_SEG_7.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_8.xy, BARRIER_SEG_8.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_9.xy, BARRIER_SEG_9.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_10.xy, BARRIER_SEG_10.zw));
	d_barrier = min(d_barrier, segment_distance_2d(p, BARRIER_SEG_11.xy, BARRIER_SEG_11.zw));

	if (d_barrier >= 82.0) {
		return 0.0;
	}

	float mesa_profile = 1.0 - smoothstep(26.0, 82.0, d_barrier);
	float ridge_noise = abs(fbm(p * 0.014, 2) * 2.0 - 1.0);
	float erosion = 1.0 - 0.10 * ridge_noise;
	float h_barrier = 52.0 * mesa_profile * erosion;

	float d_pass = segment_distance_2d(p, DEFILE_PASS_0.xy, DEFILE_PASS_0.zw);
	d_pass = min(d_pass, segment_distance_2d(p, DEFILE_PASS_1.xy, DEFILE_PASS_1.zw));
	d_pass = min(d_pass, segment_distance_2d(p, DEFILE_PASS_2.xy, DEFILE_PASS_2.zw));
	d_pass = min(d_pass, segment_distance_2d(p, DEFILE_PASS_3.xy, DEFILE_PASS_3.zw));
	d_pass = min(d_pass, segment_distance_2d(p, DEFILE_PASS_4.xy, DEFILE_PASS_4.zw));

	float carve_mask = smoothstep(16.0, 40.0, d_pass);

	// Node 0 Sanctuary Clearing Mask at (-1180.0, -1180.0): inner 28m = 0.0, outer 48m = 1.0
	float d_sanctuary = length(p - vec2(-1180.0, -1180.0));
	float sanctuary_mask = smoothstep(28.0, 48.0, d_sanctuary);
	return h_barrier * carve_mask * sanctuary_mask;
}

void evaluate_topography(vec2 p, out float floor_factor, out float max_ridge, out float pass_carve, out float abyss_disp) {
	floor_factor = 0.0;
	max_ridge = 0.0;
	float min_pass_r = 999.0;
	pass_carve = 0.0;
	abyss_disp = 0.0;

	// 8 Basins (Node 0 Safe Zone R=150m, 7 Macro Biomes R=250m)
	check_basin(p, vec2(-1000.0, -800.0), 150.0, floor_factor, max_ridge); // Node 0: waystation_sanctuary
	check_basin(p, vec2(-550.0, -900.0),  250.0, floor_factor, max_ridge); // Node 1: sw_desolation
	check_basin(p, vec2(-150.0, -550.0),  250.0, floor_factor, max_ridge); // Node 2: south_salt
	check_basin(p, vec2(0.0, 0.0),        250.0, floor_factor, max_ridge); // Node 3: cradle
	check_basin(p, vec2(-650.0, 50.0),    250.0, floor_factor, max_ridge); // Node 4: west_gorge
	check_basin(p, vec2(0.0, 650.0),      250.0, floor_factor, max_ridge); // Node 5: north_alkali
	check_basin(p, vec2(650.0, 50.0),     250.0, floor_factor, max_ridge); // Node 6: east_dunes
	check_basin(p, vec2(650.0, 650.0),    250.0, floor_factor, max_ridge); // Node 7: monolith_pass

	// 9 Canyon Passes
	check_pass(p, vec2(-900.0, -820.0), vec2(-650.0, -880.0), 18.0, min_pass_r, pass_carve); // pass_sanctuary_to_sw
	check_pass(p, vec2(-450.0, -800.0), vec2(-250.0, -650.0), 18.0, min_pass_r, pass_carve); // pass_sw_to_salt
	check_pass(p, vec2(-100.0, -420.0), vec2(-30.0, -150.0),  18.0, min_pass_r, pass_carve); // pass_salt_to_cradle
	check_pass(p, vec2(-150.0, 15.0),   vec2(-500.0, 40.0),   16.0, min_pass_r, pass_carve); // pass_cradle_to_gorge
	check_pass(p, vec2(0.0, 150.0),     vec2(0.0, 500.0),     18.0, min_pass_r, pass_carve); // pass_cradle_to_north
	check_pass(p, vec2(150.0, 15.0),    vec2(500.0, 40.0),    18.0, min_pass_r, pass_carve); // pass_cradle_to_east
	check_pass(p, vec2(-500.0, 180.0),  vec2(-150.0, 520.0),  16.0, min_pass_r, pass_carve); // pass_gorge_to_north
	check_pass(p, vec2(150.0, 650.0),   vec2(500.0, 650.0),   18.0, min_pass_r, pass_carve); // pass_north_to_monolith
	check_pass(p, vec2(650.0, 150.0),   vec2(650.0, 500.0),   18.0, min_pass_r, pass_carve); // pass_east_to_monolith

	if (min_pass_r < 1.0) {
		max_ridge *= min_pass_r;
	}

	// Thinny Beam Abyss (+325.0, +325.0, R=160.0m)
	float d_abyss = length(p - vec2(325.0, 325.0));
	if (d_abyss < 160.0) {
		float t_abyss = clamp((160.0 - d_abyss) / 50.0, 0.0, 1.0);
		abyss_disp = -28.0 * (t_abyss * t_abyss * (3.0 - 2.0 * t_abyss));
	}
}

// Evaluates combined procedural height at a given world XZ coordinate
// (1:1 Synchronized with TerrainCollisionGenerator.sample_height in terrain_collision.gd)
float sample_terrain_height(vec2 world_xz) {
	float wx = cos(wind_direction);
	float wz = sin(wind_direction);
	vec2 wind_uv = vec2(dot(world_xz, vec2(wx, wz)), dot(world_xz, vec2(-wz, wx)));

	// 1. Large-scale dune roll (2 octaves) + Playa / Salt-Sink basin flattening
	float dune_h = fbm(wind_uv * dune_scale, 2) * 2.0 - 1.0;
	if (dune_h < -0.15) {
		dune_h = mix(dune_h, -0.22, playa_flatten);
	}

	// 2. Wind-carved yardang & stepped mesa ripples zeroed out
	float yardang_h = 0.0;

	// 3. Mid-scale gravel washboard ripples zeroed out
	float gravel_h = 0.0;

	// 3b. SW Desolation Quadrant (X: -800 to -400, Z: -1000 to -600)
	float sw_x_mask = smoothstep(-850.0, -700.0, world_xz.x) * (1.0 - smoothstep(-450.0, -350.0, world_xz.x));
	float sw_z_mask = smoothstep(-1050.0, -950.0, world_xz.y) * (1.0 - smoothstep(-650.0, -550.0, world_xz.y));
	float dist_to_bunker = length(world_xz - vec2(-1000.0, -800.0));
	float bunker_clearance = smoothstep(140.0, 190.0, dist_to_bunker);
	float sw_mask = sw_x_mask * sw_z_mask * bunker_clearance;

	float sw_sculpt = 0.0;
	if (sw_mask > 0.001) {
		float dune_coord = wind_uv.x * 0.018 + fbm(vec2(wind_uv.x * 0.008, wind_uv.y * 0.022), 2) * 0.75;
		float asym_dune = sin(dune_coord) + 0.38 * sin(2.0 * dune_coord - 0.4);
		float hardpan_noise = fbm(vec2(wind_uv.x * 0.008, wind_uv.y * 0.038), 3);
		float hardpan_ridge = smoothstep(0.44, 0.72, hardpan_noise);
		float stepped_hardpan = floor(hardpan_ridge * 2.5) / 2.5;
		float hardpan_h = mix(hardpan_ridge, stepped_hardpan, 0.5) * 1.85;
		sw_sculpt = (asym_dune * 2.4 + hardpan_h) * sw_mask;
	}

	// 3c. Node 2 (Dead-Creek Salt Flats: X in [-400, 0], Z in [-800, -300])
	float salt_x_mask = smoothstep(-440.0, -360.0, world_xz.x) * (1.0 - smoothstep(-40.0, 40.0, world_xz.x));
	float salt_z_mask = smoothstep(-840.0, -760.0, world_xz.y) * (1.0 - smoothstep(-340.0, -260.0, world_xz.y));
	float salt_playa_mask = salt_x_mask * salt_z_mask;

	// 3d. Node 3: Caliche Cradle & Thinny Overlook (X in [-200, 200], Z in [-200, 200])
	float cradle_x_mask = smoothstep(-250.0, -170.0, world_xz.x) * (1.0 - smoothstep(190.0, 260.0, world_xz.x));
	float cradle_z_mask = smoothstep(-250.0, -170.0, world_xz.y) * (1.0 - smoothstep(190.0, 260.0, world_xz.y));
	float cradle_mask = cradle_x_mask * cradle_z_mask;

	float cradle_sculpt = 0.0;
	if (cradle_mask > 0.001) {
		float d_cradle_center = length(world_xz);
		float crossroads_smooth = 1.0 - smoothstep(28.0, 62.0, d_cradle_center);
		float arroyo_noise = abs(fbm(world_xz * 0.016, 3) * 2.0 - 1.0);
		float arroyo_trench = (1.0 - smoothstep(0.04, 0.22, arroyo_noise)) * 3.4;
		float plateau_raw = fbm(world_xz * 0.012, 3);
		float terrace_quant = floor(plateau_raw * 3.0) / 3.0;
		float plateau_h = mix(plateau_raw, terrace_quant, 0.75) * 4.2;
		float d_overlook = length(world_xz - vec2(140.0, 140.0));
		float overlook_promontory = (1.0 - smoothstep(0.0, 48.0, d_overlook)) * 4.8;
		float abyss_dir_dot = (world_xz.x - 140.0) + (world_xz.y - 140.0);
		float chasm_cliff_drop = smoothstep(8.0, 60.0, abyss_dir_dot) * 16.5;
		float raw_cradle = (plateau_h - arroyo_trench + overlook_promontory - chasm_cliff_drop);
		cradle_sculpt = mix(raw_cradle, 0.0, crossroads_smooth) * cradle_mask;
	}

	// 3e. Node 4: Rust-Gorge Defile Canyon (X in [-800, -400], Z in [-100, +400])
	float gorge_x_mask = smoothstep(-850.0, -750.0, world_xz.x) * (1.0 - smoothstep(-450.0, -350.0, world_xz.x));
	float gorge_z_mask = smoothstep(-150.0, -50.0, world_xz.y) * (1.0 - smoothstep(350.0, 450.0, world_xz.y));
	float west_gorge_mask = gorge_x_mask * gorge_z_mask;

	float gorge_sculpt = 0.0;
	if (west_gorge_mask > 0.001) {
		float corridor_x = -650.0 + 45.0 * sin(world_xz.y * 0.018) + 20.0 * cos(world_xz.y * 0.040);
		float lat_dist = abs(world_xz.x - corridor_x);
		float floor_talus = (fbm(world_xz * 0.045, 3) * 2.0 - 1.0) * 0.85;
		float floor_h = -0.65 + floor_talus;
		float wall_t = clamp((lat_dist - 24.0) / 44.0, 0.0, 1.0);
		float wall_smooth = wall_t * wall_t * (3.0 - 2.0 * wall_t);
		float ledge_step = floor(wall_smooth * 4.0) / 4.0;
		float cliff_h = mix(wall_smooth, ledge_step, 0.40) * 18.5;
		float raw_gorge = floor_h + cliff_h;
		float pass_east = smoothstep(-480.0, -410.0, world_xz.x);
		gorge_sculpt = (raw_gorge * (1.0 - pass_east * 0.55)) * west_gorge_mask;
	}

	// 3f. Node 5: Bleached Alkali Sink (X in [-300, 300], Z in [400, 900])
	float alkali_x_mask = smoothstep(-350.0, -250.0, world_xz.x) * (1.0 - smoothstep(250.0, 350.0, world_xz.x));
	float alkali_z_mask = smoothstep(350.0, 450.0, world_xz.y) * (1.0 - smoothstep(850.0, 950.0, world_xz.y));
	float north_alkali_mask = alkali_x_mask * alkali_z_mask;

	float alkali_sculpt = 0.0;
	if (north_alkali_mask > 0.001) {
		float d_basin = length(world_xz - vec2(0.0, 650.0));
		float pan_dip = (1.0 - smoothstep(0.0, 160.0, d_basin)) * -1.8;
		float rim_t = smoothstep(140.0, 220.0, d_basin) * (1.0 - smoothstep(250.0, 320.0, d_basin));
		float gully_n = abs(fbm(world_xz * 0.022, 3) * 2.0 - 1.0);
		float badland_hills = rim_t * (5.5 + gully_n * 3.0);
		float d_monolith = length(world_xz - vec2(45.0, 680.0));
		float pad_smooth = 1.0 - smoothstep(8.0, 22.0, d_monolith);
		float raw_alkali = pan_dip + badland_hills;
		alkali_sculpt = mix(raw_alkali, -1.2, pad_smooth) * north_alkali_mask;
	}

	// 3g. Node 6: The Great Shifting Erg (X in [400, 900], Z in [-300, 300])
	float east_x_mask = smoothstep(350.0, 450.0, world_xz.x) * (1.0 - smoothstep(850.0, 950.0, world_xz.x));
	float east_z_mask = smoothstep(-350.0, -250.0, world_xz.y) * (1.0 - smoothstep(250.0, 350.0, world_xz.y));
	float east_dunes_mask = east_x_mask * east_z_mask;

	float east_sculpt = 0.0;
	if (east_dunes_mask > 0.001) {
		float dune_phase = wind_uv.x * 0.024 + fbm(vec2(wind_uv.x * 0.006, wind_uv.y * 0.016), 2) * 1.2;
		float sharp_crest = 1.0 - abs(sin(dune_phase));
		float asym_crest = pow(sharp_crest, 1.35) * (1.0 + 0.25 * cos(dune_phase));
		float ridge_n = fbm(vec2(wind_uv.x * 0.012, wind_uv.y * 0.024), 2);
		float mega_dune_h = mix(-2.0, 14.5 + ridge_n * 2.0, clamp(asym_crest, 0.0, 1.0));
		float d_ruin = length(world_xz - vec2(680.0, -20.0));
		float scoop_factor = 1.0 - smoothstep(12.0, 44.0, d_ruin);
		float seated_dune = mix(mega_dune_h, 1.8, scoop_factor * 0.70);
		east_sculpt = seated_dune * east_dunes_mask;
	}

	// 3h. Node 7: Tower Threshold Stepped Basalt Terraces (X in [400, 900], Z in [400, 900])
	float tower_x_mask = smoothstep(350.0, 450.0, world_xz.x) * (1.0 - smoothstep(850.0, 950.0, world_xz.x));
	float tower_z_mask = smoothstep(350.0, 450.0, world_xz.y) * (1.0 - smoothstep(850.0, 950.0, world_xz.y));
	float tower_threshold_mask = tower_x_mask * tower_z_mask;

	float tower_sculpt = 0.0;
	if (tower_threshold_mask > 0.001) {
		float d_tower = length(world_xz - vec2(700.0, 700.0));
		float ascent_t = clamp((240.0 - d_tower) / 200.0, 0.0, 1.0);
		float raw_ascent = mix(2.0, 9.0, ascent_t);
		float stepped_ascent = floor(raw_ascent * 4.0) / 4.0;
		float terrace_h = mix(raw_ascent, stepped_ascent, 0.75);
		float fissure_n = abs(fbm(world_xz * 0.035, 3) * 2.0 - 1.0);
		float fissure_dip = (1.0 - smoothstep(0.04, 0.16, fissure_n)) * 4.2;
		float pad_smooth = 1.0 - smoothstep(22.0, 52.0, d_tower);
		float raw_tower = mix(terrace_h - fissure_dip, 9.0, pad_smooth);
		tower_sculpt = raw_tower * tower_threshold_mask;
	}

	float base_h = (dune_h + yardang_h + gravel_h) * displacement_scale + sw_sculpt + cradle_sculpt + gorge_sculpt + alkali_sculpt + east_sculpt + tower_sculpt;

	// 4. Topography: Basin Floor, Perimeter Ridges, Canyon Passes, Thinny Abyss
	float floor_factor;
	float max_ridge;
	float pass_carve;
	float abyss_disp;
	evaluate_topography(world_xz, floor_factor, max_ridge, pass_carve, abyss_disp);

	if (salt_playa_mask > 0.001) {
		max_ridge *= (1.0 - salt_playa_mask * 0.90);
	}
	if (west_gorge_mask > 0.001) {
		floor_factor *= (1.0 - west_gorge_mask * 0.65);
	}
	if (north_alkali_mask > 0.001) {
		floor_factor *= (1.0 - north_alkali_mask * 0.50);
	}
	if (east_dunes_mask > 0.001) {
		floor_factor *= (1.0 - east_dunes_mask * 0.70);
		max_ridge *= (1.0 - east_dunes_mask * 0.60);
	}
	if (tower_threshold_mask > 0.001) {
		floor_factor *= (1.0 - tower_threshold_mask * 0.65);
		max_ridge *= (1.0 - tower_threshold_mask * 0.50);
	}

	float raw_h = mix(base_h, -0.35, floor_factor * 0.60) + max_ridge - pass_carve * 0.35 + abyss_disp;
	float base_ground = mix(raw_h, -0.45, salt_playa_mask * 0.95);
	return base_ground + calculate_barrier_elevation(world_xz);
}

