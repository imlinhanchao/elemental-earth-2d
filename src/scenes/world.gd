# world.gd
# 2D 开放大世界总场景: 鼠标上帝视角控制、自由拖拽与缩放、六边形作业队列驱动
extends Node2D

const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")
const ResourceNodeScene = preload("res://src/scenes/resource_node.tscn")
const FurnaceScene = preload("res://src/scenes/furnace.tscn")
const IndustrialReactorScene = preload("res://src/scenes/industrial_reactor.tscn")

@onready var entities = $Entities
@onready var camera = $WorldCamera
@onready var hud = $HUD

var hex_gen: HexWorldGenerator
var generated_hexes: Dictionary = {} # Vector2i(q, r) -> BiomeType
var hovered_hex: Vector2i = Vector2i(9999, 9999)

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
	
	GameState.task_progress_updated.connect(func(_t, _p, _r): queue_redraw())
	GameState.task_queue_changed.connect(func(): queue_redraw())
	
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
	
	var iname = DataDB.get_item(item_key).get("name", item_key)
	node.item_name = iname
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
	
	# 如果是盐湖水域且没有实体覆盖，分配打水/汲水任务
	if biome == HexWorldGenerator.BiomeType.SALT_LAKE:
		var task = {
			"type": "water",
			"title": "💧 汲取盐湖卤水",
			"icon": "💧",
			"world_pos": world_p,
			"hex_coord": hex,
			"total_time": 1.8,
			"target_key": "water"
		}
		GameState.add_task(task)
	else:
		# 其他地貌分配勘查/搜寻杂物任务
		var b_name = "生机原野" if biome == HexWorldGenerator.BiomeType.PLAINS else ("熔岩地热" if biome == HexWorldGenerator.BiomeType.VOLCANO else "原始森林")
		var task = {
			"type": "forage",
			"title": "🔍 搜寻%s" % b_name,
			"icon": "🔍",
			"world_pos": world_p,
			"hex_coord": hex,
			"total_time": 1.2,
			"on_complete": func():
				if randf() < 0.4:
					GameState.inventory.add_item("stick", 1)
					GameState.post_notice("🔍 搜寻有获: 发现【枯树枝 x1】！", Color.GREEN)
				elif randf() < 0.7:
					GameState.inventory.add_item("stone", 1)
					GameState.post_notice("🔍 搜寻有获: 拾得【碎石 x1】！", Color.GREEN)
				else:
					GameState.post_notice("🔍 此处地表暂无散落杂物。", Color.GRAY)
		}
		GameState.add_task(task)

func _process(delta: float) -> void:
	# WASD / 方向键平滑移动摄像机
	var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		camera.position += dir * (camera_speed / camera.zoom.x) * delta
	
	# 平滑缩放过渡
	camera.zoom = camera.zoom.lerp(target_zoom, delta * 12.0)

func _draw() -> void:
	# 1. 绘制每一个六边形地块及专属生态纹理
	for coord in generated_hexes.keys():
		var q = coord.x
		var r = coord.y
		var biome = generated_hexes[coord]
		var center = HexWorldGenerator.hex_to_pixel(q, r)
		var col = HexWorldGenerator.get_biome_color(biome)
		
		# 绘制六边形多边形顶点 (6 个点)
		var points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			var pt = center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS
			points.append(pt)
			
		# 填充底色
		draw_colored_polygon(points, col)
		
		# 绘制六边形专属群系纹理
		_draw_hex_biome_texture(center, biome, q, r)
		
		# 勾勒六边形边界线
		points.append(points[0])
		draw_polyline(points, col.lightened(0.18), 1.0)
	
	# 2. 绘制鼠标当前悬停的六边形高亮框
	if generated_hexes.has(hovered_hex):
		var h_center = HexWorldGenerator.hex_to_pixel(hovered_hex.x, hovered_hex.y)
		var h_points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			var pt = h_center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS
			h_points.append(pt)
		h_points.append(h_points[0])
		draw_polyline(h_points, Color(0.3, 0.9, 1.0, 0.8), 2.5) # 亮青色光环
	
	# 3. 绘制当前正在进行的任务的世界地块指示器
	if not GameState.active_task.is_empty():
		var t_pos = GameState.active_task.get("world_pos", Vector2.ZERO)
		var total = float(GameState.active_task.get("total_time", 1.0))
		var elapsed = float(GameState.active_task.get("elapsed_time", 0.0))
		var pct = clamp(elapsed / total, 0.0, 1.0)
		# 发光作业环
		draw_arc(t_pos, 28.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.35), 4.0)
		draw_arc(t_pos, 28.0, -PI/2, -PI/2 + pct * TAU, 32, Color(1.0, 0.88, 0.3, 0.95), 5.0)

	# 4. 绘制排队中任务的地块指示环
	for i in range(GameState.task_queue.size()):
		var q_task = GameState.task_queue[i]
		var q_pos = q_task.get("world_pos", Vector2.ZERO)
		draw_circle(q_pos, 16.0, Color(0.1, 0.2, 0.3, 0.3))
		draw_arc(q_pos, 20.0, 0, TAU, 24, Color(0.8, 0.8, 0.3, 0.5), 2.0)

# 群系纹理绘制辅助函数
func _draw_hex_biome_texture(center: Vector2, biome: HexWorldGenerator.BiomeType, _q: int, _r: int) -> void:
	match biome:
		HexWorldGenerator.BiomeType.PLAINS:
			# 生机草丝 (两三簇细草)
			draw_line(center + Vector2(-6, 2), center + Vector2(-8, -4), Color(0.35, 0.58, 0.30), 1.5)
			draw_line(center + Vector2(-6, 2), center + Vector2(-4, -5), Color(0.38, 0.65, 0.32), 1.5)
			draw_line(center + Vector2(8, -2), center + Vector2(10, -8), Color(0.32, 0.52, 0.28), 1.5)
		HexWorldGenerator.BiomeType.VOLCANO:
			# 暗红玄武岩裂隙与熔岩微光
			draw_line(center + Vector2(-12, -4), center + Vector2(0, 2), Color(0.85, 0.25, 0.10, 0.7), 1.8)
			draw_line(center + Vector2(0, 2), center + Vector2(10, -6), Color(1.0, 0.45, 0.15, 0.8), 1.5)
			draw_circle(center + Vector2(0, 2), 2.5, Color(1.0, 0.65, 0.2, 0.9)) # 熔岩火星
		HexWorldGenerator.BiomeType.SALT_LAKE:
			# 水面涟漪与析盐白色微环
			draw_arc(center + Vector2(-4, -2), 10.0, 0.2, PI - 0.2, 10, Color(0.65, 0.82, 0.92, 0.45), 1.5)
			draw_arc(center + Vector2(6, 6), 7.0, PI + 0.2, TAU - 0.2, 8, Color(0.70, 0.88, 0.98, 0.40), 1.5)
			draw_circle(center + Vector2(12, -8), 2.5, Color(0.95, 0.98, 1.0, 0.75)) # 析盐小晶片
		HexWorldGenerator.BiomeType.DEEP_FOREST:
			# 苍翠深林苔藓斑与落叶点
			draw_circle(center + Vector2(-8, -6), 4.5, Color(0.08, 0.18, 0.09, 0.7))
			draw_circle(center + Vector2(6, 4), 3.5, Color(0.10, 0.20, 0.11, 0.7))
			draw_line(center + Vector2(-2, 8), center + Vector2(4, 10), Color(0.28, 0.20, 0.12), 2.0)

func _bind_furnace_events(f_node: Node2D) -> void:
	if f_node.has_signal("open_workbench_requested"):
		f_node.open_workbench_requested.connect(func(furnace_inst):
			hud.show_furnace_ui(furnace_inst)
		)

func _on_build_furnace_requested() -> void:
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
		var spawn_pos = HexWorldGenerator.hex_to_pixel(hovered_hex.x, hovered_hex.y) if generated_hexes.has(hovered_hex) else camera.position
		new_f.position = spawn_pos
		entities.add_child(new_f)
		_bind_furnace_events(new_f)
		GameState.post_notice("🔨 现场施工完成！消耗原木 x4 与碎石 x4 堆砌起【陶土熔炉】！", Color.GREEN)
	else:
		GameState.post_notice("❌ 建造土窑原料不足！需要: 原木 x4, 碎石 x4 (亦可用燧石充当)", Color.RED)

func _on_build_reactor_requested() -> void:
	if GameState.inventory.has_item("wood", 8) and GameState.inventory.has_item("copper", 2):
		GameState.inventory.remove_item("wood", 8)
		GameState.inventory.remove_item("copper", 2)
		var new_r = IndustrialReactorScene.instantiate()
		var spawn_pos = HexWorldGenerator.hex_to_pixel(hovered_hex.x, hovered_hex.y) if generated_hexes.has(hovered_hex) else camera.position
		new_r.position = spawn_pos
		entities.add_child(new_r)
		GameState.post_notice("🏭 近代工业巨构施工完成！消耗原木 x8 与金属铜 x2 建立【工业连续反应塔】！", Color(0.2, 0.8, 1.0))
	else:
		GameState.post_notice("❌ 建造反应塔原料不足！需要: 原木 x8, 金属铜 x2 (请先在土窑炼铜)", Color.RED)
