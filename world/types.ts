/**
 * World, Weather & Spatial Persistence Types
 * The Path of Ka - Vertical Slice Architecture
 */

import type { Vector3 } from '../core/types.ts';
import type { Item } from '../inventory/types.ts';

export type BasinId =
  | 'waystation_sanctuary'
  | 'sw_desolation'
  | 'south_salt'
  | 'cradle'
  | 'west_gorge'
  | 'north_alkali'
  | 'east_dunes'
  | 'monolith_pass';

export interface SectorEnvironmentalParameters {
  fogColorHex: string;
  fogDensity: number;
  volumetricFogDensity: number;
  sunEnergy: number;
  sunVisibility: number;
  silicaAccumulationMultiplier: number;
  weatherTone: string;
  glareVisibilityPenalty?: number;
  saltCorrosionMultiplier?: number;
  thinnyDistortionMultiplier?: number;
  ironOxideMultiplier?: number;
  kaBeaconResonanceMultiplier?: number;
  staminaDrainMultiplier?: number;
  towerNexusStrainMultiplier?: number;
}

export interface BasinNodeDefinition {
  id: BasinId;
  nodeIndex: number;
  name: string;
  center: Vector3;
  radiusMeters: number;
  isSafeZone: boolean;
  connectedBasinIds: BasinId[];
  landmarks?: Array<{
    name: string;
    position: Vector3;
    type?: string;
  }>;
  environmentalParameters?: SectorEnvironmentalParameters;
}

export interface CanyonPassDefinition {
  id: string;
  fromBasin: BasinId;
  toBasin: BasinId;
  waypointA: Vector3;
  waypointB: Vector3;
  halfWidthMeters: number;
}

export interface ThinnyAnomalyDefinition {
  id: string;
  name: string;
  center: Vector3;
  radiusMeters: number;
  description: string;
}

export interface RegionalBeaconDefinition {
  id: string;
  basinId: BasinId;
  position: Vector3;
  defenseRadiusMeters: number;
  localizedKey: string;
}

export type WeatherType =
  | 'CLEAR_ARID'
  | 'HEAT_HAZE'
  | 'DUST_DEVIL'
  | 'SEVERE_HABOOB'
  | 'COLD_DESERT_NIGHT';

export interface AtmosphericState {
  type: WeatherType;
  temperatureCelsius: number;
  relativeHumidity: number;
  windSpeedMps: number;
  windDirectionVector: Vector3;
  gritSuspensionDensityMgM3: number;
  solarRadiationWm2: number;
  visibilityMeters: number;
}

export interface GroundItemInstance {
  id: string;
  item: Item;
  worldPosition: Vector3;
  droppedTimestamp: number;
  weatherExposureGrit: number;
}

export interface WorldZoneChunk {
  chunkX: number;
  chunkZ: number;
  biome: 'SALT_FLATS' | 'CANYON_RUINS' | 'DESERT_DUNES' | 'WAYSTATION_OUTPOST';
  groundItems: GroundItemInstance[];
  spentBrassCount: number;
  campfireLit: boolean;
  campfireEmberRemaining: number;
}

// Re-export concrete sector, basin, and landmark configuration constants
export * from './biomeConfigs.ts';
