/**
 * Mount & Horse Container Ecosystem
 * Manages horse physical state, saddlebag inventory anchoring, and tethering.
 */

import type { MountState } from './types.ts';
import { InventoryContainer, TactileInventorySystem } from '../inventory/inventoryGrid.ts';
import type { ContainerConfig } from '../inventory/types.ts';
import { vec3, type Result, ok, err } from '../core/types.ts';

export class MountSystem {
  public state: MountState;
  public leftSaddlebag: InventoryContainer;
  public rightSaddlebag: InventoryContainer;
  public rifleScabbard: InventoryContainer;

  constructor(mountName: string = 'Gunslinger Dun', breed: string = 'American Standardbred') {
    const leftBagConfig: ContainerConfig = {
      id: 'mount_saddlebag_left',
      type: 'HORSE_SADDLEBAG_LEFT',
      gridWidth: 6,
      gridHeight: 6,
      maxMassCapacityKg: 35.0,
      maxVolumeCapacityCm3: 45000,
      bodyAnchorOffset: vec3(-0.45, 0.6, 0.0), // Off left flank
    };

    const rightBagConfig: ContainerConfig = {
      id: 'mount_saddlebag_right',
      type: 'HORSE_SADDLEBAG_RIGHT',
      gridWidth: 6,
      gridHeight: 6,
      maxMassCapacityKg: 35.0,
      maxVolumeCapacityCm3: 45000,
      bodyAnchorOffset: vec3(0.45, 0.6, 0.0), // Off right flank
    };

    const scabbardConfig: ContainerConfig = {
      id: 'mount_rifle_scabbard',
      type: 'HORSE_SCABBARD',
      gridWidth: 2,
      gridHeight: 8,
      maxMassCapacityKg: 8.0,
      maxVolumeCapacityCm3: 12000,
      bodyAnchorOffset: vec3(0.35, 0.7, 0.3), // Angled along cantle
    };

    this.leftSaddlebag = new InventoryContainer(leftBagConfig);
    this.rightSaddlebag = new InventoryContainer(rightBagConfig);
    this.rifleScabbard = new InventoryContainer(scabbardConfig);

    this.state = {
      id: 'mount_horse_01',
      name: mountName,
      breed,
      stamina: 100.0,
      maxStamina: 100.0,
      temperament: 'WAR_TRAINED',
      isHitched: false,
      distanceToPlayerM: 4.5,
      leftSaddlebagId: leftBagConfig.id,
      rightSaddlebagId: rightBagConfig.id,
      scabbardId: scabbardConfig.id,
    };
  }

  /**
   * Registers mount containers with the global tactile inventory system.
   */
  public registerWithInventory(inventorySys: TactileInventorySystem): void {
    inventorySys.registerContainer(this.leftSaddlebag);
    inventorySys.registerContainer(this.rightSaddlebag);
    inventorySys.registerContainer(this.rifleScabbard);
  }

  /**
   * Calculates saddle balance (checks whether load is distributed evenly between left and right flanks).
   */
  public getSaddlebagBalanceDeltaKg(): number {
    return this.leftSaddlebag.getTotalMassKg() - this.rightSaddlebag.getTotalMassKg();
  }

  public hitchToPost(): Result<string, string> {
    if (this.distanceToPlayerM > 3.0) {
      return err('Too far from mount to hitch reins.');
    }
    this.state.isHitched = true;
    return ok(`Split leather reins hitched securely. ${this.state.name} stands calm.`);
  }

  public unhitch(): Result<string, string> {
    this.state.isHitched = false;
    return ok(`Reins unhitched and gathered into left hand.`);
  }

  public inspectMount(): string {
    const leftMass = this.leftSaddlebag.getTotalMassKg().toFixed(1);
    const rightMass = this.rightSaddlebag.getTotalMassKg().toFixed(1);
    const balanceDelta = Math.abs(this.getSaddlebagBalanceDeltaKg());

    let balanceDesc = 'Saddlebags ride level across the withers.';
    if (balanceDelta > 6.0) {
      balanceDesc = `Saddle is listing heavily toward the ${this.getSaddlebagBalanceDeltaKg() > 0 ? 'left' : 'right'} flank (${balanceDelta.toFixed(1)}kg discrepancy).`;
    }

    return `[${this.state.name} - ${this.state.breed}] Coat is coated in pale grit. Left bag: ${leftMass}kg, Right bag: ${rightMass}kg. ${balanceDesc} ${this.state.isHitched ? '(Hitched)' : '(Free)'}`;
  }
}
