class_name InventoryAndJournalModal
extends RefCounted

## Tactile Inventory Grid, Saddlebag Storage & Journal / Inspection Modal Sub-Controller.
## Manages modal inspection views, journal data displays, item slot interaction hooks,
## saddlebag transfer interfaces, and encumbrance calculations.

var hud: WastelandHUD
var is_journal_open: bool = false
var is_inventory_open: bool = false

# ─── Dark-Tower Western Modular Inventory Tabs ────────────────────────────────
const TAB_EQUIPMENT: int = 0
const TAB_SUPPLIES: int = 1
const TAB_SADDLEBAG: int = 2
const TAB_JOURNAL: int = 3

var current_tab: int = TAB_EQUIPMENT

# Runtime inventory & journal storage state
var _journal_entries: Array[Dictionary] = []

var _saddlebag_left_mass: float = 12.4
var _saddlebag_right_mass: float = 13.0
var _saddlebag_max_mass: float = 30.0

func _init(p_hud: WastelandHUD) -> void:
	hud = p_hud
	_init_default_journal_entries()

func _init_default_journal_entries() -> void:
	_journal_entries = [
		{
			"title": Localization.t("JOURNAL_CHAPTER_1_TITLE"),
			"category": Localization.t("JOURNAL_CAT_MAIN_QUEST"),
			"text": Localization.t("JOURNAL_CHAPTER_1_DESC"),
			"timestamp": Localization.t("JOURNAL_TIME_DAY_1_DUSK")
		},
		{
			"title": Localization.t("JOURNAL_CHAPTER_2_TITLE"),
			"category": Localization.t("JOURNAL_CAT_BALLISTICS"),
			"text": Localization.t("JOURNAL_CHAPTER_2_DESC"),
			"timestamp": Localization.t("JOURNAL_TIME_DAY_1_NIGHT")
		}
	]

# ─── Inspection Modal ────────────────────────────────────────────────────────
func toggle_inspection(data: Dictionary) -> void:
	if hud._is_inspecting:
		hide_inspection()
	else:
		show_inspection(data)

func show_inspection(data: Dictionary) -> void:
	if hud.inspection_modal == null or hud.inspection_body_label == null:
		return
	hud._last_inspection_data = data.duplicate()
	hud._is_inspecting = true
	if hud.inspection_title_label != null:
		hud.inspection_title_label.text = hud.tr_ui("INSPECT_TITLE")
	var lines: Array[String] = [
		hud.tr_ui("INSPECT_TITLE"),
		hud.tr_ui("INSPECT_MODEL_FMT") % data.get("weapon_name", "Firearm"),
		hud.tr_ui("INSPECT_ACTION_FMT") % [data.get("action_feel", "Smooth"), data.get("tactile_severity", "PRISTINE")],
		hud.tr_ui("INSPECT_BORE_FMT") % data.get("bore_condition", "Clean"),
		hud.tr_ui("INSPECT_SURFACE_FMT") % data.get("surface_finish", "Oiled blued steel"),
		hud.tr_ui("INSPECT_CYLINDER_FMT") % data.get("cylinder_report", "Loaded"),
		hud.tr_ui("INSPECT_HAMMER_FMT") % data.get("hammer_report", "Resting"),
		hud.tr_ui("INSPECT_BALLISTICS_FMT") % [int(data.get("muzzle_velocity_mps", 275.0)), float(data.get("jam_risk_pct", 1.5))],
		"",
		hud.tr_ui("INSPECT_CLOSE_HINT")
	]
	hud.inspection_body_label.text = "\n".join(lines)
	hud.inspection_modal.visible = true

func hide_inspection() -> void:
	hud._is_inspecting = false
	if hud.inspection_modal != null:
		hud.inspection_modal.visible = false

# ─── Journal & Logbook Modal ─────────────────────────────────────────────────
func toggle_journal() -> bool:
	is_journal_open = not is_journal_open
	if is_journal_open:
		if hud.inspection_modal != null and hud.inspection_modal.visible:
			hide_inspection()
		if hud.settings_modal != null and hud.settings_modal.visible:
			hud.hide_settings_modal()
		show_journal()
	else:
		hide_journal()
	return is_journal_open

func show_journal() -> void:
	is_journal_open = true
	hud.show_notification(hud.tr_ui("HINT_INSPECT") + " [" + Localization.t("JOURNAL_TITLE") + "]", 2.5)

func hide_journal() -> void:
	is_journal_open = false

func add_journal_entry(p_title: String, p_category: String, p_text: String) -> void:
	_journal_entries.append({
		"title": p_title,
		"category": p_category,
		"text": p_text,
		"timestamp": Localization.t("JOURNAL_TIME_RECENT")
	})
	hud.show_notification(Localization.t("NOTIF_JOURNAL_ADDED_FMT") % p_title, 3.0)

func get_journal_entries() -> Array[Dictionary]:
	if _journal_entries.is_empty():
		_init_default_journal_entries()
	return _journal_entries

# ─── Tactile Inventory Grid & Tabs ───────────────────────────────────────────
func toggle_inventory() -> bool:
	is_inventory_open = not is_inventory_open
	if is_inventory_open:
		show_inventory()
	else:
		hide_inventory()
	return is_inventory_open

func show_inventory() -> void:
	is_inventory_open = true
	refresh_inventory_grid()
	hud.show_notification(Localization.t("NOTIF_INVENTORY_OPENED"), 2.0)

func hide_inventory() -> void:
	is_inventory_open = false

func refresh_inventory_grid() -> void:
	_refresh_inventory_grid()

func _refresh_inventory_grid() -> void:
	# Synchronize active inventory slots for current tab
	match current_tab:
		TAB_EQUIPMENT:
			_render_equipment_layout()
		TAB_SUPPLIES:
			_render_supplies_grid()
		TAB_SADDLEBAG:
			_render_saddlebag_storage()
		TAB_JOURNAL:
			_render_journal_log()

func on_tab_button_pressed(tab_index: int) -> void:
	_on_tab_button_pressed(tab_index)

func _on_tab_button_pressed(tab_index: int) -> void:
	current_tab = clampi(tab_index, TAB_EQUIPMENT, TAB_JOURNAL)
	refresh_inventory_grid()

func _render_equipment_layout() -> void:
	# Visual layout for gunslinger holsters, bandolier and pack
	pass

func _render_supplies_grid() -> void:
	# Spatial 10x4 tactile slot grid synchronization
	pass

func _render_saddlebag_storage() -> void:
	# Mount saddlebags dual-container display
	pass

func _render_journal_log() -> void:
	# Lore and quest objective listing
	pass

# ─── Saddlebag Transfer & Encumbrance Calculations ───────────────────────────
func transfer_item_to_saddlebag(item_id: String, quantity: int = 1) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false
	# Transfer item mass to lighter saddlebag to minimize lateral torque
	if _saddlebag_left_mass <= _saddlebag_right_mass:
		_saddlebag_left_mass = minf(_saddlebag_max_mass, _saddlebag_left_mass + 0.8 * quantity)
	else:
		_saddlebag_right_mass = minf(_saddlebag_max_mass, _saddlebag_right_mass + 0.8 * quantity)
	hud.show_notification(Localization.t("NOTIF_SADDLEBAG_TRANSFERRED_FMT") % [item_id, quantity], 2.2)
	refresh_inventory_grid()
	return true

func transfer_item_from_saddlebag(item_id: String, quantity: int = 1) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false
	if _saddlebag_left_mass >= _saddlebag_right_mass:
		_saddlebag_left_mass = maxf(0.0, _saddlebag_left_mass - 0.8 * quantity)
	else:
		_saddlebag_right_mass = maxf(0.0, _saddlebag_right_mass - 0.8 * quantity)
	hud.show_notification(Localization.t("NOTIF_SADDLEBAG_RETRIEVED_FMT") % [item_id, quantity], 2.2)
	refresh_inventory_grid()
	return true

func calculate_saddlebag_imbalance() -> float:
	var total_mass: float = _saddlebag_left_mass + _saddlebag_right_mass
	if total_mass <= 0.001:
		return 0.0
	return absf(_saddlebag_left_mass - _saddlebag_right_mass) / total_mass

func format_encumbrance_status(current_mass: float, max_mass: float) -> String:
	var ratio: float = current_mass / maxf(0.1, max_mass)
	if ratio > 1.0:
		return Localization.t("ENCUMBRANCE_OVERBURDENED_FMT") % [current_mass, max_mass]
	elif ratio > 0.75:
		return Localization.t("ENCUMBRANCE_HEAVY_FMT") % [current_mass, max_mass]
	return Localization.t("ENCUMBRANCE_LIGHT_FMT") % [current_mass, max_mass]

func format_slot_tooltip(item: Dictionary) -> String:
	var item_name: String = item.get("name", Localization.t("ITEM_UNKNOWN"))
	var category: String = item.get("category", Localization.t("ITEM_CAT_SUPPLIES"))
	var mass: float = float(item.get("mass_kg", 0.5))
	var cond: float = float(item.get("condition", 1.0)) * 100.0
	var desc: String = item.get("description", "")
	return Localization.t("ITEM_TOOLTIP_FMT") % [item_name, category, mass, int(cond), desc]

func create_item_slot_style(category: String, condition: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0627, 0.051, 0.0392, 0.75)
	box.border_color = HUDThemeStyle.SANDALWOOD_AMBER if condition > 0.5 else HUDThemeStyle.CRIMSON_HAZARD
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box

func handle_inventory_input(event: InputEvent) -> bool:
	if WorldSaveData != null and WorldSaveData.is_editor_active(): return false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var iek := event as InputEventKey
		if event.is_action_pressed("field_gunsmith_inspect") or event.is_action_pressed("inspect_weapon") or iek.keycode == KEY_I or iek.physical_keycode == KEY_I:
			var ws: Node = null
			if hud != null and hud.is_inside_tree() and hud.get_tree() != null:
				ws = hud.get_tree().root.find_child("WeaponSystem", true, false)
			if ws != null and ws.has_method("inspect_weapon"):
				toggle_inspection(ws.call("inspect_weapon"))
			elif hud != null and hud._last_inspection_data != null and not hud._last_inspection_data.is_empty():
				toggle_inspection(hud._last_inspection_data)
			else:
				toggle_inspection({})
			return true
		elif iek.keycode == KEY_J or iek.physical_keycode == KEY_J:
			toggle_journal()
			return true
	return false
