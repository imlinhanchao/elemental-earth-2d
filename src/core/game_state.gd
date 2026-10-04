# game_state.gd
# 全局游戏状态管理器 (Autoload): 包含白手起家原始制造、背包、时代演进与工具阶梯
extends Node

const DataDB = preload("res://src/core/data_db.gd")
const PlayerInventory = preload("res://src/core/player_inventory.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")
const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")

signal element_discovered(element_number: int, item_key: String)
signal notification_posted(text: String, color: Color)
signal era_advanced(old_era: int, new_era: int, era_name: String)
signal blueprint_unlocked(blueprint: ProcessBlueprint)
signal tool_equipped(tool_key: String)

# 任务作业队列信号
signal task_queue_changed
signal task_started(task: Dictionary)
signal task_progress_updated(task: Dictionary, percent: float, remaining_time: float)
signal task_completed(task: Dictionary)
signal task_cancelled(task: Dictionary)

var inventory: PlayerInventory
var solver: ChemistrySolver
var discovered_elements: Array[int] = []
var unlocked_blueprints: Dictionary = {}
var equipped_tools: Dictionary = {
	"axe": "bare_hands",     # 初始徒手砍树
	"pickaxe": "bare_hands"  # 初始徒手采矿
}

# 任务工作队列状态
var task_queue: Array[Dictionary] = []
var active_task: Dictionary = {}
var _task_id_counter: int = 0
const MAX_QUEUE_SIZE: int = 8

var current_era: int = 0
var playtime_seconds: float = 0.0
const ERA_NAMES = [
	"石器时代 (Stone Age)",
	"炼金术时代 (Alchemy Age)",
	"近代化学时代 (Modern Chemistry)",
	"电化学时代 (Electrochemistry)",
	"催化与稀土时代 (Catalysis & Rare Earth)",
	"原子能时代 (Atomic Age)"
]

func _ready() -> void:
	DataDB.initialize()
	inventory = PlayerInventory.new()
	solver = ChemistrySolver.new()
	
	solver.element_discovered.connect(_on_element_discovered)
	
	# 【一穷二白开局】: 背包初始彻底为空，玩家必须拾取地表散落碎石与断枝起家！
	# 不赠送任何加工物资
	
	print("[GameState] 一穷二白开局就绪，当前时代: %s" % ERA_NAMES[current_era])

func unlock_element(elem_num: int, item_key: String) -> void:
	if not discovered_elements.has(elem_num):
		discovered_elements.append(elem_num)
		discovered_elements.sort()
		var elem = DataDB.get_element(elem_num)
		var sym = elem.get("symbol", "?")
		var cname = elem.get("name", item_key)
		var banner = "🌟 【重大发现】你首次提纯并点亮了第 %d 号化学元素：%s (%s)！" % [elem_num, cname, sym]
		notification_posted.emit(banner, Color(1.0, 0.85, 0.2))
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
	# 时代 0 -> 时代 1 (石器 -> 炼金术时代): 成功冶炼提纯单质铜 (#29)
	if current_era == 0:
		if discovered_elements.has(29):
			advance_era(1)
	# 时代 1 -> 时代 2 (炼金术 -> 近代化学): 成功冶炼单质铁 (#26) 且导出至少 2 种蓝图
	elif current_era == 1:
		if discovered_elements.has(26) and unlocked_blueprints.size() >= 2:
			advance_era(2)
	# 时代 2 -> 时代 3: 点亮氢 (#1) 与氧 (#8)
	elif current_era == 2:
		if discovered_elements.has(8) and discovered_elements.has(1):
			advance_era(3)

func advance_era(next_era: int) -> void:
	if next_era > current_era and next_era < ERA_NAMES.size():
		var old = current_era
		current_era = next_era
		era_advanced.emit(old, current_era, ERA_NAMES[current_era])
		post_notice("🎊 【文明跃迁】时代跨越达成！人类正式步入：%s！" % ERA_NAMES[current_era], Color(1.0, 0.3, 0.5))

func _on_element_discovered(elem_num: int, item_key: String) -> void:
	unlock_element(elem_num, item_key)

func post_notice(text: String, color: Color = Color.WHITE) -> void:
	notification_posted.emit(text, color)

func get_current_territory_radius() -> int:
	match current_era:
		0: return 5   # 石器时代: 基础 5 格半径
		1: return 8   # 炼金时代: 扩展至 8 格
		2: return 11  # 近代化学: 扩展至 11 格
		3: return 14  # 电化学: 扩展至 14 格
		4: return 17  # 稀土时代: 扩展至 17 格
		5: return 20  # 原子能时代: 覆盖全图
		_: return 5 + current_era * 3

func is_hex_in_territory(q: int, r: int) -> bool:
	var dist = (abs(q) + abs(q + r) + abs(r)) / 2
	return dist <= get_current_territory_radius()

func is_pos_in_territory(pos: Vector2) -> bool:
	var h = HexWorldGenerator.pixel_to_hex(pos)
	return is_hex_in_territory(h.x, h.y)

func _process(delta: float) -> void:
	playtime_seconds += delta
	if not active_task.is_empty():
		active_task["elapsed_time"] = active_task.get("elapsed_time", 0.0) + delta
		var total: float = active_task.get("total_time", 1.0)
		var elapsed: float = active_task.get("elapsed_time", 0.0)
		var pct: float = clamp(elapsed / total, 0.0, 1.0)
		var rem: float = max(0.0, total - elapsed)
		task_progress_updated.emit(active_task, pct, rem)
		if elapsed >= total:
			_complete_active_task()

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
	if inventory != null:
		inventory.items.clear()
		inventory.item_changed.emit("", 0)
	playtime_seconds = 0.0
	era_advanced.emit(0, 0, ERA_NAMES[0])

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
	
	# 如果绑定了实体节点采收 (如矿脉、树木、石块)
	var node = completed.get("target_node")
	if node != null and is_instance_valid(node) and node.has_method("harvest_complete"):
		node.harvest_complete()
	elif completed.get("type") == "water":
		# 盐湖/水域汲水
		inventory.add_item("water", 1)
		if randf() < 0.25:
			inventory.add_item("halite", 1)
			post_notice("💧 汲水完成: 获得【水 x1】，并提纯析出【石盐 x1】！", Color(0.3, 0.85, 1.0))
		else:
			post_notice("💧 汲水完成: 获得【水 x1】！", Color(0.3, 0.85, 1.0))
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
		"stick":
			return 0.8
		"stone":
			return 1.0
		"flint":
			return 1.2
		"water":
			return 1.8
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
