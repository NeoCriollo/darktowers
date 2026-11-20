class_name MainMenu
extends Node3D

## Pre-Game Front-End Controller — "Dark Towers: The Path of Ka"
## Modular Front-End Coordinator. Delegates The Gate splash & Prologue sequence to
## MenuGateSequence, and Settings / Chronicles / Localization to MenuSettingsController.

signal gate_completed()
signal menu_action_triggered(action_name: String)
signal prologue_started()
signal prologue_completed()
signal language_changed(new_language: String)

enum FrontEndPhase { THE_GATE, THE_CROSSROADS, THE_PROLOGUE, TRANSITIONING }

const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"
const SAVE_FILE_PATH: String = "user://path_of_ka_save.cfg"
const TRANSLATIONS: Dictionary = Localization.TRANSLATIONS
const GATE_EPIGRAPH: String = "The man in black fled across the desert, and the gunslinger followed..."
const GATE_STAGES: Array[String] = [
	"CHAMBER I — SURVEYING ALKALI FLATS", "CHAMBER II — MEASURING BAROMETRIC SILICA DRIFT",
	"CHAMBER III — INDEXING SANDALWOOD & BLUED STEEL", "CHAMBER IV — ALIGNING THE GREAT MONOLITH AXIS",
	"CHAMBER V — LOADING .45 LONG COLT BRASS", "CHAMBER VI — FULL BATTERY. THE PATH OF KA AWAITS."
]
const PROLOGUE_PASSAGES: Array[String] = [
	"For forty days the alkali salt has eaten the heels from your boots. Ahead, the valley narrows into the Caliche Cradle—where overturned caravans and collapsed transit spans lie bleached beneath a burning copper sky.",
	"At the northeastern rim rises the Dark Tower. Its unshaded beacon burns through the silica drift, pulling compass needles and tired men alike along the ancient axis of Ka.",
	"Your canteen is dry. Six rounds of .45 Long Colt rest in the sandalwood iron at your hip, and the trade wind is already rising into a grit-laden gale.\n\nGuard the cylinder. Steady your breath. Step into the dust."
]
const CHRONICLES_ENTRIES: Array[Dictionary] = [
	{"title": "I. THE CALICHE CRADLE", "subtitle": "Topological Survey — Sector 01", "body": "An alkali basin scoured by northeast trade winds..."},
	{"title": "II. SANDALWOOD & BLUED STEEL", "subtitle": "The Frontier Single-Action Iron (.45 Long Colt)", "body": "A firearm in the waste is not an abstraction; it is a mechanical covenant..."},
	{"title": "III. THE DARK TOWER MONOLITH", "subtitle": "Horizon Anomaly — Bearing 045° NE", "body": "Rising eighty-five meters above the northeastern ridge..."},
	{"title": "IV. METABOLISM & THE WEIGHT OF PURSUIT", "subtitle": "Physiological Field Notes", "body": "Sprinting across loose dune crests rapidly depletes oxygen reserves..."}
]

# --- EXPORTED CONFIGURATION ---
@export_group("The Gate (Splash & Loading)")
@export var gate_duration_seconds: float = 5.5
@export var allow_skip_gate_after_seconds: float = 0.5
@export var use_threaded_world_preload: bool = false

@export_group("The Crossroads (3D Twilight Camera)")
@export var camera_base_position: Vector3 = Vector3(-1196.0, 4.5, -1194.0)
@export var camera_look_target: Vector3 = Vector3(-1140.0, 2.5, -1140.0)
@export var camera_pan_amplitude_x: float = 1.8
@export var camera_pan_amplitude_y: float = 0.35
@export var camera_pan_speed: float = 0.08
@export var enable_tower_orbit: bool = false
@export var orbit_speed: float = 0.02
@export var orbit_radius: float = 45.0
@export var orbit_height: float = 5.0
@export var orbit_target: Vector3 = Vector3(-1180.0, 1.5, -1180.0)

@export_group("The Prologue (Narrative Intro)")
@export var enable_prologue_on_new_game: bool = true
@export var typewriter_chars_per_second: float = 38.0

# --- NODE REFERENCES ---
@onready var preview_camera: Camera3D = get_node_or_null("CrossroadsBackdrop/CrossroadsCamera") as Camera3D
@onready var twilight_sun: DirectionalLight3D = get_node_or_null("CrossroadsBackdrop/TwilightSun") as DirectionalLight3D; @onready var ka_beacon_light: OmniLight3D = get_node_or_null("CrossroadsBackdrop/DarkTowerMonolith/KaBeacon/BeaconLight") as OmniLight3D
@onready var ui_layer: CanvasLayer = get_node_or_null("UILayer") as CanvasLayer; @onready var gate_overlay: Control = get_node_or_null("UILayer/GateOverlay") as Control
@onready var gate_header_label: Label = get_node_or_null("UILayer/GateOverlay/CenterContainer/VBox/HeaderTag") as Label; @onready var gate_quote_label: Label = get_node_or_null("UILayer/GateOverlay/CenterContainer/VBox/QuoteRow/QuoteLabel") as Label
@onready var gate_cursor_label: Label = get_node_or_null("UILayer/GateOverlay/CenterContainer/VBox/QuoteRow/AmberCursor") as Label; @onready var gate_stage_label: Label = get_node_or_null("UILayer/GateOverlay/CenterContainer/VBox/StageLabel") as Label
@onready var gate_chamber_readout: Label = get_node_or_null("UILayer/GateOverlay/CenterContainer/VBox/ChamberReadoutLabel") as Label
@onready var cylinder_indicator: Control = get_node_or_null("UILayer/GateOverlay/CenterContainer/VBox/CylinderHost/CylinderIndicator") as Control; @onready var silica_line_indicator: Control = get_node_or_null("UILayer/GateOverlay/CenterContainer/VBox/SilicaLineIndicator") as Control

@onready var crossroads_overlay: Control = get_node_or_null("UILayer/CrossroadsOverlay") as Control
@onready var location_tag_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/TopTelemetryBar/TelemetryRow/LocationTag") as Label; @onready var atmosphere_tag_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/TopTelemetryBar/TelemetryRow/AtmosphereTag") as Label
@onready var title_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/TitleBlock/TitleLabel") as Label; @onready var subtitle_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/TitleBlock/SubtitleLabel") as Label
@onready var epigraph_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/TitleBlock/EpigraphLabel") as Label
@onready var btn_begin_journey: Button = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/NavVBox/BtnBeginJourney") as Button; @onready var btn_resume_path: Button = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/NavVBox/BtnResumePath") as Button
@onready var btn_chronicles: Button = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/NavVBox/BtnChronicles") as Button; @onready var btn_editor: Button = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/NavVBox/BtnEditor") as Button
@onready var btn_settings: Button = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/NavVBox/BtnSettings") as Button; @onready var btn_quit: Button = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/NavVBox/BtnQuit") as Button; @onready var nav_status_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/LeftColumn/NavStatusLabel") as Label

@onready var chronicles_modal: PanelContainer = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/ChroniclesModal") as PanelContainer
@onready var chronicles_modal_title: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/ChroniclesModal/Margin/VBox/HeaderRow/ModalTitle") as Label
@onready var chronicles_entry_title: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/ChroniclesModal/Margin/VBox/EntryTitle") as Label; @onready var chronicles_entry_subtitle: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/ChroniclesModal/Margin/VBox/EntrySubtitle") as Label
@onready var chronicles_entry_body: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/ChroniclesModal/Margin/VBox/EntryBody") as Label; @onready var chronicles_tabs_hbox: HBoxContainer = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/ChroniclesModal/Margin/VBox/TabsHBox") as HBoxContainer
@onready var btn_close_chronicles: Button = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/ChroniclesModal/Margin/VBox/HeaderRow/BtnCloseChronicles") as Button

@onready var settings_modal: PanelContainer = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal") as PanelContainer
@onready var settings_modal_title: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/HeaderRow/ModalTitle") as Label
@onready var language_row: HBoxContainer = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/LanguageRow") as HBoxContainer; @onready var language_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/LanguageRow/Label") as Label
@onready var language_option: OptionButton = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/LanguageRow/LanguageOption") as OptionButton; @onready var language_cycle_button: Button = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/LanguageRow/BtnCycleLanguage") as Button
@onready var master_vol_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/MasterVolRow/Label") as Label; @onready var master_vol_slider: HSlider = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/MasterVolRow/MasterVolSlider") as HSlider; @onready var master_vol_value: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/MasterVolRow/MasterVolValue") as Label
@onready var wind_vol_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/WindVolRow/Label") as Label; @onready var wind_vol_slider: HSlider = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/WindVolRow/WindVolSlider") as HSlider; @onready var wind_vol_value: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/WindVolRow/WindVolValue") as Label
@onready var taa_check: CheckButton = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/GraphicsRow/TaaCheck") as CheckButton; @onready var fog_check: CheckButton = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/GraphicsRow/FogCheck") as CheckButton
@onready var controls_header_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/ControlsHeader") as Label; @onready var controls_body_label: Label = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/ControlsBody") as Label
@onready var btn_close_settings: Button = get_node_or_null("UILayer/CrossroadsOverlay/MarginContainer/MainColumns/RightColumn/SettingsModal/Margin/VBox/HeaderRow/BtnCloseSettings") as Button

@onready var prologue_overlay: Control = get_node_or_null("UILayer/PrologueOverlay") as Control; @onready var parchment_canvas: Control = get_node_or_null("UILayer/PrologueOverlay/CenterContainer/ParchmentTablet/ParchmentCanvas") as Control
@onready var prologue_header_label: Label = get_node_or_null("UILayer/PrologueOverlay/CenterContainer/ParchmentTablet/Margin/VBox/HeaderLabel") as Label; @onready var prologue_title_label: Label = get_node_or_null("UILayer/PrologueOverlay/CenterContainer/ParchmentTablet/Margin/VBox/TitleLabel") as Label; @onready var prologue_body_label: Label = get_node_or_null("UILayer/PrologueOverlay/CenterContainer/ParchmentTablet/Margin/VBox/BodyScroll/BodyLabel") as Label
@onready var prologue_progress_label: Label = get_node_or_null("UILayer/PrologueOverlay/CenterContainer/ParchmentTablet/Margin/VBox/FooterRow/ProgressLabel") as Label
@onready var btn_prologue_advance: Button = get_node_or_null("UILayer/PrologueOverlay/CenterContainer/ParchmentTablet/Margin/VBox/FooterRow/BtnAdvancePrologue") as Button; @onready var btn_prologue_skip: Button = get_node_or_null("UILayer/PrologueOverlay/CenterContainer/ParchmentTablet/Margin/VBox/FooterRow/BtnSkipPrologue") as Button

@onready var wind_audio_player: AudioStreamPlayer = get_node_or_null("WindAudioPlayer") as AudioStreamPlayer
@onready var sfx_audio_player: AudioStreamPlayer = get_node_or_null("SfxAudioPlayer") as AudioStreamPlayer

# --- RUNTIME STATE ---
var current_phase: FrontEndPhase = FrontEndPhase.THE_GATE
var current_language: String = Localization.DEFAULT_LANGUAGE
var gate_progress: float = 0.0; var _gate_elapsed: float = 0.0; var _last_chamber_indexed: int = 0
var _cursor_pulse_time: float = 0.0; var _camera_time: float = 0.0
var _serif_font: SystemFont = null; var _mono_font: SystemFont = null
var _active_chronicle_index: int = 0; var _active_nav_status_key: String = "STATUS_STANDBY"
var _hovered_nav_button: Button = null; var _updating_language_controls: bool = false
var _prologue_full_text: String = ""; var _prologue_visible_chars: int = 0; var _prologue_char_accum: float = 0.0
var _prologue_pause_timer: float = 0.0; var _prologue_is_finished_typing: bool = false; var _prologue_camera_push: float = 0.0

# Procedural audio state
const AUDIO_MIX_RATE: float = 44100.0
var _wind_playback: AudioStreamGeneratorPlayback = null
var _wind_phase_sub: float = 0.0; var _wind_phase_fifth: float = 0.0; var _wind_gust_phase: float = 0.0
var _brown_noise_state: float = 0.0; var _lp_filter_state: float = 0.0
var _sfx_playback: AudioStreamGeneratorPlayback = null; var _sfx_queue: Array[float] = []

# Sub-Controllers
var _gate_seq: MenuGateSequence = null
var _settings_ctrl: MenuSettingsController = null
var _cinematic_tour: MenuCinematicTour = null

func _init() -> void:
	_gate_seq = MenuGateSequence.new(self)
	_settings_ctrl = MenuSettingsController.new(self)
	_cinematic_tour = MenuCinematicTour.new(self)

func _ready() -> void:
	if DisplayServer.get_name() != "headless": Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Localization.register_listener(_on_external_language_changed)
	current_language = Localization.load_language_preference(SAVE_FILE_PATH)
	_init_typography(); _configure_window_and_root_scaling()
	_ensure_gate_ui_hierarchy(); _setup_crossroads_ui(); _setup_prologue_ui()
	_init_procedural_audio()
	if _cinematic_tour != null: _cinematic_tour.setup_tour()
	_start_gate_sequence(); _refresh_localized_ui()
	_request_world_preload()

func _request_world_preload() -> void:
	if ResourceLoader.exists(WORLD_SCENE_PATH):
		var status := ResourceLoader.load_threaded_get_status(WORLD_SCENE_PATH)
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(WORLD_SCENE_PATH, "PackedScene", true)

func _exit_tree() -> void:
	Localization.unregister_listener(_on_external_language_changed)

func _process(delta: float) -> void:
	_pump_wind_drone_audio()
	_pump_sfx_audio()
	_update_camera_pan(delta)
	match current_phase:
		FrontEndPhase.THE_GATE: _process_gate_phase(delta)
		FrontEndPhase.THE_PROLOGUE: _process_prologue_phase(delta)

func _input(event: InputEvent) -> void:
	if current_phase == FrontEndPhase.THE_GATE:
		if _gate_seq != null and _gate_seq.handle_gate_input(event):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if current_phase == FrontEndPhase.THE_GATE:
		if _gate_seq != null and _gate_seq.handle_gate_input(event):
			get_viewport().set_input_as_handled()
	elif current_phase == FrontEndPhase.THE_CROSSROADS:
		if _cinematic_tour != null and _cinematic_tour.handle_input(event):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
			if chronicles_modal != null and chronicles_modal.visible:
				chronicles_modal.visible = false; play_cylinder_index_sfx(2); get_viewport().set_input_as_handled()
			elif settings_modal != null and settings_modal.visible:
				settings_modal.visible = false; play_cylinder_index_sfx(2); get_viewport().set_input_as_handled()
	elif current_phase == FrontEndPhase.THE_PROLOGUE:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
			if code == KEY_ESCAPE: _finish_prologue_and_enter_world(); get_viewport().set_input_as_handled()
			elif code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]: _on_prologue_advance_pressed(); get_viewport().set_input_as_handled()

# ─── Typography & Layout Scaling ─────────────────────────────────────────────

func _init_typography() -> void:
	_serif_font = SystemFont.new(); _serif_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Palatino", "Times New Roman", "Serif"]); _serif_font.font_weight = 400
	_mono_font = SystemFont.new(); _mono_font.font_names = PackedStringArray(["JetBrains Mono", "Menlo", "Monaco", "Courier New", "Monospace"]); _mono_font.font_weight = 500

func _configure_window_and_root_scaling() -> void:
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)
	_apply_responsive_anchors_and_wrapping()

func _apply_responsive_anchors_and_wrapping() -> void:
	for root_ctrl: Control in [gate_overlay, crossroads_overlay, prologue_overlay]:
		if root_ctrl != null: root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var labels: Array[Label] = [epigraph_label, nav_status_label, chronicles_entry_title, chronicles_entry_subtitle, chronicles_entry_body, prologue_header_label, prologue_title_label, prologue_body_label, gate_quote_label]
	for lbl in labels:
		if lbl != null: lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _on_viewport_size_changed() -> void:
	_apply_responsive_anchors_and_wrapping()
	if parchment_canvas != null: parchment_canvas.queue_redraw()
	if cylinder_indicator != null: cylinder_indicator.queue_redraw()
	if silica_line_indicator != null: silica_line_indicator.queue_redraw()

# ─── Crossroads Navigation & Actions ─────────────────────────────────────────

func _setup_crossroads_ui() -> void:
	var labels: Array[Array] = [
		[title_label, _serif_font], [subtitle_label, _mono_font], [epigraph_label, _serif_font],
		[nav_status_label, _mono_font], [location_tag_label, _mono_font], [atmosphere_tag_label, _mono_font]
	]
	for p in labels:
		if p[0] != null and p[1] != null: p[0].add_theme_font_override("font", p[1])

	var btns: Array[Button] = [btn_begin_journey, btn_resume_path, btn_chronicles, btn_editor, btn_settings, btn_quit]
	for b in btns:
		if b == null: continue
		if _serif_font != null: b.add_theme_font_override("font", _serif_font)
		_apply_diegetic_button_style(b, b == btn_begin_journey)

	if btn_begin_journey != null:
		btn_begin_journey.mouse_entered.connect(_on_begin_journey_hovered)
		btn_begin_journey.focus_entered.connect(_on_begin_journey_hovered)
		btn_begin_journey.mouse_exited.connect(func() -> void: if _hovered_nav_button == btn_begin_journey: _hovered_nav_button = null; _update_button_visual_prefix(btn_begin_journey, tr_ui("MENU_BEGIN_JOURNEY"), false))
		btn_begin_journey.pressed.connect(_on_begin_journey_pressed)

	_wire_nav_btn(btn_resume_path, "MENU_RESUME_PATH", 2, "STATUS_RESUME_HAS_SAVE", _on_resume_path_pressed)
	_wire_nav_btn(btn_chronicles, "MENU_CHRONICLES", 3, "STATUS_CHRONICLES_HOVER", _on_chronicles_pressed)
	_wire_nav_btn(btn_editor, "MENU_EDITOR", 4, "STATUS_EDITOR_HOVER", _on_editor_pressed)
	_wire_nav_btn(btn_settings, "MENU_SETTINGS", 5, "STATUS_SETTINGS_HOVER", _on_settings_pressed)
	_wire_nav_btn(btn_quit, "MENU_QUIT", 6, "STATUS_QUIT_HOVER", _on_quit_pressed)

	_setup_chronicles_modal()
	_setup_settings_modal()

func _wire_nav_btn(btn: Button, tr_key: String, sfx_chamber: int, status_key: String, action: Callable) -> void:
	if btn == null: return
	btn.mouse_entered.connect(func() -> void:
		play_cylinder_index_sfx(sfx_chamber); _hovered_nav_button = btn; _update_button_visual_prefix(btn, tr_ui(tr_key), true)
		_set_nav_status_by_key(status_key)
	)
	btn.mouse_exited.connect(func() -> void:
		if _hovered_nav_button == btn: _hovered_nav_button = null; _update_button_visual_prefix(btn, tr_ui(tr_key), false)
	)
	btn.pressed.connect(action)

func _on_begin_journey_hovered() -> void:
	play_hammer_cock_sfx(); _hovered_nav_button = btn_begin_journey
	_update_button_visual_prefix(btn_begin_journey, tr_ui("MENU_BEGIN_JOURNEY"), true)
	_set_nav_status_by_key("STATUS_BEGIN_HOVER")

func _set_nav_status_by_key(key: String) -> void:
	_active_nav_status_key = key
	if nav_status_label != null: nav_status_label.text = tr_ui(key)

func _on_begin_journey_pressed() -> void:
	play_hammer_cock_sfx(); menu_action_triggered.emit("BEGIN_JOURNEY")
	WorldSaveData.set_editor_mode_active(false)
	if enable_prologue_on_new_game and prologue_overlay != null: start_prologue()
	else: begin_journey()

func _on_resume_path_pressed() -> void:
	play_hammer_cock_sfx(); menu_action_triggered.emit("RESUME_PATH")
	WorldSaveData.set_editor_mode_active(false)
	if FileAccess.file_exists(SAVE_FILE_PATH): begin_journey()
	else:
		_set_nav_status_by_key("STATUS_NO_SAVE_PROLOGUE")
		if enable_prologue_on_new_game and prologue_overlay != null: start_prologue()
		else: begin_journey()

func _on_chronicles_pressed() -> void:
	play_cylinder_index_sfx(3); menu_action_triggered.emit("CHRONICLES")
	if settings_modal != null: settings_modal.visible = false
	if chronicles_modal != null:
		chronicles_modal.visible = not chronicles_modal.visible
		if chronicles_modal.visible: _select_chronicle_entry(_active_chronicle_index)

func _on_editor_pressed() -> void:
	play_cylinder_index_sfx(4); menu_action_triggered.emit("EDITOR_MODE")
	WorldSaveData.set_editor_mode_active(true)
	begin_journey()

func _on_settings_pressed() -> void:
	play_cylinder_index_sfx(5); menu_action_triggered.emit("SETTINGS")
	if chronicles_modal != null: chronicles_modal.visible = false
	if settings_modal != null: settings_modal.visible = not settings_modal.visible

func _on_quit_pressed() -> void:
	play_cylinder_index_sfx(6); menu_action_triggered.emit("QUIT")
	if get_tree() != null: get_tree().quit()

func begin_journey() -> void:
	if current_phase == FrontEndPhase.TRANSITIONING: return
	current_phase = FrontEndPhase.TRANSITIONING
	_record_journey_save_marker()
	_poll_and_transition_to_world()

func _poll_and_transition_to_world() -> void:
	if not ResourceLoader.exists(WORLD_SCENE_PATH):
		return

	var status := ResourceLoader.load_threaded_get_status(WORLD_SCENE_PATH)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(WORLD_SCENE_PATH, "PackedScene", true)

	if nav_status_label != null:
		nav_status_label.text = "THE PATH OF KA — LOADING WASTELAND..."

	while true:
		var progress: Array = []
		status = ResourceLoader.load_threaded_get_status(WORLD_SCENE_PATH, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene := ResourceLoader.load_threaded_get(WORLD_SCENE_PATH) as PackedScene
			if packed_scene != null and get_tree() != null:
				get_tree().change_scene_to_packed(packed_scene)
			return
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# Fallback to direct file loading if threaded loading fails
			if get_tree() != null:
				get_tree().change_scene_to_file(WORLD_SCENE_PATH)
			return

		var pct: int = int(round((progress[0] if progress.size() > 0 else 0.0) * 100.0))
		if nav_status_label != null:
			nav_status_label.text = "THE PATH OF KA — LOADING WASTELAND (%d%%)..." % pct
		if gate_stage_label != null and gate_overlay != null and gate_overlay.visible:
			gate_stage_label.text = "CHAMBER VI — ENTERING WASTELAND (%d%%)" % pct

		await get_tree().process_frame

func _record_journey_save_marker() -> void:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(SAVE_FILE_PATH): cfg.load(SAVE_FILE_PATH)
	cfg.set_value("journey", "sector", "waystation_sanctuary"); cfg.set_value("journey", "active", true)
	cfg.set_value("checkpoint", "sector_id", "waystation_sanctuary")
	cfg.set_value("checkpoint", "region_name", "The Mohaine Way-Bunker")
	cfg.set_value("checkpoint", "position_x", -1020.0); cfg.set_value("checkpoint", "position_z", -820.0)
	cfg.set_value("checkpoint", "is_explicit_save", false)
	cfg.set_value("settings", "language", current_language); cfg.set_value("settings", "locale", current_language)
	cfg.set_value("localization", "language", current_language); cfg.save(SAVE_FILE_PATH)

# ─── Camera Motion & Drawing ─────────────────────────────────────────────────

func _update_camera_pan(delta: float) -> void:
	_camera_time += delta
	if _cinematic_tour != null:
		_cinematic_tour.process_tour(delta)
	elif preview_camera != null and preview_camera.is_inside_tree():
		var pan := Vector3(sin(_camera_time * camera_pan_speed) * camera_pan_amplitude_x, cos(_camera_time * camera_pan_speed * 0.65) * camera_pan_amplitude_y, cos(_camera_time * camera_pan_speed * 0.45) * 2.4 - (_prologue_camera_push * 10.0))
		preview_camera.position = camera_base_position + pan
		preview_camera.look_at(camera_look_target + Vector3(sin(_camera_time * camera_pan_speed * 0.5) * 3.0, cos(_camera_time * camera_pan_speed * 0.8) * 0.6, 0.0), Vector3.UP)
	if ka_beacon_light != null: ka_beacon_light.light_energy = 7.5 + 2.8 * sin(_camera_time * 1.9)

func _draw_cylinder_indicator() -> void:
	if _gate_seq != null: _gate_seq.draw_cylinder(cylinder_indicator, gate_progress)

func _draw_silica_line_indicator() -> void:
	if _gate_seq != null: _gate_seq.draw_silica_line(silica_line_indicator, gate_progress)

# ─── Procedural Audio Synthesis ──────────────────────────────────────────────

func _init_procedural_audio() -> void:
	if DisplayServer.get_name() == "headless": return
	if wind_audio_player == null:
		wind_audio_player = AudioStreamPlayer.new(); wind_audio_player.name = "WindAudioPlayer"; add_child(wind_audio_player)
	var wind_gen := AudioStreamGenerator.new(); wind_gen.mix_rate = AUDIO_MIX_RATE; wind_gen.buffer_length = 0.15
	wind_audio_player.stream = wind_gen; wind_audio_player.volume_db = -9.5; wind_audio_player.play()
	_wind_playback = wind_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

	if sfx_audio_player == null:
		sfx_audio_player = AudioStreamPlayer.new(); sfx_audio_player.name = "SfxAudioPlayer"; add_child(sfx_audio_player)
	var sfx_gen := AudioStreamGenerator.new(); sfx_gen.mix_rate = AUDIO_MIX_RATE; sfx_gen.buffer_length = 0.12
	sfx_audio_player.stream = sfx_gen; sfx_audio_player.volume_db = -3.0; sfx_audio_player.play()
	_sfx_playback = sfx_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _pump_wind_drone_audio() -> void:
	if _wind_playback == null: return
	var avail: int = _wind_playback.get_frames_available()
	if avail <= 0: return
	var inv: float = 1.0 / AUDIO_MIX_RATE
	for _i in range(avail):
		_wind_phase_sub = fmod(_wind_phase_sub + 55.0 * inv, 1.0)
		_wind_phase_fifth = fmod(_wind_phase_fifth + 82.41 * inv, 1.0)
		_wind_gust_phase = fmod(_wind_gust_phase + 0.14 * inv, 1.0)
		var gust: float = 0.55 + 0.45 * sin(_wind_gust_phase * TAU)
		var drone: float = sin(_wind_phase_sub * TAU) * 0.24 + sin(_wind_phase_fifth * TAU) * 0.11
		_brown_noise_state = clampf((_brown_noise_state + 0.025 * randf_range(-1.0, 1.0)) / 1.025, -1.0, 1.0)
		_lp_filter_state += (0.04 + 0.05 * gust) * (_brown_noise_state - _lp_filter_state)
		var samp: float = clampf((drone * 0.65 + _lp_filter_state * 0.85 * gust) * 0.45, -0.95, 0.95)
		_wind_playback.push_frame(Vector2(samp, samp))

func _pump_sfx_audio() -> void:
	if _sfx_playback == null: return
	var avail: int = _sfx_playback.get_frames_available()
	if avail <= 0: return
	for _i in range(avail):
		var s: float = _sfx_queue.pop_front() if not _sfx_queue.is_empty() else 0.0
		_sfx_playback.push_frame(Vector2(s, s))

func play_typewriter_tick_sfx(char_idx: int = 0) -> void:
	if DisplayServer.get_name() == "headless" or _sfx_queue.size() > 1400: return
	var n: int = int(AUDIO_MIX_RATE * 0.012); var pitch: float = 780.0 + float((char_idx * 37) % 180)
	for i in range(n):
		var t: float = float(i) / AUDIO_MIX_RATE
		var tap: float = sin(t * pitch * TAU) * 0.35 + randf_range(-0.35, 0.35) * 0.65
		_sfx_queue.append(clampf(tap * exp(-t * 260.0) * 0.28, -0.8, 0.8))

func play_cylinder_index_sfx(chamber_idx: int = 1) -> void:
	if DisplayServer.get_name() == "headless": return
	var n: int = int(AUDIO_MIX_RATE * 0.045); var f: float = 1350.0 + float(chamber_idx) * 65.0
	for i in range(n):
		var t: float = float(i) / AUDIO_MIX_RATE
		var met: float = sin(t * f * TAU) * 0.55 + sin(t * (f * 2.41) * TAU) * 0.35 + randf_range(-0.4, 0.4) * exp(-t * 260.0)
		_sfx_queue.append(clampf(met * exp(-t * 95.0) * 0.65, -0.95, 0.95))

func play_hammer_cock_sfx() -> void:
	if DisplayServer.get_name() == "headless": return
	_sfx_queue.clear()
	var n: int = int(AUDIO_MIX_RATE * 0.11)
	for i in range(n):
		var t: float = float(i) / AUDIO_MIX_RATE
		var c1: float = (sin(t * 1180.0 * TAU) * 0.6 + sin(t * 2740.0 * TAU) * 0.4) * exp(-t * 110.0)
		var c2: float = 0.0
		if t >= 0.042:
			var t2: float = t - 0.042
			var thud: float = sin(t2 * 420.0 * TAU) * 0.45 + sin(t2 * 1890.0 * TAU) * 0.55 + randf_range(-0.5, 0.5) * exp(-t2 * 220.0)
			c2 = thud * exp(-t2 * 75.0)
		_sfx_queue.append(clampf((c1 * 0.65 + c2 * 0.90), -0.95, 0.95))

# ─── Delegated Gate & Settings Callbacks ─────────────────────────────────────

func _ensure_gate_ui_hierarchy() -> void: _gate_seq.ensure_gate_ui_hierarchy()
func _get_localized_gate_stages() -> Array[String]: return _gate_seq.get_localized_gate_stages()
func _get_localized_prologue_passages() -> Array[String]: return _gate_seq.get_localized_prologue_passages()
func _start_gate_sequence() -> void: _gate_seq.start_gate_sequence()
func _process_gate_phase(delta: float) -> void: _gate_seq.process_gate_phase(delta)
func _update_chamber_telemetry(chambers: int) -> void: _gate_seq.update_chamber_telemetry(chambers)
func _complete_gate_immediately() -> void: _finish_gate_sequence()
func _on_gate_sequence_finished() -> void: _finish_gate_sequence()
func _finish_gate_sequence() -> void:
	if _gate_seq != null: _gate_seq.finish_gate_sequence()
	else: begin_journey()
func _setup_prologue_ui() -> void: _gate_seq.setup_prologue_ui()
func start_prologue() -> void: _gate_seq.start_prologue()
func _process_prologue_phase(delta: float) -> void: _gate_seq.process_prologue_phase(delta)
func _mark_prologue_typing_complete() -> void: _gate_seq.mark_prologue_typing_complete()
func _on_prologue_advance_pressed() -> void: _gate_seq.on_prologue_advance_pressed()
func _finish_prologue_and_enter_world() -> void: _gate_seq.finish_prologue_and_enter_world()
func _draw_parchment_tablet() -> void: _gate_seq.draw_parchment_tablet()

func _setup_chronicles_modal() -> void: _settings_ctrl.setup_chronicles_modal()
func _rebuild_chronicles_tabs() -> void: _settings_ctrl.rebuild_chronicles_tabs()
func _get_localized_chronicles_entries() -> Array[Dictionary]: return _settings_ctrl.get_localized_chronicles_entries()
func _select_chronicle_entry(idx: int) -> void: _settings_ctrl.select_chronicle_entry(idx)
func _setup_settings_modal() -> void: _settings_ctrl.setup_settings_modal()
func _ensure_language_controls_in_settings() -> void: _settings_ctrl.ensure_language_controls_in_settings()
func _on_language_option_selected(idx: int) -> void: _settings_ctrl.on_language_option_selected(idx)
func _on_language_cycle_pressed() -> void: _settings_ctrl.on_language_cycle_pressed()
func _on_external_language_changed(lang: String) -> void: _settings_ctrl.on_external_language_changed(lang)
func tr_ui(key: String) -> String: return _settings_ctrl.tr_ui(key)
func get_language() -> String: return _settings_ctrl.get_language()
func set_language(lang: String, persist: bool = true) -> String: return _settings_ctrl.set_language(lang, persist)
func cycle_language(persist: bool = true) -> String: return _settings_ctrl.cycle_language(persist)
func _refresh_localized_ui() -> void:
	_settings_ctrl.refresh_localized_ui()
	if _cinematic_tour != null:
		_cinematic_tour.refresh_telemetry_labels()
func _apply_diegetic_button_style(btn: Button, is_pri: bool = false) -> void: _settings_ctrl.apply_diegetic_button_style(btn, is_pri)
func _update_button_visual_prefix(btn: Button, txt: String, is_hov: bool) -> void: _settings_ctrl.update_button_visual_prefix(btn, txt, is_hov)
