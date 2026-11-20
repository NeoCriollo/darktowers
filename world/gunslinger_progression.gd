class_name GunslingerProgression
extends Resource

## Gunslinger Field Progression & Firearm Engineering Resource
## Governs discipline masteries, revolver machining tolerances, survival rig,
## and usage-based "Lessons of Ka" experience counters.

# --- Physical & Mental Discipline ---
@export_group("Discipline")
@export var steady_eye_level: int = 1:
	set(val):
		steady_eye_level = clampi(val, 1, 10)
		aim_sway_multiplier = maxf(0.2, 1.0 - (steady_eye_level * 0.08))

@export var cold_iron_hands_level: int = 1:
	set(val):
		cold_iron_hands_level = clampi(val, 1, 10)
		cycle_speed_multiplier = 1.0 + (cold_iron_hands_level * 0.09)
		jam_clear_duration = maxf(0.4, 1.2 - (cold_iron_hands_level * 0.08))

@export var long_walk_level: int = 1:
	set(val):
		long_walk_level = clampi(val, 1, 10)
		max_stamina_bonus = (long_walk_level - 1) * 15.0

@export var mind_of_ka_level: int = 1:
	set(val):
		mind_of_ka_level = clampi(val, 1, 10)
		todash_damping = clampf((mind_of_ka_level - 1) * 0.10, 0.0, 0.90)

# Computed modifiers read by player & weapon
var aim_sway_multiplier: float = 1.0
var cycle_speed_multiplier: float = 1.0
var jam_clear_duration: float = 1.2
var max_stamina_bonus: float = 0.0
var todash_damping: float = 0.0

# --- Firearm Upgrades ---
@export_group("Revolver Engineering")
@export var chamber_machining_tier: int = 0      # Increases muzzle velocity by +25 m/s per tier
@export var cylinder_crane_seal_tier: int = 0    # Reduces silica grit ingress rate by -30% per tier
@export var match_hammer_sear_tier: int = 0      # Reduces recoil kick by -15% per tier
@export var hardened_loading_gate_tier: int = 0  # Decreases single-cartridge load time

# --- Survival Rig ---
@export_group("Attire & Rig")
@export var holster_sealed: bool = false         # True = holstered weapon takes 0 ambient silica
@export var respirator_filter_efficiency: float = 0.0 # Dampens stamina penalty during sandstorms
@export var hobnail_boots: bool = false          # Eliminates dune incline sprint penalty

# --- Salvage Currency ---
@export_group("Salvage Pool")
@export var scrap_count: int = 25
@export var brass_count: int = 12
@export var gun_oil_fl_oz: float = 2.4

# --- Lessons of Ka (Usage Experience Trackers) ---
var jams_cleared_count: int = 0
var storm_meters_walked: float = 0.0
var clean_hits_landed: int = 0

signal discipline_leveled_up(discipline_name: String, new_level: int)
signal upgrade_installed(category: String, tier: int)

func record_jam_cleared() -> void:
	jams_cleared_count += 1
	if jams_cleared_count >= cold_iron_hands_level * 4:
		cold_iron_hands_level += 1
		discipline_leveled_up.emit("Cold Iron Hands", cold_iron_hands_level)

func record_storm_distance(meters: float) -> void:
	storm_meters_walked += meters
	if storm_meters_walked >= float(long_walk_level) * 450.0:
		long_walk_level += 1
		discipline_leveled_up.emit("Long Walk Endurance", long_walk_level)

func record_clean_hit() -> void:
	clean_hits_landed += 1
	if clean_hits_landed >= steady_eye_level * 6:
		steady_eye_level += 1
		discipline_leveled_up.emit("Steady Eye", steady_eye_level)

func can_upgrade_crane_seals() -> bool:
	return cylinder_crane_seal_tier < 3 and scrap_count >= (cylinder_crane_seal_tier + 1) * 15

func upgrade_crane_seals() -> bool:
	if not can_upgrade_crane_seals():
		return false
	scrap_count -= (cylinder_crane_seal_tier + 1) * 15
	cylinder_crane_seal_tier += 1
	upgrade_installed.emit("Crane Seal", cylinder_crane_seal_tier)
	return true

func can_upgrade_chamber_machining() -> bool:
	return chamber_machining_tier < 3 and scrap_count >= 20 and brass_count >= 6

func upgrade_chamber_machining() -> bool:
	if not can_upgrade_chamber_machining():
		return false
	scrap_count -= 20
	brass_count -= 6
	chamber_machining_tier += 1
	upgrade_installed.emit("Chamber Machining", chamber_machining_tier)
	return true

