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
