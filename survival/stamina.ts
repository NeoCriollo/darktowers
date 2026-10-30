/**
 * Metabolic Stamina & Respiration Simulation
 * Deterministic formulas coupling physical carried weight, weather stress, and blood loss.
 */

import type { EncumbranceProfile } from '../inventory/types.ts';
import { globalEventBus } from '../core/eventBus.ts';

export type ActivityLevel = 'RESTING' | 'CROUCHING' | 'WALKING' | 'SPRINTING' | 'MELEE_SWING';

export class StaminaEngine {
  public currentStamina: number = 100.0;
  public maxStamina: number = 100.0;
  public respirationRateBpm: number = 14.0; // Breaths per minute
  public heartRateBpm: number = 65.0;

  // Metabolic rates (per second)
  private readonly BASE_SPRINT_DRAIN = 14.5;
  private readonly BASE_WALK_DRAIN = 1.2;
  private readonly BASE_RECOVERY = 9.0;

  /**
   * Ticks stamina change over delta time dt.
   */
  public update(
    dtSeconds: number,
    activity: ActivityLevel,
    encumbrance: EncumbranceProfile,
    temperatureCelsius: number = 36.0,
    bloodLossFraction: number = 0.0,
    painLevel: number = 0.0
  ): void {
    // Thermal stress factor: excessive desert heat (>35°C) increases exertion
    const thermalStress = Math.max(0, (temperatureCelsius - 32.0) * 0.12);

    // Blood loss directly reduces effective maximum stamina ceiling
    this.maxStamina = Math.max(20.0, 100.0 * (1.0 - bloodLossFraction * 1.2));

    if (activity === 'SPRINTING') {
      const netDrainRate =
        (this.BASE_SPRINT_DRAIN * encumbrance.staminaPenaltyMultiplier + thermalStress + painLevel * 4.0);

      this.currentStamina = Math.max(0, this.currentStamina - netDrainRate * dtSeconds);
      this.heartRateBpm = Math.min(185.0, this.heartRateBpm + 25.0 * dtSeconds);
      this.respirationRateBpm = Math.min(48.0, this.respirationRateBpm + 10.0 * dtSeconds);

      globalEventBus.emit('survival:staminaDrained', {
        remainingStamina: this.currentStamina,
        maxStamina: this.maxStamina,
        drainRate: netDrainRate,
      });

    } else if (activity === 'WALKING') {
      const netDrainRate =
        (this.BASE_WALK_DRAIN * encumbrance.staminaPenaltyMultiplier + thermalStress * 0.5);

      if (encumbrance.encumbranceRatio > 1.2) {
        // Overburdened walking actually drains stamina
        this.currentStamina = Math.max(0, this.currentStamina - netDrainRate * dtSeconds);
      } else {
        // Slow recovery while walking lightly loaded
        const recoveryRate = (this.BASE_RECOVERY * 0.35) / encumbrance.staminaPenaltyMultiplier;
        this.currentStamina = Math.min(this.maxStamina, this.currentStamina + recoveryRate * dtSeconds);
      }

      this.heartRateBpm = Math.max(85.0, this.heartRateBpm - 5.0 * dtSeconds);

    } else {
      // RESTING or CROUCHING
      const netRecovery = (this.BASE_RECOVERY / encumbrance.staminaPenaltyMultiplier) * (1.0 - bloodLossFraction * 0.5);
      this.currentStamina = Math.min(this.maxStamina, this.currentStamina + netRecovery * dtSeconds);

      this.heartRateBpm = Math.max(65.0, this.heartRateBpm - 8.0 * dtSeconds);
      this.respirationRateBpm = Math.max(14.0, this.respirationRateBpm - 4.0 * dtSeconds);
    }
  }

  /**
   * Generates diegetic auditory/respiratory feedback without numbers.
   */
  public getRespirationStatus(): string {
    const ratio = this.currentStamina / this.maxStamina;
    if (ratio > 0.75) {
      return 'Breathing is steady and rhythmic through the nose.';
    } else if (ratio > 0.40) {
      return 'Chest heaves in deep, measured breaths; throat feels dry.';
    } else if (ratio > 0.15) {
      return 'Ragged, audible panting; temple veins pulse with hard blood pressure.';
    } else {
      return 'Gasping violently for breath; vision tunnels and hands tremble with oxygen debt.';
    }
  }
}
