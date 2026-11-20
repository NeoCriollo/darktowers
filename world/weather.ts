/**
 * Dynamic Atmospheric & Weather Loop Engine
 * Simulates wasteland meteorology, sandstorms (Haboob), and thermal cycles.
 */

import type { AtmosphericState, WeatherType } from './types.ts';
import { vec3, vec3Normalize } from '../core/types.ts';
import { globalEventBus } from '../core/eventBus.ts';

export class WeatherEngine {
  public currentAtmosphere: AtmosphericState;
  private weatherTimerSeconds: number = 0;
  private targetWeatherType: WeatherType = 'CLEAR_ARID';

  constructor(initialWeather: WeatherType = 'CLEAR_ARID') {
    this.currentAtmosphere = this.generateAtmospherePreset(initialWeather);
    this.targetWeatherType = initialWeather;
  }

  /**
   * Sets weather type directly (for scripted encounters or transitions).
   */
  public transitionTo(type: WeatherType): void {
    const previous = this.currentAtmosphere.type;
    this.targetWeatherType = type;
    this.currentAtmosphere = this.generateAtmospherePreset(type);

    globalEventBus.emit('weather:conditionChanged', {
      previousCondition: previous,
      newCondition: type,
      gritSuspensionDensity: this.currentAtmosphere.gritSuspensionDensityMgM3,
      windSpeedMps: this.currentAtmosphere.windSpeedMps,
      temperatureCelsius: this.currentAtmosphere.temperatureCelsius,
    });
  }

  /**
   * Ticks weather simulation.
   */
  public update(dtSeconds: number): void {
    this.weatherTimerSeconds += dtSeconds;

    // Small stochastic gusts in wind speed
    const windFluctuation = (Math.random() - 0.5) * 1.5 * dtSeconds;
    this.currentAtmosphere.windSpeedMps = Math.max(0.5, this.currentAtmosphere.windSpeedMps + windFluctuation);

    // Weather loop state progression (every 180 seconds if unscripted)
    if (this.weatherTimerSeconds > 180.0) {
      this.weatherTimerSeconds = 0;
      this.cycleNaturalWeather();
    }
  }

  /**
   * Resolves effective grit density taking into account sector-specific silica multiplier
   * (e.g. Node 1 SW Desolation increased silica multiplier).
   */
  public getEffectiveGritDensity(basinId?: string): number {
    const baseGrit = this.currentAtmosphere.gritSuspensionDensityMgM3;
    if (basinId === 'sw_desolation') {
      return baseGrit * 2.5;
    } else if (basinId === 'west_gorge') {
      return baseGrit * 1.8;
    } else if (basinId === 'east_dunes') {
      return baseGrit * 2.2;
    } else if (basinId === 'monolith_pass' || basinId === 'tower_threshold') {
      return baseGrit * 2.4;
    }
    return baseGrit;
  }

  /**
   * Resolves effective movement stamina drain multiplier taking into account sector-specific terrain
   * (e.g. Node 6 The Great Shifting Erg loose-sand movement fatigue).
   */
  public getEffectiveStaminaDrainMultiplier(basinId?: string): number {
    if (basinId === 'east_dunes') {
      return 1.6;
    }
    return 1.0;
  }

  /**
   * Resolves effective salt corrosion multiplier taking into account sector-specific salt flats
   * (e.g. Node 2 Dead-Creek Salt Flats and Node 5 Bleached Alkali Sink increased corrosion multiplier).
   */
  public getEffectiveCorrosionMultiplier(basinId?: string): number {
    if (basinId === 'south_salt') {
      return 2.5;
    } else if (basinId === 'north_alkali') {
      return 2.0;
    }
    return 1.0;
  }

  /**
   * Resolves effective iron-oxide mechanical fouling multiplier taking into account sector-specific canyon dust
   * (e.g. Node 4 Rust-Gorge Defile abrasive iron-oxide particulate).
   */
  public getEffectiveFoulingMultiplier(basinId?: string): number {
    if (basinId === 'west_gorge') {
      return 1.8;
    }
    return 1.0;
  }

  /**
   * Resolves effective glare visibility penalty taking into account sector-specific salt flats
   * (e.g. Node 2 Dead-Creek Salt Flats blinding horizon glare).
   */
  public getEffectiveGlarePenalty(basinId?: string): number {
    if (basinId === 'south_salt') {
      return 0.45;
    }
    return 0.0;
  }

  /**
   * Resolves effective Thinny spatial distortion hazard taking into account proximity
   * to the NE Scenic Overlook (+140, +140) and Thinny Beam Abyss (+325, +325).
   */
  public getEffectiveThinnyDistortion(position?: { x: number; z: number }): number {
    if (!position) {
      return 0.0;
    }
    const dAbyss = Math.hypot(position.x - 325.0, position.z - 325.0);
    const dOverlook = Math.hypot(position.x - 140.0, position.z - 140.0);
    const overlookFactor = dOverlook <= 60.0 ? ((60.0 - dOverlook) / 60.0) * 0.35 : 0.0;
    const abyssFactor = dAbyss <= 265.0 ? Math.max(0.0, Math.min(1.0, (265.0 - dAbyss) / 110.0)) : 0.0;
    return Math.max(overlookFactor, abyssFactor);
  }

  /**
   * Resolves effective Ka Survey Beacon energy resonance taking into account proximity
   * to the Ka Survey Beacon Monolith at (+45.0, +680.0) in Node 5 (Bleached Alkali Sink).
   * Scales from 0.0 at d > 120m to 1.0 at d = 0m.
   */
  public getEffectiveKaResonance(position?: { x: number; z: number }): number {
    if (!position) {
      return 0.0;
    }
    const dBeacon = Math.hypot(position.x - 45.0, position.z - 680.0);
    if (dBeacon > 120.0) {
      return 0.0;
    }
    return Math.max(0.0, Math.min(1.0, (120.0 - dBeacon) / 120.0));
  }

  /**
   * Resolves effective Tower Nexus psychic strain taking into account proximity
   * to the Dark Tower Spire and Citadel Plateau at (+700.0, +700.0) in Node 7 (Tower Threshold).
   * Scales from 0.0 at d > 220m to 1.0 at d = 0m.
   */
  public getEffectiveTowerNexusStrain(position?: { x: number; z: number }): number {
    if (!position) {
      return 0.0;
    }
    const dSpire = Math.hypot(position.x - 700.0, position.z - 700.0);
    if (dSpire > 220.0) {
      return 0.0;
    }
    return Math.max(0.0, Math.min(1.0, (220.0 - dSpire) / 220.0));
  }

  private cycleNaturalWeather(): void {
    const cycleMap: Record<WeatherType, WeatherType> = {
      CLEAR_ARID: 'HEAT_HAZE',
      HEAT_HAZE: 'DUST_DEVIL',
      DUST_DEVIL: 'SEVERE_HABOOB',
      SEVERE_HABOOB: 'COLD_DESERT_NIGHT',
      COLD_DESERT_NIGHT: 'CLEAR_ARID',
    };
    this.transitionTo(cycleMap[this.currentAtmosphere.type]);
  }

  private generateAtmospherePreset(type: WeatherType): AtmosphericState {
    switch (type) {
      case 'CLEAR_ARID':
        return {
          type,
          temperatureCelsius: 28.0,
          relativeHumidity: 0.12,
          windSpeedMps: 3.5,
          windDirectionVector: vec3Normalize(vec3(1.0, 0, 0.5)),
          gritSuspensionDensityMgM3: 4.0, // Mild ambient desert dust
          solarRadiationWm2: 850.0,
          visibilityMeters: 8000.0,
        };

      case 'HEAT_HAZE':
        return {
          type,
          temperatureCelsius: 41.5,
          relativeHumidity: 0.08,
          windSpeedMps: 1.8,
          windDirectionVector: vec3Normalize(vec3(0.5, 0, 1.0)),
          gritSuspensionDensityMgM3: 8.5,
          solarRadiationWm2: 1050.0,
          visibilityMeters: 4500.0,
        };

      case 'DUST_DEVIL':
        return {
          type,
          temperatureCelsius: 37.0,
          relativeHumidity: 0.09,
          windSpeedMps: 12.0,
          windDirectionVector: vec3Normalize(vec3(-0.7, 0, 0.7)),
          gritSuspensionDensityMgM3: 45.0,
          solarRadiationWm2: 720.0,
          visibilityMeters: 1200.0,
        };

      case 'SEVERE_HABOOB':
        return {
          type,
          temperatureCelsius: 32.0,
          relativeHumidity: 0.18,
          windSpeedMps: 24.5, // Gale force sandstorm
          windDirectionVector: vec3Normalize(vec3(1.0, 0, 0.2)),
          gritSuspensionDensityMgM3: 160.0, // Choking density
          solarRadiationWm2: 120.0, // Sun blotted out
          visibilityMeters: 18.0,
        };

      case 'COLD_DESERT_NIGHT':
        return {
          type,
          temperatureCelsius: 3.0,
          relativeHumidity: 0.35,
          windSpeedMps: 5.0,
          windDirectionVector: vec3Normalize(vec3(0.2, 0, -1.0)),
          gritSuspensionDensityMgM3: 2.0,
          solarRadiationWm2: 0.0,
          visibilityMeters: 1500.0,
        };
    }
  }

  /**
   * Diegetic weather description.
   */
  public describeAtmosphere(): string {
    switch (this.currentAtmosphere.type) {
      case 'CLEAR_ARID':
        return 'The sky is a bleached cobalt dome. Dry heat ripples faintly over the horizon.';
      case 'HEAT_HAZE':
        return 'Oppressive thermal radiation bakes the hardpan. Distant mesa outlines dance in shimmering mirages.';
      case 'DUST_DEVIL':
        return 'Erratic thermal vortices whip stinging sand devils across the salt flats.';
      case 'SEVERE_HABOOB':
        return 'A towering brown wall of silica sand engulfs the land. Howling winds blind vision and grit crunches between teeth.';
      case 'COLD_DESERT_NIGHT':
        return 'Freezing desert air sinks into the canyon floor. Unblinking stars burn cold overhead.';
    }
  }
}
