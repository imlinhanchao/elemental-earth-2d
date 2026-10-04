# test_save_v3.gd
# 自动化测试脚本：验证 SaveManager v3 规范、任务队列/溶液/采空瓦片持久化及 v2 兼容性
extends Node

const DataDB = preload("res://src/core/data_db.gd")
const SaveManager = preload("res://src/core/save_manager.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")

func _ready() -> void:
	print("\n========================================")
	print("💾 [Elemental Earth 2D] 存档系统 v3 自动化测试")
	print("========================================")
	
	DataDB.initialize()
	GameState.reset_to_new_game()
	
	# 1. 模拟写入复杂模拟层状态
	GameState.current_era = 1
	GameState.inventory.add_item("copper", 5)
	GameState.inventory.add_item("wood", 10)
	GameState.equip_tool("axe", "flint_axe")
	GameState.unlock_element(29, "copper")
	
	var bp = ProcessBlueprint.new("bp_smelt_copper", "连续炼铜工艺", {"malachite": 1.0}, {"copper": 1.0}, 850.0)
	GameState.unlock_blueprint(bp)
	
	# 注入任务队列与进行中任务
	var t_now = Time.get_ticks_msec()
	GameState.task_queue.append({
		"id": 101,
		"action_id": "mine",
		"hex_q": 2,
		"hex_r": -1,
		"target_key": "malachite",
		"yield_amount": 2,
		"title": "⛏️ 孔雀石",
		"icon": "⛏️",
		"world_pos_x": 100.0,
		"world_pos_y": 50.0,
		"time_required": 3.0,
		"begin_time": 0
	})
	GameState.active_task = {
		"id": 100,
		"action_id": "forage",
		"hex_q": 0,
		"hex_r": 1,
		"target_key": "stick",
		"yield_amount": 1,
		"title": "🌿 枯树枝",
		"icon": "🌿",
		"world_pos_x": 0.0,
		"world_pos_y": 30.0,
		"time_required": 2.0,
		"begin_time": 50000
	}
	
	# 注入熔炉与反应塔
	var f_buf = MixtureBuffer.new()
	f_buf.container_type = "furnace"
	f_buf.temperature = 1050.0
	f_buf.add_substance("charcoal", 2.0)
	GameState.built_furnaces[Vector2i(1, 1)] = {
		"buffer": f_buf,
		"burn_timer": 15.0,
		"is_active_fire": true
	}
	GameState.built_reactors[Vector2i(2, 2)] = {
		"blueprint_id": "bp_smelt_copper",
		"cycle_progress": 1.0,
		"total_produced": 4
	}
	
	# 注入实验台溶液
	GameState.lab_vessel.temperature = 550.0
	GameState.lab_vessel.add_substance("water", 3.0)
	GameState.lab_vessel.add_substance("malachite", 1.5)
	
	# 注入采空格子
	GameState.depleted_tiles[Vector2i(3, -2)] = 45.0
	
	# 2. 保存至测试槽位
	var slot_id = "test_slot"
	var save_ok = SaveManager.save_to_slot(slot_id, null)
	assert(save_ok, "存档写入失败!")
	print(" -> v3 存档保存成功")
	
	# 验证磁盘 JSON 结构
	var path = SaveManager.get_slot_path(slot_id)
	var file = FileAccess.open(path, FileAccess.READ)
	assert(file != null, "存档文件不存在!")
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(text)
	assert(json.get("version") == 3, "存档版本必须为 3!")
	var gs = json.get("game_state", {})
	assert(gs.get("task_queue", []).size() == 1, "任务队列序列化失败!")
	assert(not gs.get("active_task", {}).is_empty(), "进行中任务序列化失败!")
	assert(gs.get("lab_vessel", {}).get("temperature") == 550.0, "实验台温度序列化失败!")
	assert(gs.get("depleted_tiles", []).size() == 1, "采空格子序列化失败!")
	assert(gs.get("built_furnaces", []).size() == 1, "熔炉状态序列化失败!")
	assert(gs.get("built_reactors", []).size() == 1, "反应塔状态序列化失败!")
	print(" -> v3 JSON 结构字段验证通过: version=3, 队列/溶液/采空瓦片/熔炉/反应塔完整")
	
	# 3. 清空游戏状态后读档恢复
	GameState.reset_to_new_game()
	assert(GameState.inventory.items.is_empty(), "重置后背包应为空")
	assert(GameState.task_queue.is_empty(), "重置后任务队列应为空")
	assert(GameState.depleted_tiles.is_empty(), "重置后采空列表应为空")
	assert(GameState.built_furnaces.is_empty(), "重置后熔炉应为空")
	assert(GameState.built_reactors.is_empty(), "重置后反应塔应为空")
	
	var load_ok = SaveManager.load_from_slot(slot_id, null)
	assert(load_ok, "v3 存档载入失败!")
	assert(GameState.current_era == 1, "时代恢复错误!")
	assert(GameState.inventory.get_count("copper") == 5, "背包物品恢复错误!")
	assert(GameState.equipped_tools["axe"] == "flint_axe", "工具恢复错误!")
	assert(GameState.discovered_elements.has(29), "元素恢复错误!")
	assert(GameState.task_queue.size() == 1, "任务队列恢复错误!")
	assert(GameState.task_queue[0]["hex_q"] == 2, "队列坐标恢复错误!")
	assert(GameState.active_task.get("id") == 100, "进行中任务恢复错误!")
	assert(GameState.active_task.get("begin_time") == 50000, "任务 begin_time 恢复错误!")
	assert(GameState.built_furnaces.has(Vector2i(1, 1)), "熔炉坐标恢复错误!")
	assert(GameState.built_furnaces[Vector2i(1, 1)]["burn_timer"] == 15.0, "熔炉燃烧时间恢复错误!")
	assert(GameState.built_reactors.has(Vector2i(2, 2)), "反应塔坐标恢复错误!")
	assert(GameState.built_reactors[Vector2i(2, 2)]["total_produced"] == 4, "反应塔累计产出恢复错误!")
	assert(GameState.lab_vessel.temperature == 550.0, "实验台温度恢复错误!")
	assert(GameState.lab_vessel.has_substance("water", 2.9), "实验台试剂恢复错误!")
	assert(GameState.depleted_tiles.has(Vector2i(3, -2)), "采空格子恢复错误!")
	print(" -> v3 存档全量恢复校验通过: 时代/背包/工具/队列/溶液/熔炉/反应塔/采空格子全部精确吻合!")
	
	# 4. 测试 v2 旧档向下兼容性
	print("\n[测试] v2 旧版本存档向下兼容性测试:")
	var v2_dict = {
		"version": 2,
		"slot_id": "legacy_v2",
		"slot_name": "旧版存档",
		"game_state": {
			"current_era": 0,
			"playtime_seconds": 120,
			"discovered_elements": [],
			"equipped_tools": { "axe": "bare_hands", "pickaxe": "bare_hands" },
			"inventory": { "stick": 8, "stone": 4 },
			"unlocked_blueprints": {}
		},
		"world_state": {}
	}
	var v2_path = SaveManager.get_slot_path("legacy_v2")
	var v2_file = FileAccess.open(v2_path, FileAccess.WRITE)
	v2_file.store_string(JSON.stringify(v2_dict))
	v2_file.close()
	
	var v2_ok = SaveManager.load_from_slot("legacy_v2", null)
	assert(v2_ok, "v2 存档读取失败!")
	assert(GameState.inventory.get_count("stick") == 8, "v2 背包恢复错误!")
	assert(GameState.task_queue.is_empty(), "v2 缺省任务队列应为空!")
	assert(GameState.active_task.is_empty(), "v2 缺省进行中任务应为空!")
	assert(GameState.depleted_tiles.is_empty(), "v2 缺省采空格子应为空!")
	print(" -> v2 旧档平滑升级载入成功 (缺失字段安全置空，背包正常保留)")
	
	# 清理测试存档文件
	SaveManager.delete_slot(slot_id)
	SaveManager.delete_slot("legacy_v2")
	
	print("\n========================================")
	print("🎉 存档系统 v3 架构升级全部单元测试 100% 通过!")
	print("========================================\n")
	
	get_tree().quit(0)
