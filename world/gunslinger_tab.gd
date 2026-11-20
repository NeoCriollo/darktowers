class_name GunslingerTab
extends PanelContainer

const GunslingerProgression = preload("res://world/gunslinger_progression.gd")

## Diegetic Gunslinger Dossier & Field Workbench Modal
## Amber-phosphor CRT dossier displaying Gunslinger Disciplines, Revolver Engineering,
## Survival Rig status, and salvage conversion.

signal dossier_closed

@onready var steady_eye_label: Label = find_child("SteadyEyeLabel", true, false)
@onready var cold_hands_label: Label = find_child("ColdHandsLabel", true, false)
@onready var long_walk_label: Label = find_child("LongWalkLabel", true, false)
@onready var mind_ka_label: Label = find_child("MindKaLabel", true, false)

@onready var crane_seal_btn: Button = find_child("UpgradeCraneBtn", true, false)
@onready var chamber_mach_btn: Button = find_child("UpgradeChamberBtn", true, false)
@onready var salvage_label: Label = find_child("SalvagePoolLabel", true, false)

var progression: GunslingerProgression = null

func _ready() -> void:
	visible = false
	if crane_seal_btn != null:
		crane_seal_btn.pressed.connect(_on_upgrade_crane_pressed)
	if chamber_mach_btn != null:
		chamber_mach_btn.pressed.connect(_on_upgrade_chamber_pressed)

func open_dossier(prog_data: GunslingerProgression) -> void:
	progression = prog_data
	visible = true
	_refresh_display()

func close_dossier() -> void:
	visible = false
	dossier_closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_TAB):
		close_dossier()
		get_viewport().set_input_as_handled()

func _refresh_display() -> void:
	if progression == null:
		return

	if steady_eye_label != null:
		steady_eye_label.text = "[*] Steady Eye       [LVL %02d/10] | Sway: -%d%%" % [
			progression.steady_eye_level,
			int((1.0 - progression.aim_sway_multiplier) * 100.0)
		]
	if cold_hands_label != null:
		cold_hands_label.text = "[*] Cold Iron Hands  [LVL %02d/10] | Cycle: +%d%% | Jam Clear: %.2fs" % [
			progression.cold_iron_hands_level,
			int((progression.cycle_speed_multiplier - 1.0) * 100.0),
			progression.jam_clear_duration
		]
	if long_walk_label != null:
		long_walk_label.text = "[*] Long Walk Endur. [LVL %02d/10] | Bonus Stamina: +%d" % [
			progression.long_walk_level,
			int(progression.max_stamina_bonus)
		]
	if mind_ka_label != null:
		mind_ka_label.text = "[*] Mind of Ka       [LVL %02d/10] | Todash Damping: %d%%" % [
			progression.mind_of_ka_level,
			int(progression.todash_damping * 100.0)
		]

	if crane_seal_btn != null:
		crane_seal_btn.text = "Cylinder Crane Seal: [TIER %d/3] (Upgrade: 15 Scrap)" % progression.cylinder_crane_seal_tier
		crane_seal_btn.disabled = not progression.can_upgrade_crane_seals()

	if chamber_mach_btn != null:
		chamber_mach_btn.text = "Chamber Machining:  [TIER %d/3] (Upgrade: 20 Scrap, 6 Brass)" % progression.chamber_machining_tier
		chamber_mach_btn.disabled = not progression.can_upgrade_chamber_machining()

	if salvage_label != null:
		salvage_label.text = "SALVAGE POOL: [SCRAP: %d] [BRASS: %d] [GUN OIL: %.1f fl oz]" % [
			progression.scrap_count,
			progression.brass_count,
			progression.gun_oil_fl_oz
		]

func _on_upgrade_crane_pressed() -> void:
	if progression != null and progression.upgrade_crane_seals():
		_refresh_display()

func _on_upgrade_chamber_pressed() -> void:
	if progression != null and progression.upgrade_chamber_machining():
		_refresh_display()

