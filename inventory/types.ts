/**
 * Tactile Slot-Based Inventory Types & Data Models
 * The Path of Ka - Vertical Slice Architecture
 */

import type { Vector3 } from '../core/types.ts';

export type ItemCategory =
  | 'FIREARM'
  | 'AMMUNITION'
  | 'CLEANING_KIT'
  | 'MEDICAL'
  | 'RATION'
  | 'CAMP_EQUIPMENT'
  | 'VALUABLE';

export interface Item {
  id: string;
  name: string;
  category: ItemCategory;
  width: number;            // Grid width in cells (each cell is 5cm)
  height: number;           // Grid height in cells
  massKg: number;           // Weight in kilograms
  volumeCm3: number;        // Physical volume in cubic centimeters
  isRotated?: boolean;      // 90-degree spatial rotation
  condition: number;        // 0.0 (ruined) to 1.0 (mint)
  stackable: boolean;
  quantity: number;
  maxStack: number;
  tactileDescription: string;
  metadata?: Record<string, any>;
}

export type ContainerType =
  | 'PLAYER_POCKET_LEFT'
  | 'PLAYER_POCKET_RIGHT'
  | 'PLAYER_HOLSTER_RIGHT'
  | 'PLAYER_BANDOLIER'
  | 'PLAYER_BACKPACK'
  | 'HORSE_SADDLEBAG_LEFT'
  | 'HORSE_SADDLEBAG_RIGHT'
  | 'HORSE_SCABBARD';

export interface GridPlacement {
  item: Item;
  x: number; // Grid column (0-indexed)
  y: number; // Grid row (0-indexed)
}

export interface ContainerConfig {
  id: string;
  type: ContainerType;
  gridWidth: number;
  gridHeight: number;
  maxMassCapacityKg: number;
  maxVolumeCapacityCm3: number;
  bodyAnchorOffset: Vector3; // Spatial offset relative to body/mount center (x: left/right, y: up/down, z: front/back)
}

export interface EncumbranceProfile {
  totalMassKg: number;
  massCapacityKg: number;
  encumbranceRatio: number;
  centerOfMassOffset: Vector3;
  lateralImbalanceTorque: number; // Positive = pulling right, Negative = pulling left
  staminaPenaltyMultiplier: number;
  tactileStatusDescription: string;
}
