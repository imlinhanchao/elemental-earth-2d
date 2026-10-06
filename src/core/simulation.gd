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
signal tech_researched(tech_key: String)
signal milestone_completed(milestone_key: String)

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

var researched_techs: Array[String] = []
var completed_milestones: Array[String] = []

var current_era: int = 0
var playtime_seconds: float = 0.0

# 任务作业队列 (存毫秒时间戳与纯数据)
var task_queue: Array[Dictionary] = []
var active_task: Dictionary = {}
var _task_id_counter: int = 0

# 地块资源储量 (有限量，取完了就没了): Vector2i(q, r) -> Dictionary[item_key, amount]
var tile_resources: Dictionary = {}

# 地块采空状态: Vector2i(q, r) -> bool
var depleted_tiles: Dictionary = {}

# 世界地图纯数据
var hex_gen: HexWorldGenerator
var world_resources: Dictionary = {} # Vector2i(q, r) -> primary item_key
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
			names.append(str(era.get("display_name", era.get("name", ""))).split(" (")[0])
		if names.is_empty():
			names = ["石器时代", "炼金术时代", "近代化学时代"]
		return names

func _init() -> void:
	DataDB.initialize()
	inventory = PlayerInventory.new()
	solver = ChemistrySolver.new()
	lab_vessel = MixtureBuffer.new()
	lab_vessel.container_type = "flask"
	lab_vessel.temperature = 293.15
	
	solver.element_discovered.connect(_on_solver_element_discovered)
	solver.reaction_occurred.connect(_on_solver_reaction_occurred)
	inventory.item_changed.connect(_on_inventory_item_changed)
	init_world_map(12345, WORLD_HEX_RADIUS)

func init_world_map(map_seed: int = 12345, radius: int = 18) -> void:
	WORLD_HEX_RADIUS = radius
	hex_gen = HexWorldGenerator.new(map_seed)
	world_resources.clear()
	world_biomes.clear()
	tile_resources.clear()
	depleted_tiles.clear()
	
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
			_init_hex_resources(coord, biome, spawn_item)

func _init_hex_resources(coord: Vector2i, biome: HexWorldGenerator.BiomeType, spawn_item: String) -> void:
	var res: Dictionary = {}
	if spawn_item != "":
		world_resources[coord] = spawn_item
		match spawn_item:
			"wood":
				res = { "wood": 120, "stick": 30 }
			"malachite":
				res = { "malachite": 80, "stone": 40 }
			"hematite":
				res = { "hematite": 100, "stone": 40 }
			"cassiterite":
				res = { "cassiterite": 80, "stone": 30 }
			"limestone":
				res = { "limestone": 80, "stone": 30 }
			"niter":
				res = { "niter": 60, "stone": 20 }
			"sulfur":
				res = { "sulfur": 90, "flint": 25 }
			"pyrite":
				res = { "pyrite": 80, "flint": 20 }
			"rock_salt":
				res = { "rock_salt": 60, "water": 300, "sand": 40 }
			"coal":
				res = { "coal": 100, "wood": 60, "stick": 20 }
			"clay":
				res = { "clay": 80, "stone": 30 }
			"bauxite":
				res = { "bauxite": 100, "stone": 40 }
			"galena":
				res = { "galena": 100, "flint": 20 }
			"sphalerite":
				res = { "sphalerite": 100, "stone": 30 }
			"monazite":
				res = { "monazite": 80, "stone": 40 }
			"pitchblende":
				res = { "pitchblende": 80, "stone": 40 }
			"stone":
				res = { "stone": 50, "flint": 20 }
			"flint":
				res = { "flint": 30, "stone": 30 }
			"stick":
				res = { "stick": 30, "stone": 15 }
			_:
				res = { spawn_item: 80, "stone": 30 }
	else:
		match biome:
			HexWorldGenerator.BiomeType.SALT_LAKE:
				res = { "water": 300, "rock_salt": 40, "sand": 30 }
				world_resources[coord] = "water"
			HexWorldGenerator.BiomeType.VOLCANO:
				res = { "stone": 40, "flint": 20 }
				world_resources[coord] = "stone"
			HexWorldGenerator.BiomeType.DEEP_FOREST:
				res = { "wood": 80, "stick": 30 }
				world_resources[coord] = "wood"
			HexWorldGenerator.BiomeType.PLAINS:
				res = { "stone": 30, "stick": 20 }
				world_resources[coord] = "stick"
				
	tile_resources[coord] = res

func _on_solver_element_discovered(elem_num: int, item_key: String) -> void:
	unlock_element(elem_num, item_key)

func _on_solver_reaction_occurred(rx_name: String, prods: Array) -> void:
	if rx_name.contains("冶炼") or rx_name.contains("焙烧"):
		complete_milestone("first_smelt")
	for p in prods:
		if p in ["hydrogen", "oxygen", "carbon_dioxide", "carbon_monoxide", "sulfur_dioxide", "chlorine"]:
			complete_milestone("collect_gas")
		elif p == "aluminum":
			complete_milestone("produce_aluminum")
		elif p == "radium":
			complete_milestone("isolate_radium")
		elif p in ["neodymium", "lanthanum", "cerium", "praseodymium"]:
			complete_milestone("separate_rare_earth")
	if lab_vessel != null and lab_vessel.applied_voltage > 0.0:
		complete_milestone("first_electrolysis")
	if rx_name.contains("电解"):
		complete_milestone("first_electrolysis")
	# 元素嬗变：核反应、放射性衰变与粒子轰击都会使一种元素转变为另一种元素
	for w in ["嬗变", "核", "衰变", "轰击"]:
		if rx_name.contains(w):
			complete_milestone("first_transmutation")
			break

func _on_inventory_item_changed(key: String, count: int) -> void:
	if count > 0 and key != "":
		var elem_num = DataDB.is_pure_element(key)
		if elem_num > 0:
			unlock_element(elem_num, key)
		var it_data = DataDB.get_item(key)
		var m_stone = it_data.get("milestone")
		if m_stone != null and str(m_stone) != "":
			complete_milestone(str(m_stone))
		if key == "aluminum":
			complete_milestone("produce_aluminum")
		elif key == "radium":
			complete_milestone("isolate_radium")
		elif key in ["neodymium", "lanthanum", "cerium", "praseodymium"]:
			complete_milestone("separate_rare_earth")

func complete_milestone(milestone_key: String) -> void:
	if completed_milestones.has(milestone_key):
		return
	completed_milestones.append(milestone_key)
	var m_desc = milestone_key
	for era in DataDB.eras:
		for m in era.get("milestones", []):
			if m.get("key") == milestone_key:
				m_desc = m.get("description", milestone_key)
				break
	post_notice("达成里程碑：%s" % m_desc, Color(1.0, 0.85, 0.2))
	milestone_completed.emit(milestone_key)
	_check_era_advancement()

func check_milestone(milestone_key: String) -> void:
	complete_milestone(milestone_key)

func post_notice(text: String, color: Color = Color.WHITE) -> void:
	notification_posted.emit(text, color)

func unlock_element(elem_num: int, item_key: String) -> void:
	if not discovered_elements.has(elem_num):
		discovered_elements.append(elem_num)
		discovered_elements.sort()
		var elem = DataDB.get_element(elem_num)
		var sym = elem.get("symbol", "?")
		var cname = elem.get("name", item_key)
		var banner = "发现新元素：%d 号 %s（%s）" % [elem_num, cname, sym]
		post_notice(banner, Color(1.0, 0.85, 0.2))
		element_discovered.emit(elem_num, item_key)
		_check_era_advancement()

func unlock_blueprint(bp: ProcessBlueprint) -> void:
	if not unlocked_blueprints.has(bp.id):
		unlocked_blueprints[bp.id] = bp
		blueprint_unlocked.emit(bp)
		post_notice("已导出工艺蓝图：%s。可装入反应塔连续生产" % bp.display_name, Color.CYAN)
		_check_era_advancement()

func equip_tool(slot: String, tool_key: String) -> void:
	equipped_tools[slot] = tool_key
	tool_equipped.emit(tool_key)
	var t_name = DataDB.get_item(tool_key).get("name", tool_key)
	if tool_key == "flint_axe":
		t_name = "原始燧石手斧"
	elif tool_key == "stone_pickaxe":
		t_name = "粗制石镐"
	post_notice("已装备 %s" % t_name, Color.GREEN)

func _check_era_advancement() -> void:
	var era_def = DataDB.get_era(current_era)
	if era_def.is_empty():
		return
	var milestones = era_def.get("milestones", [])
	if milestones.size() > 0:
		var all_done = true
		for m in milestones:
			var m_k = str(m.get("key", ""))
			if not completed_milestones.has(m_k):
				all_done = false
				break
		if all_done:
			advance_era(current_era + 1)
			return

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
		post_notice("进入%s，领地扩展到半径 %d 格" % [ERA_NAMES[current_era], get_current_territory_radius()], Color(1.0, 0.88, 0.3))

# 背包中持有的可用器皿 (配方 required_container 中出现过的物品键)
func _get_owned_containers() -> Array:
	var result: Array = []
	for k in DataDB.get_container_keys():
		if inventory.get_count(k) > 0:
			result.append(k)
	return result

var _territory_cache_era: int = -1
var _territory_cache_radius: int = 5

func get_current_territory_radius() -> int:
	# 按时代缓存，避免每次地块判定都线性扫描 eras 表 (地形重绘时调用上万次)
	if _territory_cache_era != current_era:
		var era_def = DataDB.get_era(current_era)
		_territory_cache_radius = int(era_def["territory_radius"]) if era_def.has("territory_radius") else 5 + current_era * 3
		_territory_cache_era = current_era
	return _territory_cache_radius

func is_hex_in_territory(q: int, r: int) -> bool:
	var dist = (abs(q) + abs(q + r) + abs(r)) / 2
	return dist <= get_current_territory_radius()

func is_tile_depleted(hex: Vector2i) -> bool:
	return depleted_tiles.has(hex)

func get_hex_resource(hex: Vector2i) -> String:
	return world_resources.get(hex, "")

# --- 时间步进 (一秒时间戳钟) ---

# 实验台酒精灯：由模拟层推进温度，UI 只读显示
var lab_burner_on: bool = false
const LAB_BURNER_MAX_TEMP: float = 950.0
const LAB_HEAT_RATE: float = 160.0   # K/s
const LAB_COOL_RATE: float = 45.0    # K/s
const ROOM_TEMP: float = 293.15

var _progress_accumulator: float = 0.0

func tick(delta: float) -> void:
	playtime_seconds += delta

	# 1. 作业按到期时间精确完成 (每帧一次整数比较，开销可忽略)
	if not active_task.is_empty():
		var elapsed = (Time.get_ticks_msec() - int(active_task.get("begin_time", 0))) / 1000.0
		var time_req = float(active_task.get("time_required", 1.0))
		if elapsed >= time_req:
			_complete_active_task()
		else:
			_progress_accumulator += delta
			if _progress_accumulator >= 0.1:
				_progress_accumulator = 0.0
				task_progress_updated.emit(active_task, clampf(elapsed / time_req, 0.0, 1.0), time_req - elapsed)

	# 2. 实验台温度
	if lab_vessel:
		if lab_burner_on:
			lab_vessel.temperature = move_toward(lab_vessel.temperature, LAB_BURNER_MAX_TEMP, LAB_HEAT_RATE * delta)
		else:
			lab_vessel.temperature = move_toward(lab_vessel.temperature, ROOM_TEMP, LAB_COOL_RATE * delta)

	# 3. 化学 / 熔炉 / 反应塔结算保持 1Hz
	_second_accumulator += delta
	if _second_accumulator >= 1.0:
		_second_accumulator -= 1.0
		_on_second_tick()

func _on_second_tick() -> void:
	# 1. 实验台溶液结算 (共用一秒节拍)
	var owned_containers = _get_owned_containers()
	if lab_vessel and lab_vessel.total_moles() > 0:
		lab_vessel.available_containers = owned_containers
		solver.solve(lab_vessel, 1.0)
		
	# 2. 熔炉溶液结算 (共用一秒节拍)
	for hex in built_furnaces.keys():
		var f = built_furnaces[hex]
		var buf = f["buffer"]
		if f.get("is_active_fire", false):
			var b_timer = f.get("burn_timer", 0.0) - 1.0
			f["burn_timer"] = max(0.0, b_timer)
			buf.temperature = move_toward(buf.temperature, float(FURNACE_MAX_TEMP.get(f.get("type", "furnace"), 1100.0)), 180.0)
			if f["burn_timer"] <= 0.0:
				f["is_active_fire"] = false
		else:
			buf.temperature = move_toward(buf.temperature, 293.15, 35.0)
			
		if buf.total_moles() > 0:
			buf.available_containers = owned_containers
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
							post_notice("熔炉产出 %s ×%d，已放入行囊" % [iname, p_int], Color(0.9, 0.65, 0.2))

	# 3. 工业反应塔结算 (共用一秒节拍)
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
					post_notice("反应塔产出 %s，累计 %d 批" % [bp.display_name, r["total_produced"]], Color(0.3, 0.8, 1.0))

# --- 地块资源查询与扣减 (有限量，取完了就没了) ---

func get_tile_resources(hex: Vector2i) -> Dictionary:
	return tile_resources.get(hex, {})

func get_tile_available_resources(hex: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not tile_resources.has(hex):
		return result
	var res = tile_resources[hex]
	for k in res.keys():
		var amt = int(res[k])
		if amt > 0 and is_resource_minable(k):
			var iname = DataDB.get_item(k).get("name", k)
			result.append({
				"key": k,
				"name": iname,
				"amount": amt
			})
	return result

func consume_tile_resource(hex: Vector2i, item_key: String, count: int = 1) -> int:
	if not tile_resources.has(hex):
		return 0
	var res = tile_resources[hex]
	var cur = int(res.get(item_key, 0))
	if cur <= 0:
		return 0
	var consumed = min(cur, count)
	var remaining = cur - consumed
	if remaining <= 0:
		res.erase(item_key)
	else:
		res[item_key] = remaining
		
	# 检查该地块全部资源是否已采空
	var has_any = false
	for k in res.keys():
		if int(res[k]) > 0:
			has_any = true
			break
	if not has_any:
		depleted_tiles[hex] = true
		tile_depleted.emit(hex)
		
	return remaining

# --- 任务队列调度与合并 ---

# 作业耗时：徒手基准值，装配工具后读取 crafting.json 中的 work_time
const BARE_HAND_AXE_TIME: float = 4.0
const BARE_HAND_PICK_TIME: float = 5.0

func calculate_task_duration(item_key: String) -> float:
	if item_key == "stick":
		return 0.8
	elif item_key == "stone" or item_key == "flint" or item_key == "water":
		return 1.0
	var slot = "axe" if item_key == "wood" else "pickaxe"
	var base = BARE_HAND_AXE_TIME if slot == "axe" else BARE_HAND_PICK_TIME
	var tool_key = str(equipped_tools.get(slot, "bare_hands"))
	if tool_key == "bare_hands":
		return base
	return float(DataDB.get_crafting_recipe(tool_key).get("work_time", base))

# 各类资源在大世界显现与可开采的时代门槛配置
const RESOURCE_ERA_REQUIREMENTS: Dictionary = {
	"stone": 0,
	"flint": 0,
	"stick": 0,
	"water": 0,
	"wood": 0,
	"clay": 0,
	"malachite": 0,
	"rock_salt": 0,
	"hematite": 1,
	"cassiterite": 1,
	"limestone": 1,
	"graphite": 2,
	"niter": 2,
	"pyrolusite": 2,
	"cryolite": 3,
	"sand": 0,
	"coal": 1,
	"sulfur": 1,
	"pyrite": 1,
	"galena": 2,
	"sphalerite": 2,
	"bauxite": 3,
	"monazite": 4,
	"pitchblende": 5
}

# 获取资源所需的工具槽位类型 ("axe", "pickaxe", "bare_hands")
func get_resource_required_tool(item_key: String) -> String:
	match item_key:
		"wood":
			return "axe"
		"clay", "malachite", "hematite", "cassiterite", "limestone", "niter", "graphite", "pyrolusite", "cryolite", "coal", "sulfur", "pyrite", "galena", "sphalerite", "bauxite", "monazite", "pitchblende":
			return "pickaxe"
		_:
			return "bare_hands"

# 判定资源是否具备开采条件并在大地图显现 (兼顾时代解锁与工具完备，不满足则地图不显示)
func is_resource_minable(item_key: String) -> bool:
	if item_key == "":
		return false
	# 1. 时代门槛检测：未达到对应时代不予显现与开采
	var min_era = RESOURCE_ERA_REQUIREMENTS.get(item_key, 0)
	if current_era < min_era:
		return false
		
	# 2. 工具门槛检测：未装备所需工具不予显现与开采
	var req_tool = get_resource_required_tool(item_key)
	if req_tool == "axe":
		if equipped_tools.get("axe", "bare_hands") == "bare_hands":
			return false
	elif req_tool == "pickaxe":
		if equipped_tools.get("pickaxe", "bare_hands") == "bare_hands":
			return false
			
	return true

func can_mine(item_key: String) -> Dictionary:
	var min_era = RESOURCE_ERA_REQUIREMENTS.get(item_key, 0)
	if current_era < min_era:
		var era_def = DataDB.get_era(min_era)
		var era_name = era_def.get("name", "更高时代")
		return { "allowed": false, "reason": "文明尚未迈入【%s】，当前时代无法勘探与开采此高级资源！" % era_name }
		
	var pick = equipped_tools.get("pickaxe", "bare_hands")
	var axe = equipped_tools.get("axe", "bare_hands")
	if item_key == "wood":
		if axe == "bare_hands":
			return { "allowed": false, "reason": "徒手无法砍伐原木！请先在制作栏 (T) 制作并装配【原始燧石斧】！" }
	elif item_key in ["malachite", "hematite", "cassiterite", "limestone", "niter", "graphite", "pyrolusite", "cryolite", "sulfur", "coal", "clay", "bauxite", "galena", "sphalerite", "monazite", "pitchblende"]:
		if pick == "bare_hands":
			return { "allowed": false, "reason": "徒手无法开采坚硬矿脉与沉积层！请先在制作栏 (T) 制作并装配【粗制石镐】！" }
	return { "allowed": true, "reason": "" }

# 核心开采任务下发：支持开采次数 (5/10/20/100/1000/无尽) 与任务自动合并
func queue_hex_harvest(hex: Vector2i, item_key: String, count: int = 1, world_pos: Vector2 = Vector2.ZERO) -> bool:
	if not is_hex_in_territory(hex.x, hex.y):
		post_notice("该地块在领地外，进入下一时代后可开采", Color(1.0, 0.45, 0.3))
		return false
		
	var avail = int(tile_resources.get(hex, {}).get(item_key, 0))
	var iname = DataDB.get_item(item_key).get("name", item_key)
	if avail <= 0:
		post_notice("该地块的%s已采完" % iname, Color.ORANGE)
		return false
		
	var check = can_mine(item_key)
	if not check["allowed"]:
		post_notice(check["reason"], Color(1.0, 0.4, 0.4))
		return false
		
	var dur = calculate_task_duration(item_key)
	var action_tag = "开采"
	if item_key == "wood": action_tag = "伐木"
	elif item_key == "stick": action_tag = "拾取"
	elif item_key == "water": action_tag = "打水"
	
	var actual_count = count
	if actual_count != -1:
		actual_count = min(actual_count, avail)
		
	# === 相同的开采任务合并显示 ===
	# 1. 检查当前活跃任务
	if not active_task.is_empty():
		var a_hex = Vector2i(int(active_task.get("hex_q", 9999)), int(active_task.get("hex_r", 9999)))
		var a_key = str(active_task.get("target_key", ""))
		if a_hex == hex and a_key == item_key:
			if actual_count == -1 or int(active_task.get("repeat_count", 1)) == -1:
				active_task["repeat_count"] = -1
				active_task["title"] = "%s%s · 持续" % [action_tag, iname]
			else:
				var new_rep = int(active_task.get("repeat_count", 1)) + actual_count
				active_task["repeat_count"] = min(new_rep, avail)
				active_task["title"] = "%s%s ×%d" % [action_tag, iname, active_task["repeat_count"]]
			task_queue_changed.emit()
			post_notice("已追加到进行中的%s作业" % iname, Color.CYAN)
			return true
			
	# 2. 检查待办队列中的任务
	for i in range(task_queue.size()):
		var q_task = task_queue[i]
		var q_hex = Vector2i(int(q_task.get("hex_q", 9999)), int(q_task.get("hex_r", 9999)))
		var q_key = str(q_task.get("target_key", ""))
		if q_hex == hex and q_key == item_key:
			if actual_count == -1 or int(q_task.get("repeat_count", 1)) == -1:
				q_task["repeat_count"] = -1
				q_task["title"] = "%s%s · 持续" % [action_tag, iname]
			else:
				var new_rep = int(q_task.get("repeat_count", 1)) + actual_count
				q_task["repeat_count"] = min(new_rep, avail)
				q_task["title"] = "%s%s ×%d" % [action_tag, iname, q_task["repeat_count"]]
			task_queue_changed.emit()
			post_notice("已追加到队列中的%s作业" % iname, Color.CYAN)
			return true
			
	# 3. 新建独立作业项
	var title_str = "%s%s" % [action_tag, iname]
	if actual_count == -1:
		title_str = "%s%s · 持续" % [action_tag, iname]
	elif actual_count > 1:
		title_str = "%s%s ×%d" % [action_tag, iname, actual_count]
		
	var task: Dictionary = {
		"action_id": "harvest",
		"hex_q": hex.x,
		"hex_r": hex.y,
		"target_key": item_key,
		"yield_amount": 1,
		"repeat_count": actual_count, # 5, 10, 20, 100, 1000, 或 -1 (无尽)
		"current_cycle": 1,
		"title": title_str,
		"icon": "",
		"world_pos_x": world_pos.x,
		"world_pos_y": world_pos.y,
		"time_required": dur,
		"begin_time": 0
	}
	return add_task(task)

func queue_hex_mine(hex: Vector2i, item_key: String, count: int = 1, world_pos: Vector2 = Vector2.ZERO) -> bool:
	return queue_hex_harvest(hex, item_key, count, world_pos)

func queue_hex_water(hex: Vector2i, count: int = 1, world_pos: Vector2 = Vector2.ZERO) -> bool:
	return queue_hex_harvest(hex, "water", count, world_pos)

func queue_hex_forage(hex: Vector2i, _biome_name: String, count: int = 1, world_pos: Vector2 = Vector2.ZERO) -> bool:
	var target = "stick"
	if tile_resources.has(hex):
		var res = tile_resources[hex]
		if res.get("stick", 0) > 0:
			target = "stick"
		elif res.get("stone", 0) > 0:
			target = "stone"
		elif res.get("flint", 0) > 0:
			target = "flint"
		else:
			for k in res.keys():
				if int(res[k]) > 0:
					target = k
					break
	return queue_hex_harvest(hex, target, count, world_pos)

func add_task(task_data: Dictionary) -> bool:
	if task_queue.size() >= MAX_QUEUE_SIZE:
		post_notice("队列已满（最多 %d 项）" % MAX_QUEUE_SIZE, Color.YELLOW)
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
	var hex = Vector2i(int(finished_task.get("hex_q", 0)), int(finished_task.get("hex_r", 0)))
	var t_key = str(finished_task.get("target_key", ""))
	var amount = int(finished_task.get("yield_amount", 1))
	var rep = int(finished_task.get("repeat_count", 1))
	var cur_cycle = int(finished_task.get("current_cycle", 1))
	
	# 1. 产物收入背包及伴生物掉落
	inventory.add_item(t_key, amount)
	if t_key == "water" and randf() < 0.25:
		inventory.add_item("rock_salt", 1)
	elif t_key == "stone" and randf() < 0.15:
		inventory.add_item("flint", 1)
	elif t_key == "wood":
		if randf() < 0.50:
			inventory.add_item("bark", randi_range(1, 2))
		if randf() < 0.15:
			inventory.add_item("resin", 1)
	elif t_key == "stick":
		if randf() < 0.45:
			inventory.add_item("bark", 1)
		if randf() < 0.08:
			inventory.add_item("resin", 1)
		
	# 2. 扣减地块真实资源储量 (取完了就没了)
	var rem_res = consume_tile_resource(hex, t_key, 1)
	
	# 3. 循环判定 (无尽 -1 或 cur_cycle < rep)
	var should_continue = false
	if rep == -1:
		should_continue = (rem_res > 0)
	else:
		should_continue = (cur_cycle < rep) and (rem_res > 0)
		
	if should_continue:
		active_task["current_cycle"] = cur_cycle + 1
		active_task["begin_time"] = Time.get_ticks_msec()
		task_started.emit(active_task)
		task_queue_changed.emit()
		return # 继续下一轮循环
		
	# 4. 全部次数执行完毕或资源已采空
	if rem_res <= 0:
		var iname = DataDB.get_item(t_key).get("name", t_key)
		post_notice("该地块的%s已采完" % iname, Color.ORANGE)
		
	task_completed.emit(finished_task)
	active_task.clear()
	
	if not task_queue.is_empty():
		active_task = task_queue.pop_front()
		active_task["begin_time"] = Time.get_ticks_msec()
		task_started.emit(active_task)
		
	task_queue_changed.emit()

func has_ingredients(req_items: Array) -> bool:
	return _has_all_ingredients(req_items)

func describe_ingredients(req_items: Array) -> String:
	return _get_ingredients_desc(req_items)

func get_active_task_hex() -> Vector2i:
	if active_task.is_empty():
		return Vector2i(9999, 9999)
	return Vector2i(int(active_task.get("hex_q", 9999)), int(active_task.get("hex_r", 9999)))

# --- 打造与建造统一执行路径 (读表驱动) ---

func craft_tool(recipe_key: String) -> bool:
	var recipe = DataDB.get_crafting_recipe(recipe_key)
	if recipe.is_empty():
		post_notice("未知配方：%s" % recipe_key, Color.RED)
		return false
		
	var req_items = recipe.get("required_items", [])
	if not _has_all_ingredients(req_items):
		post_notice("材料不足，无法制作%s" % recipe.get("name", recipe_key), Color.RED)
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
		
	var m_stone = recipe.get("milestone")
	if m_stone != null and str(m_stone) != "":
		complete_milestone(str(m_stone))
	elif recipe_key == "craft_stone_pickaxe" or recipe_key == "stone_pickaxe":
		complete_milestone("craft_stone_pickaxe")
	elif recipe_key == "craft_fire_seed" or recipe_key == "fire_seed":
		complete_milestone("craft_fire_seed")
	elif recipe_key == "craft_crucible" or recipe_key == "crucible":
		complete_milestone("craft_crucible")
	elif recipe_key == "craft_gas_bottle" or recipe_key == "gas_bottle":
		complete_milestone("craft_gas_bottle")
	elif recipe_key == "craft_battery" or recipe_key == "battery":
		complete_milestone("craft_battery")
		
	var notice_text = recipe.get("notice", "制作成功: %s" % recipe.get("name", recipe_key))
	post_notice(notice_text, Color.GREEN)
	return true

# 已实现运行逻辑的建筑；数据表中其余建筑在实现前不可建造 (避免只扣料不生成)
const FURNACE_TYPES: Array[String] = ["fire_pit", "furnace", "blast_furnace"]
const IMPLEMENTED_STRUCTURES: Array[String] = ["fire_pit", "furnace", "blast_furnace", "industrial_reactor"]
# 各类炉体的最高炉温 (K)
const FURNACE_MAX_TEMP: Dictionary = {"fire_pit": 1100.0, "furnace": 1100.0, "blast_furnace": 1500.0}

func build_structure(structure_key: String, hex: Vector2i) -> bool:
	if not is_hex_in_territory(hex.x, hex.y):
		post_notice("无法建造：在领地外", Color(1.0, 0.4, 0.4))
		return false
		
	if built_furnaces.has(hex) or built_reactors.has(hex):
		post_notice("无法建造：地块已被占用", Color(1.0, 0.4, 0.4))
		return false
		
	var recipe = DataDB.get_building_recipe(structure_key)
	if recipe.is_empty() or not IMPLEMENTED_STRUCTURES.has(structure_key):
		post_notice("该建筑尚未开放：%s" % recipe.get("name", structure_key), Color.RED)
		return false
		
	var req_items = recipe.get("required_items", [])
	if not _has_all_ingredients(req_items):
		post_notice("材料不足，需要 %s" % _get_ingredients_desc(req_items), Color.RED)
		return false
		
	_consume_all_ingredients(req_items)
	depleted_tiles[hex] = true
	
	if FURNACE_TYPES.has(structure_key):
		var f_buf = MixtureBuffer.new()
		f_buf.container_type = structure_key
		f_buf.temperature = 373.15 if structure_key == "fire_pit" else 293.15
		built_furnaces[hex] = {
			"type": structure_key,
			"buffer": f_buf,
			"burn_timer": 30.0 if structure_key == "fire_pit" else 0.0,
			"is_active_fire": (structure_key == "fire_pit")
		}
	elif structure_key == "industrial_reactor":
		built_reactors[hex] = {
			"blueprint_id": "",
			"cycle_progress": 0.0,
			"total_produced": 0
		}
		
	var m_stone = recipe.get("milestone")
	if m_stone != null and str(m_stone) != "":
		complete_milestone(str(m_stone))
	elif structure_key == "furnace":
		complete_milestone("build_kiln")
		
	var notice_text = recipe.get("notice", "建造成功: %s" % recipe.get("name", structure_key))
	post_notice(notice_text, Color(0.3, 0.9, 0.5))
	structure_built.emit(structure_key, hex)
	return true

# --- 科技研发系统 ---

func can_research_tech(tech_key: String) -> bool:
	if researched_techs.has(tech_key):
		return false
	var tech = DataDB.get_tech(tech_key)
	if tech.is_empty():
		return false
	var req_era = int(tech.get("era", 0))
	if current_era < req_era:
		return false
	var prereqs = tech.get("required_techs", tech.get("prerequisites", []))
	for p in prereqs:
		if not researched_techs.has(str(p)):
			return false
	var req_items = tech.get("required_items", [])
	if not _has_all_ingredients(req_items):
		return false
	return true

func research_tech(tech_key: String) -> bool:
	if researched_techs.has(tech_key):
		post_notice("%s已研发" % DataDB.get_tech(tech_key).get("name", tech_key), Color.YELLOW)
		return false
	var tech = DataDB.get_tech(tech_key)
	if tech.is_empty():
		post_notice("未知科技：%s" % tech_key, Color.RED)
		return false
	if not can_research_tech(tech_key):
		post_notice("无法研发%s：缺少前置科技或材料" % tech.get("name", tech_key), Color.RED)
		return false
		
	var req_items = tech.get("required_items", [])
	_consume_all_ingredients(req_items)
	
	researched_techs.append(tech_key)
	tech_researched.emit(tech_key)
	
	var m_stone = tech.get("milestone")
	if m_stone != null and str(m_stone) != "":
		complete_milestone(str(m_stone))
	elif tech_key == "pottery":
		complete_milestone("research_pottery")
	elif tech_key == "gas_collection" or tech_key == "gas_collecting":
		complete_milestone("research_gas_collection")
	elif tech_key == "crystallization" or tech_key == "crystallization_tech":
		complete_milestone("crystallization_tech")
	elif tech_key == "advanced_chemical_equipment":
		complete_milestone("unlock_advanced_chem_tools")
		
	post_notice("研发完成：%s" % tech.get("name", tech_key), Color(0.3, 0.9, 0.5))
	_check_era_advancement()
	return true

func furnace_add_fuel(hex: Vector2i) -> bool:
	if not built_furnaces.has(hex):
		return false
	var f = built_furnaces[hex]
	var burned_wood = false
	if not inventory.remove_item("charcoal", 1):
		if not (inventory.remove_item("wood", 2) or inventory.remove_item("stick", 3)):
			post_notice("行囊里没有木炭、原木或树枝", Color.RED)
			return false
		burned_wood = true
	if burned_wood:
		inventory.add_item("wood_ash", 1) # 木柴燃尽留下草木灰
	f["is_active_fire"] = true
	f["burn_timer"] = f.get("burn_timer", 0.0) + 18.0
	f["buffer"].add_substance("charcoal", 1.0)
	post_notice("已添加燃料", Color.ORANGE)
	return true

func furnace_add_ore(hex: Vector2i, key: String, amount: int = 1) -> bool:
	if not built_furnaces.has(hex):
		return false
	var f = built_furnaces[hex]
	if inventory.remove_item(key, amount):
		f["buffer"].add_substance(key, float(amount))
		var iname = DataDB.get_item(key).get("name", key)
		post_notice("已投入 %s ×%d" % [iname, amount], Color.CYAN)
		return true
	else:
		post_notice("行囊里的原料不足", Color.RED)
		return false

func reactor_install_blueprint(hex: Vector2i, bp_id: String) -> bool:
	if not built_reactors.has(hex):
		return false
	if not unlocked_blueprints.has(bp_id):
		return false
	built_reactors[hex]["blueprint_id"] = bp_id
	built_reactors[hex]["cycle_progress"] = 0.0
	post_notice("反应塔已装入蓝图：%s" % unlocked_blueprints[bp_id].display_name, Color.CYAN)
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
			var names: Array[String] = []
			for alt in k:
				names.append(str(DataDB.get_item(alt).get("name", alt)))
			desc_parts.append("%s ×%d" % ["或".join(names), q])
		else:
			desc_parts.append("%s ×%d" % [DataDB.get_item(k).get("name", k), q])
	return "、".join(desc_parts)

# 距 from_hex 最近、位于领地内、仍有储量且当前可开采的 item_key 地块；没有时返回 Vector2i(9999, 9999)。
# 优先选择地表显示的就是 item_key、且左键点击就会采到它的地块，找不到再退回任意有储量的地块。
func find_nearest_resource(item_key: String, from_hex: Vector2i) -> Vector2i:
	var none := Vector2i(9999, 9999)
	if not is_resource_minable(item_key):
		return none
	var best_primary := none
	var best_any := none
	var d_primary := 1 << 30
	var d_any := 1 << 30
	for hex in tile_resources.keys():
		if int(tile_resources[hex].get(item_key, 0)) <= 0:
			continue
		if not is_hex_in_territory(hex.x, hex.y) or built_furnaces.has(hex) or built_reactors.has(hex):
			continue
		var dq = hex.x - from_hex.x
		var dr = hex.y - from_hex.y
		var d = (abs(dq) + abs(dq + dr) + abs(dr)) / 2
		if d < d_any:
			d_any = d
			best_any = hex
		if d < d_primary:
			var avail = get_tile_available_resources(hex)
			if world_resources.get(hex, "") == item_key and not avail.is_empty() and avail[0].get("key", "") == item_key:
				d_primary = d
				best_primary = hex
	return best_primary if best_primary != none else best_any

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
	researched_techs.clear()
	completed_milestones.clear()
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
		lab_vessel.temperature = ROOM_TEMP
	lab_burner_on = false
	playtime_seconds = 0.0
	init_world_map(12345, WORLD_HEX_RADIUS)
	era_advanced.emit(0, 0, ERA_NAMES[0])
