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
		return results
		
	# 遍历配方表进行查表匹配 (优先匹配带温度/电压限制的特定反应)
	var matched_formula: Dictionary = _find_matching_formula(buffer)
	if matched_formula.is_empty():
		buffer.reaction_timer = 0.0
		_check_element_discoveries(buffer, results)
		return results
		
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

func _calculate_formula_priority(formula: Dictionary) -> float:
	var score = 0.0
	var min_temp = float(formula.get("min_temp", formula.get("min_temperature", 0.0)))
	var min_volt = float(formula.get("min_voltage", 0.0))
	
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

	# 2. 温度阈值检查
	var min_temp = float(formula.get("min_temp", formula.get("min_temperature", 0.0)))
	if min_temp > 0.0 and buffer.temperature < min_temp:
		return false
		
	# 3. 电压阈值检查
	var min_volt = float(formula.get("min_voltage", 0.0))
	if min_volt > 0.0 and buffer.applied_voltage < min_volt:
		return false
		
	# 4. 反应原料检查
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

func _matches_container(buffer: MixtureBuffer, formula: Dictionary) -> bool:
	if not formula.has("required_container"):
		return true
	var req = formula["required_container"]
	if req is String:
		if req == "" or buffer.container_type == "":
			return true
		if req == buffer.container_type:
			return true
		# 容器别名兼容匹配
		if buffer.container_type == "furnace" and req in ["furnace", "kiln", "blast_furnace", "crucible"]:
			return true
		if buffer.container_type == "flask" and req in ["flask", "clay_pot", "beaker", "cell"]:
			return true
		return false
	elif req is Array:
		if req.is_empty() or buffer.container_type == "":
			return true
		if req.has(buffer.container_type):
			return true
		if buffer.container_type == "furnace":
			for alias in ["furnace", "kiln", "blast_furnace", "crucible"]:
				if req.has(alias):
					return true
		if buffer.container_type == "flask":
			for alias in ["flask", "clay_pot", "beaker", "cell"]:
				if req.has(alias):
					return true
		return false
	return true

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
			
	# 2. 生成产物进 buffer
	var prod_list = formula.get("products", [])
	var prod_keys: Array = []
	for p in prod_list:
		var p_key = p.get("key", "")
		var p_qty = float(p.get("quantity", p.get("multiple", 1.0)))
		if p_key != "":
			buffer.add_substance(p_key, p_qty)
			prod_keys.append(p_key)
			
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
