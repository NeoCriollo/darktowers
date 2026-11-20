class_name PauseMenu
extends CanvasLayer

## PauseMenu: Universal Tactical Pause Menu & Editor Lighting Controller (Tasks 1 & 2)
## Allows players and builders to press "Enter" or "Esc" anytime to pause the tree,
## free the mouse cursor, manage saves, settings, developer help tools, and toggle
## the high-visibility "Sunny Day" lighting override during Editor Mode (Modo Arquitecto).

signal resumed
signal saved
signal sunny_day_toggled(active: bool)

const AMBER_GOLD := Color(0.88, 0.65, 0.28, 0.95)
const AMBER_DIM := Color(0.55, 0.40, 0.18, 0.85)
const OBSIDIAN_BG := Color(0.06, 0.05, 0.05, 0.96)
const CRIMSON_ALERT := Color(0.85, 0.25, 0.22, 0.95)

var _is_paused: bool = false
var _main_panel: PanelContainer = null
var _backdrop: ColorRect = null
var _toast_label: Label = null
var _sunny_btn: Button = null
var _settings_panel: VBoxContainer = null
var _help_panel: VBoxContainer = null
var _buttons_vbox: VBoxContainer = null
var _mode_subtitle_lbl: Label = null

func _init() -> void:
	name = "PauseMenu"
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build_ui_layout()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if code == KEY_ENTER or code == KEY_KP_ENTER:
			toggle_pause()
			get_viewport().set_input_as_handled()
			return
		elif code == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
			if _is_paused:
				if _settings_panel != null and _settings_panel.visible:
					_settings_panel.visible = false
					_buttons_vbox.visible = true
				elif _help_panel != null and _help_panel.visible:
					_help_panel.visible = false
					_buttons_vbox.visible = true
				else:
					resume_game()
				get_viewport().set_input_as_handled()
				return
			else:
				# Only capture Esc if not inside another modal
				toggle_pause()
				get_viewport().set_input_as_handled()
				return
		elif _is_paused and code == KEY_L and WorldSaveData.is_editor_mode_active():
			toggle_sunny_day()
			get_viewport().set_input_as_handled()
			return

func is_menu_open() -> bool:
	return _is_paused

func toggle_pause() -> void:
	if _is_paused:
		resume_game()
	else:
		open_pause_menu()

func open_pause_menu() -> void:
	_is_paused = true
	visible = true
	if get_tree() != null:
		get_tree().paused = true
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_ui_state()

func resume_game() -> void:
	_is_paused = false
	visible = false
	if _settings_panel != null: _settings_panel.visible = false
	if _help_panel != null: _help_panel.visible = false
	if _buttons_vbox != null: _buttons_vbox.visible = true
	if get_tree() != null:
		get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	resumed.emit()

func save_world_state() -> void:
	var serializer := WorldLayoutSerializer.new()
	var ok := serializer.save_to_json()

	# Also trigger WorldSaveData checkpoint flush if available
	if WorldSaveData.instance != null:
		WorldSaveData.instance.save_to_disk()

	if ok:
		_show_toast(Localization.t("EDITOR_TOAST_SAVE"))
		saved.emit()
	else:
		_show_toast(Localization.t("EDITOR_TOAST_SAVE_ERR"), true)

func toggle_sunny_day() -> void:
	if not WorldSaveData.is_editor_mode_active():
		return
	var env := _resolve_environment()
	if env != null:
		var active: bool = env.toggle_sunny_day_override()
		_update_sunny_day_button_label(active)
		var status_str := Localization.t("EDITOR_SUNNY_ACTIVE") if active else Localization.t("EDITOR_SUNNY_INACTIVE")
		_show_toast(Localization.t("EDITOR_TOAST_SUNNY") % status_str)
		sunny_day_toggled.emit(active)

func exit_to_main_menu() -> void:
	if WorldSaveData.is_editor_mode_active():
		var serializer := WorldLayoutSerializer.new()
		serializer.save_to_json()

	resume_game()
	if get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _resolve_environment() -> WastelandEnvironment:
	var curr := get_tree().current_scene if get_tree() != null else null
	if curr != null:
		var env := curr.find_child("WorldEnvironment", true, false) as WastelandEnvironment
		if env != null:
			return env
		var env_direct := curr.get_node_or_null("WorldEnvironment") as WastelandEnvironment
		if env_direct != null:
			return env_direct
	return null

func _build_ui_layout() -> void:
	var screen_rect := Control.new()
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_rect)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.03, 0.03, 0.78)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.is_pressed() and ev.button_index == MOUSE_BUTTON_LEFT:
			resume_game()
	)
	screen_rect.add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.add_child(center)

	_main_panel = PanelContainer.new()
	_main_panel.name = "PauseMainPanel"
	_main_panel.custom_minimum_size = Vector2(580.0, 440.0)
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = OBSIDIAN_BG
	style.border_color = AMBER_GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	_main_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_main_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_main_panel.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = Localization.t("PAUSE_HEADER_TITLE")
	title.add_theme_color_override("font_color", AMBER_GOLD)
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "[ ESC ]"
	close_btn.flat = true
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_color_override("font_color", AMBER_GOLD)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(resume_game)
	header.add_child(close_btn)
	vbox.add_child(header)

	_mode_subtitle_lbl = Label.new()
	_mode_subtitle_lbl.text = Localization.t("PAUSE_MODE_SUBTITLE_FMT") % Localization.t("PAUSE_MODE_SURVIVAL")
	_mode_subtitle_lbl.add_theme_color_override("font_color", AMBER_DIM)
	_mode_subtitle_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_mode_subtitle_lbl)

	# Separator
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(AMBER_GOLD.r, AMBER_GOLD.g, AMBER_GOLD.b, 0.3)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Action Buttons
	_buttons_vbox = VBoxContainer.new()
	_buttons_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_buttons_vbox)

	var btn_resume := _create_menu_button(Localization.t("PAUSE_BTN_RESUME"), resume_game)
	_buttons_vbox.add_child(btn_resume)

	var btn_save := _create_menu_button(Localization.t("PAUSE_BTN_SAVE"), save_world_state)
	_buttons_vbox.add_child(btn_save)

	_sunny_btn = _create_menu_button("[L] " + Localization.t("BTN_SUNNY_DAY") + ": [" + Localization.t("STATE_DEACTIVATED") + "]", toggle_sunny_day)
	_buttons_vbox.add_child(_sunny_btn)

	var btn_settings := _create_menu_button(Localization.t("PAUSE_BTN_SETTINGS"), _toggle_settings_subview)
	_buttons_vbox.add_child(btn_settings)

	var btn_help := _create_menu_button(Localization.t("PAUSE_BTN_HELP"), _toggle_help_subview)
	_buttons_vbox.add_child(btn_help)

	var btn_exit := _create_menu_button(Localization.t("PAUSE_BTN_EXIT"), exit_to_main_menu)
	_buttons_vbox.add_child(btn_exit)

	# Subpanels (Settings & Quick Help)
	_build_settings_subview(vbox)
	_build_help_subview(vbox)

	# Toast Label
	_toast_label = Label.new()
	_toast_label.text = ""
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_color", AMBER_GOLD)
	_toast_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_toast_label)

func _create_menu_button(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = "   " + label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(530.0, 38.0)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.94, 0.90, 0.84))

	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = Color(0.09, 0.08, 0.07, 0.85)
	sb_norm.border_color = Color(0.35, 0.28, 0.16, 0.7)
	sb_norm.set_border_width_all(1)
	sb_norm.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", sb_norm)

	var sb_hov := StyleBoxFlat.new()
	sb_hov.bg_color = Color(0.18, 0.14, 0.08, 0.95)
	sb_hov.border_color = AMBER_GOLD
	sb_hov.set_border_width_all(1)
	sb_hov.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("hover", sb_hov)

	btn.pressed.connect(callback)
	return btn

func _build_settings_subview(parent: VBoxContainer) -> void:
	_settings_panel = VBoxContainer.new()
	_settings_panel.add_theme_constant_override("separation", 8)
	_settings_panel.visible = false
	parent.add_child(_settings_panel)

	var lbl := Label.new()
	lbl.text = "--- AJUSTES TÁCTICOS ---"
	lbl.add_theme_color_override("font_color", AMBER_GOLD)
	lbl.add_theme_font_size_override("font_size", 12)
	_settings_panel.add_child(lbl)

	var s_btn := _create_menu_button("<< VOLVER A OPCIONES", _toggle_settings_subview)
	_settings_panel.add_child(s_btn)

func _build_help_subview(parent: VBoxContainer) -> void:
	_help_panel = VBoxContainer.new()
	_help_panel.add_theme_constant_override("separation", 6)
	_help_panel.visible = false
	parent.add_child(_help_panel)

	var help_text := Label.new()
	help_text.text = """[W/A/S/D] VUELO 6DOF  •  [SHIFT] NITRO 120 M/S  •  [ALT] PRECISIÓN
[TAB / B] CATÁLOGO DE ACTIVOS  •  [1-8] TELETRANSPORTE SECTOR
[CLICK IZQ] AGARRAR / SOLTAR  •  [SUPR / X] ELIMINAR OBJETO
[↑ / ↓] ELEVAR / HUNDIR (+/- Y)  •  [← / →] ROTAR YAW (15°)
[SHIFT + ↑/↓] PROFUNDIDAD Z  •  [ALT + ↑/↓] TILT PITCH X
[SHIFT + RUEDA] ESCALA 0.1X-30X  •  [CTRL + D] DUPLICAR"""
	help_text.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82))
	help_text.add_theme_font_size_override("font_size", 11)
	_help_panel.add_child(help_text)

	var back_btn := _create_menu_button("<< VOLVER A OPCIONES", _toggle_help_subview)
	_help_panel.add_child(back_btn)

func _toggle_settings_subview() -> void:
	if _settings_panel == null: return
	_settings_panel.visible = not _settings_panel.visible
	_help_panel.visible = false
	_buttons_vbox.visible = not _settings_panel.visible

func _toggle_help_subview() -> void:
	if _help_panel == null: return
	_help_panel.visible = not _help_panel.visible
	_settings_panel.visible = false
	_buttons_vbox.visible = not _help_panel.visible

func _refresh_ui_state() -> void:
	var is_editor: bool = WorldSaveData.is_editor_mode_active()
	if _mode_subtitle_lbl != null:
		var mode_str := Localization.t("PAUSE_MODE_EDITOR") if is_editor else Localization.t("PAUSE_MODE_SURVIVAL")
		_mode_subtitle_lbl.text = Localization.t("PAUSE_MODE_SUBTITLE_FMT") % mode_str
	if _sunny_btn != null:
		_sunny_btn.visible = is_editor
		var env := _resolve_environment()
		var is_sunny: bool = env.is_sunny_day if env != null else false
		_update_sunny_day_button_label(is_sunny)

func _update_sunny_day_button_label(active: bool) -> void:
	if _sunny_btn != null:
		var state_str := Localization.t("STATE_ACTIVATED") if active else Localization.t("STATE_DEACTIVATED")
		_sunny_btn.text = "   [L] " + Localization.t("BTN_SUNNY_DAY") + ": [" + state_str + "]"

func _show_toast(msg: String, is_err: bool = false) -> void:
	if _toast_label != null:
		_toast_label.text = msg
		_toast_label.add_theme_color_override("font_color", CRIMSON_ALERT if is_err else AMBER_GOLD)
