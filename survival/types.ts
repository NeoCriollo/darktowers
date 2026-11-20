/**
 * Survival, Trauma & Mount System Types
 * The Path of Ka - Vertical Slice Architecture
 */

export type BodyZone =
  | 'HEAD'
  | 'TORSO'
  | 'LEFT_ARM'
  | 'RIGHT_ARM'
  | 'LEFT_LEG'
  | 'RIGHT_LEG';

export type BleedingTier =
  | 'NONE'
  | 'CAPILLARY_SEEP'
  | 'VENOUS_STEADY'
  | 'ARTERIAL_SPURTING';

export interface Wound {
  id: string;
  zone: BodyZone;
  description: string;
  bleedingTier: BleedingTier;
  bleedingRateMlPerMin: number;
  painLevel: number;        // 0.0 to 1.0
  isBandaged: boolean;
  isTourniqueted: boolean;
  infectionRisk: number;    // Elevated by sand and unwashed fabric
}

export interface BodyDamageState {
  zones: Record<BodyZone, { integrity: number; wounds: Wound[] }>; // integrity 1.0 (undamaged) to 0.0 (shattered)
  totalBloodVolumeMl: number; // Normal ~5000ml
  isConscious: boolean;
  hasLimp: boolean;
  aimTremorIntensity: number; // 0.0 to 1.0 (affected by arm integrity & pain)
}

export interface MountState {
  id: string;
  name: string;
  breed: string;
  stamina: number;           // 0 to 100
  maxStamina: number;
  temperament: 'DOCILE' | 'SKITTISH' | 'WAR_TRAINED';
  isHitched: boolean;
  distanceToPlayerM: number;
  leftSaddlebagId: string;
  rightSaddlebagId: string;
  scabbardId: string;
}

