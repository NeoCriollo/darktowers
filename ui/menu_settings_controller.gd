class_name MenuSettingsController
extends RefCounted

## Settings, Audio / Graphics Configuration, Language Localization & Chronicles Sub-Controller.
## Manages modal interfaces for the Dark Towers pre-game front-end.

var menu: MainMenu = null

func _init(p_menu: MainMenu = null) -> void:
	menu = p_menu

# ─── Chronicles Modal ────────────────────────────────────────────────────────

func setup_chronicles_modal() -> void:
	if menu.chronicles_modal == null: return
	menu.chronicles_modal.visible = false
	if menu.chronicles_entry_title != null and menu._serif_font != null:
		menu.chronicles_entry_title.add_theme_font_override("font", menu._serif_font)
	if menu.chronicles_entry_subtitle != null and menu._mono_font != null:
		menu.chronicles_entry_subtitle.add_theme_font_override("font", menu._mono_font)
	if menu.chronicles_entry_body != null and menu._serif_font != null:
		menu.chronicles_entry_body.add_theme_font_override("font", menu._serif_font)
	if menu.btn_close_chronicles != null:
		if menu._mono_font != null: menu.btn_close_chronicles.add_theme_font_override("font", menu._mono_font)
		menu.btn_close_chronicles.add_theme_font_size_override("font_size", 12)
		menu.btn_close_chronicles.pressed.connect(func() -> void:
			menu.chronicles_modal.visible = false
			menu.play_cylinder_index_sfx(1)
		)

	rebuild_chronicles_tabs()
	select_chronicle_entry(0)

func rebuild_chronicles_tabs() -> void:
	if menu.chronicles_tabs_hbox == null: return
	for child in menu.chronicles_tabs_hbox.get_children(): child.queue_free()
	var numerals: Array[String] = ["I", "II", "III", "IV"]
	for idx in range(numerals.size()):
		var tab_btn := Button.new()
		tab_btn.text = menu.tr_ui("CHRONICLES_TAB_PREFIX") % numerals[idx]
		tab_btn.custom_minimum_size = Vector2(96, 30)
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if menu._mono_font != null: tab_btn.add_theme_font_override("font", menu._mono_font)
		tab_btn.add_theme_font_size_override("font_size", 12)
		var captured_idx: int = idx
		tab_btn.pressed.connect(func() -> void:
			menu.play_cylinder_index_sfx(captured_idx + 1)
			select_chronicle_entry(captured_idx)
		)
		menu.chronicles_tabs_hbox.add_child(tab_btn)

func get_localized_chronicles_entries() -> Array[Dictionary]:
	return [
		{"title": menu.tr_ui("CHRONICLE_1_TITLE"), "subtitle": menu.tr_ui("CHRONICLE_1_SUBTITLE"), "body": menu.tr_ui("CHRONICLE_1_BODY")},
		{"title": menu.tr_ui("CHRONICLE_2_TITLE"), "subtitle": menu.tr_ui("CHRONICLE_2_SUBTITLE"), "body": menu.tr_ui("CHRONICLE_2_BODY")},
		{"title": menu.tr_ui("CHRONICLE_3_TITLE"), "subtitle": menu.tr_ui("CHRONICLE_3_SUBTITLE"), "body": menu.tr_ui("CHRONICLE_3_BODY")},
		{"title": menu.tr_ui("CHRONICLE_4_TITLE"), "subtitle": menu.tr_ui("CHRONICLE_4_SUBTITLE"), "body": menu.tr_ui("CHRONICLE_4_BODY")}
	]

func select_chronicle_entry(index: int) -> void:
	var entries: Array[Dictionary] = get_localized_chronicles_entries()
	menu._active_chronicle_index = clampi(index, 0, entries.size() - 1)
	var entry: Dictionary = entries[menu._active_chronicle_index]
	if menu.chronicles_entry_title != null: menu.chronicles_entry_title.text = String(entry.get("title", ""))
	if menu.chronicles_entry_subtitle != null: menu.chronicles_entry_subtitle.text = String(entry.get("subtitle", ""))
	if menu.chronicles_entry_body != null: menu.chronicles_entry_body.text = String(entry.get("body", ""))

# ─── Settings Modal & Sliders ────────────────────────────────────────────────

func setup_settings_modal() -> void:
	if menu.settings_modal == null: return
	menu.settings_modal.visible = false
	if menu.btn_close_settings != null:
		menu.btn_close_settings.pressed.connect(func() -> void:
			menu.settings_modal.visible = false
			menu.play_cylinder_index_sfx(1)
		)

	ensure_language_controls_in_settings()

	if menu.master_vol_slider != null:
		menu.master_vol_slider.value = 85.0
		menu.master_vol_slider.value_changed.connect(func(val: float) -> void:
			var db: float = linear_to_db(clampf(val / 100.0, 0.001, 1.0))
			AudioServer.set_bus_volume_db(0, db)
			if menu.master_vol_value != null: menu.master_vol_value.text = "%d%%" % int(round(val))
		)

	if menu.wind_vol_slider != null:
		menu.wind_vol_slider.value = 75.0
		menu.wind_vol_slider.value_changed.connect(func(val: float) -> void:
			if menu.wind_audio_player != null:
				menu.wind_audio_player.volume_db = linear_to_db(clampf(val / 100.0, 0.001, 1.0)) - 6.0
			if menu.wind_vol_value != null: menu.wind_vol_value.text = "%d%%" % int(round(val))
		)

	if menu.taa_check != null:
		menu.taa_check.button_pressed = true
		menu.taa_check.toggled.connect(func(enabled: bool) -> void:
			menu.play_cylinder_index_sfx(2)
			if menu.get_viewport() != null: menu.get_viewport().use_taa = enabled
		)

	if menu.fog_check != null:
		menu.fog_check.button_pressed = true
		menu.fog_check.toggled.connect(func(enabled: bool) -> void:
			menu.play_cylinder_index_sfx(3)
			var w_env := menu.get_node_or_null("CrossroadsBackdrop/TwilightEnvironment") as WorldEnvironment
			if w_env != null and w_env.environment != null:
				w_env.environment.volumetric_fog_enabled = enabled
		)

func ensure_language_controls_in_settings() -> void:
	var vbox := menu.settings_modal.get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox == null and menu.settings_modal != null:
		vbox = menu.settings_modal.find_child("VBox", true, false) as VBoxContainer
	if vbox != null and menu.language_row == null:
		menu.language_row = vbox.get_node_or_null("LanguageRow") as HBoxContainer
		if menu.language_row == null:
			menu.language_row = HBoxContainer.new()
			menu.language_row.name = "LanguageRow"
			menu.language_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			menu.language_row.add_theme_constant_override("separation", 12)

			menu.language_label = Label.new()
			menu.language_label.name = "Label"
			menu.language_label.custom_minimum_size = Vector2(180, 0)
			menu.language_label.add_theme_font_size_override("font_size", 13)
			menu.language_label.text = menu.tr_ui("SETTINGS_LANGUAGE_LABEL")
			menu.language_row.add_child(menu.language_label)

			menu.language_option = OptionButton.new()
			menu.language_option.name = "LanguageOption"
			menu.language_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			menu.language_option.add_theme_font_size_override("font_size", 13)
			menu.language_row.add_child(menu.language_option)

			menu.language_cycle_button = Button.new()
			menu.language_cycle_button.name = "BtnCycleLanguage"
			menu.language_cycle_button.custom_minimum_size = Vector2(64, 0)
			menu.language_cycle_button.add_theme_font_size_override("font_size", 12)
			menu.language_row.add_child(menu.language_cycle_button)

			vbox.add_child(menu.language_row)
			vbox.move_child(menu.language_row, mini(1, vbox.get_child_count() - 1))

	if menu.language_row != null:
		if menu.language_label == null: menu.language_label = menu.language_row.get_node_or_null("Label") as Label
		if menu.language_option == null: menu.language_option = menu.language_row.get_node_or_null("LanguageOption") as OptionButton
		if menu.language_cycle_button == null: menu.language_cycle_button = menu.language_row.get_node_or_null("BtnCycleLanguage") as Button

	if menu.language_option != null:
		menu.language_option.clear()
		menu.language_option.add_item("ENGLISH (EN)", 0)
		menu.language_option.set_item_metadata(0, "en")
		menu.language_option.add_item("ESPAÑOL (ES)", 1)
		menu.language_option.set_item_metadata(1, "es")
		menu.language_option.selected = Localization.get_language_index(menu.current_language)
		if not menu.language_option.item_selected.is_connected(on_language_option_selected):
			menu.language_option.item_selected.connect(on_language_option_selected)

	if menu.language_cycle_button != null:
		menu.language_cycle_button.text = String(Localization.LANGUAGE_BADGES.get(menu.current_language, "[ EN ]"))
		if not menu.language_cycle_button.pressed.is_connected(on_language_cycle_pressed):
			menu.language_cycle_button.pressed.connect(on_language_cycle_pressed)

func on_language_option_selected(index: int) -> void:
	if menu._updating_language_controls: return
	menu.play_cylinder_index_sfx(index + 1)
	set_language("es" if index == 1 else "en", true)

func on_language_cycle_pressed() -> void:
	menu.play_cylinder_index_sfx(2)
	cycle_language(true)

func on_external_language_changed(new_lang: String) -> void:
	if menu.current_language != new_lang:
		menu.current_language = new_lang
		refresh_localized_ui()
		menu.language_changed.emit(menu.current_language)

func tr_ui(key: String) -> String:
	return Localization.translate_key(key, menu.current_language)

func get_language() -> String:
	return menu.current_language

func set_language(lang: String, persist: bool = true) -> String:
	var resolved: String = Localization.set_language(lang, persist, MainMenu.SAVE_FILE_PATH)
	menu.current_language = resolved
	refresh_localized_ui()
	menu.language_changed.emit(menu.current_language)
	return menu.current_language

func cycle_language(persist: bool = true) -> String:
	return set_language("es" if menu.current_language == "en" else "en", persist)

func refresh_localized_ui() -> void:
	menu._updating_language_controls = true
	if menu.language_option != null and menu.language_option.item_count >= 2:
		menu.language_option.selected = Localization.get_language_index(menu.current_language)
	if menu.language_cycle_button != null:
		menu.language_cycle_button.text = String(Localization.LANGUAGE_BADGES.get(menu.current_language, "[ EN ]"))
	menu._updating_language_controls = false

	# 1. Gate Overlay
	if menu.gate_header_label != null: menu.gate_header_label.text = tr_ui("GATE_HEADER")
	if menu.current_phase == MainMenu.FrontEndPhase.THE_GATE:
		if menu.gate_quote_label != null:
			var epigraph: String = tr_ui("GATE_EPIGRAPH")
			var text_ratio: float = clampf(menu._gate_elapsed / maxf(0.5, menu.gate_duration_seconds * 0.68), 0.0, 1.0)
			menu.gate_quote_label.text = epigraph.substr(0, int(round(text_ratio * float(epigraph.length()))))
		menu._gate_seq.update_chamber_telemetry(menu._last_chamber_indexed)
	else:
		if menu.gate_quote_label != null: menu.gate_quote_label.text = tr_ui("GATE_EPIGRAPH")
		menu._gate_seq.update_chamber_telemetry(6)

	# 2. Crossroads Top Telemetry & Title Block
	if menu.location_tag_label != null: menu.location_tag_label.text = tr_ui("CROSSROADS_LOCATION_TAG")
	if menu.atmosphere_tag_label != null: menu.atmosphere_tag_label.text = tr_ui("CROSSROADS_ATMOSPHERE_TAG")
	if menu.subtitle_label != null: menu.subtitle_label.text = tr_ui("MENU_SUBTITLE")
	if menu.title_label != null: menu.title_label.text = tr_ui("MENU_TITLE")
	if menu.epigraph_label != null: menu.epigraph_label.text = tr_ui("MENU_EPIGRAPH")

	# 3. Crossroads Navigation Buttons & Status
	if menu.btn_begin_journey != null: update_button_visual_prefix(menu.btn_begin_journey, tr_ui("MENU_BEGIN_JOURNEY"), menu._hovered_nav_button == menu.btn_begin_journey)
	if menu.btn_resume_path != null:
		if menu._hovered_nav_button == menu.btn_resume_path: update_button_visual_prefix(menu.btn_resume_path, tr_ui("MENU_RESUME_PATH"), true)
		else:
			var has_save: bool = FileAccess.file_exists(MainMenu.SAVE_FILE_PATH)
			menu.btn_resume_path.text = ("  [○]  %s" if has_save else "  [·]  %s") % tr_ui("MENU_RESUME_PATH")
	if menu.btn_chronicles != null: update_button_visual_prefix(menu.btn_chronicles, tr_ui("MENU_CHRONICLES"), menu._hovered_nav_button == menu.btn_chronicles)
	if menu.btn_settings != null: update_button_visual_prefix(menu.btn_settings, tr_ui("MENU_SETTINGS"), menu._hovered_nav_button == menu.btn_settings)
	if menu.btn_quit != null: update_button_visual_prefix(menu.btn_quit, tr_ui("MENU_QUIT"), menu._hovered_nav_button == menu.btn_quit)
	if menu.nav_status_label != null: menu.nav_status_label.text = tr_ui(menu._active_nav_status_key)

	# 4. Chronicles Modal
	if menu.chronicles_modal_title != null: menu.chronicles_modal_title.text = tr_ui("CHRONICLES_MODAL_TITLE")
	if menu.btn_close_chronicles != null: menu.btn_close_chronicles.text = tr_ui("MODAL_BTN_CLOSE")
	if menu.chronicles_tabs_hbox != null:
		var numerals: Array[String] = ["I", "II", "III", "IV"]
		var tab_children: Array[Node] = menu.chronicles_tabs_hbox.get_children()
		for idx in range(mini(tab_children.size(), numerals.size())):
			var tab_btn := tab_children[idx] as Button
			if tab_btn != null: tab_btn.text = tr_ui("CHRONICLES_TAB_PREFIX") % numerals[idx]
	select_chronicle_entry(menu._active_chronicle_index)

	# 5. Settings Modal
	var setting_pairs: Array = [
		[menu.settings_modal_title, "SETTINGS_MODAL_TITLE"], [menu.btn_close_settings, "MODAL_BTN_CLOSE"],
		[menu.language_label, "SETTINGS_LANGUAGE_LABEL"], [menu.master_vol_label, "SETTINGS_MASTER_GAIN"],
		[menu.wind_vol_label, "SETTINGS_WIND_LEVEL"], [menu.taa_check, "SETTINGS_TAA"],
		[menu.fog_check, "SETTINGS_FOG"], [menu.controls_header_label, "SETTINGS_CONTROLS_HEADER"],
		[menu.controls_body_label, "SETTINGS_CONTROLS_BODY"]
	]
	for sp in setting_pairs:
		if sp[0] != null: sp[0].text = tr_ui(sp[1])

	# 6. Prologue Overlay
	if menu.prologue_header_label != null: menu.prologue_header_label.text = tr_ui("PROLOGUE_HEADER")
	if menu.prologue_title_label != null: menu.prologue_title_label.text = tr_ui("PROLOGUE_TITLE")
	if menu.btn_prologue_skip != null: menu.btn_prologue_skip.text = tr_ui("PROLOGUE_BTN_SKIP")
	var old_len: int = max(1, menu._prologue_full_text.length())
	var char_ratio: float = clampf(float(menu._prologue_visible_chars) / float(old_len), 0.0, 1.0)
	menu._prologue_full_text = "\n\n".join(menu._gate_seq.get_localized_prologue_passages())
	if menu._prologue_is_finished_typing:
		menu._prologue_visible_chars = menu._prologue_full_text.length()
		if menu.prologue_body_label != null: menu.prologue_body_label.text = menu._prologue_full_text + " ▌"
		if menu.prologue_progress_label != null: menu.prologue_progress_label.text = tr_ui("PROLOGUE_COMPLETE")
		if menu.btn_prologue_advance != null: menu.btn_prologue_advance.text = tr_ui("PROLOGUE_BTN_ENTER")
	else:
		menu._prologue_visible_chars = int(round(char_ratio * float(menu._prologue_full_text.length())))
		if menu.current_phase == MainMenu.FrontEndPhase.THE_PROLOGUE and menu.prologue_body_label != null:
			menu.prologue_body_label.text = menu._prologue_full_text.substr(0, menu._prologue_visible_chars) + "▌"
		if menu.prologue_progress_label != null:
			menu.prologue_progress_label.text = tr_ui("PROLOGUE_ETCHING_FMT") % int(round(char_ratio * 100.0))
		if menu.btn_prologue_advance != null: menu.btn_prologue_advance.text = tr_ui("PROLOGUE_BTN_COMPLETE")

# ─── Button Visual Styling Helpers ───────────────────────────────────────────

func apply_diegetic_button_style(btn: Button, is_primary: bool = false) -> void:
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.12, 0.09, 0.06, 0.90) if is_primary else Color(0.06, 0.05, 0.04, 0.82)
	base_style.border_color = Color(0.96, 0.68, 0.24, 0.75) if is_primary else Color(0.58, 0.44, 0.26, 0.45)
	base_style.set_border_width_all(1)
	base_style.border_width_left = 3 if is_primary else 1
	base_style.set_corner_radius_all(2)
	base_style.content_margin_left = 14.0
	base_style.content_margin_right = 14.0
	base_style.content_margin_top = 6.0
	base_style.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", base_style)

	var hover_style := base_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.24, 0.16, 0.08, 0.95) if is_primary else Color(0.14, 0.10, 0.06, 0.90)
	hover_style.border_color = Color(0.98, 0.78, 0.36, 0.95)
	hover_style.border_width_left = 4
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)

func update_button_visual_prefix(btn: Button, text_str: String, is_hovered: bool) -> void:
	btn.text = ("  [▶]  %s" if is_hovered else "  [·]  %s") % text_str

