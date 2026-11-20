/**
 * Tactical Universal Pause Menu & Sunny Day Lighting Override Domain Contract
 * "Dark Towers: The Path of Ka"
 *
 * Models state synchronization between Tree Pause, Cursor Visibility,
 * Editor Mode lighting overrides, and World Layout persistence triggers.
 */

export const PauseMenuAction = {
  RESUME: 'resume',
  SAVE_WORLD: 'save_world',
  SETTINGS: 'settings',
  DEV_HELP: 'dev_help',
  MAIN_MENU: 'main_menu',
  SUNNY_DAY_TOGGLE: 'sunny_day_toggle'
} as const;

export type PauseMenuAction = typeof PauseMenuAction[keyof typeof PauseMenuAction];

export interface LightingEnvironmentSnapshot {
  sunEnergy: number;
  sunColor: { r: number; g: number; b: number };
  ambientColor: { r: number; g: number; b: number };
  ambientEnergy: number;
  fogEnabled: boolean;
  volumetricFogEnabled: boolean;
  particleDensity: number;
  shadowsEnabled: boolean;
  sunPitchDeg: number;
}

export const SUNNY_DAY_CONSTANTS = {
  SUN_ENERGY: 3.5,
  SUN_COLOR: { r: 1.0, g: 0.98, b: 0.95 },
  AMBIENT_COLOR: { r: 1.0, g: 1.0, b: 1.0 },
  AMBIENT_ENERGY: 1.2,
  FOG_ENABLED: false,
  VOLUMETRIC_FOG_ENABLED: false,
  PARTICLE_DENSITY: 0.0,
  SHADOWS_ENABLED: false,
  OVERHEAD_PITCH_DEG: 55.0
} as const;

export const DEFAULT_ENVIRONMENT_BASELINE: LightingEnvironmentSnapshot = {
  sunEnergy: 1.95,
  sunColor: { r: 1.0, g: 0.78, b: 0.52 },
  ambientColor: { r: 0.38, g: 0.42, b: 0.50 },
  ambientEnergy: 0.65,
  fogEnabled: true,
  volumetricFogEnabled: true,
  particleDensity: 0.15,
  shadowsEnabled: true,
  sunPitchDeg: -14.0
};

export class PauseMenuState {
  public isPaused: boolean = false;
  public isEditorMode: boolean = false;
  public isSunnyDayActive: boolean = false;
  public isSettingsOpen: boolean = false;
  public isHelpOpen: boolean = false;
  public lastSaveStatus: string = '';
  public savedLightingState: LightingEnvironmentSnapshot = { ...DEFAULT_ENVIRONMENT_BASELINE };

  constructor(editorMode: boolean = false) {
    this.isEditorMode = editorMode;
  }

  public togglePause(force?: boolean): boolean {
    this.isPaused = force !== undefined ? force : !this.isPaused;
    if (!this.isPaused) {
      this.isSettingsOpen = false;
      this.isHelpOpen = false;
    }
    return this.isPaused;
  }

  public getMouseMode(): 'CAPTURED' | 'VISIBLE' {
    return this.isPaused ? 'VISIBLE' : 'CAPTURED';
  }

  public toggleSunnyDay(): boolean {
    if (!this.isEditorMode) {
      return false;
    }
    this.isSunnyDayActive = !this.isSunnyDayActive;
    return this.isSunnyDayActive;
  }

  public setSunnyDay(active: boolean): boolean {
    if (!this.isEditorMode) {
      this.isSunnyDayActive = false;
      return false;
    }
    this.isSunnyDayActive = active;
    return this.isSunnyDayActive;
  }

  public resolveEffectiveLighting(baseSectorAtmosphere?: Partial<LightingEnvironmentSnapshot>): LightingEnvironmentSnapshot {
    if (this.isSunnyDayActive && this.isEditorMode) {
      return {
        sunEnergy: SUNNY_DAY_CONSTANTS.SUN_ENERGY,
        sunColor: { ...SUNNY_DAY_CONSTANTS.SUN_COLOR },
        ambientColor: { ...SUNNY_DAY_CONSTANTS.AMBIENT_COLOR },
        ambientEnergy: SUNNY_DAY_CONSTANTS.AMBIENT_ENERGY,
        fogEnabled: SUNNY_DAY_CONSTANTS.FOG_ENABLED,
        volumetricFogEnabled: SUNNY_DAY_CONSTANTS.VOLUMETRIC_FOG_ENABLED,
        particleDensity: SUNNY_DAY_CONSTANTS.PARTICLE_DENSITY,
        shadowsEnabled: SUNNY_DAY_CONSTANTS.SHADOWS_ENABLED,
        sunPitchDeg: SUNNY_DAY_CONSTANTS.OVERHEAD_PITCH_DEG
      };
    }

    const baseline = baseSectorAtmosphere || this.savedLightingState;
    return {
      sunEnergy: baseline.sunEnergy ?? DEFAULT_ENVIRONMENT_BASELINE.sunEnergy,
      sunColor: baseline.sunColor ?? DEFAULT_ENVIRONMENT_BASELINE.sunColor,
      ambientColor: baseline.ambientColor ?? DEFAULT_ENVIRONMENT_BASELINE.ambientColor,
      ambientEnergy: baseline.ambientEnergy ?? DEFAULT_ENVIRONMENT_BASELINE.ambientEnergy,
      fogEnabled: baseline.fogEnabled ?? DEFAULT_ENVIRONMENT_BASELINE.fogEnabled,
      volumetricFogEnabled: baseline.volumetricFogEnabled ?? DEFAULT_ENVIRONMENT_BASELINE.volumetricFogEnabled,
      particleDensity: baseline.particleDensity ?? DEFAULT_ENVIRONMENT_BASELINE.particleDensity,
      shadowsEnabled: baseline.shadowsEnabled ?? DEFAULT_ENVIRONMENT_BASELINE.shadowsEnabled,
      sunPitchDeg: baseline.sunPitchDeg ?? DEFAULT_ENVIRONMENT_BASELINE.sunPitchDeg
    };
  }

  public executeAction(
    action: PauseMenuAction,
    serializerFlushCallback?: () => boolean
  ): { success: boolean; action: PauseMenuAction; message: string } {
    switch (action) {
      case PauseMenuAction.RESUME:
        this.togglePause(false);
        return {
          success: true,
          action,
          message: 'JUEGO REANUDADO'
        };

      case PauseMenuAction.SAVE_WORLD:
        let savedOk = true;
        if (serializerFlushCallback) {
          savedOk = serializerFlushCallback();
        }
        this.lastSaveStatus = savedOk
          ? 'CAMBIOS GUARDADOS EN WORLD_LAYOUT_OVERRIDES.JSON'
          : 'ERROR AL GUARDAR EL MUNDO';
        return {
          success: savedOk,
          action,
          message: this.lastSaveStatus
        };

      case PauseMenuAction.SETTINGS:
        this.isSettingsOpen = !this.isSettingsOpen;
        this.isHelpOpen = false;
        return {
          success: true,
          action,
          message: this.isSettingsOpen ? 'AJUSTES ABIERTOS' : 'AJUSTES CERRADOS'
        };

      case PauseMenuAction.DEV_HELP:
        this.isHelpOpen = !this.isHelpOpen;
        this.isSettingsOpen = false;
        return {
          success: true,
          action,
          message: this.isHelpOpen ? 'GUÍA RÁPIDA VISIBLE' : 'GUÍA RÁPIDA OCULTA'
        };

      case PauseMenuAction.SUNNY_DAY_TOGGLE:
        const active = this.toggleSunnyDay();
        return {
          success: this.isEditorMode,
          action,
          message: active ? 'LUZ DE DÍA MÁXIMA ACTIVADA' : 'ATMÓSFERA ORIGINAL RESTAURADA'
        };

      case PauseMenuAction.MAIN_MENU:
        if (serializerFlushCallback && this.isEditorMode) {
          serializerFlushCallback();
        }
        this.togglePause(false);
        return {
          success: true,
          action,
          message: 'TRANSICIÓN A MENÚ PRINCIPAL'
        };

      default:
        return {
          success: false,
          action,
          message: 'ACCIÓN NO RECONOCIDA'
        };
    }
  }

  public getVisibleMenuButtons(): string[] {
    const list: string[] = [
      '[•] CONTINUAR (RESUME)',
      '[•] GUARDAR MUNDO (SAVE WORLD)'
    ];

    if (this.isEditorMode) {
      list.push(
        this.isSunnyDayActive
          ? '[L] LUZ DE DÍA MÁXIMA: [ACTIVADA]'
          : '[L] LUZ DE DÍA MÁXIMA: [DESACTIVADA]'
      );
    }

    list.push('[•] AJUSTES (SETTINGS)');
    list.push('[•] GUÍA RÁPIDA / DEV TOOLS');
    list.push('[•] MENÚ PRINCIPAL (EXIT)');
    return list;
  }
}
