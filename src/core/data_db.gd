# data_db.gd
# 游戏基础数据库单例：负责读取与缓存物品、元素、时代数据
class_name DataDB
extends RefCounted

static var items: Dictionary = {}
static var elements: Dictionary = {}
static var formulas: Dictionary = {}
static var eras: Array = []
static var _is_initialized: bool = false

static func initialize() -> void:
	if _is_initialized:
		return
	_load_items("res://data/items.json")
	_load_elements("res://data/elements.json")
	_load_formulas("res://data/formula.json")
	_load_eras("res://data/eras.json")
	_is_initialized = true
	print("[DataDB] 初始化完成: 已加载 %d 个物品, %d 个元素, %d 个基础配方" % [items.size(), elements.size(), formulas.size()])

static func _load_items(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for item in parsed:
				if item.has("key"):
					items[item["key"]] = item

static func _load_elements(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for elem in parsed:
				if elem.has("number"):
					elements[int(elem["number"])] = elem

static func _load_formulas(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for formula in parsed:
				if formula.has("key"):
					formulas[formula["key"]] = formula

static func _load_eras(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			eras = parsed

static func get_item(key: String) -> Dictionary:
	if items.has(key):
		return items[key]
	if key == "flint":
		return {"key": "flint", "name": "碎石/燧石", "category": "材料"}
	elif key == "stick":
		return {"key": "stick", "name": "枯树枝", "category": "材料"}
	return {}

static func get_element(number: int) -> Dictionary:
	return elements.get(number, {})

static func is_pure_element(item_key: String) -> int:
	var item = get_item(item_key)
	if item.has("elemental") and item["elemental"] != null:
		return int(item["elemental"])
	return 0
