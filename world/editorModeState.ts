/**
 * Editor Mode & Locomotion State Machine Domain Contracts — "Dark Towers: The Path of Ka"
 * Task 1 & 2: State Machine Isolation, Input Routing & Persistence Parity
 *
 * Enforces strict mutual exclusivity between standard gameplay walking controls (WALK)
 * and Todash 6DoF flight mode (EDITOR_FLIGHT), preventing input bleed, ground gravity
 * interference, and modal key collisions across scene reloads.
 */

export type GameMode = 'WALK' | 'EDITOR_FLIGHT';

export type InputAction =
  // Locomotion & Survival
  | 'move_ground'
  | 'sprint'
  | 'crouch'
  | 'jump'
  | 'stamina_drain'
  | 'ground_snapping'
  | 'gravity_fall'
  // Gunsmith & Combat
  | 'fire'
  | 'aim'
  | 'reload'
  | 'clear_jam'
  | 'cock_hammer'
  | 'tactical_shoulder_swap'
  | 'field_gunsmith_inspect'
  // Modals & Navigation
  | 'toggle_recon_map'
  | 'pause_menu'
  // Dedicated Mode Switch
  | 'toggle_editor_mode'
  // Editor Flight & Halo-Forge Controls
  | 'flight_6dof'
  | 'speed_scaling_wheel'
  | 'speed_fast_shift'
  | 'speed_crawl_alt'
  | 'raycast_hover_and_select'
  | 'manipulator_grab_and_carry'
  | 'toggle_palette'
  | 'toggle_outliner'
  | 'save_world_layout'
  | 'teleport_sector_hub';

export interface ModeCapabilities {
  readonly gravityEnabled: boolean;
  readonly groundSnappingEnabled: boolean;
  readonly slopeSlidingEnabled: boolean;
  readonly playerColliderEnabled: boolean;
  readonly playerVisualsVisible: boolean;
  readonly flight6DoFEnabled: boolean;
  readonly raycastSelectionEnabled: boolean;
  readonly assetCatalogAccessible: boolean;
  readonly reconMapAccessible: boolean;
  readonly weaponMechanicsEnabled: boolean;
  readonly survivalHandicapsActive: boolean;
  readonly hudType: 'GAMEPLAY_HUD' | 'EDITOR_HUD';
}

export const MODE_CAPABILITIES: Record<GameMode, ModeCapabilities> = {
  WALK: {
    gravityEnabled: true,
    groundSnappingEnabled: true,
    slopeSlidingEnabled: true,
    playerColliderEnabled: true,
    playerVisualsVisible: true,
    flight6DoFEnabled: false,
    raycastSelectionEnabled: false,
    assetCatalogAccessible: false,
    reconMapAccessible: true,
    weaponMechanicsEnabled: true,
    survivalHandicapsActive: true,
    hudType: 'GAMEPLAY_HUD',
  },
  EDITOR_FLIGHT: {
    gravityEnabled: false,
    groundSnappingEnabled: false,
    slopeSlidingEnabled: false,
    playerColliderEnabled: false,
    playerVisualsVisible: false,
    flight6DoFEnabled: true,
    raycastSelectionEnabled: true,
    assetCatalogAccessible: true,
    reconMapAccessible: false,
    weaponMechanicsEnabled: false,
    survivalHandicapsActive: false,
    hudType: 'EDITOR_HUD',
  },
};

export const DEDICATED_EDITOR_MODE_KEY = {
  actionName: 'toggle_editor_mode',
  primaryPhysicalKey: 'F6',
  godotPhysicalCode: 4194337,
  description: 'F6 Key — Dedicated Mode Switch between Walk and Editor Flight',
} as const;

export interface EditorModePersistenceRecord {
  is_editor_mode_active: boolean;
  timestamp: number;
  last_sector: string;
}

/**
 * State machine managing the active game mode and routing inputs.
 */
export class EditorModeStateMachine {
  private _mode: GameMode;
  private _speedMultiplier: number = 1.0;
  private _lastSector: string = 'waystation_sanctuary';

  constructor(initialMode: GameMode = 'WALK') {
    this._mode = initialMode;
  }

  public get currentMode(): GameMode {
    return this._mode;
  }

  public isEditorActive(): boolean {
    return this._mode === 'EDITOR_FLIGHT';
  }

  public isWalkActive(): boolean {
    return this._mode === 'WALK';
  }

  public setMode(mode: GameMode): void {
    this._mode = mode;
  }

  public toggleMode(): GameMode {
    this._mode = this._mode === 'WALK' ? 'EDITOR_FLIGHT' : 'WALK';
    return this._mode;
  }

  public get capabilities(): ModeCapabilities {
    return MODE_CAPABILITIES[this._mode];
  }

  /**
   * Evaluates if a given input action is permitted under the active state.
   */
  public isActionAllowed(action: InputAction): boolean {
    // Mode switch and pause menu are universally available
    if (action === 'toggle_editor_mode' || action === 'pause_menu') {
      return true;
    }

    if (this._mode === 'WALK') {
      switch (action) {
        case 'move_ground':
        case 'sprint':
        case 'crouch':
        case 'jump':
        case 'stamina_drain':
        case 'ground_snapping':
        case 'gravity_fall':
        case 'fire':
        case 'aim':
        case 'reload':
        case 'clear_jam':
        case 'cock_hammer':
        case 'tactical_shoulder_swap':
        case 'field_gunsmith_inspect':
        case 'toggle_recon_map':
          return true;
        case 'flight_6dof':
        case 'speed_scaling_wheel':
        case 'speed_fast_shift':
        case 'speed_crawl_alt':
        case 'raycast_hover_and_select':
        case 'manipulator_grab_and_carry':
        case 'toggle_palette':
        case 'toggle_outliner':
        case 'save_world_layout':
        case 'teleport_sector_hub':
          return false;
      }
    }

    if (this._mode === 'EDITOR_FLIGHT') {
      switch (action) {
        case 'flight_6dof':
        case 'speed_scaling_wheel':
        case 'speed_fast_shift':
        case 'speed_crawl_alt':
        case 'raycast_hover_and_select':
        case 'manipulator_grab_and_carry':
        case 'toggle_palette':
        case 'toggle_outliner':
        case 'save_world_layout':
        case 'teleport_sector_hub':
          return true;
        case 'move_ground':
        case 'sprint':
        case 'crouch':
        case 'jump':
        case 'stamina_drain':
        case 'ground_snapping':
        case 'gravity_fall':
        case 'fire':
        case 'aim':
        case 'reload':
        case 'clear_jam':
        case 'cock_hammer':
        case 'tactical_shoulder_swap':
        case 'field_gunsmith_inspect':
        case 'toggle_recon_map':
          return false;
      }
    }

    return false;
  }

  /**
   * Resolves the contextual meaning of the [TAB] key based on current mode.
   * - In WALK: Opens/Closes the Topographic Reconnaissance Map.
   * - In EDITOR_FLIGHT: Opens/Closes the Asset Catalog Palette HUD.
   */
  public resolveTabKeyBehavior(): 'TOGGLE_RECON_MAP' | 'TOGGLE_PALETTE' {
    return this._mode === 'EDITOR_FLIGHT' ? 'TOGGLE_PALETTE' : 'TOGGLE_RECON_MAP';
  }

  /**
   * Resolves the contextual meaning of the [V] key.
   * Following Phase 1.1 normalization, [V] is exclusively firearm jam clearance.
   * Mode switching is routed to [F6] / dedicated mode switch.
   */
  public resolveVKeyBehavior(): 'CLEAR_JAM' | 'IGNORED' {
    return this._mode === 'WALK' ? 'CLEAR_JAM' : 'IGNORED';
  }

  /**
   * Resolves the dedicated mode toggle key [F6].
   */
  public resolveF6KeyBehavior(): 'TOGGLE_EDITOR_MODE' {
    return 'TOGGLE_EDITOR_MODE';
  }

  /**
   * Serializes the game mode state for disk persistence.
   */
  public serializeToConfig(): Record<string, Record<string, any>> {
    return {
      game_mode: {
        is_editor_mode_active: this.isEditorActive(),
      },
      journey: {
        sector: this._lastSector,
        speed_multiplier: this._speedMultiplier,
      },
    };
  }

  /**
   * Restores the game mode state from parsed configuration sections.
   */
  public deserializeFromConfig(cfg: Record<string, Record<string, any>>): void {
    if (cfg.game_mode && typeof cfg.game_mode.is_editor_mode_active === 'boolean') {
      this._mode = cfg.game_mode.is_editor_mode_active ? 'EDITOR_FLIGHT' : 'WALK';
    }
    if (cfg.journey && typeof cfg.journey.speed_multiplier === 'number') {
      this._speedMultiplier = cfg.journey.speed_multiplier;
    }
    if (cfg.journey && typeof cfg.journey.sector === 'string') {
      this._lastSector = cfg.journey.sector;
    }
  }

  public get speedMultiplier(): number {
    return this._speedMultiplier;
  }

  public setSpeedMultiplier(mult: number): void {
    this._speedMultiplier = Math.max(0.2, Math.min(5.0, mult));
  }
}

