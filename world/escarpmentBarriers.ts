/**
 * Hybrid Terrain Escarpment Barriers (Option C)
 * Defines the 5 Escarpment Barrier Chains, Canyon Defiles, and Mesa Elevation Math.
 * Provides 1:1 mathematical parity with terrain_collision.gd and wasteland_terrain.gdshader.
 */

export interface Segment2D {
  ax: number;
  az: number;
  bx: number;
  bz: number;
}

export interface BarrierChain {
  id: string;
  name: string;
  segments: Segment2D[];
}

export const BARRIER_CONSTANTS = {
  CORE_HALF_WIDTH: 26.0,
  SLOPE_RADIUS: 82.0,
  PEAK_HEIGHT: 52.0,
  DEFILE_INNER_RADIUS: 16.0,
  DEFILE_OUTER_RADIUS: 40.0,
  DRESSER_SAMPLE_STEP: 28.0,
  DRESSER_MIN_OFFSET: 22.0,
  DRESSER_MAX_OFFSET: 48.0,
  DRESSER_PASS_CLEARANCE: 36.0,
  DRESSER_SINK_DEPTH: 4.0,
};

// ─── 6 Escarpment Barrier Chains (14 Segments) ──────────────────────────────
export const ESCARPMENT_CHAINS: BarrierChain[] = [
  {
    id: 'chain_0_horseshoe_cradle',
    name: 'Chain 0 (Mohaine Horseshoe Cradle)',
    segments: [
      { ax: -1250.0, az: -1100.0, bx: -1225.0, bz: -1225.0 }, // West wing
      { ax: -1225.0, az: -1225.0, bx: -1100.0, bz: -1250.0 }, // South wing
    ],
  },
  {
    id: 'chain_1_mohaine_north_rim',
    name: 'Chain 1 (Mohaine North Rim)',
    segments: [
      { ax: -1250.0, az: -650.0, bx: -750.0, bz: -600.0 },
      { ax: -750.0, az: -600.0, bx: -650.0, bz: -660.0 },
    ],
  },
  {
    id: 'chain_2_sw_desolation_east_wall',
    name: 'Chain 2 (SW Desolation East Wall)',
    segments: [
      { ax: -450.0, az: -1250.0, bx: -400.0, bz: -900.0 },
      { ax: -400.0, az: -900.0, bx: -450.0, bz: -650.0 },
    ],
  },
  {
    id: 'chain_3_central_great_divide',
    name: 'Chain 3 (Central Great Divide)',
    segments: [
      { ax: -780.0, az: -100.0, bx: 0.0, bz: -100.0 },
      { ax: 0.0, az: -100.0, bx: 420.0, bz: -100.0 },
      { ax: 420.0, az: -100.0, bx: 750.0, bz: -60.0 },
      { ax: 750.0, az: -60.0, bx: 950.0, bz: -100.0 },
    ],
  },
  {
    id: 'chain_4_se_meridian_wall',
    name: 'Chain 4 (SE Meridian Wall)',
    segments: [
      { ax: 420.0, az: -100.0, bx: 420.0, bz: -650.0 },
    ],
  },
  {
    id: 'chain_5_bastions',
    name: 'Chain 5 (North Spur & Citadel Bastion)',
    segments: [
      { ax: -1250.0, az: 500.0, bx: -780.0, bz: 500.0 }, // 5A: Rust-Gorge North Spur
      { ax: 150.0, az: 1250.0, bx: 150.0, bz: 500.0 },   // 5B West Wing
      { ax: 150.0, az: 500.0, bx: 620.0, bz: 500.0 },    // 5B South Wing
    ],
  },
];

// Flat list of all 12 barrier segments
export const ALL_BARRIER_SEGMENTS: Segment2D[] = ESCARPMENT_CHAINS.flatMap((c) => c.segments);

// ─── 5 Active Crossing Canyon Passes ─────────────────────────────────────────
export const DEFILE_PASS_SEGMENTS: Segment2D[] = [
  { ax: -450.0, az: -800.0, bx: -250.0, bz: -650.0 }, // Node 1 -> 2 (pass_sw_to_salt)
  { ax: -100.0, az: -420.0, bx: -30.0, bz: -150.0 },  // Node 2 -> 3 (pass_salt_to_cradle)
  { ax: -150.0, az: 15.0, bx: -500.0, bz: 40.0 },     // Node 3 -> 4 (pass_cradle_to_gorge)
  { ax: 150.0, az: 15.0, bx: 500.0, bz: 40.0 },       // Node 3 -> 6 (pass_cradle_to_east)
  { ax: 150.0, az: 650.0, bx: 500.0, bz: 650.0 },     // Node 5 -> 7 (pass_north_to_monolith)
];

// ─── Geometric & Noise Helpers ──────────────────────────────────────────────

export function segmentDistance2D(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number {
  const dx = bx - ax;
  const dz = bz - az;
  const l2 = dx * dx + dz * dz;
  if (l2 === 0.0) {
    return Math.hypot(px - ax, pz - az);
  }
  const t = Math.max(0.0, Math.min(1.0, ((px - ax) * dx + (pz - az) * dz) / l2));
  return Math.hypot(px - (ax + t * dx), pz - (az + t * dz));
}

export function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = Math.max(0.0, Math.min(1.0, (x - edge0) / (edge1 - edge0)));
  return t * t * (3.0 - 2.0 * t);
}

function fract(x: number): number {
  return x - Math.floor(x);
}

function hash2(x: number, y: number): number {
  let px = fract(x * 127.1);
  let py = fract(y * 311.7);
  const dot = px * (px + 19.31) + py * (py + 19.31);
  px += dot;
  py += dot;
  return fract(px * py);
}

function valueNoise(x: number, y: number): number {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  const fx = fract(x);
  const fy = fract(y);
  const ux = fx * fx * (3.0 - 2.0 * fx);
  const uy = fy * fy * (3.0 - 2.0 * fy);

  const a = hash2(ix, iy);
  const b = hash2(ix + 1.0, iy);
  const c = hash2(ix, iy + 1.0);
  const d = hash2(ix + 1.0, iy + 1.0);

  const ab = a + (b - a) * ux;
  const cd = c + (d - c) * ux;
  return ab + (cd - ab) * uy;
}

export function fbm2D(x: number, y: number, octaves: number): number {
  let v = 0.0;
  let amp = 0.5;
  let freq = 1.0;
  for (let i = 0; i < octaves; i++) {
    v += valueNoise(x * freq, y * freq) * amp;
    amp *= 0.5;
    freq *= 2.1;
  }
  return v;
}

/**
 * Computes shortest distance from (x, z) to all 12 barrier segments.
 */
export function getMinBarrierDistance(x: number, z: number): number {
  let minDist = Infinity;
  for (const seg of ALL_BARRIER_SEGMENTS) {
    const d = segmentDistance2D(x, z, seg.ax, seg.az, seg.bx, seg.bz);
    if (d < minDist) {
      minDist = d;
    }
  }
  return minDist;
}

/**
 * Computes shortest distance from (x, z) to the 5 active crossing canyon passes.
 */
export function getMinDefilePassDistance(x: number, z: number): number {
  let minDist = Infinity;
  for (const seg of DEFILE_PASS_SEGMENTS) {
    const d = segmentDistance2D(x, z, seg.ax, seg.az, seg.bx, seg.bz);
    if (d < minDist) {
      minDist = d;
    }
  }
  return minDist;
}

/**
 * Calculates the exact procedural barrier elevation added on top of base terrain height.
 */
export function calculateBarrierElevation(worldX: number, worldZ: number): number {
  const dBarrier = getMinBarrierDistance(worldX, worldZ);
  if (dBarrier >= BARRIER_CONSTANTS.SLOPE_RADIUS) {
    return 0.0;
  }

  // Flat-topped mesa profile: core 26m, talus slope out to 82m
  const mesaProfile = 1.0 - smoothstep(BARRIER_CONSTANTS.CORE_HALF_WIDTH, BARRIER_CONSTANTS.SLOPE_RADIUS, dBarrier);

  // Deterministic ridged noise erosion shaping
  const ridgeNoise = Math.abs(fbm2D(worldX * 0.014, worldZ * 0.014, 2) * 2.0 - 1.0);
  const erosion = 1.0 - 0.10 * ridgeNoise;

  let hBarrier = BARRIER_CONSTANTS.PEAK_HEIGHT * mesaProfile * erosion;

  // Canyon Defile Carving Mask: 32m wide defile (inner 16m = 0.0, outer 40m = 1.0)
  const dPass = getMinDefilePassDistance(worldX, worldZ);
  const carveMask = smoothstep(BARRIER_CONSTANTS.DEFILE_INNER_RADIUS, BARRIER_CONSTANTS.DEFILE_OUTER_RADIUS, dPass);
  hBarrier *= carveMask;

  // Node 0 Sanctuary Clearing Mask at (-1180.0, -1180.0): inner 28m = 0.0, outer 48m = 1.0
  const dSanctuary = Math.hypot(worldX - (-1180.0), worldZ - (-1180.0));
  const sanctuaryMask = smoothstep(28.0, 48.0, dSanctuary);
  hBarrier *= sanctuaryMask;

  return hBarrier;
}

