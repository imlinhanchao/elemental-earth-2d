# world.gd
# 2D 开放大世界总场景: 包含柏林噪声六边形群落、程序化资源矿带与工业连续流
extends Node2D

const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")
const ResourceNodeScene = preload("res://src/scenes/resource_node.tscn")
const FurnaceScene = preload("res://src/scenes/furnace.tscn")
const IndustrialReactorScene = preload("res://src/scenes/industrial_reactor.tscn")

@onready var entities = $Entities
@onready var player = $Entities/Player
@onready var hud = $HUD

var hex_gen: HexWorldGenerator
var generated_hexes: Dictionary = {} # Vector2i(q, r) -> BiomeType

# 六边形世界边界范围 (-20 到 20 圈)
const WORLD_HEX_RADIUS: int = 18

func _ready() -> void:
	hex_gen = HexWorldGenerator.new(12345)
	
	_generate_hex_world()
	
	hud.build_furnace_requested.connect(_on_build_furnace_requested)
	hud.build_reactor_requested.connect(_on_build_reactor_requested)
	
	GameState.post_notice("🌟 [开局引导] 赤手空拳！请走向地表【枯树枝】与【碎石】，按 [空格] 拾取，按 [C] 制作工具！", Color(1.0, 0.88, 0.4))
	
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
			
			# 不在玩家出生点 (0, 0) 周边 2 格内生成障碍矿石
			if abs(q) <= 1 and abs(r) <= 1:
				continue
				
			# 程序化判定群落资源生成
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

func _process(_delta: float) -> void:
	if player and hex_gen and hud:
		var hex_coord = HexWorldGenerator.pixel_to_hex(player.position)
		var biome = hex_gen.get_biome(hex_coord.x, hex_coord.y)
		hud.update_current_biome(biome)

func _draw() -> void:
	# 绘制每一个六边形地块及专属生态纹理
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

# 群系纹理绘制辅助函数
func _draw_hex_biome_texture(center: Vector2, biome: HexWorldGenerator.BiomeType, q: int, r: int) -> void:
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
	f_node.body_entered.connect(func(body):
		if body.is_in_group("player"):
			hud.show_furnace_ui(f_node)
			GameState.post_notice("靠近了【陶土熔炉】，可向右侧面板投入矿石冶炼！", Color.GOLD)
	)
	f_node.body_exited.connect(func(body):
		if body.is_in_group("player"):
			hud.hide_furnace_ui()
	)

func _on_build_furnace_requested() -> void:
	if GameState.inventory.has_item("wood", 4) and GameState.inventory.has_item("flint", 4):
		GameState.inventory.remove_item("wood", 4)
		GameState.inventory.remove_item("flint", 4)
		var new_f = FurnaceScene.instantiate()
		new_f.position = player.position + Vector2(40, 20)
		entities.add_child(new_f)
		_bind_furnace_events(new_f)
		GameState.post_notice("🔨 现场施工完成！消耗原木 x4 与碎石 x4 堆砌起【陶土熔炉】！", Color.GREEN)
	else:
		GameState.post_notice("❌ 建造土窑原料不足！需要: 原木 x4, 碎石 x4", Color.RED)

func _on_build_reactor_requested() -> void:
	if GameState.inventory.has_item("wood", 8) and GameState.inventory.has_item("copper", 2):
		GameState.inventory.remove_item("wood", 8)
		GameState.inventory.remove_item("copper", 2)
		var new_r = IndustrialReactorScene.instantiate()
		new_r.position = player.position + Vector2(40, 20)
		entities.add_child(new_r)
		GameState.post_notice("🏭 近代工业巨构施工完成！消耗原木 x8 与金属铜 x2 建立【工业连续反应塔】！", Color(0.2, 0.8, 1.0))
	else:
		GameState.post_notice("❌ 建造反应塔原料不足！需要: 原木 x8, 金属铜 x2 (请先在土窑炼铜)", Color.RED)
