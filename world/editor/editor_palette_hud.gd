class_name EditorPaletteHUD
extends EditorAssetCatalogUI

## EditorPaletteHUD: Tactical In-Game Asset Palette Drawer (Phase 3 -> Phase 7 Upgrade)
## Extends EditorAssetCatalogUI to provide full backward-compatibility for callers
## while upgrading the visual presentation from a legacy text list to the modern
## Phase 7 Visual 3D Asset Catalog Grid with isolated SubViewports, 3D rotating
## meshes, responsive tile wrapping, and amber terminal highlights (#E1A647).

# ─── Virtualized Pool Compatibility Shims ────────────────────────────────────
# EditorAssetCatalogUI replaced its per-refresh `_active_cards` array and
# `_clear_grid_cards()` with a fixed `_pooled_cards` slot pool. These shims map the
# legacy palette API onto the pool; without them this subclass fails to compile,
# which cascades into EditorFlightController and world.gd and removes the editor.

func _visible_pool_cards() -> Array[EditorAssetCard]:
	var out: Array[EditorAssetCard] = []
	for card in _pooled_cards:
		if is_instance_valid(card) and card.visible:
			out.append(card)
	return out

func _clear_grid_cards() -> void:
	_pending_thumbnails.clear()
	_current_hovered_card = null
	for card in _pooled_cards:
		if is_instance_valid(card):
			card.visible = false

# ─── Legacy Palette Signatures & Aliases ─────────────────────────────────────

func get_active_category_id() -> String:
	if _categories.is_empty() or _current_category_idx < 0 or _current_category_idx >= _categories.size():
		return "rocks"
	return _categories[_current_category_idx].get("id", "rocks")

func get_active_category_name() -> String:
	if _categories.is_empty() or _current_category_idx < 0 or _current_category_idx >= _categories.size():
		return "ROCAS FOTOGRAMÉTRICAS"
	return _categories[_current_category_idx].get("name", "ROCAS FOTOGRAMÉTRICAS")

func get_active_category_index() -> int:
	return _current_category_idx

func get_category_count() -> int:
	return _categories.size()

func get_active_card_count() -> int:
	return _visible_pool_cards().size()

func get_selected_asset_id() -> String:
	return _selected_asset_id

func is_drawer_open() -> bool:
	return is_palette_open()

func open_drawer() -> void:
	open_palette()

func close_drawer() -> void:
	close_palette()

func toggle_drawer() -> void:
	toggle_palette()

# ─── Programmatic Navigation & Selection Helpers ─────────────────────────────

func select_category_by_id(cat_id: String) -> bool:
	for i in range(_categories.size()):
		if _categories[i].get("id", "") == cat_id:
			select_category(i)
			return true
	return false

func filter_by_search_query(query: String) -> void:
	if _search_input != null:
		_search_input.text = query
	_on_search_changed(query)

func clear_search_query() -> void:
	if _search_input != null:
		_search_input.text = ""
	_on_search_changed("")

func request_asset_spawn(target_asset_id: String) -> void:
	_on_card_clicked(target_asset_id)

func get_card_for_asset(target_id: String) -> PanelContainer:
	for card in _visible_pool_cards():
		if is_instance_valid(card) and card.get("asset_id") == target_id:
			return card
	return null

func highlight_asset_card(target_id: String) -> bool:
	var found := false
	for card in _visible_pool_cards():
		if not is_instance_valid(card):
			continue
		var is_target: bool = (card.get("asset_id") == target_id)
		card.set("is_selected", is_target)
		if is_target:
			found = true
	return found

# ─── Category Metadata Query Bridge ──────────────────────────────────────────

func get_category_badge(cat_id: String) -> String:
	for cat in _categories:
		if cat.get("id", "") == cat_id:
			return cat.get("badge", "")
	return ""

func get_category_code(cat_id: String) -> String:
	for cat in _categories:
		if cat.get("id", "") == cat_id:
			return cat.get("code", "")
	return ""

func get_category_list() -> Array[Dictionary]:
	return _categories

func get_rendered_asset_ids() -> Array[String]:
	var ids: Array[String] = []
	for card in _visible_pool_cards():
		if is_instance_valid(card):
			var aid: String = card.get("asset_id")
			if not aid.is_empty():
				ids.append(aid)
	return ids

# ─── Telemetry Formatting & Status Reporting ─────────────────────────────────

func format_palette_status_text() -> String:
	var cat_name := get_active_category_name()
	var count := get_active_card_count()
	var q_str := (" (Filtro: '%s')" % _search_query) if not _search_query.is_empty() else ""
	return "[ %s ] — %d Activos Disponibles%s" % [cat_name, count, q_str]

func get_palette_diagnostics() -> Dictionary:
	return {
		"is_open": _is_open,
		"active_category_idx": _current_category_idx,
		"active_category_id": get_active_category_id(),
		"total_categories": _categories.size(),
		"search_query": _search_query,
		"rendered_cards_count": _visible_pool_cards().size(),
		"selected_asset_id": _selected_asset_id,
		"grid_columns": _items_grid.columns if _items_grid != null else 0,
		"has_search_input": _search_input != null,
		"has_grid_container": _items_grid != null,
		"has_scroll_container": _scroll_container != null
	}

func dump_palette_diagnostics() -> void:
	var diag := get_palette_diagnostics()
	print("[EditorPaletteHUD] Status: open=%s, cat=%s, cards=%d, query='%s'" % [
		diag.get("is_open", false),
		diag.get("active_category_id", "none"),
		diag.get("rendered_cards_count", 0),
		diag.get("search_query", "")
	])

# ─── Viewport Performance & Memory Guards ────────────────────────────────────

func purge_stale_previews() -> void:
	_clear_grid_cards()

func refresh_palette_display() -> void:
	_refresh_category_view()

func force_rebuild_palette_ui() -> void:
	_clear_grid_cards()
	_refresh_category_view()

# ─── Subsystem Lifecycle Hooks ───────────────────────────────────────────────

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_grid_cards()

## Static factory helper to quickly verify palette UI contract
static func create_configured_palette() -> EditorPaletteHUD:
	var hud := EditorPaletteHUD.new()
	return hud
