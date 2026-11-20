/**
 * Dark Towers: The Path of Ka
 * Dual-Mode Object Outliner & Hierarchy Browser Domain (Phase 6)
 *
 * Sector zone bucketing, search filtering, focus camera math,
 * and outliner selection/modification state synchronization.
 */

export interface OutlinerSector {
  readonly id: string;
  readonly nodeIndex: number;
  readonly name: string;
  readonly hubX: number;
  readonly hubZ: number;
}

export interface OutlinerProp {
  readonly instanceId: string;
  readonly assetName: string;
  position: { x: number; y: number; z: number };
  rotation?: { x: number; y: number; z: number };
  scale?: { x: number; y: number; z: number };
  isCustom?: boolean;
  isModified?: boolean;
}

export const OUTLINER_SECTORS: readonly OutlinerSector[] = [
  { id: 'node_0', nodeIndex: 0, name: 'Node 0: Mohaine Way-Bunker', hubX: -1180.0, hubZ: -1180.0 },
  { id: 'node_1', nodeIndex: 1, name: 'Node 1: Southwest Desolation', hubX: -550.0, hubZ: -900.0 },
  { id: 'node_2', nodeIndex: 2, name: 'Node 2: Dead-Creek Salt Flats', hubX: -150.0, hubZ: -550.0 },
  { id: 'node_3', nodeIndex: 3, name: 'Node 3: Caliche Cradle Nexus', hubX: 0.0, hubZ: 0.0 },
  { id: 'node_4', nodeIndex: 4, name: 'Node 4: Rust-Gorge Defile', hubX: -650.0, hubZ: 50.0 },
  { id: 'node_5', nodeIndex: 5, name: 'Node 5: Bleached Alkali Sink', hubX: 0.0, hubZ: 650.0 },
  { id: 'node_6', nodeIndex: 6, name: 'Node 6: The Great Shifting Erg', hubX: 650.0, hubZ: 50.0 },
  { id: 'node_7', nodeIndex: 7, name: 'Node 7: Dark Tower Threshold', hubX: 650.0, hubZ: 650.0 }
];

export const CUSTOM_SPAWNS_SECTOR_ID = 'custom_spawns';
export const CUSTOM_SPAWNS_SECTOR_NAME = 'Custom Spawns / Overrides';

export function findNearestSectorZone(x: number, z: number): OutlinerSector {
  let closestSector = OUTLINER_SECTORS[0];
  let minDistanceSq = Number.POSITIVE_INFINITY;

  for (const sector of OUTLINER_SECTORS) {
    const dx = x - sector.hubX;
    const dz = z - sector.hubZ;
    const distSq = dx * dx + dz * dz;
    if (distSq < minDistanceSq) {
      minDistanceSq = distSq;
      closestSector = sector;
    }
  }

  return closestSector;
}

export function resolvePropSectorId(prop: OutlinerProp): string {
  if (prop.isCustom) {
    return CUSTOM_SPAWNS_SECTOR_ID;
  }
  return findNearestSectorZone(prop.position.x, prop.position.z).id;
}

export function bucketPropsBySector(props: OutlinerProp[]): Record<string, OutlinerProp[]> {
  const buckets: Record<string, OutlinerProp[]> = {};

  // Initialize all sector buckets deterministically
  for (const sector of OUTLINER_SECTORS) {
    buckets[sector.id] = [];
  }
  buckets[CUSTOM_SPAWNS_SECTOR_ID] = [];

  for (const prop of props) {
    const sectorId = resolvePropSectorId(prop);
    if (!buckets[sectorId]) {
      buckets[sectorId] = [];
    }
    buckets[sectorId].push(prop);
  }

  return buckets;
}

export function filterOutlinerProps(props: OutlinerProp[], query: string): OutlinerProp[] {
  const trimmed = query.trim().toLowerCase();
  if (trimmed.length === 0) {
    return [...props];
  }

  return props.filter((prop) => {
    const idMatch = prop.instanceId.toLowerCase().includes(trimmed);
    const nameMatch = prop.assetName.toLowerCase().includes(trimmed);
    return idMatch || nameMatch;
  });
}

export function filterGroupedProps(
  grouped: Record<string, OutlinerProp[]>,
  query: string
): Record<string, OutlinerProp[]> {
  const trimmed = query.trim().toLowerCase();
  const result: Record<string, OutlinerProp[]> = {};

  for (const [sectorId, items] of Object.entries(grouped)) {
    if (trimmed.length === 0) {
      result[sectorId] = [...items];
    } else {
      const filtered = filterOutlinerProps(items, trimmed);
      if (filtered.length > 0) {
        result[sectorId] = filtered;
      }
    }
  }

  return result;
}

export function calculateFocusCameraPosition(
  propPos: { x: number; y: number; z: number },
  elevationOffset: number = 4.0,
  distanceOffset: number = 10.0
): { x: number; y: number; z: number } {
  return {
    x: propPos.x,
    y: propPos.y + elevationOffset,
    z: propPos.z + distanceOffset
  };
}

export class EditorOutlinerState {
  private _props: Map<string, OutlinerProp> = new Map();
  private _selectedIds: Set<string> = new Set();
  private _primarySelectedId: string | null = null;
  private _modifiedIds: Set<string> = new Set();
  private _searchQuery: string = '';
  private _isPanelOpen: boolean = false;

  public isPanelOpen(): boolean {
    return this._isPanelOpen;
  }

  public setPanelOpen(open: boolean): void {
    this._isPanelOpen = open;
  }

  public togglePanel(): boolean {
    this._isPanelOpen = !this._isPanelOpen;
    return this._isPanelOpen;
  }

  public getSearchQuery(): string {
    return this._searchQuery;
  }

  public setSearchQuery(query: string): void {
    this._searchQuery = query;
  }

  public registerProp(prop: OutlinerProp): void {
    this._props.set(prop.instanceId, { ...prop });
  }

  public registerProps(props: OutlinerProp[]): void {
    for (const p of props) {
      this.registerProp(p);
    }
  }

  public unregisterProp(instanceId: string): void {
    this._props.delete(instanceId);
    this._selectedIds.delete(instanceId);
    this._modifiedIds.delete(instanceId);
    if (this._primarySelectedId === instanceId) {
      this._primarySelectedId = this._selectedIds.values().next().value ?? null;
    }
  }

  public getProp(instanceId: string): OutlinerProp | null {
    return this._props.get(instanceId) ?? null;
  }

  public getAllProps(): OutlinerProp[] {
    return Array.from(this._props.values());
  }

  public selectProp(instanceId: string | null, multi: boolean = false): OutlinerProp | null {
    if (!instanceId || !this._props.has(instanceId)) {
      if (!multi) {
        this.clearSelection();
      }
      return null;
    }

    if (!multi) {
      this._selectedIds.clear();
      this._selectedIds.add(instanceId);
      this._primarySelectedId = instanceId;
    } else {
      if (this._selectedIds.has(instanceId)) {
        this._selectedIds.delete(instanceId);
        this._primarySelectedId = this._selectedIds.values().next().value ?? null;
      } else {
        this._selectedIds.add(instanceId);
        this._primarySelectedId = instanceId;
      }
    }

    return this._primarySelectedId ? this._props.get(this._primarySelectedId) ?? null : null;
  }

  public clearSelection(): void {
    this._selectedIds.clear();
    this._primarySelectedId = null;
  }

  public getSelectedIds(): string[] {
    return Array.from(this._selectedIds);
  }

  public getPrimarySelectedProp(): OutlinerProp | null {
    if (!this._primarySelectedId) {
      return null;
    }
    return this._props.get(this._primarySelectedId) ?? null;
  }

  public isPropSelected(instanceId: string): boolean {
    return this._selectedIds.has(instanceId);
  }

  public markModified(instanceId: string): void {
    if (this._props.has(instanceId)) {
      this._modifiedIds.add(instanceId);
      const prop = this._props.get(instanceId)!;
      prop.isModified = true;
    }
  }

  public clearModified(instanceId?: string): void {
    if (instanceId) {
      this._modifiedIds.delete(instanceId);
      const prop = this._props.get(instanceId);
      if (prop) {
        prop.isModified = false;
      }
    } else {
      this._modifiedIds.clear();
      for (const prop of this._props.values()) {
        prop.isModified = false;
      }
    }
  }

  public isModified(instanceId: string): boolean {
    return this._modifiedIds.has(instanceId);
  }

  public getUnsavedCount(): number {
    return this._modifiedIds.size;
  }

  public getBucketedProps(): Record<string, OutlinerProp[]> {
    const all = this.getAllProps();
    const filtered = filterOutlinerProps(all, this._searchQuery);
    return bucketPropsBySector(filtered);
  }
}

