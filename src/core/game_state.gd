# game_state.gd
# 全局游戏状态管理器 (Autoload): 包含白手起家原始制造、背包、时代演进与工具阶梯
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
var unlocked_blueprints: Dictionary = {}
var equipped_tools: Dictionary = {
	"axe": "bare_hands",     # 初始徒手砍树
	"pickaxe": "bare_hands"  # 初始徒手采矿
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
