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

func _ready() -> void:
	terrain_layer.world = self
	overlay_layer.world = self
	
	tile_context_menu = TileContextMenuScene.instantiate()
	hud.add_child(tile_context_menu)
	tile_context_menu.harvest_requested.connect(_on_context_menu_harvest)

	GameState.structure_built.connect(_on_structure_built)
	_generate_hex_world()
	
	hud.build_furnace_requested.connect(_on_build_furnace_requested)
	hud.build_reactor_requested.connect(_on_build_reactor_requested)
	
	hud.save_requested.connect(func(): SaveManager.save_to_slot("slot_1", self))
	hud.load_requested.connect(func(): SaveManager.load_from_slot("slot_1", self))
	hud.reset_requested.connect(func():
		GameState.reset_to_new_game()
		reset_world_state()
	)
	
	GameState.task_progress_updated.connect(func(_t, _p, _r): overlay_layer.queue_redraw())
	GameState.task_queue_changed.connect(func(): overlay_layer.queue_redraw())
	
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
	elif SaveManager.has_any_save() and GameState.inventory.items.is_empty() and GameState.current_era == 0 and GameState.discovered_elements.is_empty():
		var latest = SaveManager.get_latest_save_slot()
		if latest != "":
			SaveManager.load_from_slot(latest, self)
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
		hud.inventory_modal.open()
	elif arg_name == "--screenshot-craft":
		hud._toggle_category(hud.CategoryTab.CRAFT)
	elif arg_name == "--screenshot-lab":
		hud.lab_modal.open()
	elif arg_name == "--screenshot-pt":
		hud.periodic_modal.open()
	elif arg_name == "--screenshot-hud":
		pass # 保持主界面纯净 HUD 与大世界大视野
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
		print("✅ [Screenshot] 实机渲染截图成功生成: /Users/hancel/Documents/project/elemental-earth-2d/screenshot_current.png")
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
	node.visible = in_terr and not depleted
	entities.add_child(node)

func _on_context_menu_harvest(hex: Vector2i, item_key: String, count: int) -> void:
	var world_p = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
	GameState.queue_hex_harvest(hex, item_key, count, world_p)

func _unhandled_input(event: InputEvent) -> void:
	# 鼠标右键或中键拖拽地图；右键单点呼出开采次数菜单
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging_camera = true
				drag_start_mouse = event.position
				drag_start_cam_pos = camera.position
				right_click_down_pos = event.position
			else:
				is_dragging_camera = false
				# 若右键按下与抬起位移小于 6px，判定为单点右键，呼出开采菜单
				if (event.position - right_click_down_pos).length() < 6.0:
					_handle_tile_right_click(hovered_hex, event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging_camera = event.pressed
			drag_start_mouse = event.position
			drag_start_cam_pos = camera.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = (target_zoom * 1.15).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = (target_zoom * 0.85).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_tile_click(hovered_hex)
	
	elif event is InputEventMouseMotion:
		if is_dragging_camera:
			camera.position = drag_start_cam_pos - (event.position - drag_start_mouse) / camera.zoom
			if terrain_layer:
				terrain_layer.queue_redraw()
		
		# 转换鼠标世界坐标到六边形网格坐标
		var mpos = camera.get_global_mouse_position()
		var hex = HexWorldGenerator.pixel_to_hex(mpos)
		if hex != hovered_hex:
			hovered_hex = hex
			overlay_layer.queue_redraw()
			if hud and generated_hexes.has(hovered_hex):
				hud.update_current_biome(generated_hexes[hovered_hex])

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
		camera.position += dir * (camera_speed / camera.zoom.x) * delta
		if terrain_layer:
			terrain_layer.queue_redraw()
	
	# 平滑缩放过渡
	var prev_zoom_x = camera.zoom.x
	camera.zoom = camera.zoom.lerp(target_zoom, delta * 12.0)
	if prev_zoom_x != camera.zoom.x and terrain_layer:
		terrain_layer.queue_redraw()
		
	var new_lod = 1 if camera.zoom.x >= 0.85 else 0
	if terrain_layer and terrain_layer.current_lod != new_lod:
		terrain_layer.current_lod = new_lod
		terrain_layer.queue_redraw()
	
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

func _on_build_furnace_requested() -> void:
	var target_hex = hovered_hex if generated_hexes.has(hovered_hex) else HexWorldGenerator.pixel_to_hex(camera.position)
	GameState.build_structure("furnace", target_hex)

func _on_build_reactor_requested() -> void:
	var target_hex = hovered_hex if generated_hexes.has(hovered_hex) else HexWorldGenerator.pixel_to_hex(camera.position)
	GameState.build_structure("industrial_reactor", target_hex)

func _on_structure_built(structure_key: String, hex: Vector2i) -> void:
	var spawn_pos = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
	if structure_key == "furnace":
		var new_f = FurnaceScene.instantiate()
		new_f.hex_coord = hex
		new_f.position = spawn_pos
		entities.add_child(new_f)
		built_furnaces.append(new_f)
		_bind_furnace_events(new_f)
		SaveManager.save_to_slot("auto", self)
	elif structure_key == "industrial_reactor":
		var new_r = IndustrialReactorScene.instantiate()
		new_r.hex_coord = hex
		new_r.position = spawn_pos
		entities.add_child(new_r)
		built_reactors.append(new_r)
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
			node.visible = in_terr and not depleted

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
