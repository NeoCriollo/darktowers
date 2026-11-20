/**
 * Dark Towers: The Path of Ka
 * ─────────────────────────────────────────────────────────────────────────────
 * World Editor Mode Input Routing & Exclusivity Domain Contract (Phase 7 & 8)
 *
 * Strict Architectural Invariant:
 * 1. The Reconnaissance Map is bound EXCLUSIVELY to physical key [M] (keycode 77).
 *    [TAB] (keycode 4194306) must NEVER open, toggle, or close the Recon Map.
 * 2. The Editor Asset Catalog Grid is bound to [TAB] (and alternate [B])
 *    EXCLUSIVELY when in Editor Mode (Modo Arquitecto).
 * 3. In Editor Mode, the map modal trigger is completely blocked from hijacking
 *    flight camera movement or intercepting [TAB].
 * 4. EditorFlightController enforces immediate mouse capture (MOUSE_MODE_CAPTURED)
 *    and 6DoF flight processing without requiring an initial mouse click.
 * ─────────────────────────────────────────────────────────────────────────────
 */

export const PHYSICAL_KEYCODES = {
  KEY_ESCAPE: 4194305,
  KEY_TAB: 4194306,
  KEY_M: 77,
  KEY_B: 66,
  KEY_P: 80,
  KEY_F6: 4194337,
  KEY_C: 67,
  KEY_I: 73,
  KEY_V: 86,
  KEY_Q: 81,
} as const;

export type InputContextMode =
  | 'SURVIVAL_WORLD'
  | 'SURVIVAL_MAP_OPEN'
  | 'EDITOR_FLIGHT'
  | 'EDITOR_CATALOG_OPEN'
  | 'EDITOR_OUTLINER_OPEN';

export type RoutedActionName =
  | 'toggle_recon_map'
  | 'toggle_editor_catalog'
  | 'toggle_editor_mode'
  | 'toggle_editor_outliner'
  | 'close_current_modal'
  | 'unhandled';

export type TargetSubsystem =
  | 'MAP_MODAL'
  | 'EDITOR_ASSET_CATALOG'
  | 'EDITOR_OUTLINER'
  | 'EDITOR_FLIGHT_CONTROLLER'
  | 'SURVIVAL_PLAYER'
  | 'NONE';

export interface InputRoutingDecision {
  action: RoutedActionName;
  targetSubsystem: TargetSubsystem;
  consumed: boolean;
  mouseCaptureDesired: boolean;
  blocksReconMap: boolean;
  rationale: string;
}

export interface KeyExclusivityReport {
  isExclusivelyPartitioned: boolean;
  reconMapKeyCode: number;
  editorCatalogKeyCode: number;
  hasCollision: boolean;
  violations: string[];
}

export interface GodotProjectInputAudit {
  isCompliant: boolean;
  reconMapHasOnlyM: boolean;
  catalogHasTab: boolean;
  noTabInMapActions: boolean;
  errors: string[];
}

export class EditorInputRoutingContract {
  /**
   * Resolves physical keyboard event through the input routing pipeline.
   * Guarantees zero crosstalk between reconnaissance map and asset catalog.
   */
  public static routeKeyInput(
    keyCode: number,
    context: InputContextMode
  ): InputRoutingDecision {
    // 1. [M] Key Routing (Physical 77)
    if (keyCode === PHYSICAL_KEYCODES.KEY_M) {
      if (context === 'SURVIVAL_WORLD') {
        return {
          action: 'toggle_recon_map',
          targetSubsystem: 'MAP_MODAL',
          consumed: true,
          mouseCaptureDesired: false,
          blocksReconMap: false,
          rationale: 'Physical [M] in Survival World opens Reconnaissance Map.',
        };
      }
      if (context === 'SURVIVAL_MAP_OPEN') {
        return {
          action: 'toggle_recon_map',
          targetSubsystem: 'MAP_MODAL',
          consumed: true,
          mouseCaptureDesired: true,
          blocksReconMap: false,
          rationale: 'Physical [M] with Recon Map open closes the map and restores capture.',
        };
      }
      if (
        context === 'EDITOR_FLIGHT' ||
        context === 'EDITOR_CATALOG_OPEN' ||
        context === 'EDITOR_OUTLINER_OPEN'
      ) {
        return {
          action: 'unhandled',
          targetSubsystem: 'NONE',
          consumed: false,
          mouseCaptureDesired: true,
          blocksReconMap: true,
          rationale: 'Reconnaissance Map is suppressed in Editor Mode.',
        };
      }
    }

    // 2. [TAB] Key Routing (Physical 4194306)
    if (keyCode === PHYSICAL_KEYCODES.KEY_TAB) {
      if (context === 'EDITOR_FLIGHT') {
        return {
          action: 'toggle_editor_catalog',
          targetSubsystem: 'EDITOR_ASSET_CATALOG',
          consumed: true,
          mouseCaptureDesired: false,
          blocksReconMap: true,
          rationale: 'Physical [TAB] in Editor Mode opens Asset Catalog Grid.',
        };
      }
      if (context === 'EDITOR_CATALOG_OPEN') {
        return {
          action: 'toggle_editor_catalog',
          targetSubsystem: 'EDITOR_ASSET_CATALOG',
          consumed: true,
          mouseCaptureDesired: true,
          blocksReconMap: true,
          rationale: 'Physical [TAB] with Asset Catalog open closes catalog and restores flight capture.',
        };
      }
      if (context === 'SURVIVAL_WORLD' || context === 'SURVIVAL_MAP_OPEN') {
        return {
          action: 'unhandled',
          targetSubsystem: 'NONE',
          consumed: false,
          mouseCaptureDesired: true,
          blocksReconMap: false,
          rationale: 'Physical [TAB] is prohibited from triggering Recon Map in Survival Mode.',
        };
      }
    }

    // 3. [B] Alternate Catalog Key Routing (Physical 66)
    if (keyCode === PHYSICAL_KEYCODES.KEY_B) {
      if (context === 'EDITOR_FLIGHT' || context === 'EDITOR_CATALOG_OPEN') {
        return {
          action: 'toggle_editor_catalog',
          targetSubsystem: 'EDITOR_ASSET_CATALOG',
          consumed: true,
          mouseCaptureDesired: context === 'EDITOR_CATALOG_OPEN',
          blocksReconMap: true,
          rationale: 'Physical [B] functions as alternate toggle for Editor Asset Catalog.',
        };
      }
    }

    // 4. [F6] Editor Mode Toggle (Physical 4194337)
    if (keyCode === PHYSICAL_KEYCODES.KEY_F6) {
      const enteringEditor = context.startsWith('SURVIVAL');
      return {
        action: 'toggle_editor_mode',
        targetSubsystem: 'EDITOR_FLIGHT_CONTROLLER',
        consumed: true,
        mouseCaptureDesired: enteringEditor,
        blocksReconMap: enteringEditor,
        rationale: enteringEditor
          ? 'Entering Editor Mode captures mouse and engages 6DoF flight.'
          : 'Exiting Editor Mode restores player survival controls.',
      };
    }

    // 5. [ESCAPE] Universal Dismissal (Physical 4194305)
    if (keyCode === PHYSICAL_KEYCODES.KEY_ESCAPE) {
      if (context === 'EDITOR_CATALOG_OPEN') {
        return {
          action: 'close_current_modal',
          targetSubsystem: 'EDITOR_ASSET_CATALOG',
          consumed: true,
          mouseCaptureDesired: true,
          blocksReconMap: true,
          rationale: 'Escape closes Editor Asset Catalog and returns to flight capture.',
        };
      }
      if (context === 'SURVIVAL_MAP_OPEN') {
        return {
          action: 'close_current_modal',
          targetSubsystem: 'MAP_MODAL',
          consumed: true,
          mouseCaptureDesired: true,
          blocksReconMap: false,
          rationale: 'Escape closes Recon Map and restores player look capture.',
        };
      }
    }

    return {
      action: 'unhandled',
      targetSubsystem: 'NONE',
      consumed: false,
      mouseCaptureDesired: context === 'EDITOR_FLIGHT' || context === 'SURVIVAL_WORLD',
      blocksReconMap: false,
      rationale: 'Key not mapped to modal or mode swap pipelines.',
    };
  }

  /**
   * Verifies that the map key and editor catalog key are strictly non-overlapping.
   */
  public static verifyKeyPartitionExclusivity(): KeyExclusivityReport {
    const violations: string[] = [];
    const mapKey = PHYSICAL_KEYCODES.KEY_M;
    const catalogKey = PHYSICAL_KEYCODES.KEY_TAB;

    if (mapKey === catalogKey) {
      violations.push('Recon Map and Editor Catalog share the identical physical key code!');
    }

    if (mapKey !== 77) {
      violations.push(`Recon Map key must be physical 77 (M), received ${mapKey}`);
    }

    if (catalogKey !== 4194306) {
      violations.push(`Editor Catalog key must be physical 4194306 (Tab), received ${catalogKey}`);
    }

    return {
      isExclusivelyPartitioned: violations.length === 0,
      reconMapKeyCode: mapKey,
      editorCatalogKeyCode: catalogKey,
      hasCollision: mapKey === catalogKey,
      violations,
    };
  }

  /**
   * Evaluates if mouse capture should be active immediately upon entering flight.
   */
  public static shouldCaptureMouseImmediately(isEditorActive: boolean, isCatalogOpen: boolean): boolean {
    if (!isEditorActive) return false;
    return !isCatalogOpen;
  }

  /**
   * Audits Godot project.godot text content to ensure strict input map hygiene.
   */
  public static auditProjectGodotContent(content: string): GodotProjectInputAudit {
    const errors: string[] = [];

    // Verify toggle_recon_map
    const reconMatch = content.match(/toggle_recon_map=\{[\s\S]*?"events":\s*\[([\s\S]*?)\]\s*\}/);
    let reconMapHasOnlyM = false;
    if (!reconMatch) {
      errors.push('project.godot is missing toggle_recon_map action definition');
    } else {
      const events = reconMatch[1];
      const hasM = events.includes('"physical_keycode":77');
      const hasTab = events.includes('"physical_keycode":4194306');
      if (!hasM) errors.push('toggle_recon_map missing physical_keycode:77 (M)');
      if (hasTab) errors.push('toggle_recon_map must NOT contain physical_keycode:4194306 (Tab)');
      reconMapHasOnlyM = hasM && !hasTab;
    }

    // Verify toggle_editor_catalog
    const catalogMatch = content.match(/toggle_editor_catalog=\{[\s\S]*?"events":\s*\[([\s\S]*?)\]\s*\}/);
    let catalogHasTab = false;
    if (!catalogMatch) {
      errors.push('project.godot is missing toggle_editor_catalog action definition');
    } else {
      const events = catalogMatch[1];
      const hasTab = events.includes('"physical_keycode":4194306');
      const hasM = events.includes('"physical_keycode":77');
      if (!hasTab) errors.push('toggle_editor_catalog missing physical_keycode:4194306 (Tab)');
      if (hasM) errors.push('toggle_editor_catalog must NOT contain physical_keycode:77 (M)');
      catalogHasTab = hasTab && !hasM;
    }

    // Verify map legacy actions do not bind Tab
    const legacyActions = ['toggle_map', 'map', 'ui_map'];
    let noTabInMapActions = true;
    for (const legacy of legacyActions) {
      const pattern = new RegExp(`${legacy}=\\{[\\s\\S]*?"events":\\s*\\[([\\s\\S]*?)\\]\\s*\\}`);
      const match = content.match(pattern);
      if (match && match[1].includes('"physical_keycode":4194306')) {
        errors.push(`Legacy action ${legacy} contains physical_keycode:4194306 (Tab)`);
        noTabInMapActions = false;
      }
    }

    return {
      isCompliant: errors.length === 0,
      reconMapHasOnlyM,
      catalogHasTab,
      noTabInMapActions,
      errors,
    };
  }
}

