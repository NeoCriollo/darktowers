/**
 * Persistent World State & Spatial Zone Manager
 * Tracks persistent items, spent cartridge casings, blood stains, and camp embers across chunks.
 */

import type { WorldZoneChunk, GroundItemInstance } from './types.ts';
import type { Item } from '../inventory/types.ts';
import { type Vector3, vec3 } from '../core/types.ts';

export class WorldStateManager {
  private chunks: Map<string, WorldZoneChunk> = new Map();
  private readonly CHUNK_SIZE_METERS = 64.0;

  constructor() {
    // Scaffold initial starting chunk at (0, 0): Waystation Outpost
    this.getOrCreateChunk(0, 0, 'WAYSTATION_OUTPOST');
  }

  public getChunkKey(chunkX: number, chunkZ: number): string {
    return `${chunkX}:${chunkZ}`;
  }

  public getChunkForWorldPos(x: number, z: number): WorldZoneChunk {
    const chunkX = Math.floor(x / this.CHUNK_SIZE_METERS);
    const chunkZ = Math.floor(z / this.CHUNK_SIZE_METERS);
    return this.getOrCreateChunk(chunkX, chunkZ);
  }

  public getOrCreateChunk(
    chunkX: number,
    chunkZ: number,
    defaultBiome: WorldZoneChunk['biome'] = 'DESERT_DUNES'
  ): WorldZoneChunk {
    const key = this.getChunkKey(chunkX, chunkZ);
    if (!this.chunks.has(key)) {
      this.chunks.set(key, {
        chunkX,
        chunkZ,
        biome: defaultBiome,
        groundItems: [],
        spentBrassCount: 0,
        campfireLit: false,
        campfireEmberRemaining: 0.0,
      });
    }
    return this.chunks.get(key)!;
  }

  /**
   * Drops an item into the persistent world at world coordinate (x, y, z).
   */
  public dropItemOnGround(item: Item, position: Vector3): GroundItemInstance {
    const chunk = this.getChunkForWorldPos(position.x, position.z);
    const groundInstance: GroundItemInstance = {
      id: `ground_${item.id}_${Date.now()}`,
      item,
      worldPosition: { ...position },
      droppedTimestamp: Date.now(),
      weatherExposureGrit: 0.0,
    };

    chunk.groundItems.push(groundInstance);
    return groundInstance;
  }

  /**
   * Records a spent brass casing hitting the dirt upon weapon cycling.
   */
  public recordSpentBrass(position: Vector3): void {
    const chunk = this.getChunkForWorldPos(position.x, position.z);
    chunk.spentBrassCount++;
  }

  /**
   * Serializes world state to deterministic JSON snapshot.
   */
  public serialize(): string {
    const serializedChunks: WorldZoneChunk[] = Array.from(this.chunks.values());
    return JSON.stringify({
      timestamp: Date.now(),
      chunkCount: serializedChunks.length,
      chunks: serializedChunks,
    }, null, 2);
  }

  /**
   * Restores state from snapshot.
   */
  public deserialize(jsonString: string): void {
    const data = JSON.parse(jsonString);
    this.chunks.clear();
    for (const chunk of data.chunks as WorldZoneChunk[]) {
      this.chunks.set(this.getChunkKey(chunk.chunkX, chunk.chunkZ), chunk);
    }
  }

  public describeZone(x: number, z: number): string {
    const chunk = this.getChunkForWorldPos(x, z);
    const itemSummary = chunk.groundItems.length > 0
      ? `${chunk.groundItems.length} scattered items discarded in the dust.`
      : 'No loose equipment on the ground.';
    const brassSummary = chunk.spentBrassCount > 0
      ? `${chunk.spentBrassCount} spent brass casings half-buried in the soil.`
      : '';

    return `[Chunk (${chunk.chunkX}, ${chunk.chunkZ}) - ${chunk.biome}] ${itemSummary} ${brassSummary}`;
  }
}
