# data_db.gd
# 游戏基础数据库单例：负责读取与缓存物品、元素、配方表、行动、时代、制造及建筑数据
class_name DataDB
extends RefCounted

static var items: Dictionary = {}
static var elements: Dictionary = {}
static var formulas: Dictionary = {}
static var actions: Dictionary = {}
static var eras: Array = []
static var crafting: Dictionary = {}
static var buildings: Dictionary = {}
static var _is_initialized: bool = false

static func initialize() -> void:
	if _is_initialized:
		return
	_load_items("res://data/items.json")
	_load_elements("res://data/elements.json")
	_load_formulas("res://data/formula.json")
	_load_actions("res://data/actions.json")
	_load_eras("res://data/eras.json")
	_load_crafting("res://data/crafting.json")
	_load_buildings("res://data/buildings.json")
	_is_initialized = true
	print("[DataDB] 初始化完成: 已加载 %d 个物品, %d 个元素, %d 个配方, %d 个行动, %d 个时代, %d 个制造配方, %d 个建筑配方" % [
		items.size(), elements.size(), formulas.size(), actions.size(), eras.size(), crafting.size(), buildings.size()
	])

static func _load_items(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for item in parsed:
				if item.has("key"):
					items[item["key"]] = item

static func _load_elements(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for elem in parsed:
				if elem.has("number"):
					elements[int(elem["number"])] = elem

static func _load_formulas(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for formula in parsed:
				if formula.has("key"):
					formulas[formula["key"]] = formula

static func _load_actions(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for action in parsed:
				if action.has("key"):
					actions[action["key"]] = action

static func _load_eras(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			eras = parsed

static func _load_crafting(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for item in parsed:
				if item.has("key"):
					crafting[item["key"]] = item

static func _load_buildings(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for item in parsed:
				if item.has("key"):
					buildings[item["key"]] = item

static func get_item(key: String) -> Dictionary:
	var item: Dictionary = items.get(key, {}).duplicate()
	if key == "stone":
		if item.is_empty():
			item = {"key": "stone", "category": "材料", "description": "散落的碎石块，可用于筑造与制造石器。"}
		item["name"] = "碎石"
		return item
	elif key == "flint":
		if item.is_empty():
			item = {"key": "flint", "category": "矿石", "description": "坚硬锋利的燧石，断面呈贝壳状。"}
		item["name"] = "燧石"
		return item
	elif key == "stick":
		return {"key": "stick", "name": "枯树枝", "category": "材料"}
	if not item.is_empty():
		return item
	return {}

static func get_element(number: int) -> Dictionary:
	return elements.get(number, {})

static func get_formula(key: String) -> Dictionary:
	return formulas.get(key, {})

static func get_action(key: String) -> Dictionary:
	return actions.get(key, {})

static func get_crafting_recipe(key: String) -> Dictionary:
	return crafting.get(key, {})

static func get_building_recipe(key: String) -> Dictionary:
	return buildings.get(key, {})

static func get_era(order: int) -> Dictionary:
	for era in eras:
		if int(era.get("order", -1)) == order:
			return era
	return {}

static func is_pure_element(item_key: String) -> int:
	var item = get_item(item_key)
	if item.has("elemental") and item["elemental"] != null:
		return int(item["elemental"])
	return 0
