/**
 * Biome, Basin & Landmark Concrete Configuration Constants
 * The Path of Ka - Macro 2500m x 2500m World Architecture
 */

import { vec3 } from '../core/types.ts';
import type {
  BasinId,
  BasinNodeDefinition,
  CanyonPassDefinition,
  ThinnyAnomalyDefinition,
  RegionalBeaconDefinition,
} from './types.ts';

/**
 * 8-Node Region / Basin Registry (2500m × 2500m World Architecture)
 * Node 0 (Safe Zone) + 7× 500m Biomes (Radius = 250.0m)
 */
export const BASIN_REGISTRY: Record<BasinId, BasinNodeDefinition> = {
  waystation_sanctuary: {
    id: 'waystation_sanctuary',
    nodeIndex: 0,
    name: 'The Mohaine Way-Bunker',
    center: vec3(-1000.0, 0.0, -800.0),
    radiusMeters: 150.0,
    isSafeZone: true,
    connectedBasinIds: ['sw_desolation'],
    landmarks: [{ name: 'Player Initial Spawn Interior', position: vec3(-1020.0, 0.0, -820.0), type: 'SPAWN' }],
  },
  sw_desolation: {
    id: 'sw_desolation',
    nodeIndex: 1,
    name: 'Southwest Desolation',
    center: vec3(-550.0, 0.0, -900.0),
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedBasinIds: ['waystation_sanctuary', 'south_salt'],
    environmentalParameters: {
      fogColorHex: '#d98a3d',
      fogDensity: 0.048,
      volumetricFogDensity: 0.072,
      sunEnergy: 0.55,
      sunVisibility: 0.40,
      silicaAccumulationMultiplier: 2.5,
      weatherTone: 'AMBER_HABOOB',
    },
  },
  south_salt: {
    id: 'south_salt',
    nodeIndex: 2,
    name: 'Dead-Creek Salt Flats',
    center: vec3(-150.0, 0.0, -550.0),
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedBasinIds: ['sw_desolation', 'cradle'],
    environmentalParameters: {
      fogColorHex: '#eae6d6',
      fogDensity: 0.008,
      volumetricFogDensity: 0.012,
      sunEnergy: 2.8,
      sunVisibility: 1.0,
      glareVisibilityPenalty: 0.45,
      saltCorrosionMultiplier: 2.5,
      silicaAccumulationMultiplier: 0.5,
      weatherTone: 'BLEACHED_PLAYA',
    },
    landmarks: [
      { name: 'The Dead-Creek Wire', position: vec3(-200.0, -0.45, -550.0), type: 'TELEGRAPH_LINE' },
      { name: 'Playa Megafauna Remains', position: vec3(-140.0, -0.45, -480.0), type: 'SKELETAL_CLUSTER' },
    ],
  },
  cradle: {
    id: 'cradle',
    nodeIndex: 3,
    name: 'Caliche Cradle Nexus',
    center: vec3(0.0, 0.0, 0.0),
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedBasinIds: ['south_salt', 'west_gorge', 'north_alkali', 'east_dunes'],
    environmentalParameters: {
      fogColorHex: '#adbdcf',
      fogDensity: 0.007,
      volumetricFogDensity: 0.010,
      sunEnergy: 2.2,
      sunVisibility: 1.0,
      glareVisibilityPenalty: 0.0,
      saltCorrosionMultiplier: 1.0,
      silicaAccumulationMultiplier: 1.0,
      thinnyDistortionMultiplier: 1.0,
      weatherTone: 'CRADLE_CLEAR_AZURE',
    },
    landmarks: [
      { name: 'Nexus Crossroads Waymarkers', position: vec3(0.0, 0.0, 0.0), type: 'WAYMARKER_STELAE' },
      { name: 'NE Thinny Scenic Overlook', position: vec3(140.0, 4.8, 140.0), type: 'SCENIC_OVERLOOK' },
    ],
  },
  west_gorge: {
    id: 'west_gorge',
    nodeIndex: 4,
    name: 'Rust-Gorge Defile',
    center: vec3(-650.0, 0.0, 50.0),
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedBasinIds: ['cradle', 'north_alkali'],
    environmentalParameters: {
      fogColorHex: '#473833',
      fogDensity: 0.022,
      volumetricFogDensity: 0.035,
      sunEnergy: 1.15,
      sunVisibility: 0.65,
      silicaAccumulationMultiplier: 1.8,
      ironOxideMultiplier: 1.8,
      weatherTone: 'RUST_GORGE_SHADOW',
    },
    landmarks: [
      { name: 'Collapsed Overpass Choke', position: vec3(-650.0, 0.0, 35.0), type: 'OVERPASS' },
      { name: 'Corroded Pipeline Trunk', position: vec3(-635.0, 0.0, 75.0), type: 'PIPELINE_NETWORK' },
    ],
  },
  north_alkali: {
    id: 'north_alkali',
    nodeIndex: 5,
    name: 'Bleached Alkali Sink',
    center: vec3(0.0, 0.0, 650.0),
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedBasinIds: ['cradle', 'west_gorge', 'monolith_pass'],
    environmentalParameters: {
      fogColorHex: '#e0dcc2',
      fogDensity: 0.015,
      volumetricFogDensity: 0.025,
      sunEnergy: 2.4,
      sunVisibility: 1.0,
      silicaAccumulationMultiplier: 1.0,
      saltCorrosionMultiplier: 2.0,
      kaBeaconResonanceMultiplier: 1.0,
      weatherTone: 'BLEACHED_ALKALI_SINK',
    },
    landmarks: [
      { name: 'Ka Survey Beacon Monolith Node', position: vec3(45.0, -1.2, 680.0), type: 'BEACON_NODE' },
      { name: 'NCP Armored Power Conduit Run', position: vec3(35.0, -1.5, 665.0), type: 'POWER_CONDUIT' },
    ],
  },
  east_dunes: {
    id: 'east_dunes',
    nodeIndex: 6,
    name: 'The Great Shifting Erg',
    center: vec3(650.0, 0.0, 50.0),
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedBasinIds: ['cradle', 'monolith_pass'],
    environmentalParameters: {
      fogColorHex: '#bf9e73',
      fogDensity: 0.006,
      volumetricFogDensity: 0.009,
      sunEnergy: 2.65,
      sunVisibility: 1.0,
      silicaAccumulationMultiplier: 2.2,
      staminaDrainMultiplier: 1.6,
      weatherTone: 'GREAT_SHIFTING_ERG',
    },
    landmarks: [
      { name: 'Tilted Old-Ones Brutalist Ruin Superstructure', position: vec3(680.0, 1.8, -20.0), type: 'OLD_ONES_MEGASTRUCTURE' },
      { name: 'Half-Buried Structural Gantry Struts', position: vec3(655.0, -1.0, 15.0), type: 'GANTRY_STRUT' },
    ],
  },
  monolith_pass: {
    id: 'monolith_pass',
    nodeIndex: 7,
    name: 'Threshold of the Dark Tower',
    center: vec3(650.0, 0.0, 650.0),
    radiusMeters: 250.0,
    isSafeZone: false,
    connectedBasinIds: ['north_alkali', 'east_dunes'],
    environmentalParameters: {
      fogColorHex: '#47080a',
      fogDensity: 0.018,
      volumetricFogDensity: 0.032,
      sunEnergy: 1.95,
      sunVisibility: 0.85,
      silicaAccumulationMultiplier: 2.4,
      staminaDrainMultiplier: 1.2,
      towerNexusStrainMultiplier: 1.0,
      weatherTone: 'BLOOD_CRIMSON_STORM',
    },
    landmarks: [
      { name: 'The Dark Tower Citadel Spire', position: vec3(700.0, 9.0, 700.0), type: 'DARK_TOWER_SPIRE' },
      { name: 'Approach Terrace Defense Fortifications', position: vec3(585.0, 3.5, 585.0), type: 'DEFENSE_LINE' },
    ],
  },
};

/**
 * 9 Canyon Defile Pass Graph Connections
 */
export const CANYON_PASS_REGISTRY: CanyonPassDefinition[] = [
  { id: 'pass_sanctuary_to_sw', fromBasin: 'waystation_sanctuary', toBasin: 'sw_desolation', waypointA: vec3(-900.0, 0.0, -820.0), waypointB: vec3(-650.0, 0.0, -880.0), halfWidthMeters: 18.0 },
  { id: 'pass_sw_to_salt', fromBasin: 'sw_desolation', toBasin: 'south_salt', waypointA: vec3(-450.0, 0.0, -800.0), waypointB: vec3(-250.0, 0.0, -650.0), halfWidthMeters: 18.0 },
  { id: 'pass_salt_to_cradle', fromBasin: 'south_salt', toBasin: 'cradle', waypointA: vec3(-100.0, 0.0, -420.0), waypointB: vec3(-30.0, 0.0, -150.0), halfWidthMeters: 18.0 },
  { id: 'pass_cradle_to_gorge', fromBasin: 'cradle', toBasin: 'west_gorge', waypointA: vec3(-150.0, 0.0, 15.0), waypointB: vec3(-500.0, 0.0, 40.0), halfWidthMeters: 16.0 },
  { id: 'pass_cradle_to_north', fromBasin: 'cradle', toBasin: 'north_alkali', waypointA: vec3(0.0, 0.0, 150.0), waypointB: vec3(0.0, 0.0, 500.0), halfWidthMeters: 18.0 },
  { id: 'pass_cradle_to_east', fromBasin: 'cradle', toBasin: 'east_dunes', waypointA: vec3(150.0, 0.0, 15.0), waypointB: vec3(500.0, 0.0, 40.0), halfWidthMeters: 18.0 },
  { id: 'pass_gorge_to_north', fromBasin: 'west_gorge', toBasin: 'north_alkali', waypointA: vec3(-500.0, 0.0, 180.0), waypointB: vec3(-150.0, 0.0, 520.0), halfWidthMeters: 16.0 },
  { id: 'pass_north_to_monolith', fromBasin: 'north_alkali', toBasin: 'monolith_pass', waypointA: vec3(150.0, 0.0, 650.0), waypointB: vec3(500.0, 0.0, 650.0), halfWidthMeters: 18.0 },
  { id: 'pass_east_to_monolith', fromBasin: 'east_dunes', toBasin: 'monolith_pass', waypointA: vec3(650.0, 0.0, 150.0), waypointB: vec3(650.0, 0.0, 500.0), halfWidthMeters: 18.0 },
];

/**
 * Thinny Spatial Anomaly Coordinates
 */
export const THINNY_ANOMALY_REGISTRY: ThinnyAnomalyDefinition[] = [
  { id: 'thinny_beam_abyss', name: 'Beam Abyss Thinny', center: vec3(325.0, 0.0, 325.0), radiusMeters: 160.0, description: 'Blocks direct NE path along the Beam between Caliche Cradle and Monolith Pass' },
  { id: 'thinny_nw_hollow', name: 'Northwest Alkali Hollow Thinny', center: vec3(-650.0, 0.0, 650.0), radiusMeters: 180.0, description: 'Spatial tear in the northwest quadrant' },
  { id: 'thinny_se_rift', name: 'Southeast Rust Rift Thinny', center: vec3(650.0, 0.0, -650.0), radiusMeters: 180.0, description: 'Spatial tear in the southeast erg depressions' },
];

export const REGIONAL_BEACON_REGISTRY: RegionalBeaconDefinition[] = [
  { id: 'beacon_sw_desolation', basinId: 'sw_desolation', position: vec3(-530.0, 0.0, -880.0), defenseRadiusMeters: 45.0, localizedKey: 'BEACON_SW_DESOLATION' },
  { id: 'beacon_south_salt', basinId: 'south_salt', position: vec3(-130.0, 0.0, -530.0), defenseRadiusMeters: 45.0, localizedKey: 'BEACON_SOUTH_SALT' },
  { id: 'beacon_cradle', basinId: 'cradle', position: vec3(25.0, 0.0, -20.0), defenseRadiusMeters: 45.0, localizedKey: 'BEACON_CALICHE_CRADLE' },
  { id: 'beacon_west_gorge', basinId: 'west_gorge', position: vec3(-630.0, 0.0, 70.0), defenseRadiusMeters: 45.0, localizedKey: 'BEACON_RUST_GORGE' },
  { id: 'beacon_north_alkali', basinId: 'north_alkali', position: vec3(45.0, 0.0, 680.0), defenseRadiusMeters: 45.0, localizedKey: 'BEACON_NORTH_ALKALI' },
  { id: 'beacon_east_dunes', basinId: 'east_dunes', position: vec3(670.0, 0.0, 70.0), defenseRadiusMeters: 45.0, localizedKey: 'BEACON_EAST_DUNES' },
  { id: 'beacon_monolith_pass', basinId: 'monolith_pass', position: vec3(630.0, 0.0, 630.0), defenseRadiusMeters: 45.0, localizedKey: 'BEACON_MONOLITH_PASS' },
];

export const WAYSTATION_SANCTUARY_CONFIG = {
  bunkerCenter: vec3(-1015.0, 0.0, -815.0),
  playerSpawn: vec3(-1020.0, 0.0, -820.0),
  playerSpawnOffset: vec3(2.0, 0.0, 0.0),
  thresholdGate: vec3(-900.0, 0.0, -820.0),
  modelAssetPath: 'res://assets/architecture/landmarks/waystation_bunker/bunker.glb',
  modelScale: vec3(28.0, 26.0, 28.0),
  modelRotationDegrees: vec3(0.0, 90.0, 0.0),
  interactables: ['workbench_station', 'ncp_save_terminal', 'heavy_iron_footlocker', 'artesian_hand_pump'],
  socketTransforms: {
    workbench_station: { position: vec3(2.0, 0.0, -6.8), rotationDegrees: vec3(0.0, 0.0, 0.0) },
    ncp_save_terminal: { position: vec3(-2.2, 0.0, 0.5), rotationDegrees: vec3(0.0, 90.0, 0.0) },
    heavy_iron_footlocker: { position: vec3(-1.0, 0.0, 6.8), rotationDegrees: vec3(0.0, 180.0, 0.0) },
    artesian_hand_pump: { position: vec3(5.5, 0.0, -6.5), rotationDegrees: vec3(0.0, 0.0, 0.0) },
  },
  shelterZoneBounds: { size: vec3(20.0, 16.0, 18.0), center: vec3(0.0, 8.0, 0.0) },
} as const;

export const SW_DESOLATION_CONFIG = {
  quadrantBounds: { minX: -800.0, maxX: -400.0, minZ: -1000.0, maxZ: -600.0 },
  environmentalParameters: {
    fogColorHex: '#d98a3d', fogDensity: 0.048, volumetricFogDensity: 0.072,
    sunEnergy: 0.55, sunVisibility: 0.40, silicaAccumulationMultiplier: 2.5, weatherTone: 'AMBER_HABOOB',
  },
  scavengeNodes: [
    { id: 'scavenge_sw_1', position: vec3(-720.0, 0.0, -850.0), type: 'HARDPAN_RIDGE_BASE' },
    { id: 'scavenge_sw_2', position: vec3(-640.0, 0.0, -920.0), type: 'HARDPAN_RIDGE_BASE' },
    { id: 'scavenge_sw_3', position: vec3(-580.0, 0.0, -780.0), type: 'HARDPAN_RIDGE_BASE' },
    { id: 'scavenge_sw_4', position: vec3(-520.0, 0.0, -940.0), type: 'HARDPAN_RIDGE_BASE' },
    { id: 'scavenge_sw_5', position: vec3(-480.0, 0.0, -860.0), type: 'HARDPAN_RIDGE_BASE' },
    { id: 'scavenge_sw_6', position: vec3(-610.0, 0.0, -680.0), type: 'HARDPAN_RIDGE_BASE' },
  ],
} as const;

export const SOUTH_SALT_CONFIG = {
  quadrantBounds: { minX: -400.0, maxX: 0.0, minZ: -800.0, maxZ: -300.0 },
  playaElevation: -0.45,
  environmentalParameters: {
    fogColorHex: '#eae6d6', fogDensity: 0.008, volumetricFogDensity: 0.012,
    sunEnergy: 2.8, sunVisibility: 1.0, glareVisibilityPenalty: 0.45,
    saltCorrosionMultiplier: 2.5, silicaAccumulationMultiplier: 0.5, weatherTone: 'BLEACHED_PLAYA',
  },
  landmarks: [
    { id: 'telegraph_pole_1', name: 'Dead-Creek Pole #1', position: vec3(-340.0, -0.45, -680.0), type: 'TELEGRAPH_POLE' },
    { id: 'telegraph_pole_2', name: 'Dead-Creek Pole #2', position: vec3(-284.0, -0.45, -628.0), type: 'TELEGRAPH_POLE' },
    { id: 'telegraph_pole_3', name: 'Dead-Creek Pole #3', position: vec3(-228.0, -0.45, -576.0), type: 'TELEGRAPH_POLE' },
    { id: 'telegraph_pole_4', name: 'Dead-Creek Pole #4', position: vec3(-172.0, -0.45, -524.0), type: 'TELEGRAPH_POLE' },
    { id: 'telegraph_pole_5', name: 'Dead-Creek Pole #5', position: vec3(-116.0, -0.45, -472.0), type: 'TELEGRAPH_POLE' },
    { id: 'telegraph_pole_6', name: 'Dead-Creek Pole #6', position: vec3(-60.0, -0.45, -420.0), type: 'TELEGRAPH_POLE' },
    { id: 'salt_skeleton_1', name: 'Playa Megafauna Ribcage', position: vec3(-220.0, -0.45, -580.0), type: 'BLEACHED_SKELETON' },
    { id: 'salt_skeleton_2', name: 'Desiccated Steed Remains', position: vec3(-140.0, -0.45, -480.0), type: 'BLEACHED_SKELETON' },
    { id: 'salt_skeleton_3', name: 'Salt-Crusted Titan Vertebrae', position: vec3(-280.0, -0.45, -460.0), type: 'BLEACHED_SKELETON' },
    { id: 'salt_skeleton_4', name: 'Bleached Horned Beast Skull', position: vec3(-100.0, -0.45, -640.0), type: 'BLEACHED_SKELETON' },
  ],
} as const;

export const CRADLE_NEXUS_CONFIG = {
  quadrantBounds: { minX: -200.0, maxX: 200.0, minZ: -200.0, maxZ: 200.0 },
  centralNexusCoords: vec3(0.0, 0.0, 0.0),
  scenicOverlookCoords: vec3(140.0, 4.8, 140.0),
  thinnyAbyssCenter: vec3(325.0, -28.0, 325.0),
  environmentalParameters: {
    fogColorHex: '#adbdcf', fogDensity: 0.007, volumetricFogDensity: 0.010,
    sunEnergy: 2.2, sunVisibility: 1.0, glareVisibilityPenalty: 0.0,
    saltCorrosionMultiplier: 1.0, silicaAccumulationMultiplier: 1.0,
    thinnyDistortionMultiplier: 1.0, weatherTone: 'CRADLE_CLEAR_AZURE',
  },
  landmarks: [
    { id: 'cradle_waymarker_1', name: 'Nexus Crossroads North Obelisk', position: vec3(0.0, 0.0, 6.0), type: 'STONE_WAYMARKER' },
    { id: 'cradle_waymarker_2', name: 'Nexus Crossroads South Cairn', position: vec3(0.0, 0.0, -6.0), type: 'STONE_WAYMARKER' },
    { id: 'cradle_waymarker_3', name: 'Nexus Crossroads East Stele', position: vec3(6.0, 0.0, 0.0), type: 'STONE_WAYMARKER' },
    { id: 'cradle_overlook_tripod', name: 'Ruined Theodolite Survey Station', position: vec3(139.0, 4.8, 141.0), type: 'SURVEY_OVERLOOK' },
    { id: 'cradle_overlook_barricade', name: 'Precipice Warning Rail Remnant', position: vec3(143.0, 4.8, 143.0), type: 'SURVEY_OVERLOOK' },
    { id: 'cradle_scrub_1', name: 'Arroyo Rim Ironwood Scrub #1', position: vec3(-65.0, 1.2, -45.0), type: 'DESERT_SCRUB' },
    { id: 'cradle_scrub_2', name: 'Plateau Crevice Mesquite #2', position: vec3(75.0, 2.4, -60.0), type: 'DESERT_SCRUB' },
    { id: 'cradle_scrub_3', name: 'Chasm Fissure Scrub #3', position: vec3(120.0, 3.2, 110.0), type: 'DESERT_SCRUB' },
  ],
} as const;

export const WEST_GORGE_CONFIG = {
  quadrantBounds: { minX: -800.0, maxX: -400.0, minZ: -100.0, maxZ: 400.0 },
  canyonCenter: vec3(-650.0, 0.0, 50.0),
  canyonFloorElevation: -0.65,
  cliffWallElevation: 17.85,
  environmentalParameters: {
    fogColorHex: '#473833', fogDensity: 0.022, volumetricFogDensity: 0.035,
    sunEnergy: 1.15, sunVisibility: 0.65, silicaAccumulationMultiplier: 1.8,
    ironOxideMultiplier: 1.8, weatherTone: 'RUST_GORGE_SHADOW',
  },
  landmarks: [
    { id: 'gorge_overpass_slab_1', name: 'Fractured Highway Slab Alpha', position: vec3(-650.0, 1.2, 15.0), type: 'COLLAPSED_OVERPASS' },
    { id: 'gorge_overpass_girder_1', name: 'Angled Structural I-Beam', position: vec3(-648.0, 3.5, 35.0), type: 'COLLAPSED_OVERPASS' },
    { id: 'gorge_overpass_slab_2', name: 'Tilted Concrete Roadbed Slab', position: vec3(-652.0, 2.0, 55.0), type: 'COLLAPSED_OVERPASS' },
    { id: 'gorge_pipe_manifold', name: 'Old-Ones Industrial Pipe Manifold', position: vec3(-638.0, 0.5, 75.0), type: 'CORRODED_PIPELINE' },
    { id: 'gorge_pipe_conduit_1', name: 'Talus-Buried Steel Pipe Conduit', position: vec3(-660.0, 0.4, 95.0), type: 'CORRODED_PIPELINE' },
    { id: 'gorge_pipe_conduit_2', name: 'Warped Feedline Joint', position: vec3(-642.0, 0.6, 125.0), type: 'CORRODED_PIPELINE' },
  ],
} as const;

export const NORTH_ALKALI_CONFIG = {
  quadrantBounds: { minX: -300.0, maxX: 300.0, minZ: 400.0, maxZ: 900.0 },
  basinCenter: vec3(0.0, 0.0, 650.0),
  basinFloorElevation: -1.8,
  badlandRimElevation: 6.5,
  beaconPosition: vec3(45.0, -1.2, 680.0),
  environmentalParameters: {
    fogColorHex: '#e0dcc2', fogDensity: 0.015, volumetricFogDensity: 0.025,
    sunEnergy: 2.4, sunVisibility: 1.0, silicaAccumulationMultiplier: 1.0,
    saltCorrosionMultiplier: 2.0, kaBeaconResonanceMultiplier: 1.0, weatherTone: 'BLEACHED_ALKALI_SINK',
  },
  landmarks: [
    { id: 'north_alkali_beacon_monolith', name: 'Ka Survey Beacon Monolith Pylon', position: vec3(45.0, -1.2, 680.0), type: 'KA_BEACON_MONOLITH' },
    { id: 'north_alkali_hex_plinth', name: 'Stepped Hexagonal Foundation Plinth', position: vec3(45.0, -1.2, 680.0), type: 'MONOLITH_PLINTH' },
    { id: 'north_alkali_power_conduit_1', name: 'NCP Armored Power Conduit Alpha', position: vec3(35.0, -1.5, 665.0), type: 'POWER_CONDUIT' },
    { id: 'north_alkali_power_conduit_2', name: 'NCP Armored Power Conduit Beta', position: vec3(55.0, -1.4, 695.0), type: 'POWER_CONDUIT' },
    { id: 'north_alkali_mineral_mound_1', name: 'Alkali Sulfur Crust Mound 1', position: vec3(-40.0, -1.6, 640.0), type: 'MINERAL_MOUND' },
    { id: 'north_alkali_mineral_mound_2', name: 'Alkali Sulfur Crust Mound 2', position: vec3(70.0, -1.5, 630.0), type: 'MINERAL_MOUND' },
  ],
} as const;

export const EAST_DUNES_CONFIG = {
  quadrantBounds: { minX: 400.0, maxX: 900.0, minZ: -300.0, maxZ: 300.0 },
  ergCenter: vec3(650.0, 0.0, 50.0),
  interduneTroughElevation: -2.0,
  megaDuneCrestElevationMin: 8.0,
  megaDuneCrestElevationMax: 15.5,
  ruinPocketPosition: vec3(680.0, 1.8, -20.0),
  environmentalParameters: {
    fogColorHex: '#bf9e73', fogDensity: 0.006, volumetricFogDensity: 0.009,
    sunEnergy: 2.65, sunVisibility: 1.0, silicaAccumulationMultiplier: 2.2,
    staminaDrainMultiplier: 1.6, weatherTone: 'GREAT_SHIFTING_ERG',
  },
  landmarks: [
    { id: 'east_dunes_old_ones_ruin', name: 'Tilted Old-Ones Megastructure Superstructure', position: vec3(680.0, 1.8, -20.0), type: 'OLD_ONES_MEGASTRUCTURE' },
    { id: 'east_dunes_external_truss', name: 'Protruding Heavy Steel I-Beam Truss', position: vec3(683.0, 6.2, -18.0), type: 'OLD_ONES_MEGASTRUCTURE' },
    { id: 'east_dunes_obsidian_rib', name: 'Half-Buried Obsidian Pylon Rib', position: vec3(674.0, 2.5, -24.0), type: 'OLD_ONES_MEGASTRUCTURE' },
    { id: 'east_dunes_gantry_strut_1', name: 'Half-Buried Steel Gantry Strut 1', position: vec3(655.0, -0.8, 15.0), type: 'GANTRY_STRUT' },
    { id: 'east_dunes_gantry_strut_2', name: 'Half-Buried Steel Gantry Strut 2', position: vec3(635.0, -1.2, -45.0), type: 'GANTRY_STRUT' },
    { id: 'east_dunes_boundary_pylon', name: 'Wind-Scoured Obsidian Boundary Pylon', position: vec3(715.0, -0.5, 65.0), type: 'OBSIDIAN_PYLON' },
  ],
} as const;

export const TOWER_THRESHOLD_CONFIG = {
  quadrantBounds: { minX: 400.0, maxX: 900.0, minZ: 400.0, maxZ: 900.0 },
  citadelCenter: vec3(700.0, 9.0, 700.0),
  citadelPlateauElevation: 9.0,
  fissureTroughElevation: -2.2,
  approachTerraceElevation: 2.0,
  environmentalParameters: {
    fogColorHex: '#47080a', fogDensity: 0.018, volumetricFogDensity: 0.032,
    sunEnergy: 1.95, sunVisibility: 0.85, silicaAccumulationMultiplier: 2.4,
    staminaDrainMultiplier: 1.2, towerNexusStrainMultiplier: 1.0, weatherTone: 'BLOOD_CRIMSON_STORM',
  },
  landmarks: [
    { id: 'dark_tower_spire', name: 'The Dark Tower Citadel Spire', position: vec3(700.0, 9.0, 700.0), type: 'DARK_TOWER_SPIRE' },
    { id: 'tower_hedgehog_line_1', name: 'Czech Hedgehog Fortification Line Alpha', position: vec3(575.0, 3.2, 575.0), type: 'CZECH_HEDGEHOG' },
    { id: 'tower_hedgehog_line_2', name: 'Czech Hedgehog Fortification Line Beta', position: vec3(605.0, 4.4, 605.0), type: 'CZECH_HEDGEHOG' },
    { id: 'tower_concertina_wire', name: 'Coiled Concertina Razor-Wire Barrier', position: vec3(590.0, 3.8, 590.0), type: 'CONCERTINA_WIRE' },
    { id: 'tower_armored_wreck_1', name: 'Gutted Old-Ones Main Battle Tank Hull', position: vec3(565.0, 2.8, 575.0), type: 'ARMORED_WRECK' },
    { id: 'tower_armored_wreck_2', name: 'Shattered Heavy Armored Personnel Carrier', position: vec3(615.0, 4.8, 605.0), type: 'ARMORED_WRECK' },
  ],
} as const;

