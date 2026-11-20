/**
 * Normalized Input System & Action Mapping Contracts — "Dark Towers: The Path of Ka"
 * Phase 1.1: Resolution of Keybinding Collisions
 *
 * Enforces strict physical key exclusivity between weapon maintenance routines
 * and camera perspective controls, and manages contextual multi-modal actions.
 */

export type NormalizedActionName =
  | 'tactical_shoulder_swap'
  | 'clear_jam'
  | 'toggle_recon_map'
  | 'field_gunsmith_inspect'
  | 'crouch_or_center_map'
  | 'crouch'
  | 'inspect_weapon'
  | 'toggle_map'
  | 'map'
  | 'ui_map';

export type ActionCategory =
  | 'PERSPECTIVE'
  | 'WEAPON_MAINTENANCE'
  | 'TACTICAL_RECON'
  | 'INSPECTION'
  | 'LOCOMOTION';

export type InputInteractionMode =
  | 'TRIGGER_INSTANT'
  | 'HOLD_CONTINUOUS'
  | 'CONTEXTUAL_TAP_HOLD';

export type GameplayContext =
  | 'WORLD_EXPLORATION'
  | 'RECON_MAP_OPEN'
  | 'FIREARM_ENGAGEMENT';

export interface KeyRepresentation {
  symbol: string;
  godotPhysicalCode: number;
  webKeyCode?: number;
  description: string;
}

export const PHYSICAL_KEYS = {
  KEY_Q: { symbol: 'Q', godotPhysicalCode: 81, webKeyCode: 81, description: 'Q Key — Tactical Shoulder Swap' },
  KEY_V: { symbol: 'V', godotPhysicalCode: 86, webKeyCode: 86, description: 'V Key — Clear Malfunction / Jam' },
  KEY_TAB: { symbol: 'Tab', godotPhysicalCode: 4194306, webKeyCode: 9, description: 'Tab Key — Toggle Reconnaissance Chart' },
  KEY_M: { symbol: 'M', godotPhysicalCode: 77, webKeyCode: 77, description: 'M Key — Alternate Map Hotkey' },
  KEY_I: { symbol: 'I', godotPhysicalCode: 73, webKeyCode: 73, description: 'I Key — Field Gunsmith Inspection' },
  KEY_C: { symbol: 'C', godotPhysicalCode: 67, webKeyCode: 67, description: 'C Key — Crouch Locomotion / Center Map' },
  KEY_CTRL: { symbol: 'Ctrl', godotPhysicalCode: 4194326, webKeyCode: 17, description: 'Ctrl Key — Alternate Crouch' },
} as const;

export interface ActionBindingContract {
  action: NormalizedActionName;
  displayName: string;
  category: ActionCategory;
  primaryKey: KeyRepresentation;
  alternateKeys: KeyRepresentation[];
  interactionMode: InputInteractionMode;
  description: string;
  disallowedKeyCodes: number[];
}

export const NORMALIZED_ACTION_CONFIGS: Record<NormalizedActionName, ActionBindingContract> = {
  tactical_shoulder_swap: {
    action: 'tactical_shoulder_swap',
    displayName: 'Tactical Shoulder Perspective Swap',
    category: 'PERSPECTIVE',
    primaryKey: PHYSICAL_KEYS.KEY_Q,
    alternateKeys: [],
    interactionMode: 'TRIGGER_INSTANT',
    description: 'Toggles camera spring arm shoulder perspective between right and left flanks.',
    disallowedKeyCodes: [PHYSICAL_KEYS.KEY_V.godotPhysicalCode], // Strictly disallow V
  },
  clear_jam: {
    action: 'clear_jam',
    displayName: 'Clear Firearm Malfunction (Tap-Rack)',
    category: 'WEAPON_MAINTENANCE',
    primaryKey: PHYSICAL_KEYS.KEY_V,
    alternateKeys: [],
    interactionMode: 'TRIGGER_INSTANT',
    description: 'Executes manual tap-rack routine or ejector rod extraction to clear seized cartridges.',
    disallowedKeyCodes: [PHYSICAL_KEYS.KEY_Q.godotPhysicalCode], // Strictly disallow Q
  },
  toggle_recon_map: {
    action: 'toggle_recon_map',
    displayName: 'Toggle Reconnaissance Chart',
    category: 'TACTICAL_RECON',
    primaryKey: PHYSICAL_KEYS.KEY_M,
    alternateKeys: [],
    interactionMode: 'TRIGGER_INSTANT',
    description: 'Unfolds or stows the diegetic 500m x 500m topographic military reconnaissance chart.',
    disallowedKeyCodes: [PHYSICAL_KEYS.KEY_TAB.godotPhysicalCode],
  },
  field_gunsmith_inspect: {
    action: 'field_gunsmith_inspect',
    displayName: 'Field Gunsmith & Tactile Weapon Inspection',
    category: 'INSPECTION',
    primaryKey: PHYSICAL_KEYS.KEY_I,
    alternateKeys: [],
    interactionMode: 'TRIGGER_INSTANT',
    description: 'Opens detailed tactile weapon status modal reporting bore fouling, drag, and tolerances.',
    disallowedKeyCodes: [],
  },
  crouch_or_center_map: {
    action: 'crouch_or_center_map',
    displayName: 'Contextual Crouch Locomotion / Center Recon Chart',
    category: 'LOCOMOTION',
    primaryKey: PHYSICAL_KEYS.KEY_C,
    alternateKeys: [PHYSICAL_KEYS.KEY_CTRL],
    interactionMode: 'CONTEXTUAL_TAP_HOLD',
    description: 'Holding in exploration crouches player; tapping while chart is open centers map view.',
    disallowedKeyCodes: [],
  },
  crouch: {
    action: 'crouch',
    displayName: 'Crouch Locomotion (Legacy Compatibility)',
    category: 'LOCOMOTION',
    primaryKey: PHYSICAL_KEYS.KEY_CTRL,
    alternateKeys: [PHYSICAL_KEYS.KEY_C],
    interactionMode: 'HOLD_CONTINUOUS',
    description: 'Lowers Gunslinger posture to stabilize weapon sway and reduce profile.',
    disallowedKeyCodes: [],
  },
  inspect_weapon: {
    action: 'inspect_weapon',
    displayName: 'Inspect Weapon (Legacy Compatibility)',
    category: 'INSPECTION',
    primaryKey: PHYSICAL_KEYS.KEY_I,
    alternateKeys: [],
    interactionMode: 'TRIGGER_INSTANT',
    description: 'Legacy alias for weapon inspection modal.',
    disallowedKeyCodes: [],
  },
  toggle_map: {
    action: 'toggle_map',
    displayName: 'Toggle Map (Legacy Compatibility)',
    category: 'TACTICAL_RECON',
    primaryKey: PHYSICAL_KEYS.KEY_M,
    alternateKeys: [],
    interactionMode: 'TRIGGER_INSTANT',
    description: 'Legacy alias for map modal toggle.',
    disallowedKeyCodes: [PHYSICAL_KEYS.KEY_TAB.godotPhysicalCode],
  },
  map: {
    action: 'map',
    displayName: 'Map (Legacy Compatibility)',
    category: 'TACTICAL_RECON',
    primaryKey: PHYSICAL_KEYS.KEY_M,
    alternateKeys: [],
    interactionMode: 'TRIGGER_INSTANT',
    description: 'Legacy alias for map action.',
    disallowedKeyCodes: [PHYSICAL_KEYS.KEY_TAB.godotPhysicalCode],
  },
  ui_map: {
    action: 'ui_map',
    displayName: 'UI Map (Legacy Compatibility)',
    category: 'TACTICAL_RECON',
    primaryKey: PHYSICAL_KEYS.KEY_M,
    alternateKeys: [],
    interactionMode: 'TRIGGER_INSTANT',
    description: 'Legacy alias for UI map toggle.',
    disallowedKeyCodes: [PHYSICAL_KEYS.KEY_TAB.godotPhysicalCode],
  },
  toggle_editor_catalog: {
    action: 'toggle_editor_catalog',
    displayName: 'Toggle Editor Asset Catalog Grid',
    category: 'TACTICAL_RECON',
    primaryKey: PHYSICAL_KEYS.KEY_TAB,
    alternateKeys: [PHYSICAL_KEYS.KEY_B],
    interactionMode: 'TRIGGER_INSTANT',
    description: 'Opens or closes the 3D Asset Catalog Grid in Editor Mode.',
    disallowedKeyCodes: [PHYSICAL_KEYS.KEY_M.godotPhysicalCode],
  },
};

export interface ContextualResolutionResult {
  actionName: NormalizedActionName;
  triggersShoulderSwap: boolean;
  triggersJamClearing: boolean;
  triggersMapModal: boolean;
  triggersGunsmithInspect: boolean;
  locomotionPosture: 'IDLE' | 'CROUCHING' | 'UNCHANGED';
  mapAction: 'NONE' | 'CENTER_ON_PLAYER' | 'CLOSE_MAP';
  effectiveMode: InputInteractionMode;
}

export class InputNormalizationRegistry {
  public static getBinding(action: NormalizedActionName): ActionBindingContract {
    return NORMALIZED_ACTION_CONFIGS[action];
  }

  public static getAllBindings(): ActionBindingContract[] {
    return Object.values(NORMALIZED_ACTION_CONFIGS);
  }

  public static hasCollision(actionA: NormalizedActionName, actionB: NormalizedActionName): boolean {
    const bindA = this.getBinding(actionA);
    const bindB = this.getBinding(actionB);
    if (!bindA || !bindB) return false;

    const keysA = [bindA.primaryKey.godotPhysicalCode, ...bindA.alternateKeys.map(k => k.godotPhysicalCode)];
    const keysB = [bindB.primaryKey.godotPhysicalCode, ...bindB.alternateKeys.map(k => k.godotPhysicalCode)];

    return keysA.some(code => keysB.includes(code));
  }

  public static validatePhysicalExclusivity(): {
    clearJamExclusivelyV: boolean;
    shoulderSwapExclusivelyQ: boolean;
    isCollisionFree: boolean;
  } {
    const shoulder = this.getBinding('tactical_shoulder_swap');
    const jam = this.getBinding('clear_jam');

    const shoulderCodes = [shoulder.primaryKey.godotPhysicalCode, ...shoulder.alternateKeys.map(k => k.godotPhysicalCode)];
    const jamCodes = [jam.primaryKey.godotPhysicalCode, ...jam.alternateKeys.map(k => k.godotPhysicalCode)];

    const clearJamExclusivelyV = jamCodes.length === 1 && jamCodes[0] === PHYSICAL_KEYS.KEY_V.godotPhysicalCode;
    const shoulderSwapExclusivelyQ = shoulderCodes.length === 1 && shoulderCodes[0] === PHYSICAL_KEYS.KEY_Q.godotPhysicalCode;
    const isCollisionFree = !this.hasCollision('tactical_shoulder_swap', 'clear_jam');

    return {
      clearJamExclusivelyV,
      shoulderSwapExclusivelyQ,
      isCollisionFree,
    };
  }

  public static resolveContextualInput(
    inputSymbolOrCode: string | number,
    context: GameplayContext
  ): ContextualResolutionResult | null {
    const code = typeof inputSymbolOrCode === 'number'
      ? inputSymbolOrCode
      : this.symbolToCode(inputSymbolOrCode);

    if (code === PHYSICAL_KEYS.KEY_Q.godotPhysicalCode) {
      return {
        actionName: 'tactical_shoulder_swap',
        triggersShoulderSwap: true,
        triggersJamClearing: false,
        triggersMapModal: false,
        triggersGunsmithInspect: false,
        locomotionPosture: 'UNCHANGED',
        mapAction: 'NONE',
        effectiveMode: 'TRIGGER_INSTANT',
      };
    }

    if (code === PHYSICAL_KEYS.KEY_V.godotPhysicalCode) {
      return {
        actionName: 'clear_jam',
        triggersShoulderSwap: false,
        triggersJamClearing: true,
        triggersMapModal: false,
        triggersGunsmithInspect: false,
        locomotionPosture: 'UNCHANGED',
        mapAction: 'NONE',
        effectiveMode: 'TRIGGER_INSTANT',
      };
    }

    if (code === PHYSICAL_KEYS.KEY_M.godotPhysicalCode) {
      return {
        actionName: 'toggle_recon_map',
        triggersShoulderSwap: false,
        triggersJamClearing: false,
        triggersMapModal: true,
        triggersGunsmithInspect: false,
        locomotionPosture: 'UNCHANGED',
        mapAction: context === 'RECON_MAP_OPEN' ? 'CLOSE_MAP' : 'NONE',
        effectiveMode: 'TRIGGER_INSTANT',
      };
    }

    if (code === PHYSICAL_KEYS.KEY_TAB.godotPhysicalCode) {
      return {
        actionName: 'toggle_editor_catalog',
        triggersShoulderSwap: false,
        triggersJamClearing: false,
        triggersMapModal: false,
        triggersGunsmithInspect: false,
        locomotionPosture: 'UNCHANGED',
        mapAction: 'NONE',
        effectiveMode: 'TRIGGER_INSTANT',
      };
    }

    if (code === PHYSICAL_KEYS.KEY_I.godotPhysicalCode) {
      return {
        actionName: 'field_gunsmith_inspect',
        triggersShoulderSwap: false,
        triggersJamClearing: false,
        triggersMapModal: false,
        triggersGunsmithInspect: true,
        locomotionPosture: 'UNCHANGED',
        mapAction: 'NONE',
        effectiveMode: 'TRIGGER_INSTANT',
      };
    }

    if (code === PHYSICAL_KEYS.KEY_C.godotPhysicalCode) {
      if (context === 'RECON_MAP_OPEN') {
        return {
          actionName: 'crouch_or_center_map',
          triggersShoulderSwap: false,
          triggersJamClearing: false,
          triggersMapModal: false,
          triggersGunsmithInspect: false,
          locomotionPosture: 'UNCHANGED',
          mapAction: 'CENTER_ON_PLAYER',
          effectiveMode: 'TRIGGER_INSTANT',
        };
      } else {
        return {
          actionName: 'crouch_or_center_map',
          triggersShoulderSwap: false,
          triggersJamClearing: false,
          triggersMapModal: false,
          triggersGunsmithInspect: false,
          locomotionPosture: 'CROUCHING',
          mapAction: 'NONE',
          effectiveMode: 'HOLD_CONTINUOUS',
        };
      }
    }

    return null;
  }

  private static symbolToCode(symbol: string): number {
    const s = symbol.trim().toUpperCase();
    if (s === 'Q') return PHYSICAL_KEYS.KEY_Q.godotPhysicalCode;
    if (s === 'V') return PHYSICAL_KEYS.KEY_V.godotPhysicalCode;
    if (s === 'TAB') return PHYSICAL_KEYS.KEY_TAB.godotPhysicalCode;
    if (s === 'M') return PHYSICAL_KEYS.KEY_M.godotPhysicalCode;
    if (s === 'I') return PHYSICAL_KEYS.KEY_I.godotPhysicalCode;
    if (s === 'C') return PHYSICAL_KEYS.KEY_C.godotPhysicalCode;
    if (s === 'CTRL') return PHYSICAL_KEYS.KEY_CTRL.godotPhysicalCode;
    return -1;
  }
}

