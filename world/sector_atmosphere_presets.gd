class_name SectorAtmospherePresets
extends RefCounted

## Desolate Wasteland Atmospheric Presets & Sector Atmospheric Overrides
## Extracted from WastelandEnvironment to maintain modular architecture.

# --- SECTOR ATMOSPHERE & HAZARD TUNING ---
const SECTOR_ATMOSPHERES: Dictionary = {
	"sw_desolation": {
		"fog_color": Color(0.86, 0.54, 0.22, 1.0),
		"fog_density": 0.048,
		"volumetric_fog_density": 0.072,
		"sun_energy": 0.55,
		"sun_color": Color(0.96, 0.62, 0.32, 1.0),
		"sky_horizon": Color(0.82, 0.48, 0.20, 1.0),
		"ground_horizon": Color(0.66, 0.38, 0.18, 1.0),
		"silica_multiplier": 2.5,
		"glare_visibility_penalty": 0.0,
		"salt_corrosion_rate": 1.0
	},
	"south_salt": {
		"fog_color": Color(0.92, 0.90, 0.84, 1.0),
		"fog_density": 0.008,
		"volumetric_fog_density": 0.012,
		"sun_energy": 2.8,
		"sun_color": Color(1.0, 0.98, 0.88, 1.0),
		"sun_pitch_deg": -58.0,
		"sky_horizon": Color(0.98, 0.94, 0.85, 1.0),
		"ground_horizon": Color(0.94, 0.92, 0.88, 1.0),
		"glow_intensity": 0.95,
		"glow_bloom": 0.25,
		"heat_haze_strength": 0.85,
		"glare_visibility_penalty": 0.45,
		"salt_corrosion_rate": 2.5,
		"silica_multiplier": 0.5
	},
	"cradle": {
		"fog_color": Color(0.68, 0.74, 0.82, 1.0),
		"fog_density": 0.007,
		"volumetric_fog_density": 0.010,
		"sun_energy": 2.2,
		"sun_color": Color(1.0, 0.94, 0.82, 1.0),
		"sun_pitch_deg": -32.0,
		"sun_yaw_deg": 48.0,
		"sky_horizon": Color(0.72, 0.78, 0.86, 1.0),
		"ground_horizon": Color(0.70, 0.65, 0.58, 1.0),
		"silica_multiplier": 1.0,
		"glare_visibility_penalty": 0.0,
		"salt_corrosion_rate": 1.0,
		"thinny_distortion_rate": 1.0
	},
	"west_gorge": {
		"fog_color": Color(0.28, 0.22, 0.20, 1.0),
		"fog_density": 0.022,
		"volumetric_fog_density": 0.035,
		"sun_energy": 1.15,
		"sun_color": Color(0.92, 0.80, 0.68, 1.0),
		"sun_pitch_deg": -75.0,
		"sun_yaw_deg": 42.0,
		"sky_horizon": Color(0.38, 0.30, 0.26, 1.0),
		"ground_horizon": Color(0.22, 0.16, 0.14, 1.0),
		"silica_multiplier": 1.8,
		"iron_oxide_multiplier": 1.8,
		"glare_visibility_penalty": 0.0,
		"salt_corrosion_rate": 1.0,
		"thinny_distortion_rate": 0.0
	},
	"north_alkali": {
		"fog_color": Color(0.88, 0.86, 0.76, 1.0),
		"fog_density": 0.015,
		"volumetric_fog_density": 0.025,
		"sun_energy": 2.4,
		"sun_color": Color(0.98, 0.96, 0.88, 1.0),
		"sun_pitch_deg": -62.0,
		"sun_yaw_deg": 48.0,
		"sky_horizon": Color(0.78, 0.84, 0.88, 1.0),
		"ground_horizon": Color(0.86, 0.84, 0.70, 1.0),
		"silica_multiplier": 1.0,
		"glare_visibility_penalty": 0.0,
		"salt_corrosion_rate": 2.0,
		"ka_resonance_rate": 1.0,
		"thinny_distortion_rate": 0.0
	},
	"east_dunes": {
		"fog_color": Color(0.75, 0.62, 0.45, 1.0),
		"fog_density": 0.006,
		"volumetric_fog_density": 0.009,
		"sun_energy": 2.65,
		"sun_color": Color(1.0, 0.95, 0.85, 1.0),
		"sun_pitch_deg": -68.0,
		"sun_yaw_deg": 42.0,
		"sky_horizon": Color(0.14, 0.36, 0.72, 1.0),
		"ground_horizon": Color(0.86, 0.64, 0.34, 1.0),
		"silica_multiplier": 2.2,
		"stamina_drain_multiplier": 1.6,
		"glare_visibility_penalty": 0.0,
		"salt_corrosion_rate": 1.0,
		"thinny_distortion_rate": 0.0
	},
	"tower_threshold": {
		"fog_color": Color(0.28, 0.03, 0.04, 1.0),
		"fog_density": 0.018,
		"volumetric_fog_density": 0.032,
		"sun_energy": 1.95,
		"sun_color": Color(0.95, 0.16, 0.14, 1.0),
		"sun_pitch_deg": -54.0,
		"sun_yaw_deg": 48.0,
		"sky_horizon": Color(0.65, 0.06, 0.06, 1.0),
		"ground_horizon": Color(0.20, 0.04, 0.04, 1.0),
		"silica_multiplier": 2.4,
		"stamina_drain_multiplier": 1.2,
		"glare_visibility_penalty": 0.0,
		"salt_corrosion_rate": 1.0,
		"tower_nexus_strain_rate": 1.0,
		"thinny_distortion_rate": 0.0
	},
	"monolith_pass": {
		"fog_color": Color(0.28, 0.03, 0.04, 1.0),
		"fog_density": 0.018,
		"volumetric_fog_density": 0.032,
		"sun_energy": 1.95,
		"sun_color": Color(0.95, 0.16, 0.14, 1.0),
		"sun_pitch_deg": -54.0,
		"sun_yaw_deg": 48.0,
		"sky_horizon": Color(0.65, 0.06, 0.06, 1.0),
		"ground_horizon": Color(0.20, 0.04, 0.04, 1.0),
		"silica_multiplier": 2.4,
		"stamina_drain_multiplier": 1.2,
		"glare_visibility_penalty": 0.0,
		"salt_corrosion_rate": 1.0,
		"tower_nexus_strain_rate": 1.0,
		"thinny_distortion_rate": 0.0
	}
}

static func get_sector_config(sector_id: String) -> Dictionary:
	return SECTOR_ATMOSPHERES.get(sector_id, {})

static func get_preset_config(preset: int) -> Dictionary:
	match preset:
		0: # CLEAR_ARID ("Hopeful Desolation" dawn / golden hour raking sun)
			return {
				"sun_color": Color(1.0, 0.78, 0.52),
				"sun_energy": 1.95,
				"sun_pitch_deg": -14.0,
				"fog_color": Color(0.72, 0.48, 0.32),
				"fog_density": 0.012,
				"volumetric_fog_density": 0.020,
				"sky_horizon": Color(0.88, 0.54, 0.28),
				"ground_horizon": Color(0.68, 0.42, 0.24),
				"wind_velocity": 2.2,
				"particle_density": 0.06,
				"glow_intensity": 0.45,
				"glow_bloom": 0.12,
			}
		1: # HEAT_HAZE (Blinding white-gold desert noon)
			return {
				"sun_color": Color(1.0, 0.94, 0.82),
				"sun_energy": 2.25,
				"sun_pitch_deg": -48.0,
				"fog_color": Color(0.82, 0.68, 0.52),
				"fog_density": 0.018,
				"volumetric_fog_density": 0.028,
				"sky_horizon": Color(0.92, 0.76, 0.58),
				"ground_horizon": Color(0.75, 0.60, 0.44),
				"wind_velocity": 4.8,
				"particle_density": 0.18,
				"glow_intensity": 0.85,
				"glow_bloom": 0.18,
			}
		2: # DUST_DEVIL (Amber turbulent twilight vortex)
			return {
				"sun_color": Color(0.96, 0.68, 0.44),
				"sun_energy": 1.30,
				"sun_pitch_deg": -18.0,
				"fog_color": Color(0.68, 0.45, 0.30),
				"fog_density": 0.035,
				"volumetric_fog_density": 0.048,
				"sky_horizon": Color(0.78, 0.48, 0.32),
				"ground_horizon": Color(0.58, 0.36, 0.25),
				"wind_velocity": 9.5,
				"particle_density": 0.42,
				"glow_intensity": 0.50,
				"glow_bloom": 0.12,
			}
		3: # SEVERE_HABOOB (Blood-copper apocalyptic dust wall)
			return {
				"sun_color": Color(0.82, 0.46, 0.26),
				"sun_energy": 0.45,
				"sun_pitch_deg": -12.0,
				"fog_color": Color(0.58, 0.32, 0.20),
				"fog_density": 0.088,
				"volumetric_fog_density": 0.110,
				"sky_horizon": Color(0.52, 0.30, 0.18),
				"ground_horizon": Color(0.44, 0.24, 0.14),
				"wind_velocity": 22.0,
				"particle_density": 0.92,
				"glow_intensity": 0.22,
				"glow_bloom": 0.08,
			}
		4: # COLD_DESERT_NIGHT (Cool starlit indigo)
			return {
				"sun_color": Color(0.35, 0.42, 0.62),
				"sun_energy": 0.32,
				"sun_pitch_deg": -32.0,
				"fog_color": Color(0.14, 0.16, 0.24),
				"fog_density": 0.007,
				"volumetric_fog_density": 0.010,
				"sky_horizon": Color(0.12, 0.14, 0.22),
				"ground_horizon": Color(0.08, 0.09, 0.14),
				"wind_velocity": 1.2,
				"particle_density": 0.02,
				"glow_intensity": 0.25,
				"glow_bloom": 0.06,
			}
		_:
			return get_preset_config(0)

