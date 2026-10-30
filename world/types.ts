/**
 * World, Weather & Spatial Persistence Types
 * The Path of Ka - Vertical Slice Architecture
 */

import type { Vector3 } from '../core/types.ts';
import type { Item } from '../inventory/types.ts';

export type WeatherType =
  | 'CLEAR_ARID'
  | 'HEAT_HAZE'
  | 'DUST_DEVIL'
  | 'SEVERE_HABOOB'
  | 'COLD_DESERT_NIGHT';

export interface AtmosphericState {
  type: WeatherType;
  temperatureCelsius: number;
  relativeHumidity: number;       // 0.0 to 1.0
  windSpeedMps: number;
  windDirectionVector: Vector3;
  gritSuspensionDensityMgM3: number; // airborne silica particulate
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
