# Dark Towers — Architecture & Engineering Rules

Permanent architectural, organizational, and design rules for all agent and developer sessions.

---

## 1. Strict File Granularity & Anti-Monolith Policy

To maintain clean modularity, minimize cognitive overhead, and enable fast surgical diffing:

- **Target Size:** Keep all `.gd`, `.ts`, and `.gdshader` files strictly between **150 and 450 lines**.
- **Hard Ceiling:** **Never append new feature blocks to any file exceeding 500 lines.**
- When a file approaches or exceeds this ceiling, extract decoupled domain logic into helper classes (`extends RefCounted` or dedicated child `Node` components).

### Target Granular Architecture Map
When decomposing large orchestrators, follow this exact target architecture:
- `prop_scatter.gd` -> Orchestrator only; delegate mesh building to `world/props/prop_mesh_factory.gd`, generic vignettes to `world/props/vignettes_generic.gd`, and biome landmarks to `world/props/sector_*.gd`.
- `ui.gd` -> Façade coordinator only; delegate styling to `ui/hud_theme_style.gd`, revolver drum to `ui/revolver_cylinder_widget.gd`, bars to `ui/vitals_and_gauges_widget.gd`, inventory/journal to `ui/inventory_and_journal_modal.gd`, and pause/toasts to `ui/pause_and_toast_controller.gd`.
- `map_modal.gd` -> Delegate contour elevation rendering to `ui/map_contour_renderer.gd` and POI state to `ui/map_poi_registry.gd`.
- `main_menu.gd` -> Delegate Gate prologue to `ui/menu_gate_sequence.gd` and settings sliders to `ui/menu_settings_controller.gd`.
- `world.gd` -> Delegate `_setup_*` node spawning to `world/world_bootstrap_builder.gd`.
- `player.gd` -> Delegate camera shoulder/FOV to `player/player_camera_rig.gd` and biome hazard feedback to `player/player_hazard_effects.gd`.
- `weapon_system.gd` -> Delegate hitscan/recoil/spread/fouling math to `weapons/revolver_ballistics_and_wear.gd`.
- `enemy_base.gd` -> Delegate sight/hearing sensors and loot drops to `enemies/enemy_sensors_and_loot.gd`.
- `localization.gd` -> Delegate language dictionaries to `localization/strings_en.gd` and `localization/strings_es.gd`.

### Surgical Diffs
- Always apply targeted, minimal diffs rather than rewriting whole files.
- Preserve existing comments, constants, and contracts unless explicitly asked to modify them.

---

## 2. Single Source of Truth for Scenes (`res://scenes/`)

- All `.tscn` PackedScenes **MUST live exclusively in `res://scenes/`**.
- **Never duplicate `.tscn` files in the project root** or in arbitrary subdirectories.
- Never create backup folders inside the repository (e.g., `.backup_before_rollback/`, `backup/`, etc.). Version control is handled by Git.

---

## 3. Sacred World, Physics & UI Invariants (NEVER VIOLATE)

1. **1:1 Heightmap & Shader Parity:**
   `sample_height(x, z)` in `terrain_collision.gd` and `sample_terrain_height(vec2 pos)` in `shaders/wasteland_terrain.gdshader` must remain **100% mathematically identical** across all 8 sectors (including macro-undulation, sector-specific feature sculpting, noise octaves, and chasm cuts). Physics collisions and visual vertices must never desync.

2. **Node 0 Sanctuary Invariant:**
   - The Mohaine Way-Bunker at `(-1020, -820)` and gate at `(-900, -820)` must maintain exactly `0.0` biome displacement perturbation (`expectedGround = -0.56m`).
   - Interior particulate hazard density must remain strictly `0.0` inside the sanctuary perimeter.

3. **HUD Contract:**
   Preserve the borderless Dark-Tower Western Minimalist (Destiny-Style / Borderless) HUD layout:
   - **Top-Center:** Dual vitals bars (Health & Stamina).
   - **Top-Right:** Tactical radar with obsidian heading pill.
   - **Upper-Left:** Sector banner.
   - **Mid-Left:** Diamond condition & status stack.
   - **Bottom-Left:** 76×76 px rotating 6-chamber revolver drum + 4 tactile action tiles + ammunition block.

---

## 4. Mandatory Verification

- Run `npm test` after **every change**.
- 100% of unit, contract, and subsystem tests (inventory, survival, weather, external ballistics, weapon mechanics) must pass with **0 regressions**.

