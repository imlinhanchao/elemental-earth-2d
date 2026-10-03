# chemistry_solver.gd
# 唯象化学求解器：处理体系内各组分的自发与受激反应
class_name ChemistrySolver
extends RefCounted

const DataDB = preload("res://src/core/data_db.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

signal element_discovered(element_number: int, item_key: String)
signal reaction_occurred(reaction_name: String, products: Array)

# 单次求解计算 (推进 delta_time 秒的反应过程)
func solve(buffer: MixtureBuffer, delta_time: float) -> Dictionary:
	var results = {
		"occurred": false,
		"reactions": [],
		"discovered_elements": []
	}
	
	if buffer.total_moles() <= 0.0:
		return results

	# 1. 尝试炭热还原反应 (碳 + 金属氧化物 -> 金属单质 + CO/CO2)
	_solve_carbothermic_reduction(buffer, results)

	# 2. 尝试高温热解反应 (如碳酸盐煅烧)
	_solve_thermal_decomposition(buffer, results)

	# 3. 尝试电解反应 (外加直流电解)
	_solve_electrolysis(buffer, results)

	# 4. 扫描产物中的纯净单质发现
	_check_element_discoveries(buffer, results)

	return results

# 炭热还原反应实现
func _solve_carbothermic_reduction(buffer: MixtureBuffer, results: Dictionary) -> void:
	var has_carbon = buffer.has_substance("charcoal") or buffer.has_substance("carbon") or buffer.has_substance("coal")
	if buffer.temperature < 800.0 or not has_carbon:
		return

	var carbon_key = "charcoal" if buffer.has_substance("charcoal") else ("carbon" if buffer.has_substance("carbon") else "coal")

	# 案例 1: 孔雀石/氧化铜 -> 金属铜 + 二氧化碳
	if buffer.has_substance("malachite") or buffer.has_substance("copper_ore"):
		var ore_key = "malachite" if buffer.has_substance("malachite") else "copper_ore"
		var ore_moles = buffer.consume_substance(ore_key, 1.0)
		var c_moles = buffer.consume_substance(carbon_key, 0.5)
		if ore_moles > 0:
			buffer.add_substance("copper", ore_moles * 0.9)
			buffer.add_substance("carbon_dioxide", ore_moles * 0.5)
			results["occurred"] = true
			results["reactions"].append("木炭冶炼孔雀石制备单质铜")
			reaction_occurred.emit("木炭冶炼孔雀石制备单质铜", ["copper", "carbon_dioxide"])

	# 案例 2: 铁矿石 -> 铁单质
	if buffer.has_substance("iron_ore") or buffer.has_substance("hematite"):
		var ore_key = "iron_ore" if buffer.has_substance("iron_ore") else "hematite"
		var ore_moles = buffer.consume_substance(ore_key, 1.0)
		var c_moles = buffer.consume_substance(carbon_key, 1.5)
		if ore_moles > 0:
			buffer.add_substance("iron", ore_moles * 1.0)
			buffer.add_substance("carbon_dioxide", ore_moles * 1.5)
			results["occurred"] = true
			results["reactions"].append("高炉碳热还原炼铁")
			reaction_occurred.emit("高炉碳热还原炼铁", ["iron", "carbon_dioxide"])

# 热分解反应实现
func _solve_thermal_decomposition(buffer: MixtureBuffer, results: Dictionary) -> void:
	if buffer.temperature >= 1050.0 and (buffer.has_substance("calcite") or buffer.has_substance("limestone")):
		var ore_key = "calcite" if buffer.has_substance("calcite") else "limestone"
		var ore_moles = buffer.consume_substance(ore_key, 1.0)
		if ore_moles > 0:
			buffer.add_substance("quicklime", ore_moles)
			buffer.add_substance("carbon_dioxide", ore_moles)
			results["occurred"] = true
			results["reactions"].append("碳酸钙高温热解生成生石灰")
			reaction_occurred.emit("碳酸钙高温热解生成生石灰", ["quicklime", "carbon_dioxide"])

# 电解反应实现
func _solve_electrolysis(buffer: MixtureBuffer, results: Dictionary) -> void:
	if buffer.applied_voltage < 2.0:
		return
	
	if buffer.has_substance("water", 1.0):
		var w_moles = buffer.consume_substance("water", 1.0)
		if w_moles > 0:
			buffer.add_substance("hydrogen", w_moles * 1.0)
			buffer.add_substance("oxygen", w_moles * 0.5)
			results["occurred"] = true
			results["reactions"].append("直流电解水制氢与纯氧")
			reaction_occurred.emit("直流电解水制氢与纯氧", ["hydrogen", "oxygen"])

# 扫描单质发现
func _check_element_discoveries(buffer: MixtureBuffer, results: Dictionary) -> void:
	for key in buffer.components.keys():
		var elem_num = DataDB.is_pure_element(key)
		if elem_num > 0:
			results["discovered_elements"].append(elem_num)
			element_discovered.emit(elem_num, key)
