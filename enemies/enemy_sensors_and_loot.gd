class_name EnemySensorsAndLoot
extends RefCounted

## EnemySensorsAndLoot — Sensory Detection, Tactical Raycasts & Death Loot Spawner
##
## Decoupled domain helper for EnemyBase managing:
## - 3D line-of-sight raycasts and player proximity detection
## - Tactical local obstacle avoidance across basin geometries
## - Gunshot acoustic reaction and siege aggro forcing
## - Weighted economy loot rolling (.45 LC ammo, water, rare gunsmithing components)
## - World-space loot item instantiation and death collapse remnants
## - HUD toast and combat telemetry notifications

# =============================================================================
# --- SENSORY DETECTION & LINE-OF-SIGHT ---
# =============================================================================

static func is_player_node(node: Node3D) -> bool:
	if node == null: return false
	if node is CharacterBody3D and (node.name == "Player" or node.is_in_group("player")): return true
	if "weapon_system" in node and "stamina" in node: return true
	return false

static func resolve_candidate_player(detection_area: Area3D, host: Node3D, current_target: Node3D) -> Node3D:
	if current_target != null and is_instance_valid(current_target):
		return current_target
	if detection_area != null and detection_area.is_inside_tree() and detection_area.monitoring:
		for body in detection_area.get_overlapping_bodies():
			if is_player_node(body): return body
	if host != null and host.is_inside_tree() and host.get_tree() != null:
		if host.get_tree().current_scene != null:
			var p := host.get_tree().current_scene.find_child("Player", true, false) as Node3D
			if p != null: return p
		var parent := host.get_parent()
		if parent != null:
			var sibling := parent.get_node_or_null("Player") as Node3D
			if sibling != null: return sibling
	return null

static func has_line_of_sight(host: Node3D, target: Node3D, los_raycast: RayCast3D, eye_offset: float) -> bool:
	if target == null or not is_instance_valid(target) or host == null: return false
	if not host.is_inside_tree() or host.get_world_3d() == null or host.get_world_3d().direct_space_state == null:
		return true

	var eye_origin: Vector3 = host.global_position + Vector3(0.0, eye_offset, 0.0)
	var tgt_center: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)

	if los_raycast != null and los_raycast.is_inside_tree():
		los_raycast.global_position = eye_origin
		los_raycast.target_position = los_raycast.to_local(tgt_center)
		los_raycast.force_raycast_update()
		if not los_raycast.is_colliding(): return true
		var hit_col: Object = los_raycast.get_collider()
		if hit_col == target or (hit_col is Node and target.is_ancestor_of(hit_col as Node)): return true

	var space_state := host.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye_origin, tgt_center)
	query.exclude = [host.get_rid()]
	query.collide_with_areas = false; query.collide_with_bodies = true
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty(): return true
	var collider: Object = hit.get("collider")
	return collider == target or (collider is Node and target.is_ancestor_of(collider as Node))

static func apply_local_obstacle_avoidance(host: Node3D, desired_dir: Vector3, target_player: Node3D) -> Vector3:
	if host == null or not host.is_inside_tree() or host.get_world_3d() == null or host.get_world_3d().direct_space_state == null:
		return desired_dir
	var space_state := host.get_world_3d().direct_space_state
	var waist_origin: Vector3 = host.global_position + Vector3(0.0, 0.9, 0.0)
	var query := PhysicsRayQueryParameters3D.create(waist_origin, waist_origin + desired_dir * 1.65)
	var excluded: Array[RID] = [host.get_rid()]
	if target_player is CollisionObject3D: excluded.append((target_player as CollisionObject3D).get_rid())
	query.exclude = excluded
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty(): return desired_dir
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var slide_dir := Vector3(desired_dir.x, 0.0, desired_dir.z).slide(Vector3(normal.x, 0.0, normal.z).normalized())
	return slide_dir.normalized() if slide_dir.length_squared() > 0.01 else desired_dir.rotated(Vector3.UP, PI * 0.4)

# =============================================================================
# --- LOOT ECONOMY & WEIGHTED ROLLING ---
# =============================================================================

static func build_effective_drop_table(drop_table: Array[Dictionary], w_ammo: float, w_water: float, w_comp: float) -> Array[Dictionary]:
	if drop_table.size() == 3:
		return [
			{
				"id": String(drop_table[0].get("id", "ammo_45lc")), "type": String(drop_table[0].get("type", "AMMO")),
				"name_key": String(drop_table[0].get("name_key", "LOOT_ITEM_AMMO_45LC")),
				"weight": maxf(0.0, w_ammo), "min_amount": int(drop_table[0].get("min_amount", 2)), "max_amount": int(drop_table[0].get("max_amount", 6))
			},
			{
				"id": String(drop_table[1].get("id", "survival_water")), "type": String(drop_table[1].get("type", "SURVIVAL")),
				"name_key": String(drop_table[1].get("name_key", "LOOT_ITEM_SURVIVAL_WATER")),
				"weight": maxf(0.0, w_water), "min_amount": int(drop_table[1].get("min_amount", 1)), "max_amount": int(drop_table[1].get("max_amount", 1))
			},
			{
				"id": String(drop_table[2].get("id", "rare_components")), "type": String(drop_table[2].get("type", "COMPONENT")),
				"name_key": String(drop_table[2].get("name_key", "LOOT_ITEM_RARE_COMPONENT")),
				"weight": maxf(0.0, w_comp), "min_amount": int(drop_table[2].get("min_amount", 1)), "max_amount": int(drop_table[2].get("max_amount", 1))
			}
		]
	return drop_table

static func roll_loot_drop(table: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if table.is_empty():
		return { "id": "ammo_45lc", "type": "AMMO", "name_key": "LOOT_ITEM_AMMO_45LC", "amount": 3 }
	var total_weight: float = 0.0
	for entry in table: total_weight += maxf(0.0, float(entry.get("weight", 0.0)))
	if total_weight <= 0.0:
		var fb: Dictionary = table[0].duplicate(); fb["amount"] = int(fb.get("min_amount", 1)); return fb

	var roll: float = rng.randf() * total_weight; var cumulative: float = 0.0; var chosen: Dictionary = table[0]
	for entry in table:
		cumulative += maxf(0.0, float(entry.get("weight", 0.0)))
		if roll <= cumulative: chosen = entry; break

	var min_amt: int = maxi(1, int(chosen.get("min_amount", 1)))
	var max_amt: int = maxi(min_amt, int(chosen.get("max_amount", min_amt)))
	var result: Dictionary = chosen.duplicate()
	result["amount"] = rng.randi_range(min_amt, max_amt)
	return result

static func spawn_loot_drop(host: Node3D, drop_chance: float, loot_drop_scene: PackedScene, table: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() > clampf(drop_chance, 0.0, 1.0):
		return { "instance": null, "data": {} }
	var loot_data := roll_loot_drop(table, rng)
	var item_instance: Node3D = null
	if loot_drop_scene != null: item_instance = loot_drop_scene.instantiate() as Node3D
	if item_instance == null: item_instance = LootDropItem.new()

	item_instance.name = "LootDrop_%s" % String(loot_data.get("id", "item"))
	if item_instance.has_method("configure_loot"): item_instance.call("configure_loot", loot_data)
	var spawn_pos: Vector3 = host.global_position
	item_instance.position = spawn_pos

	var world_root: Node = resolve_world_root(host)
	if world_root != null:
		world_root.call_deferred("add_child", item_instance)
		item_instance.set_deferred("global_position", spawn_pos)
	return { "instance": item_instance, "data": loot_data }

static func spawn_collapse_remnant(host: Node3D, visual_model: Node3D) -> void:
	var world_root: Node = resolve_world_root(host)
	if world_root == null or not host.is_inside_tree() or visual_model == null: return
	var corpse_fx := Node3D.new(); corpse_fx.name = "CollapsedRaiderRemnant"
	var remnant_mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(0.55, 0.32, 1.45)
	var mat := StandardMaterial3D.new(); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.26, 0.19, 0.14, 0.95); mat.roughness = 0.92
	box.material = mat; remnant_mesh.mesh = box; remnant_mesh.position = Vector3(0.0, 0.16, 0.0)
	corpse_fx.add_child(remnant_mesh); corpse_fx.position = host.global_position; corpse_fx.rotation.y = visual_model.rotation.y
	world_root.call_deferred("add_child", corpse_fx)
	corpse_fx.tree_entered.connect(func() -> void:
		var tw := corpse_fx.create_tween(); tw.tween_interval(3.5)
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.2); tw.tween_callback(corpse_fx.queue_free)
	, Object.CONNECT_ONE_SHOT)

static func resolve_world_root(host: Node3D) -> Node:
	if host != null and host.is_inside_tree() and host.get_tree() != null:
		if host.get_tree().current_scene != null: return host.get_tree().current_scene
		if host.get_parent() != null: return host.get_parent()
		return host.get_tree().root
	return host.get_parent() if host != null else null

# =============================================================================
# --- HUD NOTIFICATIONS ---
# =============================================================================

static func find_hud(host: Node) -> Node:
	var p := host.get_parent() if host != null else null
	while p != null:
		var h := p.get_node_or_null("HUD")
		if h != null: return h
		p = p.get_parent()
	if host != null and host.is_inside_tree() and host.get_tree() != null and host.get_tree().current_scene != null:
		return host.get_tree().current_scene.find_child("HUD", true, false)
	return null

static func notify_hud_detection(host: Node, enemy_title_key: String) -> void:
	var hud := find_hud(host)
	if hud != null and hud.has_method("show_notification"):
		var enemy_name: String = Localization.t(enemy_title_key)
		hud.call("show_notification", Localization.t("NOTIF_ENEMY_DETECTED_FMT") % enemy_name, 2.5)

static func notify_hud_defeat(host: Node, enemy_title_key: String, dropped_item: Node3D, loot_data: Dictionary) -> void:
	var hud := find_hud(host)
	if hud == null or not hud.has_method("show_notification"): return
	var enemy_name: String = Localization.t(enemy_title_key)
	var msg: String = Localization.t("NOTIF_ENEMY_DEFEATED_FMT") % enemy_name
	if dropped_item != null and not loot_data.is_empty():
		var item_key: String = String(loot_data.get("name_key", "LOOT_ITEM_AMMO_45LC"))
		msg = "%s  |  %s" % [Localization.t("NOTIF_ENEMY_DEFEATED_FMT") % enemy_name, Localization.t("NOTIF_LOOT_DROPPED_FMT") % Localization.t(item_key)]
	hud.call("show_notification", msg, 3.4)

