# data_db.gd
# 游戏基础数据库单例：负责读取与缓存物品、元素、配方表、行动、时代、制造、建筑、科技与实验操作数据
class_name DataDB
extends RefCounted

static var items: Dictionary = {}
static var elements: Dictionary = {}
static var formulas: Dictionary = {}
static var actions: Dictionary = {}
static var eras: Array = []
static var crafting: Dictionary = {}
static var buildings: Dictionary = {}
static var techs: Dictionary = {}
static var techs_list: Array = []
static var labs: Dictionary = {}
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
	_load_techs("res://data/techs.json")
	_load_labs("res://data/labs.json")
	_is_initialized = true
	print("[DataDB] 初始化完成: 已加载 %d 个物品, %d 个元素, %d 个配方, %d 个行动, %d 个时代, %d 个制造配方, %d 个建筑配方, %d 项科技, %d 项实验操作" % [
		items.size(), elements.size(), formulas.size(), actions.size(), eras.size(), crafting.size(), buildings.size(), techs.size(), labs.size()
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

static func _load_techs(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			techs_list = parsed
			for item in parsed:
				if item.has("key"):
					techs[item["key"]] = item

static func _load_labs(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for item in parsed:
				if item.has("key"):
					labs[item["key"]] = item

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
		return {"key": "stick", "name": "枯树枝", "category": "材料", "description": "随处可拾取的断枝。"}
	if not item.is_empty():
		return item
	return {"key": key, "name": key, "category": "物品", "description": "未知化学样本。"}

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

static func get_tech(key: String) -> Dictionary:
	return techs.get(key, {})

static func get_all_techs() -> Array:
	return techs_list

static func get_tech_era(tech_key: String) -> int:
	var t = get_tech(tech_key)
	if t.is_empty():
		return 0
	var req_techs = t.get("required_techs", [])
	if req_techs.is_empty():
		if tech_key in ["stone_tool_crafting", "wood_processing", "fire_starting"]:
			return 0
		elif tech_key in ["pottery", "bark_processing"]:
			return 1
		return 0
	var first_req = req_techs[0]
	if first_req in ["stone_tool_crafting", "stone_masonry"]:
		return 0
	elif first_req in ["pottery", "mold_making", "refractory_materials", "high_temp_furnace", "bronze_tool_crafting", "brass_tool_crafting"]:
		return 1
	elif first_req in ["iron_tool_crafting", "gas_collection", "sifting_technology", "explosives", "crystallization_tech"]:
		return 2
	elif first_req in ["electrochemistry", "manganese_alloy_smithing", "titanium_alloy_smithing", "chrome_alloy_smithing", "lithium_battery_tech", "glassworking", "production_tech", "nickel_cadmium_battery_tech"]:
		return 3
	elif first_req in ["high_pressure_tech", "advanced_chemical_equipment", "precision_machinery", "magnesium_aluminum_alloying", "gas_liquefaction"]:
		return 4
	elif first_req in ["nuclear_physics", "nuclear_reactor_tech", "particle_accelerator_tech", "jet_propulsion_tech", "solar_cell_manufacturing"]:
		return 5
	return 2

static func get_techs_for_era(era_order: int) -> Array:
	var result = []
	for t in techs_list:
		if get_tech_era(t["key"]) == era_order:
			result.append(t)
	return result

static func get_crafting_recipes_for_era(era_order: int) -> Array:
	var result = []
	for c in crafting.values():
		if int(c.get("era", 0)) == era_order:
			result.append(c)
	return result

static func get_buildings_for_era(era_order: int) -> Array:
	var result = []
	for b in buildings.values():
		if int(b.get("era", 0)) == era_order:
			result.append(b)
	return result

static func get_lab_op(key: String) -> Dictionary:
	return labs.get(key, {})

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

# 方案 2: 获取物品化学特性标签 (用于背包悬浮提示与反应启发)
static func get_item_chemical_tags(item_key: String) -> Array[Dictionary]:
	var tags: Array[Dictionary] = []
	var item = get_item(item_key)
	if item.is_empty():
		return tags
		
	var cat = str(item.get("category", ""))
	var type_arr = item.get("type", [])
	var attrs = item.get("attrs", {})
	var elem_num = int(item.get("elemental", 0))
	
	# 1. 还原剂与燃料类
	if item_key in ["charcoal", "coal", "coke", "carbon_monoxide"]:
		tags.append({"text": "🔥 高温还原剂", "color": Color(0.98, 0.55, 0.18)})
		tags.append({"text": "🪵 固体燃料", "color": Color(0.85, 0.70, 0.25)})
	elif item_key in ["wood", "stick", "bark", "branch"]:
		tags.append({"text": "🌿 可干馏热解", "color": Color(0.40, 0.85, 0.35)})
		tags.append({"text": "🪵 燃烧供热", "color": Color(0.85, 0.70, 0.25)})
		
	# 2. 矿石与可冶炼物类
	if item_key == "malachite":
		tags.append({"text": "⛏️ 易还原铜矿", "color": Color(0.18, 0.85, 0.65)})
		tags.append({"text": "♨️ 受热热解", "color": Color(0.95, 0.35, 0.25)})
	elif item_key in ["iron_ore", "hematite", "magnetite"]:
		tags.append({"text": "⛏️ 氧化铁矿", "color": Color(0.85, 0.40, 0.30)})
		tags.append({"text": "⚙️ 冶炼原料", "color": Color(0.75, 0.60, 0.90)})
	elif item_key in ["pyrite", "chalcopyrite", "sphalerite", "galena"]:
		tags.append({"text": "⛏️ 硫化物矿", "color": Color(0.90, 0.75, 0.20)})
		tags.append({"text": "🔥 焙烧脱硫", "color": Color(0.95, 0.45, 0.20)})
	elif item_key in ["bauxite"]:
		tags.append({"text": "⛏️ 铝土矿", "color": Color(0.85, 0.60, 0.40)})
		tags.append({"text": "⚡ 需高温电解", "color": Color(0.20, 0.75, 0.95)})
		
	# 3. 盐类与溶剂
	if item_key in ["halite", "rock_salt", "salt"]:
		tags.append({"text": "🧂 水溶性盐", "color": Color(0.45, 0.80, 0.95)})
		tags.append({"text": "💧 电解氯碱源", "color": Color(0.25, 0.65, 0.95)})
	elif item_key in ["water", "salt_water", "seawater"]:
		tags.append({"text": "💧 通用溶剂", "color": Color(0.30, 0.75, 1.00)})
		
	# 4. 陶土与耐火胶结
	if item_key in ["clay", "kaolin"]:
		tags.append({"text": "🏺 陶质烧结", "color": Color(0.85, 0.55, 0.35)})
		tags.append({"text": "🧱 耐火成型", "color": Color(0.70, 0.50, 0.40)})
	elif item_key in ["limestone", "calcium_carbonate"]:
		tags.append({"text": "♨️ 高温煅烧分解", "color": Color(0.95, 0.40, 0.30)})
		tags.append({"text": "🧱 冶炼造渣剂", "color": Color(0.75, 0.75, 0.75)})
	elif item_key in ["quicklime", "calcium_oxide"]:
		tags.append({"text": "♨️ 遇水剧烈放热", "color": Color(0.98, 0.35, 0.15)})
		tags.append({"text": "⚗️ 强碱脱水", "color": Color(0.65, 0.50, 0.90)})
		
	# 5. 硅石与生火材料
	if item_key == "flint":
		tags.append({"text": "⚡ 击石生火", "color": Color(0.95, 0.80, 0.25)})
		tags.append({"text": "💎 致密硬脆", "color": Color(0.60, 0.75, 0.85)})
	elif item_key in ["stone", "cut_stone"]:
		tags.append({"text": "🧱 坚固基材", "color": Color(0.65, 0.68, 0.72)})
		
	# 6. 金属单质
	if item_key in ["copper", "iron", "lead", "tin", "gold", "silver", "zinc", "bronze", "brass"]:
		tags.append({"text": "⚙️ 金属单质/合金", "color": Color(0.90, 0.75, 0.30)})
		tags.append({"text": "⚡ 优良导体", "color": Color(0.25, 0.80, 0.95)})
		
	# 7. 硫与酸
	if item_key in ["sulfur"]:
		tags.append({"text": "🧪 易挥发单质", "color": Color(0.95, 0.85, 0.15)})
		tags.append({"text": "⚗️ 制酸与火药原料", "color": Color(0.95, 0.45, 0.25)})
		
	# 兜底推导通用标签 (若上述特定物品未命中)
	if tags.is_empty():
		if elem_num > 0:
			tags.append({"text": "🔬 纯化学元素", "color": Color(0.25, 0.85, 0.95)})
		if attrs.has("burn_time") or ("fuel" in type_arr):
			tags.append({"text": "🪵 燃烧供热", "color": Color(0.85, 0.70, 0.25)})
		if cat == "矿石":
			tags.append({"text": "⛏️ 原生矿石", "color": Color(0.65, 0.75, 0.55)})
		elif cat == "材料":
			tags.append({"text": "📦 基础材料", "color": Color(0.60, 0.70, 0.80)})
			
	return tags
