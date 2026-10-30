/**
 * Dynamic Narrative Engine & World Event Triggers
 * Evaluates world, survival, and weapon conditions to generate immersive diegetic narrative cues.
 */

import { WeaponMechanics } from '../physics/weaponMechanics.ts';
import { BodyDamageEngine } from '../survival/bodyDamage.ts';
import type { AtmosphericState } from '../world/types.ts';

export interface NarrativeCue {
  id: string;
  intensity: 'WHISPER' | 'WARNING' | 'CRITICAL';
  prose: string;
}

export class DynamicNarrativeEngine {
  /**
   * Evaluates aggregate player state against wasteland hazards to surface diegetic narrative cues.
   */
  public evaluateSurvivalCues(
    weapon: WeaponMechanics,
    trauma: BodyDamageEngine,
    atmosphere: AtmosphericState
  ): NarrativeCue[] {
    const cues: NarrativeCue[] = [];

    // Weapon condition under environmental duress
    if (atmosphere.type === 'SEVERE_HABOOB' && !weapon.isHolstered) {
      cues.push({
        id: 'haboob_weapon_exposure',
        intensity: 'WARNING',
        prose: 'Grit lashes against exposed steel with a dry hiss. Fine powder is seeping into the cylinder gap and hammer well.',
      });
    }

    if (weapon.chamber.startsWith('JAMMED_')) {
      cues.push({
        id: 'weapon_malfunction_cue',
        intensity: 'CRITICAL',
        prose: 'The steel binds dead in your grip. Cold metallic panic sets in—you need to strip that casing before whatever is out there closes distance.',
      });
    }

    // Hemorrhage cues
    if (trauma.state.totalBloodVolumeMl < 4200) {
      cues.push({
        id: 'blood_loss_cue',
        intensity: 'CRITICAL',
        prose: 'The heat of your own blood soaks through your boots. The desert horizon tilts gently to the left.',
      });
    }

    // Atmospheric cues
    if (atmosphere.type === 'HEAT_HAZE') {
      cues.push({
        id: 'heat_haze_lore',
        intensity: 'WHISPER',
        prose: 'The sun is a pale executioner directly overhead. The bleached bones of old telegraph poles stretch out like crooked fingers toward the Dark Tower.',
      });
    }

    return cues;
  }
}
