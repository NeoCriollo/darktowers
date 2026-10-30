/**
 * Localized Body Trauma & Hemorrhage Simulation
 * 6-Zone physical damage model with vascular bleeding rates and diegetic symptoms.
 */

import type { BodyZone, Wound, BodyDamageState, BleedingTier } from './types.ts';
import { type Result, ok, err } from '../core/types.ts';
import { globalEventBus } from '../core/eventBus.ts';

export class BodyDamageEngine {
  public state: BodyDamageState;

  constructor() {
    this.state = {
      zones: {
        HEAD: { integrity: 1.0, wounds: [] },
        TORSO: { integrity: 1.0, wounds: [] },
        LEFT_ARM: { integrity: 1.0, wounds: [] },
        RIGHT_ARM: { integrity: 1.0, wounds: [] },
        LEFT_LEG: { integrity: 1.0, wounds: [] },
        RIGHT_LEG: { integrity: 1.0, wounds: [] },
      },
      totalBloodVolumeMl: 5000.0, // Healthy adult baseline
      isConscious: true,
      hasLimp: false,
      aimTremorIntensity: 0.0,
    };
  }

  /**
   * Inflicts a localized ballistic or blunt trauma wound.
   */
  public inflictWound(
    zone: BodyZone,
    description: string,
    integrityLoss: number,
    bleedingTier: BleedingTier
  ): Wound {
    let bleedingRateMlPerMin = 0;
    switch (bleedingTier) {
      case 'CAPILLARY_SEEP':
        bleedingRateMlPerMin = 15.0;
        break;
      case 'VENOUS_STEADY':
        bleedingRateMlPerMin = 90.0;
        break;
      case 'ARTERIAL_SPURTING':
        bleedingRateMlPerMin = 360.0;
        break;
      default:
        bleedingRateMlPerMin = 0.0;
    }

    const wound: Wound = {
      id: `wound_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      zone,
      description,
      bleedingTier,
      bleedingRateMlPerMin,
      painLevel: Math.min(1.0, integrityLoss * 1.5),
      isBandaged: false,
      isTourniqueted: false,
      infectionRisk: 0.1,
    };

    const targetZone = this.state.zones[zone];
    targetZone.integrity = Math.max(0.0, targetZone.integrity - integrityLoss);
    targetZone.wounds.push(wound);

    this.recalculateImpairments();

    globalEventBus.emit('survival:traumaApplied', {
      zone,
      severity: integrityLoss,
      bleedingRate: bleedingRateMlPerMin,
    });

    return wound;
  }

  /**
   * Recalculates functional physical impairments based on wounded zones.
   */
  private recalculateImpairments(): void {
    // Limp from leg damage
    this.state.hasLimp =
      this.state.zones.LEFT_LEG.integrity < 0.65 ||
      this.state.zones.RIGHT_LEG.integrity < 0.65;

    // Aim tremor from arm damage and pain
    const armDamage =
      (1.0 - this.state.zones.RIGHT_ARM.integrity) * 0.7 +
      (1.0 - this.state.zones.LEFT_ARM.integrity) * 0.3;

    let aggregatePain = 0;
    for (const z of Object.values(this.state.zones)) {
      for (const w of z.wounds) {
        aggregatePain += w.painLevel;
      }
    }

    this.state.aimTremorIntensity = Math.min(1.0, armDamage * 0.75 + aggregatePain * 0.15);

    // Unconsciousness threshold from severe hypovolemic shock
    if (this.state.totalBloodVolumeMl < 2800.0) {
      this.state.isConscious = false;
    }
  }

  /**
   * Ticks hemorrhage and blood volume loss over time dt.
   */
  public updateHemorrhage(dtSeconds: number): void {
    let totalMlPerSec = 0;

    for (const z of Object.values(this.state.zones)) {
      for (const w of z.wounds) {
        if (w.isTourniqueted) continue; // Stops arterial bleeding completely
        if (w.isBandaged) {
          totalMlPerSec += (w.bleedingRateMlPerMin / 60.0) * 0.15; // Bandage slows seep by 85%
        } else {
          totalMlPerSec += (w.bleedingRateMlPerMin / 60.0);
        }
      }
    }

    this.state.totalBloodVolumeMl = Math.max(0.0, this.state.totalBloodVolumeMl - totalMlPerSec * dtSeconds);
    this.recalculateImpairments();
  }

  /**
   * Applies emergency field dressing / pressure bandage to a wound.
   */
  public applyBandage(woundId: string): Result<string, string> {
    for (const z of Object.values(this.state.zones)) {
      const wound = z.wounds.find(w => w.id === woundId);
      if (wound) {
        wound.isBandaged = true;
        wound.bleedingRateMlPerMin *= 0.15;
        this.recalculateImpairments();
        return ok(`Clean linen bandage bound tightly over [${wound.zone}]: ${wound.description}. Bleeding curtailed.`);
      }
    }
    return err(`Wound [${woundId}] not found.`);
  }

  /**
   * Generates sensory diegetic trauma inspection report without floating numbers.
   */
  public inspectPhysicalCondition(): string {
    const lines: string[] = [];

    // Blood volume status
    const bloodRatio = this.state.totalBloodVolumeMl / 5000.0;
    if (bloodRatio > 0.90) {
      lines.push('Skin is warm and dry with natural desert sun coloration.');
    } else if (bloodRatio > 0.75) {
      lines.push('Fingertips are cool and pale; light perspiration beads on forehead.');
    } else if (bloodRatio > 0.60) {
      lines.push('Lips are ashen white; a cold, nauseating chill shivers through extremities.');
    } else {
      lines.push('CRITICAL HEMORRHAGE: Postural syncope near; world dissolves into high-ringing white noise.');
    }

    // Zone inspections
    for (const [zoneKey, zoneData] of Object.entries(this.state.zones)) {
      if (zoneData.wounds.length > 0) {
        for (const w of zoneData.wounds) {
          const status = w.isBandaged ? '(Dressed with stained cloth)' : '(Openly bleeding)';
          lines.push(`- [${zoneKey}]: ${w.description} ${status}`);
        }
      }
    }

    if (this.state.hasLimp) {
      lines.push('Right knee cannot bear full downforce; gait drags heavily in deep sand.');
    }

    if (this.state.aimTremorIntensity > 0.3) {
      lines.push('Spasms twitch in forearm muscles; maintaining a steady sight picture is excruciating.');
    }

    return lines.join('\n');
  }
}
