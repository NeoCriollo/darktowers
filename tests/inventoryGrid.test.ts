/**
 * Tactile Slot-Based Inventory System Unit Tests
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { InventoryContainer, TactileInventorySystem } from '../inventory/inventoryGrid.ts';
import type { Item, ContainerConfig } from '../inventory/types.ts';
import { vec3 } from '../core/types.ts';

describe('Tactile Slot-Based Inventory', () => {
  const pocketConfig: ContainerConfig = {
    id: 'coat_pocket_right',
    type: 'PLAYER_POCKET_RIGHT',
    gridWidth: 4,
    gridHeight: 3,
    maxMassCapacityKg: 6.0,
    maxVolumeCapacityCm3: 8000,
    bodyAnchorOffset: vec3(0.25, -0.2, 0.1),
  };

  const saddlebagConfig: ContainerConfig = {
    id: 'mount_saddlebag_right',
    type: 'HORSE_SADDLEBAG_RIGHT',
    gridWidth: 6,
    gridHeight: 6,
    maxMassCapacityKg: 30.0,
    maxVolumeCapacityCm3: 40000,
    bodyAnchorOffset: vec3(0.45, 0.6, 0.0),
  };

  const ammoBox: Item = {
    id: 'ammo_45_box_01',
    name: 'Cartridge Box (.45 Colt, 20 rds)',
    category: 'AMMUNITION',
    width: 2,
    height: 1,
    massKg: 0.65,
    volumeCm3: 450,
    condition: 1.0,
    stackable: false,
    quantity: 1,
    maxStack: 1,
    tactileDescription: 'Cardboard box stamped with brass eagle insignia, rattling with heavy lead cartridges.',
  };

  it('should successfully place item within spatial bounds and reject overlaps', () => {
    const container = new InventoryContainer(pocketConfig);

    // Place at (0, 0)
    const place1 = container.placeItemAt(ammoBox, 0, 0);
    assert.ok(place1.success);

    // Placing overlapping item at (1, 0) must fail
    const overlappingItem: Item = { ...ammoBox, id: 'ammo_box_02' };
    const place2 = container.placeItemAt(overlappingItem, 1, 0);
    assert.equal(place2.success, false, 'Overlapping items must be rejected');

    // Placing adjacent item at (2, 0) must succeed
    const place3 = container.placeItemAt(overlappingItem, 2, 0);
    assert.ok(place3.success, 'Adjacent placement must succeed');
  });

  it('should respect item spatial rotation (width and height swap)', () => {
    const container = new InventoryContainer(pocketConfig);

    // ammoBox is 2x1. If rotated, footprint is 1x2.
    // Placing rotated at column 3, row 0 (fits within grid 4x3)
    const rotatedItem: Item = { ...ammoBox, id: 'rotated_box' };
    const placeRes = container.placeItemAt(rotatedItem, 3, 0, true);
    assert.ok(placeRes.success);
    assert.equal(placeRes.value.item.isRotated, true);
  });

  it('should enforce strict mass capacity limits', () => {
    const container = new InventoryContainer(pocketConfig); // max 6.0kg

    const heavyLeadIngot: Item = {
      id: 'lead_ingot',
      name: 'Smelted Lead Bar',
      category: 'VALUABLE',
      width: 2,
      height: 2,
      massKg: 10.5, // exceeds 6.0kg limit
      volumeCm3: 1200,
      condition: 1.0,
      stackable: false,
      quantity: 1,
      maxStack: 1,
      tactileDescription: 'Cold, heavy gray lead bar.',
    };

    const placeRes = container.placeItemAt(heavyLeadIngot, 0, 0);
    assert.equal(placeRes.success, false);
    assert.ok(placeRes.error.includes('Exceeds maximum mass capacity'));
  });

  it('should transfer items seamlessly between player containers and mount saddlebags', () => {
    const invSys = new TactileInventorySystem();
    const pocket = new InventoryContainer(pocketConfig);
    const saddlebag = new InventoryContainer(saddlebagConfig);

    invSys.registerContainer(pocket);
    invSys.registerContainer(saddlebag);

    // Place in pocket initially
    pocket.placeItemAt(ammoBox, 0, 0);
    assert.equal(pocket.getPlacements().length, 1);
    assert.equal(saddlebag.getPlacements().length, 0);

    // Transfer from pocket to mount saddlebag
    const transferRes = invSys.transferItem(ammoBox.id, pocketConfig.id, saddlebagConfig.id, 2, 2);
    assert.ok(transferRes.success);
    assert.equal(pocket.getPlacements().length, 0);
    assert.equal(saddlebag.getPlacements().length, 1);
    assert.equal(saddlebag.getItem(ammoBox.id)?.name, ammoBox.name);
  });

  it('should accurately compute encumbrance ratio and lateral imbalance torque', () => {
    const invSys = new TactileInventorySystem();

    const rightPocket = new InventoryContainer(pocketConfig);
    const leftPocket = new InventoryContainer({
      ...pocketConfig,
      id: 'coat_pocket_left',
      type: 'PLAYER_POCKET_LEFT',
      bodyAnchorOffset: vec3(-0.25, -0.2, 0.1),
    });

    invSys.registerContainer(rightPocket);
    invSys.registerContainer(leftPocket);

    // Load 3 heavy boxes into right pocket only
    rightPocket.placeItemAt({ ...ammoBox, id: 'box_r1', massKg: 1.8 }, 0, 0);
    rightPocket.placeItemAt({ ...ammoBox, id: 'box_r2', massKg: 1.8 }, 2, 0);

    const profile = invSys.computePlayerEncumbrance(75.0);
    assert.ok(profile.totalMassKg > 3.0);
    assert.ok(profile.lateralImbalanceTorque > 0.0, 'Weight in right pocket must create positive rightward torque');
    assert.ok(profile.tactileStatusDescription.length > 0);
  });
});
