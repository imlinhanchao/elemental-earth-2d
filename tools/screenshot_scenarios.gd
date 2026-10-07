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
		# 顶栏装备与元素、制作抽屉 (可制作的排在前面)、开局中心种着一棵树苗
		for k in ["stick", "flint", "stone", "wood"]:
			GameState.inventory.add_item(k, 6)
		GameState.inventory.add_item("sapling", 2)
		GameState.craft_tool("flint_axe")
		GameState.sim.discovered_elements.append(6)
		GameState.element_discovered.emit(6, "charcoal")
		if w.hud.element_discovery_modal: w.hud.element_discovery_modal.close()
		GameState.sim.queue_plant_sapling(Vector2i(0, 0))
		GameState.active_task["begin_time"] = Time.get_ticks_msec() - 60000
		GameState.sim.tick(0.01)
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.3, 1.3)
		w.camera.reset_smoothing()
		await w.get_tree().create_timer(0.2).timeout
		w.hud._toggle_category(w.hud.CategoryTab.CRAFT)
	elif arg_name == "--screenshot-lab":
		# 焙烧孔雀石：放入木炭点火，侦测卡提示温度 (先登记碳，避免弹出元素发现弹窗)
		GameState.sim.discovered_elements.append(6)
		GameState.sim.current_era = 2
		GameState.sim.researched_techs.append("gas_collection")
		for k in ["wood", "charcoal", "malachite", "flint", "stone", "stick", "gas_bottle", "clay_pot", "crucible", "wooden_bucket"]:
			GameState.inventory.add_item(k, 5)
		GameState.inventory.wear["crucible"] = 6
		GameState.lab.set_container("crucible")
		GameState.lab.fragments.append("copper_smelting")
		GameState.lab.set_operation("roasting")
		GameState.lab.toggle_chain("gas_collecting_air")
		w.hud.lab_modal.open()
		w.hud.lab_modal.add_reagent("malachite", 1.0)
		w.hud.lab_modal.add_reagent("charcoal", 1.0)
		GameState.lab.add_fuel("charcoal")
		GameState.lab.ignite()
		w.hud.lab_modal._refresh_all()
	elif arg_name == "--screenshot-lab-gallery":
		# 所有容器的简笔图拼成一张图：每格为实验装置区域，放入少量试剂显示液面
		var lab_modal = w.hud.lab_modal
		var keys: Array = ["", "wooden_bucket", "clay_pot", "crucible", "kiln", "gas_bottle", "beaker", "test_tube", "iron_tank",
			"distilling_flask", "evaporating_dish", "sealed_tube", "reaction_kettle", "autoclave", "graphite_electrolytic_cell",
			"fractionating_column", "sieve", "blast_furnace", "reactor_vessel"]
		for k in keys:
			if k != "":
				GameState.inventory.add_item(k, 1)
		GameState.inventory.add_item("water", 50)
		lab_modal.open()
		var sheet: Image = null
		var cols := 5
		for i in range(keys.size()):
			lab_modal.lab.retrieve_all()
			lab_modal.lab.set_container(keys[i])
			if keys[i] != "":
				lab_modal.lab.add_reagent("water", 3)
			lab_modal._refresh_all()
			await w.get_tree().create_timer(0.15).timeout
			var img = w.get_viewport().get_texture().get_image()
			# 画布按窗口拉伸，换算到截图像素
			var scale = Vector2(img.get_size()) / w.get_viewport().get_visible_rect().size
			var r = lab_modal.vessel_draw.get_global_rect()
			var cell = img.get_region(Rect2i(Vector2i(r.position * scale), Vector2i(r.size * scale)))
			if sheet == null:
				sheet = Image.create(cell.get_width() * cols, cell.get_height() * int(ceil(keys.size() / float(cols))), false, cell.get_format())
				sheet.fill(Color.WHITE)
			sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i((i % cols) * cell.get_width(), (i / cols) * cell.get_height()))
		sheet.save_png(ProjectSettings.globalize_path("res://screenshot_lab_gallery.png"))
		print("[Screenshot] lab gallery saved")
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
	elif arg_name == "--screenshot-furnace":
		# 点击地图上的鼓风高炉：炉体模式实验台，焙烧赤铁矿 (走 world 的地块点击分发)
		GameState.sim.discovered_elements.append(6)
		GameState.sim.discovered_elements.append(26)
		GameState.sim.discovered_elements.append(29)
		GameState.current_era = 1
		for k in ["wood", "stone"]:
			GameState.inventory.add_item(k, 20)
		GameState.inventory.add_item("copper", 4)
		GameState.inventory.add_item("charcoal", 10)
		GameState.inventory.add_item("hematite", 6)
		GameState.inventory.add_item("flint", 3)
		var fh = Vector2i(1, 0)
		GameState.build_structure("blast_furnace", fh)
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.3, 1.3)
		w.camera.reset_smoothing()
		w._handle_tile_click(fh)
		var fb = GameState.get_furnace_bench(fh)
		w.hud.lab_modal._on_op_pressed("roasting")
		w.hud.lab_modal.add_reagent("hematite", 2.0)
		w.hud.lab_modal.add_reagent("charcoal", 2.0)
		fb.add_fuel("charcoal")
		fb.add_fuel("charcoal")
		w.hud.lab_modal._on_fire_pressed()
		w.hud.lab_modal._refresh_all()
		await w.get_tree().create_timer(3.0).timeout
	elif arg_name == "--screenshot-reactor":
		GameState.current_era = 2
		GameState.sim.discovered_elements.append_array([6, 29])
		for k in ["wood", "copper"]:
			GameState.inventory.add_item(k, 20)
		GameState.sim.lab.on_reaction({"formula_key": "charcoal_production", "products": []})
		GameState.build_structure("industrial_reactor", Vector2i(1, 0))
		GameState.reactor_install_blueprint(Vector2i(1, 0), "charcoal_production")
		w.camera.position = Vector2.ZERO
		w.camera.zoom = Vector2(1.3, 1.3)
		w.camera.reset_smoothing()
		w._handle_tile_click(Vector2i(1, 0))
		await w.get_tree().create_timer(2.2).timeout
	elif arg_name == "--screenshot-periodic":
		# 元素图鉴：周期表布局，点亮几种不同族的元素，高亮铜
		GameState.sim.discovered_elements.append_array([1, 6, 8, 11, 16, 17, 18, 20, 26, 29, 50, 57, 92])
		w.hud.periodic_modal.open(29)
	elif arg_name == "--screenshot-periodic-story":
		GameState.sim.discovered_elements.append_array([1, 6, 8, 11, 16, 17, 18, 20, 26, 29, 50, 57, 92])
		w.hud.periodic_modal.open()
		await w.get_tree().process_frame
		w.hud.periodic_modal.show_element(29)
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
	elif arg_name == "--screenshot-newgame":
		# 新游戏随机地图，装备斧头后显示开局领地内的树木
		GameState.reset_to_new_game()
		w.reset_world_state()
		GameState.equipped_tools["axe"] = "flint_axe"
		GameState.tool_equipped.emit("flint_axe")
		w.camera.zoom = Vector2(0.8, 0.8)
		w.target_zoom = w.camera.zoom
		w.camera.reset_smoothing()
		w.terrain_layer.refresh()
		print("[Screenshot] seed=%d" % GameState.sim.world_seed)
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
