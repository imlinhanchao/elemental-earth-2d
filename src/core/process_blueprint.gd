# process_blueprint.gd
# 工业工艺蓝图数据对象 (从微观实验室固化导出，用于插装进工业反应塔批量连续生产)
class_name ProcessBlueprint
extends RefCounted

var id: String = ""
var display_name: String = ""
var inputs: Dictionary = {}    # input_key -> required_moles
var outputs: Dictionary = {}   # output_key -> yield_moles
var min_temp: float = 293.15   # 最低启动温度 (K)
var optimal_temp: float = 293.15
var requires_electricity: bool = false
var duration_seconds: float = 3.0 # 单轮生产耗时

func _init(p_id: String = "", p_name: String = "", p_in: Dictionary = {}, p_out: Dictionary = {}, p_temp: float = 293.15) -> void:
	id = p_id
	display_name = p_name
	inputs = p_in
	outputs = p_out
	min_temp = p_temp
