# player_inventory.gd
# 玩家随身背包数据单例
class_name PlayerInventory
extends RefCounted

signal item_changed(item_key: String, count: int)

# item_key -> count
var items: Dictionary = {}

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
		item_changed.emit(key, 0)
	else:
		item_changed.emit(key, items[key])
	return true

func get_count(key: String) -> int:
	return items.get(key, 0)

func has_item(key: String, min_count: int = 1) -> bool:
	return get_count(key) >= min_count
