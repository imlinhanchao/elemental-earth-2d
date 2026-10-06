# test_tutorial.gd
# 无头测试：教程 7 步按目标自动推进，地图标记指向正确资源，完成后标记清除
# 用法: Godot --headless --path . res://tests/test_tutorial.tscn
# (以场景方式运行，才能访问 GameState 自动加载)
extends Node

const SettingsManager = preload("res://src/core/settings_manager.gd")

var _failed := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		_failed += 1
		printerr("  ✗ ", msg)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _ready() -> void:
	print("\n[新手教程测试]")
	# 教程完成会写入玩家设置，测试结束后恢复原值
	var had_completed = SettingsManager.is_tutorial_completed()
	# 建造篝火会触发自动保存，测试前备份玩家的 auto 存档，结束后还原
	var auto_path = "user://save_auto.json"
	var auto_backup = FileAccess.get_file_as_bytes(auto_path) if FileAccess.file_exists(auto_path) else PackedByteArray()
	await get_tree().process_frame
	GameState.reset_to_new_game()
	GameState.start_tutorial()
	var w = load("res://src/scenes/world.tscn").instantiate()
	add_child(w)
	await _wait(0.5)
	var inv = GameState.inventory

	var mk = GameState.tutorial_marker_hex
	_check(mk != Vector2i(9999, 9999) and int(GameState.tile_resources.get(mk, {}).get("stone", 0)) > 0, "第 1 步在地图上标出一块有碎石的地块")
	var first = GameState.get_tile_available_resources(mk)
	_check(not first.is_empty() and first[0]["key"] == "stone", "标出的地块左键点击就会采到碎石")
	_check(GameState.get_hex_resource(mk) == "stone", "标出的地块地表显示的就是碎石")
	inv.add_item("stone", 2)
	await _wait(1.5)
	_check(GameState.tutorial_step == 1, "采到 2 块碎石后自动进入第 2 步")
	_check(int(GameState.tile_resources.get(GameState.tutorial_marker_hex, {}).get("stick", 0)) > 0, "第 2 步标记改为枯树枝地块")

	inv.add_item("stick", 2)
	inv.add_item("flint", 2)
	await _wait(1.5)
	_check(GameState.tutorial_step == 2 and GameState.tutorial_marker_hex == Vector2i(9999, 9999), "第 3 步 (制作) 没有地图标记")
	_check(GameState.craft_tool("flint_axe"), "按教程材料可以制作燧石手斧")
	await _wait(1.5)
	_check(GameState.tutorial_step == 3, "装备斧头后进入第 4 步")
	_check(int(GameState.tile_resources.get(GameState.tutorial_marker_hex, {}).get("wood", 0)) > 0, "第 4 步标记指向树木 (装备斧头后才可见)")
	var tree_node = w.resource_nodes.get(GameState.tutorial_marker_hex)
	_check(tree_node != null and tree_node.visible, "装备斧头后，标记地块上的树木节点在地图上可见")
	var hidden_trees = 0
	for h in w.resource_nodes.keys():
		var n = w.resource_nodes[h]
		if n.item_key == "wood" and GameState.is_hex_in_territory(h.x, h.y) and not n.visible:
			hidden_trees += 1
	_check(hidden_trees == 0, "领地内所有树木在装备斧头后都显示出来 (隐藏 %d 棵)" % hidden_trees)

	inv.add_item("wood", 4)
	await _wait(1.5)
	_check(GameState.tutorial_step == 4, "砍到 4 根原木后进入第 5 步")
	inv.add_item("stone", 4)
	await _wait(1.5)
	_check(GameState.tutorial_step == 5, "碎石凑够 4 块后进入第 6 步 (建造)")
	_check(GameState.build_structure("fire_pit", Vector2i(1, 0)), "按教程材料可以建造篝火堆")
	await _wait(1.5)
	_check(GameState.tutorial_step == 6, "建好篝火堆后进入第 7 步")

	w.hud.tech_modal.open()
	await _wait(1.5)
	_check(not GameState.is_tutorial_active, "打开科技树后教程完成")
	_check(GameState.tutorial_marker_hex == Vector2i(9999, 9999), "教程结束后清除地图标记")

	w.queue_free()
	SettingsManager.set_tutorial_completed(had_completed)
	if auto_backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(auto_path))
	else:
		var f = FileAccess.open(auto_path, FileAccess.WRITE)
		f.store_buffer(auto_backup)
		f.close()
	if _failed == 0:
		print("🎉 新手教程测试全部通过")
		get_tree().quit(0)
	else:
		printerr("❌ %d 项失败" % _failed)
		get_tree().quit(1)
