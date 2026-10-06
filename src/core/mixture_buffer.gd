# mixture_buffer.gd
# 容器/管道内的混合物料状态对象
class_name MixtureBuffer
extends RefCounted

# 存储组分: item_key -> moles (摩尔量)
var components: Dictionary = {}

var temperature: float = 293.15 # 开氏度 (默认 20℃)
var pressure: float = 101.325   # kPa (默认 1 atm)
var volume: float = 1.0         # 容积 (升 L)
var applied_voltage: float = 0.0 # 外加电解电压 (V)

var container_type: String = "flask"
# 额外可用器皿：玩家背包中持有的筛子/坩埚/烧杯等，由模拟层每秒同步
var available_containers: Array = []
var reaction_timer: float = 0.0

func add_substance(key: String, moles: float) -> void:
	if moles <= 0.0:
		return
	components[key] = components.get(key, 0.0) + moles

func consume_substance(key: String, moles: float) -> float:
	var current = components.get(key, 0.0)
	var actual_consumed = min(current, moles)
	components[key] = current - actual_consumed
	if components[key] <= 0.00001:
		components.erase(key)
	return actual_consumed

func get_moles(key: String) -> float:
	return components.get(key, 0.0)

func total_moles() -> float:
	var sum: float = 0.0
	for m in components.values():
		sum += m
	return sum

func has_substance(key: String, min_moles: float = 0.001) -> bool:
	return get_moles(key) >= min_moles

func clear() -> void:
	components.clear()
	applied_voltage = 0.0

func duplicate_buffer() -> RefCounted:
	var copy = get_script().new()
	copy.components = components.duplicate()
	copy.temperature = temperature
	copy.pressure = pressure
	copy.volume = volume
	copy.applied_voltage = applied_voltage
	return copy
