# simulation.gd
# 游戏核心模拟层 (Simulation Layer): 纯数据状态与规则逻辑，统一一秒时间戳钟，完全解耦场景视图
class_name Simulation
extends RefCounted

const DataDB = preload("res://src/core/data_db.gd")
const PlayerInventory = preload("res://src/core/player_inventory.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")
const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")

signal element_discovered(element_number: int, item_key: String)
signal notification_posted(text: String, color: Color)
signal era_advanced(old_era: int, new_era: int, era_name: String)
signal blueprint_unlocked(blueprint: ProcessBlueprint)
signal tool_equipped(tool_key: String)

signal task_queue_changed
signal task_started(task: Dictionary)
signal task_progress_updated(task: Dictionary, percent: float, remaining_time: float)
signal task_completed(task: Dictionary)
signal task_cancelled(task: Dictionary)

signal tile_depleted(hex: Vector2i)
signal tile_respawned(hex: Vector2i)
signal structure_built(structure_key: String, hex: Vector2i)

const MAX_QUEUE_SIZE: int = 8

var inventory: PlayerInventory
var solver: ChemistrySolver
var lab_vessel: MixtureBuffer

var discovered_elements: Array[int] = []
var unlocked_blueprints: Dictionary = {} # id -> ProcessBlueprint
var equipped_tools: Dictionary = {
	"axe": "bare_hands",
	"pickaxe": "bare_hands"
}

var current_era: int = 0
var playtime_seconds: float = 0.0

# 任务作业队列 (存毫秒时间戳与纯数据)
var task_queue: Array[Dictionary] = []
var active_task: Dictionary = {}
var _task_id_counter: int = 0

# 地块采空与重生状态: Vector2i(q, r) -> float (剩余重生秒数)
var depleted_tiles: Dictionary = {}

# 世界地图纯数据
var hex_gen: HexWorldGenerator
var world_resources: Dictionary = {} # Vector2i(q, r) -> item_key
var world_biomes: Dictionary = {}    # Vector2i(q, r) -> BiomeType
var WORLD_HEX_RADIUS: int = 18

# 工业建筑模拟层状态: Vector2i(q, r) -> Dictionary
var built_furnaces: Dictionary = {}
var built_reactors: Dictionary = {}

# 1 秒定时结算钟
var _second_accumulator: float = 0.0

var ERA_NAMES: Array[String]:
	get:
		var names: Array[String] = []
		for era in DataDB.eras:
			names.append(str(era.get("display_name", era.get("name", ""))))
		if names.is_empty():
			names = ["石器时代 (Stone Age)", "炼金术时代 (Alchemy Age)", "近代化学时代 (Modern Chemistry)"]
		return names

func _init() -> void:
	DataDB.initialize()
	inventory = PlayerInventory.new()
	solver = ChemistrySolver.new()
	lab_vessel = MixtureBuffer.new()
	lab_vessel.container_type = "flask"
	lab_vessel.temperature = 293.15
	
	solver.element_discovered.connect(_on_solver_element_discovered)
	init_world_map(12345, WORLD_HEX_RADIUS)

func init_world_map(map_seed: int = 12345, radius: int = 18) -> void:
	WORLD_HEX_RADIUS = radius
	hex_gen = HexWorldGenerator.new(map_seed)
	world_resources.clear()
	world_biomes.clear()
	
	for q in range(-radius, radius + 1):
		var r1 = max(-radius, -q - radius)
		var r2 = min(radius, -q + radius)
		for r in range(r1, r2 + 1):
			var coord = Vector2i(q, r)
			var biome = hex_gen.get_biome(q, r)
			world_biomes[coord] = biome
			if abs(q) <= 1 and abs(r) <= 1:
				continue
			var spawn_item = hex_gen.determine_resource_spawn(q, r, biome)
			if spawn_item != "":
				world_resources[coord] = spawn_item

func _on_solver_element_discovered(elem_num: int, item_key: String) -> void:
	unlock_element(elem_num, item_key)

func post_notice(text: String, color: Color = Color.WHITE) -> void:
	notification_posted.emit(text, color)

func unlock_element(elem_num: int, item_key: String) -> void:
	if not discovered_elements.has(elem_num):
		discovered_elements.append(elem_num)
		discovered_elements.sort()
		var elem = DataDB.get_element(elem_num)
		var sym = elem.get("symbol", "?")
		var cname = elem.get("name", item_key)
		var banner = "🌟 【重大发现】你首次提纯并点亮了第 %d 号化学元素：%s (%s)！" % [elem_num, cname, sym]
		post_notice(banner, Color(1.0, 0.85, 0.2))
		element_discovered.emit(elem_num, item_key)
		_check_era_advancement()

func unlock_blueprint(bp: ProcessBlueprint) -> void:
	if not unlocked_blueprints.has(bp.id):
		unlocked_blueprints[bp.id] = bp
		blueprint_unlocked.emit(bp)
		post_notice("📜 成功固化导出【工业工艺蓝图: %s】！可插入反应塔批量生产！" % bp.display_name, Color.CYAN)
		_check_era_advancement()

func equip_tool(slot: String, tool_key: String) -> void:
	equipped_tools[slot] = tool_key
	tool_equipped.emit(tool_key)
	var t_name = DataDB.get_item(tool_key).get("name", tool_key)
	if tool_key == "flint_axe":
		t_name = "原始燧石手斧"
	elif tool_key == "stone_pickaxe":
		t_name = "粗制石镐"
	post_notice("⚒️ 成功装配工具: 【%s】！能力大幅解锁！" % t_name, Color.GREEN)

func _check_era_advancement() -> void:
	var era_def = DataDB.get_era(current_era)
	var req = era_def.get("advance_threshold", {})
	if req.is_empty():
		return
	var needed_elems = req.get("elements", [])
	var min_bps = int(req.get("min_blueprints", 0))
	if needed_elems.is_empty() and min_bps <= 0:
		return
	for elem_num in needed_elems:
		if not discovered_elements.has(int(elem_num)):
			return
	if min_bps > 0 and unlocked_blueprints.size() < min_bps:
		return
	advance_era(current_era + 1)

func advance_era(target_era: int) -> void:
	if target_era > current_era and target_era < ERA_NAMES.size():
		var old = current_era
		current_era = target_era
		era_advanced.emit(old, current_era, ERA_NAMES[current_era])
		post_notice("🏛️ 【伟大跨越】文明迈入新纪元：%s！" % ERA_NAMES[current_era], Color(1.0, 0.88, 0.3))

func get_current_territory_radius() -> int:
	var era_def = DataDB.get_era(current_era)
	if era_def.has("territory_radius"):
		return int(era_def["territory_radius"])
	return 5 + current_era * 3

func is_hex_in_territory(q: int, r: int) -> bool:
	var dist = (abs(q) + abs(q + r) + abs(r)) / 2
	return dist <= get_current_territory_radius()

func is_tile_depleted(hex: Vector2i) -> bool:
	return depleted_tiles.has(hex)

func get_hex_resource(hex: Vector2i) -> String:
	return world_resources.get(hex, "")

# --- 时间步进 (一秒时间戳钟) ---

func tick(delta: float) -> void:
	playtime_seconds += delta
	
	_second_accumulator += delta
	if _second_accumulator >= 1.0:
		_second_accumulator -= 1.0
		_on_second_tick()

func _on_second_tick() -> void:
	var now = Time.get_ticks_msec()
	
	# 1. 任务完成结算 (到点才完成，按毫秒时间戳)
	if not active_task.is_empty():
		var begin_time: int = int(active_task.get("begin_time", 0))
		var time_req: float = float(active_task.get("time_required", 1.0))
		var elapsed = (now - begin_time) / 1000.0
		var pct = clamp(elapsed / time_req, 0.0, 1.0)
		var rem = max(0.0, time_req - elapsed)
		task_progress_updated.emit(active_task, pct, rem)
		if elapsed >= time_req:
			_complete_active_task()
			
	# 2. 地块重生结算
	var respawned: Array[Vector2i] = []
	for hex in depleted_tiles.keys():
		var rem_time: float = depleted_tiles[hex] - 1.0
		if rem_time <= 0.0:
			respawned.append(hex)
		else:
			depleted_tiles[hex] = rem_time
			
	for h in respawned:
		depleted_tiles.erase(h)
		tile_respawned.emit(h)
		
	# 3. 实验台溶液结算 (共用一秒节拍)
	if lab_vessel and lab_vessel.total_moles() > 0:
		solver.solve(lab_vessel, 1.0)
		
	# 4. 熔炉溶液结算 (共用一秒节拍)
	for hex in built_furnaces.keys():
		var f = built_furnaces[hex]
		var buf = f["buffer"]
		if f.get("is_active_fire", false):
			var b_timer = f.get("burn_timer", 0.0) - 1.0
			f["burn_timer"] = max(0.0, b_timer)
			buf.temperature = move_toward(buf.temperature, 1100.0, 180.0)
			if f["burn_timer"] <= 0.0:
				f["is_active_fire"] = false
		else:
			buf.temperature = move_toward(buf.temperature, 293.15, 35.0)
			
		if buf.total_moles() > 0:
			var res = solver.solve(buf, 1.0)
			if res["occurred"]:
				buf.consume_substance("carbon_dioxide", 999.0)
				buf.consume_substance("carbon_monoxide", 999.0)
				for p_key in res.get("products", []):
					if buf.has_substance(p_key, 0.1):
						var p_amount = buf.consume_substance(p_key, 999.0)
						var p_int = int(ceil(p_amount))
						if p_int > 0:
							inventory.add_item(p_key, p_int)
							var iname = DataDB.get_item(p_key).get("name", p_key)
							post_notice("✨ 熔炉炼制完成！成功收获 %s x%d，已收入背包！" % [iname, p_int], Color(0.9, 0.65, 0.2))

	# 5. 工业反应塔结算 (共用一秒节拍)
	for hex in built_reactors.keys():
		var r = built_reactors[hex]
		var bp_id = r.get("blueprint_id", "")
		if bp_id != "" and unlocked_blueprints.has(bp_id):
			var bp = unlocked_blueprints[bp_id]
			var has_inputs = true
			for in_k in bp.inputs.keys():
				if not inventory.has_item(in_k, int(ceil(bp.inputs[in_k]))):
					has_inputs = false
					break
			if has_inputs:
				r["cycle_progress"] = r.get("cycle_progress", 0.0) + 1.0
				if r["cycle_progress"] >= bp.duration_seconds:
					r["cycle_progress"] = 0.0
					for in_k in bp.inputs.keys():
						inventory.remove_item(in_k, int(ceil(bp.inputs[in_k])))
					for out_k in bp.outputs.keys():
						var out_qty = int(ceil(bp.outputs[out_k]))
						inventory.add_item(out_k, out_qty)
						r["total_produced"] = r.get("total_produced", 0) + out_qty
					post_notice("⚙️ 工业反应塔批量产出: %s 完成！累计自动化产出: %d" % [bp.display_name, r["total_produced"]], Color(0.3, 0.8, 1.0))

# --- 任务队列调度 ---

func calculate_task_duration(item_key: String) -> float:
	var pick = equipped_tools.get("pickaxe", "bare_hands")
	var axe = equipped_tools.get("axe", "bare_hands")
	if item_key == "wood":
		return 2.0 if axe == "flint_axe" else 4.0
	elif item_key == "stick":
		return 0.8
	elif item_key == "stone" or item_key == "flint":
		return 1.0
	else:
		if pick == "iron_pickaxe": return 1.2
		elif pick == "copper_pickaxe": return 2.0
		elif pick == "stone_pickaxe": return 3.0
		else: return 5.0

func can_mine(item_key: String) -> Dictionary:
	var pick = equipped_tools.get("pickaxe", "bare_hands")
	var axe = equipped_tools.get("axe", "bare_hands")
	if item_key == "wood":
		if axe == "bare_hands":
			return { "allowed": false, "reason": "徒手无法砍伐原木！请先在手工作坊 (C) 制作【原始燧石斧】！" }
	elif item_key in ["malachite", "iron_ore", "hematite", "sulfur"]:
		if pick == "bare_hands":
			return { "allowed": false, "reason": "徒手无法开采坚硬矿脉！请先在手工作坊 (C) 制作【粗制石镐】！" }
	return { "allowed": true, "reason": "" }

func queue_hex_mine(hex: Vector2i, item_key: String, world_pos: Vector2 = Vector2.ZERO) -> bool:
	if not is_hex_in_territory(hex.x, hex.y):
		post_notice("🚩 此资源超出当前文明领地边界！请提升时代纪元以拓疆辟土！", Color(1.0, 0.45, 0.3))
		return false
		
	var check = can_mine(item_key)
	if not check["allowed"]:
		post_notice(check["reason"], Color(1.0, 0.4, 0.4))
		return false
		
	var dur = calculate_task_duration(item_key)
	var iname = DataDB.get_item(item_key).get("name", item_key)
	var icon = "⛏️"
	if item_key == "wood": icon = "🪓"
	elif item_key == "stick": icon = "🌿"
	elif item_key == "stone": icon = "🪨"
	elif item_key == "flint": icon = "💎"
	
	var task: Dictionary = {
		"action_id": "mine",
		"hex_q": hex.x,
		"hex_r": hex.y,
		"target_key": item_key,
		"yield_amount": 2,
		"title": "%s %s" % [icon, iname],
		"icon": icon,
		"world_pos_x": world_pos.x,
		"world_pos_y": world_pos.y,
		"time_required": dur,
		"begin_time": 0
	}
	return add_task(task)

func queue_hex_water(hex: Vector2i, world_pos: Vector2 = Vector2.ZERO) -> bool:
	if not is_hex_in_territory(hex.x, hex.y):
		post_notice("🚩 此水域超出当前文明领地边界！", Color(1.0, 0.45, 0.3))
		return false
		
	var task: Dictionary = {
		"action_id": "water",
		"hex_q": hex.x,
		"hex_r": hex.y,
		"target_key": "water",
		"yield_amount": 1,
		"title": "💧 汲取卤水",
		"icon": "💧",
		"world_pos_x": world_pos.x,
		"world_pos_y": world_pos.y,
		"time_required": 1.8,
		"begin_time": 0
	}
	return add_task(task)

func queue_hex_forage(hex: Vector2i, biome_name: String, world_pos: Vector2 = Vector2.ZERO) -> bool:
	if not is_hex_in_territory(hex.x, hex.y):
		post_notice("🚩 此区域超出当前文明领地边界！", Color(1.0, 0.45, 0.3))
		return false
		
	var task: Dictionary = {
		"action_id": "forage",
		"hex_q": hex.x,
		"hex_r": hex.y,
		"target_key": "stick",
		"yield_amount": 2,
		"title": "🌿 拾取断枝",
		"icon": "🌿",
		"world_pos_x": world_pos.x,
		"world_pos_y": world_pos.y,
		"time_required": 0.8,
		"begin_time": 0
	}
	return add_task(task)

func add_task(task_data: Dictionary) -> bool:
	if task_queue.size() >= MAX_QUEUE_SIZE:
		post_notice("⚠️ 工作队列已满（上限 %d 项），请等待当前作业完成！" % MAX_QUEUE_SIZE, Color.YELLOW)
		return false
		
	_task_id_counter += 1
	var t = task_data.duplicate()
	t["id"] = _task_id_counter
	
	if active_task.is_empty():
		t["begin_time"] = Time.get_ticks_msec()
		active_task = t
		task_started.emit(active_task)
	else:
		task_queue.append(t)
		
	task_queue_changed.emit()
	return true

func cancel_task(task_id: int) -> void:
	if not active_task.is_empty() and active_task.get("id") == task_id:
		var cancelled = active_task.duplicate()
		active_task.clear()
		task_cancelled.emit(cancelled)
		if not task_queue.is_empty():
			active_task = task_queue.pop_front()
			active_task["begin_time"] = Time.get_ticks_msec()
			task_started.emit(active_task)
		task_queue_changed.emit()
		return
		
	for i in range(task_queue.size()):
		if task_queue[i].get("id") == task_id:
			var cancelled = task_queue[i]
			task_queue.remove_at(i)
			task_cancelled.emit(cancelled)
			task_queue_changed.emit()
			return

func _complete_active_task() -> void:
	var finished_task = active_task.duplicate()
	var act_id = finished_task.get("action_id", "mine")
	var hex = Vector2i(int(finished_task.get("hex_q", 0)), int(finished_task.get("hex_r", 0)))
	var t_key = finished_task.get("target_key", "")
	var amount = int(finished_task.get("yield_amount", 1))
	
	if act_id == "mine":
		inventory.add_item(t_key, amount)
		if t_key == "stone" and randf() < 0.25:
			inventory.add_item("flint", 1)
		depleted_tiles[hex] = 60.0
		tile_depleted.emit(hex)
	elif act_id == "forage":
		inventory.add_item("stick", amount)
		depleted_tiles[hex] = 45.0
		tile_depleted.emit(hex)
	elif act_id == "water":
		inventory.add_item("water", 1)
		if randf() < 0.35:
			inventory.add_item("rock_salt", 1)
			
	task_completed.emit(finished_task)
	active_task.clear()
	
	if not task_queue.is_empty():
		active_task = task_queue.pop_front()
		active_task["begin_time"] = Time.get_ticks_msec()
		task_started.emit(active_task)
		
	task_queue_changed.emit()

func get_active_task_hex() -> Vector2i:
	if active_task.is_empty():
		return Vector2i(9999, 9999)
	return Vector2i(int(active_task.get("hex_q", 9999)), int(active_task.get("hex_r", 9999)))

# --- 打造与建造统一执行路径 (读表驱动) ---

func craft_tool(recipe_key: String) -> bool:
	var recipe = DataDB.get_crafting_recipe(recipe_key)
	if recipe.is_empty():
		post_notice("❌ 未知制造配方: %s" % recipe_key, Color.RED)
		return false
		
	var req_items = recipe.get("required_items", [])
	if not _has_all_ingredients(req_items):
		post_notice("❌ 原料不足！制作【%s】失败" % recipe.get("name", recipe_key), Color.RED)
		return false
		
	_consume_all_ingredients(req_items)
	
	var r_type = recipe.get("type", "tool")
	if r_type == "tool":
		var slot = recipe.get("slot", "pickaxe")
		var t_key = recipe.get("result_tool", recipe_key)
		equip_tool(slot, t_key)
	elif r_type == "item":
		var res_item = recipe.get("result_item", "")
		var res_qty = int(recipe.get("result_quantity", 1))
		inventory.add_item(res_item, res_qty)
		
	var notice_text = recipe.get("notice", "制作成功: %s" % recipe.get("name", recipe_key))
	post_notice(notice_text, Color.GREEN)
	return true

func build_structure(structure_key: String, hex: Vector2i) -> bool:
	if not is_hex_in_territory(hex.x, hex.y):
		post_notice("🚩 无法在此建造：超出当前文明领地边界！", Color(1.0, 0.4, 0.4))
		return false
		
	var recipe = DataDB.get_building_recipe(structure_key)
	if recipe.is_empty():
		post_notice("❌ 未知建筑类型: %s" % structure_key, Color.RED)
		return false
		
	var req_items = recipe.get("required_items", [])
	if not _has_all_ingredients(req_items):
		post_notice("❌ 建造原料不足！需要: %s" % _get_ingredients_desc(req_items), Color.RED)
		return false
		
	_consume_all_ingredients(req_items)
	
	if structure_key == "furnace":
		var f_buf = MixtureBuffer.new()
		f_buf.container_type = "furnace"
		f_buf.temperature = 293.15
		built_furnaces[hex] = {
			"buffer": f_buf,
			"burn_timer": 0.0,
			"is_active_fire": false
		}
	elif structure_key == "industrial_reactor":
		built_reactors[hex] = {
			"blueprint_id": "",
			"cycle_progress": 0.0,
			"total_produced": 0
		}
		
	var notice_text = recipe.get("notice", "建造成功: %s" % recipe.get("name", structure_key))
	post_notice(notice_text, Color(0.3, 0.9, 0.5))
	structure_built.emit(structure_key, hex)
	return true

func furnace_add_fuel(hex: Vector2i) -> bool:
	if not built_furnaces.has(hex):
		return false
	var f = built_furnaces[hex]
	if inventory.remove_item("charcoal", 1) or inventory.remove_item("wood", 2):
		f["is_active_fire"] = true
		f["burn_timer"] = f.get("burn_timer", 0.0) + 18.0
		f["buffer"].add_substance("charcoal", 1.0)
		post_notice("🔥 向熔炉投入木炭燃料，炉膛升起熊熊烈火！", Color.ORANGE)
		return true
	else:
		post_notice("背包中没有木炭或木材可用作燃料！", Color.RED)
		return false

func furnace_add_ore(hex: Vector2i, key: String, amount: int = 1) -> bool:
	if not built_furnaces.has(hex):
		return false
	var f = built_furnaces[hex]
	if inventory.remove_item(key, amount):
		f["buffer"].add_substance(key, float(amount))
		var iname = DataDB.get_item(key).get("name", key)
		post_notice("📥 投入原料: %s x%d 到炉膛中" % [iname, amount], Color.CYAN)
		return true
	else:
		post_notice("背包中没有足够的原料！", Color.RED)
		return false

func reactor_install_blueprint(hex: Vector2i, bp_id: String) -> bool:
	if not built_reactors.has(hex):
		return false
	if not unlocked_blueprints.has(bp_id):
		return false
	built_reactors[hex]["blueprint_id"] = bp_id
	built_reactors[hex]["cycle_progress"] = 0.0
	post_notice("📥 已向工业反应塔插装芯片: 【%s】" % unlocked_blueprints[bp_id].display_name, Color.CYAN)
	return true

func _has_all_ingredients(req_items: Array) -> bool:
	for req in req_items:
		var q_needed = int(req.get("quantity", 1))
		var k = req.get("key")
		if k is Array:
			var total = 0
			for alt_k in k:
				total += inventory.get_count(alt_k)
			if total < q_needed:
				return false
		elif k is String:
			if inventory.get_count(k) < q_needed:
				return false
	return true

func _consume_all_ingredients(req_items: Array) -> void:
	for req in req_items:
		var q_needed = int(req.get("quantity", 1))
		var k = req.get("key")
		if k is Array:
			for alt_k in k:
				var available = inventory.get_count(alt_k)
				var take = min(available, q_needed)
				if take > 0:
					inventory.remove_item(alt_k, take)
					q_needed -= take
				if q_needed <= 0:
					break
		elif k is String:
			inventory.remove_item(k, q_needed)

func _get_ingredients_desc(req_items: Array) -> String:
	var desc_parts: Array[String] = []
	for req in req_items:
		var q = req.get("quantity", 1)
		var k = req.get("key")
		if k is Array:
			desc_parts.append("%s x%d" % [k[0], q])
		else:
			desc_parts.append("%s x%d" % [k, q])
	return ", ".join(desc_parts)

func get_formatted_playtime() -> String:
	var total_sec = int(playtime_seconds)
	var hrs = total_sec / 3600
	var mins = (total_sec % 3600) / 60
	var secs = total_sec % 60
	if hrs > 0:
		return "%02d:%02d:%02d" % [hrs, mins, secs]
	else:
		return "%02d:%02d" % [mins, secs]

func reset_to_new_game() -> void:
	current_era = 0
	discovered_elements.clear()
	equipped_tools = {
		"axe": "bare_hands",
		"pickaxe": "bare_hands"
	}
	unlocked_blueprints.clear()
	task_queue.clear()
	active_task.clear()
	depleted_tiles.clear()
	built_furnaces.clear()
	built_reactors.clear()
	if inventory != null:
		inventory.items.clear()
		inventory.item_changed.emit("", 0)
	if lab_vessel != null:
		lab_vessel.clear()
		lab_vessel.temperature = 293.15
	playtime_seconds = 0.0
	init_world_map(12345, WORLD_HEX_RADIUS)
	era_advanced.emit(0, 0, ERA_NAMES[0])
