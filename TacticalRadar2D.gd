class_name TacticalRadar2D
extends Control

## Diegetic Tactical Radar Minimap — "Glass & Iron" Tactical HUD
## Renders a real-time circular vector radar display in the top-right corner with:
## - Topographic contour lines & elevation defiles from MapModal/TerrainCollisionGenerator
## - Concentric range rings, cardinal ticks, and rotating CRT sweep wedge
## - Dynamic player blip with directional FOV cone aligned to 3D yaw
## - Ka Beacon & landmark POIs with edge clamping
## - Real-time compass heading and elevation telemetry footer

@export var radar_radius: float = 64.0
@export var world_view_radius: float = 180.0 ## World units covered from player center
@export var sweep_speed_rpm: float = 24.0

var player_pos: Vector3 = Vector3.ZERO
var player_heading: float = 0.0
var sweep_angle: float = 0.0

# Cached map contour data passed from WorldManager / MapModal or sampled locally
var cached_contours: Array = []
var cached_landmarks: Array = [
	{"name": "Dark Tower Ka", "pos": Vector2(700.0, 700.0), "type": "beacon"},
	{"name": "Waystation Bunker", "pos": Vector2(-1000.0, -800.0), "type": "sanctuary"},
	{"name": "SW Desolation", "pos": Vector2(-550.0, -900.0), "type": "basin"},
	{"name": "Dead-Creek Salt", "pos": Vector2(-150.0, -550.0), "type": "basin"},
	{"name": "Caliche Cradle", "pos": Vector2(0.0, 0.0), "type": "basin"},
	{"name": "Quebrada Óxido", "pos": Vector2(-650.0, 50.0), "type": "gorge"},
	{"name": "Cuenca Álcali", "pos": Vector2(0.0, 650.0), "type": "flat"},
	{"name": "Great Erg", "pos": Vector2(650.0, 50.0), "type": "dunes"},
	{"name": "Threshold Dark Tower", "pos": Vector2(650.0, 650.0), "type": "pass"}
]

const COLOR_BG := Color(0.04, 0.035, 0.03, 0.88)
const COLOR_BORDER := Color(0.92, 0.72, 0.38, 0.75)
const COLOR_GRID := Color(0.92, 0.72, 0.38, 0.20)
const COLOR_CONTOUR_LOW := Color(0.62, 0.50, 0.32, 0.25)
const COLOR_CONTOUR_MID := Color(0.82, 0.65, 0.36, 0.35)
const COLOR_CONTOUR_HIGH := Color(0.95, 0.76, 0.42, 0.48)
const COLOR_SWEEP := Color(0.92, 0.72, 0.38, 0.12)
const COLOR_BLIP := Color(1.0, 0.85, 0.50, 0.95)
const COLOR_BEACON := Color(1.0, 0.36, 0.14, 0.95)

# Dark-Tower Western Minimalist HUD Palette
const COLOR_OBSIDIAN_PILL := Color(0.0627, 0.051, 0.0392, 0.75)  ## rgba(16, 13, 10, 0.75)
const COLOR_BRONZE_HAIRLINE := Color(0.549, 0.427, 0.231, 0.90) ## #8c6d3b
const COLOR_BONE_WHITE := Color(0.957, 0.937, 0.902, 1.0)        ## #f4efe6
const COLOR_AMBER_WARM := Color(0.847, 0.608, 0.251, 1.0)        ## #d89b40

var _heading_pill_style: StyleBoxFlat = null

func _ready() -> void:
	custom_minimum_size = Vector2(radar_radius * 2.0 + 16.0, radar_radius * 2.0 + 36.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading_pill_style = StyleBoxFlat.new()
	_heading_pill_style.bg_color = COLOR_OBSIDIAN_PILL
	_heading_pill_style.border_color = COLOR_BRONZE_HAIRLINE
	_heading_pill_style.set_border_width_all(1)
	_heading_pill_style.set_corner_radius_all(9)
	_ensure_default_contours()

func _process(delta: float) -> void:
	sweep_angle = fposmod(sweep_angle + (sweep_speed_rpm * TAU / 60.0) * delta, TAU)
	queue_redraw()

func update_player_transform(pos: Vector3, heading: float) -> void:
	player_pos = pos
	player_heading = heading
	queue_redraw()

func set_contour_data(contours: Array) -> void:
	cached_contours = contours
	queue_redraw()

func set_landmarks_data(landmarks: Array) -> void:
	cached_landmarks = landmarks
	queue_redraw()

func _ensure_default_contours() -> void:
	if not cached_contours.is_empty():
		return
	# Sample elevation contours across the 2500m x 2500m map if TerrainCollisionGenerator is available
	const GRID_STEPS: int = 24
	const WORLD_HALF: float = 1250.0
	var step_size: float = (WORLD_HALF * 2.0) / float(GRID_STEPS)
	var thresholds: Array[float] = [-1.2, 0.0, 1.35, 2.6]

	for t_idx in range(thresholds.size()):
		var elev: float = thresholds[t_idx]
		var segments: Array[Vector2] = []
		for gz in range(GRID_STEPS):
			var z0: float = -WORLD_HALF + gz * step_size
			var z1: float = z0 + step_size
			for gx in range(GRID_STEPS):
				var x0: float = -WORLD_HALF + gx * step_size
				var x1: float = x0 + step_size
				var h00: float = _sample_elevation(x0, z0)
				var h10: float = _sample_elevation(x1, z0)
				var h01: float = _sample_elevation(x0, z1)

				if (h00 < elev and h10 >= elev) or (h00 >= elev and h10 < elev):
					var frac_x: float = clampf((elev - h00) / maxf(0.001, absf(h10 - h00)), 0.0, 1.0)
					segments.append(Vector2(lerpf(x0, x1, frac_x), z0))
					segments.append(Vector2(lerpf(x0, x1, frac_x) + step_size * 0.45, z0 + step_size * 0.45))
				if (h00 < elev and h01 >= elev) or (h00 >= elev and h01 < elev):
					var frac_z: float = clampf((elev - h00) / maxf(0.001, absf(h01 - h00)), 0.0, 1.0)
					segments.append(Vector2(x0, lerpf(z0, z1, frac_z)))
					segments.append(Vector2(x0 + step_size * 0.45, lerpf(z0, z1, frac_z) + step_size * 0.45))

		if not segments.is_empty():
			cached_contours.append({
				"elevation": elev,
				"tier": t_idx,
				"segments": segments
			})

func _sample_elevation(world_x: float, world_z: float) -> float:
	if ResourceLoader.exists("res://terrain_collision.gd"):
		var tc_script = load("res://terrain_collision.gd")
		if tc_script != null and tc_script.has_method("sample_height"):
			return tc_script.sample_height(world_x, world_z)
	return 0.0

func _draw() -> void:
	var sz: Vector2 = size
	var center := sz * 0.5 - Vector2(0, 10) # Offset slightly to leave room for HUD labels below

	# 1. Background Bezel & Outer Ring
	draw_circle(center, radar_radius, COLOR_BG)
	draw_arc(center, radar_radius, 0.0, TAU, 48, COLOR_BORDER, 1.5, true)
	draw_arc(center, radar_radius - 2.0, 0.0, TAU, 36, Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.25), 1.0, true)

	# Set canvas transform to radar center for radial drawings
	draw_set_transform(center, 0.0, Vector2.ONE)

	# 2. Concentric Range Rings & Crosshairs
	draw_arc(Vector2.ZERO, radar_radius * 0.33, 0.0, TAU, 28, COLOR_GRID, 1.0)
	draw_arc(Vector2.ZERO, radar_radius * 0.66, 0.0, TAU, 36, COLOR_GRID, 1.0)
	draw_line(Vector2(-radar_radius, 0), Vector2(radar_radius, 0), COLOR_GRID, 1.0)
	draw_line(Vector2(0, -radar_radius), Vector2(0, radar_radius), COLOR_GRID, 1.0)

	# 2b. The Path of the Beam (Magnetic Axis across Mid-World)
	# Stephen King lore: Six Beams hold up the Dark Tower. Compass needles and radar waver along this line.
	var beam_origin := Vector2(-radar_radius, -radar_radius * 0.78)
	var beam_dest := Vector2(radar_radius, radar_radius * 0.78)
	draw_line(beam_origin, beam_dest, Color(0.95, 0.45, 0.22, 0.28), 1.2)

	# Cardinal Ticks (N, S, E, W)
	var tick_len: float = 4.0
	draw_line(Vector2(0, -radar_radius), Vector2(0, -radar_radius + tick_len), COLOR_BORDER, 1.5)
	draw_line(Vector2(0, radar_radius - tick_len), Vector2(0, radar_radius), COLOR_BORDER, 1.5)
	draw_line(Vector2(-radar_radius, 0), Vector2(-radar_radius + tick_len, 0), COLOR_BORDER, 1.5)
	draw_line(Vector2(radar_radius - tick_len, 0), Vector2(radar_radius, 0), COLOR_BORDER, 1.5)

	# 3. Topographic Contours & Defiles (Supports both segment-pair & polylines formats)
	for contour in cached_contours:
		var tier: int = int(contour.get("tier", 0))
		var c_col: Color = COLOR_CONTOUR_LOW
		if tier == 1:
			c_col = COLOR_CONTOUR_MID
		elif tier >= 2:
			c_col = COLOR_CONTOUR_HIGH

		if contour.has("points"):
			var points: PackedVector2Array = contour["points"]
			var local_points := PackedVector2Array()
			for pt in points:
				var world_offset := Vector2(pt.x - player_pos.x, pt.y - player_pos.z)
				if world_offset.length() <= world_view_radius:
					var radar_pt = (world_offset / world_view_radius) * radar_radius
					local_points.push_back(radar_pt)
			if local_points.size() > 1:
				draw_polyline(local_points, c_col, 1.0, true)
		elif contour.has("segments"):
			var segs: Array = contour["segments"]
			var idx: int = 0
			while idx + 1 < segs.size():
				var p0: Vector2 = segs[idx]
				var p1: Vector2 = segs[idx + 1]
				var off0 := Vector2(p0.x - player_pos.x, p0.y - player_pos.z)
				var off1 := Vector2(p1.x - player_pos.x, p1.y - player_pos.z)
				if off0.length() <= world_view_radius and off1.length() <= world_view_radius:
					var r0 = (off0 / world_view_radius) * radar_radius
					var r1 = (off1 / world_view_radius) * radar_radius
					draw_line(r0, r1, c_col, 1.0)
				idx += 2

	# 4. Landmark Beacons & POIs
	for landmark in cached_landmarks:
		var lm_pos: Vector2 = landmark["pos"]
		var is_beacon: bool = (landmark.get("type", "") == "beacon" or landmark.get("is_beacon", false))
		var world_offset := lm_pos - Vector2(player_pos.x, player_pos.z)
		var dist := world_offset.length()

		var px_dist: float = (dist / world_view_radius) * radar_radius
		var is_clamped: bool = false
		if px_dist > radar_radius - 5.0:
			px_dist = radar_radius - 5.0
			is_clamped = true

		var angle: float = atan2(world_offset.y, world_offset.x)
		var radar_pt: Vector2 = Vector2(cos(angle), sin(angle)) * px_dist
		var col: Color = COLOR_BEACON if is_beacon else COLOR_BLIP
		if is_clamped:
			col.a *= 0.65

		if is_beacon:
			var d_pts: PackedVector2Array = [
				radar_pt + Vector2(0, -4),
				radar_pt + Vector2(4, 0),
				radar_pt + Vector2(0, 4),
				radar_pt + Vector2(-4, 0)
			]
			draw_colored_polygon(d_pts, col)
		else:
			draw_circle(radar_pt, 2.5, col)

	# 4b. Dynamic Supply Cache Rhombus Blips (Warzone-style Loot Caches)
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		var loot_mgr := get_tree().root.find_child("LootCrateManager", true, false)
		if loot_mgr != null and loot_mgr.has_method("get_radar_crate_blips"):
			var crate_blips: Array = loot_mgr.call("get_radar_crate_blips")
			for cb in crate_blips:
				var c_pos: Vector2 = cb.get("pos", Vector2.ZERO)
				var ready: bool = cb.get("ready", false)
				var is_rare: bool = cb.get("is_rare", false)
				var w_off := c_pos - Vector2(player_pos.x, player_pos.z)
				var c_dist := w_off.length()

				if c_dist <= world_view_radius:
					var p_dist: float = (c_dist / world_view_radius) * radar_radius
					var ang: float = atan2(w_off.y, w_off.x)
					var r_pt := Vector2(cos(ang), sin(ang)) * p_dist
					var c_col: Color = (Color(0.25, 0.85, 0.95, 0.9) if is_rare else Color(0.92, 0.72, 0.38, 0.85)) if ready else Color(0.4, 0.25, 0.2, 0.4)

					# Draw small hollow diamond / rhombus [◇]
					var dia: PackedVector2Array = [
						r_pt + Vector2(0, -2.5),
						r_pt + Vector2(2.5, 0),
						r_pt + Vector2(0, 2.5),
						r_pt + Vector2(-2.5, 0)
					]
					draw_polyline(dia, c_col, 1.2, true)

	# 5. Rotating CRT Sweep Line & Sector Arc
	var sweep_dir := Vector2(cos(sweep_angle), sin(sweep_angle))
	draw_line(Vector2.ZERO, sweep_dir * radar_radius, COLOR_BORDER, 1.0)

	var poly_points := PackedVector2Array([Vector2.ZERO])
	for i in range(8):
		var ang: float = sweep_angle - (float(i) * 0.05)
		poly_points.push_back(Vector2(cos(ang), sin(ang)) * radar_radius)
	draw_colored_polygon(poly_points, COLOR_SWEEP)

	# 6. Player Heading Cone & Center Blip
	# Rotate along player yaw (atan2 in 2D matches yaw: forward is -Z, heading is yaw)
	draw_set_transform(center, player_heading - PI * 0.5, Vector2.ONE)
	var fov_poly := PackedVector2Array([
		Vector2.ZERO,
		Vector2(-6, 10),
		Vector2(6, 10)
	])
	draw_colored_polygon(fov_poly, Color(COLOR_BLIP.r, COLOR_BLIP.g, COLOR_BLIP.b, 0.45))
	draw_line(Vector2.ZERO, Vector2(0, 12), COLOR_BLIP, 1.5)
	draw_circle(Vector2.ZERO, 2.5, COLOR_BLIP)

	# Reset transform for HUD text footer
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 7. Dark Translucent Pill Badge & Heading Text (Destiny-Style Western Tactical Pill)
	var deg: int = int(round(rad_to_deg(fposmod(-player_heading + TAU, TAU)))) % 360
	var bearing_str: String = _get_heading_bearing(deg)
	var info_text: String = "HDG %03d° %s" % [deg, bearing_str]

	var pill_w: float = 126.0
	var pill_h: float = 18.0
	var pill_rect := Rect2(center.x - pill_w * 0.5, center.y + radar_radius + 4.0, pill_w, pill_h)

	if _heading_pill_style != null:
		draw_style_box(_heading_pill_style, pill_rect)
	else:
		draw_rect(pill_rect, COLOR_OBSIDIAN_PILL, true)
		draw_rect(pill_rect, COLOR_BRONZE_HAIRLINE, false, 1.0)

	var text_y: float = pill_rect.position.y + 13.0
	var text_pos := Vector2(pill_rect.position.x, text_y)
	draw_string(ThemeDB.fallback_font, text_pos, info_text, HORIZONTAL_ALIGNMENT_CENTER, pill_w, 10, COLOR_BONE_WHITE)

func _get_heading_bearing(deg: int) -> String:
	const POINTS: Array[String] = [
		"N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
		"S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"
	]
	var idx: int = int(floor(fposmod(float(deg) + 11.25, 360.0) / 22.5)) % 16
	var card: String = POINTS[idx]
	var rem: float = fposmod(float(deg), 22.5)
	if card in ["N", "S", "E", "W"]:
		if rem < 6.0:
			var prev_pt: String = POINTS[(idx + 15) % 16]
			return "%s - %s" % [card, prev_pt]
		elif rem > 16.5:
			var next_pt: String = POINTS[(idx + 1) % 16]
			return "%s - %s" % [card, next_pt]
		else:
			var sub_pt: String = POINTS[(idx + 15) % 16]
			return "%s - %s" % [card, sub_pt]
	return card
