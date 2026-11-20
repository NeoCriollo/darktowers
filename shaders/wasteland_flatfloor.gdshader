// wasteland_flatfloor.gdshader
// Stochastic, multi-tone Mohaine Desert surface shader for custom flatfloor props
// in "Dark Towers: The Path of Ka".
//
// Features:
//   1. Zero vertex displacement (preserves 1:1 flat collider geometry at any scale/rotation).
//   2. World-space triplanar projection (eliminates stretching on non-uniform scales).
//   3. Stochastic Voronoi/grid cell rotation (0-360 deg), scale jitter, and FBM domain
//      warping to completely eliminate straight-line square repetition.
//   4. Tangent-correct normal rotation per stochastic cell so normal-mapped lighting
//      stays physically consistent regardless of cell rotation angle.
//   5. Multi-scale Mohaine Desert lore palette blending sun-bleached alkali sand,
//      golden dune drifts, wind-scoured ochre loam, and caliche gravel pockets.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

// ─── Scanned Ground Detail Textures ─────────────────────────────────────────
uniform sampler2D texture_gravel_albedo : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D texture_gravel_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D texture_gravel_roughness : hint_roughness_r, filter_linear_mipmap_anisotropic;

// ─── Tiling & Stochastic Anti-Grid Controls ─────────────────────────────────
uniform float detail_tile_macro : hint_range(0.01, 1.0, 0.01) = 0.13;
uniform float detail_tile_micro : hint_range(0.2, 10.0, 0.05) = 1.65;
uniform float domain_warp_strength : hint_range(0.0, 2.0, 0.05) = 0.42;
uniform float detail_normal_depth : hint_range(0.0, 3.0, 0.05) = 0.95;
uniform float wind_direction : hint_range(0.0, 6.2832, 0.01) = 3.93;

// ─── Mid-World / Mohaine Desert Multi-Tone Palette ──────────────────────────
uniform vec4 bleached_alkali_sand : source_color = vec4(0.82, 0.74, 0.61, 1.0);
uniform vec4 golden_dune_sand : source_color = vec4(0.72, 0.58, 0.40, 1.0);
uniform vec4 ochre_terracotta_earth : source_color = vec4(0.55, 0.40, 0.28, 1.0);
uniform vec4 caliche_gravel_pocket : source_color = vec4(0.42, 0.33, 0.25, 1.0);
uniform vec4 wind_silica_drift : source_color = vec4(0.78, 0.69, 0.55, 1.0);

uniform float sand_roughness : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float gravel_roughness : hint_range(0.0, 1.0, 0.01) = 0.94;
uniform float dune_sparkle : hint_range(0.0, 0.2, 0.005) = 0.035;

// ─── Varyings ───────────────────────────────────────────────────────────────
varying vec3 v_world_pos;
varying vec3 v_world_normal;

// ─── Procedural Hash & Gradient Noise Helpers ───────────────────────────────
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i + vec2(0.0, 0.0));
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int i = 0; i < octaves; i++) {
		v += amp * value_noise(p);
		p = rot * p * 2.03 + vec2(17.1, 31.7);
		amp *= 0.5;
	}
	return v;
}

// ─── Stochastic Rotated Cell Sampling (Eliminates Straight Grid Lines) ──────
// Breaks the plane into organic warped cells; each cell rotates the texture and
// normal map by a random 0..360 deg angle and random phase offset, then blends
// smoothly across cell boundaries with quintic weights.
void sample_stochastic_ground(
	vec2 base_uv,
	float cell_density,
	out vec3 out_albedo,
	out vec3 out_normal_ts,
	out float out_roughness
) {
	vec2 warp = vec2(
		fbm(base_uv * 0.45 + vec2(3.1, 7.4), 2),
		fbm(base_uv * 0.45 + vec2(14.8, 2.9), 2)
	) - 0.5;
	vec2 warped_uv = base_uv + warp * domain_warp_strength;

	vec2 grid_p = warped_uv * cell_density;
	vec2 i_cell = floor(grid_p);
	vec2 f_cell = fract(grid_p);
	// Quintic C2-continuous interpolation curve to hide cell transitions
	vec2 w = f_cell * f_cell * f_cell * (f_cell * (f_cell * 6.0 - 15.0) + 10.0);

	vec3 accum_col = vec3(0.0);
	vec3 accum_nrm = vec3(0.0);
	float accum_rgh = 0.0;

	for (int dy = 0; dy <= 1; dy++) {
		for (int dx = 0; dx <= 1; dx++) {
			vec2 corner = vec2(float(dx), float(dy));
			vec2 cell_id = i_cell + corner;
			float weight = (dx == 1 ? w.x : (1.0 - w.x)) * (dy == 1 ? w.y : (1.0 - w.y));

			vec2 rnd = hash22(cell_id);
			float angle = hash12(cell_id + vec2(19.3, 47.1)) * 6.2831853;
			float cs = cos(angle);
			float sn = sin(angle);
			mat2 rot = mat2(vec2(cs, -sn), vec2(sn, cs));

			float scale_jitter = mix(0.86, 1.14, rnd.x);
			vec2 local_uv = rot * ((warped_uv - (cell_id / cell_density)) * scale_jitter) + rnd;

			vec3 col_s = texture(texture_gravel_albedo, local_uv).rgb;
			vec3 nrm_s = texture(texture_gravel_normal, local_uv).rgb * 2.0 - 1.0;
			// Rotate tangent-space XY normal components to match the cell's rotation
			nrm_s.xy = mat2(vec2(cs, sn), vec2(-sn, cs)) * nrm_s.xy;
			float rgh_s = texture(texture_gravel_roughness, local_uv).r;

			accum_col += col_s * weight;
			accum_nrm += nrm_s * weight;
			accum_rgh += rgh_s * weight;
		}
	}

	out_albedo = accum_col;
	out_normal_ts = normalize(accum_nrm);
	out_roughness = accum_rgh;
}

// ─── Vertex Shader (Zero Displacement for Exact Collider Parity) ────────────
void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// ─── Fragment Shader ────────────────────────────────────────────────────────
void fragment() {
	vec3 world_pos = v_world_pos;
	vec3 world_norm = normalize(v_world_normal);

	// Select primary world plane based on surface orientation (supports flat or tilted placement)
	vec3 abs_n = abs(world_norm);
	vec2 plane_uv = world_pos.xz;
	if (abs_n.x > abs_n.y && abs_n.x > abs_n.z) {
		plane_uv = world_pos.zy;
	} else if (abs_n.z > abs_n.y && abs_n.z > abs_n.x) {
		plane_uv = world_pos.xy;
	}

	// 1. Dual-Scale Stochastic Ground Sampling (Macro patches + Golden-angle rotated Micro grit)
	vec3 col_macro;
	vec3 nrm_macro;
	float rgh_macro;
	sample_stochastic_ground(plane_uv * detail_tile_macro, 0.55, col_macro, nrm_macro, rgh_macro);

	// Golden-angle rotation (137.5 deg) between macro and micro layers prevents harmonic grid alignment
	mat2 golden_rot = mat2(vec2(-0.7373688, -0.6754903), vec2(0.6754903, -0.7373688));
	vec3 col_micro;
	vec3 nrm_micro;
	float rgh_micro;
	sample_stochastic_ground(golden_rot * (plane_uv * detail_tile_micro), 0.45, col_micro, nrm_micro, rgh_micro);

	vec3 scanned_base = mix(col_macro, col_micro, 0.44);
	vec3 scanned_normal = normalize(vec3(nrm_macro.xy + nrm_micro.xy, nrm_macro.z * nrm_micro.z));
	float scanned_rough = clamp(mix(rgh_macro, rgh_micro, 0.5) + 0.12, 0.0, 1.0);

	// 2. Multi-Tone Mohaine Desert Biome Noise Blending
	float macro_dune_n = fbm(plane_uv * 0.022 + vec2(4.2, -9.1), 3);
	float med_ochre_n  = fbm(plane_uv * 0.058 + vec2(-12.7, 6.3), 4);
	float pocket_n     = fbm(plane_uv * 0.140 + vec2(21.4, 15.8), 3);
	float micro_grain  = fbm(plane_uv * 0.450, 2);

	// Wind-aligned silica sand streaks (matching wasteland_terrain wind_direction)
	float wx = cos(wind_direction);
	float wz = sin(wind_direction);
	vec2 wind_uv = vec2(dot(plane_uv, vec2(wx, wz)), dot(plane_uv, vec2(-wz, wx)));
	float wind_streak_n = fbm(wind_uv * vec2(0.035, 0.16) + vec2(fbm(plane_uv * 0.04, 2) * 1.4), 3);

	// Layer organic desert tones from golden sand -> bleached alkali -> warm ochre -> gravel pockets
	vec3 desert_tone = mix(golden_dune_sand.rgb, bleached_alkali_sand.rgb, smoothstep(0.38, 0.72, macro_dune_n));
	float ochre_mask = smoothstep(0.36, 0.68, med_ochre_n);
	desert_tone = mix(desert_tone, ochre_terracotta_earth.rgb, ochre_mask * 0.65);
	float gravel_mask = smoothstep(0.55, 0.82, pocket_n) * ochre_mask;
	desert_tone = mix(desert_tone, caliche_gravel_pocket.rgb, gravel_mask * 0.55);

	// Infuse wind-swept pale silica drifts across the surface
	float drift_mask = smoothstep(0.48, 0.76, wind_streak_n);
	desert_tone = mix(desert_tone, wind_silica_drift.rgb, drift_mask * 0.48);

	// 3. Combine Scanned Texture Detail with Multi-Tone Sand Palette
	// Normalize scanned texture around its mean luminance (~0.52) so it adds crisp
	// geological grain, pebbles, and cracks without darkening the sandy palette.
	vec3 detail_contrast = clamp(scanned_base / vec3(0.54, 0.50, 0.46), vec3(0.55), vec3(1.45));
	vec3 final_albedo = desert_tone * mix(vec3(1.0), detail_contrast, 0.78);

	// Subtle quartz sand-grain sparkle on sunlit sandy drifts
	float sand_weight = clamp(1.0 - ochre_mask * 0.6 + drift_mask * 0.4, 0.0, 1.0);
	float sparkle = pow(micro_grain, 5.0) * dune_sparkle * sand_weight;
	final_albedo += vec3(sparkle);

	float final_roughness = mix(gravel_roughness, sand_roughness, sand_weight);
	final_roughness = mix(final_roughness, scanned_rough, 0.42);

	ALBEDO = clamp(final_albedo, vec3(0.0), vec3(1.0));
	ROUGHNESS = clamp(final_roughness, 0.0, 1.0);
	METALLIC = 0.0;
	SPECULAR = mix(0.08, 0.22, sand_weight);
	NORMAL_MAP = scanned_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = detail_normal_depth;
}

