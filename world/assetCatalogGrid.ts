/**
 * Dark Towers: The Path of Ka
 * Visual 3D Asset Catalog Grid Domain (Phase 7)
 *
 * Grid container layout mathematics, column sizing, responsive wrapping,
 * AABB camera framing, 3D continuous spin, thumbnail cache keys,
 * and fallback placeholder resolution.
 */

export interface CatalogGridCategory {
  readonly id: string;
  readonly name: string;
  readonly code: string;
  readonly badge: string;
}

export interface CatalogGridItem {
  readonly id: string;
  readonly category: string;
  readonly name: string;
  readonly glbName?: string;
  readonly assetPath?: string;
  readonly tierBadge?: string;
  readonly material?: string;
  readonly isCustom?: boolean;
}

export interface GridLayoutConfig {
  readonly containerWidth: number;
  readonly minCardWidth: number;
  readonly cardHeight: number;
  readonly hGap: number;
  readonly vGap: number;
}

export interface GridLayoutResult {
  readonly columns: number;
  readonly cardWidth: number;
  readonly cardHeight: number;
  readonly rows: number;
  readonly totalHeight: number;
}

export interface Vector3D {
  readonly x: number;
  readonly y: number;
  readonly z: number;
}

export interface AABB3D {
  readonly min: Vector3D;
  readonly max: Vector3D;
  readonly size: Vector3D;
  readonly center: Vector3D;
}

export interface CameraFramingResult {
  readonly distance: number;
  readonly cameraPosition: Vector3D;
  readonly lookTarget: Vector3D;
  readonly fovDegrees: number;
  readonly boundingRadius: number;
}

export interface ThumbnailPathResolution {
  readonly isValid: boolean;
  readonly resolvedPath: string;
  readonly isFallback: boolean;
  readonly fallbackType: 'mesh_box' | 'wireframe_cube' | 'empty_glyph';
}

// ─── Visual Theme Styling Constants ──────────────────────────────────────────

export const AMBER_TERMINAL_HEX = '#E1A647';
export const AMBER_TERMINAL_RGB = { r: 0.882, g: 0.651, b: 0.278 };
export const AMBER_DIM_HEX = '#8C6527';
export const OBSIDIAN_PANEL_HEX = '#0D0B0A';
export const OBSIDIAN_CARD_HEX = '#141210';

export const DEFAULT_CAMERA_FOV_DEGREES = 38.0;
export const DEFAULT_CAMERA_MARGIN = 1.25;
export const DEFAULT_SPIN_SPEED_RAD_PER_SEC = 0.8;

export const CANONICAL_GRID_CATEGORIES: readonly CatalogGridCategory[] = [
  { id: 'rocks', name: 'ROCAS FOTOGRAMÉTRICAS', code: 'ROCKS', badge: '7 ASSETS' },
  { id: 'architecture', name: 'ARQUITECTURA NCP', code: 'ARCH', badge: '4 ASSETS' },
  { id: 'props', name: 'PELIGROS Y PERTRECHOS', code: 'PROPS', badge: '4 ASSETS' },
  { id: 'custom', name: 'PROPIOS / CUSTOM 3D', code: 'CUSTOM', badge: 'CUSTOM GLB' }
];

// ─── Grid Layout Mathematics ────────────────────────────────────────────────

export function calculateGridColumns(
  containerWidth: number,
  minCardWidth: number,
  gap: number = 8.0
): number {
  if (containerWidth <= 0 || minCardWidth <= 0) {
    return 1;
  }
  const availableWidth = containerWidth + gap;
  const slotWidth = minCardWidth + gap;
  const calculated = Math.floor(availableWidth / slotWidth);
  return Math.max(1, calculated);
}

export function calculateCardWidth(
  containerWidth: number,
  columns: number,
  gap: number = 8.0
): number {
  const safeColumns = Math.max(1, columns);
  const totalGaps = (safeColumns - 1) * gap;
  const usableWidth = Math.max(0, containerWidth - totalGaps);
  return Math.floor(usableWidth / safeColumns);
}

export function calculateGridLayout(
  totalItems: number,
  config: GridLayoutConfig
): GridLayoutResult {
  const columns = calculateGridColumns(config.containerWidth, config.minCardWidth, config.hGap);
  const cardWidth = calculateCardWidth(config.containerWidth, columns, config.hGap);
  const rows = totalItems <= 0 ? 0 : Math.ceil(totalItems / columns);
  const gapHeight = rows > 1 ? (rows - 1) * config.vGap : 0;
  const totalHeight = rows * config.cardHeight + gapHeight;

  return {
    columns,
    cardWidth,
    cardHeight: config.cardHeight,
    rows,
    totalHeight
  };
}

// ─── Category Filtering & Item Counts ───────────────────────────────────────

export function filterCatalogItems(
  items: readonly CatalogGridItem[],
  categoryId: string | 'all',
  searchQuery: string = ''
): CatalogGridItem[] {
  const normalizedQuery = searchQuery.trim().toLowerCase();

  return items.filter((item) => {
    const matchesCategory =
      categoryId === 'all' || item.category === categoryId;

    if (!matchesCategory) {
      return false;
    }

    if (normalizedQuery.length === 0) {
      return true;
    }

    const nameMatch = item.name.toLowerCase().includes(normalizedQuery);
    const idMatch = item.id.toLowerCase().includes(normalizedQuery);
    const glbMatch = item.glbName?.toLowerCase().includes(normalizedQuery) ?? false;
    const matMatch = item.material?.toLowerCase().includes(normalizedQuery) ?? false;

    return nameMatch || idMatch || glbMatch || matMatch;
  });
}

export function computeCategoryCounts(
  items: readonly CatalogGridItem[]
): Record<string, number> {
  const counts: Record<string, number> = {};

  for (const cat of CANONICAL_GRID_CATEGORIES) {
    counts[cat.id] = 0;
  }

  for (const item of items) {
    if (counts[item.category] !== undefined) {
      counts[item.category] += 1;
    } else {
      counts[item.category] = 1;
    }
  }

  return counts;
}

// ─── 3D AABB & Camera Framing Mathematics ───────────────────────────────────

export function computeAABBFromExtents(min: Vector3D, max: Vector3D): AABB3D {
  const size: Vector3D = {
    x: Math.max(0.001, max.x - min.x),
    y: Math.max(0.001, max.y - min.y),
    z: Math.max(0.001, max.z - min.z)
  };
  const center: Vector3D = {
    x: (min.x + max.x) * 0.5,
    y: (min.y + max.y) * 0.5,
    z: (min.z + max.z) * 0.5
  };
  return { min, max, size, center };
}

export function computeBoundingRadius(size: Vector3D): number {
  return 0.5 * Math.sqrt(size.x * size.x + size.y * size.y + size.z * size.z);
}

export function computeThumbnailCameraFraming(
  size: Vector3D,
  center: Vector3D = { x: 0, y: 0, z: 0 },
  fovDegrees: number = DEFAULT_CAMERA_FOV_DEGREES,
  margin: number = DEFAULT_CAMERA_MARGIN
): CameraFramingResult {
  const boundingRadius = computeBoundingRadius(size);
  const halfFovRad = ((fovDegrees * 0.5) * Math.PI) / 180.0;
  const sinHalfFov = Math.max(0.01, Math.sin(halfFovRad));
  const rawDistance = (boundingRadius / sinHalfFov) * margin;
  const distance = Math.max(0.5, rawDistance);

  // Position camera at a standardized isometric angle looking at center
  const offsetDir = { x: 0.65, y: 0.45, z: 0.85 };
  const len = Math.sqrt(
    offsetDir.x * offsetDir.x + offsetDir.y * offsetDir.y + offsetDir.z * offsetDir.z
  );
  const normOffset = {
    x: (offsetDir.x / len) * distance,
    y: (offsetDir.y / len) * distance,
    z: (offsetDir.z / len) * distance
  };

  const cameraPosition: Vector3D = {
    x: center.x + normOffset.x,
    y: center.y + normOffset.y,
    z: center.z + normOffset.z
  };

  return {
    distance,
    cameraPosition,
    lookTarget: { ...center },
    fovDegrees,
    boundingRadius
  };
}

export function computeSpinRotation(
  currentYaw: number,
  deltaSeconds: number,
  speedRadPerSec: number = DEFAULT_SPIN_SPEED_RAD_PER_SEC
): number {
  const nextYaw = currentYaw + speedRadPerSec * deltaSeconds;
  const tau = 2.0 * Math.PI;
  return ((nextYaw % tau) + tau) % tau;
}

// ─── Thumbnail Cache Keys & Fallback Resolver ───────────────────────────────

export function generateThumbnailCacheKey(
  assetId: string,
  resolution: number = 128
): string {
  const sanitizedId = assetId.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '_');
  return `thumb_${sanitizedId}_${resolution}`;
}

export function isValidThumbnailCacheKey(key: string): boolean {
  return /^thumb_[a-z0-9_-]+_\d+$/.test(key);
}

export function resolveThumbnailAssetPath(
  assetPath?: string | null
): ThumbnailPathResolution {
  if (!assetPath || typeof assetPath !== 'string') {
    return {
      isValid: false,
      resolvedPath: 'fallback://primitive_box',
      isFallback: true,
      fallbackType: 'mesh_box'
    };
  }

  const trimmed = assetPath.trim();
  if (trimmed.length === 0) {
    return {
      isValid: false,
      resolvedPath: 'fallback://primitive_box',
      isFallback: true,
      fallbackType: 'mesh_box'
    };
  }

  const lower = trimmed.toLowerCase();
  const hasValid3dExt = lower.endsWith('.glb') || lower.endsWith('.gltf');

  if (!hasValid3dExt && !trimmed.startsWith('res://') && !trimmed.startsWith('procedural_')) {
    return {
      isValid: false,
      resolvedPath: 'fallback://primitive_box',
      isFallback: true,
      fallbackType: 'wireframe_cube'
    };
  }

  return {
    isValid: true,
    resolvedPath: trimmed,
    isFallback: false,
    fallbackType: 'mesh_box'
  };
}

export class ThumbnailMemoryCache<T> {
  private readonly _map = new Map<string, T>();
  private readonly _maxEntries: number;

  constructor(maxEntries: number = 64) {
    this._maxEntries = Math.max(1, maxEntries);
  }

  public get(key: string): T | undefined {
    return this._map.get(key);
  }

  public set(key: string, value: T): void {
    if (this._map.size >= this._maxEntries && !this._map.has(key)) {
      const oldestKey = this._map.keys().next().value;
      if (oldestKey !== undefined) {
        this._map.delete(oldestKey);
      }
    }
    this._map.set(key, value);
  }

  public has(key: string): boolean {
    return this._map.has(key);
  }

  public clear(): void {
    this._map.clear();
  }

  public size(): number {
    return this._map.size;
  }
}
