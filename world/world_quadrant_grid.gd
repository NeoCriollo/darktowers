class_name WorldQuadrantGrid
extends RefCounted

## World Quadrant Topographic Grid & POI World-Mapping System
## 2500m × 2500m Mid-World Coordinate Space (Centered at (0, 0), Extents: [-1250m, +1250m])
## 4×4 Grid (16 Quadrants Q01–Q16, spanning 625m × 625m each).

const QUADRANT_SIZE: float = 625.0
const HALF_EXTENT: float = 1250.0
const COL_CODES: Array[String] = ["A", "B", "C", "D"]
const ROW_CODES: Array[String] = ["1", "2", "3", "4"]

const QUADRANTS: Dictionary = {
	"Q01": {
		"id": "Q01", "code": "A1", "col": 0, "row": 0,
		"name": "Mohaine Waystation Sanctuary & SW Perimeter", "biome": "waystation_sanctuary", "biome_name": "The Mohaine Way-Bunker",
		"bounds": {"min_x": -1250.0, "max_x": -625.0, "min_z": -1250.0, "max_z": -625.0, "center_x": -937.5, "center_z": -937.5},
		"elevation": {"min": -3.32, "max": 10.98, "avg": 1.42, "relief": 14.30, "type": "Basin Floor & Encircling Ridge"},
		"features": ["Player Spawn (-1020, -820)", "Mohaine Bunker (-1015, -815)", "Threshold Gate (-900, -820)"]
	},
	"Q02": {
		"id": "Q02", "code": "B1", "col": 1, "row": 0,
		"name": "Southwest Desolation & Hardpan Dunes", "biome": "sw_desolation", "biome_name": "Southwest Desolation",
		"bounds": {"min_x": -625.0, "max_x": 0.0, "min_z": -1250.0, "max_z": -625.0, "center_x": -312.5, "center_z": -937.5},
		"elevation": {"min": -2.19, "max": 8.60, "avg": 1.04, "relief": 10.79, "type": "Wind-Swept Sand Dunes & Hardpan"},
		"features": ["SW Basin Center (-550, -900)", "Ka Beacon (-530, -880)", "Telegraph Poles #1-#2"]
	},
	"Q03": {
		"id": "Q03", "code": "C1", "col": 2, "row": 0,
		"name": "South Wasteland & Salt Apron", "biome": "south_salt", "biome_name": "Dead-Creek Salt Flats (South)",
		"bounds": {"min_x": 0.0, "max_x": 625.0, "min_z": -1250.0, "max_z": -625.0, "center_x": 312.5, "center_z": -937.5},
		"elevation": {"min": -1.38, "max": 10.10, "avg": -0.05, "relief": 11.47, "type": "Playa Transition & Southern Ridges"},
		"features": ["Dead-Creek South Margin", "Outer Caliche Transition", "Southern Natural Ridge"]
	},
	"Q04": {
		"id": "Q04", "code": "D1", "col": 3, "row": 0,
		"name": "Southeast Rust Rift & Thinny Anomaly", "biome": "east_dunes", "biome_name": "The Great Shifting Erg (Southeast)",
		"bounds": {"min_x": 625.0, "max_x": 1250.0, "min_z": -1250.0, "max_z": -625.0, "center_x": 937.5, "center_z": -937.5},
		"elevation": {"min": -1.76, "max": 1.89, "avg": -0.48, "relief": 3.65, "type": "Low Undulating Dunes & Void Rift"},
		"features": ["Southeast Rust Rift Thinny (+650, -650)", "Low Arid Dune Floor"]
	},
	"Q05": {
		"id": "Q05", "code": "A2", "col": 0, "row": 1,
		"name": "Western Scarp & Mohaine North Ridge", "biome": "waystation_sanctuary", "biome_name": "Mohaine North Buffer",
		"bounds": {"min_x": -1250.0, "max_x": -625.0, "min_z": -625.0, "max_z": 0.0, "center_x": -937.5, "center_z": -312.5},
		"elevation": {"min": -1.55, "max": 17.04, "avg": 0.73, "relief": 18.59, "type": "Escarpment & Perimeter Ridge"},
		"features": ["Waystation North Mountain Flank", "Canyon Wall Escarpment (+17m)"]
	},
	"Q06": {
		"id": "Q06", "code": "B2", "col": 1, "row": 1,
		"name": "Dead-Creek Salt Flats (Playa Pan)", "biome": "south_salt", "biome_name": "Dead-Creek Salt Flats",
		"bounds": {"min_x": -625.0, "max_x": 0.0, "min_z": -625.0, "max_z": 0.0, "center_x": -312.5, "center_z": -312.5},
		"elevation": {"min": -3.64, "max": 21.35, "avg": 1.84, "relief": 24.98, "type": "Dead-Level Playa Pan (-0.45m) & Rim Ridges"},
		"features": ["Salt Basin Center (-150, -550)", "Ka Beacon (-130, -530)", "Telegraph Wire (Poles #3-#6)", "Megafauna Skeletons"]
	},
	"Q07": {
		"id": "Q07", "code": "C2", "col": 2, "row": 1,
		"name": "Caliche Cradle South & Nexus Approach", "biome": "cradle", "biome_name": "Caliche Cradle (South)",
		"bounds": {"min_x": 0.0, "max_x": 625.0, "min_z": -625.0, "max_z": 0.0, "center_x": 312.5, "center_z": -312.5},
		"elevation": {"min": -2.81, "max": 18.89, "avg": 1.62, "relief": 21.70, "type": "Arroyo Trenching & Terraced Limestone"},
		"features": ["Cradle Ka Beacon (+25, -20)", "Nexus South Cairn", "Nexus East Stele"]
	},
	"Q08": {
		"id": "Q08", "code": "D2", "col": 3, "row": 1,
		"name": "Great Shifting Erg South & Buried Ruins", "biome": "east_dunes", "biome_name": "The Great Shifting Erg (South)",
		"bounds": {"min_x": 625.0, "max_x": 1250.0, "min_z": -625.0, "max_z": 0.0, "center_x": 937.5, "center_z": -312.5},
		"elevation": {"min": -3.13, "max": 18.27, "avg": 0.47, "relief": 21.40, "type": "Mega-Dunes & Old-Ones Superstructures"},
		"features": ["Tilted Old-Ones Ruin (+680, -20)", "Protruding I-Beam Truss", "Obsidian Pylon Rib"]
	},
	"Q09": {
		"id": "Q09", "code": "A3", "col": 0, "row": 2,
		"name": "Rust-Gorge Defile & Overpass Choke", "biome": "west_gorge", "biome_name": "Rust-Gorge Defile",
		"bounds": {"min_x": -1250.0, "max_x": -625.0, "min_z": 0.0, "max_z": 625.0, "center_x": -937.5, "center_z": 312.5},
		"elevation": {"min": -1.79, "max": 26.51, "avg": 2.46, "relief": 28.31, "type": "Sheer Sandstone Canyon (+18m) & Talus"},
		"features": ["Gorge Basin Center (-650, 50)", "Ka Beacon (-630, 70)", "Collapsed Highway Overpass (-650, 15)"]
	},
	"Q10": {
		"id": "Q10", "code": "B3", "col": 1, "row": 2,
		"name": "Defile-Alkali Pass & Northwest Interior", "biome": "west_gorge", "biome_name": "Rust-Gorge / Alkali Confluence",
		"bounds": {"min_x": -625.0, "max_x": 0.0, "min_z": 0.0, "max_z": 625.0, "center_x": -312.5, "center_z": 312.5},
		"elevation": {"min": -3.81, "max": 27.01, "avg": 4.63, "relief": 30.82, "type": "Mountain Passes & Elevated Mesas"},
		"features": ["Pass Cradle to Gorge", "Pass Gorge to North Alkali", "Peak Mesas (+27.0m)"]
	},
	"Q11": {
		"id": "Q11", "code": "C3", "col": 2, "row": 2,
		"name": "Caliche Cradle Nexus & Thinny Beam Abyss", "biome": "cradle", "biome_name": "Caliche Cradle Nexus",
		"bounds": {"min_x": 0.0, "max_x": 625.0, "min_z": 0.0, "max_z": 625.0, "center_x": 312.5, "center_z": 312.5},
		"elevation": {"min": -30.15, "max": 18.55, "avg": -1.84, "relief": 48.70, "type": "Crossroads Basin, Cliff (+4.8m) & Abyss (-30m)"},
		"features": ["Nexus Crossroads (0, 0)", "NE Overlook (+140, +140)", "Thinny Beam Abyss (+325, +325)"]
	},
	"Q12": {
		"id": "Q12", "code": "D3", "col": 3, "row": 2,
		"name": "The Great Shifting Erg (Central Mega-Dunes)", "biome": "east_dunes", "biome_name": "The Great Shifting Erg",
		"bounds": {"min_x": 625.0, "max_x": 1250.0, "min_z": 0.0, "max_z": 625.0, "center_x": 937.5, "center_z": 312.5},
		"elevation": {"min": -3.10, "max": 18.56, "avg": 1.52, "relief": 21.66, "type": "Razor-Crest Mega-Dunes (+15.5m) & Troughs"},
		"features": ["Erg Basin Center (+650, 50)", "Ka Beacon (+670, 70)", "Gantry Struts", "Boundary Pylons"]
	},
	"Q13": {
		"id": "Q13", "code": "A4", "col": 0, "row": 3,
		"name": "Northwest Scarp & Alkali Hollow Thinny", "biome": "north_alkali", "biome_name": "Northwest Alkali Scarp",
		"bounds": {"min_x": -1250.0, "max_x": -625.0, "min_z": 625.0, "max_z": 1250.0, "center_x": -937.5, "center_z": 937.5},
		"elevation": {"min": -1.76, "max": 1.78, "avg": -0.47, "relief": 3.54, "type": "Undulating Scarp & Void Tear"},
		"features": ["Northwest Alkali Hollow Thinny (-650, 650)", "Escarpment Ridge"]
	},
	"Q14": {
		"id": "Q14", "code": "B4", "col": 1, "row": 3,
		"name": "Bleached Alkali Sink (West Basin)", "biome": "north_alkali", "biome_name": "Bleached Alkali Sink (West)",
		"bounds": {"min_x": -625.0, "max_x": 0.0, "min_z": 625.0, "max_z": 1250.0, "center_x": -312.5, "center_z": 937.5},
		"elevation": {"min": -2.11, "max": 15.57, "avg": 0.69, "relief": 17.68, "type": "Concave Saucer Depression (-1.8m) & Badlands"},
		"features": ["Alkali Sink Center (0, 650)", "Sulfur Crust Mounds"]
	},
	"Q15": {
		"id": "Q15", "code": "C4", "col": 2, "row": 3,
		"name": "Bleached Alkali Sink (East & Beacon Monolith)", "biome": "north_alkali", "biome_name": "Bleached Alkali Sink (East)",
		"bounds": {"min_x": 0.0, "max_x": 625.0, "min_z": 625.0, "max_z": 1250.0, "center_x": 312.5, "center_z": 937.5},
		"elevation": {"min": -2.99, "max": 15.63, "avg": 1.60, "relief": 18.62, "type": "Foundation Plinths & Badland Hills"},
		"features": ["Ka Beacon Monolith (+45, 680)", "Hexagonal Plinth", "Power Conduits"]
	},
	"Q16": {
		"id": "Q16", "code": "D4", "col": 3, "row": 3,
		"name": "Threshold of the Dark Tower & Citadel Spire", "biome": "monolith_pass", "biome_name": "Threshold of the Dark Tower",
		"bounds": {"min_x": 625.0, "max_x": 1250.0, "min_z": 625.0, "max_z": 1250.0, "center_x": 937.5, "center_z": 937.5},
		"elevation": {"min": -2.53, "max": 8.83, "avg": 0.91, "relief": 11.36, "type": "Stepped Volcanic Basalt Terraces (+9.0m)"},
		"features": ["The Dark Tower Spire (+700, +700)", "Citadel Beacon (+630, +630)", "Outer Fortress (+650, +650)"]
	}
}

static func get_quadrant_at(world_x: float, world_z: float) -> Dictionary:
	var cx := clampf(world_x, -1250.0, 1249.9)
	var cz := clampf(world_z, -1250.0, 1249.9)
	var c := clampi(int(floor((cx + 1250.0) / QUADRANT_SIZE)), 0, 3)
	var r := clampi(int(floor((cz + 1250.0) / QUADRANT_SIZE)), 0, 3)
	var q_id := "Q%02d" % (r * 4 + c + 1)
	return QUADRANTS.get(q_id, {})

static func get_quadrant(id: String) -> Dictionary:
	return QUADRANTS.get(id, {})

static func get_all_quadrants() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for i in range(1, 17):
		var q_id := "Q%02d" % i
		if QUADRANTS.has(q_id):
			list.append(QUADRANTS[q_id])
	return list

static func print_quadrant_summary() -> void:
	print("==========================================================================================")
	print("          DARK TOWERS: 2500m x 2500m QUADRANT TOPOGRAPHIC & ELEVATION RELIEF MAP          ")
	print("==========================================================================================")
	for i in range(1, 17):
		var q_id := "Q%02d" % i
		var q: Dictionary = QUADRANTS[q_id]
		var b: Dictionary = q["bounds"]
		var e: Dictionary = q["elevation"]
		print("[%s %s] %-38s | X:[%+5.0f..%+5.0f] Z:[%+5.0f..%+5.0f] | Elev:[%+5.1f..%+5.1fm] Relief:%4.1fm" % [
			q["id"], q["code"], q["name"], b["min_x"], b["max_x"], b["min_z"], b["max_z"], e["min"], e["max"], e["relief"]
		])

static func print_ascii_grid() -> void:
	print("+----------------------------------------------------------------------------------------------------+")
	print("|                      MID-WORLD 4x4 TOPOGRAPHIC QUADRANT GRID REFERENCE                             |")
	print("+--------------------+--------------------+--------------------+-------------------------------------+")
	print("| Col A [-1250..-625]| Col B [-625..0]    | Col C [0..625]     | Col D [625..1250]                   |")
	print("+--------------------+--------------------+--------------------+-------------------------------------+")
	for r in range(3, -1, -1):
		var z_min: float = -1250.0 + r * 625.0
		var z_max: float = z_min + 625.0
		print("| ROW %d (Z: %+5.0f to %+5.0fm)" % [r + 1, z_min, z_max])
		var l1 := "|"
		var l2 := "|"
		for c in range(4):
			var q_num: int = r * 4 + c + 1
			var q_id := "Q%02d" % q_num
			var q: Dictionary = QUADRANTS[q_id]
			l1 += " [%s %s] %-12s|" % [q["id"], q["code"], String(q["biome"]).substr(0, 12)]
			l2 += " Relf: %4.1fm %-8s|" % [q["elevation"]["relief"], String(q["code"])]
		print(l1)
		print(l2)
		print("+--------------------+--------------------+--------------------+-------------------------------------+")

