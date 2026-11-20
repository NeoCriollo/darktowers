/**
 * Dark Towers: The Path of Ka
 * In-Game World Editor Mode & Halo-Forge Manipulator (Phases 1 & 2)
 *
 * Core architecture constants, speed multipliers, 6DoF flight math,
 * 8-sector wasteland teleportation coordinates, surface clamping,
 * yaw snap rotation, and distance tether calculations.
 */

export interface EditorFlightConfig {
  readonly normalSpeed: number;
  readonly fastSpeed: number;
  readonly crawlSpeed: number;
  readonly minSpeedMultiplier: number;
  readonly maxSpeedMultiplier: number;
  readonly mouseSensitivity: number;
  readonly acceleration: number;
}

export interface SectorHub {
  readonly id: number;
  readonly key: string;
  readonly name: string;
  readonly worldX: number;
  readonly worldZ: number;
  readonly sectorTag: string;
}

export const DEFAULT_EDITOR_CONFIG: Readonly<EditorFlightConfig> = {
  normalSpeed: 25.0,
  fastSpeed: 120.0,
  crawlSpeed: 6.0,
  minSpeedMultiplier: 0.2,
  maxSpeedMultiplier: 5.0,
  mouseSensitivity: 0.002,
  acceleration: 14.0
};

export const MANIPULATOR_CONSTANTS = {
  MIN_TETHER_DIST: 3.0,
  MAX_TETHER_DIST: 250.0,
  MIN_SCALE: 0.1,
  MAX_SCALE: 30.0,
  YAW_SNAP_RAD: (15.0 * Math.PI) / 180.0
} as const;

export const EDITOR_SECTOR_HUBS: readonly SectorHub[] = [
  { id: 1, key: 'KEY_1', name: 'The Mohaine Way-Bunker', worldX: -1180.0, worldZ: -1180.0, sectorTag: 'waystation_sanctuary' },
  { id: 2, key: 'KEY_2', name: 'Southwest Desolation', worldX: -550.0, worldZ: -900.0, sectorTag: 'sw_desolation' },
  { id: 3, key: 'KEY_3', name: 'Dead-Creek Salt Flats', worldX: -150.0, worldZ: -550.0, sectorTag: 'south_salt' },
  { id: 4, key: 'KEY_4', name: 'Caliche Cradle Nexus', worldX: 0.0, worldZ: 0.0, sectorTag: 'cradle' },
  { id: 5, key: 'KEY_5', name: 'Rust-Gorge Defile', worldX: -650.0, worldZ: 50.0, sectorTag: 'west_gorge' },
  { id: 6, key: 'KEY_6', name: 'Bleached Alkali Sink', worldX: 0.0, worldZ: 650.0, sectorTag: 'north_alkali' },
  { id: 7, key: 'KEY_7', name: 'The Great Shifting Erg', worldX: 650.0, worldZ: 50.0, sectorTag: 'east_dunes' },
  { id: 8, key: 'KEY_8', name: 'Threshold of the Dark Tower', worldX: 650.0, worldZ: 650.0, sectorTag: 'monolith_pass' }
];

export class EditorSessionState {
  public isEditorActive: boolean = false;
  public isFlightActive: boolean = false;
  public speedMultiplier: number = 1.0;
  public position: { x: number; y: number; z: number } = { x: -1180.0, y: 0.0, z: -1180.0 };
  public rotation: { yaw: number; pitch: number } = { yaw: 0.0, pitch: 0.0 };

  constructor(startActive: boolean = false) {
    this.isEditorActive = startActive;
    this.isFlightActive = startActive;
  }

  public toggleFlight(): boolean {
    this.isFlightActive = !this.isFlightActive;
    return this.isFlightActive;
  }

  public setFlightMode(active: boolean): void {
    this.isFlightActive = active;
  }

  public adjustSpeed(wheelUp: boolean): number {
    const factor = wheelUp ? 1.15 : 1.0 / 1.15;
    this.speedMultiplier = Math.max(
      DEFAULT_EDITOR_CONFIG.minSpeedMultiplier,
      Math.min(DEFAULT_EDITOR_CONFIG.maxSpeedMultiplier, this.speedMultiplier * factor)
    );
    return this.speedMultiplier;
  }

  public computeCurrentSpeed(isFastModifier: boolean, isCrawlModifier: boolean): number {
    let base = DEFAULT_EDITOR_CONFIG.normalSpeed;
    if (isFastModifier) {
      base = DEFAULT_EDITOR_CONFIG.fastSpeed;
    } else if (isCrawlModifier) {
      base = DEFAULT_EDITOR_CONFIG.crawlSpeed;
    }
    return base * this.speedMultiplier;
  }

  public teleportToHub(hubNumber: number): SectorHub | null {
    const hub = EDITOR_SECTOR_HUBS.find(h => h.id === hubNumber);
    if (!hub) return null;
    this.position.x = hub.worldX;
    this.position.z = hub.worldZ;
    return hub;
  }

  public snapToGround(groundY: number, eyeHeight: number = 1.8): void {
    this.position.y = groundY + eyeHeight;
  }

  public updateLookAngles(deltaX: number, deltaY: number): void {
    this.rotation.yaw -= deltaX * DEFAULT_EDITOR_CONFIG.mouseSensitivity;
    this.rotation.pitch -= deltaY * DEFAULT_EDITOR_CONFIG.mouseSensitivity;
    const maxPitch = (88.0 * Math.PI) / 180.0;
    this.rotation.pitch = Math.max(-maxPitch, Math.min(maxPitch, this.rotation.pitch));
  }
}

// ─── Phase 2: Grab & Carry Math Helpers ─────────────────────────────────────

export function computeClampedSurfaceY(
  groundY: number,
  sinkDepth: number,
  heightOffset: number,
  isAltFreeY: boolean,
  rayTargetY: number
): number {
  if (isAltFreeY) {
    return rayTargetY + heightOffset;
  }
  return groundY - sinkDepth + heightOffset;
}

export function snapRotateYaw(
  currentYawRad: number,
  isClockwise: boolean,
  snapRad: number = MANIPULATOR_CONSTANTS.YAW_SNAP_RAD
): number {
  const step = isClockwise ? snapRad : -snapRad;
  const newAngle = currentYawRad + step;
  // Normalize to [-PI, PI]
  return Math.atan2(Math.sin(newAngle), Math.cos(newAngle));
}

export function applyUniformScale(
  currentScale: { x: number; y: number; z: number },
  factor: number,
  minScale: number = MANIPULATOR_CONSTANTS.MIN_SCALE,
  maxScale: number = MANIPULATOR_CONSTANTS.MAX_SCALE
): { x: number; y: number; z: number } {
  const newX = currentScale.x * factor;
  const newY = currentScale.y * factor;
  const newZ = currentScale.z * factor;
  const maxComp = Math.max(newX, Math.max(newY, newZ));
  const minComp = Math.min(newX, Math.min(newY, newZ));

  if (maxComp <= maxScale && minComp >= minScale) {
    return { x: newX, y: newY, z: newZ };
  }
  return { ...currentScale };
}

export function adjustTetherDistance(
  currentDist: number,
  delta: number,
  minDist: number = MANIPULATOR_CONSTANTS.MIN_TETHER_DIST,
  maxDist: number = MANIPULATOR_CONSTANTS.MAX_TETHER_DIST
): number {
  return Math.max(minDist, Math.min(maxDist, currentDist + delta));
}

export function isNodeSelectable(nodeName: string, isTerrainCollider: boolean): boolean {
  if (isTerrainCollider) return false;
  const lower = nodeName.toLowerCase();
  if (lower.includes('terrain') || lower.includes('ground') || lower.includes('desertground')) {
    return false;
  }
  return true;
}

export function computeFlightDisplacement(
  direction: { x: number; y: number; z: number },
  speed: number,
  delta: number
): { x: number; y: number; z: number } {
  const lenSq = direction.x * direction.x + direction.y * direction.y + direction.z * direction.z;
  if (lenSq < 0.00001) {
    return { x: 0, y: 0, z: 0 };
  }
  const invLen = 1.0 / Math.sqrt(lenSq);
  const factor = speed * delta;
  return {
    x: direction.x * invLen * factor,
    y: direction.y * invLen * factor,
    z: direction.z * invLen * factor
  };
}

export function formatEditorTelemetry(
  speed: number,
  multiplier: number,
  position: { x: number; y: number; z: number }
): string {
  return `[ MODO ARQUITECTO · TODASH FLIGHT ]  VEL: ${speed.toFixed(1)} m/s (${multiplier.toFixed(1)}x)  |  POS: (${position.x.toFixed(1)}, ${position.y.toFixed(1)}, ${position.z.toFixed(1)})  |  [TAB] CATÁLOGO  [V] PIE  [1-8] SECTORES`;
}

export function formatGrabbedTelemetry(
  nodeName: string,
  position: { x: number; y: number; z: number },
  scale: { x: number; y: number; z: number }
): string {
  return `[ AGARRADO: ${nodeName} ]  POS: (${position.x.toFixed(1)}, ${position.y.toFixed(1)}, ${position.z.toFixed(1)})  SCALE: (${scale.x.toFixed(2)}, ${scale.y.toFixed(2)}, ${scale.z.toFixed(2)})  |  [↑/↓] ELEVAR  [←/→] ROTAR  [Q/E] ROTAR  [SHIFT+RUEDA] ESCALA  [CTRL+D] CLONAR  [X] BORRAR`;
}

export function adjustElevationOffset(
  currentOffset: number,
  delta: number
): number {
  return currentOffset + delta;
}

export function formatHoveredTelemetry(
  nodeName: string,
  position: { x: number; y: number; z: number },
  scale: { x: number; y: number; z: number }
): string {
  return `[ APUNTANDO: ${nodeName} ]  POS: (${position.x.toFixed(1)}, ${position.y.toFixed(1)}, ${position.z.toFixed(1)})  SCALE: (${scale.x.toFixed(2)}, ${scale.y.toFixed(2)}, ${scale.z.toFixed(2)})  |  [CLICK IZQ] AGARRAR  [X / SUPR] BORRAR`;
}

export function validateHubBoundaries(hub: SectorHub): boolean {
  const mapBound = 1250.0;
  return (
    Math.abs(hub.worldX) <= mapBound &&
    Math.abs(hub.worldZ) <= mapBound &&
    hub.id >= 1 &&
    hub.id <= 8
  );
}

export function resolveLookVector(
  yaw: number,
  pitch: number
): { x: number; y: number; z: number } {
  const cosPitch = Math.cos(pitch);
  return {
    x: -Math.sin(yaw) * cosPitch,
    y: Math.sin(pitch),
    z: -Math.cos(yaw) * cosPitch
  };
}

// ---------------------------------------------------------------------
// Phase 3: Asset Palette Spawner Domain & Catalog Contracts
// ---------------------------------------------------------------------

export interface CatalogCategory {
  readonly id: string;
  readonly name: string;
  readonly code: string;
  readonly badge: string;
}

export interface CatalogAsset {
  readonly id: string;
  readonly category: string;
  readonly name: string;
  readonly glbName: string;
  readonly tierBadge: string;
  readonly defaultScale: { x: number; y: number; z: number };
  readonly defaultSink: number;
  readonly material: string;
}

export const PALETTE_CATEGORIES: readonly CatalogCategory[] = [
  { id: 'rocks', name: 'ROCAS FOTOGRAMÉTRICAS', code: 'ROCKS', badge: '7 ASSETS' },
  { id: 'architecture', name: 'ARQUITECTURA NCP', code: 'ARCH', badge: '4 ASSETS' },
  { id: 'props', name: 'PELIGROS Y PERTRECHOS', code: 'PROPS', badge: '4 ASSETS' }
];

export const CATALOG_ASSETS: readonly CatalogAsset[] = [
  { id: 'rock_3', category: 'rocks', name: 'Rock3 (5K) — Tier A Scatter', glbName: 'Rock3 (5K)', tierBadge: '[TIER A - 5K]', defaultScale: { x: 2.5, y: 2.5, z: 2.5 }, defaultSink: 0.35, material: 'STONE' },
  { id: 'rock_5b', category: 'rocks', name: 'Rock5b (11K) — Caliche Ground Slab', glbName: 'Rock5b (11K)', tierBadge: '[TIER A - 11K]', defaultScale: { x: 3.5, y: 1.8, z: 3.5 }, defaultSink: 0.45, material: 'STONE' },
  { id: 'rock_5c', category: 'rocks', name: 'Rock5c (23K) — Vertical Crag', glbName: 'Rock5c (23K)', tierBadge: '[TIER B - 23K]', defaultScale: { x: 4.0, y: 6.0, z: 4.0 }, defaultSink: 0.60, material: 'STONE' },
  { id: 'rock_1', category: 'rocks', name: 'Rock1 (38K) — Outcrop Shelf', glbName: 'Rock1 (38K)', tierBadge: '[TIER B - 38K]', defaultScale: { x: 5.0, y: 3.5, z: 5.0 }, defaultSink: 0.50, material: 'STONE' },
  { id: 'rock_5a', category: 'rocks', name: 'Rock5a (37K) — Escarpment Face', glbName: 'Rock5a (37K)', tierBadge: '[TIER B - 37K]', defaultScale: { x: 6.0, y: 9.0, z: 5.0 }, defaultSink: 0.80, material: 'STONE' },
  { id: 'rock_2', category: 'rocks', name: 'Rock2 (41K) — Talus Monolith', glbName: 'Rock2 (41K)', tierBadge: '[HERO - 41K]', defaultScale: { x: 7.0, y: 7.0, z: 7.0 }, defaultSink: 1.00, material: 'STONE' },
  { id: 'rock_4', category: 'rocks', name: 'Rock4 (60K) — Horizon Spire', glbName: 'Rock4 (60K)', tierBadge: '[HERO - 60K]', defaultScale: { x: 10.0, y: 16.0, z: 10.0 }, defaultSink: 1.50, material: 'STONE' },
  { id: 'monolith_pylon', category: 'architecture', name: 'Ka Survey Beacon Pylon', glbName: 'dark_tower_beacon_monolith_pylon.glb', tierBadge: '[NCP BEACON]', defaultScale: { x: 1.0, y: 1.0, z: 1.0 }, defaultSink: 0.50, material: 'STEEL' },
  { id: 'bunker_slab', category: 'architecture', name: 'Way-Bunker Blast Foundation', glbName: 'procedural_bunker_slab', tierBadge: '[CONCRETE]', defaultScale: { x: 1.0, y: 1.0, z: 1.0 }, defaultSink: 0.20, material: 'STONE' },
  { id: 'highway_pillar', category: 'architecture', name: 'Overpass Support Pillar', glbName: 'procedural_highway_pillar', tierBadge: '[OLD-ONES INFRA]', defaultScale: { x: 1.0, y: 1.0, z: 1.0 }, defaultSink: 0.80, material: 'STONE' },
  { id: 'midworld_door', category: 'architecture', name: 'Freestanding Mid-World Door', glbName: 'midworld_doorway', tierBadge: '[TODASH GATE]', defaultScale: { x: 1.0, y: 1.0, z: 1.0 }, defaultSink: 0.00, material: 'WOOD' },
  { id: 'supply_crate', category: 'props', name: 'Frontier Footlocker Crate', glbName: 'supply_crate', tierBadge: '[LOOT CACHE]', defaultScale: { x: 1.0, y: 1.0, z: 1.0 }, defaultSink: 0.00, material: 'STEEL' },
  { id: 'thinny_anomaly', category: 'props', name: 'Thinny Spatial Anomaly Tear', glbName: 'thinny_zone', tierBadge: '[HAZARD FX]', defaultScale: { x: 1.0, y: 1.0, z: 1.0 }, defaultSink: 0.00, material: 'ENERGY' },
  { id: 'telegraph_pole', category: 'props', name: 'Dead-Creek Telegraph Pole', glbName: 'procedural_telegraph_pole', tierBadge: '[FRONTIER WIRE]', defaultScale: { x: 1.0, y: 1.0, z: 1.0 }, defaultSink: 0.50, material: 'WOOD' },
  { id: 'skeleton_debris', category: 'props', name: 'Sun-Bleached Skeleton & Wreck', glbName: 'procedural_skeleton_debris', tierBadge: '[SCATTER]', defaultScale: { x: 1.0, y: 1.0, z: 1.0 }, defaultSink: 0.10, material: 'BONE' }
];

export function getCatalogCategories(): readonly CatalogCategory[] {
  return PALETTE_CATEGORIES;
}

export function getAssetsByCategory(categoryId: string): readonly CatalogAsset[] {
  return CATALOG_ASSETS.filter((a) => a.category === categoryId);
}

export function getAssetById(assetId: string): CatalogAsset | undefined {
  return CATALOG_ASSETS.find((a) => a.id === assetId);
}

export function cyclePaletteCategory(
  currentIdx: number,
  direction: number,
  totalCategories: number = PALETTE_CATEGORIES.length
): number {
  if (totalCategories <= 0) return 0;
  let next = (currentIdx + direction) % totalCategories;
  if (next < 0) next += totalCategories;
  return next;
}

export function computeSpawnPlacement(
  cameraPos: { x: number; y: number; z: number },
  forwardVec: { x: number; y: number; z: number },
  spawnDistance: number,
  sampleGroundHeight: (x: number, z: number) => number,
  defaultSink: number = 0.0
): { x: number; y: number; z: number } {
  const targetX = cameraPos.x + forwardVec.x * spawnDistance;
  const targetZ = cameraPos.z + forwardVec.z * spawnDistance;
  const groundY = sampleGroundHeight(targetX, targetZ);
  return {
    x: targetX,
    y: groundY - defaultSink,
    z: targetZ
  };
}

// ─── Multi-Selection & Grab State Contracts ─────────────────────────────────

export function toggleSelection(
  currentSelection: readonly string[],
  targetId: string,
  isMultiSelect: boolean
): string[] {
  if (!isMultiSelect) {
    return [targetId];
  }
  if (currentSelection.includes(targetId)) {
    return currentSelection.filter((id) => id !== targetId);
  }
  return [...currentSelection, targetId];
}

export function duplicateSelectedNodes<T extends { id: string; position: { x: number; y: number; z: number } }>(
  items: readonly T[]
): T[] {
  return items.map((item) => ({
    ...item,
    id: `${item.id}_Copy`,
    position: { ...item.position }
  }));
}

