/**
 * Dark Towers: The Path of Ka
 * Editor Mode UI & Input Isolation Domain (Phase 7 - Architecture & Verification)
 *
 * Models deterministic mode separation between Survival Mode and Editor Flight Mode.
 * Ensures complete deactivation of the survival HUD, weapon cylinder bar, crosshair,
 * and player physics/viewmodel when WorldSaveData.is_editor_active() is true,
 * and validates full handoff to 6DoF Flight Controller and Editor Palette HUD.
 */

export interface SurvivalHUDComponents {
  topCenterVitals: boolean;
  weaponConsole: boolean;
  crosshair: boolean;
  conditionStack: boolean;
  upperLeftBanner: boolean;
  tacticalRadar: boolean;
  jamBanner: boolean;
  inspectionModal: boolean;
}

export interface EditorHUDComponents {
  overlayVisible: boolean;
  paletteDrawerVisible: boolean;
  outlinerVisible: boolean;
}

export interface PlayerPhysicsHandoff {
  collisionEnabled: boolean;
  meshVisualsVisible: boolean;
  weaponViewmodelVisible: boolean;
  physicsProcessEnabled: boolean;
  cameraSpringLength: number;
  cameraOffset: { x: number; y: number; z: number };
  cameraCurrent: boolean;
  isFrozen: boolean;
  inputProcessEnabled: boolean;
}

export interface FlightControllerHandoff {
  flightActive: boolean;
  mouseLookPriority: 'flight' | 'player';
  paletteInputEnabled: boolean;
  cameraAuthority: boolean;
  physicsProcessEnabled: boolean;
  driftVelocityZeroed: boolean;
}

export interface EditorModeIsolationState {
  isEditorActive: boolean;
  survivalHUD: SurvivalHUDComponents;
  editorHUD: EditorHUDComponents;
  playerPhysics: PlayerPhysicsHandoff;
  flightController: FlightControllerHandoff;
}

// ─── Constants ──────────────────────────────────────────────────────────────

export const SURVIVAL_CAMERA_SPRING_LENGTH = 3.0;
export const EDITOR_CAMERA_SPRING_LENGTH = 0.0;

export const SURVIVAL_CAMERA_OFFSET_RIGHT = { x: 0.75, y: 0.0, z: 0.0 };
export const SURVIVAL_CAMERA_OFFSET_LEFT = { x: -0.75, y: 0.0, z: 0.0 };
export const EDITOR_CAMERA_OFFSET_CENTER = { x: 0.0, y: 0.0, z: 0.0 };

// ─── Pure State Resolvers ───────────────────────────────────────────────────

export function resolveSurvivalHUDVisibility(isEditorActive: boolean): SurvivalHUDComponents {
  if (isEditorActive) {
    return {
      topCenterVitals: false,
      weaponConsole: false,
      crosshair: false,
      conditionStack: false,
      upperLeftBanner: false,
      tacticalRadar: false,
      jamBanner: false,
      inspectionModal: false
    };
  }

  return {
    topCenterVitals: true,
    weaponConsole: true,
    crosshair: true,
    conditionStack: true,
    upperLeftBanner: true,
    tacticalRadar: true,
    jamBanner: false, // In survival, jam banner visibility is dynamic based on weapon state
    inspectionModal: false
  };
}

export function resolveEditorHUDVisibility(
  isEditorActive: boolean,
  paletteOpen: boolean = false,
  outlinerOpen: boolean = false
): EditorHUDComponents {
  return {
    overlayVisible: isEditorActive,
    paletteDrawerVisible: isEditorActive && paletteOpen,
    outlinerVisible: isEditorActive && outlinerOpen
  };
}

export function resolvePlayerPhysicsHandoff(
  isEditorActive: boolean,
  isRightShoulder: boolean = true
): PlayerPhysicsHandoff {
  if (isEditorActive) {
    return {
      collisionEnabled: false,
      meshVisualsVisible: false,
      weaponViewmodelVisible: false,
      physicsProcessEnabled: false,
      cameraSpringLength: EDITOR_CAMERA_SPRING_LENGTH,
      cameraOffset: { ...EDITOR_CAMERA_OFFSET_CENTER },
      cameraCurrent: false,
      isFrozen: true,
      inputProcessEnabled: false
    };
  }

  return {
    collisionEnabled: true,
    meshVisualsVisible: true,
    weaponViewmodelVisible: true,
    physicsProcessEnabled: true,
    cameraSpringLength: SURVIVAL_CAMERA_SPRING_LENGTH,
    cameraOffset: isRightShoulder
      ? { ...SURVIVAL_CAMERA_OFFSET_RIGHT }
      : { ...SURVIVAL_CAMERA_OFFSET_LEFT },
    cameraCurrent: true,
    isFrozen: false,
    inputProcessEnabled: true
  };
}

export function resolveFlightControllerHandoff(isEditorActive: boolean): FlightControllerHandoff {
  return {
    flightActive: isEditorActive,
    mouseLookPriority: isEditorActive ? 'flight' : 'player',
    paletteInputEnabled: isEditorActive,
    cameraAuthority: isEditorActive,
    physicsProcessEnabled: isEditorActive,
    driftVelocityZeroed: !isEditorActive
  };
}

export function createInitialIsolationState(startInEditor: boolean = false): EditorModeIsolationState {
  return {
    isEditorActive: startInEditor,
    survivalHUD: resolveSurvivalHUDVisibility(startInEditor),
    editorHUD: resolveEditorHUDVisibility(startInEditor),
    playerPhysics: resolvePlayerPhysicsHandoff(startInEditor),
    flightController: resolveFlightControllerHandoff(startInEditor)
  };
}

export function transitionIsolationMode(
  currentState: EditorModeIsolationState,
  targetEditorActive: boolean
): EditorModeIsolationState {
  return {
    isEditorActive: targetEditorActive,
    survivalHUD: resolveSurvivalHUDVisibility(targetEditorActive),
    editorHUD: resolveEditorHUDVisibility(
      targetEditorActive,
      targetEditorActive ? currentState.editorHUD.paletteDrawerVisible : false,
      targetEditorActive ? currentState.editorHUD.outlinerVisible : false
    ),
    playerPhysics: resolvePlayerPhysicsHandoff(targetEditorActive),
    flightController: resolveFlightControllerHandoff(targetEditorActive)
  };
}

// ─── Invariant Validation ───────────────────────────────────────────────────

export interface InvariantValidationResult {
  isValid: boolean;
  violations: string[];
}

export function validateIsolationInvariants(state: EditorModeIsolationState): InvariantValidationResult {
  const violations: string[] = [];

  if (state.isEditorActive) {
    // In Editor Mode:
    if (state.survivalHUD.topCenterVitals) {
      violations.push('Survival topCenterVitals must be hidden when editor mode is active');
    }
    if (state.survivalHUD.weaponConsole) {
      violations.push('Survival weaponConsole must be hidden when editor mode is active');
    }
    if (state.survivalHUD.crosshair) {
      violations.push('Survival crosshair must be hidden when editor mode is active');
    }
    if (state.survivalHUD.upperLeftBanner) {
      violations.push('Survival upperLeftBanner must be hidden when editor mode is active');
    }
    if (state.survivalHUD.conditionStack) {
      violations.push('Survival conditionStack must be hidden when editor mode is active');
    }
    if (state.playerPhysics.collisionEnabled) {
      violations.push('Player collisionShape must be disabled when editor mode is active');
    }
    if (state.playerPhysics.meshVisualsVisible) {
      violations.push('Player mesh visuals must be hidden when editor mode is active');
    }
    if (state.playerPhysics.weaponViewmodelVisible) {
      violations.push('Player weapon viewmodel must be hidden when editor mode is active');
    }
    if (state.playerPhysics.physicsProcessEnabled) {
      violations.push('Player physics_process must be suspended when editor mode is active');
    }
    if (state.playerPhysics.cameraSpringLength !== EDITOR_CAMERA_SPRING_LENGTH) {
      violations.push('Camera springLength must be 0.0 to prevent 3rd-person clipping in flight');
    }
    if (!state.editorHUD.overlayVisible) {
      violations.push('EditorHUDOverlay must be visible when editor mode is active');
    }
    if (!state.playerPhysics.isFrozen) {
      violations.push('Player must be frozen when editor mode is active');
    }
    if (state.playerPhysics.inputProcessEnabled) {
      violations.push('Player input processing must be disabled when editor mode is active');
    }
    if (!state.flightController.flightActive) {
      violations.push('EditorFlightController must be active when editor mode is active');
    }
    if (!state.flightController.cameraAuthority) {
      violations.push('Flight controller must have camera authority in editor mode');
    }
    if (!state.flightController.physicsProcessEnabled) {
      violations.push('Flight controller physics must be enabled in editor mode');
    }
    if (state.flightController.mouseLookPriority !== 'flight') {
      violations.push('Flight controller must have mouse look priority in editor mode');
    }
  } else {
    // In Survival Mode:
    if (!state.survivalHUD.topCenterVitals) {
      violations.push('Survival topCenterVitals must be visible in survival mode');
    }
    if (!state.survivalHUD.weaponConsole) {
      violations.push('Survival weaponConsole must be visible in survival mode');
    }
    if (!state.survivalHUD.crosshair) {
      violations.push('Survival crosshair must be visible in survival mode');
    }
    if (!state.playerPhysics.collisionEnabled) {
      violations.push('Player collisionShape must be enabled in survival mode');
    }
    if (!state.playerPhysics.meshVisualsVisible) {
      violations.push('Player mesh visuals must be visible in survival mode');
    }
    if (!state.playerPhysics.physicsProcessEnabled) {
      violations.push('Player physics_process must be active in survival mode');
    }
    if (state.playerPhysics.isFrozen) {
      violations.push('Player must not be frozen in survival mode');
    }
    if (!state.playerPhysics.cameraCurrent) {
      violations.push('Player camera must be current in survival mode');
    }
    if (!state.playerPhysics.inputProcessEnabled) {
      violations.push('Player input processing must be enabled in survival mode');
    }
    if (state.playerPhysics.cameraSpringLength <= 0.0) {
      violations.push('Camera springLength must be > 0.0 in OTS survival mode');
    }
    if (state.editorHUD.overlayVisible) {
      violations.push('EditorHUDOverlay must be hidden in survival mode');
    }
    if (state.flightController.flightActive) {
      violations.push('EditorFlightController must be deactivated in survival mode');
    }
    if (state.flightController.cameraAuthority) {
      violations.push('Flight controller must yield camera authority in survival mode');
    }
    if (state.flightController.physicsProcessEnabled) {
      violations.push('Flight controller physics must be disabled in survival mode');
    }
    if (!state.flightController.driftVelocityZeroed) {
      violations.push('Flight controller drift velocity must be zeroed upon exit');
    }
    if (state.flightController.mouseLookPriority !== 'player') {
      violations.push('Player character must have mouse look priority in survival mode');
    }
  }

  return {
    isValid: violations.length === 0,
    violations
  };
}

