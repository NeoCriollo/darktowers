class_name Localization
extends RefCounted

## UI Localization & TranslationServer Manager — "Dark Towers: The Path of Ka"
##
## Provides dynamic runtime localization between English ("en") and Spanish ("es"):
## - Lightweight dictionary lookup + native Godot TranslationServer registration
## - CSV translation loader support (parse_csv_translations)
## - Automatic persistence of language preference to user://path_of_ka_save.cfg
## - Reactive listener callbacks so active UI controllers update immediately.
## Language dictionaries are isolated in StringsEn and StringsEs.

const SAVE_FILE_PATH: String = "user://path_of_ka_save.cfg"
const DEFAULT_LANGUAGE: String = "en"
const SUPPORTED_LANGUAGES: Array[String] = ["en", "es"]

const LANGUAGE_LABELS: Dictionary = {
	"en": "ENGLISH (EN)",
	"es": "ESPAÑOL (ES)"
}

const LANGUAGE_BADGES: Dictionary = {
	"en": "[ EN ]",
	"es": "[ ES ]"
}

const TRANSLATIONS: Dictionary = {
	"en": StringsEn.STRINGS,
	"es": StringsEs.STRINGS
}

static var _current_language: String = DEFAULT_LANGUAGE
static var _server_registered: bool = false
static var _listeners: Array[Callable] = []

static func ensure_initialized() -> void:
	if _server_registered:
		return
	_server_registered = true
	var en_dict: Dictionary = TRANSLATIONS.get("en", {})
	for lang_code in SUPPORTED_LANGUAGES:
		var tr_res := Translation.new()
		tr_res.locale = lang_code
		var lang_dict: Dictionary = TRANSLATIONS.get(lang_code, {})
		for key in lang_dict.keys():
			var translated_val: String = String(lang_dict[key])
			tr_res.add_message(StringName(key), StringName(translated_val))
			if en_dict.has(key):
				var en_literal: String = String(en_dict[key])
				if en_literal != key:
					tr_res.add_message(StringName(en_literal), StringName(translated_val))
		TranslationServer.add_translation(tr_res)
	TranslationServer.set_locale(_current_language)

static func set_language(lang_code: String, save_preference: bool = true, path: String = SAVE_FILE_PATH) -> String:
	if not SUPPORTED_LANGUAGES.has(lang_code):
		push_warning("Localization: unsupported language code '%s', defaulting to '%s'" % [lang_code, DEFAULT_LANGUAGE])
		lang_code = DEFAULT_LANGUAGE

	_current_language = lang_code
	ensure_initialized()
	TranslationServer.set_locale(lang_code)

	if save_preference:
		save_language_preference(lang_code, path)

	_notify_listeners(lang_code)
	return _current_language

static func get_language() -> String:
	return _current_language

static func get_language_index(lang_code: String = "") -> int:
	var code := lang_code if not lang_code.is_empty() else _current_language
	var idx := SUPPORTED_LANGUAGES.find(code)
	return maxi(0, idx)

static func get_string(key: String, default_override: String = "") -> String:
	ensure_initialized()
	var lang_dict: Dictionary = TRANSLATIONS.get(_current_language, {})
	if lang_dict.has(key):
		return String(lang_dict[key])
	var en_dict: Dictionary = TRANSLATIONS.get(DEFAULT_LANGUAGE, {})
	if en_dict.has(key):
		return String(en_dict[key])
	if not default_override.is_empty():
		return default_override
	return key

static func has(key: String, lang_code: String = "") -> bool:
	ensure_initialized()
	var code := lang_code if not lang_code.is_empty() else _current_language
	var lang_dict: Dictionary = TRANSLATIONS.get(code, {})
	if lang_dict.has(key):
		return true
	var en_dict: Dictionary = TRANSLATIONS.get(DEFAULT_LANGUAGE, {})
	return en_dict.has(key)

static func t(key: String, default_override: String = "") -> String:
	return get_string(key, default_override)

static func translate_key(key: String, lang_code: String = "") -> String:
	ensure_initialized()
	var code := lang_code if not lang_code.is_empty() else _current_language
	var lang_dict: Dictionary = TRANSLATIONS.get(code, {})
	if lang_dict.has(key):
		return String(lang_dict[key])
	var en_dict: Dictionary = TRANSLATIONS.get(DEFAULT_LANGUAGE, {})
	if en_dict.has(key):
		return String(en_dict[key])
	return key

static func format_string(key: String, args: Array, default_override: String = "") -> String:
	var template: String = get_string(key, default_override)
	return template % args

static func get_language_label(lang_code: String = "") -> String:
	var code := lang_code if not lang_code.is_empty() else _current_language
	return String(LANGUAGE_LABELS.get(code, code.to_upper()))

static func get_language_badge(lang_code: String = "") -> String:
	var code := lang_code if not lang_code.is_empty() else _current_language
	return String(LANGUAGE_BADGES.get(code, "[ %s ]" % code.to_upper()))

static func register_language_listener(callable: Callable) -> void:
	if not _listeners.has(callable):
		_listeners.append(callable)

static func unregister_language_listener(callable: Callable) -> void:
	_listeners.erase(callable)

static func register_listener(callable: Callable) -> void:
	register_language_listener(callable)

static func unregister_listener(callable: Callable) -> void:
	unregister_language_listener(callable)

static func _notify_listeners(lang_code: String) -> void:
	var active_listeners: Array[Callable] = []
	for listener in _listeners:
		if listener.is_valid():
			active_listeners.append(listener)
			listener.call(lang_code)
	_listeners = active_listeners

static func save_language_preference(lang_code: String, path: String = SAVE_FILE_PATH) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Localization: failed to load existing save config for language persistence: %d" % err)
	cfg.set_value("settings", "language", lang_code)
	var save_err := cfg.save(path)
	if save_err != OK:
		push_warning("Localization: failed to save language preference to '%s': %d" % [path, save_err])

static func load_language_preference(path: String = SAVE_FILE_PATH) -> String:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err == OK and cfg.has_section_key("settings", "language"):
		var loaded_code: String = String(cfg.get_value("settings", "language", DEFAULT_LANGUAGE))
		if SUPPORTED_LANGUAGES.has(loaded_code):
			return loaded_code
	return DEFAULT_LANGUAGE

static func parse_csv_translations(csv_content: String) -> Dictionary:
	var result: Dictionary = {"en": {}, "es": {}}
	var lines := csv_content.split("\n")
	if lines.size() < 2:
		return result

	var header_tokens: Array = _split_csv_line(lines[0])
	var en_idx: int = -1
	var es_idx: int = -1
	for col_idx in range(header_tokens.size()):
		var token: String = String(header_tokens[col_idx]).strip_edges().to_lower()
		if token == "en":
			en_idx = col_idx
		elif token == "es":
			es_idx = col_idx

	if en_idx == -1 or es_idx == -1:
		push_warning("Localization: CSV missing required 'en' or 'es' column header.")
		return result

	for line_idx in range(1, lines.size()):
		var raw_line := lines[line_idx].strip_edges()
		if raw_line.is_empty() or raw_line.begins_with("#"):
			continue
		var cols := _split_csv_line(raw_line)
		if cols.size() == 0:
			continue
		var key: String = String(cols[0]).strip_edges()
		if key.is_empty():
			continue
		if en_idx < cols.size():
			var en_val: String = String(cols[en_idx]).strip_edges()
			if not en_val.is_empty():
				result["en"][key] = en_val
		if es_idx < cols.size():
			var es_val: String = String(cols[es_idx]).strip_edges()
			if not es_val.is_empty():
				result["es"][key] = es_val

	return result

static func _split_csv_line(line: String) -> Array:
	var tokens: Array = []
	var cur: String = ""
	var in_quotes: bool = false
	var i: int = 0
	while i < line.length():
		var ch := line[i]
		if ch == '"':
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				cur += '"'
				i += 1
			else:
				in_quotes = not in_quotes
		elif ch == ',' and not in_quotes:
			tokens.append(cur)
			cur = ""
		else:
			cur += ch
		i += 1
	tokens.append(cur)
	return tokens

static func translate_region_name(display_name: String, lang_code: String = "") -> String:
	var upper_name: String = display_name.to_upper().strip_edges()
	var key_lookup := {
		"THE MOHAINE WAY-BUNKER": "REGION_THE_MOHAINE_WAY_BUNKER",
		"REFUGIO DE MOHAINE": "REGION_THE_MOHAINE_WAY_BUNKER",
		"SOUTHWEST DESOLATION": "REGION_SOUTHWEST_DESOLATION",
		"DESOLACIÓN SUROESTE": "REGION_SOUTHWEST_DESOLATION",
		"CALICHE CRADLE": "REGION_CALICHE_CRADLE",
		"CALICHE CRADLE NEXUS": "REGION_CALICHE_CRADLE_NEXUS",
		"CUNA DE CALICHE": "REGION_CALICHE_CRADLE",
		"BLEACHED ALKALI SINK": "REGION_BLEACHED_ALKALI_SINK",
		"CUENCA DE ÁLCALI BLANQUEADA": "REGION_BLEACHED_ALKALI_SINK",
		"RUST-GORGE DEFILE": "REGION_RUST_GORGE_DEFILE",
		"DESFILADERO QUEBRADA DEL ÓXIDO": "REGION_RUST_GORGE_DEFILE",
		"THE GREAT SHIFTING ERG": "REGION_THE_GREAT_SHIFTING_ERG",
		"EL GRAN ERG CAMBIANTE": "REGION_THE_GREAT_SHIFTING_ERG",
		"DEAD-CREEK SALT FLATS": "REGION_DEAD_CREEK_SALT_FLATS",
		"SALINAS DEL ARROYO MUERTO": "REGION_DEAD_CREEK_SALT_FLATS",
		"THRESHOLD OF THE DARK TOWER": "REGION_THRESHOLD_OF_THE_DARK_TOWER",
		"UMBRAL DE LA TORRE OSCURA": "REGION_THRESHOLD_OF_THE_DARK_TOWER"
	}
	if key_lookup.has(upper_name):
		return translate_key(key_lookup[upper_name], lang_code)
	return display_name

static func translate_chamber_state(state_str: String, lang_code: String = "") -> String:
	var u := state_str.to_upper().strip_edges()
	match u:
		"LIVE", "LIVE_ROUND", "CHAMBERED_LIVE": return translate_key("CHAMBER_LIVE_ROUND", lang_code)
		"EMPTY": return translate_key("CHAMBER_EMPTY", lang_code)
		"SPENT", "SPENT_CASING", "CHAMBERED_SPENT": return translate_key("CHAMBER_SPENT_CASING", lang_code)
		"STOVEPIPE", "STOVEPIPE_JAM": return translate_key("CHAMBER_STOVEPIPE_JAM", lang_code)
		"FAILURE_TO_FEED": return translate_key("CHAMBER_FAILURE_TO_FEED", lang_code)
		"FAILURE_TO_EXTRACT": return translate_key("CHAMBER_FAILURE_TO_EXTRACT", lang_code)
		"OUT_OF_BATTERY": return translate_key("CHAMBER_OUT_OF_BATTERY", lang_code)
		_:
			var direct := translate_key("CHAMBER_" + u, lang_code)
			return direct if direct != ("CHAMBER_" + u) else state_str

static func translate_hammer_state(state_str: String, lang_code: String = "") -> String:
	var u := state_str.to_upper().strip_edges()
	match u:
		"COCKED": return translate_key("HAMMER_COCKED", lang_code)
		"RESTING": return translate_key("HAMMER_RESTING", lang_code)
		"DECOCKED": return translate_key("HAMMER_DECOCKED", lang_code)
		"HALF_COCK", "HALF-COCK": return translate_key("HAMMER_HALF_COCK", lang_code)
		_:
			var direct := translate_key("HAMMER_" + u, lang_code)
			return direct if direct != ("HAMMER_" + u) else state_str

static func translate_locomotion_state(state_str: String, lang_code: String = "") -> String:
	var u := state_str.to_upper().strip_edges()
	match u:
		"IDLE": return translate_key("LOCO_IDLE", lang_code)
		"WALKING": return translate_key("LOCO_WALKING", lang_code)
		"SPRINTING": return translate_key("LOCO_SPRINTING", lang_code)
		"CROUCHING": return translate_key("LOCO_CROUCHING", lang_code)
		"AIRBORNE": return translate_key("LOCO_AIRBORNE", lang_code)
		"EXHAUSTED": return translate_key("LOCO_EXHAUSTED", lang_code)
		_:
			var direct := translate_key("LOCO_" + u, lang_code)
			return direct if direct != ("LOCO_" + u) else state_str

static func translate_weather_preset(preset_str: String, lang_code: String = "") -> String:
	var u := preset_str.to_upper().strip_edges()
	match u:
		"CLEAR_ARID": return translate_key("WEATHER_CLEAR_ARID", lang_code)
		"HEAT_HAZE": return translate_key("WEATHER_HEAT_HAZE", lang_code)
		"DUST_DEVIL": return translate_key("WEATHER_DUST_DEVIL", lang_code)
		"SEVERE_HABOOB": return translate_key("WEATHER_SEVERE_HABOOB", lang_code)
		"COLD_DESERT_NIGHT": return translate_key("WEATHER_COLD_DESERT_NIGHT", lang_code)
		_:
			var direct := translate_key("WEATHER_" + u, lang_code)
			return direct if direct != ("WEATHER_" + u) else preset_str
