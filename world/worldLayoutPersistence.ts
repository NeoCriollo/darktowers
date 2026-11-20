/**
 * Dark Towers: The Path of Ka
 * World Layout Persistence & JSON Overrides Domain (Phase 4)
 *
 * Schema definitions, coordinate bounds checking (2500m x 2500m),
 * catalog asset validation, and Node 0 Sanctuary Invariant clearance.
 */

import { CATALOG_ASSETS } from './editorMode.ts';

export interface TransformOverride {
  position: [number, number, number];
  rotation: [number, number, number];
  scale: [number, number, number];
}

export interface SpawnedPropOverride {
  instance_id: string;
  asset_id: string;
  position: [number, number, number];
  rotation: [number, number, number];
  scale: [number, number, number];
}

export interface WorldLayoutOverrideData {
  version: string;
  timestamp: string;
  modifications: Record<string, TransformOverride>;
  deletions: string[];
  spawned: SpawnedPropOverride[];
}

export const CURRENT_SCHEMA_VERSION = '1.0.0';
export const MAP_HALF_EXTENT = 1250.0; // 2500m x 2500m

// Node 0 Sanctuary Invariant Coordinates
export const NODE_0_BUNKER_SPAWN = { x: -1180.0, z: -1180.0 };
export const NODE_0_GATE_THRESHOLD = { x: -1060.0, z: -1060.0 };
export const SANCTUARY_SPAWN_CLEAR_RADIUS = 6.0;

export function createEmptyLayoutOverride(): WorldLayoutOverrideData {
  return {
    version: CURRENT_SCHEMA_VERSION,
    timestamp: new Date().toISOString(),
    modifications: {},
    deletions: [],
    spawned: []
  };
}

export function validateLayoutSchema(data: unknown): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!data || typeof data !== 'object') {
    return { valid: false, errors: ['Layout data must be a valid JSON object.'] };
  }

  const payload = data as Partial<WorldLayoutOverrideData>;

  if (typeof payload.version !== 'string' || payload.version !== CURRENT_SCHEMA_VERSION) {
    errors.push(`Invalid or missing schema version: ${String(payload.version)} (expected ${CURRENT_SCHEMA_VERSION})`);
  }

  if (typeof payload.modifications !== 'object' || payload.modifications === null) {
    errors.push('Missing or invalid modifications dictionary.');
  } else {
    for (const [id, mod] of Object.entries(payload.modifications)) {
      _validateTransform(`modifications[${id}]`, mod, errors);
    }
  }

  if (!Array.isArray(payload.deletions)) {
    errors.push('Missing or invalid deletions array.');
  }

  if (!Array.isArray(payload.spawned)) {
    errors.push('Missing or invalid spawned array.');
  } else {
    const validAssetIds = new Set(CATALOG_ASSETS.map((a) => a.id));
    for (let i = 0; i < payload.spawned.length; i++) {
      const item = payload.spawned[i];
      if (!item.instance_id || typeof item.instance_id !== 'string') {
        errors.push(`spawned[${i}]: Missing or invalid instance_id`);
      }
      const isCustomAsset = typeof item.asset_id === 'string' && (item.asset_id.startsWith('custom_') || Boolean(item.asset_path) || item.asset_id === 'prop');
      if (!item.asset_id || (!validAssetIds.has(item.asset_id) && !isCustomAsset)) {
        errors.push(`spawned[${i}]: Unknown catalog asset_id '${item.asset_id}'`);
      }
      _validateTransform(`spawned[${i}]`, item, errors);
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

function _validateTransform(context: string, tf: unknown, errors: string[]): void {
  if (!tf || typeof tf !== 'object') {
    errors.push(`${context}: Transform must be an object.`);
    return;
  }
  const t = tf as Partial<TransformOverride>;

  if (!Array.isArray(t.position) || t.position.length !== 3) {
    errors.push(`${context}: position must be a 3-element numeric array.`);
  } else {
    const [x, , z] = t.position;
    if (Math.abs(x) > MAP_HALF_EXTENT || Math.abs(z) > MAP_HALF_EXTENT) {
      errors.push(`${context}: position (${x}, ${z}) out of map bounds (+/-${MAP_HALF_EXTENT}m).`);
    }
  }

  if (!Array.isArray(t.rotation) || t.rotation.length !== 3) {
    errors.push(`${context}: rotation must be a 3-element numeric array.`);
  }

  if (!Array.isArray(t.scale) || t.scale.length !== 3) {
    errors.push(`${context}: scale must be a 3-element numeric array.`);
  } else {
    for (const s of t.scale) {
      if (typeof s !== 'number' || s <= 0.0) {
        errors.push(`${context}: scale components must be positive numbers.`);
        break;
      }
    }
  }
}

export function validateNode0SanctuaryClearance(
  data: WorldLayoutOverrideData
): { clear: boolean; violations: string[] } {
  const violations: string[] = [];

  const checkPosition = (label: string, pos: [number, number, number]) => {
    const [x, , z] = pos;
    // Check bunker spawn point clearance
    const distToBunker = Math.hypot(x - NODE_0_BUNKER_SPAWN.x, z - NODE_0_BUNKER_SPAWN.z);
    if (distToBunker < SANCTUARY_SPAWN_CLEAR_RADIUS) {
      violations.push(`${label} at (${x.toFixed(1)}, ${z.toFixed(1)}) violates Node 0 bunker spawn clearance (${distToBunker.toFixed(2)}m < ${SANCTUARY_SPAWN_CLEAR_RADIUS}m).`);
    }

    // Check corridor centerline clearance from bunker (-1180, -1180) to gate (-1060, -1060)
    const dx = NODE_0_GATE_THRESHOLD.x - NODE_0_BUNKER_SPAWN.x;
    const dz = NODE_0_GATE_THRESHOLD.z - NODE_0_BUNKER_SPAWN.z;
    const l2 = dx * dx + dz * dz;
    const t = Math.max(0.0, Math.min(1.0, ((x - NODE_0_BUNKER_SPAWN.x) * dx + (z - NODE_0_BUNKER_SPAWN.z) * dz) / l2));
    const distToCorridor = Math.hypot(x - (NODE_0_BUNKER_SPAWN.x + t * dx), z - (NODE_0_BUNKER_SPAWN.z + t * dz));
    if (distToCorridor < 4.0) {
      violations.push(`${label} at (${x.toFixed(1)}, ${z.toFixed(1)}) blocks Node 0 blast-gate corridor.`);
    }
  };

  for (const [id, mod] of Object.entries(data.modifications)) {
    if (mod.position) {
      checkPosition(`Modification '${id}'`, mod.position);
    }
  }

  for (const item of data.spawned) {
    if (item.position) {
      checkPosition(`Spawned '${item.instance_id}'`, item.position);
    }
  }

  return {
    clear: violations.length === 0,
    violations
  };
}

export function serializeLayoutOverrides(data: WorldLayoutOverrideData): string {
  return JSON.stringify(data, null, 2);
}

export function parseLayoutOverrides(jsonText: string): WorldLayoutOverrideData {
  const parsed = JSON.parse(jsonText);
  const validation = validateLayoutSchema(parsed);
  if (!validation.valid) {
    throw new Error(`Invalid layout overrides: ${validation.errors.join('; ')}`);
  }
  return parsed as WorldLayoutOverrideData;
}

// ─── Phase 6.5: Procedural Prop & Override Persistence Contracts ───────────

export interface ProceduralPropNode {
  name: string;
  prop_uuid: string;
  position: [number, number, number];
  rotation: [number, number, number];
  scale: [number, number, number];
  instance_id?: string;
  meta?: Record<string, unknown>;
}

export function generateEscarpmentRockId(seedVal: number): string {
  return `EscarpmentRock_${Math.floor(seedVal)}`;
}

export function generateEscarpmentCliffId(seedVal: number): string {
  return `EscarpmentCliff_${Math.floor(seedVal)}`;
}

export function generateSanctuaryOutcropShelfId(index1Based: number): string {
  return `Mohaine_OutcropShelf_${index1Based}`;
}

export function generateSanctuaryCalicheSlabId(index1Based: number): string {
  return `Mohaine_CalicheSlab_${index1Based}`;
}

export function generateSanctuaryCrouchBoulderId(index1Based: number): string {
  return `Mohaine_CrouchBoulder_${index1Based}`;
}

export function generateCastleStoneId(index1Based: number, assetName: string): string {
  return `Q01_MedievalRuin_${index1Based}_${assetName.replace(/\s+/g, '_')}`;
}

export function normalizeIdentifier(id: string): string {
  return id.replace(/[\s()]/g, '_').replace(/_+/g, '_');
}

export function recordProceduralModification(
  data: WorldLayoutOverrideData,
  prop: ProceduralPropNode,
  newTransform: TransformOverride
): WorldLayoutOverrideData {
  const stableId = prop.prop_uuid || prop.instance_id || prop.name;
  if (!stableId || stableId.startsWith('@')) {
    throw new Error(`Cannot record modification for prop with volatile runtime name: ${prop.name}`);
  }

  data.modifications[stableId] = {
    position: [...newTransform.position],
    rotation: [...newTransform.rotation],
    scale: [...newTransform.scale]
  };

  const delIdx = data.deletions.indexOf(stableId);
  if (delIdx >= 0) {
    data.deletions.splice(delIdx, 1);
  }

  return data;
}

export function applyLayoutOverridesToProceduralProps(
  props: ProceduralPropNode[],
  layout: WorldLayoutOverrideData
): { appliedCount: number; updatedProps: ProceduralPropNode[]; deletedIds: string[] } {
  const deletionSet = new Set(layout.deletions.map(normalizeIdentifier));
  const modEntries = Object.entries(layout.modifications);
  const normalizedMods = new Map<string, TransformOverride>();

  for (const [key, val] of modEntries) {
    normalizedMods.set(key, val);
    normalizedMods.set(normalizeIdentifier(key), val);
  }

  let appliedCount = 0;
  const updatedProps: ProceduralPropNode[] = [];
  const deletedIds: string[] = [];

  for (const prop of props) {
    const pUuid = prop.prop_uuid || '';
    const pInst = prop.instance_id || '';
    const pName = prop.name || '';

    const isDeleted =
      (pUuid && (deletionSet.has(pUuid) || deletionSet.has(normalizeIdentifier(pUuid)))) ||
      (pInst && (deletionSet.has(pInst) || deletionSet.has(normalizeIdentifier(pInst)))) ||
      (pName && (deletionSet.has(pName) || deletionSet.has(normalizeIdentifier(pName))));

    if (isDeleted) {
      deletedIds.push(pUuid || pInst || pName);
      continue;
    }

    const mod =
      normalizedMods.get(pUuid) ||
      normalizedMods.get(normalizeIdentifier(pUuid)) ||
      normalizedMods.get(pInst) ||
      normalizedMods.get(normalizeIdentifier(pInst)) ||
      normalizedMods.get(pName) ||
      normalizedMods.get(normalizeIdentifier(pName));

    if (mod) {
      appliedCount++;
      updatedProps.push({
        ...prop,
        position: [...mod.position],
        rotation: [...mod.rotation],
        scale: [...mod.scale]
      });
    } else {
      updatedProps.push({ ...prop });
    }
  }

  return { appliedCount, updatedProps, deletedIds };
}

export function reloadAndPreserveProceduralOverrides(
  freshProceduralProps: ProceduralPropNode[],
  layoutJson: string
): ProceduralPropNode[] {
  const layout = parseLayoutOverrides(layoutJson);
  const { updatedProps } = applyLayoutOverridesToProceduralProps(freshProceduralProps, layout);
  return updatedProps;
}

