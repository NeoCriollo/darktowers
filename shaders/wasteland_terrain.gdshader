// wasteland_terrain.gdshader
// Multi-layer procedural terrain shader for "Dark Towers: The Path of Ka"
//
// Combines three surface biome layers using noise-driven blending:
//   Layer 0 – Cracked alkali flat (pale, high-roughness, craze-patterned)
//   Layer 1 – Wind-scoured gravel bed (dark grit, micro-bump)
//   Layer 2 – Rolling dune crest sand (warm ochre, low roughness, sparkle)
//   Layer 3 – Exposed sedimentary strata & bedrock ribs (banded, rugged)
//
// Scaled for the 2500m × 2500m macro-footprint (X, Z ∈ [-1250, +1250]).
// Provides 1:1 vertex displacement parity with TerrainCollisionGenerator (terrain_collision.gd).
// Procedural heightmath is modularly included from terrain_height_math.gdshaderinc.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

// ─── Global Displacement ───────────────────────────────────────────────────
uniform float displacement_scale : hint_range(0.0, 8.0, 0.05) = 2.5;
uniform float dune_scale : hint_range(0.001, 0.05, 0.001) = 0.008;
uniform float gravel_scale : hint_range(0.001, 0.1, 0.001) = 0.024;
uniform float micro_scale : hint_range(0.01, 0.5, 0.01) = 0.14;
uniform float wind_direction : hint_range(0.0, 6.2832, 0.01) = 3.93;
uniform float yardang_scale : hint_range(0.001, 0.05, 0.001) = 0.012;
uniform float yardang_strength : hint_range(0.0, 2.0, 0.05) = 0.65;
uniform float playa_flatten : hint_range(0.0, 1.0, 0.05) = 0.55;

// ─── Layer 0 – Cracked Playa & Salt Sink ───────────────────────────────────
uniform vec4 alkali_albedo : source_color = vec4(0.78, 0.73, 0.65, 1.0);
uniform vec4 salt_crust_albedo : source_color = vec4(0.90, 0.88, 0.83, 1.0);
uniform float alkali_roughness : hint_range(0.0, 1.0, 0.01) = 0.92;
uniform float alkali_crack_scale : hint_range(0.01, 2.0, 0.01) = 0.55;
uniform float alkali_crack_depth : hint_range(0.0, 1.0, 0.01) = 0.42;

// ─── Layer 1 – Gravel Bed & Scanned Ground Detail ──────────────────────────
uniform sampler2D texture_gravel_albedo : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D texture_gravel_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D texture_gravel_roughness : hint_roughness_r, filter_linear_mipmap_anisotropic;
uniform float detail_tile_macro : hint_range(0.01, 2.0, 0.01) = 0.15;
uniform float detail_tile_micro : hint_range(0.5, 20.0, 0.1) = 3.0;
uniform float detail_normal_depth : hint_range(0.0, 5.0, 0.05) = 1.0;
uniform float silica_dust_blend : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 gravel_albedo : source_color = vec4(0.34, 0.30, 0.26, 1.0);
uniform float gravel_roughness : hint_range(0.0, 1.0, 0.01) = 0.97;
uniform float gravel_bump_strength : hint_range(0.0, 4.0, 0.05) = 1.6;

// ─── Layer 2 – Dune Sand ───────────────────────────────────────────────────
uniform vec4 dune_albedo : source_color = vec4(0.62, 0.52, 0.36, 1.0);
uniform float dune_roughness : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float dune_sparkle : hint_range(0.0, 0.3, 0.005) = 0.04;

// ─── Layer 3 – Photogrammetry Rock Escarpments & Ridge Ribs ────────────────
uniform sampler2D texture_cliff_albedo : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D texture_cliff_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform float cliff_tile_macro : hint_range(0.005, 0.5, 0.005) = 0.035;
uniform float cliff_tile_micro : hint_range(0.05, 2.0, 0.01) = 0.22;
uniform float cliff_blend_sharpness : hint_range(1.0, 16.0, 0.5) = 4.0;
uniform vec4 strata_albedo_a : source_color = vec4(0.46, 0.34, 0.27, 1.0);
uniform vec4 strata_albedo_b : source_color = vec4(0.26, 0.23, 0.21, 1.0);
uniform float strata_roughness : hint_range(0.0, 1.0, 0.01) = 0.92;
uniform float strata_frequency : hint_range(0.5, 8.0, 0.1) = 2.8;

// ─── Blend / Transition ────────────────────────────────────────────────────
uniform float blend_sharpness : hint_range(1.0, 16.0, 0.5) = 5.0;

// ─── Wind Erosion Tint ─────────────────────────────────────────────────────
uniform vec4 wind_tint : source_color = vec4(0.58, 0.52, 0.44, 1.0);
uniform float wind_tint_strength : hint_range(0.0, 1.0, 0.01) = 0.18;

// ─── Procedural Noise & Terrain Displacement Math ──────────────────────────
#include "res://shaders/include/terrain_height_math.gdshaderinc"

// ─── Varyings ──────────────────────────────────────────────────────────────
varying vec3 v_world_normal;
varying vec2 v_world_xz;
varying float v_world_height;

// ─── Vertex Shader ──────────────────────────────────────────────────────────
void vertex() {
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	v_world_xz = world_xz;

	float h_center = sample_terrain_height(world_xz);
	VERTEX.y += h_center;
	v_world_height = h_center;

	float eps = 0.35;
	float dh_dx = (sample_terrain_height(world_xz + vec2(eps, 0.0)) - sample_terrain_height(world_xz - vec2(eps, 0.0))) / (2.0 * eps);
	float dh_dz = (sample_terrain_height(world_xz + vec2(0.0, eps)) - sample_terrain_height(world_xz - vec2(0.0, eps))) / (2.0 * eps);

	vec3 displaced_normal = normalize(vec3(-dh_dx, 1.0, -dh_dz));
	vec3 displaced_tangent = normalize(vec3(1.0, dh_dx, 0.0));
	vec3 displaced_binormal = normalize(cross(displaced_tangent, displaced_normal));

	NORMAL = displaced_normal;
	TANGENT = displaced_tangent;
	BINORMAL = displaced_binormal;
	v_world_normal = displaced_normal;
}

// ─── Fragment Shader ────────────────────────────────────────────────────────
void fragment() {
	vec2 world_xz = v_world_xz;
	vec3 world_norm = normalize(v_world_normal);

	float wx = cos(wind_direction);
	float wz = sin(wind_direction);
	vec2 wind_uv = vec2(dot(world_xz, vec2(wx, wz)), dot(world_xz, vec2(-wz, wx)));

	// 1. Bleached Alkali Salt Flats: south_salt (-150, -550) & north_alkali (0, +650)
	float d_salt1 = length(world_xz - vec2(-150.0, -550.0));
	float d_salt2 = length(world_xz - vec2(0.0, 650.0));
	float salt_mask = max(smoothstep(320.0, 70.0, d_salt1), smoothstep(320.0, 70.0, d_salt2));

	// 2. Wind-swept Erg Dunes & Yardang Ridges: east_dunes (+650, +50) & sw_desolation (-550, -900)
	float d_dune1 = length(world_xz - vec2(650.0, 50.0));
	float d_dune2 = length(world_xz - vec2(-550.0, -900.0));
	float dune_mask = max(smoothstep(320.0, 70.0, d_dune1), smoothstep(320.0, 70.0, d_dune2));

	// 3. Caliche Hardpan & Rocky Gorge: cradle (0, 0) & west_gorge (-650, +50)
	float d_gorge1 = length(world_xz - vec2(0.0, 0.0));
	float d_gorge2 = length(world_xz - vec2(-650.0, 50.0));
	float gorge_mask = max(smoothstep(320.0, 70.0, d_gorge1), smoothstep(320.0, 70.0, d_gorge2));

	// 4. Dark Obsidian around The Dark Tower (+700, +700) in monolith_pass (+650, +650)
	float d_tower = length(world_xz - vec2(700.0, 700.0));
	float obsidian_mask = smoothstep(380.0, 40.0, d_tower);

	// 5. Thinny Beam Abyss (+325, +325) Spatial Rift
	float d_abyss_frag = length(world_xz - vec2(325.0, 325.0));
	float abyss_mask = smoothstep(160.0, 40.0, d_abyss_frag);

	float dune_n   = fbm(world_xz * dune_scale * 1.2,  3);
	float gravel_n = fbm(world_xz * gravel_scale * 1.3, 4);
	float micro_n  = fbm(world_xz * micro_scale,        2);

	// Layer 0: Cracked Playa & Salt-Crystal Sink (Circular craze spots & rings disabled)
	float crack_mask = 1.0;
	float salt_rim = 0.0;
	vec4 playa_base = mix(alkali_albedo, salt_crust_albedo, salt_mask * 0.45);
	vec4 alkali_col = playa_base;
	float alkali_r  = alkali_roughness;

	// Layer 3: Photogrammetry Rock Ridge & Escarpment Triplanar Sampling
	vec3 world_pos = vec3(world_xz.x, v_world_height, world_xz.y);
	vec3 triplanar_w = pow(abs(world_norm), vec3(cliff_blend_sharpness));
	triplanar_w /= (triplanar_w.x + triplanar_w.y + triplanar_w.z + 0.0001);

	// Dual-Scale Photogrammetry Cliff Albedo (Macro scale for cliff formations + Micro for cracks)
	vec3 rock_macro = texture(texture_cliff_albedo, world_pos.zy * cliff_tile_macro).rgb * triplanar_w.x
	                + texture(texture_cliff_albedo, world_pos.xz * cliff_tile_macro).rgb * triplanar_w.y
	                + texture(texture_cliff_albedo, world_pos.xy * cliff_tile_macro).rgb * triplanar_w.z;

	vec3 rock_micro = texture(texture_cliff_albedo, world_pos.zy * cliff_tile_micro).rgb * triplanar_w.x
	                + texture(texture_cliff_albedo, world_pos.xz * cliff_tile_micro).rgb * triplanar_w.y
	                + texture(texture_cliff_albedo, world_pos.xy * cliff_tile_micro).rgb * triplanar_w.z;

	vec3 scanned_rock_base = mix(rock_macro, rock_micro, 0.42);
	// Warm desert rock tint matching RockPackLibrary DESERT_TINT Color(0.88, 0.80, 0.72)
	vec3 photogrammetry_cliff_albedo = scanned_rock_base * vec3(0.90, 0.82, 0.74);

	// Triplanar Normal Map for Rock Escarpments
	vec3 n_c_macro = (texture(texture_cliff_normal, world_pos.zy * cliff_tile_macro).rgb * 2.0 - 1.0) * triplanar_w.x
	               + (texture(texture_cliff_normal, world_pos.xz * cliff_tile_macro).rgb * 2.0 - 1.0) * triplanar_w.y
	               + (texture(texture_cliff_normal, world_pos.xy * cliff_tile_macro).rgb * 2.0 - 1.0) * triplanar_w.z;

	vec3 n_c_micro = (texture(texture_cliff_normal, world_pos.zy * cliff_tile_micro).rgb * 2.0 - 1.0) * triplanar_w.x
	               + (texture(texture_cliff_normal, world_pos.xz * cliff_tile_micro).rgb * 2.0 - 1.0) * triplanar_w.y
	               + (texture(texture_cliff_normal, world_pos.xy * cliff_tile_micro).rgb * 2.0 - 1.0) * triplanar_w.z;

	vec3 scanned_cliff_normal = normalize(n_c_macro + n_c_micro);

	float fold_warp = fbm(wind_uv * vec2(0.018, 0.045), 2) * 1.5;
	float strata_phase = v_world_height * (strata_frequency * 0.35) + fold_warp;
	float strata_band = smoothstep(0.35, 0.65, 0.5 + 0.5 * sin(strata_phase));
	// Natural geological shading: subtle mineral oxidation banding modulating the cracked rock albedo:
	vec3 mineral_band = mix(vec3(0.86, 0.82, 0.78), vec3(1.10, 1.05, 0.98), strata_band);
	vec4 strata_col = vec4(photogrammetry_cliff_albedo * mineral_band, 1.0);
	float strata_r = strata_roughness;

	float gx = 0.0;
	float gz = 0.0;

	float sparkle = pow(micro_n, 6.0) * (dune_sparkle + dune_mask * 0.04);
	vec4 dune_col = dune_albedo + vec4(sparkle);

	float slope = 1.0 - clamp(world_norm.y, 0.0, 1.0);
	float strata_w = clamp(smoothstep(0.09, 0.26, slope) + smoothstep(1.35, 2.75, v_world_height) * 0.65 + gorge_mask * 0.35, 0.0, 1.0);
	float basin_mask = clamp(smoothstep(-0.15, -0.45, v_world_height) + salt_mask * 0.60, 0.0, 1.0);
	float dune_w   = (1.0 - strata_w) * (1.0 - basin_mask * 0.85) * smoothstep(0.45, 0.75, dune_n) * (1.0 + dune_mask * 0.80);
	float gravel_w = (1.0 - strata_w - dune_w) * (1.0 - basin_mask * 0.75) * smoothstep(0.35, 0.6, gravel_n) * (1.0 + gorge_mask * 0.50);
	float alkali_w = max(0.0, 1.0 - strata_w - dune_w - gravel_w) * (1.0 + salt_mask * 1.20);

	strata_w = pow(max(0.0, strata_w), blend_sharpness * 0.25);
	dune_w   = pow(max(0.0, dune_w),   blend_sharpness * 0.25);
	gravel_w = pow(max(0.0, gravel_w), blend_sharpness * 0.25);
	alkali_w = pow(max(0.0, alkali_w), blend_sharpness * 0.25);
	float total_w = strata_w + dune_w + gravel_w + alkali_w + 0.0001;
	strata_w /= total_w; dune_w /= total_w; gravel_w /= total_w; alkali_w /= total_w;

	// ─── Dual-Scale 4K Scanned Ground Detail Sampling ───
	vec2 uv_macro = world_xz * detail_tile_macro;
	vec2 uv_micro = world_xz * detail_tile_micro;
	vec3 col_macro = texture(texture_gravel_albedo, uv_macro).rgb;
	vec3 col_micro = texture(texture_gravel_albedo, uv_micro).rgb;
	vec3 scanned_gravel_base = mix(col_macro, col_micro, 0.45);
	vec3 alkali_tint = vec3(0.85, 0.76, 0.62);
	vec3 scanned_gravel_col = mix(scanned_gravel_base, alkali_tint, silica_dust_blend);

	vec3 n_macro = texture(texture_gravel_normal, uv_macro).rgb * 2.0 - 1.0;
	vec3 n_micro = texture(texture_gravel_normal, uv_micro).rgb * 2.0 - 1.0;
	vec3 scanned_normal_ts = normalize(n_macro + n_micro);
	float scanned_rough = clamp(texture(texture_gravel_roughness, uv_micro).r + 0.15, 0.0, 1.0);

	vec4 ground_detail = vec4(scanned_gravel_col, 1.0);
	vec4 final_albedo = strata_col * strata_w + dune_col * dune_w + ground_detail * gravel_w + alkali_col * alkali_w;
	// Infuse the 4K photogrammetry texture across desert ground so flat synthetic sand colors don't mask it:
	final_albedo.rgb = mix(final_albedo.rgb * scanned_gravel_base * 1.55, final_albedo.rgb, strata_w * 0.95 + salt_mask * 0.45);
	float final_roughness = strata_r * strata_w + dune_roughness * dune_w + scanned_rough * gravel_w + alkali_r * alkali_w;
	final_roughness = mix(final_roughness, scanned_rough, 0.55 * (1.0 - salt_mask) * (1.0 - strata_w * 0.85));

	vec2 wind_vec = vec2(wx, wz);
	float windward_slope = dot(-world_norm.xz, wind_vec);
	float tint_mask = smoothstep(-0.02, 0.18, windward_slope) * wind_tint_strength;
	final_albedo.rgb = mix(final_albedo.rgb, wind_tint.rgb, tint_mask);

	// Node 1 SW Desolation Amber Haboob Tone Shift
	float sw_zone_mask = smoothstep(320.0, 90.0, d_dune2);
	if (sw_zone_mask > 0.001) {
		vec3 amber_haboob_tint = vec3(0.68, 0.44, 0.22);
		final_albedo.rgb = mix(final_albedo.rgb, amber_haboob_tint, sw_zone_mask * 0.28);
	}

	// Node 2 Dead-Creek Salt Flats (South Salt): Blinding White Playa & Salt Crust
	float south_salt_mask = smoothstep(340.0, 80.0, d_salt1);
	vec2 poly_uv = voronoi_polygons(world_xz * 0.75);
	float poly_rim = smoothstep(0.065, 0.015, poly_uv.y);
	float poly_fissure = smoothstep(0.012, 0.035, poly_uv.y);
	if (south_salt_mask > 0.001) {
		vec3 blinding_salt_white = mix(vec3(0.96, 0.95, 0.92), vec3(0.88, 0.86, 0.82), poly_rim * 0.35);
		final_albedo.rgb = mix(final_albedo.rgb, blinding_salt_white, south_salt_mask * 0.92);
		final_roughness = mix(final_roughness, mix(0.18, 0.45, poly_rim), south_salt_mask * 0.88);
	}

	// Node 3 Caliche Cradle: Pale Caliche Plateau Tops & Terracotta Arroyo Strata
	float cradle_zone = smoothstep(270.0, 50.0, d_gorge1);
	if (cradle_zone > 0.001) {
		float wall_slope = smoothstep(0.12, 0.32, slope);
		vec3 caliche_top = mix(vec3(0.88, 0.82, 0.68), vec3(0.80, 0.74, 0.60), (1.0 - crack_mask) * 0.45);
		float terracotta_bands = sin(v_world_height * 3.8 + fbm(world_xz * 0.05, 2) * 2.0) * 0.5 + 0.5;
		vec3 terracotta_strata = mix(vec3(0.68, 0.28, 0.18), vec3(0.52, 0.20, 0.14), terracotta_bands) * photogrammetry_cliff_albedo * 1.6;
		vec3 caliche_surface = mix(caliche_top, terracotta_strata, wall_slope);
		final_albedo.rgb = mix(final_albedo.rgb, caliche_surface, cradle_zone * 0.88);
		final_roughness = mix(final_roughness, mix(0.72, 0.88, wall_slope), cradle_zone * 0.85);
	}

	// Node 4 Rust-Gorge Defile: Oxidized Sandstone Strata & Dark Shale Rubble
	float gorge_node_mask = smoothstep(300.0, 70.0, d_gorge2);
	if (gorge_node_mask > 0.001) {
		float wall_slope = smoothstep(0.12, 0.32, slope);
		float sandstone_strata = sin(v_world_height * 2.8 + fbm(world_xz * 0.06, 2) * 1.5) * 0.5 + 0.5;
		float rust_streak = sin(world_xz.x * 0.75 + world_xz.y * 0.35) * 0.5 + 0.5;
		vec3 sandstone_wall = mix(vec3(0.42, 0.18, 0.12), vec3(0.26, 0.11, 0.08), sandstone_strata * 0.55 + rust_streak * 0.25) * photogrammetry_cliff_albedo * 2.2;
		vec3 shale_floor = mix(vec3(0.22, 0.15, 0.13), vec3(0.16, 0.12, 0.10), gravel_n);
		vec3 gorge_surface = mix(shale_floor, sandstone_wall, wall_slope);
		final_albedo.rgb = mix(final_albedo.rgb, gorge_surface, gorge_node_mask * 0.92);
		final_roughness = mix(final_roughness, mix(0.92, 0.82, wall_slope), gorge_node_mask * 0.88);
		SPECULAR = mix(SPECULAR, 0.08, gorge_node_mask * 0.85);
	}

	// Node 5 Bleached Alkali Sink: Yellowish-White Alkali Crust & Badland Marl
	float north_alkali_zone = smoothstep(320.0, 80.0, d_salt2);
	if (north_alkali_zone > 0.001) {
		float hill_slope = smoothstep(0.14, 0.35, slope);
		vec2 alkali_poly = voronoi_polygons(world_xz * 0.65);
		float alkali_crack = smoothstep(0.015, 0.045, alkali_poly.y);
		float sulfur_tinge = fbm(world_xz * 0.05, 2) * 0.12;
		vec3 alkali_floor = mix(vec3(0.82, 0.78, 0.60), vec3(0.92, 0.89, 0.72) + vec3(sulfur_tinge, sulfur_tinge * 0.5, -sulfur_tinge), alkali_crack);
		float rill_noise = sin(v_world_height * 4.5 + fbm(world_xz * 0.08, 2) * 2.2) * 0.5 + 0.5;
		vec3 badland_marl = mix(vec3(0.74, 0.73, 0.62), vec3(0.62, 0.60, 0.50), rill_noise * 0.40);
		vec3 alkali_surface = mix(alkali_floor, badland_marl, hill_slope);
		final_albedo.rgb = mix(final_albedo.rgb, alkali_surface, north_alkali_zone * 0.92);
		final_roughness = mix(final_roughness, mix(0.28, 0.82, hill_slope), north_alkali_zone * 0.88);
		SPECULAR = mix(SPECULAR, mix(0.85, 0.15, hill_slope), north_alkali_zone * 0.90);
	}

	// Node 6 The Great Shifting Erg: Golden-Ochre Dune Ripples & Cool Shadow Contrast
	float east_dunes_zone = smoothstep(340.0, 80.0, d_dune1);
	if (east_dunes_zone > 0.001) {
		vec3 golden_sand = vec3(0.86, 0.64, 0.34);
		float stoss_wave = cos(wind_uv.x * 24.0 + fbm(wind_uv * 2.0, 2) * 3.5) * 0.5 + 0.5;
		float stoss_factor = smoothstep(-0.05, 0.20, windward_slope);
		vec3 stoss_sand = mix(golden_sand * 0.94, golden_sand * 1.06, stoss_wave * stoss_factor);
		vec3 leeward_cool_shadow = vec3(0.22, 0.28, 0.42);
		float leeward_factor = smoothstep(0.08, -0.22, windward_slope);
		float crevice_factor = smoothstep(0.45, 0.12, world_norm.y);
		float shadow_tint_w = clamp(leeward_factor * 0.65 + crevice_factor * 0.45, 0.0, 0.75);
		vec3 erg_dune_col = mix(stoss_sand, leeward_cool_shadow, shadow_tint_w);
		final_albedo.rgb = mix(final_albedo.rgb, erg_dune_col, east_dunes_zone * 0.94);
		final_roughness = mix(final_roughness, mix(0.58, 0.74, shadow_tint_w), east_dunes_zone * 0.90);
		SPECULAR = mix(SPECULAR, 0.35, east_dunes_zone * 0.85);
	}

	// Node 7 Tower Threshold: Vitrified Black Basalt & Obsidian Reflections
	float tower_zone_mask = smoothstep(360.0, 70.0, d_tower);
	if (tower_zone_mask > 0.001) {
		vec3 obsidian_base = vec3(0.06, 0.05, 0.07);
		vec2 basalt_poly = voronoi_polygons(world_xz * 0.55);
		float column_seam = smoothstep(0.025, 0.085, basalt_poly.y);
		vec3 crimson_reflection = vec3(0.85, 0.12, 0.10);
		float facet_sheen = pow(max(0.0, dot(world_norm, normalize(vec3(-0.4, 0.8, -0.4)))), 3.0);
		vec3 basalt_surface = mix(obsidian_base, crimson_reflection * 0.45, facet_sheen * 0.65);
		float fissure_crack = smoothstep(0.035, 0.14, abs(fbm(world_xz * 0.035, 3) * 2.0 - 1.0));
		float crimson_glow_w = (1.0 - fissure_crack) * (1.0 - column_seam * 0.7);
		vec3 crimson_vein = vec3(0.92, 0.14, 0.08);
		vec3 final_tower_col = mix(crimson_vein, basalt_surface, column_seam * 0.85 + 0.15);
		final_albedo.rgb = mix(final_albedo.rgb, final_tower_col, tower_zone_mask * 0.95);
		final_roughness = mix(final_roughness, mix(0.18, 0.55, 1.0 - column_seam), tower_zone_mask * 0.92);
		SPECULAR = mix(SPECULAR, 0.94, tower_zone_mask * 0.92);
		EMISSION = mix(EMISSION, crimson_vein * 2.8, tower_zone_mask * crimson_glow_w * 0.85);
	}

	// Thinny Beam Abyss (+325, +325)
	float abyss_rim_mask = smoothstep(240.0, 110.0, d_abyss_frag);
	if (abyss_rim_mask > 0.001) {
		float ribbon_phase = TIME * 2.2 + (world_xz.x - world_xz.y) * 0.15;
		float ribbon_wave1 = sin(ribbon_phase) * cos(TIME * 1.4 + (world_xz.x + world_xz.y) * 0.09);
		float ribbon_bands = pow(max(0.0, sin(ribbon_phase * 2.0 + sin(world_xz.x * 0.2))), 5.0);
		vec3 todash_sheen_a = vec3(0.18, 0.90, 0.75);
		vec3 todash_sheen_b = vec3(0.85, 0.22, 0.70);
		vec3 ribbon_col = mix(todash_sheen_a, todash_sheen_b, ribbon_wave1 * 0.5 + 0.5);
		ribbon_col += vec3(0.40, 0.70, 1.0) * ribbon_bands * 0.85;
		final_albedo.rgb = mix(final_albedo.rgb, ribbon_col, abyss_rim_mask * 0.82);
		final_roughness = mix(final_roughness, 0.12, abyss_rim_mask * 0.85);
		SPECULAR = mix(SPECULAR, 0.96, abyss_rim_mask * 0.85);
		EMISSION = mix(EMISSION, ribbon_col * 0.85 * (0.5 + ribbon_bands * 0.6), abyss_rim_mask * smoothstep(200.0, 110.0, d_abyss_frag));
	}

	vec2 salt_poly_grad = vec2(poly_rim * 1.6 - (1.0 - poly_fissure) * 1.1) * south_salt_mask;
	vec3 local_normal = normalize(vec3(-salt_poly_grad.x, 1.0, -salt_poly_grad.y));
	vec3 bump_ts = normalize(vec3(local_normal.x, local_normal.z, local_normal.y));
	vec3 ground_normal = normalize(mix(scanned_normal_ts, bump_ts, south_salt_mask * 0.75));
	vec3 blended_normal_map = normalize(mix(ground_normal, scanned_cliff_normal, strata_w * 0.88));
	NORMAL_MAP       = blended_normal_map * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = detail_normal_depth;

	ALBEDO     = final_albedo.rgb;
	ROUGHNESS  = clamp(final_roughness, 0.0, 1.0);
	METALLIC   = obsidian_mask * 0.15;
	SSS_STRENGTH = dune_w * 0.25;

	float salt_spec = mix(0.20, 0.46, salt_rim);
	float base_spec = dune_w * 0.28 + gravel_w * 0.05 + alkali_w * salt_spec + strata_w * 0.14;
	SPECULAR = mix(mix(base_spec, 0.92, south_salt_mask * 0.88), 0.65, obsidian_mask * 0.85);
}
