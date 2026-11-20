class_name EditorAssetCatalogUI
extends CanvasLayer

## EditorAssetCatalogUI: Visual 3D Asset Catalog Grid (Phase 7 - Virtualized Pool)
## Fixed pool of reusable EditorAssetCard UI slots inside _items_grid.
## Cross-category global search fallback, 2-tier caching, and isolated shared 3D turntable.

signal asset_spawn_requested(asset_id: String)
signal palette_closed
signal category_selected(category_id: String)

const EditorAssetCatalogScript = preload("res://world/editor/editor_asset_catalog.gd")
const EditorFolderScannerScript = preload("res://world/editor/editor_folder_scanner.gd")
const EditorAssetCardScript = preload("res://ui/editor_asset_card.gd")
const AssetThumbnailGeneratorScript = preload("res://world/editor/asset_thumbnail_generator.gd")

const AMBER_GOLD := Color(0.88, 0.65, 0.28, 0.95) # #E1A647
const AMBER_DIM := Color(0.55, 0.40, 0.18, 0.80)
const OBSIDIAN_BG := Color(0.05, 0.04, 0.04, 0.94)

var _is_open: bool = false
var _current_category_idx: int = 0
var _categories: Array[Dictionary] = []
var _search_query: String = ""
var _selected_asset_id: String = ""

var _main_panel: PanelContainer = null
var _tab_container: HBoxContainer = null
var _search_input: LineEdit = null
var _scroll_container: ScrollContainer = null
var _items_grid: GridContainer = null
var _status_label: Label = null
var _tab_buttons: Array[Button] = []
var _empty_label: Label = null

# Fixed UI Slot Pool & Stagger Queue
var _pooled_cards: Array[EditorAssetCard] = []
var _pending_thumbnails: Array[Dictionary] = []
var _is_generating_thumbnails: bool = false

# Single Shared 3D Hover Viewport Rig
var _hover_viewport_container: SubViewportContainer = null
var _hover_viewport: SubViewport = null
var _hover_pivot: Node3D = null
var _hover_camera: Camera3D = null
var _current_hovered_card: EditorAssetCard = null

func _init() -> void:
	name = "EditorAssetCatalogUI"
	layer = 105

func _ready() -> void:
	_categories = EditorAssetCatalogScript.get_categories()
	_build_ui_layout()
	_setup_shared_hover_rig()
	visible = false

func _process(delta: float) -> void:
	if _is_open and DisplayServer.get_name() != "headless":
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _is_open and _hover_pivot != null and _current_hovered_card != null:
		AssetThumbnailGeneratorScript.apply_spin_step(_hover_pivot, delta, 1.4)

func is_palette_open() -> bool:
	return _is_open

func open_palette() -> void:
	_is_open = true
	visible = true
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_category_view()

func close_palette() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	_detach_hover_rig()
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	palette_closed.emit()

func toggle_palette() -> void:
	if _is_open:
		close_palette()
	else:
		open_palette()

func cycle_category(direction: int) -> void:
	if _categories.is_empty():
		return
	_current_category_idx = (_current_category_idx + direction) % _categories.size()
	if _current_category_idx < 0:
		_current_category_idx += _categories.size()
	_refresh_category_view()

func select_category(index: int) -> void:
	if index >= 0 and index < _categories.size():
		_current_category_idx = index
		_refresh_category_view()

func handle_input(event: InputEvent) -> bool:
	if not _is_open:
		return false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if event.is_action_pressed("toggle_editor_catalog") or code == KEY_TAB or code == KEY_B or code == KEY_ESCAPE:
			close_palette()
			return true
		elif event.keycode == KEY_Q:
			cycle_category(-1)
			return true
		elif event.keycode == KEY_E:
			cycle_category(1)
			return true
		elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
			select_category(event.keycode - KEY_1)
			return true
	return false

func _build_ui_layout() -> void:
	var screen_rect := Control.new()
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_rect)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.50)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.is_pressed() and ev.button_index == MOUSE_BUTTON_LEFT:
			close_palette()
	)
	screen_rect.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.add_child(center)

	_main_panel = PanelContainer.new()
	_main_panel.name = "AssetCatalogPanel"
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.custom_minimum_size = Vector2(800.0, 520.0)

	var style := StyleBoxFlat.new()
	style.bg_color = OBSIDIAN_BG
	style.border_color = AMBER_GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_main_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_main_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_main_panel.add_child(vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)

	var title_lbl := Label.new()
	title_lbl.text = "◆ CATÁLOGO VISUAL 3D — THE BEAM PALETTE"
	title_lbl.add_theme_color_override("font_color", AMBER_GOLD)
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Filtrar activos..."
	_search_input.custom_minimum_size = Vector2(180.0, 24.0)
	_search_input.add_theme_font_size_override("font_size", 11)
	_search_input.text_changed.connect(_on_search_changed)
	header_hbox.add_child(_search_input)

	var close_btn := Button.new()
	close_btn.text = "[ ESC ]"
	close_btn.flat = true
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_color_override("font_color", AMBER_GOLD)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(close_palette)
	header_hbox.add_child(close_btn)
	vbox.add_child(header_hbox)

	_tab_container = HBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_tab_container)
	_build_category_tabs()

	_scroll_container = ScrollContainer.new()
	_scroll_container.custom_minimum_size = Vector2(760.0, 400.0)
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll_container)

	_items_grid = GridContainer.new()
	_items_grid.columns = 4
	_items_grid.add_theme_constant_override("h_separation", 12)
	_items_grid.add_theme_constant_override("v_separation", 12)
	_items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_items_grid)

	_empty_label = Label.new()
	_empty_label.name = "CatalogEmptyLabel"
	_empty_label.add_theme_color_override("font_color", AMBER_DIM)
	_empty_label.add_theme_font_size_override("font_size", 12)
	_empty_label.visible = false
	_scroll_container.add_child(_empty_label)

	var footer_hbox := HBoxContainer.new()
	footer_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_status_label = Label.new()
	_status_label.text = "MOSTRANDO: 0 ACTIVOS"
	_status_label.add_theme_color_override("font_color", AMBER_DIM)
	_status_label.add_theme_font_size_override("font_size", 11)
	footer_hbox.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(spacer)

	var footer_keys := Label.new()
	footer_keys.text = "[Q/E] PESTAÑAS  •  [1-4] CATEGORÍAS  •  [CLICK] GENERAR Y ENGANCHAR"
	footer_keys.add_theme_color_override("font_color", AMBER_DIM)
	footer_keys.add_theme_font_size_override("font_size", 11)
	footer_hbox.add_child(footer_keys)
	vbox.add_child(footer_hbox)

func _setup_shared_hover_rig() -> void:
	_hover_viewport_container = SubViewportContainer.new()
	_hover_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_viewport_container.stretch = true
	_hover_viewport_container.visible = false
	_hover_viewport_container.custom_minimum_size = Vector2(168.0, 130.0)

	_hover_viewport = SubViewport.new()
	_hover_viewport.size = Vector2i(168, 130)
	_hover_viewport.own_world_3d = true
	_hover_viewport.transparent_bg = false
	_hover_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_hover_viewport_container.add_child(_hover_viewport)

func _build_category_tabs() -> void:
	_tab_buttons.clear()
	for i in range(_categories.size()):
		var cat: Dictionary = _categories[i]
		var btn := Button.new()
		btn.text = "[%d] %s" % [i + 1, cat.get("code", cat.get("name", "CAT"))]
		btn.custom_minimum_size = Vector2(160.0, 28.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 11)
		var cat_idx := i
		btn.pressed.connect(func(): select_category(cat_idx))
		_tab_container.add_child(btn)
		_tab_buttons.append(btn)

func _refresh_category_view() -> void:
	if _categories.is_empty() or _items_grid == null:
		return

	for i in range(_tab_buttons.size()):
		var btn := _tab_buttons[i]
		if i == _current_category_idx:
			btn.add_theme_color_override("font_color", AMBER_GOLD)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.18, 0.14, 0.08, 0.95); sb.border_color = AMBER_GOLD
			sb.set_border_width_all(1); sb.set_corner_radius_all(3)
			btn.add_theme_stylebox_override("normal", sb)
		else:
			btn.add_theme_color_override("font_color", AMBER_DIM)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.08, 0.07, 0.07, 0.70); sb.border_color = Color(0.30, 0.25, 0.18, 0.50)
			sb.set_border_width_all(1); sb.set_corner_radius_all(3)
			btn.add_theme_stylebox_override("normal", sb)

	_detach_hover_rig()

	var cur_cat: Dictionary = _categories[_current_category_idx]
	var cat_id: String = cur_cat.get("id", "")
	category_selected.emit(cat_id)

	var query := _search_query.strip_edges().to_lower()
	var matching_assets: Array[Dictionary] = []

	if query.is_empty():
		matching_assets = EditorAssetCatalogScript.get_assets_in_category(cat_id)
	else:
		# Search in current category first
		var cat_assets := EditorAssetCatalogScript.get_assets_in_category(cat_id)
		for asset in cat_assets:
			if _matches_query(asset, query):
				matching_assets.append(asset)
		# Cross-category global fallback if 0 matches in current category
		if matching_assets.is_empty():
			for cat_info in _categories:
				var c_id: String = cat_info.get("id", "")
				if c_id == cat_id: continue
				for asset in EditorAssetCatalogScript.get_assets_in_category(c_id):
					if _matches_query(asset, query):
						matching_assets.append(asset)

	if _status_label != null:
		_status_label.text = "MOSTRANDO: %d ACTIVOS" % matching_assets.size()

	if matching_assets.is_empty():
		if _empty_label != null:
			_empty_label.visible = true
			if cat_id == "custom":
				_empty_label.text = "  [ CARPETA CUSTOM VACÍA ]\n  Agrega archivos .glb en res://assets/custom_props/"
			else:
				_empty_label.text = "  [ SIN RESULTADOS PARA LA BÚSQUEDA ]"
		for card in _pooled_cards:
			card.visible = false
		return

	if _empty_label != null:
		_empty_label.visible = false

	# Ensure pool capacity in _items_grid
	while _pooled_cards.size() < matching_assets.size():
		var new_card: EditorAssetCard = EditorAssetCardScript.new()
		_items_grid.add_child(new_card)
		new_card.card_clicked.connect(_on_card_clicked)
		new_card.card_hovered.connect(func(aid: String): _on_card_hovered(new_card, aid))
		new_card.card_unhovered.connect(func(_aid: String): _on_card_unhovered(new_card))
		_pooled_cards.append(new_card)

	_pending_thumbnails.clear()

	# Bind matching data into UI slots
	for i in range(matching_assets.size()):
		var asset: Dictionary = matching_assets[i]
		var card: EditorAssetCard = _pooled_cards[i]
		card.visible = true
		card.bind_asset(asset)

		var ckey := AssetThumbnailGeneratorScript.get_cache_key(asset.get("id", ""), 128)
		if not AssetThumbnailGeneratorScript.has_cached_texture(ckey):
			_pending_thumbnails.append({"card": card, "asset": asset})

	# Hide excess pooled slots
	for k in range(matching_assets.size(), _pooled_cards.size()):
		_pooled_cards[k].visible = false

	_start_staggered_thumbnail_baking()

func _matches_query(asset: Dictionary, query: String) -> bool:
	var n: String = asset.get("name", "").to_lower()
	var aid: String = asset.get("id", "").to_lower()
	var mat: String = asset.get("material", "").to_lower()
	return n.contains(query) or aid.contains(query) or mat.contains(query)

func _start_staggered_thumbnail_baking() -> void:
	if _is_generating_thumbnails or _pending_thumbnails.is_empty():
		return
	_is_generating_thumbnails = true
	while not _pending_thumbnails.is_empty():
		var task: Dictionary = _pending_thumbnails.pop_front()
		var card: EditorAssetCard = task.get("card", null)
		var asset: Dictionary = task.get("asset", {})
		var aid: String = asset.get("id", "")
		if is_instance_valid(card) and not aid.is_empty() and card.visible:
			var tex: Texture2D = await AssetThumbnailGeneratorScript.bake_static_thumbnail_async(self, aid, asset, 128)
			if tex != null and is_instance_valid(card) and card.asset_id == aid:
				card.set_thumbnail_texture(tex)
		if get_tree() != null:
			await get_tree().process_frame
	_is_generating_thumbnails = false

func _on_card_hovered(card: EditorAssetCard, aid: String) -> void:
	_current_hovered_card = card
	var slot := card.get_preview_slot()
	if slot != null:
		var rig := AssetThumbnailGeneratorScript.setup_preview_rig(_hover_viewport, aid, card.asset_data)
		_hover_pivot = rig.get("pivot", null)
		_hover_camera = rig.get("camera", null)

		# Wait for one rendered frame before revealing to prevent black flicker
		if get_tree() != null:
			await RenderingServer.frame_post_draw

		if _current_hovered_card == card:
			if _hover_viewport_container.get_parent() != slot:
				if _hover_viewport_container.get_parent() != null:
					_hover_viewport_container.get_parent().remove_child(_hover_viewport_container)
				slot.add_child(_hover_viewport_container)
			_hover_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_hover_viewport_container.visible = true

func _on_card_unhovered(card: EditorAssetCard) -> void:
	if _current_hovered_card == card:
		_detach_hover_rig()

func _detach_hover_rig() -> void:
	_current_hovered_card = null
	if _hover_viewport_container != null:
		_hover_viewport_container.visible = false
		if _hover_viewport_container.get_parent() != null:
			_hover_viewport_container.get_parent().remove_child(_hover_viewport_container)
	if _hover_viewport != null:
		for child in _hover_viewport.get_children():
			child.queue_free()
	_hover_pivot = null
	_hover_camera = null

func _on_card_clicked(target_asset_id: String) -> void:
	_selected_asset_id = target_asset_id
	close_palette()
	asset_spawn_requested.emit(target_asset_id)

func _on_search_changed(new_text: String) -> void:
	_search_query = new_text
	_refresh_category_view()
