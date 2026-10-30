/**
 * Deterministic Fixed-Step Game Loop Runner
 * Supports decoupled tick rates (60Hz Physics / 20Hz Survival & World).
 */

import { ENGINE_CONFIG } from './config.ts';

export interface TickableSystem {
  name: string;
  onPhysicsTick?(dt: number, totalTime: number): void;
  onSurvivalTick?(dt: number, totalTime: number): void;
}

export class GameLoop {
  private systems: TickableSystem[] = [];
  private isRunning: boolean = false;
  private totalSimulationTime: number = 0;

  private physicsAccumulator: number = 0;
  private survivalAccumulator: number = 0;

  public registerSystem(system: TickableSystem): void {
    this.systems.push(system);
  }

  public stepManual(deltaRealTimeSeconds: number): void {
    // Clamp delta time to avoid spiral of death
    const clampedDelta = Math.min(deltaRealTimeSeconds, 0.25);

    this.physicsAccumulator += clampedDelta;
    this.survivalAccumulator += clampedDelta;

    // Physics step (60Hz)
    const physicsDt = ENGINE_CONFIG.PHYSICS_DELTA_TIME_S;
    while (this.physicsAccumulator >= physicsDt) {
      for (const sys of this.systems) {
        if (sys.onPhysicsTick) {
          sys.onPhysicsTick(physicsDt, this.totalSimulationTime);
        }
      }
      this.physicsAccumulator -= physicsDt;
      this.totalSimulationTime += physicsDt;
    }

    // Survival step (20Hz)
    const survivalDt = ENGINE_CONFIG.SURVIVAL_DELTA_TIME_S;
    while (this.survivalAccumulator >= survivalDt) {
      for (const sys of this.systems) {
        if (sys.onSurvivalTick) {
          sys.onSurvivalTick(survivalDt, this.totalSimulationTime);
        }
      }
      this.survivalAccumulator -= survivalDt;
    }
  }

  public getTotalTime(): number {
    return this.totalSimulationTime;
  }

  public reset(): void {
    this.totalSimulationTime = 0;
    this.physicsAccumulator = 0;
    this.survivalAccumulator = 0;
  }
}
