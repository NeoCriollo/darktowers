class_name MenuGateSequence
extends RefCounted

## Gunslinger Gate Splash / Loading Sequence & Prologue Narrative Intro Sub-Controller.
## Manages the 6-chamber loading sequence ("The Gate") and the parchment typewriter
## crawl ("The Weight of Ka") before transitioning to the active world.

var menu: MainMenu = null

func _init(p_menu: MainMenu = null) -> void:
	menu = p_menu

# ─── Gate UI & Sequence Initialization ───────────────────────────────────────

func ensure_gate_ui_hierarchy() -> void:
	if menu.gate_header_label != null and menu._mono_font != null:
		menu.gate_header_label.add_theme_font_override("font", menu._mono_font)
	if menu.gate_quote_label != null and menu._serif_font != null:
		menu.gate_quote_label.add_theme_font_override("font", menu._serif_font)
	if menu.gate_cursor_label != null and menu._serif_font != null:
		menu.gate_cursor_label.add_theme_font_override("font", menu._serif_font)
	if menu.gate_stage_label != null and menu._mono_font != null:
		menu.gate_stage_label.add_theme_font_override("font", menu._mono_font)
	if menu.gate_chamber_readout != null and menu._mono_font != null:
		menu.gate_chamber_readout.add_theme_font_override("font", menu._mono_font)

	if menu.cylinder_indicator != null and not menu.cylinder_indicator.draw.is_connected(menu._draw_cylinder_indicator):
		menu.cylinder_indicator.draw.connect(menu._draw_cylinder_indicator)
	if menu.silica_line_indicator != null and not menu.silica_line_indicator.draw.is_connected(menu._draw_silica_line_indicator):
		menu.silica_line_indicator.draw.connect(menu._draw_silica_line_indicator)

	if menu.gate_overlay != null:
		menu.gate_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
		if not menu.gate_overlay.gui_input.is_connected(_on_gate_overlay_gui_input):
			menu.gate_overlay.gui_input.connect(_on_gate_overlay_gui_input)
	var bg := menu.get_node_or_null("UILayer/GateOverlay/PitchBlackBg") as Control
	if bg != null:
		bg.mouse_filter = Control.MOUSE_FILTER_PASS
		if not bg.gui_input.is_connected(_on_gate_overlay_gui_input):
			bg.gui_input.connect(_on_gate_overlay_gui_input)

func handle_gate_input(event: InputEvent) -> bool:
	if menu == null or menu.current_phase != MainMenu.FrontEndPhase.THE_GATE:
		return false
	if menu._gate_elapsed < menu.allow_skip_gate_after_seconds:
		return false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		complete_gate_immediately()
		return true
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			complete_gate_immediately()
			return true
	return false

func _on_gate_overlay_gui_input(event: InputEvent) -> void:
	if handle_gate_input(event):
		if menu != null and menu.get_viewport() != null:
			menu.get_viewport().set_input_as_handled()

func get_localized_gate_stages() -> Array[String]:
	return [
		menu.tr_ui("GATE_STAGE_1"), menu.tr_ui("GATE_STAGE_2"),
		menu.tr_ui("GATE_STAGE_3"), menu.tr_ui("GATE_STAGE_4"),
		menu.tr_ui("GATE_STAGE_5"), menu.tr_ui("GATE_STAGE_6")
	]

func get_localized_prologue_passages() -> Array[String]:
	return [
		menu.tr_ui("PROLOGUE_PASSAGE_1"),
		menu.tr_ui("PROLOGUE_PASSAGE_2"),
		menu.tr_ui("PROLOGUE_PASSAGE_3")
	]

func start_gate_sequence() -> void:
	menu.current_phase = MainMenu.FrontEndPhase.THE_GATE
	menu.gate_progress = 0.0
	menu._gate_elapsed = 0.0
	menu._last_chamber_indexed = 0

	if menu.gate_overlay != null:
		menu.gate_overlay.visible = true
		menu.gate_overlay.modulate = Color(1, 1, 1, 1)
	if menu.crossroads_overlay != null:
		menu.crossroads_overlay.visible = false
		menu.crossroads_overlay.modulate = Color(1, 1, 1, 0)
	if menu.prologue_overlay != null:
		menu.prologue_overlay.visible = false
		menu.prologue_overlay.modulate = Color(1, 1, 1, 0)

	if menu.gate_header_label != null: menu.gate_header_label.text = menu.tr_ui("GATE_HEADER")
	if menu.gate_quote_label != null: menu.gate_quote_label.text = ""
	if menu.gate_stage_label != null: menu.gate_stage_label.text = get_localized_gate_stages()[0]
	if menu.gate_chamber_readout != null:
		menu.gate_chamber_readout.text = menu.tr_ui("GATE_CYLINDER_READOUT") % ["[○][○][○][○][○][○]", 0]

	if menu.use_threaded_world_preload and ResourceLoader.exists(MainMenu.WORLD_SCENE_PATH):
		ResourceLoader.load_threaded_request(MainMenu.WORLD_SCENE_PATH)

func process_gate_phase(delta: float) -> void:
	menu._gate_elapsed += delta
	menu._cursor_pulse_time += delta

	if menu.gate_cursor_label != null:
		var pulse_alpha: float = 0.45 + 0.50 * (0.5 + 0.5 * sin(menu._cursor_pulse_time * 4.2))
		menu.gate_cursor_label.modulate = Color(0.96, 0.68, 0.24, pulse_alpha)

	var raw_ratio: float = clampf(menu._gate_elapsed / maxf(0.5, menu.gate_duration_seconds), 0.0, 1.0)
	menu.gate_progress = smoothstep(0.0, 1.0, raw_ratio)

	if menu.gate_quote_label != null:
		var epigraph: String = menu.tr_ui("GATE_EPIGRAPH")
		var text_ratio: float = clampf(menu._gate_elapsed / (menu.gate_duration_seconds * 0.68), 0.0, 1.0)
		var visible_chars: int = int(round(text_ratio * float(epigraph.length())))
		var target_substr: String = epigraph.substr(0, visible_chars)
		if menu.gate_quote_label.text != target_substr:
			menu.gate_quote_label.text = target_substr

	var chambers_loaded: int = clampi(int(floor(menu.gate_progress * 6.0)), 0, 6)
	if chambers_loaded > menu._last_chamber_indexed:
		menu._last_chamber_indexed = chambers_loaded
		menu.play_cylinder_index_sfx(chambers_loaded)
		update_chamber_telemetry(chambers_loaded)

	if menu.cylinder_indicator != null: menu.cylinder_indicator.queue_redraw()
	if menu.silica_line_indicator != null: menu.silica_line_indicator.queue_redraw()

	if menu._gate_elapsed >= menu.gate_duration_seconds:
		on_gate_sequence_finished()

func update_chamber_telemetry(chambers_loaded: int) -> void:
	var stages: Array[String] = get_localized_gate_stages()
	if menu.gate_stage_label != null:
		var stage_idx: int = clampi(chambers_loaded - 1, 0, stages.size() - 1)
		menu.gate_stage_label.text = stages[stage_idx]

	if menu.gate_chamber_readout != null:
		var slots: String = ""
		for i in range(6): slots += "[●]" if i < chambers_loaded else "[○]"
		menu.gate_chamber_readout.text = menu.tr_ui("GATE_CYLINDER_READOUT") % [slots, chambers_loaded]

func complete_gate_immediately() -> void:
	if menu == null or menu.current_phase != MainMenu.FrontEndPhase.THE_GATE: return
	menu.gate_progress = 1.0
	if menu.gate_quote_label != null: menu.gate_quote_label.text = menu.tr_ui("GATE_EPIGRAPH")
	if menu._last_chamber_indexed < 6:
		menu._last_chamber_indexed = 6
		menu.play_hammer_cock_sfx()
		update_chamber_telemetry(6)
	if menu.cylinder_indicator != null: menu.cylinder_indicator.queue_redraw()
	if menu.silica_line_indicator != null: menu.silica_line_indicator.queue_redraw()
	on_gate_sequence_finished()

func finish_gate_sequence() -> void:
	complete_gate_immediately()

func on_gate_sequence_finished() -> void:
	if menu == null or menu.current_phase != MainMenu.FrontEndPhase.THE_GATE: return
	menu.current_phase = MainMenu.FrontEndPhase.THE_CROSSROADS
	menu.gate_completed.emit()

	if menu.crossroads_overlay != null: menu.crossroads_overlay.visible = true

	if menu.is_inside_tree():
		var tween := menu.create_tween().set_parallel(true)
		if menu.gate_overlay != null:
			tween.tween_property(menu.gate_overlay, "modulate:a", 0.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if menu.crossroads_overlay != null:
			tween.tween_property(menu.crossroads_overlay, "modulate:a", 1.0, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(func() -> void:
			if menu.gate_overlay != null: menu.gate_overlay.visible = false
			if menu.btn_begin_journey != null and menu.btn_begin_journey.is_inside_tree():
				menu.btn_begin_journey.grab_focus()
		)
	else:
		if menu.gate_overlay != null: menu.gate_overlay.visible = false
		if menu.crossroads_overlay != null: menu.crossroads_overlay.modulate = Color(1, 1, 1, 1)
		if menu.btn_begin_journey != null and menu.btn_begin_journey.is_inside_tree():
			menu.btn_begin_journey.grab_focus()

# ─── Step 3: The Prologue / Narrative Intro ──────────────────────────────────

func setup_prologue_ui() -> void:
	if menu.prologue_header_label != null and menu._mono_font != null:
		menu.prologue_header_label.add_theme_font_override("font", menu._mono_font)
	if menu.prologue_title_label != null and menu._serif_font != null:
		menu.prologue_title_label.add_theme_font_override("font", menu._serif_font)
	if menu.prologue_body_label != null and menu._serif_font != null:
		menu.prologue_body_label.add_theme_font_override("font", menu._serif_font)
	if menu.prologue_progress_label != null and menu._mono_font != null:
		menu.prologue_progress_label.add_theme_font_override("font", menu._mono_font)

	if menu.parchment_canvas != null and not menu.parchment_canvas.draw.is_connected(draw_parchment_tablet):
		menu.parchment_canvas.draw.connect(draw_parchment_tablet)

	if menu.btn_prologue_advance != null:
		if menu._mono_font != null: menu.btn_prologue_advance.add_theme_font_override("font", menu._mono_font)
		menu._apply_diegetic_button_style(menu.btn_prologue_advance, true)
		menu.btn_prologue_advance.pressed.connect(on_prologue_advance_pressed)

	if menu.btn_prologue_skip != null:
		if menu._mono_font != null: menu.btn_prologue_skip.add_theme_font_override("font", menu._mono_font)
		menu._apply_diegetic_button_style(menu.btn_prologue_skip, false)
		menu.btn_prologue_skip.pressed.connect(finish_prologue_and_enter_world)

func start_prologue() -> void:
	menu.current_phase = MainMenu.FrontEndPhase.THE_PROLOGUE
	menu.prologue_started.emit()

	menu._prologue_full_text = "\n\n".join(get_localized_prologue_passages())
	menu._prologue_visible_chars = 0
	menu._prologue_char_accum = 0.0
	menu._prologue_pause_timer = 0.0
	menu._prologue_is_finished_typing = false
	menu._prologue_camera_push = 0.0

	if menu.prologue_header_label != null: menu.prologue_header_label.text = menu.tr_ui("PROLOGUE_HEADER")
	if menu.prologue_title_label != null: menu.prologue_title_label.text = menu.tr_ui("PROLOGUE_TITLE")
	if menu.prologue_body_label != null: menu.prologue_body_label.text = ""
	if menu.btn_prologue_skip != null: menu.btn_prologue_skip.text = menu.tr_ui("PROLOGUE_BTN_SKIP")
	if menu.btn_prologue_advance != null: menu.btn_prologue_advance.text = menu.tr_ui("PROLOGUE_BTN_COMPLETE")
	if menu.prologue_progress_label != null: menu.prologue_progress_label.text = menu.tr_ui("PROLOGUE_ETCHING_FMT") % 0

	if menu.prologue_overlay != null:
		menu.prologue_overlay.visible = true
		menu.prologue_overlay.modulate = Color(1, 1, 1, 0)

	if menu.parchment_canvas != null: menu.parchment_canvas.queue_redraw()

	if menu.is_inside_tree():
		var tween := menu.create_tween().set_parallel(true)
		if menu.crossroads_overlay != null:
			tween.tween_property(menu.crossroads_overlay, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
		if menu.prologue_overlay != null:
			tween.tween_property(menu.prologue_overlay, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_callback(func() -> void:
			if menu.crossroads_overlay != null: menu.crossroads_overlay.visible = false
			if menu.btn_prologue_advance != null and menu.btn_prologue_advance.is_inside_tree():
				menu.btn_prologue_advance.grab_focus()
		)
	else:
		if menu.crossroads_overlay != null: menu.crossroads_overlay.visible = false
		if menu.prologue_overlay != null: menu.prologue_overlay.modulate = Color(1, 1, 1, 1)

func process_prologue_phase(delta: float) -> void:
	menu._cursor_pulse_time += delta
	menu._prologue_camera_push = minf(1.0, menu._prologue_camera_push + delta * 0.045)

	if menu._prologue_is_finished_typing:
		if menu.prologue_body_label != null:
			var cursor_str: String = " ▌" if sin(menu._cursor_pulse_time * 4.5) >= 0.0 else "  "
			menu.prologue_body_label.text = menu._prologue_full_text + cursor_str
		return

	if menu._prologue_pause_timer > 0.0:
		menu._prologue_pause_timer -= delta
		return

	menu._prologue_char_accum += delta * menu.typewriter_chars_per_second
	var step_chars: int = int(floor(menu._prologue_char_accum))
	if step_chars <= 0: return
	menu._prologue_char_accum -= float(step_chars)

	var total_len: int = menu._prologue_full_text.length()
	var prev_chars: int = menu._prologue_visible_chars
	menu._prologue_visible_chars = mini(total_len, menu._prologue_visible_chars + step_chars)

	if menu._prologue_visible_chars > prev_chars:
		var latest_char: String = menu._prologue_full_text.substr(menu._prologue_visible_chars - 1, 1)
		if latest_char != " " and latest_char != "\n":
			menu.play_typewriter_tick_sfx(menu._prologue_visible_chars)
		if latest_char in [".", "!", "?"]: menu._prologue_pause_timer = 0.24
		elif latest_char in [",", ";", ":", "—"]: menu._prologue_pause_timer = 0.11
		elif latest_char == "\n": menu._prologue_pause_timer = 0.18

	var revealed: String = menu._prologue_full_text.substr(0, menu._prologue_visible_chars)
	if menu.prologue_body_label != null: menu.prologue_body_label.text = revealed + "▌"

	if menu.prologue_progress_label != null and total_len > 0:
		var pct: int = int(round((float(menu._prologue_visible_chars) / float(total_len)) * 100.0))
		menu.prologue_progress_label.text = menu.tr_ui("PROLOGUE_ETCHING_FMT") % pct

	if menu._prologue_visible_chars >= total_len:
		mark_prologue_typing_complete()

func mark_prologue_typing_complete() -> void:
	menu._prologue_is_finished_typing = true
	menu._prologue_visible_chars = menu._prologue_full_text.length()
	if menu.prologue_body_label != null: menu.prologue_body_label.text = menu._prologue_full_text + " ▌"
	if menu.prologue_progress_label != null: menu.prologue_progress_label.text = menu.tr_ui("PROLOGUE_COMPLETE")
	if menu.btn_prologue_advance != null: menu.btn_prologue_advance.text = menu.tr_ui("PROLOGUE_BTN_ENTER")
	menu.play_cylinder_index_sfx(6)

func on_prologue_advance_pressed() -> void:
	if not menu._prologue_is_finished_typing:
		mark_prologue_typing_complete()
	else:
		finish_prologue_and_enter_world()

func finish_prologue_and_enter_world() -> void:
	if menu.current_phase == MainMenu.FrontEndPhase.TRANSITIONING: return
	menu.play_hammer_cock_sfx()
	menu.prologue_completed.emit()
	menu.begin_journey()

func draw_parchment_tablet() -> void:
	if menu.parchment_canvas == null: return
	var sz: Vector2 = menu.parchment_canvas.size
	if sz.x <= 10.0 or sz.y <= 10.0: return

	var rect := Rect2(Vector2.ZERO, sz)
	menu.parchment_canvas.draw_rect(rect, Color(0.09, 0.072, 0.054, 0.94), true)

	var stripe_count: int = 26
	for i in range(stripe_count):
		var y_pos: float = (float(i) / float(stripe_count)) * sz.y
		var alpha: float = 0.025 + 0.02 * sin(float(i) * 2.17)
		menu.parchment_canvas.draw_line(Vector2(12.0, y_pos), Vector2(sz.x - 12.0, y_pos), Color(0.68, 0.54, 0.36, alpha), 1.0)

	var outer_border := Color(0.76, 0.52, 0.26, 0.72)
	var inner_border := Color(0.54, 0.38, 0.22, 0.38)
	menu.parchment_canvas.draw_rect(rect.grow(-2.0), outer_border, false, 1.5)
	menu.parchment_canvas.draw_rect(rect.grow(-8.0), inner_border, false, 1.0)

	var c_len: float = 16.0
	var corners: Array[Vector2] = [Vector2(8.0, 8.0), Vector2(sz.x - 8.0, 8.0), Vector2(8.0, sz.y - 8.0), Vector2(sz.x - 8.0, sz.y - 8.0)]
	for idx in range(corners.size()):
		var pt: Vector2 = corners[idx]
		var dx: float = c_len if (idx % 2 == 0) else -c_len
		var dy: float = c_len if (idx < 2) else -c_len
		menu.parchment_canvas.draw_line(pt, pt + Vector2(dx, 0.0), outer_border, 2.0)
		menu.parchment_canvas.draw_line(pt, pt + Vector2(0.0, dy), outer_border, 2.0)

func draw_cylinder(indicator: Control, progress: float) -> void:
	if indicator == null: return
	var sz: Vector2 = indicator.size; var center: Vector2 = sz * 0.5; var outer_r: float = minf(sz.x, sz.y) * 0.42
	if outer_r <= 4.0: return
	var amber_dim := Color(0.72, 0.52, 0.24, 0.35); var amber_bright := Color(0.96, 0.68, 0.24, 0.92)
	indicator.draw_circle(center, outer_r, Color(0.08, 0.075, 0.07, 0.95))
	indicator.draw_arc(center, outer_r, 0.0, TAU, 48, amber_dim, 1.5, true)
	indicator.draw_circle(center, outer_r * 0.16, Color(0.18, 0.15, 0.11, 1.0))
	var exact: float = progress * 6.0; var base_rot: float = -PI * 0.5 + floor(exact) * (TAU / 6.0)
	for i in range(6):
		var angle: float = base_rot + float(i) * (TAU / 6.0)
		var c_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (outer_r * 0.55)
		indicator.draw_circle(c_pos, outer_r * 0.21, Color(0.03, 0.03, 0.03, 1.0))
		var fill: float = clampf(exact - float(i), 0.0, 1.0)
		if fill > 0.01:
			indicator.draw_circle(c_pos, outer_r * 0.21 * 0.82 * smoothstep(0.0, 1.0, fill), amber_bright)
			indicator.draw_arc(c_pos, outer_r * 0.21, 0.0, TAU, 24, amber_bright, 1.5, true)
		else:
			indicator.draw_arc(c_pos, outer_r * 0.21, 0.0, TAU, 24, amber_dim, 1.1, true)

func draw_silica_line(indicator: Control, progress: float) -> void:
	if indicator == null: return
	var sz: Vector2 = indicator.size; var pad_x: float = 8.0; var track_w: float = maxf(10.0, sz.x - pad_x * 2.0)
	var start_pt := Vector2(pad_x, sz.y * 0.5); var end_pt := Vector2(pad_x + track_w, sz.y * 0.5)
	indicator.draw_line(start_pt, end_pt, Color(0.38, 0.30, 0.20, 0.22), 1.0)
	var fill_w: float = track_w * clampf(progress, 0.0, 1.0)
	if fill_w > 0.5:
		var act_end := Vector2(pad_x + fill_w, sz.y * 0.5)
		indicator.draw_line(start_pt, act_end, Color(0.88, 0.64, 0.26, 0.78), 2.0)
		indicator.draw_circle(act_end, 2.8, Color(0.98, 0.78, 0.36, 0.92))


