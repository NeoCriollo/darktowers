/**
 * Dark Towers: The Path of Ka
 * Custom .glb Folder Scanner & Dynamic Previewer Domain (Phase 5)
 *
 * Handles runtime custom 3D asset directory parsing, filename formatting,
 * AABB normalization, pivot recentering, and custom asset layout overrides.
 */

export interface CustomPropEntry {
  readonly id: string;
  readonly category: string;
  readonly name: string;
  readonly glbName: string;
  readonly assetPath: string;
  readonly tierBadge: string;
  readonly scale: { x: number; y: number; z: number };
  readonly sink: number;
  readonly material: string;
}

export interface NormalizationResult {
  readonly scaleFactor: number;
  readonly pivotOffset: { x: number; y: number; z: number };
  readonly maxDimension: number;
  readonly normalizedSize: { x: number; y: number; z: number };
}

export const TARGET_NORMALIZED_DIMENSION = 2.5; // Default ~2.5m human scale
export const MAX_RAW_DIM_THRESHOLD = 50.0;
export const MIN_RAW_DIM_THRESHOLD = 0.15;
export const VALID_3D_EXTENSIONS = ['.glb', '.gltf'] as const;

export function isValid3dFile(fileName: string): boolean {
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.import') || lower.endsWith('.png') || lower.endsWith('.jpg')) {
    return false;
  }
  return VALID_3D_EXTENSIONS.some((ext) => lower.endsWith(ext));
}

export function formatDisplayName(rawStem: string): string {
  const stripped = rawStem.replace(/[-_]/g, '').trim();
  if (stripped.length >= 24 && /^[0-9a-fA-F]+$/.test(stripped)) {
    return 'Model #' + stripped.substring(0, 8).toUpperCase();
  }

  const cleaned = rawStem
    .replace(/_/g, ' ')
    .replace(/-/g, ' ')
    .replace(/\bassets\b/gi, '')
    .replace(/\basset\b/gi, '')
    .replace(/\bfree\b/gi, '')
    .trim();

  const words = cleaned.split(/\s+/).filter((w) => w.length > 0);
  if (words.length === 0) return rawStem;

  return words
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

export function inferMaterialFromName(stem: string): string {
  const lower = stem.toLowerCase();
  if (
    lower.includes('metal') ||
    lower.includes('iron') ||
    lower.includes('steel') ||
    lower.includes('beam') ||
    lower.includes('bunker')
  ) {
    return 'STEEL';
  }
  if (
    lower.includes('wood') ||
    lower.includes('plank') ||
    lower.includes('door') ||
    lower.includes('pole')
  ) {
    return 'WOOD';
  }
  if (lower.includes('bone') || lower.includes('skull') || lower.includes('rib')) {
    return 'BONE';
  }
  if (lower.includes('energy') || lower.includes('plasma') || lower.includes('thinny')) {
    return 'ENERGY';
  }
  return 'STONE';
}

export function parseCustomPropsDirectory(
  fileNames: readonly string[],
  baseDir: string = 'res://assets/custom_props/'
): CustomPropEntry[] {
  const entries: CustomPropEntry[] = [];
  const normalizedBase = baseDir.endsWith('/') ? baseDir : baseDir + '/';

  for (const fileName of fileNames) {
    if (!isValid3dFile(fileName) || fileName.startsWith('.')) {
      continue;
    }

    const dotIndex = fileName.lastIndexOf('.');
    const stem = dotIndex >= 0 ? fileName.substring(0, dotIndex) : fileName;
    const cleanId = 'custom_' + stem.toLowerCase().replace(/[\s-]/g, '_');
    const dispName = formatDisplayName(stem);
    const fullPath = normalizedBase + fileName;
    const material = inferMaterialFromName(stem);

    entries.push({
      id: cleanId,
      category: 'custom',
      name: dispName,
      glbName: fileName,
      assetPath: fullPath,
      tierBadge: '[CUSTOM GLB]',
      scale: { x: 1.0, y: 1.0, z: 1.0 },
      sink: 0.1,
      material
    });
  }

  // Alphabetical sort by display name
  entries.sort((a, b) => a.name.localeCompare(b.name));
  return entries;
}

export function computeAABBNormalization(
  minBound: [number, number, number],
  maxBound: [number, number, number],
  targetDimension: number = TARGET_NORMALIZED_DIMENSION
): NormalizationResult {
  const sizeX = Math.max(0.0001, maxBound[0] - minBound[0]);
  const sizeY = Math.max(0.0001, maxBound[1] - minBound[1]);
  const sizeZ = Math.max(0.0001, maxBound[2] - minBound[2]);

  const maxDimension = Math.max(sizeX, Math.max(sizeY, sizeZ));
  let scaleFactor = 1.0;

  if (maxDimension > MAX_RAW_DIM_THRESHOLD || maxDimension < MIN_RAW_DIM_THRESHOLD) {
    scaleFactor = targetDimension / maxDimension;
  }

  // Bottom-center pivot offset: X and Z centered, Y bottom aligned at 0
  const bottomCenterX = minBound[0] + sizeX * 0.5;
  const bottomCenterY = minBound[1];
  const bottomCenterZ = minBound[2] + sizeZ * 0.5;

  const pivotOffset = {
    x: -bottomCenterX,
    y: -bottomCenterY,
    z: -bottomCenterZ
  };

  return {
    scaleFactor,
    pivotOffset,
    maxDimension,
    normalizedSize: {
      x: sizeX * scaleFactor,
      y: sizeY * scaleFactor,
      z: sizeZ * scaleFactor
    }
  };
}

export const COLLISION_LAYER_WORLD = 1;

export interface MockHierarchyNode {
  name: string;
  type: string;
  hasMesh?: boolean;
  collisionLayer?: number;
  collisionMask?: number;
  children: MockHierarchyNode[];
  parent?: MockHierarchyNode;
  meta: Record<string, unknown>;
}

export interface CollisionGenerationReport {
  checkedMeshes: number;
  generatedCollisions: number;
  existingCollisions: number;
}

export function simulateMeshCollisionPass(
  root: MockHierarchyNode,
  options: {
    collisionLayer?: number;
    ballisticMaterial?: string;
    useTrimesh?: boolean;
  } = {}
): CollisionGenerationReport {
  const layer = options.collisionLayer ?? COLLISION_LAYER_WORLD;
  const mat = options.ballisticMaterial ?? 'STONE';
  const report: CollisionGenerationReport = {
    checkedMeshes: 0,
    generatedCollisions: 0,
    existingCollisions: 0
  };

  const meshes: MockHierarchyNode[] = [];
  function gather(node: MockHierarchyNode) {
    if (node.type === 'MeshInstance3D' && node.hasMesh !== false) {
      meshes.push(node);
    }
    for (const ch of node.children) {
      ch.parent = node;
      gather(ch);
    }
  }
  gather(root);

  for (const mi of meshes) {
    report.checkedMeshes++;
    if (hasCollision(mi)) {
      report.existingCollisions++;
      continue;
    }

    const sb: MockHierarchyNode = {
      name: `${mi.name}_col`,
      type: 'StaticBody3D',
      collisionLayer: layer,
      collisionMask: 0,
      children: [
        {
          name: `${mi.name}_shape`,
          type: 'CollisionShape3D',
          children: [],
          meta: {}
        }
      ],
      meta: {
        ballistic_material: mat,
        reactive_target: true
      }
    };
    sb.parent = mi;
    mi.children.push(sb);
    report.generatedCollisions++;
  }

  return report;
}

function hasCollision(mi: MockHierarchyNode): boolean {
  for (const ch of mi.children) {
    if (ch.type === 'CollisionObject3D' || ch.type === 'StaticBody3D' || ch.type === 'CollisionShape3D') {
      return true;
    }
  }
  let p = mi.parent;
  while (p) {
    if (p.type === 'CollisionObject3D' || p.type === 'StaticBody3D') {
      return true;
    }
    if (p.name === 'ModelPivot' || p.name.startsWith('CustomProp_')) break;
    p = p.parent;
  }
  if (mi.parent) {
    for (const sib of mi.parent.children) {
      if (sib === mi) continue;
      if (sib.type === 'CollisionShape3D' || sib.type === 'StaticBody3D') {
        const sName = sib.name.toLowerCase();
        const mName = mi.name.toLowerCase();
        if (sName.startsWith(mName) || sName.includes('col')) {
          return true;
        }
      }
    }
  }
  return false;
}

export function simulateDisableAllCollisions(root: MockHierarchyNode): void {
  if (root.collisionLayer !== undefined) {
    root.collisionLayer = 0;
  }
  if (root.collisionMask !== undefined) {
    root.collisionMask = 0;
  }
  for (const ch of root.children) {
    simulateDisableAllCollisions(ch);
  }
}
