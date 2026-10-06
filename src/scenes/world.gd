# world.gd
# 2D 开放大世界总场景: 鼠标上帝视角控制、时代领地疆域系统、自动存档与工业连续流
extends Node2D

const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")
const ResourceNodeScene = preload("res://src/scenes/resource_node.tscn")
const FurnaceScene = preload("res://src/scenes/furnace.tscn")
const IndustrialReactorScene = preload("res://src/scenes/industrial_reactor.tscn")
const TileContextMenuScene = preload("res://src/ui/tile_context_menu.tscn")
const SaveManager = preload("res://src/core/save_manager.gd")
const SettingsManager = preload("res://src/core/settings_manager.gd")

@onready var terrain_layer = $TerrainLayer
@onready var entities = $Entities
@onready var overlay_layer = $OverlayLayer
@onready var camera = $WorldCamera
@onready var hud = $HUD

var hex_gen: HexWorldGenerator
var generated_hexes: Dictionary = {} # Vector2i(q, r) -> BiomeType
var hovered_hex: Vector2i = Vector2i(9999, 9999)

# 区块开采上下文菜单
var tile_context_menu: PanelContainer
var right_click_down_pos: Vector2 = Vector2.ZERO

# 建筑实例列表 (用于全量持久化存档)
var built_furnaces: Array[Node2D] = []
var built_reactors: Array[Node2D] = []

# 设施建造选址模式交互状态
var is_placing_structure: bool = false
var placing_structure_key: String = ""

# 自动存档计时器
var auto_save_timer: float = 0.0

# 摄像机控制状态
var is_dragging_camera: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_cam_pos: Vector2 = Vector2.ZERO
var camera_speed: float = 650.0
var target_zoom: Vector2 = Vector2.ONE

# 六边形世界边界范围 (-20 到 20 圈)
const WORLD_HEX_RADIUS: int = 18

# hex -> ResourceNode 索引：替代每个节点各自监听全局信号 / 每帧轮询
var resource_nodes: Dictionary = {}
var _hovered_node: Node2D = null

func _ready() -> void:
	add_to_group("world")
	terrain_layer.world = self
	overlay_layer.world = self
	
	tile_context_menu = TileContextMenuScene.instantiate()
	hud.add_child(tile_context_menu)
	tile_context_menu.harvest_requested.connect(_on_context_menu_harvest)

	GameState.structure_built.connect(_on_structure_built)
	GameState.tile_depleted.connect(func(hex):
		var n = resource_nodes.get(hex)
		if is_instance_valid(n): n.harvest_complete()
	)
	GameState.tile_respawned.connect(func(hex):
		var n = resource_nodes.get(hex)
		if is_instance_valid(n): n.on_respawned()
	)
	_generate_hex_world()
	
	hud.build_structure_requested.connect(_on_build_structure_requested)
	hud.build_furnace_requested.connect(func(): _on_build_structure_requested("furnace"))
	hud.build_reactor_requested.connect(func(): _on_build_structure_requested("industrial_reactor"))
	hud.cancel_placement_requested.connect(cancel_placement_mode)
	
	hud.save_requested.connect(func(): SaveManager.save_to_slot("slot_1", self))
	hud.load_requested.connect(func(): SaveManager.load_from_slot("slot_1", self))
	hud.reset_requested.connect(func():
		GameState.reset_to_new_game()
		reset_world_state()
	)
	
	GameState.task_progress_updated.connect(func(_t, _p, _r): overlay_layer.queue_redraw())
	GameState.task_queue_changed.connect(func(): overlay_layer.queue_redraw())
	
	# 工具装配与时代演进时，实时刷新大世界地表可开采资源显示状态
	GameState.tool_equipped.connect(func(_tool_key):
		apply_depleted_tiles_to_nodes()
		overlay_layer.queue_redraw()
	)
	
	GameState.era_advanced.connect(func(_old, _new, era_name):
		apply_depleted_tiles_to_nodes()
		terrain_layer.queue_redraw()
		overlay_layer.queue_redraw()
		GameState.post_notice("【领地疆域扩展】随着迈向【%s】，文明疆域拓展至半径 %d 格！" % [era_name, GameState.get_current_territory_radius()], Color(1.0, 0.85, 0.2))
		SaveManager.save_to_slot("auto", self)
	)
	
	# 如果有待载入的槽位 (例如从主菜单选中的)
	if SaveManager.pending_load_slot != "":
		var target = SaveManager.pending_load_slot
		SaveManager.pending_load_slot = ""
		SaveManager.load_from_slot(target, self)
		hud._update_era_label()
	elif not GameState.is_tutorial_active and SaveManager.has_any_save() and GameState.inventory.items.is_empty() and GameState.current_era == 0 and GameState.discovered_elements.is_empty():
		var latest = SaveManager.get_latest_save_slot()
		if latest != "":
			SaveManager.load_from_slot(latest, self)
			hud._update_era_label()
	else:
		GameState.post_notice("[开局引导] 鼠标点击地表【碎石】、【枯树枝】加入工作队列！点击盐湖打水！右键拖拽视野！", Color(1.0, 0.88, 0.4))
	
	# 如果携带 --screenshot 参数，则在指定延时后截取对应画面并退出
	var all_args = OS.get_cmdline_user_args() + OS.get_cmdline_args()
	print("[Screenshot Debug] all_args = ", all_args)
	for arg in all_args:
		if arg.contains("screenshot"):
			_capture_screenshot_after_delay(arg)
			break

func _capture_screenshot_after_delay(arg_name: String) -> void:
	await get_tree().create_timer(1.2).timeout
	if hud.era_modal.visible:
		hud.era_modal.visible = false
		
	if arg_name == "--screenshot-inv":
		GameState.inventory.add_item("bark", 15)
		hud.inventory_modal.open()
		await get_tree().create_timer(0.2).timeout
		get_viewport().warp_mouse(Vector2(480, 320))
		var item_data = DataDB.get_item("bark")
		hud.inventory_modal._show_tooltip_for_item("bark", item_data, 15)
	elif arg_name == "--screenshot-milestone":
		GameState.current_era = 0
		GameState.discovered_elements = [6]
		GameState.completed_milestones = []
		hud._update_era_label()
		await get_tree().create_timer(0.1).timeout
		GameState.complete_milestone("craft_stone_pickaxe")
		if hud.element_discovery_modal:
			hud.element_discovery_modal.close()
		hud.era_modal.show_current_era_status()
		await get_tree().create_timer(0.4).timeout
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(1.0, 1.0)
		target_zoom = Vector2(1.0, 1.0)
		camera.reset_smoothing()
	elif arg_name == "--screenshot-element-discovery":
		GameState.unlock_element(29, "copper")
		await get_tree().create_timer(0.4).timeout
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(1.0, 1.0)
		target_zoom = Vector2(1.0, 1.0)
		camera.reset_smoothing()
	elif arg_name == "--screenshot-craft":
		hud._toggle_category(hud.CategoryTab.CRAFT)
	elif arg_name == "--screenshot-lab":
		GameState.inventory.add_item("wood", 5)
		hud.lab_modal.open()
		hud.lab_modal.add_reagent("wood", 1.0)
	elif arg_name == "--screenshot-codex":
		hud.lab_modal.open()
		hud.lab_modal._switch_tab(1)
	elif arg_name == "--screenshot-tutorial":
		GameState.start_tutorial()
		hud.tutorial_dock.visible = true
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(1.0, 1.0)
		target_zoom = Vector2(1.0, 1.0)
		camera.reset_smoothing()
		terrain_layer.queue_redraw()
	elif arg_name == "--screenshot-campfire":
		GameState.inventory.add_item("wood", 10)
		GameState.inventory.add_item("stone", 10)
		GameState.build_structure("fire_pit", Vector2i(0, 0))
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(1.5, 1.5)
		target_zoom = Vector2(1.5, 1.5)
		camera.reset_smoothing()
		terrain_layer.queue_redraw()
	elif arg_name == "--screenshot-placement":
		GameState.inventory.add_item("wood", 10)
		GameState.inventory.add_item("stone", 10)
		enter_placement_mode("fire_pit")
		hovered_hex = Vector2i(1, 0)
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(1.3, 1.3)
		target_zoom = Vector2(1.3, 1.3)
		camera.reset_smoothing()
		terrain_layer.queue_redraw()
		overlay_layer.queue_redraw()
	elif arg_name == "--screenshot-task-complete":
		for h in GameState.world_resources.keys():
			if GameState.is_hex_in_territory(h.x, h.y) and GameState.world_resources[h] == "stone":
				GameState.queue_hex_harvest(h, "stone", 1, Vector2.ZERO)
				break
		# 等待 1.6 秒确保 1.0 秒的任务真实完成并从队列移除
		await get_tree().create_timer(1.6).timeout
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(1.3, 1.3)
		target_zoom = Vector2(1.3, 1.3)
		camera.reset_smoothing()
		terrain_layer.queue_redraw()
		overlay_layer.queue_redraw()
	elif arg_name == "--screenshot-hud":
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(1.0, 1.0)
		target_zoom = Vector2(1.0, 1.0)
		camera.reset_smoothing()
		terrain_layer.queue_redraw()
	elif arg_name == "--screenshot-era-modal":
		hud.era_modal.show_current_era_status()
	elif arg_name == "--screenshot-context-menu":
		var test_hex = Vector2i(1, 0)
		var test_screen_pos = Vector2(850, 420)
		var res_list = [
			{"key": "wood", "name": "原木", "amount": 120},
			{"key": "stick", "name": "枯树枝", "amount": 30}
		]
		tile_context_menu.open_at(test_screen_pos, test_hex, res_list)
	elif arg_name == "--screenshot-context-menu-count":
		var test_hex = Vector2i(1, 0)
		var test_screen_pos = Vector2(850, 420)
		var res_info = {"key": "wood", "name": "原木", "amount": 120}
		tile_context_menu.open_at(test_screen_pos, test_hex, [res_info])
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
		hud.tech_modal.open()
		
	await get_tree().create_timer(0.6).timeout
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("/Users/hancel/Documents/project/elemental-earth-2d/screenshot_current.png")
		print("[Screenshot] 实机渲染截图成功生成: /Users/hancel/Documents/project/elemental-earth-2d/screenshot_current.png")
	get_tree().quit(0)

func _generate_hex_world() -> void:
	hex_gen = GameState.sim.hex_gen
	generated_hexes = GameState.world_biomes.duplicate()
	for coord in GameState.world_resources.keys():
		var item_key = GameState.world_resources[coord]
		_spawn_resource_at_hex(coord.x, coord.y, item_key)
	terrain_layer.queue_redraw()
	overlay_layer.queue_redraw()

func _spawn_resource_at_hex(q: int, r: int, item_key: String) -> void:
	var pos = HexWorldGenerator.hex_to_pixel(q, r)
	var node = ResourceNodeScene.instantiate()
	node.position = pos
	node.item_key = item_key
	node.hex_coord = Vector2i(q, r)
	
	var iname = DataDB.get_item(item_key).get("name", item_key)
	node.item_name = iname
	var in_terr = GameState.is_hex_in_territory(q, r)
	var depleted = GameState.depleted_tiles.has(Vector2i(q, r))
	var minable = GameState.sim.is_resource_minable(item_key)
	node.visible = in_terr and not depleted and minable
	entities.add_child(node)
	resource_nodes[Vector2i(q, r)] = node

func _on_context_menu_harvest(hex: Vector2i, item_key: String, count: int) -> void:
	var world_p = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
	GameState.queue_hex_harvest(hex, item_key, count, world_p)

func _unhandled_input(event: InputEvent) -> void:
	# ESC 按键取消建造选址模式
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and is_placing_structure:
			cancel_placement_mode()
			get_viewport().set_input_as_handled()
			return

	# 鼠标右键或中键拖拽地图；右键单点呼出开采次数菜单或取消建造
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging_camera = true
				drag_start_mouse = event.position
				drag_start_cam_pos = camera.position
				right_click_down_pos = event.position
			else:
				is_dragging_camera = false
				# 若右键按下与抬起位移小于 6px，判定为单点右键
				if (event.position - right_click_down_pos).length() < 6.0:
					if is_placing_structure:
						cancel_placement_mode()
					else:
						_handle_tile_right_click(hovered_hex, event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging_camera = event.pressed
			drag_start_mouse = event.position
			drag_start_cam_pos = camera.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# 直接应用缩放，消除弹性与顿挫
			camera.zoom = (camera.zoom * 1.15).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
			target_zoom = camera.zoom
			_update_terrain_lod()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# 直接应用缩放，消除弹性与顿挫
			camera.zoom = (camera.zoom * 0.85).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
			target_zoom = camera.zoom
			_update_terrain_lod()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_placing_structure:
				confirm_placement(hovered_hex)
			else:
				_handle_tile_click(hovered_hex)
	
	elif event is InputEventMouseMotion:
		if is_dragging_camera:
			camera.position = _clamp_camera(drag_start_cam_pos - (event.position - drag_start_mouse) / camera.zoom)
		
		# 转换鼠标世界坐标到六边形网格坐标
		var mpos = camera.get_global_mouse_position()
		var hex = HexWorldGenerator.pixel_to_hex(mpos)
		if hex != hovered_hex:
			hovered_hex = hex
			overlay_layer.queue_redraw()
			if is_instance_valid(_hovered_node): _hovered_node.set_hovered(false)
			_hovered_node = resource_nodes.get(hex)
			if is_instance_valid(_hovered_node) and _hovered_node.visible: _hovered_node.set_hovered(true)
			if hud and generated_hexes.has(hovered_hex):
				hud.update_current_biome(generated_hexes[hovered_hex])

# 地形只在 LOD 阈值被跨越时重绘一次；镜头移动/缩放本身不触发重绘
func _update_terrain_lod() -> void:
	var new_lod = 1 if camera.zoom.x >= 0.85 else 0
	if terrain_layer and terrain_layer.current_lod != new_lod:
		terrain_layer.current_lod = new_lod
		terrain_layer.queue_redraw()

# 镜头可达范围限制在地形预绘制区域内 (见 terrain_layer.DRAW_HEX_RADIUS)
const CAMERA_LIMIT: float = 1500.0
func _clamp_camera(pos: Vector2) -> Vector2:
	return pos.clamp(Vector2(-CAMERA_LIMIT, -CAMERA_LIMIT), Vector2(CAMERA_LIMIT, CAMERA_LIMIT))

func _handle_tile_click(hex: Vector2i) -> void:
	if not GameState.is_hex_in_territory(hex.x, hex.y):
		GameState.post_notice("此区域超出当前文明领地边界！", Color(1.0, 0.45, 0.3))
		return
		
	var available = GameState.get_tile_available_resources(hex)
	if available.is_empty():
		GameState.post_notice("该区块无可开采的资源储备（已采尽）！", Color.GRAY)
		return
		
	# 点击一下只开采一下主要资源
	var target_key = available[0].get("key", "")
	var world_p = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
	GameState.queue_hex_harvest(hex, target_key, 1, world_p)

func _handle_tile_right_click(hex: Vector2i, screen_pos: Vector2) -> void:
	if not GameState.is_hex_in_territory(hex.x, hex.y):
		GameState.post_notice("此区域超出当前文明领地边界！", Color(1.0, 0.45, 0.3))
		return
		
	var available = GameState.get_tile_available_resources(hex)
	if available.is_empty():
		GameState.post_notice("该区块无可开采的资源储备（已采尽）！", Color.GRAY)
		return
		
	if tile_context_menu:
		tile_context_menu.open_at(screen_pos, hex, available)

func _process(delta: float) -> void:
	# WASD / 方向键平滑移动摄像机
	var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		camera.position = _clamp_camera(camera.position + dir * (camera_speed / camera.zoom.x) * delta)
	
	# 自动存档周期计时
	var interval = float(SettingsManager.get_setting("auto_save_interval", 45.0))
	if interval > 0.1:
		auto_save_timer += delta
		if auto_save_timer >= interval:
			auto_save_timer = 0.0
			SaveManager.save_to_slot("auto", self)

func _bind_furnace_events(f_node: Node2D) -> void:
	if f_node.has_signal("open_workbench_requested"):
		f_node.open_workbench_requested.connect(func(furnace_inst):
			hud.show_furnace_ui(furnace_inst)
		)

func get_build_validity(hex: Vector2i) -> Dictionary:
	if not generated_hexes.has(hex):
		return {"valid": false, "reason": "未探索未知区域"}
	if not GameState.is_hex_in_territory(hex.x, hex.y):
		return {"valid": false, "reason": "超出文明领地边界"}
	if GameState.built_furnaces.has(hex) or GameState.built_reactors.has(hex):
		return {"valid": false, "reason": "地块已被设施占用"}
	if generated_hexes.get(hex) == HexWorldGenerator.BiomeType.SALT_LAKE:
		return {"valid": false, "reason": "无法在盐湖水域中建造"}
	return {"valid": true, "reason": "可安放设施"}

func is_valid_build_hex(hex: Vector2i) -> bool:
	return get_build_validity(hex).get("valid", false)

func enter_placement_mode(structure_key: String) -> void:
	is_placing_structure = true
	placing_structure_key = structure_key
	var recipe = DataDB.get_building_recipe(structure_key)
	var b_name = recipe.get("name", structure_key)
	hud.show_placement_mode(b_name)
	GameState.post_notice("建造选址: 请在领地空闲地块点击安放【%s】(右键或ESC取消)" % b_name, Color(0.3, 0.9, 0.6))
	overlay_layer.queue_redraw()

func cancel_placement_mode() -> void:
	if not is_placing_structure:
		return
	is_placing_structure = false
	placing_structure_key = ""
	hud.hide_placement_mode()
	overlay_layer.queue_redraw()
	GameState.post_notice("已取消建造", Color(0.8, 0.8, 0.8))

func confirm_placement(hex: Vector2i) -> void:
	var check = get_build_validity(hex)
	if not check.get("valid", false):
		GameState.post_notice("无法在此建造: %s" % check.get("reason", "无效地块"), Color(1.0, 0.4, 0.4))
		return
	var key = placing_structure_key
	is_placing_structure = false
	placing_structure_key = ""
	hud.hide_placement_mode()
	overlay_layer.queue_redraw()
	GameState.build_structure(key, hex)

func _find_valid_build_hex(preferred_hex: Vector2i) -> Vector2i:
	if is_valid_build_hex(preferred_hex):
		return preferred_hex
			
	# 从中心向外螺旋搜索最近的未被建筑占用的领地内地块
	var radius = GameState.get_current_territory_radius()
	for r in range(0, radius + 1):
		for q in range(-r, r + 1):
			for s in range(-r, r + 1):
				var h = Vector2i(q, s)
				if is_valid_build_hex(h):
					return h
	return Vector2i.ZERO

func _on_build_structure_requested(structure_key: String) -> void:
	var recipe = DataDB.get_building_recipe(structure_key)
	if recipe.is_empty():
		GameState.post_notice("未知建筑类型: %s" % structure_key, Color.RED)
		return
	var req_items = recipe.get("required_items", [])
	if not GameState.sim._has_all_ingredients(req_items):
		GameState.post_notice("建造原料不足！需要: %s" % GameState.sim._get_ingredients_desc(req_items), Color.RED)
		return
		
	# 启动地图自由交互放置模式
	enter_placement_mode(structure_key)

func _on_build_furnace_requested() -> void:
	_on_build_structure_requested("furnace")

func _on_build_reactor_requested() -> void:
	_on_build_structure_requested("industrial_reactor")

func _on_structure_built(structure_key: String, hex: Vector2i) -> void:
	var spawn_pos = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
	if GameState.sim.FURNACE_TYPES.has(structure_key):
		var new_f = FurnaceScene.instantiate()
		new_f.hex_coord = hex
		new_f.building_type = structure_key
		new_f.position = spawn_pos
		entities.add_child(new_f)
		built_furnaces.append(new_f)
		_bind_furnace_events(new_f)
		# 隐匿该地块上的自然资源，避免与建筑视觉穿模
		for child in entities.get_children():
			if "hex_coord" in child and child.hex_coord == hex and "item_key" in child:
				child.visible = false
		GameState.depleted_tiles[hex] = true
		SaveManager.save_to_slot("auto", self)
	elif structure_key == "industrial_reactor":
		var new_r = IndustrialReactorScene.instantiate()
		new_r.hex_coord = hex
		new_r.position = spawn_pos
		entities.add_child(new_r)
		built_reactors.append(new_r)
		for child in entities.get_children():
			if "hex_coord" in child and child.hex_coord == hex and "item_key" in child:
				child.visible = false
		GameState.depleted_tiles[hex] = true
		SaveManager.save_to_slot("auto", self)

# --- 存档序列化与反序列化接口 ---

func serialize_world_state() -> Dictionary:
	var f_data: Array = []
	for hex in GameState.built_furnaces.keys():
		var f = GameState.built_furnaces[hex]
		var pos = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
		var buf = f.get("buffer")
		var comps: Dictionary = {}
		var temp: float = 293.15
		if buf != null and "components" in buf:
			comps = buf.components.duplicate()
			temp = buf.temperature
		f_data.append({
			"hex_q": hex.x,
			"hex_r": hex.y,
			"x": pos.x,
			"y": pos.y,
			"temperature": temp,
			"burn_timer": float(f.get("burn_timer", 0.0)),
			"is_active_fire": bool(f.get("is_active_fire", false)),
			"components": comps
		})
	var r_data: Array = []
	for hex in GameState.built_reactors.keys():
		var r = GameState.built_reactors[hex]
		var r_pos = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
		r_data.append({
			"hex_q": hex.x,
			"hex_r": hex.y,
			"x": r_pos.x,
			"y": r_pos.y,
			"blueprint_id": str(r.get("blueprint_id", "")),
			"total_produced": int(r.get("total_produced", 0))
		})
	return {
		"cam_x": camera.position.x,
		"cam_y": camera.position.y,
		"zoom": target_zoom.x,
		"furnaces": f_data,
		"reactors": r_data
	}

func deserialize_world_state(data: Dictionary) -> void:
	if data.has("cam_x") and data.has("cam_y"):
		camera.position = Vector2(float(data["cam_x"]), float(data["cam_y"]))
	if data.has("zoom"):
		target_zoom = Vector2(float(data["zoom"]), float(data["zoom"]))
		camera.zoom = target_zoom
		
	# 清理旧建筑表现节点
	for f in built_furnaces:
		if is_instance_valid(f): f.queue_free()
	built_furnaces.clear()
	for r in built_reactors:
		if is_instance_valid(r): r.queue_free()
	built_reactors.clear()
	
	# 按模拟层状态实例化熔炉视图节点
	for f_hex in GameState.built_furnaces.keys():
		var new_f = FurnaceScene.instantiate()
		new_f.hex_coord = f_hex
		new_f.building_type = GameState.built_furnaces[f_hex].get("type", "furnace")
		new_f.position = HexWorldGenerator.hex_to_pixel(f_hex.x, f_hex.y)
		entities.add_child(new_f)
		built_furnaces.append(new_f)
		_bind_furnace_events(new_f)

	# 按模拟层状态实例化反应塔视图节点
	for r_hex in GameState.built_reactors.keys():
		var new_r = IndustrialReactorScene.instantiate()
		new_r.hex_coord = r_hex
		new_r.position = HexWorldGenerator.hex_to_pixel(r_hex.x, r_hex.y)
		entities.add_child(new_r)
		built_reactors.append(new_r)

	# 将已采空的格子状态覆盖到地表资源节点上
	apply_depleted_tiles_to_nodes()
	terrain_layer.queue_redraw()
	overlay_layer.queue_redraw()

func apply_depleted_tiles_to_nodes() -> void:
	for node in entities.get_children():
		if node is Area2D and "hex_coord" in node:
			var in_terr = GameState.is_hex_in_territory(node.hex_coord.x, node.hex_coord.y)
			var depleted = GameState.depleted_tiles.has(node.hex_coord)
			var minable = true
			if "item_key" in node and not str(node.item_key).is_empty():
				minable = GameState.sim.is_resource_minable(node.item_key)
			node.visible = in_terr and not depleted and minable

func reset_world_state() -> void:
	for f in built_furnaces:
		if is_instance_valid(f): f.queue_free()
	built_furnaces.clear()
	for r in built_reactors:
		if is_instance_valid(r): r.queue_free()
	built_reactors.clear()
	camera.position = Vector2.ZERO
	target_zoom = Vector2.ONE
	camera.zoom = Vector2.ONE
	apply_depleted_tiles_to_nodes()
	terrain_layer.queue_redraw()
	overlay_layer.queue_redraw()
