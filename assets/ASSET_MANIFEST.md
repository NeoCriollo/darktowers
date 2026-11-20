# Dark Towers: The Path of Ka — 3D Asset & Shader Manifest (Godot 4.3)

This directory structure is designed for a scalable, modular **Godot 4.3** production pipeline. Each category separates raw imported meshes (`.glb` / `.fbx`), LOD chains, reusable scene prefabs (`.tscn`), and surface materials/shaders (`.tres` / `.gdshader`).

---

## Naming & Import Conventions

| Prefix / Suffix | Asset Type | Example |
| :--- | :--- | :--- |
| `SM_` | Static Mesh (`.glb`) | `SM_BrutalWall_Plain_01.glb` |
| `SK_` | Skeletal Mesh / Rig (`.glb`) | `SK_Gunslinger_Base.glb` |
| `BP_` / `PFB_` | PackedScene Prefab (`.tscn`) | `PFB_Conduit_JunctionValve.tscn` |
| `Mat_` | Master Material / ShaderMaterial (`.tres`) | `Mat_BrutalConcrete.tres` |
| `MI_` | Material Instance (`.tres`) | `MI_BrutalConcrete_SaltCrusted.tres` |
| `T_` | Texture Map (`_A`, `_N`, `_ORM`, `_E`) | `T_CarbonSteel_ORM.dds` |
| `_LOD0` .. `_LOD3` | Level of Detail Mesh Suffixes | `SM_DarkTower_Spire_LOD0.glb` |
| `-col` / `-convcol` | Godot Auto-Collision Mesh Suffixes | `SM_Pillar_Cylindrical_01-col` |

---

## I. Architectural & Monumental Assets (`res://assets/architecture/`)

### 1. The Dark Tower — *Faro del Ka* (`landmarks/dark_tower/`)
Colossal hyper-tall brutalist spire with vertical ribbing, reinforced steel bracing, and the apex Ka emission beacon.
- `res://assets/architecture/landmarks/dark_tower/meshes/` — Base hero spire geometry, vertical ribbing modules, steel bracing, and apex beacon housing.
- `res://assets/architecture/landmarks/dark_tower/lods/` — Layered macro LOD meshes (`_LOD0` through `_LOD4`) for horizon rendering.
- `res://assets/architecture/landmarks/dark_tower/shaders/` — Non-colliding background depth shader, Ka apex beacon volumetric/emission shader, and custom triplanar edge-weathering shader.
- `res://assets/architecture/landmarks/dark_tower/prefabs/` — Assembled landmark `.tscn` prefabs.

### 2. Brutalist Modular Building Kit (`modular_brutalist/`)
Grid-snapped structural kit for monoliths, bunkers, and vertical ruins.
- **Core Wall Segments (`core_walls/`)**
  - `res://assets/architecture/modular_brutalist/core_walls/concrete_plain/` — Plain reinforced concrete panels.
  - `res://assets/architecture/modular_brutalist/core_walls/concrete_fractured/` — Fractured/eroded concrete panels with exposed rebar.
  - `res://assets/architecture/modular_brutalist/core_walls/catwalk_grated/` — Grated industrial catwalk tiles.
- **Structural Supports (`structural_supports/`)**
  - `res://assets/architecture/modular_brutalist/structural_supports/cylindrical_pillars/` — Massive load-bearing cylindrical pillars.
  - `res://assets/architecture/modular_brutalist/structural_supports/h_beams/` — Heavy-duty structural H-beams.
  - `res://assets/architecture/modular_brutalist/structural_supports/cross_bracing/` — Rusted steel cross-bracing struts.
- **Access Infrastructure (`access_infrastructure/`)**
  - `res://assets/architecture/modular_brutalist/access_infrastructure/gantry_stairs/` — Wind-scoured gantry stairs.
  - `res://assets/architecture/modular_brutalist/access_infrastructure/cantilevered_balconies/` — Cantilevered lookout and walkway balconies.
  - `res://assets/architecture/modular_brutalist/access_infrastructure/maintenance_ladders/` — Segmented vertical maintenance ladders and cages.
- **Assembled Prefabs (`prefabs/`)**
  - `res://assets/architecture/modular_brutalist/prefabs/` — Reusable multi-piece brutalist room and ruin assemblies.

### 3. Pre-Break Infrastructural Scars (`pre_break_infrastructure/`)
Relics of pre-collapse civil and industrial engineering spanning the wasteland.
- **Highways & Overpasses (`highways_overpasses/`)**
  - `res://assets/architecture/pre_break_infrastructure/highways_overpasses/road_decks/` — Segmented and buckled asphalt/concrete road decks.
  - `res://assets/architecture/pre_break_infrastructure/highways_overpasses/collapsed_pylons/` — Sheared and toppled concrete support pylons.
  - `res://assets/architecture/pre_break_infrastructure/highways_overpasses/rebar_cages/` — Twisted skeletal rebar cages.
- **Industrial Pipelines (`industrial_pipelines/`)**
  - `res://assets/architecture/pre_break_infrastructure/industrial_pipelines/conduit_straight/` — Massive rusted steel straight conduit tubes.
  - `res://assets/architecture/pre_break_infrastructure/industrial_pipelines/conduit_elbows/` — Angled 45°/90° pipeline elbows.
  - `res://assets/architecture/pre_break_infrastructure/industrial_pipelines/junction_valves/` — Pressure junction valves and manifold stations.
- **Assembled Prefabs (`prefabs/`)**
  - `res://assets/architecture/pre_break_infrastructure/prefabs/` — Spline-ready highway and pipeline assemblies.

---

## II. Environmental & Terrain Assets (`res://assets/environment/`)

### 1. Procedural Terrain & Geomorphology (`terrain_geomorphology/`)
- **Yardangs & Spires (`yardangs_spires/`)**
  - `res://assets/architecture/` -> `res://assets/environment/terrain_geomorphology/yardangs_spires/sedimentary_ridges/` — Wind-carved sedimentary ridge megameshes.
  - `res://assets/environment/terrain_geomorphology/yardangs_spires/sandstone_wind_fins/` — Sharp sandstone wind-fins aligned with prevailing gale vectors.
- **Salt Playas & Dunes (`salt_playas_dunes/`)**
  - `res://assets/environment/terrain_geomorphology/salt_playas_dunes/alkali_mud_flats/` — Cracked alkali mud flat surface plates and blends.
  - `res://assets/environment/terrain_geomorphology/salt_playas_dunes/sand_erg_profiles/` — Rolling sand erg dune meshes.
  - `res://assets/environment/terrain_geomorphology/salt_playas_dunes/heightmaps/` — 16-bit/32-bit EXR/RAW heightmap textures for `HeightMapShape3D` physics grids.

### 2. PropScatter Vignette Kit (`prop_scatter_vignettes/`)
Designed for integration with [`prop_scatter.gd`](../prop_scatter.gd) and `MultiMeshInstance3D` batching.
- **Scavenger Outposts (`scavenger_outposts/`)**
  - `res://assets/environment/prop_scatter_vignettes/scavenger_outposts/canvas_wind_breaks/` — Tattered canvas wind-breaks (vertex-wind ready).
  - `res://assets/environment/prop_scatter_vignettes/scavenger_outposts/scrap_lean_tos/` — Corrugated scrap-metal lean-to shelters.
  - `res://assets/environment/prop_scatter_vignettes/scavenger_outposts/rusted_oil_drums/` — Rusted industrial oil drums and storage barrels.
  - `res://assets/environment/prop_scatter_vignettes/scavenger_outposts/crude_fire_pits/` — Stone/scrap fire rings, ash piles, and ember emitters.
- **Wasteland Debris (`wasteland_debris/`)**
  - `res://assets/environment/prop_scatter_vignettes/wasteland_debris/cargo_haulers/` — Overturned pre-break heavy cargo haulers.
  - `res://assets/environment/prop_scatter_vignettes/wasteland_debris/transport_skeletons/` — Weathered chassis and transport vehicle skeletons.
  - `res://assets/environment/prop_scatter_vignettes/wasteland_debris/bleached_timber_frames/` — Sun-bleached timber frames and fencing remnants.
- **Vignette Prefabs (`prefabs/`)**
  - `res://assets/environment/prop_scatter_vignettes/prefabs/` — Pre-dressed micro-camp and wreckage clusters.

---

## III. Character & Weapon Mechanics (`res://assets/characters/` & `res://assets/weapons/`)

### 1. The Gunslinger — Player Character (`res://assets/characters/gunslinger/`)
- **Base Skeleton & Animation (`base_rig/`)**
  - `res://assets/characters/gunslinger/base_rig/skeleton/` — Humanoid rig (`Skeleton3D` + `BoneAttachment3D` sockets) optimized for Godot's `AnimationTree`.
  - `res://assets/characters/gunslinger/base_rig/animations/ots_locomotion/` — Over-the-shoulder (OTS) directional walk, run, and strafe libraries.
  - `res://assets/characters/gunslinger/base_rig/animations/tactical_crouch/` — Tactical crouch idle, locomotion, and cover transitions.
  - `res://assets/characters/gunslinger/base_rig/animations/shoulder_swap/` — Smooth left/right shoulder-swapping blend transitions.
- **Modular Gear Attachments (`modular_gear/`)**
  - `res://assets/characters/gunslinger/modular_gear/duster_coat/` — Dusted leather duster coat with lower-hem cloth physics pins.
  - `res://assets/characters/gunslinger/modular_gear/cartridge_bandoliers/` — Chest/hip `.45 Long Colt` cartridge bandoliers.
  - `res://assets/characters/gunslinger/modular_gear/holster_rig/` — Drop-leg leather gunbelt and quick-draw holster rig.
  - `res://assets/characters/gunslinger/modular_gear/scout_hat_cloth/` — Wide-brimmed scout hat with brim cloth/wind simulation.
- **Character Prefabs (`prefabs/`)**
  - `res://assets/characters/gunslinger/prefabs/` — Assembled visual character rig scenes linked to [`player.tscn`](../player.tscn).

### 2. Frontier Sambar Revolver — .45 Long Colt (`res://assets/weapons/revolver_sambar_45lc/`)
Linked to [`weapon_system.gd`](../weapon_system.gd) for procedural recoil, reload state machines, and chamber indexing.
- **Anatomical Parts (`anatomical_parts/`)**
  - `res://assets/weapons/revolver_sambar_45lc/anatomical_parts/frame/` — Main receiver frame and Sambar stag grip panels.
  - `res://assets/weapons/revolver_sambar_45lc/anatomical_parts/cylinder_6chamber/` — Individually indexable rotating 6-chamber cylinder.
  - `res://assets/weapons/revolver_sambar_45lc/anatomical_parts/striking_hammer/` — Articulated striking hammer and trigger sear.
  - `res://assets/weapons/revolver_sambar_45lc/anatomical_parts/loading_gate/` — Hinged side loading gate and ejector rod.
  - `res://assets/weapons/revolver_sambar_45lc/anatomical_parts/barrel_assembly/` — Rifled barrel assembly and front sight blade.
- **Tactical States & Ballistic Details (`tactical_states/`)**
  - `res://assets/weapons/revolver_sambar_45lc/tactical_states/brass_casings/` — Physical `.45 LC` brass casings (live rounds vs. extracted shells).
  - `res://assets/weapons/revolver_sambar_45lc/tactical_states/spent_primers/` — Indented spent copper primer cap meshes/decals.
  - `res://assets/weapons/revolver_sambar_45lc/tactical_states/fouling_grit_vfx/` — Interactive powder fouling, sand grit accumulation nodes, and muzzle smoke emitters.
- **Weapon Animations & Prefabs (`animations/` & `prefabs/`)**
  - `res://assets/weapons/revolver_sambar_45lc/animations/` — Mechanical chamber-by-chamber reload, fan-the-hammer, and unjam animations.
  - `res://assets/weapons/revolver_sambar_45lc/prefabs/` — Assembled revolver scene with bone/node pivots exposed for script control.

---

## IV. Master Material & Surface Shader Library (`res://assets/materials/`)

- **`mat_brutal_concrete/` (`Mat_BrutalConcrete`)**
  - `res://assets/materials/master_library/mat_brutal_concrete/shaders/` — Dual-layer normal mapping (micro-pitting), procedural edge dust accumulation, and world-space elevation salt-crust layering.
  - `res://assets/materials/master_library/mat_brutal_concrete/textures/` — Concrete base albedo, macro/micro normals, and curvature masks.
- **`mat_carbon_steel/` (`Mat_CarbonSteel`)**
  - `res://assets/materials/master_library/mat_carbon_steel/shaders/` — High-contrast industrial metallic shader supporting dynamic barrel-fouling carbon burn parameters.
  - `res://assets/materials/master_library/mat_carbon_steel/textures/` — Pre-break industrial roughness maps, micro-rust streak masks, and carbon scoring maps.
- **`mat_rusted_iron/` (`Mat_RustedIron`)**
  - `res://assets/materials/master_library/mat_rusted_iron/shaders/` — Heavy oxidation shader with dynamic color-shifting gradients from deep ochre to oxidized green corrosion.
  - `res://assets/materials/master_library/mat_rusted_iron/textures/` — Oxidation ramp gradients, pitted iron normals, and flaking rust masks.
- **`mat_alkali_sand/` (`Mat_AlkaliSand`)**
  - `res://assets/materials/master_library/mat_alkali_sand/shaders/` — Triplanar-mapped fine silica shader with directional sunlight & wind-storm particle density specular sparkle highlights.
  - `res://assets/materials/master_library/mat_alkali_sand/textures/` — Silica grain normals, glitter/sparkle noise maps, and wind-ripple height maps.
- **`shared_textures/`**
  - `res://assets/materials/shared_textures/noise_masks/` — Global triplanar masks, Perlin/Voronoi weathering noises.
  - `res://assets/materials/shared_textures/weathering_decals/` — Edge wear, leak streaks, and blast scorch decals.
  - `res://assets/materials/shared_textures/detail_normals/` — Shared tiling micro-surface detail normals.

