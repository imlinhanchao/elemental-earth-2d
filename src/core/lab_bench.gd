# lab_bench.gd
# 实验台模拟层：选择操作、点火与燃料、电源、手稿与已确证工艺。
# 纯数据，由 Simulation 持有并每帧推进；界面 (lab_workbench_modal.gd) 只发命令、读状态。
#
# 玩法要点：
# - 配方必须用对操作才会反应 (labs.json，如焙烧、干馏、搅拌、电解)；
# - 加热类操作要先投燃料再点火，燃料按燃烧时长消耗，燃料种类决定最高温度；
# - 电解类操作要接入电池，电池电压决定能做哪些电解，电量用完即报废；
# - 手稿 (配方线索) 从采集、研发、首次获得物品中获得；只有持有手稿的配方，侦测卡才会指出缺什么；
# - 第一次做成某个配方即「确证」，记入手稿并生成工艺蓝图；
# - 实验没反应不损失原料：「全部取回」把烧瓶内容退回行囊，只有燃料和电量会消耗；
# - 做实验必须先放一件制造出的容器 (木桶、陶罐、坩埚、烧杯…)，配方的 required_container 决定能用哪些；
#   加热类操作要求容器耐热 (attrs.can_heat)，每完成一次反应消耗容器 1 点耐久，耐久用完容器损坏。
extends RefCounted

const DataDB = preload("res://src/core/data_db.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")

const ROOM_TEMP := 293.15
const HEAT_RATE := 120.0      # K/s
const COOL_RATE := 45.0       # K/s
const BELLOWS_BONUS := 200.0  # 持有风箱时火焰温度提高 (K)
const FRAGMENT_HARVEST_CHANCE := 0.08   # 每次采集完成掉落手稿的概率
const FRAGMENT_NEW_ITEM_CHANCE := 0.25  # 第一次获得某物品时，得到以它为主料的手稿的概率
const STARTER_FRAGMENTS := ["charcoal_production"]
# 枯树枝没有登记在 items.json 中，单独给出燃料参数
const STICK_FUEL := {"burn_time": 10.0, "max_temp": 873.0}

enum Group { NORMAL, FIRE, POWER }

signal reacted(formula_key: String, products: Array, lost: Array)

var sim # Simulation (不写类型，避免循环引用)
var vessel: MixtureBuffer

var operation: String = ""
var container: String = ""      # 当前放在台上的容器 (行囊中的物品 key)
var chain_ops: Array = []       # 已勾选的追加操作 (集气、冷凝)
var fire_lit: bool = false
var fuel_queue: Array = []      # 已投入、尚未开始燃烧的燃料
var cur_fuel: String = ""       # 正在燃烧的燃料
var cur_fuel_left: float = 0.0  # 当前这份燃料剩余秒数
var power_key: String = ""
var power_left: float = 0.0

var fragments: Array = []       # 持有手稿的配方 key (按获得顺序)
var proven: Dictionary = {}     # 已确证配方 key -> true
var seen_items: Dictionary = {} # 曾经获得过的物品 key -> true (手稿中未见过的物品显示为 ???)
var produced: Dictionary = {}   # 本次实验生成的物品，取回时按四舍五入计数

func _init(p_sim, p_vessel: MixtureBuffer) -> void:
	sim = p_sim
	vessel = p_vessel
	reset()

func reset() -> void:
	operation = ""
	container = ""
	vessel.container_type = ""
	chain_ops.clear()
	fire_lit = false
	fuel_queue.clear()
	cur_fuel = ""
	cur_fuel_left = 0.0
	power_key = ""
	power_left = 0.0
	fragments = STARTER_FRAGMENTS.duplicate()
	proven.clear()
	seen_items.clear()
	produced.clear()
	vessel.operations = []
	vessel.chain_ops = []
	vessel.applied_voltage = 0.0

# ---------------------------------------------------------------- 操作

static func op_group(op: Dictionary) -> int:
	if op.get("requires_electricity", false):
		return Group.POWER
	if op.get("requires_burning", false):
		return Group.FIRE
	return Group.NORMAL

# 实验台上列出的操作：至少有一个配方用到、且不是附加操作 (集气等)，按 常温 / 点火 / 通电 排序
static func listed_operations() -> Array:
	var used := {}
	for f in DataDB.formulas.values():
		used[ChemistrySolver.formula_operation(f)] = true
	var ops: Array = []
	for op in DataDB.labs.values():
		if used.has(op["key"]) and not op.get("is_chain", false) and not ChemistrySolver.CHAIN_OPS.has(op["key"]):
			ops.append(op)
	# 按组稳定排序 (数据表内顺序保持不变)
	var sorted: Array = []
	for g in [Group.NORMAL, Group.FIRE, Group.POWER]:
		for op in ops:
			if op_group(op) == g:
				sorted.append(op)
	return sorted

# 追加操作 (可与主操作同时进行)：集气、冷凝
static func listed_chain_operations() -> Array:
	var ops: Array = []
	for k in ChemistrySolver.CHAIN_OPS:
		var op = DataDB.get_lab_op(k)
		if not op.is_empty():
			ops.append(op)
	return ops

static func unlock_era(key: String) -> int:
	return int(DataDB.get_lab_op(key).get("unlock_era", 0))

# 炉体内能完成的操作：加热类 (鼓风高炉另可吹炼)
static func furnace_operations(furnace_type: String) -> Array:
	var ops: Array = []
	for op in DataDB.labs.values():
		if op_group(op) != Group.FIRE:
			continue
		if op["key"] == "blowing" and furnace_type != "blast_furnace":
			continue
		ops.append(op["key"])
	return ops

# 操作锁定原因，可用时返回 ""。器皿 (陶罐、坩埚等) 由配方的 required_container 判断，这里只检查科技与工具
func op_lock_reason(key: String) -> String:
	var op = DataDB.get_lab_op(key)
	if op.is_empty():
		return "未知操作"
	var era = unlock_era(key)
	if era > sim.current_era:
		var names = sim.ERA_NAMES
		return "%s解锁" % (names[era] if era < names.size() else "后续时代")
	for t in op.get("required_techs", []):
		if not sim.researched_techs.has(t):
			return "需要研发%s" % DataDB.get_tech(t).get("name", t)
	# 可加热的器皿 (陶罐、坩埚、烧杯等) 由配方的 required_container 判断；其余是必须持有的工具 (筛子、风箱、冷凝管…)
	for req in op.get("required_item", []):
		var alts: Array = req["key"] if req["key"] is Array else [req["key"]]
		var heatable := false
		var owned := false
		for k in alts:
			var attrs = DataDB.get_item(k).get("attrs", {})
			if attrs is Dictionary and attrs.get("can_heat", false):
				heatable = true
			if sim.inventory.get_count(k) > 0:
				owned = true
		# 追加操作的器皿 (集气瓶、冷凝用陶罐) 必须持有；主操作的可加热器皿交给配方判断
		if (not heatable or ChemistrySolver.CHAIN_OPS.has(key)) and not owned:
			return "需要%s" % DataDB.get_item(alts[0]).get("name", alts[0])
	return ""

func set_operation(key: String) -> bool:
	if key != "" and op_lock_reason(key) != "":
		sim.post_notice("无法%s：%s" % [DataDB.get_lab_op(key).get("name", key), op_lock_reason(key)], Color(1.0, 0.45, 0.35))
		return false
	operation = key
	vessel.operations = [key] if key != "" else []
	vessel.reaction_timer = 0.0
	if fire_lit and not needs_fire():
		fire_lit = false
	return true

func toggle_chain(key: String) -> bool:
	if chain_ops.has(key):
		chain_ops.erase(key)
	else:
		var reason = op_lock_reason(key)
		if reason != "":
			sim.post_notice("无法%s：%s" % [DataDB.get_lab_op(key).get("name", key), reason], Color(1.0, 0.45, 0.35))
			return false
		# 两种集气方式只能选一种
		for g in ChemistrySolver.GAS_CHAIN_OPS:
			if g != key and ChemistrySolver.GAS_CHAIN_OPS.has(key):
				chain_ops.erase(g)
		chain_ops.append(key)
	vessel.chain_ops = chain_ops.duplicate()
	return true

func needs_fire() -> bool:
	return DataDB.get_lab_op(operation).get("requires_burning", false)

func needs_power() -> bool:
	return DataDB.get_lab_op(operation).get("requires_electricity", false)

# ---------------------------------------------------------------- 容器

static func is_container(key: String) -> bool:
	return DataDB.get_item(key).get("type", []).has("container")

static func can_heat(key: String) -> bool:
	var attrs = DataDB.get_item(key).get("attrs", {})
	return attrs is Dictionary and attrs.get("can_heat", false)

static func max_durable(key: String) -> int:
	var d = DataDB.get_item(key).get("durable")
	return max(1, int(d)) if d != null else 1

# 行囊中可放上实验台的容器
func container_options() -> Array:
	var keys: Array = []
	for k in sim.inventory.items.keys():
		if sim.inventory.get_count(k) > 0 and is_container(k):
			keys.append(k)
	keys.sort()
	return keys

func durability_left(key: String) -> int:
	return sim.inventory.durability_left(key, max_durable(key))

# 换容器前要先取回里面的东西；再点一次当前容器则撤下
func set_container(key: String) -> bool:
	if key == container:
		return true
	if not vessel.components.is_empty():
		sim.post_notice("先把容器里的东西取回，再换容器", Color(1.0, 0.6, 0.3))
		return false
	if key != "":
		if not is_container(key) or sim.inventory.get_count(key) <= 0:
			sim.post_notice("行囊里没有%s" % DataDB.get_item(key).get("name", key), Color(1.0, 0.45, 0.35))
			return false
		if fire_lit and not can_heat(key):
			sim.post_notice("%s不耐热，先熄火" % DataDB.get_item(key).get("name", key), Color(1.0, 0.45, 0.35))
			return false
	container = key
	vessel.container_type = key
	vessel.reaction_timer = 0.0
	return true

# 能装下该配方的容器中，优先已放上的，其次行囊中剩余耐久最多的
func best_container_for(f: Dictionary) -> String:
	var req = ChemistrySolver.formula_containers(f)
	if req.is_empty() or req.has(container):
		return container
	var best := ""
	var best_left := -1
	for k in container_options():
		if req.has(k) and durability_left(k) > best_left:
			best = k
			best_left = durability_left(k)
	return best

# 配方可用容器的名称，如「坩埚或窑炉」
static func container_names(f: Dictionary) -> String:
	var names: Array = []
	for c in ChemistrySolver.formula_containers(f):
		if is_container(c):
			names.append(DataDB.get_item(c).get("name", c))
	return "或".join(names.slice(0, 3)) if not names.is_empty() else "其他容器"

# 每完成一次反应消耗 1 点耐久；用坏最后一件时容器从台上撤下，里面的东西仍可取回
func _wear_container() -> void:
	if container == "":
		return
	var name = DataDB.get_item(container).get("name", container)
	if sim.inventory.use_durability(container, max_durable(container), 1):
		if sim.inventory.get_count(container) <= 0:
			sim.post_notice("%s用坏了，里面的东西可以取回" % name, Color(1.0, 0.6, 0.3))
			container = ""
			vessel.container_type = ""
			if fire_lit:
				fire_lit = false
		else:
			sim.post_notice("一件%s用坏了，换上新的" % name, Color(1.0, 0.75, 0.4))

# ---------------------------------------------------------------- 点火与燃料

static func fuel_info(key: String) -> Dictionary:
	if key == "stick":
		return STICK_FUEL
	var attrs = DataDB.get_item(key).get("attrs", {})
	if not (attrs is Dictionary) or not attrs.has("max_temp") or not attrs.has("burn_time"):
		return {}
	return {"burn_time": float(attrs["burn_time"]), "max_temp": float(attrs["max_temp"])}

# 行囊中可作燃料的物品 (按最高温度从低到高)
func fuel_options() -> Array:
	var keys: Array = []
	for k in sim.inventory.items.keys():
		if sim.inventory.get_count(k) > 0 and not fuel_info(k).is_empty():
			keys.append(k)
	keys.sort_custom(_fuel_less)
	return keys

# 注：Godot 4.2 的 lambda 中调用本脚本的静态函数会解析为 Nil，排序比较函数写成普通方法
func _fuel_less(a: String, b: String) -> bool:
	return fuel_info(a)["max_temp"] < fuel_info(b)["max_temp"]

func add_fuel(key: String) -> bool:
	if fuel_info(key).is_empty() or not sim.inventory.remove_item(key, 1):
		return false
	fuel_queue.append(key)
	return true

# 已投入燃料的剩余总秒数
func fuel_seconds() -> float:
	var s = cur_fuel_left
	for k in fuel_queue:
		s += fuel_info(k)["burn_time"]
	return s

func has_bellows() -> bool:
	return sim.inventory.get_count("bellows") > 0

func flame_temp() -> float:
	if not fire_lit or cur_fuel == "":
		return ROOM_TEMP
	return fuel_info(cur_fuel)["max_temp"] + (BELLOWS_BONUS if has_bellows() else 0.0)

# 点火：需要燃料，以及火种 (不消耗) 或燧石 (每次消耗 1 块)
func ignite() -> bool:
	if fire_lit:
		return true
	if not needs_fire():
		sim.post_notice("当前操作不需要加热", Color(1.0, 0.8, 0.4))
		return false
	if container == "":
		sim.post_notice("先放一件容器再点火", Color(1.0, 0.6, 0.3))
		return false
	if not can_heat(container):
		sim.post_notice("%s不耐热，不能放在火上" % DataDB.get_item(container).get("name", container), Color(1.0, 0.45, 0.35))
		return false
	if cur_fuel_left <= 0.0 and fuel_queue.is_empty():
		sim.post_notice("先放入燃料再点火", Color(1.0, 0.6, 0.3))
		return false
	if sim.inventory.get_count("fire_seed") <= 0 and not sim.inventory.remove_item("flint", 1):
		sim.post_notice("点火需要火种或燧石", Color(1.0, 0.45, 0.35))
		return false
	fire_lit = true
	if cur_fuel_left <= 0.0:
		_next_fuel()
	return true

func extinguish() -> void:
	fire_lit = false

func _next_fuel() -> bool:
	if fuel_queue.is_empty():
		cur_fuel = ""
		cur_fuel_left = 0.0
		return false
	cur_fuel = fuel_queue.pop_front()
	cur_fuel_left = fuel_info(cur_fuel)["burn_time"]
	return true

# ---------------------------------------------------------------- 电源

static func battery_info(key: String) -> Dictionary:
	var item = DataDB.get_item(key)
	var attrs = item.get("attrs", {})
	if not item.get("type", []).has("battery") or not (attrs is Dictionary) or not attrs.has("voltage"):
		return {}
	return {"voltage": float(attrs["voltage"]), "power_time": float(attrs.get("power_time", 60.0))}

func battery_options() -> Array:
	var keys: Array = []
	for k in sim.inventory.items.keys():
		if sim.inventory.get_count(k) > 0 and not battery_info(k).is_empty():
			keys.append(k)
	return keys

func connect_power(key: String) -> bool:
	if not needs_power():
		sim.post_notice("当前操作不需要通电", Color(1.0, 0.8, 0.4))
		return false
	if power_left > 0.0:
		sim.post_notice("电池还有电", Color(1.0, 0.8, 0.4))
		return false
	if battery_info(key).is_empty() or not sim.inventory.remove_item(key, 1):
		return false
	power_key = key
	power_left = battery_info(key)["power_time"]
	return true

func voltage() -> float:
	return battery_info(power_key).get("voltage", 0.0) if power_left > 0.0 else 0.0

# ---------------------------------------------------------------- 每帧推进

func tick(delta: float) -> void:
	# 容器被拿去做别的用了 (如用作制作材料)
	if container != "" and sim.inventory.get_count(container) <= 0:
		container = ""
		vessel.container_type = ""
		fire_lit = false
	if fire_lit:
		cur_fuel_left -= delta
		if cur_fuel_left <= 0.0:
			if cur_fuel == "wood":
				sim.inventory.add_item("wood_ash", 1) # 木柴燃尽留下草木灰
			if not _next_fuel():
				fire_lit = false
				sim.post_notice("燃料烧完，火熄灭了", Color(1.0, 0.7, 0.3))
	var target = flame_temp() if fire_lit else ROOM_TEMP
	var rate = HEAT_RATE if target > vessel.temperature else COOL_RATE
	vessel.temperature = move_toward(vessel.temperature, target, rate * delta)

	if needs_power() and power_left > 0.0:
		vessel.applied_voltage = voltage()
		power_left -= delta
		if power_left <= 0.0:
			sim.post_notice("%s电量耗尽" % DataDB.get_item(power_key).get("name", power_key), Color(1.0, 0.7, 0.3))
			power_key = ""
			power_left = 0.0
	else:
		vessel.applied_voltage = 0.0

# 求解器在实验台烧瓶中完成一次反应
func on_reaction(result: Dictionary) -> void:
	var f_key = str(result.get("formula_key", ""))
	for p in result.get("products", []):
		produced[p] = true
	reacted.emit(f_key, result.get("products", []), result.get("lost", []))
	if f_key == "":
		return
	_wear_container()
	var f = DataDB.get_formula(f_key)
	var m = DataDB.get_lab_op(ChemistrySolver.formula_operation(f)).get("milestone")
	if m != null and str(m) != "":
		sim.complete_milestone(str(m))
	if proven.has(f_key):
		return
	proven[f_key] = true
	if not fragments.has(f_key):
		fragments.append(f_key)
	sim.post_notice("发现新工艺：%s，已记入手稿" % f.get("name", f_key), Color(0.95, 0.75, 0.3))
	sim.unlock_blueprint(_blueprint_from(f), true)

func _blueprint_from(f: Dictionary) -> ProcessBlueprint:
	var inputs := {}
	for req in f.get("required_items", []):
		var k = req["key"][0] if req["key"] is Array else req["key"]
		inputs[k] = float(req.get("quantity", 1.0))
	var outputs := {}
	for p in f.get("products", []):
		outputs[p["key"]] = float(p.get("quantity", p.get("multiple", 1.0)))
	var bp = ProcessBlueprint.new(f["key"], f.get("name", f["key"]), inputs, outputs, ChemistrySolver.formula_min_temp(f))
	bp.duration_seconds = max(3.0, float(f.get("time_required", 3.0)))
	return bp

# ---------------------------------------------------------------- 烧瓶投料与取回

func add_reagent(key: String, amount: int = 1) -> bool:
	if container == "":
		sim.post_notice("先在实验台上放一件容器", Color(1.0, 0.6, 0.3))
		return false
	if not sim.inventory.remove_item(key, amount):
		return false
	vessel.add_substance(key, float(amount))
	return true

# 把烧瓶内容全部退回行囊：本次生成的产物四舍五入，未反应的原料向下取整 (不会凭空多出)
func retrieve_all() -> Dictionary:
	var got := {}
	for k in vessel.components.keys():
		var amt = float(vessel.components[k])
		var n = int(round(amt)) if produced.has(k) else int(floor(amt + 0.001))
		if n > 0:
			sim.inventory.add_item(k, n)
			got[k] = n
	vessel.components.clear()
	vessel.reaction_timer = 0.0
	vessel.active_formula = ""
	produced.clear()
	return got

# ---------------------------------------------------------------- 手稿

func has_clue(f_key: String) -> bool:
	return proven.has(f_key) or fragments.has(f_key)

static func formula_era(f: Dictionary) -> int:
	var key = f.get("required_era")
	if key == null:
		return 0
	for e in DataDB.eras:
		if e.get("key") == key:
			return int(e.get("order", 0))
	return 0

static func main_items(f: Dictionary) -> Array:
	var keys: Array = []
	for req in f.get("required_items", []):
		if req.get("isMain", false):
			keys.append_array(req["key"] if req["key"] is Array else [req["key"]])
	return keys

# 可掉落的手稿：当前时代以内、尚未持有或确证、主料曾经获得过
func eligible_fragments() -> Array:
	var pool: Array = []
	for f in DataDB.formulas.values():
		if not f.has("fragment_description") or has_clue(f["key"]):
			continue
		if formula_era(f) > sim.current_era:
			continue
		var mains = main_items(f)
		var seen_main := mains.is_empty()
		for k in mains:
			if seen_items.has(k):
				seen_main = true
		if not seen_main:
			continue
		pool.append(f)
	return pool

func grant_fragment(pool: Array) -> String:
	if pool.is_empty():
		return ""
	var f = pool[randi() % pool.size()]
	fragments.append(f["key"])
	sim.post_notice("获得手稿：%s" % f.get("name", f["key"]), Color(0.85, 0.65, 0.35))
	return f["key"]

func on_harvest() -> void:
	if randf() < FRAGMENT_HARVEST_CHANCE:
		grant_fragment(eligible_fragments())

# 研发科技后必得一份手稿：优先选配方或其操作需要这项科技的，其次选与科技同时代的，最后任选一份
func on_tech(tech_key: String) -> void:
	var all = eligible_fragments()
	var by_tech: Array = []
	var by_era: Array = []
	var tech_era = DataDB.get_tech_era(tech_key)
	for f in all:
		var op_techs = DataDB.get_lab_op(ChemistrySolver.formula_operation(f)).get("required_techs", [])
		if f.get("required_techs", []).has(tech_key) or op_techs.has(tech_key):
			by_tech.append(f)
		elif formula_era(f) == tech_era:
			by_era.append(f)
	grant_fragment(by_tech if not by_tech.is_empty() else (by_era if not by_era.is_empty() else all))

func note_item(key: String) -> void:
	if key == "" or seen_items.has(key):
		return
	seen_items[key] = true
	if randf() < FRAGMENT_NEW_ITEM_CHANCE:
		var pool: Array = []
		for f in eligible_fragments():
			if main_items(f).has(key):
				pool.append(f)
		grant_fragment(pool)

# 手稿正文：#物品# 未见过的显示为 ???，$操作$ 显示操作名 (BBCode)
func fragment_text(f_key: String, known_col: String, op_col: String, unknown_col: String) -> String:
	var f = DataDB.get_formula(f_key)
	var desc = str(f.get("fragment_description", f.get("description", "")))
	var prods := {}
	for p in f.get("products", []):
		prods[p["key"]] = true
	var re = RegEx.new()
	re.compile("#([\\w]+)#")
	var out := ""
	var pos := 0
	for m in re.search_all(desc):
		out += desc.substr(pos, m.get_start() - pos)
		var k = m.get_string(1)
		if seen_items.has(k) or prods.has(k) or proven.has(f_key):
			out += "[color=%s]%s[/color]" % [known_col, DataDB.get_item(k).get("name", k)]
		else:
			out += "[color=%s]???[/color]" % unknown_col
		pos = m.get_end()
	out += desc.substr(pos)
	re.compile("\\$([\\w]+)\\$")
	var res := ""
	pos = 0
	for m in re.search_all(out):
		res += out.substr(pos, m.get_start() - pos)
		res += "[color=%s]%s[/color]" % [op_col, DataDB.get_lab_op(m.get_string(1)).get("name", "???")]
		pos = m.get_end()
	return res + out.substr(pos)

# 按手稿备料：切换到所需操作，并从行囊把每种原料按用量投入烧瓶。返回缺少的原料名称
func prepare_from_fragment(f_key: String) -> Array:
	var f = DataDB.get_formula(f_key)
	var missing: Array = []
	var box = best_container_for(f)
	if box == "":
		missing.append(container_names(f))
		return missing
	if box != container and not set_container(box):
		missing.append("换用%s（先取回当前容器里的东西）" % container_names(f))
		return missing
	var op = ChemistrySolver.formula_operation(f)
	if op != "" and op != operation:
		if op_lock_reason(op) != "":
			missing.append(op_lock_reason(op))
		else:
			set_operation(op)
	# 手稿里写到要集气或冷凝的，能做就顺手勾上
	for c in chain_needed(f):
		if not chain_ops.has(c) and op_lock_reason(c) == "":
			toggle_chain(c)
	for req in f.get("required_items", []):
		var need = int(ceil(float(req.get("quantity", 1.0))))
		var alts: Array = req["key"] if req["key"] is Array else [req["key"]]
		var have_in_vessel := false
		for k in alts:
			if vessel.get_moles(k) >= float(req.get("quantity", 1.0)):
				have_in_vessel = true
		if have_in_vessel:
			continue
		var done := false
		for k in alts:
			if sim.inventory.get_count(k) >= need:
				add_reagent(k, need)
				done = true
				break
		if not done:
			var nm = DataDB.get_item(alts[0]).get("name", alts[0]) if seen_items.has(alts[0]) else "???"
			missing.append("%s ×%d" % [nm, need])
	return missing

# 配方中需要追加操作才能收集的产物对应的追加操作 (气体默认用排空气集气)
static func chain_needed(f: Dictionary) -> Array:
	var out: Array = []
	for p in f.get("products", []):
		var need = str(p.get("required_chain_operation", ""))
		if need == "" and DataDB.get_item(str(p.get("key", ""))).get("type", []).has("gas"):
			need = "gas_collecting_air"
		if need in ChemistrySolver.CHAIN_OPS and not out.has(need):
			if out.has("gas_collecting") and need == "gas_collecting_air":
				continue
			out.append(need)
	return out

# ---------------------------------------------------------------- 侦测卡

# 当前烧瓶的状态说明。只有持有手稿的配方才会指出具体缺什么，避免直接给出答案。
# 返回 {"state": empty|reacting|blocked|unknown|partial|inert, "text": String, "progress": float}
func diagnose() -> Dictionary:
	if container == "":
		return {"state": "empty", "text": "先在右侧选择一件容器放上实验台"}
	if vessel.components.is_empty():
		return {"state": "empty", "text": "从右侧行囊选择试剂放入%s" % DataDB.get_item(container).get("name", container)}
	if vessel.active_formula != "":
		var f = DataDB.get_formula(vessel.active_formula)
		var t = max(1.0, float(f.get("time_required", 1.0)))
		var nm = f.get("name", "") if has_clue(f["key"]) else "未知反应"
		return {"state": "reacting", "text": "%s进行中" % nm, "progress": clampf(vessel.reaction_timer / t, 0.0, 1.0)}

	var full_known: Array = []
	var full_unknown := false
	var partial: Array = []
	for f in DataDB.formulas.values():
		var reqs = f.get("required_items", [])
		if reqs.is_empty():
			continue
		var present := 0
		for req in reqs:
			if _req_present(req):
				present += 1
		if present == reqs.size():
			if has_clue(f["key"]):
				full_known.append(f)
			else:
				full_unknown = true
		elif present > 0 and has_clue(f["key"]):
			partial.append(f)

	if not full_known.is_empty():
		var f = full_known[0]
		var needs: Array = []
		var op = ChemistrySolver.formula_operation(f)
		if op != "" and op != operation:
			needs.append("改用「%s」" % DataDB.get_lab_op(op).get("name", op))
		var t = ChemistrySolver.formula_min_temp(f)
		if t > 0.0 and vessel.temperature < t:
			needs.append("加热到 %d ℃（当前 %d ℃）" % [int(t - 273.15), int(vessel.temperature - 273.15)])
		var v = ChemistrySolver.formula_min_voltage(f)
		if v > 0.0 and vessel.applied_voltage < v:
			needs.append("通电 %.0f V 以上" % v)
		if not sim.solver._matches_container(vessel, f):
			needs.append("换用%s" % container_names(f))
		elif ChemistrySolver.formula_min_temp(f) > 0.0 and DataDB.get_lab_op(op).get("requires_burning", false) and not can_heat(container):
			needs.append("换用耐热的%s" % container_names(f))
		if needs.is_empty():
			return {"state": "reacting", "text": "%s即将开始" % f.get("name", ""), "progress": 0.0}
		return {"state": "blocked", "text": "%s：%s" % [f.get("name", ""), "，".join(needs)]}
	if full_unknown:
		return {"state": "unknown", "text": "没有反应。换一种操作，或者加热到更高温度试试"}
	if not partial.is_empty():
		var f = partial[0]
		var lack: Array = []
		for req in f.get("required_items", []):
			if not _req_present(req):
				var k = req["key"][0] if req["key"] is Array else req["key"]
				var nm = DataDB.get_item(k).get("name", k) if seen_items.has(k) else "???"
				lack.append("%s ×%d" % [nm, int(ceil(float(req.get("quantity", 1.0))))])
		return {"state": "partial", "text": "按手稿「%s」还缺 %s" % [f.get("name", ""), "、".join(lack)]}
	return {"state": "inert", "text": "这些试剂之间没有已知反应"}

func _req_present(req: Dictionary) -> bool:
	var q = float(req.get("quantity", 1.0))
	var alts: Array = req["key"] if req["key"] is Array else [req["key"]]
	for k in alts:
		if vessel.get_moles(k) >= q:
			return true
	return false

# ---------------------------------------------------------------- 存档

func serialize() -> Dictionary:
	return {
		"operation": operation,
		"container": container,
		"chain_ops": chain_ops.duplicate(),
		"fire_lit": fire_lit,
		"fuel_queue": fuel_queue.duplicate(),
		"cur_fuel": cur_fuel,
		"cur_fuel_left": cur_fuel_left,
		"power_key": power_key,
		"power_left": power_left,
		"fragments": fragments.duplicate(),
		"proven": proven.keys(),
		"seen_items": seen_items.keys(),
		"produced": produced.keys(),
	}

# 旧存档没有这些字段：给初始手稿，曾获得物品按当前行囊推算
func deserialize(d: Dictionary) -> void:
	reset()
	operation = str(d.get("operation", ""))
	vessel.operations = [operation] if operation != "" else []
	container = str(d.get("container", ""))
	if not is_container(container):
		container = ""
	vessel.container_type = container
	chain_ops = Array(d.get("chain_ops", []))
	vessel.chain_ops = chain_ops.duplicate()
	fire_lit = bool(d.get("fire_lit", false))
	fuel_queue = Array(d.get("fuel_queue", []))
	cur_fuel = str(d.get("cur_fuel", ""))
	cur_fuel_left = float(d.get("cur_fuel_left", 0.0))
	power_key = str(d.get("power_key", ""))
	power_left = float(d.get("power_left", 0.0))
	if d.has("fragments"):
		fragments = Array(d["fragments"])
	for k in d.get("proven", []):
		proven[str(k)] = true
	if d.has("seen_items"):
		for k in d["seen_items"]:
			seen_items[str(k)] = true
	else:
		for k in sim.inventory.items.keys():
			seen_items[k] = true
	for k in d.get("produced", []):
		produced[str(k)] = true
