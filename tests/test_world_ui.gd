# test_world_ui.gd
# 无头测试：弹窗 / HUD 面板上滚动不缩放地图；顶栏显示装备与元素；制作抽屉筛选与换行；树苗掉落、种植、长成与存读档
# 用法: Godot --headless --path . res://tests/test_world_ui.tscn
extends Node

var _failed := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		_failed += 1
		printerr("  ✗ ", msg)

func _wheel(w, pos: Vector2) -> float:
	w.camera.zoom = Vector2.ONE
	var ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	w._unhandled_input(ev)
	return w.camera.zoom.x

func _ready() -> void:
	print("\n[地图与界面测试]")
	var SaveManager = load("res://src/core/save_manager.gd")
	SaveManager.suppress_auto_save = true
	await get_tree().process_frame
	GameState.reset_to_new_game()
	var w = load("res://src/scenes/world.tscn").instantiate()
	add_child(w)
	await get_tree().create_timer(0.4).timeout
	var hud = w.hud
	var sim = GameState.sim
	var vp_size = get_viewport().get_visible_rect().size
	var center = vp_size / 2

	# --- 1. 滚轮 ---
	_check(_wheel(w, center) > 1.0, "地图上滚动滚轮会缩放")
	for m in [hud.lab_modal, hud.tech_modal, hud.inventory_modal, hud.periodic_modal, hud.settings_modal]:
		m.open()
		await get_tree().process_frame
		_check(_wheel(w, center) == 1.0 and _wheel(w, Vector2(20, center.y)) == 1.0, "%s 打开时滚动不缩放地图" % m.name)
		ModalStack.close_top()
		await get_tree().process_frame
	hud._toggle_category(hud.CategoryTab.CRAFT)
	await get_tree().process_frame
	await get_tree().process_frame
	var drawer_rect: Rect2 = hud.action_drawer.get_global_rect()
	_check(_wheel(w, drawer_rect.get_center()) == 1.0, "在制作抽屉上滚动不缩放地图")
	_check(_wheel(w, Vector2(center.x, drawer_rect.position.y - 40)) > 1.0, "抽屉打开时，在抽屉外的地图上滚动仍会缩放")
	var top_rect: Rect2 = hud.get_node("Margin/MainVBox/TopBarPanel").get_global_rect()
	_check(_wheel(w, top_rect.get_center()) == 1.0, "在顶栏上滚动不缩放地图")

	# --- 2. 制作抽屉 ---
	var scroll: ScrollContainer = hud.drawer_grid.get_parent()
	_check(hud.drawer_grid is HFlowContainer, "制作抽屉卡片自动换行")
	_check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "制作抽屉没有横向滚动")
	var max_era_shown := 0
	var first_disabled := -1
	var last_enabled := -1
	for i in range(hud._card_used):
		var c: Button = hud._card_pool[i]
		if c.disabled and first_disabled < 0: first_disabled = i
		if not c.disabled: last_enabled = i
	for key in hud.drawer_card_by_key.keys():
		max_era_shown = maxi(max_era_shown, int(DataDB.get_crafting_recipe(key).get("era", 0)))
	_check(max_era_shown == 0, "石器时代只列出石器时代的配方")
	_check(hud._drawer_footer.text.contains("后续时代"), "抽屉底部说明还有配方在后续时代解锁")
	_check(scroll.custom_minimum_size.y <= 3 * hud.CARD_SIZE.y + 20 + 1, "抽屉最多 3 行高")
	GameState.inventory.add_item("stick", 2)
	GameState.inventory.add_item("flint", 2)
	await get_tree().process_frame
	await get_tree().process_frame
	first_disabled = -1
	last_enabled = -1
	for i in range(hud._card_used):
		var c: Button = hud._card_pool[i]
		if c.disabled and first_disabled < 0: first_disabled = i
		if not c.disabled: last_enabled = i
	_check(last_enabled >= 0 and (first_disabled < 0 or last_enabled < first_disabled), "能制作的配方排在前面")
	hud._filter_buttons["容器"].emit_signal("pressed")
	await get_tree().process_frame
	var only_containers := true
	for key in hud.drawer_card_by_key.keys():
		if hud._recipe_category(DataDB.get_crafting_recipe(key)) != "容器": only_containers = false
	_check(only_containers, "「容器」筛选只显示容器")
	hud._filter_buttons["all"].emit_signal("pressed")
	hud._only_available_btn.button_pressed = true
	await get_tree().process_frame
	var all_ok: bool = hud._card_used > 0
	for i in range(hud._card_used):
		if hud._card_pool[i].disabled: all_ok = false
	_check(all_ok, "「只看能制作的」只显示可制作的配方")
	hud._only_available_btn.button_pressed = false
	hud._close_drawer()

	# --- 3. 顶栏：装备与元素 ---
	_check(hud._tool_labels["axe"].text == "徒手" and hud._tool_labels["pickaxe"].text == "徒手", "开局顶栏显示斧、镐均为徒手")
	GameState.craft_tool("flint_axe")
	await get_tree().process_frame
	_check(hud._tool_labels["axe"].text == "原始燧石手斧" and hud._tool_icons["axe"].modulate.a == 1.0, "装备斧头后顶栏显示斧头名称：%s" % hud._tool_labels["axe"].text)
	_check(hud._element_btn.text == "元素 0/118", "顶栏显示已发现元素 0/118")
	GameState.unlock_element(29, "copper")
	await get_tree().process_frame
	_check(hud._element_btn.text == "元素 1/118" and hud._element_btn.tooltip_text.contains("Cu"), "发现铜后顶栏更新为 1/118，悬停列出 Cu")
	while ModalStack.close_top(): pass
	hud._element_btn.emit_signal("pressed")
	await get_tree().process_frame
	_check(hud.periodic_modal.visible, "点击元素按钮打开周期表")
	while ModalStack.close_top(): pass
	await get_tree().process_frame

	# --- 4. 树苗 ---
	var inv = GameState.inventory
	var tree_hex := Vector2i(9999, 9999)
	for h in GameState.tile_resources.keys():
		if GameState.is_hex_in_territory(h.x, h.y) and int(GameState.tile_resources[h].get("wood", 0)) > 0:
			tree_hex = h
			break
	_check(tree_hex != Vector2i(9999, 9999), "领地内有树木")
	# 砍到只剩最后一根，再砍一次必定得到树苗
	var left = int(GameState.tile_resources[tree_hex]["wood"])
	GameState.consume_tile_resource(tree_hex, "wood", left - 1)
	var before = inv.get_count("sapling")
	var queued = GameState.queue_hex_harvest(tree_hex, "wood", 1, Vector2.ZERO)
	GameState.active_task["begin_time"] = Time.get_ticks_msec() - 60000
	GameState.sim.tick(0.01)
	_check(inv.get_count("sapling") == before + 1, "砍下地块最后一根原木必定得到 1 棵橡树苗")
	# 开局中心 (0,0) 没有资源，可以种树
	var plant_hex := Vector2i(0, 0)
	_check(sim.can_plant_sapling(plant_hex), "领地内的空地可以种树")
	var lake_hex := Vector2i(9999, 9999)
	for h in GameState.world_biomes.keys():
		if sim.is_water_hex(h) and GameState.is_hex_in_territory(h.x, h.y):
			lake_hex = h
			break
	if lake_hex != Vector2i(9999, 9999):
		_check(not sim.can_plant_sapling(lake_hex), "湖面不能种树")
	_check(not sim.can_plant_sapling(Vector2i(30, 0)), "领地外不能种树")
	_check(sim.queue_plant_sapling(plant_hex), "下发种树作业")
	_check(not sim.queue_plant_sapling(plant_hex), "同一地块不能重复下发种树")
	GameState.active_task["begin_time"] = Time.get_ticks_msec() - 60000
	sim.tick(0.01)
	_check(sim.saplings.has(plant_hex) and inv.get_count("sapling") == before, "种树作业完成：消耗 1 棵树苗，地块开始生长")
	await get_tree().process_frame
	var node = w.resource_nodes.get(plant_hex)
	_check(node != null and node.visible and node.item_key == "sapling", "地图上画出树苗")
	_check(not sim.can_dig_mud(plant_hex) and not w.is_valid_build_hex(plant_hex), "树苗地块不能挖泥土、不能建造")
	_check(sim.get_tile_tool_hint(plant_hex).contains("生长"), "点击树苗提示正在生长")

	# 存档 → 重新读档，生长进度保留
	sim.saplings[plant_hex] = 50.0
	_check(SaveManager.save_to_slot("test_world_ui_slot", w), "种着树苗时可以存档")
	sim.saplings.clear()
	SaveManager.load_from_slot("test_world_ui_slot", w, true)
	await get_tree().process_frame
	_check(absf(float(sim.saplings.get(plant_hex, -1.0)) - 50.0) < 0.01, "读档后树苗剩余生长时间恢复")
	node = w.resource_nodes.get(plant_hex)
	_check(node != null and node.visible and node.item_key == "sapling", "读档后地图上仍画出树苗")

	# 长成
	for i in range(51):
		sim._on_second_tick()
	await get_tree().process_frame
	_check(not sim.saplings.has(plant_hex) and int(GameState.tile_resources[plant_hex].get("wood", 0)) == sim.GROWN_TREE_RESOURCES["wood"], "树苗长成后地块有 %d 根原木" % sim.GROWN_TREE_RESOURCES["wood"])
	node = w.resource_nodes.get(plant_hex)
	_check(node != null and node.visible and node.item_key == "wood", "长成后地图上画出橡树（已装备斧头）")
	var avail = GameState.get_tile_available_resources(plant_hex)
	_check(not avail.is_empty() and avail[0]["key"] == "wood", "长成的树可以砍伐")
	# 长成的树在读档后仍在 (开局中心原本没有主资源)
	SaveManager.save_to_slot("test_world_ui_slot", w)
	SaveManager.load_from_slot("test_world_ui_slot", w, true)
	await get_tree().process_frame
	node = w.resource_nodes.get(plant_hex)
	_check(node != null and node.visible and node.item_key == "wood", "读档后种出的树仍在")
	# 普通林地读档后仍先画橡树 (JSON 按键名排序后 stick 在 wood 前)
	var forest_ok := true
	for h in GameState.tile_resources.keys():
		if GameState.world_resources.get(h, "") == "wood" and int(GameState.tile_resources[h].get("wood", 0)) > 0 and GameState.is_hex_in_territory(h.x, h.y):
			var n = w.resource_nodes.get(h)
			if n == null or n.item_key != "wood": forest_ok = false
	_check(forest_ok, "读档后装备斧头时所有林地都画橡树、左键砍原木")
	SaveManager.delete_slot("test_world_ui_slot")

	w.queue_free()
	if _failed == 0:
		print("🎉 地图与界面测试全部通过")
		get_tree().quit(0)
	else:
		printerr("❌ %d 项失败" % _failed)
		get_tree().quit(1)
