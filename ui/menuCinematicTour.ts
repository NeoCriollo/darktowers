/**
 * Menu Cinematic Tour Sub-Controller Contracts — "Dark Towers: The Path of Ka"
 * Defines the 8 curated Wasteland Vistas, Telephoto Spiral Math, Timing, and Transition Logic.
 */

export interface TourVista {
  id: string;
  name: string;
  poiCenter: [number, number, number];
  rStart: number;
  hStart: number;
  theta0: number;
  locationEn: string;
  locationEs: string;
  atmosphereEn: string;
  atmosphereEs: string;
  preset: string;
  sunEnergy: number;
  sunColor: [number, number, number];
  fogDensity: number;
  dollyZoom?: boolean;
}

export const SPIRAL_CONFIG = {
  OMEGA: 0.025,
  K_R: 1.4,
  K_H: 0.65,
  BASE_FOV: 36.0,
  RADIUS_MULTIPLIER: 1.9,
};

export const DOLLY_CONFIG = {
  DOLLY_FOV_MIN: 36.0,
  DOLLY_FOV_MAX: 65.0,
  TARGET_WIDTH: 45.0,
  DOLLY_ZONES: [3, 7],
};

export const HABOOB_CONFIG = {
  BURST_AMOUNT: 80,
  LIFETIME: 1.2,
  EXPLOSIVENESS: 0.85,
  DUST_COLOR_HEX: '#c2b280',
  OCCLUSION_WINDOW: 0.4, // ~0.4s dense occlusion window
  NEAR_PLANE_Z: -0.5,
};

export const TOUR_TIMING = {
  HOLD_DURATION: 8.5,
  FADE_DURATION: 1.3,
  TOTAL_VISTA_CYCLE: 11.1, // 8.5s hold + 2.6s crossfade
};

// 8 Curated Regional Wasteland Vistas with Telephoto Radii (Base * 1.9)
export const TOUR_VISTAS: TourVista[] = [
  {
    id: 'vista_0_bunker',
    name: 'Mohaine Way-Bunker & Horseshoe Cradle',
    poiCenter: [-1180.0, 1.8, -1180.0],
    rStart: 95.0 * SPIRAL_CONFIG.RADIUS_MULTIPLIER, // 180.5m
    hStart: 48.0,
    theta0: 3.93,
    dollyZoom: false,
    locationEn: '0 · THE MOHAINE WAY-BUNKER  |  SECTOR: PILGRIMAGE THRESHOLD',
    locationEs: '0 · REFUGIO MOHAINE  |  SECTOR: UMBRAL DE LA PEREGRINACIÓN',
    atmosphereEn: 'ATMOSPHERE: COPPER TWILIGHT  |  AIRBORNE SILICA: 11.4 mg/m³',
    atmosphereEs: 'ATMÓSFERA: CREPÚSCULO COBRIZO  |  SÍLICE EN SUSPENSIÓN: 11.4 mg/m³',
    preset: 'sw_desolation',
    sunEnergy: 1.4,
    sunColor: [0.98, 0.52, 0.24],
    fogDensity: 0.012,
  },
  {
    id: 'vista_1_sw_desolation',
    name: 'SW Desolation & Yardang Ridges',
    poiCenter: [-530.0, 6.0, -840.0],
    rStart: 110.0 * SPIRAL_CONFIG.RADIUS_MULTIPLIER, // 209.0m
    hStart: 55.0,
    theta0: 3.50,
    dollyZoom: false,
    locationEn: 'I · SOUTHWEST DESOLATION  |  SECTOR: YARDANG RIDGES',
    locationEs: 'I · DESOLACIÓN DEL SUROESTE  |  SECTOR: CRESTAS DE YARDANG',
    atmosphereEn: 'ATMOSPHERE: GALE DRIFT  |  AIRBORNE SILICA: 28.5 mg/m³',
    atmosphereEs: 'ATMÓSFERA: BORRASCA DE POLVO  |  SÍLICE EN SUSPENSIÓN: 28.5 mg/m³',
    preset: 'sw_desolation',
    sunEnergy: 0.9,
    sunColor: [0.96, 0.62, 0.32],
    fogDensity: 0.028,
  },
  {
    id: 'vista_2_south_salt',
    name: 'Dead-Creek Salt Flats',
    poiCenter: [-130.0, 3.0, -510.0],
    rStart: 130.0 * SPIRAL_CONFIG.RADIUS_MULTIPLIER, // 247.0m
    hStart: 60.0,
    theta0: 2.80,
    dollyZoom: false,
    locationEn: 'II · DEAD-CREEK SALT FLATS  |  SECTOR: BLEACHED PLAYA',
    locationEs: 'II · SALAR DE DEAD-CREEK  |  SECTOR: PLAYA DE ÁLCALI BLANQUEADO',
    atmosphereEn: 'ATMOSPHERE: HIGH GLARE  |  AIRBORNE SILICA: 5.7 mg/m³',
    atmosphereEs: 'ATMÓSFERA: RESPLANDOR CEGADOR  |  SÍLICE EN SUSPENSIÓN: 5.7 mg/m³',
    preset: 'south_salt',
    sunEnergy: 2.8,
    sunColor: [1.0, 0.98, 0.88],
    fogDensity: 0.006,
  },
  {
    id: 'vista_3_cradle_thinny',
    name: 'Caliche Cradle & Thinny Overlook',
    poiCenter: [140.0, 10.0, 140.0],
    rStart: 120.0 * SPIRAL_CONFIG.RADIUS_MULTIPLIER, // 228.0m
    hStart: 65.0,
    theta0: 4.20,
    dollyZoom: true,
    locationEn: 'III · CALICHE CRADLE  |  SECTOR: THINNY OVERLOOK',
    locationEs: 'III · CUNA DE CALICHE  |  SECTOR: MIRADOR DE LA GRIETA THINNY',
    atmosphereEn: 'ATMOSPHERE: BEAM WARP  |  KA RESONANCE: 432.0 Hz',
    atmosphereEs: 'ATMÓSFERA: DISTORSIÓN DEL HAZ  |  RESONANCIA: 432.0 Hz',
    preset: 'cradle',
    sunEnergy: 2.0,
    sunColor: [0.85, 0.92, 0.98],
    fogDensity: 0.008,
  },
  {
    id: 'vista_4_west_gorge',
    name: 'Rust-Gorge Defile & Collapsed Highway',
    poiCenter: [-650.0, 12.0, 25.0],
    rStart: 100.0 * SPIRAL_CONFIG.RADIUS_MULTIPLIER, // 190.0m
    hStart: 58.0,
    theta0: 1.60,
    dollyZoom: false,
    locationEn: 'IV · RUST-GORGE DEFILE  |  SECTOR: COLLAPSED HIGHWAY SPAN',
    locationEs: 'IV · DESFILADERO DE HERRUMBRE  |  SECTOR: VIADUCTO COLAPSADO',
    atmosphereEn: 'ATMOSPHERE: IRON-OXIDE DUST  |  AIRBORNE SILICA: 32.1 mg/m³',
    atmosphereEs: 'ATMÓSFERA: POLVO DE ÓXIDO FÉRREO  |  SÍLICE EN SUSPENSIÓN: 32.1 mg/m³',
    preset: 'west_gorge',
    sunEnergy: 1.2,
    sunColor: [0.92, 0.80, 0.68],
    fogDensity: 0.022,
  },
  {
    id: 'vista_5_north_alkali',
    name: 'Bleached Alkali Sink & Ka Beacon Monolith',
    poiCenter: [45.0, 8.0, 680.0],
    rStart: 95.0 * SPIRAL_CONFIG.RADIUS_MULTIPLIER, // 180.5m
    hStart: 52.0,
    theta0: 3.14,
    dollyZoom: false,
    locationEn: 'V · ALKALI SINK BASIN  |  SECTOR: KA BEACON MONOLITH',
    locationEs: 'V · CUENCA ALCALINA  |  SECTOR: MONOLITO DEL HAZ DE KA',
    atmosphereEn: 'ATMOSPHERE: COPPER TWILIGHT  |  AIRBORNE SILICA: 14.2 mg/m³',
    atmosphereEs: 'ATMÓSFERA: CREPÚSCULO DE COBRE  |  SÍLICE EN SUSPENSIÓN: 14.2 mg/m³',
    preset: 'north_alkali',
    sunEnergy: 2.2,
    sunColor: [0.98, 0.96, 0.88],
    fogDensity: 0.015,
  },
  {
    id: 'vista_6_east_dunes',
    name: 'The Great Shifting Erg & Megastructure Ruins',
    poiCenter: [680.0, 12.0, -20.0],
    rStart: 140.0 * SPIRAL_CONFIG.RADIUS_MULTIPLIER, // 266.0m
    hStart: 70.0,
    theta0: 0.80,
    dollyZoom: false,
    locationEn: 'VI · THE GREAT SHIFTING ERG  |  SECTOR: OLD-ONES RUINS',
    locationEs: 'VI · EL GRAN ERG MÓVIL  |  SECTOR: RUINAS DE LOS ANTIGUOS',
    atmosphereEn: 'ATMOSPHERE: SILICA GALE  |  AIRBORNE SILICA: 39.4 mg/m³',
    atmosphereEs: 'ATMÓSFERA: VENTISCA DE SÍLICE  |  SÍLICE EN SUSPENSIÓN: 39.4 mg/m³',
    preset: 'east_dunes',
    sunEnergy: 2.5,
    sunColor: [1.0, 0.95, 0.85],
    fogDensity: 0.010,
  },
  {
    id: 'vista_7_dark_tower',
    name: 'The Dark Tower Citadel Pinnacle',
    poiCenter: [700.0, 42.0, 700.0],
    rStart: 160.0 * SPIRAL_CONFIG.RADIUS_MULTIPLIER, // 304.0m
    hStart: 85.0,
    theta0: 3.93,
    dollyZoom: true,
    locationEn: 'VII · THE DARK TOWER CITADEL  |  SECTOR: PINNACLE OF KA',
    locationEs: 'VII · CIUDADELA DE LA TORRE OSCURA  |  SECTOR: CÚSPIDE DEL HAZ',
    atmosphereEn: 'ATMOSPHERE: HABOOB TEMPEST  |  AIRBORNE SILICA: 68.0 mg/m³',
    atmosphereEs: 'ATMÓSFERA: TEMPESTAD DE HABOOB  |  SÍLICE EN SUSPENSIÓN: 68.0 mg/m³',
    preset: 'tower_threshold',
    sunEnergy: 1.8,
    sunColor: [0.95, 0.16, 0.14],
    fogDensity: 0.020,
  },
];

/**
 * Computes descending spiral orbital position for a given vista at time t.
 * For zones 3 & 7 (Thinny and Tower), applies Selective Dolly Zoom vertigo math:
 * dynamic_radius = TARGET_WIDTH / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))
 */
export function computeDescendingSpiralPosition(
  vista: TourVista,
  t: number,
  vistaIndex: number = -1
): {
  cameraPos: [number, number, number];
  cameraLook: [number, number, number];
  currentRadius: number;
  currentHeight: number;
  fov: number;
  isDollyZoom: boolean;
} {
  const isDolly = Boolean(vista.dollyZoom || (vistaIndex >= 0 && DOLLY_CONFIG.DOLLY_ZONES.includes(vistaIndex)));
  const currentHeight = vista.hStart - (SPIRAL_CONFIG.K_H * t);
  const angle = vista.theta0 + (SPIRAL_CONFIG.OMEGA * t);

  let currentFov = SPIRAL_CONFIG.BASE_FOV;
  let currentRadius = vista.rStart - (SPIRAL_CONFIG.K_R * t);

  if (isDolly) {
    const progress = Math.min(Math.max(t / TOUR_TIMING.HOLD_DURATION, 0.0), 1.0);
    currentFov = DOLLY_CONFIG.DOLLY_FOV_MIN + (DOLLY_CONFIG.DOLLY_FOV_MAX - DOLLY_CONFIG.DOLLY_FOV_MIN) * progress;
    const halfFovRad = (currentFov * Math.PI) / 360.0;
    currentRadius = DOLLY_CONFIG.TARGET_WIDTH / (2.0 * Math.tan(halfFovRad));
  }

  const camX = vista.poiCenter[0] + currentRadius * Math.cos(angle);
  const camY = vista.poiCenter[1] + currentHeight;
  const camZ = vista.poiCenter[2] + currentRadius * Math.sin(angle);

  return {
    cameraPos: [camX, camY, camZ],
    cameraLook: [vista.poiCenter[0], vista.poiCenter[1], vista.poiCenter[2]],
    currentRadius,
    currentHeight,
    fov: currentFov,
    isDollyZoom: isDolly,
  };
}

export function computeTourPhase(elapsedTime: number): {
  vistaIndex: number;
  phase: 'HOLD' | 'HABOOB_SURGE' | 'HABOOB_PEAK' | 'HABOOB_CLEAR' | 'FADE_OUT' | 'FADE_IN';
  fadeAlpha: number;
  dustOpacity: number;
  isOccluded: boolean;
  timeInVista: number;
} {
  const totalCycle = TOUR_TIMING.TOTAL_VISTA_CYCLE;
  const numVistas = TOUR_VISTAS.length;
  const grandDuration = totalCycle * numVistas;

  const loopedTime = ((elapsedTime % grandDuration) + grandDuration) % grandDuration;
  const rawIndex = Math.floor(loopedTime / totalCycle);
  const vistaIndex = Math.min(rawIndex, numVistas - 1);
  const timeInVista = loopedTime - vistaIndex * totalCycle;

  if (timeInVista < TOUR_TIMING.HOLD_DURATION) {
    return {
      vistaIndex,
      phase: 'HOLD',
      fadeAlpha: 0.0,
      dustOpacity: 0.0,
      isOccluded: false,
      timeInVista,
    };
  }

  const transitionTime = timeInVista - TOUR_TIMING.HOLD_DURATION;

  if (transitionTime < 0.9) {
    // Surge onset (0.0 to 0.9s)
    const t = transitionTime / 0.9;
    const alpha = t * t * (3.0 - 2.0 * t);
    return {
      vistaIndex,
      phase: 'HABOOB_SURGE',
      fadeAlpha: alpha,
      dustOpacity: alpha,
      isOccluded: false,
      timeInVista,
    };
  } else if (transitionTime < 1.3) {
    // Peak occlusion window (~0.4s between 0.9s and 1.3s)
    const nextIndex = (vistaIndex + 1) % numVistas;
    const effectiveIndex = transitionTime >= 1.1 ? nextIndex : vistaIndex;
    return {
      vistaIndex: effectiveIndex,
      phase: 'HABOOB_PEAK',
      fadeAlpha: 1.0,
      dustOpacity: 1.0,
      isOccluded: true,
      timeInVista,
    };
  } else {
    // Dispersal (1.3 to 2.6s)
    const nextIndex = (vistaIndex + 1) % numVistas;
    const t = (transitionTime - 1.3) / 1.3;
    const alpha = Math.max(0.0, 1.0 - t * t * (3.0 - 2.0 * t));
    return {
      vistaIndex: nextIndex,
      phase: 'HABOOB_CLEAR',
      fadeAlpha: alpha,
      dustOpacity: alpha,
      isOccluded: false,
      timeInVista,
    };
  }
}
