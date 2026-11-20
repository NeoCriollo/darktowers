shader_type canvas_item;

// CRT Scanline & Phosphor Distortion Shader — "Dark Towers: The Path of Ka"
//
// Simulates dying cathode-ray telemetry, horizontal scanline rasterization,
// subtle barrel curvature, static noise and progressive fade-to-black.

uniform float scanline_density : hint_range(50.0, 600.0) = 240.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.42;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.85;
uniform float noise_amount : hint_range(0.0, 0.5) = 0.045;
uniform float static_flicker : hint_range(0.0, 0.3) = 0.03;
uniform float fade_to_black : hint_range(0.0, 1.0) = 0.0;
uniform vec4 phosphor_tint : source_color = vec4(0.92, 0.42, 0.18, 1.0); // Amber-crimson terminal phosphor

float random_noise(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;

	// Subtle CRT curvature distortion
	vec2 centered = uv - 0.5;
	float dist_sq = dot(centered, centered);
	uv = uv + centered * dist_sq * 0.06;

	// Check screen boundaries
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Vignette falloff
		float vig = clamp(1.0 - dist_sq * vignette_intensity * 3.2, 0.0, 1.0);

		// Horizontal scanline modulation
		float scanline = sin(uv.y * scanline_density * 3.14159265 + TIME * 4.0) * 0.5 + 0.5;
		float scan_factor = 1.0 - (1.0 - scanline) * scanline_intensity;

		// White/pink static noise & flicker
		float noise = (random_noise(uv + vec2(TIME * 0.31, TIME * 0.17)) - 0.5) * noise_amount;
		float flicker = 1.0 - sin(TIME * 28.0) * static_flicker;

		vec3 terminal_col = phosphor_tint.rgb * vig * scan_factor * flicker + vec3(noise);

		// Blend with dark background according to fade_to_black
		float bg_alpha = clamp(0.72 + fade_to_black * 0.28, 0.0, 1.0);
		vec3 final_rgb = mix(vec3(0.02, 0.015, 0.012), terminal_col, 0.55 * (1.0 - fade_to_black * 0.75));

		COLOR = vec4(final_rgb, fade_to_black * bg_alpha);
	}
}
