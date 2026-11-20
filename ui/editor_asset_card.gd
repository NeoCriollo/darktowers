class_name EditorAssetCard
extends PanelContainer

## EditorAssetCard: Modular 3D Visual Asset Tile Card (Phase 7 - Virtualized)
## Renders a lightweight static TextureRect thumbnail backed by 2-tier caching
## (Memory + user:// disk cache) and a procedural fallback while rendering.
## Fully fixed minimum size (180x210) to guarantee zero layout collapse.

signal card_clicked(asset_id: String)
signal card_hovered(asset_id: String)
signal card_unhovered(asset_id: String)

const AssetThumbnailGeneratorScript = preload("res://world/editor/asset_thumbnail_generator.gd")

const AMBER_BORDER := Color(0.88, 0.65, 0.28, 1.0) # #E1A647
const AMBER_DIM := Color(0.55, 0.40, 0.18, 0.80)
const CARD_BG_NORMAL := Color(0.08, 0.07, 0.06, 0.94)
const CARD_BG_HOVER := Color(0.14, 0.11, 0.07, 0.98)
const CARD_BG_SELECTED := Color(0.20, 0.15, 0.08, 0.98)

const PREVIEW_WIDTH: int = 168
const PREVIEW_HEIGHT: int = 130
const CARD_MIN_WIDTH: float = 180.0
const CARD_MIN_HEIGHT: float = 210.0

var asset_id: String = ""
var asset_data: Dictionary = {}
var is_selected: bool = false:
	set(val):
		is_selected = val
		_update_appearance()

var _is_hovered: bool = false
var _texture_rect: TextureRect = null
var _preview_slot: Control = null
var _title_label: Label = null
var _badge_label: Label = null
var _status_badge: Label = null
var _style_box: StyleBoxFlat = null

func _init() -> void:
	name = "EditorAssetCard"
	custom_minimum_size = Vector2(CARD_MIN_WIDTH, CARD_MIN_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _ready() -> void:
	_build_card_ui()
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func bind_asset(data: Dictionary) -> void:
	asset_data = data
	asset_id = data.get("id", "")

	if _title_label == null:
		_build_card_ui()

	var display_name: String = data.get("name", asset_id)
	_title_label.text = display_name
	_title_label.tooltip_text = display_name

	var badge_str: String = data.get("tier_badge", "")
	if badge_str.is_empty():
		badge_str = "[%s]" % data.get("material", "PROP")
	_badge_label.text = badge_str

	_apply_initial_thumbnail()
	_update_appearance()

func setup(data: Dictionary) -> void:
	bind_asset(data)

func set_thumbnail_texture(tex: Texture2D) -> void:
	if _texture_rect != null and tex != null:
		_texture_rect.texture = tex
		if _status_badge != null:
			_status_badge.visible = false

func mark_rendering_in_progress() -> void:
	if _status_badge != null:
		_status_badge.visible = true

func get_preview_slot() -> Control:
	return _preview_slot

func _apply_initial_thumbnail() -> void:
	if _texture_rect == null:
		return
	var cache_key := AssetThumbnailGeneratorScript.get_cache_key(asset_id, 128)
	if AssetThumbnailGeneratorScript.has_cached_texture(cache_key):
		_texture_rect.texture = AssetThumbnailGeneratorScript.get_cached_texture(cache_key)
		if _status_badge != null:
			_status_badge.visible = false
	else:
		_texture_rect.texture = AssetThumbnailGeneratorScript.get_procedural_placeholder(asset_id, 128)
		if _status_badge != null:
			_status_badge.visible = true

func _build_card_ui() -> void:
	if _style_box != null:
		return

	_style_box = StyleBoxFlat.new()
	_style_box.set_corner_radius_all(4)
	_style_box.content_margin_left = 6.0
	_style_box.content_margin_right = 6.0
	_style_box.content_margin_top = 6.0
	_style_box.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", _style_box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(vbox)

	# Lightweight thumbnail preview container (TextureRect instead of SubViewport)
	_preview_slot = Control.new()
	_preview_slot.name = "PreviewSlot"
	_preview_slot.custom_minimum_size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	_preview_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_preview_slot)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "ThumbnailRect"
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_preview_slot.add_child(_texture_rect)

	# Subtle "RENDERING..." status badge
	_status_badge = Label.new()
	_status_badge.name = "StatusBadge"
	_status_badge.text = "RENDERING..."
	_status_badge.add_theme_font_size_override("font_size", 9)
	_status_badge.add_theme_color_override("font_color", Color(0.88, 0.65, 0.28, 0.75))
	_status_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_status_badge.offset_left = -78.0
	_status_badge.offset_top = -18.0
	_status_badge.visible = false
	_preview_slot.add_child(_status_badge)

	# Bottom telemetry metadata
	var meta_vbox := VBoxContainer.new()
	meta_vbox.add_theme_constant_override("separation", 2)
	meta_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(meta_vbox)

	_title_label = Label.new()
	_title_label.text = "Asset Preview"
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	meta_vbox.add_child(_title_label)

	_badge_label = Label.new()
	_badge_label.text = "[TIER A]"
	_badge_label.add_theme_font_size_override("font_size", 9)
	_badge_label.add_theme_color_override("font_color", AMBER_DIM)
	_badge_label.mouse_filter = Control.MOUSE_FILTER_PASS
	meta_vbox.add_child(_badge_label)

	_update_appearance()

func _update_appearance() -> void:
	if _style_box == null:
		return

	if is_selected:
		_style_box.bg_color = CARD_BG_SELECTED
		_style_box.border_color = AMBER_BORDER
		_style_box.set_border_width_all(2)
		if _title_label != null:
			_title_label.add_theme_color_override("font_color", AMBER_BORDER)
	elif _is_hovered:
		_style_box.bg_color = CARD_BG_HOVER
		_style_box.border_color = AMBER_BORDER
		_style_box.set_border_width_all(2)
		if _title_label != null:
			_title_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		_style_box.bg_color = CARD_BG_NORMAL
		_style_box.border_color = Color(0.32, 0.26, 0.16, 0.70)
		_style_box.set_border_width_all(1)
		if _title_label != null:
			_title_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		card_clicked.emit(asset_id)

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_appearance()
	card_hovered.emit(asset_id)

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_appearance()
	card_unhovered.emit(asset_id)

func cleanup() -> void:
	pass
