# THE PATH OF KA — VERTICAL SLICE ARCHITECTURE & ROADMAP

> **Directive Reference:** Vertical Slice Architecture (M4 Apple Silicon Target)  
> **Genre:** Gritty, tactile, single-player survival RPG (RDR2 mechanical weight + loot economy)  
> **Design Philosophy:** Strict Diegetic UI (zero floating damage numbers), deterministic ballistics, persistent world state, and component-based modularity.

---

## 1. System Vision & Technical Pillars

### 1.1 Tactility & Mechanical Weight
Every action carries mechanical friction, audio-visual feedback, and manual intervention:
- **No Instant Ammo Pools:** Ammunition must be loaded individual round by individual round into cylinder chambers, gate loaders, or box magazines.
- **Physical Weapon Degradation:** Grit from dust storms, unburnt black powder fouling, and corrosion directly affect internal clearances. Muzzle velocity drops deterministically, and tolerances tighten until cycling failures occur.
- **Physical Inventory:** Items occupy 2D grid dimensions $(W \times H)$, possess physical mass ($kg$), displacement volume ($cm^3$), and center-of-mass offsets that directly impact the player's locomotion physics and stamina recovery.

### 1.2 Zero Floating Numbers (Diegetic UI)
All status communication to the player is embodied in the world and character:
- **Health & Bleeding:** Auditory labored breathing, peripheral vision vignetting, blood trails on terrain, localized limp, and trembling hands when aiming.
- **Weapon Condition:** Carbon soot around cylinder gap, gritty tactile click when cocking the hammer, resistance on the ejector rod, or a stovepiped brass casing caught in the ejection port.
- **Survival Vitals:** Chapped lips, shivers in desert night, sweat accumulation and heat shimmer in midday sun.

### 1.3 Target Hardware Optimization: Apple Silicon (M4 Architecture)
- Designed to leverage Unified Memory Architecture (UMA) for zero-copy state transfers between simulation logic and future Metal/WebGPU renderers.
- Cache-conscious data structures (contiguous typed arrays for spatial chunks and particle/grit matrices).
- Deterministic fixed-rate tick runner ($60\,\text{Hz}$ physics/ballistics, $20\,\text{Hz}$ survival/weather integration).

---

## 2. Modular Architecture Overview

```
/project-root
├── /core             # High-frequency game loop, state management, event bus, engine configuration
├── /physics          # Raycasting, ballistics, internal barrel friction, weapon wear/jamming formulas
├── /inventory        # Tactile slot-based grid inventory, weight/volume limits, center-of-mass dynamics
├── /survival         # Metabolic stamina, localized body damage, hemorrhage, horse/saddle containers
├── /world            # Procedural wasteland generation, dynamic weather loops (dust/heat), zone persistence
├── /narrative        # Lore hooks, dynamic world event triggers, diegetic dialogue/text fragments
└── /tests            # Comprehensive unit and integration test verification suite
```

---

## 3. Mathematical Models & Mechanical Formulations

### 3.1 External & Internal Ballistics
1. **Aerodynamic Drag (Runge-Kutta 4th Order Integration):**
   $$\vec{F}_{\text{drag}} = -\frac{1}{2} \rho(h, T) \cdot C_d \cdot A \cdot \|\vec{v}_{\text{rel}}\| \cdot \vec{v}_{\text{rel}}$$
   Where:
   - $\rho(h, T)$ is air density as a function of altitude and desert temperature.
   - $\vec{v}_{\text{rel}} = \vec{v}_{\text{bullet}} - \vec{v}_{\text{wind}}$.
   - $C_d$ is the supersonic/transonic drag coefficient modeled via G1/G7 drag curves.

2. **Barrel Friction & Muzzle Velocity Degradation:**
   $$V_{\text{actual}} = V_{\text{nominal}} \cdot \sqrt{1 - \kappa_{\text{grit}} \cdot G(t) - \kappa_{\text{carbon}} \cdot C(t)}$$
   Where:
   - $G(t) \in [0, 1]$: Accumulated silica dust particulate index.
   - $C(t) \in [0, 1]$: Accumulated unburnt propellant/carbon fouling index.
   - $\kappa_{\text{grit}}, \kappa_{\text{carbon}}$: Friction coefficients specific to the firearm's bore tolerance.

3. **Cycling Reliability & Jam Probability:**
   $$P_{\text{jam}}(D) = \frac{1}{1 + \exp\left(-\beta \cdot (D - D_{\text{threshold}})\right)}$$
   Where composite degradation $D = 0.55 \cdot G(t) + 0.35 \cdot C(t) + 0.10 \cdot W_{\text{wear}}$.
   - When $D > D_{\text{threshold}}$, cycling a round rolls against $P_{\text{jam}}$.
   - Failure modes: `STOVEPIPE`, `FAILURE_TO_FEED`, `FAILURE_TO_EXTRACT`, `HAMMER_LIGHT_STRIKE`.

### 3.2 Tactile Inventory & Spatial Moments
1. **Center of Mass Dislocation ($\vec{R}_{\text{CoM}}$):**
   $$\vec{R}_{\text{CoM}} = \frac{\sum_{i=1}^{N} m_i \cdot \vec{r}_i}{M_{\text{player}} + \sum_{i=1}^{N} m_i}$$
   Unbalanced saddlebags or overloaded single-side coat pockets generate a torque offset, accelerating limb fatigue and destabilizing crosshair sway.

### 3.3 Metabolic Stamina & Thermoregulation
$$\frac{dS}{dt} = -\left( \dot{S}_{\text{base}} \cdot \left(1 + \frac{M_{\text{carried}}}{M_{\text{capacity}}}\right)^{1.8} + \Phi_{\text{environment}}(\text{Heat}, \text{Hydration}, \text{Grit}) \right)$$

---

## 4. Agent Swarm Execution Mandates

| Swarm Agent | Domain Area | Responsibilities & Boundaries |
| :--- | :--- | :--- |
| **Agent 1** | **Ballistics & Weapon Mechanics** | Implement deterministic projectile integration, chamber/cylinder state machines, manual clearing routines, and fouling/grit formulas. |
| **Agent 2** | **Survival & Mount Systems** | Implement metabolic stamina decay, 6-zone anatomical trauma with vascular hemorrhage rates, and horse/saddle dual-container sync. |
| **Agent 3** | **World & State Engine** | Scaffold persistent zone serialization (item drops, tracks), ambient weather state machine (Haboob sandstorms, thermal radiation), and chunk dispatchers. |

---

## 5. Milestone & Deliverable Schedule

```mermaid
flowchart LR
    A["Sprint 0: Architecture & Core Loops (Now)"] --> B["Sprint 1: Interactive Terminal Simulation"]
    B --> C["Sprint 2: Apple Silicon Metal/WebGPU Pipeline"]
    C --> D["Sprint 3: Full Vertical Slice Playable Loop"]
```

### Sprint 0 (Immediate Deliverable)
- [x] Foundational Directory Structure initialized.
- [x] Comprehensive `roadmap.md` established.
- [x] **Weapon Maintenance Subsystem:** Fully implemented state machine with degradation formulas, cleaning actions, and firing cycles.
- [x] **Tactile Slot-Based Inventory:** Spatial 2D grid allocation, mass/volume constraints, center-of-mass calculation, and container nesting (Pockets $\to$ Saddlebags).
- [x] Core Event Bus & Game Loop scaffolded.
- [x] Automated test suite verifying physical invariants.

### Sprint 1 (Mechanics Polish & Diegetic Feedback)
- Audio/haptic event binding for weapon actions (lever-action clack, spring tension, dry-fire click).
- Localized bleeding wound dressing loop (tourniquet vs clean bandage vs cauterization).
- Horse tethering, hitching post dynamics, and lead-rope physics.

### Sprint 2 (Engine Binding for Apple Silicon M4)
- Contiguous typed-buffer memory layouts for SIMD/Neon accelerations.
- Metal-backed or WebGPU headless pipeline for visual representation.
- Dynamic audio synthesis for wind howling through canyon geometry.

### Sprint 3 (The Vertical Slice Scenario)
- *Scenario:* Player navigates from abandoned waystation through a gathering dust storm to recover a lost cache.
- *Test:* Weapon exposed to sandstorm jams during confrontation; player clears stovepipe, retreats to mount, accesses saddlebag cleaning kit, applies solvent and bore cloth, and re-engages.

