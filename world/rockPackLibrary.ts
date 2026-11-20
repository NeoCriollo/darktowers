/**
 * Dark Towers: The Path of Ka
 * Photogrammetry Rock Pack Library & Area 1 Sanctuary Placement Metadata
 *
 * Captures the 7 photogrammetry rock nodes from THREE.GLTFExporter r183,
 * normalized to [-0.5, +0.5] unit space, their analytical bounding boxes,
 * culling tiers, and Area 1 (Node 0: Mohaine Way-Bunker) placements.
 */

export interface RockMetadata {
  readonly name: string;
  readonly tier: 'TierA' | 'TierB' | 'TierC';
  readonly vertexCount: number;
  readonly min: readonly [number, number, number];
  readonly max: readonly [number, number, number];
  readonly rawSize: readonly [number, number, number];
  readonly rawCenter: readonly [number, number, number];
  readonly defaultVisibilityRangeEnd: number;
}

export interface ScaledAABB {
  readonly rockName: string;
  readonly tier: string;
  readonly minX: number;
  readonly maxX: number;
  readonly minY: number;
  readonly maxY: number;
  readonly minZ: number;
  readonly maxZ: number;
  readonly sizeX: number;
  readonly sizeY: number;
  readonly sizeZ: number;
  readonly centerX: number;
  readonly centerY: number;
  readonly centerZ: number;
}

export interface SanctuaryRockPlacement {
  readonly rockName: string;
  readonly category: 'outcrop_shelf' | 'caliche_slab' | 'crouch_boulder';
  readonly worldX: number;
  readonly worldZ: number;
  readonly scaleX: number;
  readonly scaleY: number;
  readonly scaleZ: number;
  readonly sinkDepth: number;
  readonly rotYDeg: number;
}

export const ROCK_PACK_REGISTRY: Readonly<Record<string, RockMetadata>> = {
  'Rock3 (5K)': {
    name: 'Rock3 (5K)',
    tier: 'TierA',
    vertexCount: 7704,
    min: [-0.500013, -0.241794, -0.313261],
    max: [0.500013, 0.241792, 0.313260],
    rawSize: [1.000026, 0.483586, 0.626521],
    rawCenter: [0.0, -0.000001, -0.0000005],
    defaultVisibilityRangeEnd: 350.0
  },
  'Rock5b (11K)': {
    name: 'Rock5b (11K)',
    tier: 'TierA',
    vertexCount: 7173,
    min: [-0.378313, -0.127112, -0.500018],
    max: [0.378313, 0.127112, 0.500018],
    rawSize: [0.756626, 0.254224, 1.000036],
    rawCenter: [0.0, 0.0, 0.0],
    defaultVisibilityRangeEnd: 350.0
  },
  'Rock5c (23K)': {
    name: 'Rock5c (23K)',
    tier: 'TierB',
    vertexCount: 14779,
    min: [-0.434741, -0.500020, -0.279218],
    max: [0.434741, 0.500020, 0.279218],
    rawSize: [0.869482, 1.000040, 0.558436],
    rawCenter: [0.0, 0.0, 0.0],
    defaultVisibilityRangeEnd: 900.0
  },
  'Rock5a (37K)': {
    name: 'Rock5a (37K)',
    tier: 'TierB',
    vertexCount: 24591,
    min: [-0.500095, -0.455214, -0.274273],
    max: [0.500095, 0.455214, 0.274273],
    rawSize: [1.000190, 0.910428, 0.548546],
    rawCenter: [0.0, 0.0, 0.0],
    defaultVisibilityRangeEnd: 900.0
  },
  'Rock1 (38K)': {
    name: 'Rock1 (38K)',
    tier: 'TierC',
    vertexCount: 26044,
    min: [-0.478779, -0.212692, -0.500028],
    max: [0.478779, 0.212692, 0.500028],
    rawSize: [0.957558, 0.425384, 1.000056],
    rawCenter: [0.0, 0.0, 0.0],
    defaultVisibilityRangeEnd: 900.0
  },
  'Rock2 (41K)': {
    name: 'Rock2 (41K)',
    tier: 'TierC',
    vertexCount: 31556,
    min: [-0.500003, -0.215991, -0.360493],
    max: [0.500003, 0.215991, 0.360493],
    rawSize: [1.000006, 0.431982, 0.720986],
    rawCenter: [0.0, 0.0, 0.0],
    defaultVisibilityRangeEnd: 900.0
  },
  'Rock4 (60K)': {
    name: 'Rock4 (60K)',
    tier: 'TierC',
    vertexCount: 40879,
    min: [-0.351002, -0.499981, -0.219056],
    max: [0.351002, 0.499981, 0.219056],
    rawSize: [0.702004, 0.999962, 0.438112],
    rawCenter: [0.0, 0.0, 0.0],
    defaultVisibilityRangeEnd: 900.0
  }
};

export const AREA_1_PLACEMENTS: readonly SanctuaryRockPlacement[] = [
  // 1. Bunker Flank Outcrop Shelves (Tier C)
  { rockName: 'Rock1 (38K)', category: 'outcrop_shelf', worldX: -1015.0, worldZ: -788.0, scaleX: 20.0, scaleY: 16.0, scaleZ: 18.0, sinkDepth: 2.5, rotYDeg: 15.0 },
  { rockName: 'Rock2 (41K)', category: 'outcrop_shelf', worldX: -1038.0, worldZ: -794.0, scaleX: 22.0, scaleY: 18.0, scaleZ: 20.0, sinkDepth: 2.5, rotYDeg: -30.0 },
  { rockName: 'Rock1 (38K)', category: 'outcrop_shelf', worldX: -1045.0, worldZ: -815.0, scaleX: 24.0, scaleY: 19.0, scaleZ: 18.0, sinkDepth: 2.5, rotYDeg: 90.0 },
  { rockName: 'Rock2 (41K)', category: 'outcrop_shelf', worldX: -1038.0, worldZ: -838.0, scaleX: 21.0, scaleY: 17.0, scaleZ: 19.0, sinkDepth: 2.5, rotYDeg: 45.0 },
  { rockName: 'Rock1 (38K)', category: 'outcrop_shelf', worldX: -1015.0, worldZ: -842.0, scaleX: 19.0, scaleY: 15.0, scaleZ: 17.0, sinkDepth: 2.5, rotYDeg: -15.0 },

  // 2. Caliche Slabs (Tier A - Rock5b)
  { rockName: 'Rock5b (11K)', category: 'caliche_slab', worldX: -875.0, worldZ: -842.0, scaleX: 6.0, scaleY: 2.5, scaleZ: 6.0, sinkDepth: 0.8, rotYDeg: 25.0 },
  { rockName: 'Rock5b (11K)', category: 'caliche_slab', worldX: -850.0, worldZ: -805.0, scaleX: 6.5, scaleY: 2.4, scaleZ: 6.2, sinkDepth: 0.9, rotYDeg: -40.0 },
  { rockName: 'Rock5b (11K)', category: 'caliche_slab', worldX: -815.0, worldZ: -835.0, scaleX: 6.0, scaleY: 2.5, scaleZ: 5.8, sinkDepth: 0.8, rotYDeg: 15.0 },
  { rockName: 'Rock5b (11K)', category: 'caliche_slab', worldX: -780.0, worldZ: -855.0, scaleX: 7.0, scaleY: 2.6, scaleZ: 6.5, sinkDepth: 0.9, rotYDeg: 60.0 },
  { rockName: 'Rock5b (11K)', category: 'caliche_slab', worldX: -740.0, worldZ: -840.0, scaleX: 6.2, scaleY: 2.4, scaleZ: 6.0, sinkDepth: 0.8, rotYDeg: -20.0 },
  { rockName: 'Rock5b (11K)', category: 'caliche_slab', worldX: -695.0, worldZ: -868.0, scaleX: 6.5, scaleY: 2.5, scaleZ: 6.5, sinkDepth: 0.85, rotYDeg: 35.0 },
  { rockName: 'Rock5b (11K)', category: 'caliche_slab', worldX: -650.0, worldZ: -885.0, scaleX: 6.0, scaleY: 2.5, scaleZ: 6.0, sinkDepth: 0.8, rotYDeg: -55.0 },

  // 3. Tactical Crouch Cover Boulders (Tier A - Rock3)
  { rockName: 'Rock3 (5K)', category: 'crouch_boulder', worldX: -860.0, worldZ: -836.0, scaleX: 3.2, scaleY: 3.2, scaleZ: 3.0, sinkDepth: 0.4, rotYDeg: 45.0 },
  { rockName: 'Rock3 (5K)', category: 'crouch_boulder', worldX: -825.0, worldZ: -802.0, scaleX: 3.4, scaleY: 3.3, scaleZ: 3.2, sinkDepth: 0.4, rotYDeg: -70.0 },
  { rockName: 'Rock3 (5K)', category: 'crouch_boulder', worldX: -770.0, worldZ: -860.0, scaleX: 3.5, scaleY: 3.5, scaleZ: 3.3, sinkDepth: 0.4, rotYDeg: 20.0 },
  { rockName: 'Rock3 (5K)', category: 'crouch_boulder', worldX: -710.0, worldZ: -838.0, scaleX: 3.3, scaleY: 3.2, scaleZ: 3.1, sinkDepth: 0.4, rotYDeg: -35.0 },
  { rockName: 'Rock3 (5K)', category: 'crouch_boulder', worldX: -660.0, worldZ: -895.0, scaleX: 3.6, scaleY: 3.4, scaleZ: 3.4, sinkDepth: 0.4, rotYDeg: 80.0 }
];

export function computeScaledAABB(
  rockName: string,
  scale: { x: number; y: number; z: number },
  position: { x: number; y: number; z: number } = { x: 0, y: 0, z: 0 }
): ScaledAABB {
  const meta = ROCK_PACK_REGISTRY[rockName];
  if (!meta) {
    throw new Error(`Unknown rock name: ${rockName}`);
  }

  const rawSizeX = meta.rawSize[0];
  const rawSizeY = meta.rawSize[1];
  const rawSizeZ = meta.rawSize[2];

  const sizeX = rawSizeX * scale.x;
  const sizeY = rawSizeY * scale.y;
  const sizeZ = rawSizeZ * scale.z;

  const halfX = sizeX * 0.5;
  const halfY = sizeY * 0.5;
  const halfZ = sizeZ * 0.5;

  return {
    rockName,
    tier: meta.tier,
    minX: position.x - halfX,
    maxX: position.x + halfX,
    minY: position.y - halfY,
    maxY: position.y + halfY,
    minZ: position.z - halfZ,
    maxZ: position.z + halfZ,
    sizeX,
    sizeY,
    sizeZ,
    centerX: position.x,
    centerY: position.y,
    centerZ: position.z
  };
}

export function pointInside2DBox(
  px: number,
  pz: number,
  minX: number,
  maxX: number,
  minZ: number,
  maxZ: number,
  padding: number = 0.0
): boolean {
  return (
    px >= minX - padding &&
    px <= maxX + padding &&
    pz >= minZ - padding &&
    pz <= maxZ + padding
  );
}

export function distancePointToSegment2D(
  px: number,
  pz: number,
  ax: number,
  az: number,
  bx: number,
  bz: number
): number {
  const abx = bx - ax;
  const abz = bz - az;
  const lenSq = abx * abx + abz * abz;
  if (lenSq < 0.0001) {
    const dx = px - ax;
    const dz = pz - az;
    return Math.sqrt(dx * dx + dz * dz);
  }
  const t = Math.max(0.0, Math.min(1.0, ((px - ax) * abx + (pz - az) * abz) / lenSq));
  const nx = ax + t * abx;
  const nz = az + t * abz;
  const dx = px - nx;
  const dz = pz - nz;
  return Math.sqrt(dx * dx + dz * dz);
}

