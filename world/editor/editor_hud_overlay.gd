class_name EditorHUDOverlay
extends CanvasLayer

## EditorHUDOverlay: Minimal Obsidian Tactical HUD for Architect Mode
## Renders:
##  1. Fixed Center Crosshair: High-contrast center aim reticle with dark halo.
##  2. Top-Left Object / Telemetry Card: Shows target node name, world position, and scale.
##  3. Bottom-Right Keybind Card: Clean vertical tactical list of context-sensitive actions.

class CenterReticleCrosshair extends Control:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 3.5, Color(0.04, 0.04, 0.04, 0.85))
		draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 1.0, 0.95))
		var pip_col := Color(1.0, 1.0, 1.0, 0.88)
		var shadow_col := Color(0.04, 0.04, 0.04, 0.75)
		var offsets = [Vector2(0, -7), Vector2(0, 7), Vector2(-7, 0), Vector2(7, 0)]
		var lengths = [Vector2(0, -4), Vector2(0, 4), Vector2(-4, 0), Vector2(4, 0)]
		for i in range(4):
			draw_line(offsets[i], offsets[i] + lengths[i], shadow_col, 2.0)
			draw_line(offsets[i], offsets[i] + lengths[i], pip_col, 1.0)

var _top_panel: PanelContainer = null
var _title_label: Label = null
var _details_label: Label = null

var _keybinds_panel: PanelContainer = null
var _keybinds_grid: GridContainer = null
var _keybinds_header: Label = null

var _crosshair: Control = null
var _toast_label: Label = null
var _toast_timer: float = 0.0

func _init() -> void:
	name = "EditorHUDOverlay"
	layer = 101 # Render cleanly above standard scene layers

func _ready() -> void:
	_build_hud_layout()

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_label != null:
			_toast_label.visible = false

func show_toast(message: String, duration: float = 2.5) -> void:
	if _toast_label != null:
		_toast_label.text = message
		_toast_label.visible = true
		_toast_timer = duration

func set_crosshair_visible(p_visible: bool) -> void:
	if _crosshair != null:
		_crosshair.visible = p_visible

func update_hud(mode: String, title: String, details: String, keybinds: Array) -> void:
	if _title_label != null:
		_title_label.text = title
	if _details_label != null:
		_details_label.text = details

	_update_keybind_rows(mode, keybinds)

## Formats the editor telemetry card + keybind list from live controller state.
func render_editor_state(palette: EditorAssetCatalogUI, manipulator: EditorManipulator, selection_mgr: EditorSelectionManager, player_ref: Node3D, cur_spd: float, speed_multiplier: float) -> void:
	var mode := "flight"
	var title := ""
	var details := ""
	var keybinds: Array = []

	if palette != null and palette.is_palette_open():
		mode = "palette"
		title = "[ CATÁLOGO DE ACTIVOS DEL HAZ ]"
		details = "SELECCIONA UN ACTIVO PARA GENERAR  |  [TAB / ESC] CERRAR"
		keybinds = [
			["[1 - 4]", "Pestaña de Categoría"],
			["[CLICK]", "Generar y Enganchar"],
			["[Q / E]", "Pestaña Anterior / Sig."],
			["[TAB / ESC]", "Cerrar Catálogo"]
		]
	elif manipulator != null and manipulator.is_grabbing():
		mode = "grabbing"
		var grabbed := manipulator.get_grabbed_node()
		var p: Vector3 = grabbed.global_position if grabbed != null else Vector3.ZERO
		var g_name: String = grabbed.name if grabbed != null else "Desconocido"
		title = "[ MOVIENDO: %s ]" % g_name
		details = "POS: (%.1f, %.1f, %.1f)  |  DISTANCIA: %.1fm" % [p.x, p.y, p.z, manipulator.get_tether_distance()]
		keybinds = [
			["[CLICK / G]", "Fijar y Colocar"], ["[ESC / DER]", "Cancelar y Soltar"],
			["[↑ / ↓]", "Elevar / Bajar (+Y / -Y)"], ["[Q / E]", "Rotar 15° (Yaw)"],
			["[← / →]", "Giro Rápido"], ["[SHIFT + RUEDA]", "Escalar Proporcional"],
			["[ALT]", "Vuelo Libre (Sin Suelo)"]
		]
	elif selection_mgr != null and not selection_mgr.get_selected_nodes().is_empty():
		mode = "selected"
		var sel := selection_mgr.get_selected_nodes()
		if sel.size() == 1:
			var sn := sel[0]
			var p: Vector3 = sn.global_position
			var s: Vector3 = sn.scale
			title = "[ SELECCIONADO: %s ]" % sn.name
			details = "POS: (%.1f, %.1f, %.1f)  |  SCALE: (%.2f, %.2f, %.2f)" % [p.x, p.y, p.z, s.x, s.y, s.z]
		else:
			var ancla: Vector3 = sel[0].global_position
			title = "[ SELECCIONADOS: %d OBJETOS ]" % sel.size()
			details = "GRUPO MULTI-SELECCIÓN  |  ANCLA: (%.1f, %.1f, %.1f)" % [ancla.x, ancla.y, ancla.z]
		keybinds = [
			["[G]", "Mover con Cámara"], ["[↑ / ↓]", "Elevar / Bajar (+Y / -Y)"],
			["[Q / E]", "Rotar 15° (Yaw)"], ["[← / →]", "Giro Rápido"],
			["[SHIFT + RUEDA]", "Escalar Objeto"], ["[CTRL + D]", "Clonar Selección"],
			["[X / SUPR]", "Eliminar Objeto"], ["[ESC / DER]", "Deseleccionar"]
		]
	elif selection_mgr != null and selection_mgr.get_hovered_node() != null:
		mode = "hover"
		var hovered := selection_mgr.get_hovered_node()
		var p: Vector3 = hovered.global_position
		var s: Vector3 = hovered.scale
		title = "[ APUNTANDO: %s ]" % hovered.name
		details = "POS: (%.1f, %.1f, %.1f)  |  SCALE: (%.2f, %.2f, %.2f)" % [p.x, p.y, p.z, s.x, s.y, s.z]
		keybinds = [
			["[CLICK IZQ]", "Seleccionar Objeto"], ["[SHIFT + CLICK]", "Añadir a Grupo"],
			["[CTRL + D]", "Clonar Rápido"], ["[X / SUPR]", "Eliminar Objeto"],
			["[TAB / B]", "Catálogo de Activos"]
		]
	else:
		mode = "flight"
		var px: float = player_ref.global_position.x if player_ref != null else 0.0
		var py: float = player_ref.global_position.y if player_ref != null else 0.0
		var pz: float = player_ref.global_position.z if player_ref != null else 0.0
		title = "[ MODO ARQUITECTO · TODASH FLIGHT ]"
		details = "VEL: %.1f m/s (%.1fx)  |  POS: (%.1f, %.1f, %.1f)" % [cur_spd, speed_multiplier, px, py, pz]
		keybinds = [
			["[CLICK IZQ]", "Seleccionar en Mira"], ["[P]", "Esquema / Outliner"],
			["[TAB / B]", "Catálogo de Activos"], ["[CTRL + S]", "Guardar Diseño JSON"],
			["[1 - 8]", "Teletransporte Sector"], ["[F]", "Ajustar al Terreno"],
			["[F6]", "Aterrizar / Modo a Pie"], ["[ESC]", "Menú de Pausa"]
		]

	update_hud(mode, title, details, keybinds)

func _update_keybind_rows(mode: String, keybinds: Array) -> void:
	if _keybinds_grid == null:
		return

	# Clear existing rows
	for child in _keybinds_grid.get_children():
		child.queue_free()

	if _keybinds_header != null:
		match mode:
			"grabbing": _keybinds_header.text = "◆ MOVIENDO OBJETO ◆"
			"selected": _keybinds_header.text = "◆ OBJETO SELECCIONADO ◆"
			"hover": _keybinds_header.text = "◆ APUNTANDO OBJETO ◆"
			_: _keybinds_header.text = "◆ COMANDOS ARQUITECTO ◆"

	for item in keybinds:
		if not (item is Array) or item.size() < 2:
			continue
		var key_str: String = str(item[0])
		var desc_str: String = str(item[1])

		var key_lbl := Label.new()
		key_lbl.text = key_str
		key_lbl.add_theme_color_override("font_color", Color(0.96, 0.82, 0.42, 1.0))
		key_lbl.add_theme_font_size_override("font_size", 11)
		_keybinds_grid.add_child(key_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = desc_str
		desc_lbl.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86, 0.92))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		_keybinds_grid.add_child(desc_lbl)

func _build_hud_layout() -> void:
	_build_center_crosshair()
	_build_top_left_panel()
	_build_bottom_right_panel()
	_build_toast_label()

func _build_center_crosshair() -> void:
	_crosshair = CenterReticleCrosshair.new()
	_crosshair.name = "CenterReticle"
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

func _build_top_left_panel() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.name = "EditorTopPill"
	_top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_top_panel.position = Vector2(24.0, 16.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.05, 0.90)
	style.border_color = Color(0.88, 0.65, 0.28, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_top_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.38, 1.0))
	_title_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_title_label)

	_details_label = Label.new()
	_details_label.name = "DetailsLabel"
	_details_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 0.95))
	_details_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_details_label)

	_top_panel.add_child(vbox)
	add_child(_top_panel)

func _build_bottom_right_panel() -> void:
	_keybinds_panel = PanelContainer.new()
	_keybinds_panel.name = "EditorKeybindsCard"
	_keybinds_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_keybinds_panel.anchor_left = 1.0
	_keybinds_panel.anchor_top = 1.0
	_keybinds_panel.anchor_right = 1.0
	_keybinds_panel.anchor_bottom = 1.0
	_keybinds_panel.offset_left = -290.0
	_keybinds_panel.offset_top = -240.0
	_keybinds_panel.offset_right = -24.0
	_keybinds_panel.offset_bottom = -24.0
	_keybinds_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_keybinds_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.05, 0.92)
	style.border_color = Color(0.88, 0.65, 0.28, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_keybinds_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	_keybinds_header = Label.new()
	_keybinds_header.name = "KeybindsHeader"
	_keybinds_header.text = "◆ COMANDOS ARQUITECTO ◆"
	_keybinds_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keybinds_header.add_theme_color_override("font_color", Color(0.96, 0.78, 0.38, 1.0))
	_keybinds_header.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_keybinds_header)

	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.88, 0.65, 0.28, 0.45)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	_keybinds_grid = GridContainer.new()
	_keybinds_grid.columns = 2
	_keybinds_grid.add_theme_constant_override("h_separation", 14)
	_keybinds_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(_keybinds_grid)

	_keybinds_panel.add_child(vbox)
	add_child(_keybinds_panel)

func _build_toast_label() -> void:
	_toast_label = Label.new()
	_toast_label.name = "ToastLabel"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.anchor_left = 0.5
	_toast_label.anchor_right = 0.5
	_toast_label.offset_left = -260.0
	_toast_label.offset_right = 260.0
	_toast_label.offset_top = 70.0
	_toast_label.offset_bottom = 98.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45, 1.0))
	_toast_label.add_theme_font_size_override("font_size", 12)
	_toast_label.visible = false

	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.04, 0.04, 0.04, 0.90)
	toast_style.border_color = Color(0.88, 0.65, 0.28, 0.90)
	toast_style.set_border_width_all(1)
	toast_style.set_corner_radius_all(3)
	_toast_label.add_theme_stylebox_override("normal", toast_style)
	add_child(_toast_label)
