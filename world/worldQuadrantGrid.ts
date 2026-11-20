/**
 * Quadrant-Based Topographic Grid & POI World-Mapping System
 * 2500m × 2500m World Architecture (Centered at (0, 0), Extents [-1250m, +1250m])
 * 4×4 Grid (16 Quadrants, 625m × 625m each)
 */

import { vec3, type Vector3 } from '../core/types.ts';
import type { BasinId } from './types.ts';
import {
  BASIN_REGISTRY,
  REGIONAL_BEACON_REGISTRY,
  THINNY_ANOMALY_REGISTRY,
  WAYSTATION_SANCTUARY_CONFIG,
  SOUTH_SALT_CONFIG,
  CRADLE_NEXUS_CONFIG,
  WEST_GORGE_CONFIG,
  NORTH_ALKALI_CONFIG,
  EAST_DUNES_CONFIG,
  TOWER_THRESHOLD_CONFIG,
} from './biomeConfigs.ts';

export type QuadrantId =
  | 'Q01' | 'Q02' | 'Q03' | 'Q04'
  | 'Q05' | 'Q06' | 'Q07' | 'Q08'
  | 'Q09' | 'Q10' | 'Q11' | 'Q12'
  | 'Q13' | 'Q14' | 'Q15' | 'Q16';

export type GridCellCode =
  | 'A1' | 'B1' | 'C1' | 'D1'
  | 'A2' | 'B2' | 'C2' | 'D2'
  | 'A3' | 'B3' | 'C3' | 'D3'
  | 'A4' | 'B4' | 'C4' | 'D4';

export interface QuadrantBounds {
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
  centerX: number;
  centerZ: number;
  sizeMeters: number;
}

export interface QuadrantElevationProfile {
  minElevationM: number;
  maxElevationM: number;
  avgElevationM: number;
  reliefDeltaM: number;
  terrainType: string;
}

export interface QuadrantDefinition {
  id: QuadrantId;
  code: GridCellCode;
  colIndex: number;
  rowIndex: number;
  name: string;
  primaryBiomeId: BasinId;
  biomeName: string;
  bounds: QuadrantBounds;
  elevation: QuadrantElevationProfile;
  description: string;
  keyFeatures: string[];
}

export interface QuadrantPOIEntry {
  id: string;
  name: string;
  category: 'BASIN' | 'SAFEHOUSE' | 'GATE' | 'BEACON' | 'THINNY' | 'LANDMARK' | 'SPIRE';
  quadrantId: QuadrantId;
  gridCode: GridCellCode;
  position: Vector3;
}

export const QUADRANT_GRID_CONFIG = {
  GRID_COLUMNS: 4,
  GRID_ROWS: 4,
  QUADRANT_COUNT: 16,
  WORLD_MIN_X: -1250.0,
  WORLD_MAX_X: 1250.0,
  WORLD_MIN_Z: -1250.0,
  WORLD_MAX_Z: 1250.0,
  QUADRANT_SIZE_M: 625.0,
  COL_CODES: ['A', 'B', 'C', 'D'] as const,
  ROW_CODES: ['1', '2', '3', '4'] as const,
} as const;

export const QUADRANT_DEFINITIONS: Record<QuadrantId, QuadrantDefinition> = {
  Q01: {
    id: 'Q01', code: 'A1', colIndex: 0, rowIndex: 0,
    name: 'Mohaine Waystation Sanctuary & SW Perimeter', primaryBiomeId: 'waystation_sanctuary', biomeName: 'The Mohaine Way-Bunker',
    bounds: { minX: -1250.0, maxX: -625.0, minZ: -1250.0, maxZ: -625.0, centerX: -937.5, centerZ: -937.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -3.32, maxElevationM: 10.98, avgElevationM: 1.42, reliefDeltaM: 14.30, terrainType: 'Basin Floor & Encircling Ridge' },
    description: 'Starting safe-zone sanctuary centered at (-1000, -800) with blast ridge ring rising to +11m.',
    keyFeatures: ['Player Initial Spawn (-1020, -820)', 'Mohaine Way-Bunker (-1015, -815)', 'Threshold Warning Gate (-900, -820)', 'Sanctuary Enclosure'],
  },
  Q02: {
    id: 'Q02', code: 'B1', colIndex: 1, rowIndex: 0,
    name: 'Southwest Desolation & Hardpan Dunes', primaryBiomeId: 'sw_desolation', biomeName: 'Southwest Desolation',
    bounds: { minX: -625.0, maxX: 0.0, minZ: -1250.0, maxZ: -625.0, centerX: -312.5, centerZ: -937.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -2.19, maxElevationM: 8.60, avgElevationM: 1.04, reliefDeltaM: 10.79, terrainType: 'Wind-Swept Sand Dunes & Hardpan' },
    description: 'Amber haboob territory with rolling asymmetric dunes, silica hazards, and hardpan scavenger nodes.',
    keyFeatures: ['SW Desolation Basin Center (-550, -900)', 'Ka Survey Beacon (-530, -880)', 'Dead-Creek Telegraph Poles #1-#2', 'Scavenge Nodes'],
  },
  Q03: {
    id: 'Q03', code: 'C1', colIndex: 2, rowIndex: 0,
    name: 'South Wasteland & Salt Apron', primaryBiomeId: 'south_salt', biomeName: 'Dead-Creek Salt Flats (South)',
    bounds: { minX: 0.0, maxX: 625.0, minZ: -1250.0, maxZ: -625.0, centerX: 312.5, centerZ: -937.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -1.38, maxElevationM: 10.10, avgElevationM: -0.05, reliefDeltaM: 11.47, terrainType: 'Playa Transition & Southern Ridges' },
    description: 'Southern desolate buffer zone between the salt flats and the southeastern erg fissures.',
    keyFeatures: ['Dead-Creek South Margin', 'Outer Caliche Transition', 'Southern Natural Ridge Barrier'],
  },
  Q04: {
    id: 'Q04', code: 'D1', colIndex: 3, rowIndex: 0,
    name: 'Southeast Rust Rift & Thinny Anomaly', primaryBiomeId: 'east_dunes', biomeName: 'The Great Shifting Erg (Southeast)',
    bounds: { minX: 625.0, maxX: 1250.0, minZ: -1250.0, maxZ: -625.0, centerX: 937.5, centerZ: -937.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -1.76, maxElevationM: 1.89, avgElevationM: -0.48, reliefDeltaM: 3.65, terrainType: 'Low Undulating Dunes & Void Rift' },
    description: 'Distorted southeastern sector dominated by the Southeast Rust Rift spatial tear.',
    keyFeatures: ['Southeast Rust Rift Thinny (+650, -650)', 'Low Arid Dune Floor', 'Spatial Auditory Disorientation'],
  },
  Q05: {
    id: 'Q05', code: 'A2', colIndex: 0, rowIndex: 1,
    name: 'Western Scarp & Mohaine North Ridge', primaryBiomeId: 'waystation_sanctuary', biomeName: 'Mohaine North Buffer',
    bounds: { minX: -1250.0, maxX: -625.0, minZ: -625.0, maxZ: 0.0, centerX: -937.5, centerZ: -312.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -1.55, maxElevationM: 17.04, avgElevationM: 0.73, reliefDeltaM: 18.59, terrainType: 'Escarpment & Perimeter Ridge' },
    description: 'High rock barriers forming the natural northwestern wall of the sanctuary defile approach.',
    keyFeatures: ['Waystation North Mountain Flank', 'Canyon Wall Escarpment (+17m)', 'Perimeter Boundary'],
  },
  Q06: {
    id: 'Q06', code: 'B2', colIndex: 1, rowIndex: 1,
    name: 'Dead-Creek Salt Flats (Playa Pan)', primaryBiomeId: 'south_salt', biomeName: 'Dead-Creek Salt Flats',
    bounds: { minX: -625.0, maxX: 0.0, minZ: -625.0, maxZ: 0.0, centerX: -312.5, centerZ: -312.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -3.64, maxElevationM: 21.35, avgElevationM: 1.84, reliefDeltaM: 24.98, terrainType: 'Dead-Level Playa Pan (-0.45m) & Rim Ridges' },
    description: 'Bleached alkaline salt basin clamped to -0.45m elevation, ringed by craggy limestone outcrops.',
    keyFeatures: ['Dead-Creek Basin Center (-150, -550)', 'Salt Flats Ka Beacon (-130, -530)', 'Telegraph Wire (Poles #3-#6)', 'Megafauna Skeletons'],
  },
  Q07: {
    id: 'Q07', code: 'C2', colIndex: 2, rowIndex: 1,
    name: 'Caliche Cradle South & Nexus Approach', primaryBiomeId: 'cradle', biomeName: 'Caliche Cradle (South)',
    bounds: { minX: 0.0, maxX: 625.0, minZ: -625.0, maxZ: 0.0, centerX: 312.5, centerZ: -312.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -2.81, maxElevationM: 18.89, avgElevationM: 1.62, reliefDeltaM: 21.70, terrainType: 'Arroyo Trenching & Terraced Limestone' },
    description: 'Eroded limestone arroyos and south approaches leading into the central Caliche Cradle crossroads.',
    keyFeatures: ['Caliche Cradle Ka Beacon (+25, -20)', 'Nexus South Cairn', 'Nexus East Stele', 'Ironwood Scrub'],
  },
  Q08: {
    id: 'Q08', code: 'D2', colIndex: 3, rowIndex: 1,
    name: 'Great Shifting Erg South & Buried Ruins', primaryBiomeId: 'east_dunes', biomeName: 'The Great Shifting Erg (South)',
    bounds: { minX: 625.0, maxX: 1250.0, minZ: -625.0, maxZ: 0.0, centerX: 937.5, centerZ: -312.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -3.13, maxElevationM: 18.27, avgElevationM: 0.47, reliefDeltaM: 21.40, terrainType: 'Mega-Dunes & Old-Ones Superstructures' },
    description: 'Deep sand troughs and towering dunes concealing massive pre-break brutalist architecture.',
    keyFeatures: ['Tilted Old-Ones Megastructure (+680, -20)', 'Protruding I-Beam Truss', 'Obsidian Pylon Rib', 'Gantry Struts'],
  },
  Q09: {
    id: 'Q09', code: 'A3', colIndex: 0, rowIndex: 2,
    name: 'Rust-Gorge Defile & Overpass Choke', primaryBiomeId: 'west_gorge', biomeName: 'Rust-Gorge Defile',
    bounds: { minX: -1250.0, maxX: -625.0, minZ: 0.0, maxZ: 625.0, centerX: -937.5, centerZ: 312.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -1.79, maxElevationM: 26.51, avgElevationM: 2.46, reliefDeltaM: 28.31, terrainType: 'Sheer Sandstone Canyon (+18m) & Talus' },
    description: 'Claustrophobic oxidized sandstone canyon walls flanking a winding corridor with collapsed highway ruins.',
    keyFeatures: ['Rust-Gorge Basin Center (-650, 50)', 'Gorge Ka Beacon (-630, 70)', 'Collapsed Overpass (-650, 15)', 'Corroded Pipeline Network'],
  },
  Q10: {
    id: 'Q10', code: 'B3', colIndex: 1, rowIndex: 2,
    name: 'Defile-Alkali Pass & Northwest Interior', primaryBiomeId: 'west_gorge', biomeName: 'Rust-Gorge / Alkali Confluence',
    bounds: { minX: -625.0, maxX: 0.0, minZ: 0.0, maxZ: 625.0, centerX: -312.5, centerZ: 312.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -3.81, maxElevationM: 27.01, avgElevationM: 4.63, reliefDeltaM: 30.82, terrainType: 'Mountain Passes & Elevated Mesas' },
    description: 'High-elevation mountain passes connecting Rust-Gorge with Caliche Cradle and Bleached Alkali Sink.',
    keyFeatures: ['Pass Cradle to Gorge', 'Pass Gorge to North Alkali', 'Peak Elevation Mesas (+27.0m)'],
  },
  Q11: {
    id: 'Q11', code: 'C3', colIndex: 2, rowIndex: 2,
    name: 'Caliche Cradle Nexus & Thinny Beam Abyss', primaryBiomeId: 'cradle', biomeName: 'Caliche Cradle Nexus',
    bounds: { minX: 0.0, maxX: 625.0, minZ: 0.0, maxZ: 625.0, centerX: 312.5, centerZ: 312.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -30.15, maxElevationM: 18.55, avgElevationM: -1.84, reliefDeltaM: 48.70, terrainType: 'Crossroads Basin, Cliff (+4.8m) & Abyss (-30m)' },
    description: 'The geometric and navigational heart of Mid-World. Scenic overlook at (+140, +140) gazing across the deadly Beam Abyss.',
    keyFeatures: ['Nexus Crossroads (0, 0)', 'NE Scenic Overlook Promontory (+140, +140)', 'Thinny Beam Abyss Chasm (+325, +325)', 'Citadel Approach Barricades'],
  },
  Q12: {
    id: 'Q12', code: 'D3', colIndex: 3, rowIndex: 2,
    name: 'The Great Shifting Erg (Central Mega-Dunes)', primaryBiomeId: 'east_dunes', biomeName: 'The Great Shifting Erg',
    bounds: { minX: 625.0, maxX: 1250.0, minZ: 0.0, maxZ: 625.0, centerX: 937.5, centerZ: 312.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -3.10, maxElevationM: 18.56, avgElevationM: 1.52, reliefDeltaM: 21.66, terrainType: 'Razor-Crest Mega-Dunes (+15.5m) & Troughs' },
    description: 'Immense shifting sand sea with severe stamina drag, howling silica squalls, and razor-sharp dune crests.',
    keyFeatures: ['Erg Basin Center (+650, 50)', 'Erg Ka Beacon (+670, 70)', 'Gantry Struts', 'Wind-Scoured Boundary Pylons'],
  },
  Q13: {
    id: 'Q13', code: 'A4', colIndex: 0, rowIndex: 3,
    name: 'Northwest Scarp & Alkali Hollow Thinny', primaryBiomeId: 'north_alkali', biomeName: 'Northwest Alkali Scarp',
    bounds: { minX: -1250.0, maxX: -625.0, minZ: 625.0, maxZ: 1250.0, centerX: -937.5, centerZ: 937.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -1.76, maxElevationM: 1.78, avgElevationM: -0.47, reliefDeltaM: 3.54, terrainType: 'Undulating Scarp & Void Tear' },
    description: 'Remote northwestern corner concealing the Northwest Alkali Hollow spatial tear.',
    keyFeatures: ['Northwest Alkali Hollow Thinny (-650, 650)', 'Perimeter Mountain Escarpment', 'Barren Alkali Crust'],
  },
  Q14: {
    id: 'Q14', code: 'B4', colIndex: 1, rowIndex: 3,
    name: 'Bleached Alkali Sink (West Basin)', primaryBiomeId: 'north_alkali', biomeName: 'Bleached Alkali Sink (West)',
    bounds: { minX: -625.0, maxX: 0.0, minZ: 625.0, maxZ: 1250.0, centerX: -312.5, centerZ: 937.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -2.11, maxElevationM: 15.57, avgElevationM: 0.69, reliefDeltaM: 17.68, terrainType: 'Concave Saucer Depression (-1.8m) & Badlands' },
    description: 'Western half of the concave saucer basin dipping to -1.8m with sulfur crust mounds and badland hills.',
    keyFeatures: ['Alkali Sink Center (0, 650)', 'Sulfur Crust Mounds', 'Pass Gorge to North Alkali Confluence'],
  },
  Q15: {
    id: 'Q15', code: 'C4', colIndex: 2, rowIndex: 3,
    name: 'Bleached Alkali Sink (East & Beacon Monolith)', primaryBiomeId: 'north_alkali', biomeName: 'Bleached Alkali Sink (East)',
    bounds: { minX: 0.0, maxX: 625.0, minZ: 625.0, maxZ: 1250.0, centerX: 312.5, centerZ: 937.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -2.99, maxElevationM: 15.63, avgElevationM: 1.60, reliefDeltaM: 18.62, terrainType: 'Foundation Plinths & Badland Hills' },
    description: 'Site of the great Ka Survey Beacon Monolith Pylon sitting on a foundation pad at (+45, +680).',
    keyFeatures: ['Ka Beacon Monolith (+45, 680)', 'Hexagonal Foundation Plinth', 'Power Conduit Run', 'Pass North to Monolith'],
  },
  Q16: {
    id: 'Q16', code: 'D4', colIndex: 3, rowIndex: 3,
    name: 'Threshold of the Dark Tower & Citadel Spire', primaryBiomeId: 'monolith_pass', biomeName: 'Threshold of the Dark Tower',
    bounds: { minX: 625.0, maxX: 1250.0, minZ: 625.0, maxZ: 1250.0, centerX: 937.5, centerZ: 937.5, sizeMeters: 625.0 },
    elevation: { minElevationM: -2.53, maxElevationM: 8.83, avgElevationM: 0.91, reliefDeltaM: 11.36, terrainType: 'Stepped Volcanic Basalt Terraces (+9.0m)' },
    description: 'Final milestone sector: ascending basalt terraces, heavy fortifications, and The Dark Tower Spire at (+700, +700).',
    keyFeatures: ['The Dark Tower Citadel Spire (+700, +700)', 'Citadel Approach Beacon (+630, +630)', 'Outer Fortress (+650, +650)', 'Fortification Line'],
  },
};

/**
 * Maps any world coordinate (x, z) to its corresponding Quadrant.
 */
export function getQuadrantForPosition(worldX: number, worldZ: number): QuadrantDefinition {
  const clampedX = Math.max(-1250.0, Math.min(1249.99, worldX));
  const clampedZ = Math.max(-1250.0, Math.min(1249.99, worldZ));
  const col = Math.floor((clampedX - (-1250.0)) / 625.0);
  const row = Math.floor((clampedZ - (-1250.0)) / 625.0);
  const safeCol = Math.max(0, Math.min(3, col));
  const safeRow = Math.max(0, Math.min(3, row));
  const qNum = safeRow * 4 + safeCol + 1;
  const qId = `Q${String(qNum).padStart(2, '0')}` as QuadrantId;
  return QUADRANT_DEFINITIONS[qId];
}

export function getQuadrantById(id: QuadrantId): QuadrantDefinition {
  return QUADRANT_DEFINITIONS[id];
}

export function getAllQuadrants(): QuadrantDefinition[] {
  return Object.values(QUADRANT_DEFINITIONS);
}

/**
 * Builds the complete unified POI and Landmark Coordinate Registry.
 */
export function getAllRegisteredPOIs(): QuadrantPOIEntry[] {
  const entries: QuadrantPOIEntry[] = [];

  // 1. Basins
  for (const b of Object.values(BASIN_REGISTRY)) {
    const q = getQuadrantForPosition(b.center.x, b.center.z);
    entries.push({
      id: `basin_${b.id}`,
      name: b.name,
      category: 'BASIN',
      quadrantId: q.id,
      gridCode: q.code,
      position: vec3(b.center.x, b.center.y, b.center.z),
    });
  }

  // 2. Safehouse & Gate
  const spawnQ = getQuadrantForPosition(WAYSTATION_SANCTUARY_CONFIG.playerSpawn.x, WAYSTATION_SANCTUARY_CONFIG.playerSpawn.z);
  entries.push({
    id: 'poi_waystation_interior',
    name: 'Mohaine Way-Bunker Safehouse',
    category: 'SAFEHOUSE',
    quadrantId: spawnQ.id,
    gridCode: spawnQ.code,
    position: vec3(WAYSTATION_SANCTUARY_CONFIG.playerSpawn.x, WAYSTATION_SANCTUARY_CONFIG.playerSpawn.y, WAYSTATION_SANCTUARY_CONFIG.playerSpawn.z),
  });

  const gateQ = getQuadrantForPosition(WAYSTATION_SANCTUARY_CONFIG.thresholdGate.x, WAYSTATION_SANCTUARY_CONFIG.thresholdGate.z);
  entries.push({
    id: 'poi_threshold_warning_gate',
    name: 'Mohaine Threshold Warning Gate',
    category: 'GATE',
    quadrantId: gateQ.id,
    gridCode: gateQ.code,
    position: vec3(WAYSTATION_SANCTUARY_CONFIG.thresholdGate.x, WAYSTATION_SANCTUARY_CONFIG.thresholdGate.y, WAYSTATION_SANCTUARY_CONFIG.thresholdGate.z),
  });

  // 3. Regional Beacons
  for (const b of REGIONAL_BEACON_REGISTRY) {
    const q = getQuadrantForPosition(b.position.x, b.position.z);
    entries.push({
      id: b.id,
      name: `Ka Beacon (${b.localizedKey})`,
      category: 'BEACON',
      quadrantId: q.id,
      gridCode: q.code,
      position: vec3(b.position.x, b.position.y, b.position.z),
    });
  }

  // 4. Thinny Anomalies
  for (const t of THINNY_ANOMALY_REGISTRY) {
    const q = getQuadrantForPosition(t.center.x, t.center.z);
    entries.push({
      id: t.id,
      name: t.name,
      category: 'THINNY',
      quadrantId: q.id,
      gridCode: q.code,
      position: vec3(t.center.x, t.center.y, t.center.z),
    });
  }

  // 5. Regional Landmarks
  const landmarkSets = [
    SOUTH_SALT_CONFIG.landmarks,
    CRADLE_NEXUS_CONFIG.landmarks,
    WEST_GORGE_CONFIG.landmarks,
    NORTH_ALKALI_CONFIG.landmarks,
    EAST_DUNES_CONFIG.landmarks,
    TOWER_THRESHOLD_CONFIG.landmarks,
  ];

  for (const set of landmarkSets) {
    for (const lm of set) {
      const q = getQuadrantForPosition(lm.position.x, lm.position.z);
      entries.push({
        id: lm.id,
        name: lm.name,
        category: 'LANDMARK',
        quadrantId: q.id,
        gridCode: q.code,
        position: vec3(lm.position.x, lm.position.y, lm.position.z),
      });
    }
  }

  return entries;
}

export function getPOIsForQuadrant(id: QuadrantId): QuadrantPOIEntry[] {
  return getAllRegisteredPOIs().filter(poi => poi.quadrantId === id);
}

/**
 * Returns a tactical ASCII map representation of the 4x4 quadrant grid.
 */
export function generateAsciiMap(): string {
  const lines: string[] = [
    '+---------------------------------------------------------------------------------------------------+',
    '|                    DARK TOWERS: THE PATH OF KA — 2500m x 2500m TOPOGRAPHIC QUADRANT GRID          |',
    '+--------------------+--------------------+--------------------+------------------------------------+',
    '| Col A [-1250..-625]| Col B [-625..0]    | Col C [0..625]     | Col D [625..1250]                  |',
    '+--------------------+--------------------+--------------------+------------------------------------+',
  ];

  for (let r = 3; r >= 0; r--) {
    const zMin = -1250 + r * 625;
    const zMax = zMin + 625;
    lines.push(`| ROW ${r + 1} (Z: ${zMin > 0 ? '+' : ''}${zMin} to ${zMax > 0 ? '+' : ''}${zMax}m)`);
    let rowLine1 = '|';
    let rowLine2 = '|';
    let rowLine3 = '|';
    for (let c = 0; c < 4; c++) {
      const qNum = r * 4 + c + 1;
      const qId = `Q${String(qNum).padStart(2, '0')}` as QuadrantId;
      const q = QUADRANT_DEFINITIONS[qId];
      const codeStr = `[${q.id} ${q.code}]`.padEnd(20);
      const nameStr = q.biomeName.slice(0, 19).padEnd(20);
      const elevStr = `Relief: ${q.elevation.reliefDeltaM.toFixed(1)}m`.padEnd(20);
      rowLine1 += ` ${codeStr}|`;
      rowLine2 += ` ${nameStr}|`;
      rowLine3 += ` ${elevStr}|`;
    }
    lines.push(rowLine1);
    lines.push(rowLine2);
    lines.push(rowLine3);
    lines.push('+--------------------+--------------------+--------------------+------------------------------------+');
  }

  return lines.join('\n');
}
