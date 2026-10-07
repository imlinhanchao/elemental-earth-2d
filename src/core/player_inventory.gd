# player_inventory.gd
# 玩家随身背包数据单例
class_name PlayerInventory
extends RefCounted

signal item_changed(item_key: String, count: int)

# item_key -> count
var items: Dictionary = {}
# 有耐久的物品：item_key -> 当前正在用的这一件已消耗的耐久 (同类物品叠放，只记最上面一件)
var wear: Dictionary = {}

func add_item(key: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	items[key] = items.get(key, 0) + amount
	item_changed.emit(key, items[key])

func remove_item(key: String, amount: int = 1) -> bool:
	var current = items.get(key, 0)
	if current < amount:
		return false
	items[key] = current - amount
	if items[key] <= 0:
		items.erase(key)
		wear.erase(key)
		item_changed.emit(key, 0)
	else:
		item_changed.emit(key, items[key])
	return true

func get_count(key: String) -> int:
	return items.get(key, 0)

func has_item(key: String, min_count: int = 1) -> bool:
	return get_count(key) >= min_count

# 剩余总耐久：max_durable 为单件耐久 (items.json 的 durable)
func durability_left(key: String, max_durable: int) -> int:
	var n = get_count(key)
	if n <= 0:
		return 0
	return n * max_durable - int(wear.get(key, 0))

# 消耗耐久，用尽一件就移除一件。返回是否用坏了一件
func use_durability(key: String, max_durable: int, amount: int = 1) -> bool:
	if get_count(key) <= 0:
		return false
	var w = int(wear.get(key, 0)) + amount
	if w < max_durable:
		wear[key] = w
		item_changed.emit(key, get_count(key))
		return false
	wear.erase(key)
	remove_item(key, 1)
	return true

func clear() -> void:
	items.clear()
	wear.clear()
