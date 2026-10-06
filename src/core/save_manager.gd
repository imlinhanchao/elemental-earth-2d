# save_manager.gd
# 游戏通用持久化存档管理器: 升级至 v3 架构，支持时代、工具、背包、蓝图、任务队列、实验台溶液、地块采空与建筑网格坐标
class_name SaveManager
extends RefCounted

const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

# 旧版存档中已更名的物品键
const LEGACY_ITEM_KEYS: Dictionary = {"iron_ore": "hematite", "halite": "rock_salt"}

# v4: 新增地块剩余储量；任务保存已耗时长与循环次数 (不再保存跨进程无效的 begin_time)
const SAVE_VERSION: int = 4

const SLOT_DEFINITIONS: Array[Dictionary] = [
	{ "id": "auto", "name": "自动存档", "is_auto": true },
	{ "id": "slot_1", "name": "手动档案 1", "is_auto": false },
	{ "id": "slot_2", "name": "手动档案 2", "is_auto": false },
	{ "id": "slot_3", "name": "手动档案 3", "is_auto": false },
	{ "id": "slot_4", "name": "手动档案 4", "is_auto": false }
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
		"version": 1,
		"timestamp": 0,
		"datetime": "",
		"playtime_formatted": "00:00",
		"era": 0,
		"era_name": "石器时代",
		"elements_count": 0,
		"territory_radius": 5,
		"inventory_count": 0,
		"furnaces_count": 0,
		"reactors_count": 0,
		"tasks_count": 0
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
	result["version"] = int(parsed.get("version", 1))
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
	result["tasks_count"] = int(meta.get("tasks_count", 0))
	
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
	var tasks_count: int = GameState.task_queue.size() + (1 if not GameState.active_task.is_empty() else 0)
	
	var save_dict: Dictionary = {
		"version": SAVE_VERSION,
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
			"reactors_count": reactors_count,
			"tasks_count": tasks_count
		},
		"game_state": {
			"current_era": GameState.current_era,
			"playtime_seconds": GameState.playtime_seconds,
			"discovered_elements": GameState.discovered_elements,
			"researched_techs": GameState.researched_techs,
			"completed_milestones": GameState.completed_milestones,
			"equipped_tools": GameState.equipped_tools,
			"inventory": GameState.inventory.items,
			"unlocked_blueprints": _serialize_blueprints(),
			"task_queue": _serialize_tasks(GameState.task_queue),
			"active_task": _serialize_task(GameState.active_task),
			"lab_vessel": _serialize_lab_vessel(GameState.lab_vessel),
			"depleted_tiles": _serialize_depleted_tiles(GameState.depleted_tiles),
			"tile_resources": _serialize_tile_resources(GameState.tile_resources),
			"built_furnaces": _serialize_furnaces(GameState.built_furnaces),
			"built_reactors": _serialize_reactors(GameState.built_reactors)
		},
		"world_state": world_data
	}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print("[SaveManager] 写入槽位失败: %s" % path)
		GameState.post_notice("存档写入失败！", Color.RED)
		return false
		
	file.store_string(JSON.stringify(save_dict))
	file.close()
	print("[SaveManager] 进度已成功保存至槽位 (v%d): %s (%s)" % [SAVE_VERSION, slot_id, path])
	if slot_id != "auto":
		GameState.post_notice("进度已成功保存至【%s】！" % def_name, Color(0.3, 0.9, 0.5))
	return true

static func load_from_slot(slot_id: String, world_node: Node2D = null) -> bool:
	check_legacy_migration()
	var path = get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		GameState.post_notice("该存档槽位为空！", Color.YELLOW)
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		GameState.post_notice("无法打开存档文件！", Color.RED)
		return false
		
	var json_str = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		GameState.post_notice("存档数据损坏或格式错误！", Color.RED)
		return false
		
	var version = int(parsed.get("version", 1))
	var gs_data = parsed.get("game_state", {})
	
	GameState.current_era = int(gs_data.get("current_era", 0))
	GameState.playtime_seconds = float(gs_data.get("playtime_seconds", 0.0))
	
	GameState.discovered_elements = []
	for num in gs_data.get("discovered_elements", []):
		GameState.discovered_elements.append(int(num))
		
	var r_techs: Array[String] = []
	for t in gs_data.get("researched_techs", []):
		r_techs.append(str(t))
	GameState.researched_techs = r_techs
	
	var c_milestones: Array[String] = []
	for m in gs_data.get("completed_milestones", []):
		c_milestones.append(str(m))
	GameState.completed_milestones = c_milestones
		
	GameState.equipped_tools = gs_data.get("equipped_tools", {
		"axe": "bare_hands",
		"pickaxe": "bare_hands"
	})
	
	GameState.inventory.items = {}
	var inv_data = gs_data.get("inventory", {})
	for k in inv_data.keys():
		# 旧档物品键迁移：iron_ore → hematite，halite → rock_salt (与 items.json 对齐)
		var nk = LEGACY_ITEM_KEYS.get(k, k)
		GameState.inventory.items[nk] = GameState.inventory.items.get(nk, 0) + int(inv_data[k])
	GameState.inventory.item_changed.emit("", 0)
	
	_deserialize_blueprints(gs_data.get("unlocked_blueprints", {}))
	
	# v3 专属模拟层状态 (向下兼容 v2 旧档)
	if version >= 3:
		var q_data = gs_data.get("task_queue", [])
		GameState.task_queue = _deserialize_tasks(q_data, version)
		
		var act_data = gs_data.get("active_task", {})
		if act_data is Dictionary and not act_data.is_empty():
			GameState.active_task = _deserialize_task(act_data, version)
		else:
			GameState.active_task = {}
			
		GameState.depleted_tiles = _deserialize_depleted_tiles(gs_data.get("depleted_tiles", []))
		if version >= 4:
			_deserialize_tile_resources(gs_data.get("tile_resources", []))
		_deserialize_lab_vessel(gs_data.get("lab_vessel", {}))
		_deserialize_furnaces(gs_data.get("built_furnaces", []))
		_deserialize_reactors(gs_data.get("built_reactors", []))
	else:
		# v2 旧档：无任务、无溶液、无采空记录，缺的字段当空
		GameState.task_queue = []
		GameState.active_task = {}
		GameState.depleted_tiles = {}
		GameState.built_furnaces.clear()
		GameState.built_reactors.clear()
		if GameState.lab_vessel:
			GameState.lab_vessel.clear()
			GameState.lab_vessel.temperature = 293.15
			
	GameState.task_queue_changed.emit()
	
	var world_data = parsed.get("world_state", {})
	if world_node != null and world_node.has_method("deserialize_world_state"):
		world_node.deserialize_world_state(world_data)
		
	GameState.era_advanced.emit(0, GameState.current_era, GameState.ERA_NAMES[GameState.current_era])
	GameState.post_notice("成功载入【%s】(v%d)！当前时代: %s" % [
		parsed.get("slot_name", slot_id),
		version,
		GameState.ERA_NAMES[GameState.current_era]
	], Color(0.2, 0.9, 1.0))
	return true

static func delete_slot(slot_id: String) -> bool:
	var path = get_slot_path(slot_id)
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		return (err == OK)
	return true

# --- 序列化辅助函数 ---

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

static func _serialize_tasks(queue: Array[Dictionary]) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for t in queue:
		list.append(_serialize_task(t))
	return list

static func _serialize_task(t: Dictionary) -> Dictionary:
	if t.is_empty():
		return {}
	return {
		"id": int(t.get("id", 0)),
		"action_id": str(t.get("action_id", "mine")),
		"hex_q": int(t.get("hex_q", 0)),
		"hex_r": int(t.get("hex_r", 0)),
		"target_key": str(t.get("target_key", "")),
		"yield_amount": int(t.get("yield_amount", 1)),
		"title": str(t.get("title", "")),
		"icon": str(t.get("icon", "")),
		"world_pos_x": float(t.get("world_pos_x", 0.0)),
		"world_pos_y": float(t.get("world_pos_y", 0.0)),
		"time_required": float(t.get("time_required", t.get("total_time", 1.0))),
		"repeat_count": int(t.get("repeat_count", 1)),
		"current_cycle": int(t.get("current_cycle", 1)),
		# begin_time 是本次进程的 ticks_msec，跨进程无意义；只保存已进行的秒数
		"elapsed": (Time.get_ticks_msec() - int(t["begin_time"])) / 1000.0 if int(t.get("begin_time", 0)) != 0 else 0.0
	}

static func _deserialize_tasks(tasks_array: Array, version: int = SAVE_VERSION) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for item in tasks_array:
		if item is Dictionary:
			var t = _deserialize_task(item, version)
			t["begin_time"] = 0 # 排队任务在开工时才计时
			list.append(t)
	return list

static func _deserialize_task(item: Dictionary, version: int = SAVE_VERSION) -> Dictionary:
	var now = Time.get_ticks_msec()
	var time_req = float(item.get("time_required", item.get("total_time", 1.0)))
	# v4 保存 elapsed 秒数；v2 保存 elapsed_time；v3 的 begin_time 属于旧进程，按刚开工处理
	var elapsed = float(item.get("elapsed", item.get("elapsed_time", 0.0)))
	# begin_time 为 0 表示未开工，因此恢复值至少为 1；进程刚启动时可能为负数，仍然有效
	var b_time = now - int(clampf(elapsed, 0.0, time_req) * 1000.0)
	if b_time == 0:
		b_time = 1

	return {
		"id": int(item.get("id", 0)),
		"action_id": str(item.get("action_id", "mine")),
		"hex_q": int(item.get("hex_q", 0)),
		"hex_r": int(item.get("hex_r", 0)),
		"target_key": str(item.get("target_key", "")),
		"yield_amount": int(item.get("yield_amount", 1)),
		"title": str(item.get("title", "")),
		"icon": str(item.get("icon", "")),
		"world_pos_x": float(item.get("world_pos_x", 0.0)),
		"world_pos_y": float(item.get("world_pos_y", 0.0)),
		"time_required": time_req,
		"repeat_count": int(item.get("repeat_count", 1)),
		"current_cycle": int(item.get("current_cycle", 1)),
		"begin_time": b_time
	}

static func _serialize_lab_vessel(vessel: MixtureBuffer) -> Dictionary:
	if vessel == null:
		return {}
	return {
		"temperature": vessel.temperature,
		"applied_voltage": vessel.applied_voltage,
		"container_type": vessel.container_type,
		"reaction_timer": vessel.reaction_timer,
		"burner_on": GameState.sim.lab_burner_on,
		"components": vessel.components.duplicate()
	}

static func _deserialize_lab_vessel(data: Dictionary) -> void:
	if GameState.lab_vessel == null:
		return
	GameState.lab_vessel.clear()
	GameState.lab_vessel.temperature = float(data.get("temperature", 293.15))
	GameState.lab_vessel.applied_voltage = float(data.get("applied_voltage", 0.0))
	GameState.lab_vessel.container_type = str(data.get("container_type", "flask"))
	GameState.lab_vessel.reaction_timer = float(data.get("reaction_timer", 0.0))
	GameState.sim.lab_burner_on = bool(data.get("burner_on", false))
	var comps = data.get("components", {})
	if comps is Dictionary:
		for k in comps.keys():
			GameState.lab_vessel.components[k] = float(comps[k])

# 地块剩余储量 (v4)：保存每个地块的实际剩余量，读档后资源不再回满
static func _serialize_tile_resources(tiles: Dictionary) -> Array:
	var list: Array = []
	for h in tiles.keys():
		list.append([int(h.x), int(h.y), tiles[h]])
	return list

static func _deserialize_tile_resources(data: Variant) -> void:
	if not (data is Array) or data.is_empty():
		return
	var restored: Dictionary = {}
	for item in data:
		if item is Array and item.size() == 3 and item[2] is Dictionary:
			var res: Dictionary = {}
			for k in item[2].keys():
				res[LEGACY_ITEM_KEYS.get(k, k)] = int(item[2][k])
			restored[Vector2i(int(item[0]), int(item[1]))] = res
	GameState.tile_resources.clear()
	GameState.tile_resources.merge(restored)

static func _serialize_depleted_tiles(tiles: Dictionary) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for h in tiles.keys():
		list.append({
			"q": int(h.x),
			"r": int(h.y),
			"remaining_time": float(tiles[h])
		})
	return list

static func _deserialize_depleted_tiles(tiles_data: Variant) -> Dictionary:
	var dict: Dictionary = {}
	if tiles_data is Array:
		for item in tiles_data:
			if item is Dictionary and item.has("q") and item.has("r"):
				var coord = Vector2i(int(item["q"]), int(item["r"]))
				dict[coord] = float(item.get("remaining_time", 60.0))
	return dict

static func _serialize_furnaces(furnaces: Dictionary) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for hex in furnaces.keys():
		var f = furnaces[hex]
		var buf = f.get("buffer")
		var comps: Dictionary = {}
		var temp: float = 293.15
		if buf != null and "components" in buf:
			comps = buf.components.duplicate()
			temp = buf.temperature
		list.append({
			"hex_q": hex.x,
			"hex_r": hex.y,
			"type": str(f.get("type", "furnace")),
			"temperature": temp,
			"burn_timer": float(f.get("burn_timer", 0.0)),
			"is_active_fire": bool(f.get("is_active_fire", false)),
			"components": comps
		})
	return list

static func _deserialize_furnaces(furnaces_data: Variant) -> void:
	GameState.built_furnaces.clear()
	if furnaces_data is Array:
		for item in furnaces_data:
			if item is Dictionary and item.has("hex_q") and item.has("hex_r"):
				var hex = Vector2i(int(item["hex_q"]), int(item["hex_r"]))
				var b_type = str(item.get("type", "furnace"))
				var buf = MixtureBuffer.new()
				buf.container_type = b_type
				buf.temperature = float(item.get("temperature", 293.15))
				var comps = item.get("components", {})
				if comps is Dictionary:
					for k in comps.keys():
						buf.components[k] = float(comps[k])
				GameState.built_furnaces[hex] = {
					"type": b_type,
					"buffer": buf,
					"burn_timer": float(item.get("burn_timer", 0.0)),
					"is_active_fire": bool(item.get("is_active_fire", false))
				}

static func _serialize_reactors(reactors: Dictionary) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for hex in reactors.keys():
		var r = reactors[hex]
		list.append({
			"hex_q": hex.x,
			"hex_r": hex.y,
			"blueprint_id": str(r.get("blueprint_id", "")),
			"cycle_progress": float(r.get("cycle_progress", 0.0)),
			"total_produced": int(r.get("total_produced", 0))
		})
	return list

static func _deserialize_reactors(reactors_data: Variant) -> void:
	GameState.built_reactors.clear()
	if reactors_data is Array:
		for item in reactors_data:
			if item is Dictionary and item.has("hex_q") and item.has("hex_r"):
				var hex = Vector2i(int(item["hex_q"]), int(item["hex_r"]))
				GameState.built_reactors[hex] = {
					"blueprint_id": str(item.get("blueprint_id", "")),
					"cycle_progress": float(item.get("cycle_progress", 0.0)),
					"total_produced": int(item.get("total_produced", 0))
				}
