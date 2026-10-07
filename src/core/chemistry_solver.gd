# chemistry_solver.gd
# 查表式化学求解器：读取 DataDB.formulas 配方表，按时间步进匹配执行反应
class_name ChemistrySolver
extends RefCounted

const DataDB = preload("res://src/core/data_db.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

signal element_discovered(element_number: int, item_key: String)
signal reaction_occurred(reaction_name: String, products: Array)

func solve(buffer: MixtureBuffer, delta_time: float) -> Dictionary:
	var results = {
		"occurred": false,
		"reactions": [],
		"discovered_elements": [],
		"in_progress": false
	}
	
	if buffer.total_moles() <= 0.0:
		buffer.reaction_timer = 0.0
		buffer.active_formula = ""
		return results
		
	# 遍历配方表进行查表匹配 (优先匹配带温度/电压限制的特定反应)
	var matched_formula: Dictionary = _find_matching_formula(buffer)
	if matched_formula.is_empty():
		buffer.reaction_timer = 0.0
		buffer.active_formula = ""
		_check_element_discoveries(buffer, results)
		return results
	# 换了配方 (投料或条件变化) 就重新计时
	var f_key = str(matched_formula.get("key", ""))
	if buffer.active_formula != f_key:
		buffer.active_formula = f_key
		buffer.reaction_timer = 0.0
	results["formula_key"] = f_key
		
	var time_req = max(1.0, float(matched_formula.get("time_required", 1.0)))
	buffer.reaction_timer += delta_time
	
	if buffer.reaction_timer >= time_req:
		buffer.reaction_timer -= time_req
		_execute_formula(buffer, matched_formula, results)
	else:
		results["in_progress"] = true
		
	_check_element_discoveries(buffer, results)
	return results

func _find_matching_formula(buffer: MixtureBuffer) -> Dictionary:
	var best_formula: Dictionary = {}
	var best_score: float = -1.0
	
	for f_key in DataDB.formulas.keys():
		var f = DataDB.formulas[f_key]
		if _matches_conditions(buffer, f):
			var score = _calculate_formula_priority(f)
			if score > best_score:
				best_score = score
				best_formula = f
				
	return best_formula

# 配方所需操作 (labs.json 的 key)，没有写则为空
static func formula_operation(formula: Dictionary) -> String:
	var ra = formula.get("required_actions")
	return str(ra.get("key", "")) if ra is Dictionary else ""

# 最低温度 (K)：配方自己写了就用配方的，否则用所需操作的默认值 (如焙烧 973K)
static func formula_min_temp(formula: Dictionary) -> float:
	var t = float(formula.get("min_temp", formula.get("min_temperature", 0.0)))
	if t > 0.0:
		return t
	return float(DataDB.get_lab_op(formula_operation(formula)).get("default_min_temp", 0.0))

# 最低电压 (V)：同上
static func formula_min_voltage(formula: Dictionary) -> float:
	var v = float(formula.get("min_voltage", 0.0))
	if v > 0.0:
		return v
	return float(DataDB.get_lab_op(formula_operation(formula)).get("default_min_voltage", 0.0))

# 能被追加操作收集的产物：集气 (排水 / 排空气) 收集气体，冷凝收集蒸气
const CHAIN_OPS := ["gas_collecting", "gas_collecting_air", "condensation"]
const GAS_CHAIN_OPS := ["gas_collecting", "gas_collecting_air"]

static func product_collected(p: Dictionary, chain_ops: Array) -> bool:
	if chain_ops.has("*"):
		return true
	var need = str(p.get("required_chain_operation", ""))
	if need in CHAIN_OPS:
		return chain_ops.has(need)
	if need == "" and DataDB.get_item(str(p.get("key", ""))).get("type", []).has("gas"):
		for g in GAS_CHAIN_OPS:
			if chain_ops.has(g):
				return true
		return false
	return true # 其余写在 required_chain_operation 的操作 (加热、溶解等) 视为主操作的一部分

func _calculate_formula_priority(formula: Dictionary) -> float:
	var score = 0.0
	var min_temp = formula_min_temp(formula)
	var min_volt = formula_min_voltage(formula)
	
	# 有温度或电压条件的配方优先级远高于常温常压配方，防止被无门槛配方提前抢占
	if min_temp > 0.0:
		score += 10000.0 + min_temp
	if min_volt > 0.0:
		score += 10000.0 + min_volt * 100.0
		
	if formula.has("required_container") and not str(formula["required_container"]).is_empty():
		score += 500.0
		
	var req_items = formula.get("required_items", [])
	score += req_items.size() * 10.0
	return score

func _matches_conditions(buffer: MixtureBuffer, formula: Dictionary) -> bool:
	# 1. 容器匹配检查
	if not _matches_container(buffer, formula):
		return false

	# 2. 操作匹配：选错操作 (如该焙烧却在搅拌) 不反应
	# 少数配方以集气为主操作 (如一氧化氮氧化)，勾选该追加操作即可
	var op = formula_operation(formula)
	if op != "" and not buffer.operations.has("*") and not buffer.operations.has(op) and not buffer.chain_ops.has(op):
		return false

	# 3. 温度阈值检查
	var min_temp = formula_min_temp(formula)
	if min_temp > 0.0 and buffer.temperature < min_temp:
		return false
		
	# 4. 电压阈值检查
	var min_volt = formula_min_voltage(formula)
	if min_volt > 0.0 and buffer.applied_voltage < min_volt:
		return false
		
	# 5. 反应原料检查
	var req_items = formula.get("required_items", [])
	if req_items.is_empty():
		return false
		
	for req in req_items:
		var q_needed = float(req.get("quantity", 1.0))
		var k = req.get("key")
		if k is Array:
			var found_alt = false
			for alt_k in k:
				if buffer.get_moles(alt_k) >= q_needed:
					found_alt = true
					break
			if not found_alt:
				return false
		elif k is String:
			if buffer.get_moles(k) < q_needed:
				return false
		else:
			return false
			
	return true

# 炉体能当作哪些容器：炉膛本身耐火，可代替坩埚、窑炉 (篝火堆只能闷烧)
const FURNACE_CONTAINERS := {
	"fire_pit": ["fire_pit"],
	"furnace": ["furnace", "kiln", "crucible"],
	"blast_furnace": ["blast_furnace", "furnace", "kiln", "crucible"],
}

static func formula_containers(formula: Dictionary) -> Array:
	var req = formula.get("required_container")
	if req is Array:
		return req
	if req is String and req != "":
		return [req]
	return []

func _matches_container(buffer: MixtureBuffer, formula: Dictionary) -> bool:
	var req = formula_containers(formula)
	if req.is_empty() or buffer.container_type == "*":
		return true
	for c in FURNACE_CONTAINERS.get(buffer.container_type, [buffer.container_type]):
		if req.has(c):
			return true
	return false

func _execute_formula(buffer: MixtureBuffer, formula: Dictionary, results: Dictionary) -> void:
	# 1. 消耗原料
	var req_items = formula.get("required_items", [])
	for req in req_items:
		var q_needed = float(req.get("quantity", 1.0))
		var k = req.get("key")
		if k is Array:
			for alt_k in k:
				if buffer.get_moles(alt_k) >= q_needed:
					buffer.consume_substance(alt_k, q_needed)
					break
		elif k is String:
			buffer.consume_substance(k, q_needed)
			
	# 2. 生成产物进 buffer；没有对应追加操作时，气体逸散、需冷凝的产物随蒸气流失
	var prod_list = formula.get("products", [])
	var prod_keys: Array = []
	var lost: Array = []
	for p in prod_list:
		var p_key = p.get("key", "")
		var p_qty = float(p.get("quantity", p.get("multiple", 1.0)))
		if p_key == "":
			continue
		if not product_collected(p, buffer.chain_ops):
			lost.append(p_key)
			continue
		buffer.add_substance(p_key, p_qty)
		prod_keys.append(p_key)
	results["lost"] = lost
			
	var f_name = formula.get("name", formula.get("key", "未知反应"))
	results["occurred"] = true
	results["reactions"].append(f_name)
	results["products"] = prod_keys
	reaction_occurred.emit(f_name, prod_keys)

func _check_element_discoveries(buffer: MixtureBuffer, results: Dictionary) -> void:
	for key in buffer.components.keys():
		var elem_num = DataDB.is_pure_element(key)
		if elem_num > 0 and not results["discovered_elements"].has(elem_num):
			results["discovered_elements"].append(elem_num)
			element_discovered.emit(elem_num, key)
