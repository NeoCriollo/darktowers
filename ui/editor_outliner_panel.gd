class_name EditorOutlinerPanel
extends CanvasLayer

## EditorOutlinerPanel: Dual-Mode Object Outliner & Hierarchy Browser (Phase 6)
## Tactical amber & obsidian panel providing a searchable, sector-categorized
## tree of all world props in the wasteland with bidirectional 3D raycast sync.

signal outliner_toggled(is_open: bool)
signal prop_focus_requested(target: Node3D)

const AMBER_GOLD := Color(0.88, 0.65, 0.28, 0.95)
const AMBER_DIM := Color(0.55, 0.40, 0.18, 0.80)
const OBSIDIAN_BG := Color(0.05, 0.04, 0.04, 0.94)

const SECTOR_HUBS: Array[Dictionary] = [
	{"id": "node_0", "name": "Node 0: Mohaine Way-Bunker", "pos": Vector2(-1180.0, -1180.0)},
	{"id": "node_1", "name": "Node 1: Southwest Desolation", "pos": Vector2(-550.0, -900.0)},
	{"id": "node_2", "name": "Node 2: Dead-Creek Salt Flats", "pos": Vector2(-150.0, -550.0)},
	{"id": "node_3", "name": "Node 3: Caliche Cradle Nexus", "pos": Vector2(0.0, 0.0)},
	{"id": "node_4", "name": "Node 4: Rust-Gorge Defile", "pos": Vector2(-650.0, 50.0)},
	{"id": "node_5", "name": "Node 5: Bleached Alkali Sink", "pos": Vector2(0.0, 650.0)},
	{"id": "node_6", "name": "Node 6: The Great Shifting Erg", "pos": Vector2(650.0, 50.0)},
	{"id": "node_7", "name": "Node 7: Dark Tower Threshold", "pos": Vector2(650.0, 650.0)}
]
const CUSTOM_SECTOR_ID: String = "custom_spawns"
const CUSTOM_SECTOR_NAME: String = "Custom Spawns / Overrides"

var _is_open: bool = false
var _selection_mgr: EditorSelectionManager = null
var _world_root: Node = null
var _search_filter: String = ""

var _panel_container: PanelContainer = null
var _search_edit: LineEdit = null
var _tree: Tree = null
var _status_label: Label = null
var _unsaved_label: Label = null

var _node_to_item: Dictionary = {}
var _item_to_node: Dictionary = {}
var _sector_items: Dictionary = {}
var _is_syncing_selection: bool = false

func _init() -> void:
	name = "EditorOutlinerPanel"
	layer = 104

func _ready() -> void:
	_build_ui_layout()
	visible = false

func _process(_delta: float) -> void:
	if _is_open and DisplayServer.get_name() != "headless":
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func initialize(selection_mgr: EditorSelectionManager, world_root: Node = null) -> void:
	_selection_mgr = selection_mgr
	_world_root = world_root
	if _selection_mgr != null:
		if not _selection_mgr.selection_changed.is_connected(_on_selection_manager_changed):
			_selection_mgr.selection_changed.connect(_on_selection_manager_changed)
		if not _selection_mgr.modification_state_changed.is_connected(_on_modification_changed):
			_selection_mgr.modification_state_changed.connect(_on_modification_changed)
		if not _selection_mgr.prop_deleted.is_connected(_on_prop_deleted):
			_selection_mgr.prop_deleted.connect(_on_prop_deleted)

func is_panel_open() -> bool:
	return _is_open

func toggle_panel() -> void:
	if _is_open: close_panel()
	else: open_panel()

func open_panel() -> void:
	_is_open = true
	visible = true
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh_props()
	outliner_toggled.emit(true)

func close_panel() -> void:
	if not _is_open: return
	_is_open = false
	visible = false
	outliner_toggled.emit(false)

func handle_input(event: InputEvent) -> bool:
	if not _is_open: return false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			close_panel(); return true
		elif event.keycode == KEY_F:
			focus_selected_prop(); return true
	return false

func refresh_props() -> void:
	if _tree == null: return
	_tree.clear()
	_node_to_item.clear()
	_item_to_node.clear()
	_sector_items.clear()

	var root_item: TreeItem = _tree.create_item()

	for sector in SECTOR_HUBS:
		var s_item := _tree.create_item(root_item)
		s_item.set_text(0, "▼ " + str(sector["name"]))
		s_item.set_custom_color(0, AMBER_GOLD)
		s_item.set_selectable(0, false)
		_sector_items[str(sector["id"])] = s_item

	var custom_item := _tree.create_item(root_item)
	custom_item.set_text(0, "▼ " + CUSTOM_SECTOR_NAME)
	custom_item.set_custom_color(0, Color(0.98, 0.72, 0.32, 1.0))
	custom_item.set_selectable(0, false)
	_sector_items[CUSTOM_SECTOR_ID] = custom_item

	var all_props := _collect_all_props()
	var sector_counts: Dictionary = {}
	var visible_count: int = 0
	var filter_lower := _search_filter.strip_edges().to_lower()

	for prop in all_props:
		if prop == null or not is_instance_valid(prop): continue
		var inst_id := _resolve_instance_id(prop)
		var asset_name := _resolve_asset_name(prop)

		if not filter_lower.is_empty():
			if not inst_id.to_lower().contains(filter_lower) and not asset_name.to_lower().contains(filter_lower):
				continue

		var is_custom := _is_custom_prop(prop)
		var sector_id := _get_nearest_sector(prop.global_position, is_custom)
		var parent_item: TreeItem = _sector_items.get(sector_id, custom_item)

		var prop_item := _tree.create_item(parent_item)
		var is_mod := _selection_mgr.is_prop_modified(prop) if _selection_mgr != null else false
		prop_item.set_text(0, "  ▫ %s%s" % [inst_id, " ●" if is_mod else ""])
		prop_item.set_custom_color(0, Color(1.0, 0.88, 0.45, 1.0) if is_mod else Color(0.85, 0.85, 0.85, 0.95))
		prop_item.set_metadata(0, prop)
		_node_to_item[prop] = prop_item
		_item_to_node[prop_item] = prop
		sector_counts[sector_id] = sector_counts.get(sector_id, 0) + 1
		visible_count += 1

	for s_id in _sector_items:
		var item: TreeItem = _sector_items[s_id]
		var count: int = sector_counts.get(s_id, 0)
		var base_name: String = CUSTOM_SECTOR_NAME if s_id == CUSTOM_SECTOR_ID else _get_sector_name(s_id)
		item.set_text(0, "▼ %s (%d)" % [base_name, count])
		item.collapsed = (not filter_lower.is_empty() and count == 0)

	if _status_label != null:
		_status_label.text = "PROPS VISIBLES: %d / %d" % [visible_count, all_props.size()]
	_update_unsaved_indicator()

	if _selection_mgr != null and _selection_mgr.get_selected_node() != null:
		_sync_selection_to_tree(_selection_mgr.get_selected_node())

func focus_selected_prop() -> void:
	if _tree == null: return
	var selected_item := _tree.get_selected()
	if selected_item == null or not _item_to_node.has(selected_item): return
	var node: Node3D = _item_to_node[selected_item]
	if node != null and is_instance_valid(node):
		prop_focus_requested.emit(node)
		if _selection_mgr != null: _selection_mgr.request_focus(node)

func _collect_all_props() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var seen: Dictionary = {}
	var root: Node = _world_root if _world_root != null else (get_tree().current_scene if (is_inside_tree() and get_tree() != null) else null)
	if root != null:
		_gather_candidate_props(root, result, seen)
	return result

func _gather_candidate_props(parent: Node, out_props: Array[Node3D], seen: Dictionary) -> void:
	if parent == null or parent.is_in_group("player") or _is_terrain_name(parent.name):
		return
	if parent is Node3D and parent != self:
		var p3d := parent as Node3D
		if _is_selectable_prop(p3d) and not seen.has(p3d):
			seen[p3d] = true
			out_props.append(p3d)
			return
	for child in parent.get_children():
		_gather_candidate_props(child, out_props, seen)

func _is_selectable_prop(node: Node3D) -> bool:
	if node == null or _is_terrain_name(node.name) or node.is_in_group("player") or node.name.begins_with("_Editor"):
		return false
	if node.has_meta("catalog_asset_id") or node.has_meta("asset_path") or node.has_meta("instance_id"):
		return true
	if node.name.begins_with("EditorProp_") or node.name.begins_with("CustomProp_") or node.name.begins_with("Q01_"):
		return true
	var p := node.get_parent()
	return p != null and (p.name.begins_with("Vignettes_") or p.name.begins_with("Sector_") or p.name == "PropScatter")

func _is_terrain_name(n: String) -> bool:
	var l := n.to_lower()
	return l.contains("terrain") or l.contains("ground") or l.contains("generator")

func _is_custom_prop(node: Node3D) -> bool:
	return node.has_meta("asset_path") or node.has_meta("is_custom") or node.name.begins_with("CustomProp_")

func _get_nearest_sector(pos: Vector3, is_custom: bool) -> String:
	if is_custom: return CUSTOM_SECTOR_ID
	var best_id := "node_0"
	var min_dist_sq := INF
	var pos_2d := Vector2(pos.x, pos.z)
	for hub in SECTOR_HUBS:
		var d_sq := pos_2d.distance_squared_to(hub["pos"])
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			best_id = str(hub["id"])
	return best_id

func _get_sector_name(sector_id: String) -> String:
	for hub in SECTOR_HUBS:
		if hub["id"] == sector_id: return str(hub["name"])
	return sector_id

func _resolve_instance_id(node: Node3D) -> String:
	if node.has_meta("prop_uuid"): return str(node.get_meta("prop_uuid"))
	return str(node.get_meta("instance_id")) if node.has_meta("instance_id") else node.name

func _resolve_asset_name(node: Node3D) -> String:
	if node.has_meta("catalog_asset_id"): return str(node.get_meta("catalog_asset_id"))
	return node.name.replace("EditorProp_", "").replace("CustomProp_", "")

func _on_tree_item_selected() -> void:
	if _is_syncing_selection or _tree == null: return
	var sel := _tree.get_selected()
	if sel == null or not _item_to_node.has(sel): return
	var node: Node3D = _item_to_node[sel]
	if node != null and is_instance_valid(node) and _selection_mgr != null:
		_is_syncing_selection = true
		_selection_mgr.select_prop(node)
		_is_syncing_selection = false

func _on_selection_manager_changed(target: Node3D) -> void:
	if _is_syncing_selection or not _is_open: return
	_sync_selection_to_tree(target)

func _sync_selection_to_tree(target: Node3D) -> void:
	if _tree == null: return
	if target == null or not is_instance_valid(target):
		_tree.deselect_all(); return
	var item: TreeItem = _node_to_item.get(target, null)
	if item != null:
		_is_syncing_selection = true
		var p := item.get_parent()
		if p != null: p.collapsed = false
		item.select(0)
		_tree.scroll_to_item(item)
		_is_syncing_selection = false

func _on_modification_changed() -> void:
	_update_unsaved_indicator()
	for node in _node_to_item:
		if node != null and is_instance_valid(node):
			var item: TreeItem = _node_to_item[node]
			var is_mod := _selection_mgr.is_prop_modified(node) if _selection_mgr != null else false
			var inst_id := _resolve_instance_id(node)
			item.set_text(0, "  ▫ %s%s" % [inst_id, " ●" if is_mod else ""])
			item.set_custom_color(0, Color(1.0, 0.88, 0.45, 1.0) if is_mod else Color(0.85, 0.85, 0.85, 0.95))

func _on_prop_deleted(_deleted_node: Node3D) -> void:
	refresh_props()

func _update_unsaved_indicator() -> void:
	if _unsaved_label == null: return
	var count: int = _selection_mgr.get_modified_count() if _selection_mgr != null else 0
	_unsaved_label.text = "● %d SIN GUARDAR" % count
	_unsaved_label.visible = count > 0

func _build_ui_layout() -> void:
	_panel_container = PanelContainer.new()
	_panel_container.name = "OutlinerPanelRoot"
	_panel_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel_container.anchor_left = 1.0
	_panel_container.anchor_right = 1.0
	_panel_container.offset_left = -330.0
	_panel_container.offset_right = -14.0
	_panel_container.offset_top = 16.0
	_panel_container.offset_bottom = 560.0
	_panel_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = OBSIDIAN_BG
	panel_style.border_color = AMBER_GOLD
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(3)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	_panel_container.add_theme_stylebox_override("panel", panel_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "◆ ESQUEMA / OUTLINER [P] ◆"
	title_lbl.add_theme_color_override("font_color", AMBER_GOLD)
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	_unsaved_label = Label.new()
	_unsaved_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 1.0))
	_unsaved_label.add_theme_font_size_override("font_size", 10)
	_unsaved_label.visible = false
	header.add_child(_unsaved_label)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", AMBER_GOLD)
	close_btn.pressed.connect(close_panel)
	header.add_child(close_btn)
	main_vbox.add_child(header)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Filtrar por nombre o ID... (rock, bunker)"
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(func(t: String): _search_filter = t; refresh_props())
	_search_edit.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	var edit_style := StyleBoxFlat.new()
	edit_style.bg_color = Color(0.08, 0.07, 0.07, 0.95)
	edit_style.border_color = AMBER_DIM
	edit_style.set_border_width_all(1)
	_search_edit.add_theme_stylebox_override("normal", edit_style)
	main_vbox.add_child(_search_edit)

	_tree = Tree.new()
	_tree.name = "OutlinerTree"
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_tree_item_selected)
	_tree.item_activated.connect(focus_selected_prop)
	var tree_style := StyleBoxFlat.new()
	tree_style.bg_color = Color(0.04, 0.04, 0.04, 0.85)
	_tree.add_theme_stylebox_override("panel", tree_style)
	main_vbox.add_child(_tree)

	var toolbar := HBoxContainer.new()
	_status_label = Label.new()
	_status_label.text = "PROPS: 0"
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0.90))
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_status_label)

	var focus_btn := Button.new()
	focus_btn.text = "[F] Enfocar"
	focus_btn.add_theme_color_override("font_color", AMBER_GOLD)
	focus_btn.add_theme_font_size_override("font_size", 10)
	focus_btn.pressed.connect(focus_selected_prop)
	toolbar.add_child(focus_btn)

	var refresh_btn := Button.new()
	refresh_btn.text = "↻"
	refresh_btn.add_theme_color_override("font_color", AMBER_GOLD)
	refresh_btn.pressed.connect(refresh_props)
	toolbar.add_child(refresh_btn)
	main_vbox.add_child(toolbar)

	_panel_container.add_child(main_vbox)
	add_child(_panel_container)
