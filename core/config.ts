/**
 * Global Configuration and Simulation Constants
 * Optimized for local Apple Silicon execution.
 */

import { vec3, type Vector3 } from './types.ts';

export const ENGINE_CONFIG = {
  // Target tick rates
  PHYSICS_TICK_RATE_HZ: 60,
  PHYSICS_DELTA_TIME_S: 1 / 60,
  SURVIVAL_TICK_RATE_HZ: 20,
  SURVIVAL_DELTA_TIME_S: 1 / 20,

  // Environmental physics constants
  STANDARD_GRAVITY: vec3(0, -9.80665, 0), // m/s^2
  SEA_LEVEL_AIR_DENSITY: 1.225, // kg/m^3
  DESERT_ELEVATION_AIR_DENSITY: 1.085, // kg/m^3 (approx 1200m altitude, 38°C)

  // Ballistics thresholds
  SPEED_OF_SOUND_MPS: 343.0,
  RAY_STEP_SIZE_M: 0.1, // Precision step for deterministic collision

  // Weapon degradation constants
  GRIT_ACCUMULATION_RATE_HABOOB: 0.08, // per second in unshielded sandstorm
  GRIT_ACCUMULATION_RATE_AMBIENT: 0.001, // per second in dry air
  HOLSTER_PROTECTION_FACTOR: 0.94, // 94% grit deflection when holstered
  CARBON_FOULING_PER_SHOT_STANDARD: 0.022,
  CARBON_FOULING_PER_SHOT_BLACK_POWDER: 0.065,

  // Jam threshold parameters
  JAM_DEGRADATION_THRESHOLD: 0.45,
  JAM_LOGISTIC_STEEPNESS: 8.5,

  // Tactile inventory physical baselines
  MAX_COMFORT_PLAYER_MASS_KG: 24.0,
  CRITICAL_OVERBURDEN_MASS_KG: 45.0,
  SLOT_CELL_UNIT_CM: 5.0, // Each grid cell is 5cm x 5cm

  // Apple Silicon optimization flags
  TARGET_ARCH: 'arm64',
  ENABLE_TYPED_ARRAYS: true,
} as const;

export const WORLD_CONFIG = {
  // Global 2500m × 2500m Macro-Footprint
  TOTAL_MAP_FOOTPRINT_M: 2500.0,
  HALF_EXTENT_M: 1250.0,
  BOUNDS_MIN_X: -1250.0,
  BOUNDS_MAX_X: 1250.0,
  BOUNDS_MIN_Z: -1250.0,
  BOUNDS_MAX_Z: 1250.0,

  // Perimeter Barrier Colliders
  PERIMETER_COLLIDER_OFFSET_M: 1246.0,
  PERIMETER_COLLIDER_HEIGHT_M: 60.0,

  // Axis of the Beam: 0.785 rad (~45° NE) from (0, 0) through (+650, +650) to (+700, +700)
  AXIS_OF_THE_BEAM_RAD: 0.785,
  DARK_TOWER_POSITION: vec3(700.0, 0.0, 700.0),
  DARK_TOWER_HEIGHT_M: 120.0,

  // Initial Player Spawn: Waystation Mohaine Way-Bunker
  INITIAL_PLAYER_SPAWN: vec3(-1020.0, 0.0, -820.0),
} as const;

