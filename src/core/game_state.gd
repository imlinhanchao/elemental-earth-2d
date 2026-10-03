# game_state.gd
# 全局游戏状态管理器 (Autoload): 包含背包、时代演进、图鉴、蓝图库与工具装配
extends Node

const DataDB = preload("res://src/core/data_db.gd")
const PlayerInventory = preload("res://src/core/player_inventory.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")

signal element_discovered(element_number: int, item_key: String)
signal notification_posted(text: String, color: Color)
signal era_advanced(old_era: int, new_era: int, era_name: String)
signal blueprint_unlocked(blueprint: ProcessBlueprint)
signal tool_equipped(tool_key: String)

var inventory: PlayerInventory
var solver: ChemistrySolver
var discovered_elements: Array[int] = []
var unlocked_blueprints: Dictionary = {} # id -> ProcessBlueprint
var equipped_tools: Dictionary = {
	"pickaxe": "stone_pickaxe" # 初始石镐
}

var current_era: int = 0
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
	
	# 初始物资
	inventory.add_item("wood", 16)
	inventory.add_item("charcoal", 8)
	
	# 预置初始已知简单蓝图 (木炭烧结)
	var bp_charcoal = ProcessBlueprint.new("bp_charcoal", "密闭干馏木材制木炭", {"wood": 2.0}, {"charcoal": 1.5}, 550.0)
	unlock_blueprint(bp_charcoal)

	print("[GameState] 全局状态与时代系统就绪，当前时代: %s" % ERA_NAMES[current_era])

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
		
		# 检查时代推进里程碑
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
	post_notice("⚒️ 成功装备工具: %s！开采效率大幅跃升！" % t_name, Color.GREEN)

func _check_era_advancement() -> void:
	# 时代 0 -> 时代 1 (石器 -> 炼金术时代): 点亮单质铜 (#29) 且点亮单质碳 (#6)
	if current_era == 0:
		if discovered_elements.has(29): # 炼出金属铜
			advance_era(1)
	# 时代 1 -> 时代 2 (炼金术 -> 近代化学): 点亮单质铁 (#26) 且导出至少 2 种工业蓝图
	elif current_era == 1:
		if discovered_elements.has(26) and unlocked_blueprints.size() >= 2:
			advance_era(2)
	# 时代 2 -> 时代 3 (近代化学 -> 电化学时代): 成功电解水获得纯氧 (#8) 与氢气 (#1)
	elif current_era == 2:
		if discovered_elements.has(8) and discovered_elements.has(1):
			advance_era(3)

func advance_era(next_era: int) -> void:
	if next_era > current_era and next_era < ERA_NAMES.size():
		var old = current_era
		current_era = next_era
		era_advanced.emit(old, current_era, ERA_NAMES[current_era])
		post_notice("🎊 【文明跃迁】时代跨越达成！全人类步入：%s！" % ERA_NAMES[current_era], Color(1.0, 0.3, 0.5))

func _on_element_discovered(elem_num: int, item_key: String) -> void:
	unlock_element(elem_num, item_key)

func post_notice(text: String, color: Color = Color.WHITE) -> void:
	notification_posted.emit(text, color)
