# world.gd
# 2D 开放大世界总场景: 鼠标上帝视角控制、时代领地疆域系统、自动存档与工业连续流
extends Node2D

const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")
const ResourceNodeScene = preload("res://src/scenes/resource_node.tscn")
const FurnaceScene = preload("res://src/scenes/furnace.tscn")
const IndustrialReactorScene = preload("res://src/scenes/industrial_reactor.tscn")
const SaveManager = preload("res://src/core/save_manager.gd")
const SettingsManager = preload("res://src/core/settings_manager.gd")

@onready var entities = $Entities
@onready var camera = $WorldCamera
@onready var hud = $HUD

var hex_gen: HexWorldGenerator
var generated_hexes: Dictionary = {} # Vector2i(q, r) -> BiomeType
var hovered_hex: Vector2i = Vector2i(9999, 9999)

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
	
	GameState.task_progress_updated.connect(func(_t, _p, _r): queue_redraw())
	GameState.task_queue_changed.connect(func(): queue_redraw())
	
	GameState.era_advanced.connect(func(_old, _new, era_name):
		queue_redraw()
		GameState.post_notice("🚩 【领地疆域扩展】随着迈向【%s】，文明疆域拓展至半径 %d 格！" % [era_name, GameState.get_current_territory_radius()], Color(1.0, 0.85, 0.2))
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
		GameState.post_notice("🌟 [开局引导] 鼠标点击地表【碎石】、【枯树枝】加入工作队列！点击盐湖打水！右键拖拽视野！", Color(1.0, 0.88, 0.4))
	
	# 如果携带 --screenshot 参数，则在1.5秒后截取当前画面并退出
	for arg in OS.get_cmdline_user_args():
		if arg == "--screenshot":
			_capture_screenshot_after_delay()

func _capture_screenshot_after_delay() -> void:
	await get_tree().create_timer(1.2).timeout
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
	queue_redraw()

func _spawn_resource_at_hex(q: int, r: int, item_key: String) -> void:
	var pos = HexWorldGenerator.hex_to_pixel(q, r)
	var node = ResourceNodeScene.instantiate()
	node.position = pos
	node.item_key = item_key
	node.hex_coord = Vector2i(q, r)
	
	var iname = DataDB.get_item(item_key).get("name", item_key)
	node.item_name = iname
	if GameState.depleted_tiles.has(Vector2i(q, r)):
		node.visible = false
	entities.add_child(node)

func _unhandled_input(event: InputEvent) -> void:
	# 鼠标右键或中键拖拽地图
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
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
		
		# 转换鼠标世界坐标到六边形网格坐标
		var mpos = camera.get_global_mouse_position()
		var hex = HexWorldGenerator.pixel_to_hex(mpos)
		if hex != hovered_hex:
			hovered_hex = hex
			queue_redraw()
			if hex_gen and hud:
				var biome = hex_gen.get_biome(hovered_hex.x, hovered_hex.y)
				hud.update_current_biome(biome)

func _handle_tile_click(hex: Vector2i) -> void:
	if not generated_hexes.has(hex):
		return
		
	var biome = generated_hexes[hex]
	var world_p = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
	
	if biome == HexWorldGenerator.BiomeType.SALT_LAKE:
		GameState.queue_hex_water(hex, world_p)
	else:
		var b_name = "生机原野" if biome == HexWorldGenerator.BiomeType.PLAINS else ("熔岩地热" if biome == HexWorldGenerator.BiomeType.VOLCANO else "原始森林")
		GameState.queue_hex_forage(hex, b_name, world_p)

func _process(delta: float) -> void:
	# WASD / 方向键平滑移动摄像机
	var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		camera.position += dir * (camera_speed / camera.zoom.x) * delta
	
	# 平滑缩放过渡
	camera.zoom = camera.zoom.lerp(target_zoom, delta * 12.0)
	
	# 自动存档周期计时
	var interval = float(SettingsManager.get_setting("auto_save_interval", 45.0))
	if interval > 0.1:
		auto_save_timer += delta
		if auto_save_timer >= interval:
			auto_save_timer = 0.0
			SaveManager.save_to_slot("auto", self)

func _draw() -> void:
	# 1. 绘制每一个六边形地块及专属生态纹理
	for coord in generated_hexes.keys():
		var q = coord.x
		var r = coord.y
		var biome = generated_hexes[coord]
		var center = HexWorldGenerator.hex_to_pixel(q, r)
		var col = HexWorldGenerator.get_biome_color(biome)
		var in_territory = GameState.is_hex_in_territory(q, r)
		
		# 绘制六边形多边形顶点 (6 个点)
		var points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			var pt = center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS
			points.append(pt)
			
		# 填充底色 (若超出领地，叠加迷雾遮罩颜色)
		draw_colored_polygon(points, col)
		
		# 绘制六边形专属群系纹理
		_draw_hex_biome_texture(center, biome, q, r)
		
		# 勾勒六边形边界线
		points.append(points[0])
		draw_polyline(points, col.lightened(0.18), 1.0)
		
		# 超出领地范围瓦片叠加神秘未开拓迷雾
		if not in_territory:
			draw_colored_polygon(points, Color(0.04, 0.06, 0.10, 0.58))
	
	# 2. 绘制文明领地外沿金色发光边界线 (Territory Borders)
	var hex_dirs = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)
	]
	for coord in generated_hexes.keys():
		if GameState.is_hex_in_territory(coord.x, coord.y):
			var c = HexWorldGenerator.hex_to_pixel(coord.x, coord.y)
			for i in range(6):
				var neighbor = coord + hex_dirs[i]
				if not GameState.is_hex_in_territory(neighbor.x, neighbor.y):
					var a1 = deg_to_rad(60.0 * i - 30.0)
					var a2 = deg_to_rad(60.0 * ((i + 1) % 6) - 30.0)
					var p1 = c + Vector2(cos(a1), sin(a1)) * HexWorldGenerator.HEX_RADIUS
					var p2 = c + Vector2(cos(a2), sin(a2)) * HexWorldGenerator.HEX_RADIUS
					# 领地外发光金色线条
					draw_line(p1, p2, Color(1.0, 0.88, 0.35, 0.95), 3.0)

	# 3. 绘制鼠标当前悬停的六边形高亮框
	if generated_hexes.has(hovered_hex):
		var h_center = HexWorldGenerator.hex_to_pixel(hovered_hex.x, hovered_hex.y)
		var h_points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			var pt = h_center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS
			h_points.append(pt)
		h_points.append(h_points[0])
		var h_col = Color(0.3, 0.9, 1.0, 0.85) if GameState.is_hex_in_territory(hovered_hex.x, hovered_hex.y) else Color(1.0, 0.4, 0.4, 0.7)
		draw_polyline(h_points, h_col, 2.5)
	
	# 4. 绘制当前正在进行的任务的世界地块指示器
	if not GameState.active_task.is_empty():
		var t_pos = Vector2(
			float(GameState.active_task.get("world_pos_x", GameState.active_task.get("world_pos", Vector2.ZERO).x)),
			float(GameState.active_task.get("world_pos_y", GameState.active_task.get("world_pos", Vector2.ZERO).y))
		)
		var total = float(GameState.active_task.get("time_required", GameState.active_task.get("total_time", 1.0)))
		var begin_time = int(GameState.active_task.get("begin_time", 0))
		var elapsed = (Time.get_ticks_msec() - begin_time) / 1000.0 if begin_time > 0 else float(GameState.active_task.get("elapsed_time", 0.0))
		var pct = clamp(elapsed / max(total, 0.001), 0.0, 1.0)
		draw_arc(t_pos, 28.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.35), 4.0)
		draw_arc(t_pos, 28.0, -PI/2, -PI/2 + pct * TAU, 32, Color(1.0, 0.88, 0.3, 0.95), 5.0)

	# 5. 绘制排队中任务的地块指示环
	for i in range(GameState.task_queue.size()):
		var q_task = GameState.task_queue[i]
		var q_pos = Vector2(
			float(q_task.get("world_pos_x", q_task.get("world_pos", Vector2.ZERO).x)),
			float(q_task.get("world_pos_y", q_task.get("world_pos", Vector2.ZERO).y))
		)
		draw_circle(q_pos, 16.0, Color(0.1, 0.2, 0.3, 0.3))
		draw_arc(q_pos, 20.0, 0, TAU, 24, Color(0.8, 0.8, 0.3, 0.5), 2.0)

# 群系纹理绘制辅助函数
func _draw_hex_biome_texture(center: Vector2, biome: HexWorldGenerator.BiomeType, _q: int, _r: int) -> void:
	match biome:
		HexWorldGenerator.BiomeType.PLAINS:
			draw_line(center + Vector2(-6, 2), center + Vector2(-8, -4), Color(0.35, 0.58, 0.30), 1.5)
			draw_line(center + Vector2(-6, 2), center + Vector2(-4, -5), Color(0.38, 0.65, 0.32), 1.5)
			draw_line(center + Vector2(8, -2), center + Vector2(10, -8), Color(0.32, 0.52, 0.28), 1.5)
		HexWorldGenerator.BiomeType.VOLCANO:
			draw_line(center + Vector2(-12, -4), center + Vector2(0, 2), Color(0.85, 0.25, 0.10, 0.7), 1.8)
			draw_line(center + Vector2(0, 2), center + Vector2(10, -6), Color(1.0, 0.45, 0.15, 0.8), 1.5)
			draw_circle(center + Vector2(0, 2), 2.5, Color(1.0, 0.65, 0.2, 0.9))
		HexWorldGenerator.BiomeType.SALT_LAKE:
			draw_arc(center + Vector2(-4, -2), 10.0, 0.2, PI - 0.2, 10, Color(0.65, 0.82, 0.92, 0.45), 1.5)
			draw_arc(center + Vector2(6, 6), 7.0, PI + 0.2, TAU - 0.2, 8, Color(0.70, 0.88, 0.98, 0.40), 1.5)
			draw_circle(center + Vector2(12, -8), 2.5, Color(0.95, 0.98, 1.0, 0.75))
		HexWorldGenerator.BiomeType.DEEP_FOREST:
			draw_circle(center + Vector2(-8, -6), 4.5, Color(0.08, 0.18, 0.09, 0.7))
			draw_circle(center + Vector2(6, 4), 3.5, Color(0.10, 0.20, 0.11, 0.7))
			draw_line(center + Vector2(-2, 8), center + Vector2(4, 10), Color(0.28, 0.20, 0.12), 2.0)

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
	
	# 如果是旧存档或外部导入，GameState.built_furnaces 为空，从 world_data 补充到 GameState
	if GameState.built_furnaces.is_empty() and data.has("furnaces"):
		for f_item in data.get("furnaces", []):
			var f_hex = Vector2i(9999, 9999)
			if f_item.has("hex_q") and f_item.has("hex_r"):
				f_hex = Vector2i(int(f_item["hex_q"]), int(f_item["hex_r"]))
			else:
				f_hex = HexWorldGenerator.pixel_to_hex(Vector2(float(f_item.get("x", 0.0)), float(f_item.get("y", 0.0))))
			var buf = MixtureBuffer.new()
			buf.container_type = "furnace"
			buf.temperature = float(f_item.get("temperature", 293.15))
			var comps = f_item.get("components", {})
			if comps is Dictionary:
				for c_k in comps.keys():
					buf.components[c_k] = float(comps[c_k])
			GameState.built_furnaces[f_hex] = {
				"buffer": buf,
				"burn_timer": float(f_item.get("burn_timer", 0.0)),
				"is_active_fire": bool(f_item.get("is_active_fire", false))
			}
			
	if GameState.built_reactors.is_empty() and data.has("reactors"):
		for r_item in data.get("reactors", []):
			var r_hex = Vector2i(9999, 9999)
			if r_item.has("hex_q") and r_item.has("hex_r"):
				r_hex = Vector2i(int(r_item["hex_q"]), int(r_item["hex_r"]))
			else:
				r_hex = HexWorldGenerator.pixel_to_hex(Vector2(float(r_item.get("x", 0.0)), float(r_item.get("y", 0.0))))
			GameState.built_reactors[r_hex] = {
				"blueprint_id": str(r_item.get("blueprint_id", "")),
				"cycle_progress": 0.0,
				"total_produced": int(r_item.get("total_produced", 0))
			}

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
	queue_redraw()

func apply_depleted_tiles_to_nodes() -> void:
	for node in entities.get_children():
		if node is Area2D and "hex_coord" in node:
			if GameState.depleted_tiles.has(node.hex_coord):
				node.visible = false
			else:
				node.visible = true

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
	queue_redraw()
