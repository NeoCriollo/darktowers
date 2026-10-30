/**
 * Tactile Slot-Based Grid Inventory Subsystem
 * Pure modular component managing physical item packing, mass distribution, and torque.
 */

import type {
  Item,
  GridPlacement,
  ContainerConfig,
  EncumbranceProfile,
} from './types.ts';
import { type Result, ok, err, type Vector3, vec3, vec3Add, vec3Scale } from '../core/types.ts';
import { globalEventBus } from '../core/eventBus.ts';
import { ENGINE_CONFIG } from '../core/config.ts';

export class InventoryContainer {
  public readonly config: ContainerConfig;
  private placements: Map<string, GridPlacement> = new Map();
  // 2D cell occupancy matrix: occupancy[y][x] = itemId or null
  private occupancyGrid: (string | null)[][];

  constructor(config: ContainerConfig) {
    this.config = config;
    this.occupancyGrid = Array.from({ length: config.gridHeight }, () =>
      Array.from({ length: config.gridWidth }, () => null)
    );
  }

  public getPlacements(): ReadonlyArray<GridPlacement> {
    return Array.from(this.placements.values());
  }

  public getItem(itemId: string): Item | undefined {
    return this.placements.get(itemId)?.item;
  }

  public getTotalMassKg(): number {
    let mass = 0;
    for (const p of this.placements.values()) {
      mass += p.item.massKg * p.item.quantity;
    }
    return mass;
  }

  public getTotalVolumeCm3(): number {
    let vol = 0;
    for (const p of this.placements.values()) {
      vol += p.item.volumeCm3 * p.item.quantity;
    }
    return vol;
  }

  /**
   * Checks whether a rectangular footprint (w, h) fits at (x, y) without colliding.
   */
  public canPlaceAt(w: number, h: number, x: number, y: number, ignoreItemId?: string): boolean {
    if (x < 0 || y < 0 || x + w > this.config.gridWidth || y + h > this.config.gridHeight) {
      return false;
    }

    for (let r = y; r < y + h; r++) {
      for (let c = x; c < x + w; c++) {
        const occupant = this.occupancyGrid[r][c];
        if (occupant !== null && occupant !== ignoreItemId) {
          return false;
        }
      }
    }

    return true;
  }

  /**
   * Inserts an item into specific (x, y) coordinates with tactile spatial validation.
   */
  public placeItemAt(item: Item, x: number, y: number, isRotated: boolean = false): Result<GridPlacement, string> {
    const w = isRotated ? item.height : item.width;
    const h = isRotated ? item.width : item.height;

    // 1. Check weight limit
    const itemMass = item.massKg * item.quantity;
    if (this.getTotalMassKg() + itemMass > this.config.maxMassCapacityKg) {
      return err(
        `Exceeds maximum mass capacity of ${this.config.maxMassCapacityKg}kg for [${this.config.id}] (Item: ${itemMass.toFixed(2)}kg).`
      );
    }

    // 2. Check volume limit
    const itemVol = item.volumeCm3 * item.quantity;
    if (this.getTotalVolumeCm3() + itemVol > this.config.maxVolumeCapacityCm3) {
      return err(
        `Exceeds physical volume displacement of ${this.config.maxVolumeCapacityCm3}cm³ for [${this.config.id}].`
      );
    }

    // 3. Check spatial bounds and collision
    if (!this.canPlaceAt(w, h, x, y)) {
      return err(`Grid collision or out of bounds at (${x}, ${y}) for item footprint ${w}x${h}.`);
    }

    // Allocate in occupancy grid
    const itemToStore: Item = { ...item, isRotated };
    for (let r = y; r < y + h; r++) {
      for (let c = x; c < x + w; c++) {
        this.occupancyGrid[r][c] = itemToStore.id;
      }
    }

    const placement: GridPlacement = { item: itemToStore, x, y };
    this.placements.set(itemToStore.id, placement);

    globalEventBus.emit('inventory:itemMoved', {
      itemId: itemToStore.id,
      sourceContainerId: 'ground',
      targetContainerId: this.config.id,
      x,
      y,
    });

    return ok(placement);
  }

  /**
   * Removes an item from the container.
   */
  public removeItem(itemId: string): Result<Item, string> {
    const placement = this.placements.get(itemId);
    if (!placement) {
      return err(`Item [${itemId}] not found in container [${this.config.id}].`);
    }

    const item = placement.item;
    const w = item.isRotated ? item.height : item.width;
    const h = item.isRotated ? item.width : item.height;

    // Clear grid
    for (let r = placement.y; r < placement.y + h; r++) {
      for (let c = placement.x; c < placement.x + w; c++) {
        if (this.occupancyGrid[r][c] === itemId) {
          this.occupancyGrid[r][c] = null;
        }
      }
    }

    this.placements.delete(itemId);
    return ok(item);
  }

  /**
   * Automatically finds the first open slot for an item (scans row by row, testing unrotated then rotated).
   */
  public autoInsert(item: Item): Result<GridPlacement, string> {
    // Try unrotated first
    for (let r = 0; r <= this.config.gridHeight - item.height; r++) {
      for (let c = 0; c <= this.config.gridWidth - item.width; c++) {
        if (this.canPlaceAt(item.width, item.height, c, r)) {
          return this.placeItemAt(item, c, r, false);
        }
      }
    }

    // Try rotated
    for (let r = 0; r <= this.config.gridHeight - item.width; r++) {
      for (let c = 0; c <= this.config.gridWidth - item.height; c++) {
        if (this.canPlaceAt(item.height, item.width, c, r)) {
          return this.placeItemAt(item, c, r, true);
        }
      }
    }

    return err(`No sufficient contiguous slot grid space found in [${this.config.id}] for item [${item.name}].`);
  }
}

/**
 * Composite Manager tracking all player and mount containers,
 * calculating center-of-mass moments and physical load balancing.
 */
export class TactileInventorySystem {
  private containers: Map<string, InventoryContainer> = new Map();

  public registerContainer(container: InventoryContainer): void {
    this.containers.set(container.config.id, container);
  }

  public getContainer(id: string): InventoryContainer | undefined {
    return this.containers.get(id);
  }

  /**
   * Transfers an item between two containers (e.g., from player pocket to horse saddlebag).
   */
  public transferItem(
    itemId: string,
    sourceContainerId: string,
    targetContainerId: string,
    targetX?: number,
    targetY?: number,
    rotate?: boolean
  ): Result<GridPlacement, string> {
    const src = this.containers.get(sourceContainerId);
    const dst = this.containers.get(targetContainerId);

    if (!src) return err(`Source container [${sourceContainerId}] not found.`);
    if (!dst) return err(`Target container [${targetContainerId}] not found.`);

    const placement = src.getItem(itemId);
    if (!placement) return err(`Item [${itemId}] not in source container.`);

    // Extract item
    const removeRes = src.removeItem(itemId);
    if (!removeRes.success) return removeRes;

    const item = removeRes.value;

    let placeRes: Result<GridPlacement, string>;
    if (targetX !== undefined && targetY !== undefined) {
      placeRes = dst.placeItemAt(item, targetX, targetY, rotate ?? false);
    } else {
      placeRes = dst.autoInsert(item);
    }

    // Rollback if destination placement failed
    if (!placeRes.success) {
      src.placeItemAt(item, 0, 0, false); // fallback return
      return err(`Transfer failed: ${placeRes.error}`);
    }

    globalEventBus.emit('inventory:itemMoved', {
      itemId,
      sourceContainerId,
      targetContainerId,
      x: placeRes.value.x,
      y: placeRes.value.y,
    });

    return placeRes;
  }

  /**
   * Calculates the aggregate encumbrance profile across all player-worn containers.
   */
  public computePlayerEncumbrance(playerBodyMassKg: number = 78.0): EncumbranceProfile {
    let totalCarriedMass = 0;
    let weightedPositionSum = vec3(0, 0, 0);

    const playerContainers = Array.from(this.containers.values()).filter(c =>
      c.config.type.startsWith('PLAYER_')
    );

    for (const c of playerContainers) {
      const containerMass = c.getTotalMassKg();
      totalCarriedMass += containerMass;

      // Contribution to center of mass offset
      const anchor = c.config.bodyAnchorOffset;
      weightedPositionSum = vec3Add(
        weightedPositionSum,
        vec3Scale(anchor, containerMass)
      );
    }

    const totalSystemMass = playerBodyMassKg + totalCarriedMass;
    const centerOfMassOffset = vec3Scale(weightedPositionSum, 1.0 / totalSystemMass);

    // Lateral imbalance torque = X-offset * carried mass (in kg*m)
    const lateralImbalanceTorque = weightedPositionSum.x;

    const maxComfort = ENGINE_CONFIG.MAX_COMFORT_PLAYER_MASS_KG;
    const encumbranceRatio = totalCarriedMass / maxComfort;

    // Non-linear stamina penalty multiplier: S_pen = 1.0 + (ratio)^1.8
    const staminaPenaltyMultiplier = 1.0 + Math.pow(Math.max(0, encumbranceRatio - 0.7), 1.8);

    // Sensory diegetic status description
    let tactileStatusDescription: string;
    if (encumbranceRatio < 0.6) {
      tactileStatusDescription = 'Pouch and holster ride lightly; stride is unburdened and agile.';
    } else if (encumbranceRatio < 1.0) {
      tactileStatusDescription = 'Straps pull taut across shoulders; weight shifts with each heavy bootstep.';
    } else if (encumbranceRatio < 1.4) {
      tactileStatusDescription = 'Lead cartridges and equipment strain coat seams; breathing is heavy and footwork sluggish.';
    } else {
      tactileStatusDescription = 'CRITICAL OVERBURDEN: Knees bow under crushing deadweight; sprint is impossible.';
    }

    if (Math.abs(lateralImbalanceTorque) > 2.5) {
      const side = lateralImbalanceTorque > 0 ? 'right' : 'left';
      tactileStatusDescription += ` Severe weight listing pulls torso heavily to the ${side}.`;
    }

    return {
      totalMassKg: totalCarriedMass,
      massCapacityKg: maxComfort,
      encumbranceRatio,
      centerOfMassOffset,
      lateralImbalanceTorque,
      staminaPenaltyMultiplier,
      tactileStatusDescription,
    };
  }
}
