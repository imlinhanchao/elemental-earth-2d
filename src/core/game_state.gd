# game_state.gd
# 全局游戏状态管理器 (Autoload)
extends Node

const DataDB = preload("res://src/core/data_db.gd")
const PlayerInventory = preload("res://src/core/player_inventory.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")

signal element_discovered(element_number: int, item_key: String)
signal notification_posted(text: String, color: Color)

var inventory: PlayerInventory
var solver: ChemistrySolver
var discovered_elements: Array[int] = []

func _ready() -> void:
	DataDB.initialize()
	inventory = PlayerInventory.new()
	solver = ChemistrySolver.new()
	
	solver.element_discovered.connect(_on_element_discovered)
	
	# 给玩家一些初始生存工具与测试物资
	inventory.add_item("wood", 10)
	inventory.add_item("charcoal", 5)
	
	print("[GameState] 全局状态就绪")

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

func _on_element_discovered(elem_num: int, item_key: String) -> void:
	unlock_element(elem_num, item_key)

func post_notice(text: String, color: Color = Color.WHITE) -> void:
	notification_posted.emit(text, color)
