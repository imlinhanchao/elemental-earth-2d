# save_manager.gd
# 游戏通用持久化存档管理器: 包含业界标准多槽位归档、自动存档、元数据摘要提取及跨场景读写
class_name SaveManager
extends RefCounted

const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")

const SLOT_DEFINITIONS: Array[Dictionary] = [
	{ "id": "auto", "name": "⚡ 自动存档", "is_auto": true },
	{ "id": "slot_1", "name": "💾 存档槽位 1", "is_auto": false },
	{ "id": "slot_2", "name": "💾 存档槽位 2", "is_auto": false },
	{ "id": "slot_3", "name": "💾 存档槽位 3", "is_auto": false },
	{ "id": "slot_4", "name": "💾 存档槽位 4", "is_auto": false }
]

const LEGACY_SAVE_PATH: String = "user://elemental_save.json"

# 跨场景传参：主菜单选择载入后，标记目标槽位给大世界场景
static var pending_load_slot: String = ""

static func get_slot_path(slot_id: String) -> String:
	return "user://save_%s.json" % slot_id

static func check_legacy_migration() -> void:
	# 兼容旧版本单文件存档，自动迁移至 save_auto.json
	var auto_path = get_slot_path("auto")
	if not FileAccess.file_exists(auto_path) and FileAccess.file_exists(LEGACY_SAVE_PATH):
		var src = FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
		if src:
			var txt = src.get_as_text()
			src.close()
			var dst = FileAccess.open(auto_path, FileAccess.WRITE)
			if dst:
				dst.store_string(txt)
				dst.close()

static func get_slot_meta(slot_id: String) -> Dictionary:
	check_legacy_migration()
	var path = get_slot_path(slot_id)
	
	var def_name = "存档槽位"
	var is_auto = (slot_id == "auto")
	for s in SLOT_DEFINITIONS:
		if s["id"] == slot_id:
			def_name = s["name"]
			is_auto = s.get("is_auto", false)
			break
			
	var result: Dictionary = {
		"slot_id": slot_id,
		"slot_name": def_name,
		"is_auto": is_auto,
		"exists": false,
		"timestamp": 0,
		"datetime": "",
		"playtime_formatted": "00:00",
		"era": 0,
		"era_name": "石器时代",
		"elements_count": 0,
		"territory_radius": 5,
		"inventory_count": 0,
		"furnaces_count": 0,
		"reactors_count": 0
	}
	
	if not FileAccess.file_exists(path):
		return result
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return result
		
	var json_str = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		return result
		
	result["exists"] = true
	result["timestamp"] = int(parsed.get("timestamp", 0))
	result["datetime"] = str(parsed.get("datetime", ""))
	result["playtime_formatted"] = str(parsed.get("playtime_formatted", "00:00"))
	
	var meta = parsed.get("metadata", {})
	result["era"] = int(meta.get("era", 0))
	result["era_name"] = str(meta.get("era_name", "石器时代"))
	result["elements_count"] = int(meta.get("elements_count", 0))
	result["territory_radius"] = int(meta.get("territory_radius", 5))
	result["inventory_count"] = int(meta.get("inventory_items_count", 0))
	result["furnaces_count"] = int(meta.get("furnaces_count", 0))
	result["reactors_count"] = int(meta.get("reactors_count", 0))
	
	return result

static func get_all_slots() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for s in SLOT_DEFINITIONS:
		list.append(get_slot_meta(s["id"]))
	return list

static func has_any_save() -> bool:
	check_legacy_migration()
	for s in SLOT_DEFINITIONS:
		if FileAccess.file_exists(get_slot_path(s["id"])):
			return true
	return false

static func get_latest_save_slot() -> String:
	check_legacy_migration()
	var best_slot: String = ""
	var max_time: int = -1
	for s in SLOT_DEFINITIONS:
		var meta = get_slot_meta(s["id"])
		if meta["exists"] and meta["timestamp"] > max_time:
			max_time = meta["timestamp"]
			best_slot = s["id"]
	return best_slot

static func save_to_slot(slot_id: String, world_node: Node2D = null) -> bool:
	var path = get_slot_path(slot_id)
	var world_data: Dictionary = {}
	var furnaces_count: int = 0
	var reactors_count: int = 0
	
	if world_node != null and world_node.has_method("serialize_world_state"):
		world_data = world_node.serialize_world_state()
		furnaces_count = world_data.get("furnaces", []).size()
		reactors_count = world_data.get("reactors", []).size()
		
	var def_name = "存档"
	for s in SLOT_DEFINITIONS:
		if s["id"] == slot_id:
			def_name = s["name"]
			break
			
	var dt_str = Time.get_datetime_string_from_system().replace("T", " ")
	
	var save_dict: Dictionary = {
		"version": 2,
		"slot_id": slot_id,
		"slot_name": def_name,
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": dt_str,
		"playtime_seconds": GameState.playtime_seconds,
		"playtime_formatted": GameState.get_formatted_playtime(),
		"metadata": {
			"era": GameState.current_era,
			"era_name": GameState.ERA_NAMES[GameState.current_era],
			"elements_count": GameState.discovered_elements.size(),
			"territory_radius": GameState.get_current_territory_radius(),
			"inventory_items_count": GameState.inventory.items.size(),
			"furnaces_count": furnaces_count,
			"reactors_count": reactors_count
		},
		"game_state": {
			"current_era": GameState.current_era,
			"playtime_seconds": GameState.playtime_seconds,
			"discovered_elements": GameState.discovered_elements,
			"equipped_tools": GameState.equipped_tools,
			"inventory": GameState.inventory.items,
			"unlocked_blueprints": _serialize_blueprints()
		},
		"world_state": world_data
	}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print("[SaveManager] 写入槽位失败: %s" % path)
		GameState.post_notice("❌ 存档写入失败！", Color.RED)
		return false
		
	file.store_string(JSON.stringify(save_dict, "\t"))
	file.close()
	print("[SaveManager] 进度已成功保存至槽位: %s (%s)" % [slot_id, path])
	if slot_id != "auto":
		GameState.post_notice("💾 进度已成功保存至【%s】！" % def_name, Color(0.3, 0.9, 0.5))
	return true

static func load_from_slot(slot_id: String, world_node: Node2D = null) -> bool:
	check_legacy_migration()
	var path = get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		GameState.post_notice("⚠️ 该存档槽位为空！", Color.YELLOW)
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		GameState.post_notice("❌ 无法打开存档文件！", Color.RED)
		return false
		
	var json_str = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		GameState.post_notice("❌ 存档数据损坏或格式错误！", Color.RED)
		return false
		
	var gs_data = parsed.get("game_state", {})
	GameState.current_era = int(gs_data.get("current_era", 0))
	GameState.playtime_seconds = float(gs_data.get("playtime_seconds", 0.0))
	
	GameState.discovered_elements = []
	for num in gs_data.get("discovered_elements", []):
		GameState.discovered_elements.append(int(num))
		
	GameState.equipped_tools = gs_data.get("equipped_tools", {
		"axe": "bare_hands",
		"pickaxe": "bare_hands"
	})
	
	GameState.inventory.items = {}
	var inv_data = gs_data.get("inventory", {})
	for k in inv_data.keys():
		GameState.inventory.items[k] = int(inv_data[k])
	GameState.inventory.item_changed.emit("", 0)
	
	_deserialize_blueprints(gs_data.get("unlocked_blueprints", {}))
	
	var world_data = parsed.get("world_state", {})
	if world_node != null and world_node.has_method("deserialize_world_state"):
		world_node.deserialize_world_state(world_data)
		
	GameState.era_advanced.emit(0, GameState.current_era, GameState.ERA_NAMES[GameState.current_era])
	GameState.post_notice("📂 成功载入【%s】！当前时代: %s" % [
		parsed.get("slot_name", slot_id),
		GameState.ERA_NAMES[GameState.current_era]
	], Color(0.2, 0.9, 1.0))
	return true

static func delete_slot(slot_id: String) -> bool:
	var path = get_slot_path(slot_id)
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		return (err == OK)
	return true

static func _serialize_blueprints() -> Dictionary:
	var dict: Dictionary = {}
	for k in GameState.unlocked_blueprints.keys():
		var bp = GameState.unlocked_blueprints[k]
		dict[k] = {
			"id": bp.id,
			"display_name": bp.display_name,
			"inputs": bp.inputs,
			"outputs": bp.outputs,
			"min_temp": bp.min_temp,
			"duration_seconds": bp.duration_seconds
		}
	return dict

static func _deserialize_blueprints(dict: Dictionary) -> void:
	GameState.unlocked_blueprints = {}
	for k in dict.keys():
		var d = dict[k]
		var bp = ProcessBlueprint.new(
			d.get("id", k),
			d.get("display_name", k),
			d.get("inputs", {}),
			d.get("outputs", {}),
			float(d.get("min_temp", 293.15))
		)
		bp.duration_seconds = float(d.get("duration_seconds", 3.0))
		GameState.unlocked_blueprints[k] = bp
