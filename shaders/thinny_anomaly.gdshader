shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_disabled;

// "Thinny" Anomaly Portal & Surface Distortion Shader
// Inspired by Stephen King's The Dark Tower / The Mist:
// An oily, iridescent puddle / spatial rift where reality wears thin.

uniform vec4 base_oil_color : source_color = vec4(0.08, 0.07, 0.12, 0.85);
uniform vec4 sheen_color_a : source_color = vec4(0.42, 0.85, 0.72, 1.0); // Oily cyan/green
uniform vec4 sheen_color_b : source_color = vec4(0.85, 0.28, 0.65, 1.0); // Oily magenta/violet
uniform float ripple_speed : hint_range(0.1, 4.0, 0.1) = 0.8;
uniform float anomaly_intensity : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// Eerie subtle breathing displacement
	float wave = sin(TIME * ripple_speed * 2.0 + VERTEX.x * 2.5 + VERTEX.z * 2.5);
	VERTEX.y += wave * 0.06 * anomaly_intensity;
}

void fragment() {
	// Concentric distance from pool center
	vec2 centered_uv = UV - vec2(0.5);
	float dist = length(centered_uv) * 2.0;
	
	// Edge fade / soft pool boundary
	float pool_alpha = smoothstep(1.0, 0.35, dist);

	// Multi-frequency oil swirl
	float t = TIME * ripple_speed * 0.4;
	float n1 = noise(centered_uv * 6.0 + vec2(t, -t));
	float n2 = noise(centered_uv * 12.0 - vec2(t * 1.3, t * 0.7));
	float swirl = (n1 + n2 * 0.5) / 1.5;

	// Screen-space refraction / distortion
	vec2 screen_offset = vec2(
		cos(swirl * 6.2831 + TIME) * 0.015,
		sin(swirl * 6.2831 + TIME) * 0.015
	) * anomaly_intensity * pool_alpha;

	vec4 bg_sample = texture(screen_texture, SCREEN_UV + screen_offset);

	// Thin-film iridescence
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec4 irid_color = mix(sheen_color_a, sheen_color_b, sin(swirl * 8.0 + fresnel * 4.0) * 0.5 + 0.5);

	// Composite final surface
	vec3 final_color = mix(bg_sample.rgb, base_oil_color.rgb, 0.4);
	final_color = mix(final_color, irid_color.rgb, 0.55 * (fresnel + 0.25));
	
	// Core void pulse
	float core_pulse = sin(TIME * 3.0) * 0.5 + 0.5;
	final_color += vec3(0.1, 0.02, 0.15) * (1.0 - dist) * core_pulse;

	ALBEDO = final_color;
	ROUGHNESS = 0.04;
	METALLIC = 0.65;
	SPECULAR = 0.95;
	ALPHA = pool_alpha * 0.92;
}

