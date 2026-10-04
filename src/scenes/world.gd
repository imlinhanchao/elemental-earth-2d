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
	hex_gen = HexWorldGenerator.new(12345)
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
	for q in range(-WORLD_HEX_RADIUS, WORLD_HEX_RADIUS + 1):
		var r1 = max(-WORLD_HEX_RADIUS, -q - WORLD_HEX_RADIUS)
		var r2 = min(WORLD_HEX_RADIUS, -q + WORLD_HEX_RADIUS)
		for r in range(r1, r2 + 1):
			var biome = hex_gen.get_biome(q, r)
			var coord = Vector2i(q, r)
			generated_hexes[coord] = biome
			
			if abs(q) <= 1 and abs(r) <= 1:
				continue
				
			var spawn_item = hex_gen.determine_resource_spawn(q, r, biome)
			if spawn_item != "":
				_spawn_resource_at_hex(q, r, spawn_item)
				
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
		var total = float(GameState.active_task.get("total_time", 1.0))
		var elapsed = float(GameState.active_task.get("elapsed_time", 0.0))
		var pct = clamp(elapsed / total, 0.0, 1.0)
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
	var spawn_pos = HexWorldGenerator.hex_to_pixel(hovered_hex.x, hovered_hex.y) if generated_hexes.has(hovered_hex) else camera.position
	if not GameState.is_pos_in_territory(spawn_pos):
		GameState.post_notice("🚩 无法在此建造：超出当前文明领地边界！", Color(1.0, 0.4, 0.4))
		return
		
	var stone_count = GameState.inventory.get_count("stone")
	var flint_count = GameState.inventory.get_count("flint")
	if GameState.inventory.has_item("wood", 4) and (stone_count + flint_count >= 4):
		GameState.inventory.remove_item("wood", 4)
		var needed = 4
		var take_stone = min(stone_count, needed)
		if take_stone > 0:
			GameState.inventory.remove_item("stone", take_stone)
			needed -= take_stone
		if needed > 0:
			GameState.inventory.remove_item("flint", needed)
		var new_f = FurnaceScene.instantiate()
		new_f.position = spawn_pos
		entities.add_child(new_f)
		built_furnaces.append(new_f)
		_bind_furnace_events(new_f)
		GameState.post_notice("🔨 现场施工完成！消耗原木 x4 与碎石 x4 堆砌起【陶土熔炉】！", Color.GREEN)
		SaveManager.save_to_slot("auto", self)
	else:
		GameState.post_notice("❌ 建造土窑原料不足！需要: 原木 x4, 碎石 x4 (亦可用燧石充当)", Color.RED)

func _on_build_reactor_requested() -> void:
	var spawn_pos = HexWorldGenerator.hex_to_pixel(hovered_hex.x, hovered_hex.y) if generated_hexes.has(hovered_hex) else camera.position
	if not GameState.is_pos_in_territory(spawn_pos):
		GameState.post_notice("🚩 无法在此建造：超出当前文明领地边界！", Color(1.0, 0.4, 0.4))
		return
		
	if GameState.inventory.has_item("wood", 8) and GameState.inventory.has_item("copper", 2):
		GameState.inventory.remove_item("wood", 8)
		GameState.inventory.remove_item("copper", 2)
		var new_r = IndustrialReactorScene.instantiate()
		new_r.position = spawn_pos
		entities.add_child(new_r)
		built_reactors.append(new_r)
		GameState.post_notice("🏭 近代工业巨构施工完成！消耗原木 x8 与金属铜 x2 建立【工业连续反应塔】！", Color(0.2, 0.8, 1.0))
		SaveManager.save_to_slot("auto", self)
	else:
		GameState.post_notice("❌ 建造反应塔原料不足！需要: 原木 x8, 金属铜 x2 (请先在土窑炼铜)", Color.RED)

# --- 存档序列化与反序列化接口 ---

func serialize_world_state() -> Dictionary:
	var f_data: Array = []
	for f in built_furnaces:
		if is_instance_valid(f):
			f_data.append({
				"x": f.position.x,
				"y": f.position.y,
				"temperature": f.buffer.temperature,
				"burn_timer": f.burn_timer,
				"is_active_fire": f.is_active_fire,
				"components": f.buffer.components
			})
	var r_data: Array = []
	for r in built_reactors:
		if is_instance_valid(r):
			r_data.append({
				"x": r.position.x,
				"y": r.position.y,
				"blueprint_id": r.installed_blueprint.id if r.installed_blueprint else "",
				"total_produced": r.total_produced_count
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
		
	# 清理旧建筑
	for f in built_furnaces:
		if is_instance_valid(f): f.queue_free()
	built_furnaces.clear()
	for r in built_reactors:
		if is_instance_valid(r): r.queue_free()
	built_reactors.clear()
	
	# 还原熔炉
	for f_item in data.get("furnaces", []):
		var new_f = FurnaceScene.instantiate()
		new_f.position = Vector2(float(f_item["x"]), float(f_item["y"]))
		entities.add_child(new_f)
		built_furnaces.append(new_f)
		_bind_furnace_events(new_f)
		new_f.buffer.temperature = float(f_item.get("temperature", 293.15))
		new_f.burn_timer = float(f_item.get("burn_timer", 0.0))
		new_f.is_active_fire = bool(f_item.get("is_active_fire", false))
		var comps = f_item.get("components", {})
		for c_k in comps.keys():
			new_f.buffer.components[c_k] = float(comps[c_k])
			
	# 还原反应塔
	for r_item in data.get("reactors", []):
		var new_r = IndustrialReactorScene.instantiate()
		new_r.position = Vector2(float(r_item["x"]), float(r_item["y"]))
		entities.add_child(new_r)
		built_reactors.append(new_r)
		new_r.total_produced_count = int(r_item.get("total_produced", 0))
		var bpid = r_item.get("blueprint_id", "")
		if bpid != "" and GameState.unlocked_blueprints.has(bpid):
			new_r.install_blueprint(GameState.unlocked_blueprints[bpid])

	queue_redraw()

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
	queue_redraw()
