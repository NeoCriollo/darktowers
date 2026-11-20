class_name MapContourRenderer
extends RefCounted

## Topographic Elevation Contours, Cartographic Canvas Drawing & Projection Sub-Controller.
## Handles heightfield sampling, metric-to-pixel cartographic projections,
## and procedural 2D canvas drawing (contours, grid, POIs, Dark Tower beacon, and player marker).

var modal: MapModal = null

func _init(p_modal: MapModal = null) -> void:
	modal = p_modal

# ─── Elevation Sampling & Contours ───────────────────────────────────────────

func sample_world_elevation(world_x: float, world_z: float) -> float:
	if ClassDB.class_exists("TerrainCollisionGenerator") or ResourceLoader.exists("res://terrain_collision.gd"):
		return TerrainCollisionGenerator.sample_height(world_x, world_z)
	return 0.0

func _sample_world_elevation(world_x: float, world_z: float) -> float: return sample_world_elevation(world_x, world_z)

func build_topographic_contours() -> void:
	modal._contour_polylines.clear()
	const GRID_STEPS: int = 32
	var step_size: float = (modal.world_half_extent * 2.0) / float(GRID_STEPS)
	var thresholds: Array[float] = [-1.2, 0.0, 1.35, 2.6]

	for t_idx in range(thresholds.size()):
		var elev: float = thresholds[t_idx]
		var segments: Array[Vector2] = []
		for gz in range(GRID_STEPS):
			var z0: float = -modal.world_half_extent + gz * step_size
			var z1: float = z0 + step_size
			for gx in range(GRID_STEPS):
				var x0: float = -modal.world_half_extent + gx * step_size
				var x1: float = x0 + step_size
				var h00: float = sample_world_elevation(x0, z0)
				var h10: float = sample_world_elevation(x1, z0)
				var h01: float = sample_world_elevation(x0, z1)
				if (h00 < elev and h10 >= elev) or (h00 >= elev and h10 < elev):
					var frac_x: float = clampf((elev - h00) / maxf(0.001, absf(h10 - h00)), 0.0, 1.0)
					segments.append(Vector2(lerpf(x0, x1, frac_x), z0))
					segments.append(Vector2(lerpf(x0, x1, frac_x) + step_size * 0.45, z0 + step_size * 0.45))
				if (h00 < elev and h01 >= elev) or (h00 >= elev and h01 < elev):
					var frac_z: float = clampf((elev - h00) / maxf(0.001, absf(h01 - h00)), 0.0, 1.0)
					segments.append(Vector2(x0, lerpf(z0, z1, frac_z)))
					segments.append(Vector2(x0 + step_size * 0.45, lerpf(z0, z1, frac_z) + step_size * 0.45))
		modal._contour_polylines.append({"elevation": elev, "tier": t_idx, "segments": segments})

func _build_topographic_contours() -> void: build_topographic_contours()

# ─── Coordinate Projection Math ──────────────────────────────────────────────

func get_map_canvas_size() -> Vector2:
	if modal._map_canvas != null and modal._map_canvas.size.x > 16.0 and modal._map_canvas.size.y > 16.0:
		return modal._map_canvas.size
	if modal._map_viewport_frame != null and modal._map_viewport_frame.size.x > 16.0 and modal._map_viewport_frame.size.y > 16.0:
		return modal._map_viewport_frame.size
	return Vector2(580.0, 440.0)

func world_to_map(world_pos: Vector3, canvas_size: Vector2 = Vector2.ZERO) -> Vector2:
	var c_size: Vector2 = canvas_size if canvas_size != Vector2.ZERO else get_map_canvas_size()
	var center: Vector2 = c_size * 0.5 + modal.pan_offset
	var usable_span: float = minf(c_size.x, c_size.y) * 0.84 * modal.zoom_level
	var scale_px_per_meter: float = usable_span / maxf(1.0, modal.world_half_extent * 2.0)
	return Vector2(center.x + world_pos.x * scale_px_per_meter, center.y - world_pos.z * scale_px_per_meter)

func map_to_world(map_pos: Vector2, canvas_size: Vector2 = Vector2.ZERO) -> Vector3:
	var c_size: Vector2 = canvas_size if canvas_size != Vector2.ZERO else get_map_canvas_size()
	var center: Vector2 = c_size * 0.5 + modal.pan_offset
	var usable_span: float = minf(c_size.x, c_size.y) * 0.84 * modal.zoom_level
	var scale_px_per_meter: float = maxf(0.0001, usable_span / maxf(1.0, modal.world_half_extent * 2.0))
	var wx: float = (map_pos.x - center.x) / scale_px_per_meter
	var wz: float = -(map_pos.y - center.y) / scale_px_per_meter
	var wy: float = sample_world_elevation(wx, wz)
	return Vector3(wx, wy, wz)

func world_to_map_canvas(world_pos: Vector3, canvas_size: Vector2 = Vector2.ZERO) -> Vector2: return world_to_map(world_pos, canvas_size)
func map_canvas_to_world(map_pos: Vector2, canvas_size: Vector2 = Vector2.ZERO) -> Vector3: return map_to_world(map_pos, canvas_size)
func meters_to_pixels(meters: float, canvas_size: Vector2 = Vector2.ZERO) -> float:
	var c_size: Vector2 = canvas_size if canvas_size != Vector2.ZERO else get_map_canvas_size()
	var usable_span: float = minf(c_size.x, c_size.y) * 0.84 * modal.zoom_level
	return meters * (usable_span / maxf(1.0, modal.world_half_extent * 2.0))
func _meters_to_pixels(meters: float, canvas_size: Vector2 = Vector2.ZERO) -> float: return meters_to_pixels(meters, canvas_size)

func clamp_pan_offset(raw_offset: Vector2) -> Vector2:
	var c_size: Vector2 = get_map_canvas_size()
	var max_pan_x: float = maxf(120.0, c_size.x * 0.45 * modal.zoom_level)
	var max_pan_y: float = maxf(120.0, c_size.y * 0.45 * modal.zoom_level)
	return Vector2(clampf(raw_offset.x, -max_pan_x, max_pan_x), clampf(raw_offset.y, -max_pan_y, max_pan_y))
func _clamp_pan_offset(raw_offset: Vector2) -> Vector2: return clamp_pan_offset(raw_offset)

# ─── Procedural Canvas Drawing ────────────────────────────────────────────────

func draw_cartographic_canvas(canvas: Control) -> void:
	var c_size: Vector2 = canvas.size
	if c_size.x <= 8.0 or c_size.y <= 8.0:
		c_size = get_map_canvas_size()
		if canvas.custom_minimum_size.x < 16.0:
			canvas.custom_minimum_size = c_size
	var font: Font = modal._mono_font if modal._mono_font != null else ThemeDB.fallback_font

	canvas.draw_rect(Rect2(Vector2.ZERO, c_size), MapModal.CANVAS_BG_COLOR, true)
	draw_cartographic_grid(canvas, c_size, font)
	draw_quadrant_grid_overlay(canvas, c_size, font)
	draw_topographic_contours(canvas, c_size)
	draw_canyon_corridors_and_beam_axis(canvas, c_size)
	draw_escarpment_barriers(canvas, c_size)
	draw_regional_basins_and_fog(canvas, c_size, font)
	draw_field_pois(canvas, c_size, font)
	draw_dark_tower_beacon(canvas, c_size, font)
	draw_player_marker(canvas, c_size, font)
	draw_amber_terminal_overlay(canvas, c_size, font)

func _draw_cartographic_canvas(canvas: Control) -> void: draw_cartographic_canvas(canvas)
func draw_tactical_canvas(canvas: Control) -> void: draw_cartographic_canvas(canvas)
func _draw_tactical_canvas(canvas: Control) -> void: draw_cartographic_canvas(canvas)

func draw_cartographic_grid(canvas: Control, c_size: Vector2, font: Font) -> void:
	var step_minor: float = 250.0
	var count: int = int(round((modal.world_half_extent * 2.0) / step_minor))
	for i in range(count + 1):
		var coord_m: float = -modal.world_half_extent + i * step_minor
		var is_origin: bool = is_zero_approx(coord_m)
		var is_major: bool = (i % 2 == 0) or is_origin
		var col: Color = Color(0.92, 0.72, 0.38, 0.28) if is_origin else (MapModal.AMBER_GRID_MAJOR if is_major else MapModal.AMBER_GRID_MINOR)
		var width: float = 1.5 if is_origin else 1.0

		var v_top: Vector2 = world_to_map(Vector3(coord_m, 0.0, modal.world_half_extent), c_size)
		var v_bot: Vector2 = world_to_map(Vector3(coord_m, 0.0, -modal.world_half_extent), c_size)
		canvas.draw_line(v_top, v_bot, col, width)

		var h_left: Vector2 = world_to_map(Vector3(-modal.world_half_extent, 0.0, coord_m), c_size)
		var h_right: Vector2 = world_to_map(Vector3(modal.world_half_extent, 0.0, coord_m), c_size)
		canvas.draw_line(h_left, h_right, col, width)

		if is_major and font != null:
			var label_text: String = "%+dm" % int(coord_m)
			if v_top.x >= 28.0 and v_top.x <= c_size.x - 36.0:
				canvas.draw_string(font, Vector2(v_top.x + 3.0, clampf(v_top.y + 12.0, 14.0, c_size.y - 6.0)), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 0.72, 0.38, 0.42))
			if h_left.y >= 16.0 and h_left.y <= c_size.y - 16.0:
				canvas.draw_string(font, Vector2(clampf(h_left.x + 4.0, 6.0, c_size.x - 42.0), h_left.y - 3.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 0.72, 0.38, 0.42))

	var nw: Vector2 = world_to_map(Vector3(-modal.world_half_extent, 0.0, modal.world_half_extent), c_size)
	var se: Vector2 = world_to_map(Vector3(modal.world_half_extent, 0.0, -modal.world_half_extent), c_size)
	canvas.draw_rect(Rect2(nw, se - nw), Color(0.92, 0.72, 0.38, 0.45), false, 1.5)

func draw_quadrant_grid_overlay(canvas: Control, c_size: Vector2, font: Font) -> void:
	var q_size: float = 625.0
	var col_lines := [-625.0, 0.0, 625.0]
	var border_col := Color(1.0, 0.76, 0.35, 0.42)
	for wx in col_lines:
		var v0: Vector2 = world_to_map(Vector3(wx, 0.0, modal.world_half_extent), c_size)
		var v1: Vector2 = world_to_map(Vector3(wx, 0.0, -modal.world_half_extent), c_size)
		canvas.draw_line(v0, v1, border_col, 1.8)
	for wz in col_lines:
		var h0: Vector2 = world_to_map(Vector3(-modal.world_half_extent, 0.0, wz), c_size)
		var h1: Vector2 = world_to_map(Vector3(modal.world_half_extent, 0.0, wz), c_size)
		canvas.draw_line(h0, h1, border_col, 1.8)

	if font != null:
		var col_codes := ["A", "B", "C", "D"]
		for r in range(4):
			for c in range(4):
				var q_num: int = r * 4 + c + 1
				var min_x: float = -modal.world_half_extent + c * q_size
				var max_z: float = -modal.world_half_extent + (r + 1) * q_size
				var badge_pos: Vector2 = world_to_map(Vector3(min_x + 18.0, 0.0, max_z - 18.0), c_size)
				if badge_pos.x >= 4.0 and badge_pos.x <= c_size.x - 50.0 and badge_pos.y >= 14.0 and badge_pos.y <= c_size.y - 4.0:
					var callsign := "Q%02d [%s%d]" % [q_num, col_codes[c], r + 1]
					canvas.draw_string(font, badge_pos, callsign, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.84, 0.45, 0.52))

func draw_topographic_contours(canvas: Control, c_size: Vector2) -> void:
	if modal != null and modal._contour_polylines.is_empty():
		build_topographic_contours()
	for entry in modal._contour_polylines:
		var tier: int = int(entry.get("tier", 0))
		var col: Color = MapModal.CONTOUR_LOW_COLOR if tier == 0 else (MapModal.CONTOUR_MID_COLOR if tier == 1 else MapModal.CONTOUR_HIGH_COLOR)
		var segs: Array = entry.get("segments", [])
		var idx: int = 0
		while idx + 1 < segs.size():
			var p0_w: Vector2 = segs[idx]
			var p1_w: Vector2 = segs[idx + 1]
			var m0: Vector2 = world_to_map(Vector3(p0_w.x, 0.0, p0_w.y), c_size)
			var m1: Vector2 = world_to_map(Vector3(p1_w.x, 0.0, p1_w.y), c_size)
			canvas.draw_line(m0, m1, col, 1.2)
			idx += 2

func get_corridors() -> Array:
	if ResourceLoader.exists("res://world/world_node_graph.gd"):
		var graph_res = load("res://world/world_node_graph.gd")
		if graph_res != null and "CORRIDORS" in graph_res:
			return graph_res.CORRIDORS
	if modal != null and not modal._canyon_corridors.is_empty():
		return modal._canyon_corridors
	return []

func draw_canyon_corridors_and_beam_axis(canvas: Control, c_size: Vector2) -> void:
	var origin_map: Vector2 = world_to_map(Vector3(0.0, 0.0, 0.0), c_size)
	var mid_beam_map: Vector2 = world_to_map(Vector3(650.0, 0.0, 650.0), c_size)
	var tower_map: Vector2 = world_to_map(modal.dark_tower_world_position, c_size)
	draw_dashed_line(canvas, origin_map, mid_beam_map, Color(1.0, 0.44, 0.18, 0.55), 1.8, 8.0, 5.0)
	draw_dashed_line(canvas, mid_beam_map, tower_map, Color(1.0, 0.38, 0.12, 0.75), 2.2, 8.0, 4.0)

	var corridors := get_corridors()
	for corridor in corridors:
		var wa: Vector2 = corridor.get("a", Vector2.ZERO)
		var wb: Vector2 = corridor.get("b", Vector2.ZERO)
		var ma: Vector2 = world_to_map(Vector3(wa.x, 0.0, wa.y), c_size)
		var mb: Vector2 = world_to_map(Vector3(wb.x, 0.0, wb.y), c_size)
		var is_blocked: bool = bool(corridor.get("blocked", false))
		var is_safe: bool = String(corridor.get("hazard", "NONE")) == "NONE" or String(corridor.get("from", "")) == "waystation_sanctuary"

		if is_blocked:
			draw_dashed_line(canvas, ma, mb, Color(0.95, 0.22, 0.28, 0.85), 2.0, 6.0, 4.0)
			if corridor.has("choke"):
				var cp: Vector2 = corridor["choke"]
				var mp: Vector2 = world_to_map(Vector3(cp.x, 0.0, cp.y), c_size)
				canvas.draw_line(mp - Vector2(5.0, 5.0), mp + Vector2(5.0, 5.0), Color(0.98, 0.24, 0.30, 0.95), 2.0)
				canvas.draw_line(mp - Vector2(-5.0, 5.0), mp + Vector2(-5.0, 5.0), Color(0.98, 0.24, 0.30, 0.95), 2.0)
		else:
			var line_col: Color = Color(0.98, 0.84, 0.48, 0.65) if is_safe else Color(0.92, 0.74, 0.38, 0.45)
			draw_dashed_line(canvas, ma, mb, line_col, 1.5, 7.0, 4.0)
			if corridor.has("choke"):
				var cp: Vector2 = corridor["choke"]
				var mp: Vector2 = world_to_map(Vector3(cp.x, 0.0, cp.y), c_size)
				var choke_col: Color = Color(1.0, 0.88, 0.52, 0.90) if is_safe else Color(1.0, 0.78, 0.35, 0.75)
				canvas.draw_circle(mp, 2.5, choke_col)
				canvas.draw_arc(mp, 4.5, 0.0, TAU, 16, choke_col * Color(1.0, 1.0, 1.0, 0.5), 1.0)

func draw_escarpment_barriers(canvas: Control, c_size: Vector2) -> void:
	if not ClassDB.class_exists("TerrainCollisionGenerator") and not ResourceLoader.exists("res://terrain_collision.gd"):
		return
	var ridge_col := Color(1.0, 0.72, 0.28, 0.88)
	var hachure_col := Color(0.92, 0.64, 0.22, 0.65)
	const STEP_M: float = 18.0

	for seg in TerrainCollisionGenerator.BARRIER_SEGMENTS:
		var a := Vector2(float(seg[0]), float(seg[1]))
		var b := Vector2(float(seg[2]), float(seg[3]))
		var diff := b - a
		var len_seg := diff.length()
		if len_seg < 1.0: continue
		var dir := diff / len_seg
		var steps := int(len_seg / STEP_M)

		for s in range(steps):
			var w0 := a + dir * (float(s) * STEP_M)
			var w1 := a + dir * (float(s + 1) * STEP_M)
			var mid := (w0 + w1) * 0.5
			var d_pass := _get_min_defile_distance(mid.x, mid.y)
			if d_pass < 36.0: continue

			var m0: Vector2 = world_to_map(Vector3(w0.x, 0.0, w0.y), c_size)
			var m1: Vector2 = world_to_map(Vector3(w1.x, 0.0, w1.y), c_size)
			canvas.draw_line(m0, m1, ridge_col, 2.2)

			var m_mid := (m0 + m1) * 0.5
			var map_norm := Vector2(-(m1.y - m0.y), m1.x - m0.x).normalized()
			canvas.draw_line(m_mid, m_mid + map_norm * 3.5, hachure_col, 1.2)
			canvas.draw_line(m_mid, m_mid - map_norm * 3.5, hachure_col, 1.2)

func _get_min_defile_distance(px: float, pz: float) -> float:
	var min_d := 99999.0
	for p in TerrainCollisionGenerator.DEFILE_PASSES:
		var d: float = TerrainCollisionGenerator.segment_distance_2d(px, pz, float(p[0]), float(p[1]), float(p[2]), float(p[3]))
		if d < min_d: min_d = d
	return min_d

func draw_regional_basins_and_fog(canvas: Control, c_size: Vector2, font: Font) -> void:
	for poi_id in modal._pois.keys():
		var poi: Dictionary = modal._pois[poi_id]
		var cat: String = String(poi.get("category", ""))
		if cat != "REGION" and cat != "SANCTUARY":
			continue
		var w_pos: Vector3 = poi.get("world_pos", Vector3.ZERO)
		var map_pt: Vector2 = world_to_map(w_pos, c_size)
		var radius_px: float = maxf(18.0, meters_to_pixels(float(poi.get("radius", 250.0)), c_size))
		var discovered: bool = modal.is_poi_visible_on_map(poi_id)
		var is_selected: bool = (poi_id == modal._selected_poi_id)
		var is_sanctuary: bool = (cat == "SANCTUARY")

		if discovered:
			var ring_col: Color = MapModal.AMBER_BRIGHT if is_selected else (Color(0.98, 0.82, 0.42, 0.55) if is_sanctuary else Color(0.92, 0.72, 0.38, 0.32))
			canvas.draw_arc(map_pt, radius_px, 0.0, TAU, 48, ring_col, 2.0 if is_selected else (1.5 if is_sanctuary else 1.0))
			if is_sanctuary:
				canvas.draw_arc(map_pt, radius_px * 0.45, 0.0, TAU, 28, Color(0.98, 0.84, 0.48, 0.45), 1.0)
				canvas.draw_rect(Rect2(map_pt - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), Color(0.08, 0.07, 0.05, 0.95), true)
				canvas.draw_rect(Rect2(map_pt - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), MapModal.AMBER_BRIGHT, false, 1.5)
				canvas.draw_circle(map_pt, 2.4, MapModal.AMBER_BRIGHT)
			else:
				canvas.draw_arc(map_pt, 4.5, 0.0, TAU, 16, MapModal.AMBER_PRIMARY, 1.5)

			if font != null:
				var reg_name: String = modal.get_poi_localized_name(poi_id)
				var label_color: Color = MapModal.AMBER_BRIGHT if is_selected else (Color(1.0, 0.90, 0.60, 0.95) if is_sanctuary else Color(0.94, 0.80, 0.50, 0.88))
				canvas.draw_string(font, Vector2(map_pt.x - reg_name.length() * 3.0, map_pt.y - 8.0), reg_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, label_color)
		else:
			canvas.draw_circle(map_pt, radius_px * 0.88, MapModal.FOG_OF_WAR_COLOR)
			canvas.draw_arc(map_pt, radius_px * 0.88, 0.0, TAU, 36, Color(0.55, 0.46, 0.32, 0.22), 1.0)
			if font != null:
				canvas.draw_string(font, Vector2(map_pt.x - 12.0, map_pt.y + 4.0), "[ ? ]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.56, 0.42, 0.48))

func draw_field_pois(canvas: Control, c_size: Vector2, font: Font) -> void:
	for poi_id in modal._pois.keys():
		var poi: Dictionary = modal._pois[poi_id]
		var cat: String = String(poi.get("category", ""))
		if cat in ["REGION", "SANCTUARY", "DARK_TOWER"] or not modal.is_poi_visible_on_map(poi_id):
			continue

		var w_pos: Vector3 = poi.get("world_pos", Vector3.ZERO)
		var pt: Vector2 = world_to_map(w_pos, c_size)
		var is_sel: bool = (poi_id == modal._selected_poi_id or poi_id == modal._hovered_poi_id)
		var icon_col: Color = MapModal.AMBER_BRIGHT if is_sel else MapModal.AMBER_PRIMARY

		match cat:
			"THINNY":
				var r_px: float = maxf(12.0, meters_to_pixels(float(poi.get("radius", 160.0)), c_size))
				var pulse: float = 0.5 + 0.5 * sin(modal._pulse_time * 2.8)
				canvas.draw_circle(pt, r_px, Color(0.18, 0.04, 0.12, 0.25))
				canvas.draw_arc(pt, r_px, 0.0, TAU, 36, Color(0.95, 0.35, 0.25, 0.45 + pulse * 0.35), 1.5)
				canvas.draw_arc(pt, r_px * 0.5, 0.0, TAU, 24, Color(0.85, 0.22, 0.38, 0.35), 1.0)
				canvas.draw_line(pt + Vector2(-5, 0), pt + Vector2(5, 0), Color(1.0, 0.35, 0.35, 0.85), 1.5)
				canvas.draw_line(pt + Vector2(0, -5), pt + Vector2(0, 5), Color(1.0, 0.35, 0.35, 0.85), 1.5)
			"OUTPOST":
				var r := 5.5 if is_sel else 4.5
				canvas.draw_rect(Rect2(pt - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), Color(0.08, 0.06, 0.04, 0.92), true)
				canvas.draw_rect(Rect2(pt - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), icon_col, false, 1.5)
				canvas.draw_circle(pt, 1.8, icon_col)
			"OVERPASS":
				canvas.draw_line(pt + Vector2(-6, -3), pt + Vector2(6, -3), icon_col, 2.0)
				canvas.draw_line(pt + Vector2(-6, 3), pt + Vector2(6, 3), icon_col, 2.0)
				canvas.draw_line(pt + Vector2(-2, -5), pt + Vector2(-2, 5), icon_col, 1.2)
				canvas.draw_line(pt + Vector2(2, -5), pt + Vector2(2, 5), icon_col, 1.2)
			"CARAVAN":
				canvas.draw_arc(pt, 5.0, 0.0, TAU, 16, icon_col, 1.4)
				canvas.draw_line(pt + Vector2(-4, -4), pt + Vector2(4, 4), icon_col, 1.2)
				canvas.draw_line(pt + Vector2(-4, 4), pt + Vector2(4, -4), icon_col, 1.2)
			"MONOLITH":
				var poly := PackedVector2Array([pt + Vector2(0, -7), pt + Vector2(5, 0), pt + Vector2(0, 7), pt + Vector2(-5, 0)])
				canvas.draw_colored_polygon(poly, Color(0.18, 0.14, 0.08, 0.92))
				poly.append(pt + Vector2(0, -7))
				canvas.draw_polyline(poly, icon_col, 1.5)

		if font != null and (modal.zoom_level >= 1.15 or is_sel):
			var p_name: String = modal.get_poi_localized_name(poi_id)
			canvas.draw_string(font, pt + Vector2(8.0, 4.0), p_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, icon_col)

func draw_dark_tower_beacon(canvas: Control, c_size: Vector2, font: Font) -> void:
	var origin_pt: Vector2 = world_to_map(modal.ka_origin_world_position, c_size)
	canvas.draw_arc(origin_pt, 6.0, 0.0, TAU, 20, Color(0.92, 0.72, 0.38, 0.45), 1.0)
	canvas.draw_line(origin_pt + Vector2(-9, 0), origin_pt + Vector2(9, 0), Color(0.92, 0.72, 0.38, 0.45), 1.0)
	canvas.draw_line(origin_pt + Vector2(0, -9), origin_pt + Vector2(0, 9), Color(0.92, 0.72, 0.38, 0.45), 1.0)

	var tower_pt: Vector2 = world_to_map(modal.dark_tower_world_position, c_size)
	var pulse: float = 0.5 + 0.5 * sin(modal._pulse_time * 3.2)
	var outer_r: float = 14.0 + pulse * 6.0

	canvas.draw_circle(tower_pt, 10.0, MapModal.KA_BEACON_GLOW)
	canvas.draw_arc(tower_pt, outer_r, 0.0, TAU, 32, Color(1.0, 0.42, 0.14, 0.75 - pulse * 0.45), 1.6)
	canvas.draw_arc(tower_pt, 9.0, 0.0, TAU, 24, MapModal.AMBER_BRIGHT, 1.5)

	var d_outer := 8.5
	var d_inner := 3.6
	var star_pts := PackedVector2Array()
	for i in range(8):
		var ang: float = i * (TAU / 8.0) - PI * 0.5
		var rad: float = d_outer if (i % 2 == 0) else d_inner
		star_pts.append(tower_pt + Vector2(cos(ang), sin(ang)) * rad)
	canvas.draw_colored_polygon(star_pts, MapModal.KA_BEACON_CRIMSON)
	star_pts.append(star_pts[0])
	canvas.draw_polyline(star_pts, MapModal.AMBER_BRIGHT, 1.3)

	if font != null:
		var tower_title: String = Localization.t("MAP_POI_DARK_TOWER")
		canvas.draw_string(font, tower_pt + Vector2(-tower_title.length() * 3.2, -16.0), tower_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MapModal.AMBER_BRIGHT)

func draw_player_marker(canvas: Control, c_size: Vector2, font: Font) -> void:
	var p_pos: Vector3 = modal.get_live_player_position() if modal != null and modal.has_method("get_live_player_position") else (modal.player_world_position if modal != null else Vector3.ZERO)
	var p_yaw: float = modal.get_live_player_yaw() if modal != null and modal.has_method("get_live_player_yaw") else (modal.player_facing_yaw_rad if modal != null else 0.0)
	var p_map: Vector2 = world_to_map(p_pos, c_size)
	var forward_world := Vector2(-sin(p_yaw), -cos(p_yaw)).normalized()
	var map_dir := Vector2(forward_world.x, -forward_world.y).normalized()
	var map_right := Vector2(-map_dir.y, map_dir.x)

	var cone_len: float = 34.0
	var cone_half_w: float = 14.0
	var cone_poly := PackedVector2Array([p_map, p_map + map_dir * cone_len - map_right * cone_half_w, p_map + map_dir * cone_len + map_right * cone_half_w])
	canvas.draw_colored_polygon(cone_poly, Color(0.98, 0.82, 0.42, 0.14))
	canvas.draw_line(p_map, cone_poly[1], Color(0.98, 0.82, 0.42, 0.35), 1.0)
	canvas.draw_line(p_map, cone_poly[2], Color(0.98, 0.82, 0.42, 0.35), 1.0)

	var pulse_phase: float = fposmod(modal._pulse_time * 0.85, 1.0) if modal != null else 0.0
	var pulse_radius: float = lerpf(5.0, 22.0, pulse_phase)
	var pulse_alpha: float = (1.0 - pulse_phase) * 0.72
	canvas.draw_arc(p_map, pulse_radius, 0.0, TAU, 28, Color(0.98, 0.82, 0.42, pulse_alpha), 1.5)

	var tip: Vector2 = p_map + map_dir * 9.5
	var rear_l: Vector2 = p_map - map_dir * 6.5 - map_right * 6.0
	var rear_mid: Vector2 = p_map - map_dir * 3.2
	var rear_r: Vector2 = p_map - map_dir * 6.5 + map_right * 6.0
	var chevron := PackedVector2Array([tip, rear_l, rear_mid, rear_r])
	canvas.draw_colored_polygon(chevron, MapModal.AMBER_BRIGHT)
	chevron.append(tip)
	canvas.draw_polyline(chevron, Color(0.12, 0.08, 0.04, 0.95), 1.4)
	canvas.draw_circle(p_map, 2.2, Color(1.0, 0.96, 0.82, 1.0))

	if font != null:
		canvas.draw_string(font, p_map + Vector2(11.0, 4.0), "KA-01", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MapModal.AMBER_BRIGHT)

func draw_amber_terminal_overlay(canvas: Control, c_size: Vector2, font: Font) -> void:
	var y_line: float = 0.0
	while y_line < c_size.y:
		canvas.draw_line(Vector2(0.0, y_line), Vector2(c_size.x, y_line), Color(0.92, 0.72, 0.38, 0.025), 1.0)
		y_line += 4.0

	var compass_center := Vector2(c_size.x - 42.0, 42.0)
	canvas.draw_circle(compass_center, 24.0, Color(0.03, 0.025, 0.02, 0.88))
	canvas.draw_arc(compass_center, 24.0, 0.0, TAU, 32, Color(0.92, 0.72, 0.38, 0.55), 1.2)
	canvas.draw_line(compass_center + Vector2(0, -18), compass_center + Vector2(0, 18), MapModal.AMBER_PRIMARY, 1.2)
	canvas.draw_line(compass_center + Vector2(-18, 0), compass_center + Vector2(18, 0), MapModal.AMBER_DIM, 1.0)
	var ne_vec := Vector2(cos(-PI * 0.25), sin(-PI * 0.25))
	canvas.draw_line(compass_center, compass_center + ne_vec * 20.0, MapModal.KA_BEACON_CRIMSON, 1.5)
	if font != null:
		canvas.draw_string(font, compass_center + Vector2(-3.5, -26.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MapModal.AMBER_BRIGHT)
		canvas.draw_string(font, compass_center + Vector2(16.0, -14.0), "KA", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MapModal.KA_BEACON_CRIMSON)

	var scale_100m_px: float = clampf(meters_to_pixels(100.0, c_size), 32.0, 220.0)
	var sb_origin := Vector2(18.0, c_size.y - 18.0)
	canvas.draw_line(sb_origin, sb_origin + Vector2(scale_100m_px, 0.0), MapModal.AMBER_PRIMARY, 2.0)
	canvas.draw_line(sb_origin + Vector2(0, -4), sb_origin + Vector2(0, 4), MapModal.AMBER_PRIMARY, 1.5)
	canvas.draw_line(sb_origin + Vector2(scale_100m_px, -4), sb_origin + Vector2(scale_100m_px, 4), MapModal.AMBER_PRIMARY, 1.5)
	if font != null:
		canvas.draw_string(font, sb_origin + Vector2(4.0, -6.0), "100 m (%.1fx)" % modal.zoom_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MapModal.AMBER_PRIMARY)

func draw_dashed_line(canvas: Control, from_pt: Vector2, to_pt: Vector2, col: Color, width: float, dash_len: float, gap_len: float) -> void:
	var total_vec: Vector2 = to_pt - from_pt
	var dist: float = total_vec.length()
	if dist < 0.5:
		return
	var dir: Vector2 = total_vec / dist
	var travelled: float = 0.0
	while travelled < dist:
		var seg_end: float = minf(dist, travelled + dash_len)
		canvas.draw_line(from_pt + dir * travelled, from_pt + dir * seg_end, col, width)
		travelled += dash_len + gap_len

