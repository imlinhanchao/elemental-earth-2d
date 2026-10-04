# simulation.gd
# 游戏核心模拟层 (Simulation Layer): 纯数据状态与规则逻辑，不持有任何场景节点与视图
class_name Simulation
extends RefCounted

const DataDB = preload("res://src/core/data_db.gd")
const PlayerInventory = preload("res://src/core/player_inventory.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

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

const MAX_QUEUE_SIZE: int = 8
const ERA_NAMES: Array[String] = [
	"石器时代 (Stone Age)",
	"炼金术时代 (Alchemy Age)",
	"近代化学时代 (Modern Chemistry)",
	"电化学时代 (Electrochemistry)",
	"催化与稀土时代 (Catalysis & Rare Earth)",
	"原子能时代 (Atomic Age)"
]

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

# 任务作业队列
var task_queue: Array[Dictionary] = []
var active_task: Dictionary = {}
var _task_id_counter: int = 0

# 地块采空与重生状态: Vector2i(q, r) -> float (剩余重生秒数)
var depleted_tiles: Dictionary = {}

# 1 秒定时结算钟
var _second_accumulator: float = 0.0

func _init() -> void:
	DataDB.initialize()
	inventory = PlayerInventory.new()
	solver = ChemistrySolver.new()
	lab_vessel = MixtureBuffer.new()
	lab_vessel.temperature = 293.15
	
	solver.element_discovered.connect(_on_solver_element_discovered)

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
	if current_era == 0:
		if discovered_elements.has(29): # 单质铜
			advance_era(1)
	elif current_era == 1:
		if discovered_elements.has(26) and unlocked_blueprints.size() >= 2: # 单质铁
			advance_era(2)

func advance_era(target_era: int) -> void:
	if target_era > current_era and target_era < ERA_NAMES.size():
		var old = current_era
		current_era = target_era
		era_advanced.emit(old, current_era, ERA_NAMES[current_era])
		post_notice("🏛️ 【伟大跨越】文明迈入新纪元：%s！" % ERA_NAMES[current_era], Color(1.0, 0.88, 0.3))

func get_current_territory_radius() -> int:
	match current_era:
		0: return 5   # 石器时代
		1: return 8   # 炼金时代
		2: return 11  # 近代化学
		3: return 14  # 电化学
		4: return 17  # 稀土时代
		5: return 20  # 原子能时代
		_: return 5 + current_era * 3

func is_hex_in_territory(q: int, r: int) -> bool:
	var dist = (abs(q) + abs(q + r) + abs(r)) / 2
	return dist <= get_current_territory_radius()

func tick(delta: float) -> void:
	playtime_seconds += delta
	
	# 任务进度推进
	if not active_task.is_empty():
		active_task["elapsed_time"] = active_task.get("elapsed_time", 0.0) + delta
		var total: float = active_task.get("total_time", 1.0)
		var elapsed: float = active_task.get("elapsed_time", 0.0)
		var pct: float = clamp(elapsed / total, 0.0, 1.0)
		var rem: float = max(0.0, total - elapsed)
		task_progress_updated.emit(active_task, pct, rem)
		if elapsed >= total:
			_complete_active_task()
			
	# 地块重生冷却计时
	var respawned: Array[Vector2i] = []
	for hex in depleted_tiles.keys():
		var rem_time: float = depleted_tiles[hex] - delta
		if rem_time <= 0.0:
			respawned.append(hex)
		else:
			depleted_tiles[hex] = rem_time
			
	for h in respawned:
		depleted_tiles.erase(h)
		tile_respawned.emit(h)
		
	# 每秒时钟结算
	_second_accumulator += delta
	if _second_accumulator >= 1.0:
		_second_accumulator -= 1.0
		_on_second_tick()

func _on_second_tick() -> void:
	# 每秒化学求解与被动状态维护
	if lab_vessel and lab_vessel.total_moles() > 0:
		solver.solve(lab_vessel, 1.0)

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
		"total_time": dur,
		"elapsed_time": 0.0
	}
	return add_task(task)

func queue_hex_water(hex: Vector2i, world_pos: Vector2 = Vector2.ZERO) -> bool:
	if not is_hex_in_territory(hex.x, hex.y):
		post_notice("🚩 无法在此开工：超出当前文明领地边界！", Color(1.0, 0.45, 0.3))
		return false
		
	var task: Dictionary = {
		"action_id": "water",
		"hex_q": hex.x,
		"hex_r": hex.y,
		"target_key": "water",
		"title": "💧 汲取卤水",
		"icon": "💧",
		"world_pos_x": world_pos.x,
		"world_pos_y": world_pos.y,
		"total_time": 1.8,
		"elapsed_time": 0.0
	}
	return add_task(task)

func queue_hex_forage(hex: Vector2i, biome_name: String, world_pos: Vector2 = Vector2.ZERO) -> bool:
	if not is_hex_in_territory(hex.x, hex.y):
		post_notice("🚩 无法在此开工：超出当前文明领地边界！", Color(1.0, 0.45, 0.3))
		return false
		
	var task: Dictionary = {
		"action_id": "forage",
		"hex_q": hex.x,
		"hex_r": hex.y,
		"title": "🔍 搜寻%s" % biome_name,
		"icon": "🔍",
		"world_pos_x": world_pos.x,
		"world_pos_y": world_pos.y,
		"total_time": 1.2,
		"elapsed_time": 0.0
	}
	return add_task(task)

func get_active_task_hex() -> Vector2i:
	if active_task.is_empty():
		return Vector2i(9999, 9999)
	return Vector2i(int(active_task.get("hex_q", 9999)), int(active_task.get("hex_r", 9999)))

func add_task(task_data: Dictionary) -> bool:
	if task_queue.size() >= MAX_QUEUE_SIZE:
		post_notice("⚠️ 任务队列已满 (最多可排队 %d 个工作)！" % MAX_QUEUE_SIZE, Color(1.0, 0.6, 0.2))
		return false
		
	_task_id_counter += 1
	task_data["id"] = _task_id_counter
	task_data["elapsed_time"] = 0.0
	
	if active_task.is_empty():
		active_task = task_data
		task_started.emit(active_task)
		post_notice("▶️ 开始工作: 【%s】(预计需 %.1f 秒)..." % [active_task.get("title", "工作"), active_task.get("total_time", 1.0)], Color(0.4, 0.9, 1.0))
	else:
		task_queue.append(task_data)
		post_notice("📥 已加入待办队列: 【%s】(排队 #%d)" % [task_data.get("title", "工作"), task_queue.size()], Color(0.8, 0.8, 0.4))
		
	task_queue_changed.emit()
	return true

func cancel_task(task_id: int) -> void:
	if not active_task.is_empty() and active_task.get("id") == task_id:
		var cancelled = active_task
		active_task = {}
		task_cancelled.emit(cancelled)
		post_notice("⏹️ 取消工作: 【%s】" % cancelled.get("title", "工作"), Color(0.8, 0.4, 0.4))
		_start_next_task()
		task_queue_changed.emit()
		return
		
	for i in range(task_queue.size()):
		if task_queue[i].get("id") == task_id:
			var removed = task_queue[i]
			task_queue.remove_at(i)
			task_cancelled.emit(removed)
			post_notice("⏹️ 从队列移除了工作: 【%s】" % removed.get("title", "工作"), Color(0.8, 0.4, 0.4))
			task_queue_changed.emit()
			return

func _start_next_task() -> void:
	if task_queue.size() > 0:
		active_task = task_queue.pop_front()
		active_task["elapsed_time"] = 0.0
		task_started.emit(active_task)
		post_notice("▶️ 开始工作: 【%s】(预计需 %.1f 秒)..." % [active_task.get("title", "工作"), active_task.get("total_time", 1.0)], Color(0.4, 0.9, 1.0))
	task_queue_changed.emit()

func _complete_active_task() -> void:
	var completed = active_task
	var action_id = completed.get("action_id", completed.get("type", ""))
	var hex_q = int(completed.get("hex_q", 9999))
	var hex_r = int(completed.get("hex_r", 9999))
	var hex_coord = Vector2i(hex_q, hex_r)
	
	if action_id == "mine":
		var target_key = completed.get("target_key", "")
		var yield_amt = int(completed.get("yield_amount", 2))
		if target_key != "":
			inventory.add_item(target_key, yield_amt)
			var iname = DataDB.get_item(target_key).get("name", target_key)
			if target_key == "stone" and randf() < 0.25:
				inventory.add_item("flint", 1)
				post_notice("✨ 采集完成: %s x%d，并伴生收获【燧石 x1】！" % [iname, yield_amt], Color(0.2, 0.9, 0.5))
			else:
				post_notice("✨ 采集完成: %s x%d！" % [iname, yield_amt], Color(0.2, 0.9, 0.5))
				
		if hex_coord != Vector2i(9999, 9999):
			depleted_tiles[hex_coord] = 10.0 # 10秒重生时间
			tile_depleted.emit(hex_coord)
			
	elif action_id == "water":
		inventory.add_item("water", 1)
		if randf() < 0.25:
			inventory.add_item("halite", 1)
			post_notice("💧 汲水完成: 获得【水 x1】，并提纯析出【石盐 x1】！", Color(0.3, 0.85, 1.0))
		else:
			post_notice("💧 汲水完成: 获得【水 x1】！", Color(0.3, 0.85, 1.0))
			
	elif action_id == "forage":
		if randf() < 0.4:
			inventory.add_item("stick", 1)
			post_notice("🔍 搜寻有获: 发现【枯树枝 x1】！", Color.GREEN)
		elif randf() < 0.7:
			inventory.add_item("stone", 1)
			post_notice("🔍 搜寻有获: 拾得【碎石 x1】！", Color.GREEN)
		else:
			post_notice("🔍 此处地表暂无散落杂物。", Color.GRAY)
			
	elif completed.has("on_complete") and completed["on_complete"] is Callable:
		completed["on_complete"].call()
		
	task_completed.emit(completed)
	active_task = {}
	_start_next_task()
	task_queue_changed.emit()

func calculate_task_duration(item_key: String) -> float:
	var axe = equipped_tools.get("axe", "bare_hands")
	var pick = equipped_tools.get("pickaxe", "bare_hands")
	
	match item_key:
		"stick": return 0.8
		"stone": return 1.0
		"flint": return 1.2
		"water": return 1.8
		"wood":
			if axe == "flint_axe": return 2.0
			elif axe == "copper_axe": return 1.4
			elif axe == "iron_axe": return 0.8
			return 4.0
		"malachite", "iron_ore", "sulfur", "halite":
			if pick == "iron_pickaxe": return 1.2
			elif pick == "copper_pickaxe": return 2.2
			elif pick == "stone_pickaxe": return 3.6
			return 5.0
	return 2.0

func can_mine(item_key: String) -> Dictionary:
	var axe = equipped_tools.get("axe", "bare_hands")
	var pick = equipped_tools.get("pickaxe", "bare_hands")
	if item_key == "wood":
		if axe == "bare_hands":
			return {"allowed": false, "reason": "❌ 橡树坚硬，徒手无法折断！请按 [C] 制作【原始燧石斧】！"}
	elif item_key in ["malachite", "iron_ore", "sulfur", "halite"]:
		if pick == "bare_hands":
			return {"allowed": false, "reason": "❌ 矿脉坚如磐石，徒手无法挖掘！请按 [C] 制作【粗制石镐】！"}
	return {"allowed": true, "reason": ""}

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
	if inventory != null:
		inventory.items.clear()
		inventory.item_changed.emit("", 0)
	if lab_vessel != null:
		lab_vessel.clear()
		lab_vessel.temperature = 293.15
	playtime_seconds = 0.0
	era_advanced.emit(0, 0, ERA_NAMES[0])
