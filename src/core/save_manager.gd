# save_manager.gd
# 游戏通用持久化存档管理器: 负责全量序列化与恢复时代进度、背包、蓝图及大世界建筑
class_name SaveManager
extends RefCounted

const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")
const SAVE_PATH: String = "user://elemental_save.json"

static func save_game(world_node: Node2D = null) -> bool:
	var save_dict: Dictionary = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": Time.get_datetime_string_from_system(),
		"game_state": {
			"current_era": GameState.current_era,
			"discovered_elements": GameState.discovered_elements,
			"equipped_tools": GameState.equipped_tools,
			"inventory": GameState.inventory.items,
			"unlocked_blueprints": _serialize_blueprints()
		},
		"world_state": {}
	}
	
	if world_node != null and world_node.has_method("serialize_world_state"):
		save_dict["world_state"] = world_node.serialize_world_state()
		
	var json_text = JSON.stringify(save_dict, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		print("[SaveManager] 存档写入失败: ", FileAccess.get_open_error())
		GameState.post_notice("❌ 存档写入失败！", Color.RED)
		return false
		
	file.store_string(json_text)
	file.close()
	print("[SaveManager] 存档成功写入: %s" % SAVE_PATH)
	GameState.post_notice("💾 游戏进度已成功安全保存！", Color(0.3, 0.9, 0.5))
	return true

static func load_game(world_node: Node2D = null) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		GameState.post_notice("⚠️ 未找到历史存档文件！", Color.YELLOW)
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		GameState.post_notice("❌ 无法打开存档文件！", Color.RED)
		return false
		
	var json_text = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		GameState.post_notice("❌ 存档数据损坏或格式错误！", Color.RED)
		return false
		
	var gs_data = parsed.get("game_state", {})
	GameState.current_era = int(gs_data.get("current_era", 0))
	
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
	GameState.post_notice("📂 存档进度读取成功！当前时代: %s" % GameState.ERA_NAMES[GameState.current_era], Color(0.2, 0.9, 1.0))
	return true

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func reset_save(world_node: Node2D = null) -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	GameState.current_era = 0
	GameState.discovered_elements = []
	GameState.equipped_tools = { "axe": "bare_hands", "pickaxe": "bare_hands" }
	GameState.inventory.items = {}
	GameState.unlocked_blueprints = {}
	GameState.inventory.item_changed.emit("", 0)
	GameState.era_advanced.emit(0, 0, GameState.ERA_NAMES[0])
	
	if world_node != null and world_node.has_method("reset_world_state"):
		world_node.reset_world_state()
		
	GameState.post_notice("🔄 进度已完全重置，重新开启石器时代！", Color.GOLD)

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
