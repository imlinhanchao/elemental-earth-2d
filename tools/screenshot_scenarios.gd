# tools/screenshot_scenarios.gd
# 开发工具：无头实机截图场景。用法：Godot --path . ++ --screenshot[-场景名]
# 由 world.gd 在检测到 --screenshot 参数时调用；正式游玩不会加载此脚本的逻辑。
extends RefCounted

static func run(w: Node2D, arg_name: String) -> void:
	load("res://src/core/save_manager.gd").suppress_auto_save = true # 截图场景不写玩家的自动存档
	await w.get_tree().create_timer(1.2).timeout
	if w.hud.era_modal.visible:
		w.hud.era_modal.visible = false
		
	if arg_name == "--screenshot-inv":
		GameState.inventory.add_item("bark", 15)
		w.hud.inventory_modal.open()
		await w.get_tree().create_timer(0.2).timeout
		w.get_viewport().warp_mouse(Vector2(480, 320))
		var item_data = DataDB.get_item("bark")
		w.hud.inventory_modal._show_tooltip_for_item("bark", item_data, 15)
	elif arg_name == "--screenshot-milestone":
		GameState.current_era = 0
		GameState.discovered_elements = [6]
		GameState.completed_milestones = []
		w.hud._update_era_label()
		await w.get_tree().create_timer(0.1).timeout
		GameState.complete_milestone("craft_stone_pickaxe")
		if w.hud.element_discovery_modal:
			w.hud.element_discovery_modal.close()
		w.hud.era_modal.show_current_era_status()
		await w.get_tree().create_timer(0.4).timeout
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.0, 1.0)
		w.target_zoom = Vector2(1.0, 1.0)
		w.camera.reset_smoothing()
	elif arg_name == "--screenshot-element-discovery":
		GameState.unlock_element(29, "copper")
		await w.get_tree().create_timer(0.4).timeout
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.0, 1.0)
		w.target_zoom = Vector2(1.0, 1.0)
		w.camera.reset_smoothing()
	elif arg_name == "--screenshot-craft":
		w.hud._toggle_category(w.hud.CategoryTab.CRAFT)
	elif arg_name == "--screenshot-lab":
		# 焙烧孔雀石：放入木炭点火，侦测卡提示温度 (先登记碳，避免弹出元素发现弹窗)
		GameState.sim.discovered_elements.append(6)
		GameState.sim.current_era = 2
		GameState.sim.researched_techs.append("gas_collection")
		for k in ["wood", "charcoal", "malachite", "flint", "stone", "stick", "gas_bottle", "clay_pot"]:
			GameState.inventory.add_item(k, 5)
		GameState.lab.fragments.append("copper_smelting")
		GameState.lab.set_operation("roasting")
		GameState.lab.toggle_chain("gas_collecting_air")
		w.hud.lab_modal.open()
		w.hud.lab_modal.add_reagent("malachite", 1.0)
		w.hud.lab_modal.add_reagent("charcoal", 1.0)
		GameState.lab.add_fuel("charcoal")
		GameState.lab.ignite()
		w.hud.lab_modal._refresh_all()
	elif arg_name == "--screenshot-codex":
		GameState.lab.seen_items["wood"] = true
		GameState.lab.fragments.append("copper_smelting")
		GameState.lab.fragments.append("iron_smelting")
		w.hud.lab_modal.open()
		w.hud.lab_modal._switch_tab(1)
	elif arg_name == "--screenshot-tutorial-craft":
		GameState.inventory.add_item("stone", 2)
		GameState.inventory.add_item("stick", 2)
		GameState.inventory.add_item("flint", 2)
		GameState.start_tutorial()
		GameState.set_tutorial_step(2)
		w.hud.tutorial_dock.visible = true
		w.hud._toggle_category(w.hud.CategoryTab.CRAFT)
	elif arg_name == "--screenshot-tutorial":
		GameState.start_tutorial()
		w.hud.tutorial_dock.visible = true
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.0, 1.0)
		w.target_zoom = Vector2(1.0, 1.0)
		w.camera.reset_smoothing()
		w.terrain_layer.refresh()
	elif arg_name == "--screenshot-campfire":
		GameState.inventory.add_item("wood", 10)
		GameState.inventory.add_item("stone", 10)
		GameState.build_structure("fire_pit", Vector2i(0, 0))
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.5, 1.5)
		w.target_zoom = Vector2(1.5, 1.5)
		w.camera.reset_smoothing()
		w.terrain_layer.refresh()
	elif arg_name == "--screenshot-placement":
		GameState.inventory.add_item("wood", 10)
		GameState.inventory.add_item("stone", 10)
		w.enter_placement_mode("fire_pit")
		w.hovered_hex = Vector2i(1, 0)
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.3, 1.3)
		w.target_zoom = Vector2(1.3, 1.3)
		w.camera.reset_smoothing()
		w.terrain_layer.refresh()
		w.overlay_layer.queue_redraw()
	elif arg_name == "--screenshot-task-complete":
		for h in GameState.world_resources.keys():
			if GameState.is_hex_in_territory(h.x, h.y) and GameState.world_resources[h] == "stone":
				GameState.queue_hex_harvest(h, "stone", 1, Vector2.ZERO)
				break
		# 等待 1.6 秒确保 1.0 秒的任务真实完成并从队列移除
		await w.get_tree().create_timer(1.6).timeout
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.3, 1.3)
		w.target_zoom = Vector2(1.3, 1.3)
		w.camera.reset_smoothing()
		w.terrain_layer.refresh()
		w.overlay_layer.queue_redraw()
	elif arg_name == "--screenshot-hud":
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.0, 1.0)
		w.target_zoom = Vector2(1.0, 1.0)
		w.camera.reset_smoothing()
		w.terrain_layer.refresh()
	elif arg_name == "--screenshot-era-modal":
		w.hud.era_modal.show_current_era_status()
	elif arg_name == "--screenshot-context-menu":
		var test_hex = Vector2i(1, 0)
		var test_screen_pos = Vector2(850, 420)
		var res_list = [
			{"key": "wood", "name": "原木", "amount": 120},
			{"key": "stick", "name": "枯树枝", "amount": 30}
		]
		w.tile_context_menu.open_at(test_screen_pos, test_hex, res_list)
	elif arg_name == "--screenshot-context-menu-count":
		var test_hex = Vector2i(1, 0)
		var test_screen_pos = Vector2(850, 420)
		var res_info = {"key": "wood", "name": "原木", "amount": 120}
		w.tile_context_menu.open_at(test_screen_pos, test_hex, [res_info])
	elif arg_name == "--screenshot-repeat-task":
		for h in GameState.world_resources.keys():
			if GameState.is_hex_in_territory(h.x, h.y) and GameState.world_resources[h] == "wood":
				GameState.queue_hex_harvest(h, "wood", 20, Vector2.ZERO)
				GameState.queue_hex_harvest(h, "wood", 10, Vector2.ZERO)
				break
		for h in GameState.world_resources.keys():
			if GameState.is_hex_in_territory(h.x, h.y) and GameState.world_resources[h] in ["stone", "flint"]:
				GameState.queue_hex_harvest(h, GameState.world_resources[h], -1, Vector2.ZERO)
				break
	elif arg_name == "--screenshot-hud-queue":
		GameState.queue_hex_forage(Vector2i(0, 0), "生机原野", 1, Vector2.ZERO)
		GameState.queue_hex_forage(Vector2i(1, 0), "生机原野", 1, Vector2.ZERO)
	else:
		w.hud.tech_modal.open()
		
	await w.get_tree().create_timer(0.6).timeout
	var img = w.get_viewport().get_texture().get_image()
	if img:
		var out_path = ProjectSettings.globalize_path("res://screenshot_current.png")
		img.save_png(out_path)
		print("[Screenshot] 实机渲染截图成功生成: %s" % out_path)
	w.get_tree().quit(0)
