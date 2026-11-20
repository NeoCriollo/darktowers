/**
 * Node-Based Regional Traversal & Connection Graph
 * The Path of Ka - Master Regional Topology
 * Connects Node 0 (Mohaine Way-Bunker) through Node 7 (Threshold of the Tower)
 */

import { vec3, type Vector3 } from '../core/types.ts';
import type { BasinId } from './types.ts';
import { BASIN_REGISTRY } from './biomeConfigs.ts';

export type CorridorType = 'CANYON_PASS' | 'CHOKE_POINT' | 'HAZARDOUS_ABYSS' | 'ANCIENT_TUNNEL';
export type CorridorHazardType = 'NONE' | 'SILICA_HABOOB' | 'SALT_CORROSION' | 'IRON_OXIDE' | 'THINNY_DISTORTION' | 'FALL_HAZARD';

export interface RegionalNode {
  nodeIndex: number;
  id: BasinId;
  name: string;
  center: Vector3;
  radiusMeters: number;
  isSafeZone: boolean;
  connectedNodeIds: BasinId[];
}

export interface RegionalCorridor {
  id: string;
  name: string;
  fromBasin: BasinId;
  toBasin: BasinId;
  fromIndex: number;
  toIndex: number;
  waypointA: Vector3;
  waypointB: Vector3;
  chokePoint: Vector3;
  halfWidthMeters: number;
  corridorType: CorridorType;
  isBidirectional: boolean;
  isBlocked: boolean;
  hazardType: CorridorHazardType;
  hazardMultiplier: number;
  staminaDrainMultiplier: number;
  description: string;
}

export const REGIONAL_NODES: Record<BasinId, RegionalNode> = {
  waystation_sanctuary: {
    nodeIndex: 0,
    id: 'waystation_sanctuary',
    name: 'The Mohaine Way-Bunker',
    center: BASIN_REGISTRY.waystation_sanctuary.center,
    radiusMeters: 150.0,
    isSafeZone: true,
    connectedNodeIds: ['sw_desolation', 'south_salt'],
  },
  sw_desolation: {
    nodeIndex: 1,
    id: 'sw_desolation',
    name: 'Southwest Desolation',
    center: BASIN_REGISTRY.sw_desolation.center,
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedNodeIds: ['waystation_sanctuary', 'south_salt'],
  },
  south_salt: {
    nodeIndex: 2,
    id: 'south_salt',
    name: 'Dead-Creek Salt Flats',
    center: BASIN_REGISTRY.south_salt.center,
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedNodeIds: ['waystation_sanctuary', 'sw_desolation', 'cradle'],
  },
  cradle: {
    nodeIndex: 3,
    id: 'cradle',
    name: 'Caliche Cradle Hub',
    center: BASIN_REGISTRY.cradle.center,
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedNodeIds: ['south_salt', 'west_gorge', 'north_alkali', 'east_dunes', 'monolith_pass'],
  },
  west_gorge: {
    nodeIndex: 4,
    id: 'west_gorge',
    name: 'Rust-Gorge Defile',
    center: BASIN_REGISTRY.west_gorge.center,
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedNodeIds: ['cradle', 'north_alkali'],
  },
  north_alkali: {
    nodeIndex: 5,
    id: 'north_alkali',
    name: 'Bleached Alkali Sink',
    center: BASIN_REGISTRY.north_alkali.center,
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedNodeIds: ['cradle', 'west_gorge', 'monolith_pass'],
  },
  east_dunes: {
    nodeIndex: 6,
    id: 'east_dunes',
    name: 'The Great Shifting Erg',
    center: BASIN_REGISTRY.east_dunes.center,
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedNodeIds: ['cradle', 'monolith_pass'],
  },
  monolith_pass: {
    nodeIndex: 7,
    id: 'monolith_pass',
    name: 'Threshold of the Dark Tower',
    center: BASIN_REGISTRY.monolith_pass.center,
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedNodeIds: ['north_alkali', 'east_dunes', 'cradle'],
  },
};

export const REGIONAL_CORRIDORS: RegionalCorridor[] = [
  {
    id: 'pass_sanctuary_to_sw',
    name: 'Mohaine Sanctuary Gate Defile',
    fromBasin: 'waystation_sanctuary',
    toBasin: 'sw_desolation',
    fromIndex: 0,
    toIndex: 1,
    waypointA: vec3(-900.0, 0.0, -820.0),
    waypointB: vec3(-650.0, 0.0, -880.0),
    chokePoint: vec3(-900.0, 0.0, -820.0),
    halfWidthMeters: 18.0,
    corridorType: 'CHOKE_POINT',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'NONE',
    hazardMultiplier: 1.0,
    staminaDrainMultiplier: 1.0,
    description: 'Eastern defile pass opening from the fortified Way-Bunker gate into the windswept desolation.',
  },
  {
    id: 'pass_sanctuary_to_salt',
    name: 'Southern Culvert Drainage Wash',
    fromBasin: 'waystation_sanctuary',
    toBasin: 'south_salt',
    fromIndex: 0,
    toIndex: 2,
    waypointA: vec3(-950.0, 0.0, -780.0),
    waypointB: vec3(-280.0, 0.0, -650.0),
    chokePoint: vec3(-615.0, 0.0, -715.0),
    halfWidthMeters: 14.0,
    corridorType: 'ANCIENT_TUNNEL',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'SALT_CORROSION',
    hazardMultiplier: 1.4,
    staminaDrainMultiplier: 1.3,
    description: 'Dry-wash culvert bypass connecting the Mohaine perimeter directly to the southern salt flats.',
  },
  {
    id: 'pass_sw_to_salt',
    name: 'Hardpan Siphon Pass',
    fromBasin: 'sw_desolation',
    toBasin: 'south_salt',
    fromIndex: 1,
    toIndex: 2,
    waypointA: vec3(-450.0, 0.0, -800.0),
    waypointB: vec3(-250.0, 0.0, -650.0),
    chokePoint: vec3(-350.0, 0.0, -725.0),
    halfWidthMeters: 18.0,
    corridorType: 'CANYON_PASS',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'SILICA_HABOOB',
    hazardMultiplier: 1.5,
    staminaDrainMultiplier: 1.2,
    description: 'Windswept pass between SW dunes and the dead-level Dead-Creek salt pan.',
  },
  {
    id: 'pass_salt_to_cradle',
    name: 'Dead-Creek Arroyo Corridor',
    fromBasin: 'south_salt',
    toBasin: 'cradle',
    fromIndex: 2,
    toIndex: 3,
    waypointA: vec3(-100.0, 0.0, -420.0),
    waypointB: vec3(-30.0, 0.0, -150.0),
    chokePoint: vec3(-65.0, 0.0, -285.0),
    halfWidthMeters: 18.0,
    corridorType: 'CANYON_PASS',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'SALT_CORROSION',
    hazardMultiplier: 1.2,
    staminaDrainMultiplier: 1.1,
    description: 'Dry erosion gully climbing from the bleached playa into the central Caliche limestone crossroads.',
  },
  {
    id: 'pass_cradle_to_gorge',
    name: 'West Caliche Defile Pass',
    fromBasin: 'cradle',
    toBasin: 'west_gorge',
    fromIndex: 3,
    toIndex: 4,
    waypointA: vec3(-150.0, 0.0, 15.0),
    waypointB: vec3(-500.0, 0.0, 40.0),
    chokePoint: vec3(-325.0, 0.0, 27.5),
    halfWidthMeters: 16.0,
    corridorType: 'CHOKE_POINT',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'IRON_OXIDE',
    hazardMultiplier: 1.8,
    staminaDrainMultiplier: 1.4,
    description: 'Narrow canyon gateway flanked by oxidized cliffs entering the claustrophobic Rust-Gorge defile.',
  },
  {
    id: 'pass_cradle_to_north',
    name: 'North Caliche Conduit Pass',
    fromBasin: 'cradle',
    toBasin: 'north_alkali',
    fromIndex: 3,
    toIndex: 5,
    waypointA: vec3(0.0, 0.0, 150.0),
    waypointB: vec3(0.0, 0.0, 500.0),
    chokePoint: vec3(0.0, 0.0, 325.0),
    halfWidthMeters: 18.0,
    corridorType: 'CANYON_PASS',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'NONE',
    hazardMultiplier: 1.3,
    staminaDrainMultiplier: 1.2,
    description: 'Direct North passage carving through limestone ridges toward the Bleached Alkali Sink.',
  },
  {
    id: 'pass_cradle_to_east',
    name: 'Windward Erg Pass',
    fromBasin: 'cradle',
    toBasin: 'east_dunes',
    fromIndex: 3,
    toIndex: 6,
    waypointA: vec3(150.0, 0.0, 15.0),
    waypointB: vec3(500.0, 0.0, 40.0),
    chokePoint: vec3(325.0, 0.0, 27.5),
    halfWidthMeters: 18.0,
    corridorType: 'CANYON_PASS',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'SILICA_HABOOB',
    hazardMultiplier: 1.6,
    staminaDrainMultiplier: 1.5,
    description: 'Sand-drifted eastern pass ascending into the high-amplitude mega-dunes of the Great Shifting Erg.',
  },
  {
    id: 'pass_gorge_to_north',
    name: 'Gorge-Alkali High Pass',
    fromBasin: 'west_gorge',
    toBasin: 'north_alkali',
    fromIndex: 4,
    toIndex: 5,
    waypointA: vec3(-500.0, 0.0, 180.0),
    waypointB: vec3(-150.0, 0.0, 520.0),
    chokePoint: vec3(-325.0, 0.0, 350.0),
    halfWidthMeters: 16.0,
    corridorType: 'CHOKE_POINT',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'IRON_OXIDE',
    hazardMultiplier: 2.0,
    staminaDrainMultiplier: 1.5,
    description: 'High-elevation mountain defile with stepped sandstone ledges bridging the gorge to the northern basin.',
  },
  {
    id: 'pass_north_to_monolith',
    name: 'Monolith Pass Defile',
    fromBasin: 'north_alkali',
    toBasin: 'monolith_pass',
    fromIndex: 5,
    toIndex: 7,
    waypointA: vec3(150.0, 0.0, 650.0),
    waypointB: vec3(500.0, 0.0, 650.0),
    chokePoint: vec3(325.0, 0.0, 650.0),
    halfWidthMeters: 18.0,
    corridorType: 'CANYON_PASS',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'NONE',
    hazardMultiplier: 1.7,
    staminaDrainMultiplier: 1.3,
    description: 'Fortified eastern passage past the Ka Monolith leading directly into the Tower Citadel perimeter.',
  },
  {
    id: 'pass_east_to_monolith',
    name: 'Dunecrest Citadel Approach',
    fromBasin: 'east_dunes',
    toBasin: 'monolith_pass',
    fromIndex: 6,
    toIndex: 7,
    waypointA: vec3(650.0, 0.0, 150.0),
    waypointB: vec3(650.0, 0.0, 500.0),
    chokePoint: vec3(650.0, 0.0, 325.0),
    halfWidthMeters: 18.0,
    corridorType: 'CANYON_PASS',
    isBidirectional: true,
    isBlocked: false,
    hazardType: 'SILICA_HABOOB',
    hazardMultiplier: 1.9,
    staminaDrainMultiplier: 1.6,
    description: 'Razor-dune corridor passing ancient gantry wreckage toward the basalt approach terraces.',
  },
  {
    id: 'connector_cradle_to_monolith_thinny',
    name: 'Beam Abyss Thinny Chasm Connector',
    fromBasin: 'cradle',
    toBasin: 'monolith_pass',
    fromIndex: 3,
    toIndex: 7,
    waypointA: vec3(140.0, 4.8, 140.0),
    waypointB: vec3(585.0, 3.5, 585.0),
    chokePoint: vec3(325.0, -28.0, 325.0),
    halfWidthMeters: 32.0,
    corridorType: 'HAZARDOUS_ABYSS',
    isBidirectional: true,
    isBlocked: true,
    hazardType: 'THINNY_DISTORTION',
    hazardMultiplier: 4.5,
    staminaDrainMultiplier: 2.5,
    description: 'Direct NE path along the Beam severed by the 28m-deep Thinny Beam Abyss void. Severe psychic auditory damage.',
  },
];

export function getRegionalNode(idOrIndex: BasinId | number): RegionalNode | undefined {
  if (typeof idOrIndex === 'number') {
    return Object.values(REGIONAL_NODES).find(n => n.nodeIndex === idOrIndex);
  }
  return REGIONAL_NODES[idOrIndex];
}

export function getAllRegionalNodes(): RegionalNode[] {
  return Object.values(REGIONAL_NODES);
}

export function getRegionalCorridor(id: string): RegionalCorridor | undefined {
  return REGIONAL_CORRIDORS.find(c => c.id === id);
}

export function getCorridorBetween(fromBasin: BasinId, toBasin: BasinId): RegionalCorridor | undefined {
  return REGIONAL_CORRIDORS.find(
    c => (c.fromBasin === fromBasin && c.toBasin === toBasin) ||
         (c.isBidirectional && c.fromBasin === toBasin && c.toBasin === fromBasin)
  );
}

export function getCorridorsForNode(basinId: BasinId): RegionalCorridor[] {
  return REGIONAL_CORRIDORS.filter(c => c.fromBasin === basinId || (c.isBidirectional && c.toBasin === basinId));
}

export function getNavigableCorridors(): RegionalCorridor[] {
  return REGIONAL_CORRIDORS.filter(c => !c.isBlocked);
}

export function canTraverseDirectly(fromBasin: BasinId, toBasin: BasinId): boolean {
  if (fromBasin === toBasin) return true;
  const corridor = getCorridorBetween(fromBasin, toBasin);
  return corridor !== undefined && !corridor.isBlocked;
}

export function findNavigablePath(startBasin: BasinId, goalBasin: BasinId): BasinId[] | null {
  if (startBasin === goalBasin) return [startBasin];

  const queue: Array<{ current: BasinId; path: BasinId[] }> = [{ current: startBasin, path: [startBasin] }];
  const visited = new Set<BasinId>([startBasin]);

  while (queue.length > 0) {
    const { current, path } = queue.shift()!;
    if (current === goalBasin) return path;

    const corridors = getCorridorsForNode(current);
    for (const c of corridors) {
      if (c.isBlocked) continue;
      const nextNode = c.fromBasin === current ? c.toBasin : c.fromBasin;
      if (!visited.has(nextNode)) {
        visited.add(nextNode);
        queue.push({ current: nextNode, path: [...path, nextNode] });
      }
    }
  }

  return null;
}

