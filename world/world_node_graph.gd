class_name WorldNodeGraph
extends RefCounted

## Master Node-Based Regional Traversal & Connection Graph
## 8 Primary Biome Nodes (Node 0 Mohaine Way-Bunker through Node 7 Tower Threshold)
## Connected via bidirectional canyon passes, choke points, and hazardous anomaly connectors.

const NODES: Dictionary = {
	"waystation_sanctuary": {
		"node_index": 0, "id": "waystation_sanctuary", "name": "The Mohaine Way-Bunker",
		"center": Vector2(-1000.0, -800.0), "radius": 150.0, "is_safe_zone": true,
		"connected_nodes": ["sw_desolation", "south_salt"]
	},
	"sw_desolation": {
		"node_index": 1, "id": "sw_desolation", "name": "Southwest Desolation",
		"center": Vector2(-550.0, -900.0), "radius": 250.0, "is_safe_zone": false,
		"connected_nodes": ["waystation_sanctuary", "south_salt"]
	},
	"south_salt": {
		"node_index": 2, "id": "south_salt", "name": "Dead-Creek Salt Flats",
		"center": Vector2(-150.0, -550.0), "radius": 250.0, "is_safe_zone": false,
		"connected_nodes": ["waystation_sanctuary", "sw_desolation", "cradle"]
	},
	"cradle": {
		"node_index": 3, "id": "cradle", "name": "Caliche Cradle Hub",
		"center": Vector2(0.0, 0.0), "radius": 250.0, "is_safe_zone": false,
		"connected_nodes": ["south_salt", "west_gorge", "north_alkali", "east_dunes", "monolith_pass"]
	},
	"west_gorge": {
		"node_index": 4, "id": "west_gorge", "name": "Rust-Gorge Defile",
		"center": Vector2(-650.0, 50.0), "radius": 250.0, "is_safe_zone": false,
		"connected_nodes": ["cradle", "north_alkali"]
	},
	"north_alkali": {
		"node_index": 5, "id": "north_alkali", "name": "Bleached Alkali Sink",
		"center": Vector2(0.0, 650.0), "radius": 250.0, "is_safe_zone": false,
		"connected_nodes": ["cradle", "west_gorge", "monolith_pass"]
	},
	"east_dunes": {
		"node_index": 6, "id": "east_dunes", "name": "The Great Shifting Erg",
		"center": Vector2(650.0, 50.0), "radius": 250.0, "is_safe_zone": false,
		"connected_nodes": ["cradle", "monolith_pass"]
	},
	"monolith_pass": {
		"node_index": 7, "id": "monolith_pass", "name": "Threshold of the Dark Tower",
		"center": Vector2(650.0, 650.0), "radius": 250.0, "is_safe_zone": false,
		"connected_nodes": ["north_alkali", "east_dunes", "cradle"]
	}
}

const CORRIDORS: Array[Dictionary] = [
	{
		"id": "pass_sanctuary_to_sw", "name": "Mohaine Sanctuary Gate Defile",
		"from": "waystation_sanctuary", "to": "sw_desolation",
		"a": Vector2(-900.0, -820.0), "b": Vector2(-650.0, -880.0), "choke": Vector2(-900.0, -820.0),
		"half_width": 18.0, "type": "CHOKE_POINT", "bidirectional": true, "blocked": false,
		"hazard_mult": 1.0, "stamina_mult": 1.0, "hazard": "NONE"
	},
	{
		"id": "pass_sanctuary_to_salt", "name": "Southern Culvert Drainage Wash",
		"from": "waystation_sanctuary", "to": "south_salt",
		"a": Vector2(-950.0, -780.0), "b": Vector2(-280.0, -650.0), "choke": Vector2(-615.0, -715.0),
		"half_width": 14.0, "type": "ANCIENT_TUNNEL", "bidirectional": true, "blocked": false,
		"hazard_mult": 1.4, "stamina_mult": 1.3, "hazard": "SALT_CORROSION"
	},
	{
		"id": "pass_sw_to_salt", "name": "Hardpan Siphon Pass",
		"from": "sw_desolation", "to": "south_salt",
		"a": Vector2(-450.0, -800.0), "b": Vector2(-250.0, -650.0), "choke": Vector2(-350.0, -725.0),
		"half_width": 18.0, "type": "CANYON_PASS", "bidirectional": true, "blocked": false,
		"hazard_mult": 1.5, "stamina_mult": 1.2, "hazard": "SILICA_HABOOB"
	},
	{
		"id": "pass_salt_to_cradle", "name": "Dead-Creek Arroyo Corridor",
		"from": "south_salt", "to": "cradle",
		"a": Vector2(-100.0, -420.0), "b": Vector2(-30.0, -150.0), "choke": Vector2(-65.0, -285.0),
		"half_width": 18.0, "type": "CANYON_PASS", "bidirectional": true, "blocked": false,
		"hazard_mult": 1.2, "stamina_mult": 1.1, "hazard": "SALT_CORROSION"
	},
	{
		"id": "pass_cradle_to_gorge", "name": "West Caliche Defile Pass",
		"from": "cradle", "to": "west_gorge",
		"a": Vector2(-150.0, 15.0), "b": Vector2(-500.0, 40.0), "choke": Vector2(-325.0, 27.5),
		"half_width": 16.0, "type": "CHOKE_POINT", "bidirectional": true, "blocked": false,
		"hazard_mult": 1.8, "stamina_mult": 1.4, "hazard": "IRON_OXIDE"
	},
	{
		"id": "pass_cradle_to_north", "name": "North Caliche Conduit Pass",
		"from": "cradle", "to": "north_alkali",
		"a": Vector2(0.0, 150.0), "b": Vector2(0.0, 500.0), "choke": Vector2(0.0, 325.0),
		"half_width": 18.0, "type": "CANYON_PASS", "bidirectional": true, "blocked": false,
		"hazard_mult": 1.3, "stamina_mult": 1.2, "hazard": "NONE"
	},
	{
		"id": "pass_cradle_to_east", "name": "Windward Erg Pass",
		"from": "cradle", "to": "east_dunes",
		"a": Vector2(150.0, 15.0), "b": Vector2(500.0, 40.0), "choke": Vector2(325.0, 27.5),
		"half_width": 18.0, "type": "CANYON_PASS", "bidirectional": true, "blocked": false,
		"hazard_mult": 1.6, "stamina_mult": 1.5, "hazard": "SILICA_HABOOB"
	},
	{
		"id": "pass_gorge_to_north", "name": "Gorge-Alkali High Pass",
		"from": "west_gorge", "to": "north_alkali",
		"a": Vector2(-500.0, 180.0), "b": Vector2(-150.0, 520.0), "choke": Vector2(-325.0, 350.0),
		"half_width": 16.0, "type": "CHOKE_POINT", "bidirectional": true, "blocked": false,
		"hazard_mult": 2.0, "stamina_mult": 1.5, "hazard": "IRON_OXIDE"
	},
	{
		"id": "pass_north_to_monolith", "name": "Monolith Pass Defile",
		"from": "north_alkali", "to": "monolith_pass",
		"a": Vector2(150.0, 650.0), "b": Vector2(500.0, 650.0), "choke": Vector2(325.0, 650.0),
		"half_width": 18.0, "type": "CANYON_PASS", "bidirectional": true, "blocked": false,
		"hazard_mult": 1.7, "stamina_mult": 1.3, "hazard": "NONE"
	},
	{
		"id": "pass_east_to_monolith", "name": "Dunecrest Citadel Approach",
		"from": "east_dunes", "to": "monolith_pass",
		"a": Vector2(650.0, 150.0), "b": Vector2(650.0, 500.0), "choke": Vector2(650.0, 325.0),
		"half_width": 18.0, "type": "CANYON_PASS", "bidirectional": true, "blocked": false,
		"hazard_mult": 1.9, "stamina_mult": 1.6, "hazard": "SILICA_HABOOB"
	},
	{
		"id": "connector_cradle_to_monolith_thinny", "name": "Beam Abyss Thinny Chasm Connector",
		"from": "cradle", "to": "monolith_pass",
		"a": Vector2(140.0, 140.0), "b": Vector2(585.0, 585.0), "choke": Vector2(325.0, 325.0),
		"half_width": 32.0, "type": "HAZARDOUS_ABYSS", "bidirectional": true, "blocked": true,
		"hazard_mult": 4.5, "stamina_mult": 2.5, "hazard": "THINNY_DISTORTION"
	}
]

static func get_node(id_or_index: Variant) -> Dictionary:
	if id_or_index is int:
		for k in NODES:
			if NODES[k]["node_index"] == id_or_index:
				return NODES[k]
	elif id_or_index is String:
		return NODES.get(id_or_index, {})
	return {}

static func get_corridor(id: String) -> Dictionary:
	for c in CORRIDORS:
		if c["id"] == id:
			return c
	return {}

static func get_corridor_between(from_basin: String, to_basin: String) -> Dictionary:
	for c in CORRIDORS:
		if (c["from"] == from_basin and c["to"] == to_basin) or (c["bidirectional"] and c["from"] == to_basin and c["to"] == from_basin):
			return c
	return {}

static func get_corridors_for_node(basin_id: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for c in CORRIDORS:
		if c["from"] == basin_id or (c["bidirectional"] and c["to"] == basin_id):
			list.append(c)
	return list

static func can_traverse_directly(from_basin: String, to_basin: String) -> bool:
	if from_basin == to_basin: return true
	var c := get_corridor_between(from_basin, to_basin)
	return not c.is_empty() and not bool(c.get("blocked", false))

static func dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func resolve_active_corridor(p: Vector2) -> Dictionary:
	for c in CORRIDORS:
		var d := dist_to_segment(p, c["a"], c["b"])
		if d <= float(c["half_width"]):
			return c
	return {}

static func get_corridor_hazard_multiplier(p: Vector2) -> float:
	var c := resolve_active_corridor(p)
	if not c.is_empty():
		return float(c.get("hazard_mult", 1.0))
	return 1.0

