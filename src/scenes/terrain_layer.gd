# terrain_layer.gd
# 方案三：现代科学信息图 · 极简冷灰几何风 (Modern Scientific Minimalist & Infographic)
# 渲染高科技六边形元素卡片瓷砖、深海蓝图背景网格、外向数据回路与外围浮云
extends Node2D

const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")

const HEX_EDGE_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),   # edge 0: vertex 0 -> 1 (East)
	Vector2i(0, 1),   # edge 1: vertex 1 -> 2 (Southeast)
	Vector2i(-1, 1),  # edge 2: vertex 2 -> 3 (Southwest)
	Vector2i(-1, 0),  # edge 3: vertex 3 -> 4 (West)
	Vector2i(0, -1),  # edge 4: vertex 4 -> 5 (Northwest)
	Vector2i(1, -1)   # edge 5: vertex 5 -> 0 (Northeast)
]

var world: Node2D = null
var current_lod: int = 1

func _draw() -> void:
	if not world or world.generated_hexes.is_empty():
		return
		
	var generated_hexes = world.generated_hexes
	
	# 1. 绘制深海蓝图背景网格 (Scientific Blueprint Coordinate Grid)
	_draw_blueprint_grid()
	
	# 2. 绘制向外延伸的科学数据回路与浮动元素标牌 (Data Circuit Lines & Outer Nodes)
	_draw_data_circuit_lines()
	
	
	# 3. 遍历渲染全部六边形：
	# - 已解锁领地 (in_territory): 现代高精度白瓷/浅色元素卡片 (H, C, O, Cu, Fe) + 霓虹发光描边 + 科学参数
	# - 未解锁领地 (not in_territory): 暗蓝微光透视线框
	var font = ThemeDB.fallback_font
	
	for coord in generated_hexes.keys():
		var q = coord.x
		var r = coord.y
		var biome = generated_hexes[coord]
		var center = HexWorldGenerator.hex_to_pixel(q, r)
		var in_territory = GameState.is_hex_in_territory(q, r)
		
		# 基础六边形 6 个外顶点
		var outer_points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			outer_points.append(center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS)
			
		if in_territory:
			# === 方案三现代科学元素卡片 (Porcelain Elemental Infographic Cell) ===
			# 卡片具有 2px 内缩暗隙，形成现代卡片间隙分离感
			var card_radius = HexWorldGenerator.HEX_RADIUS * 0.92
			var card_points = PackedVector2Array()
			for i in range(6):
				var angle = deg_to_rad(60.0 * i - 30.0)
				card_points.append(center + Vector2(cos(angle), sin(angle)) * card_radius)
				
			# 计算该瓦片的化学元素属性 (匹配效果图)
			var res_key = GameState.world_resources.get(coord, "")
			var elem_info = _get_element_cell_info(biome, res_key)
			
			var fill_color = elem_info.fill as Color
			var border_color = elem_info.border as Color
			var text_color = elem_info.text_color as Color
			var sym = elem_info.symbol as String
			var top_text = elem_info.top_text as String
			var sub_text = elem_info.sub_text as String
			
			# (1) 卡片纯净瓷感多边形底色
			draw_colored_polygon(card_points, fill_color)
			
			# (2) 内切 1px 高光发丝线倒角
			var inner_bevel = PackedVector2Array()
			for i in range(6):
				var angle = deg_to_rad(60.0 * i - 30.0)
				inner_bevel.append(center + Vector2(cos(angle), sin(angle)) * (card_radius * 0.86))
			inner_bevel.append(inner_bevel[0])
			draw_polyline(inner_bevel, Color(1.0, 1.0, 1.0, 0.45), 1.0)
			
			# (3) 外部高饱和霓虹发光轮廓线
			var closed_card = card_points.duplicate()
			closed_card.append(card_points[0])
			draw_polyline(closed_card, border_color, 2.0)
			
			# (4) 绘制现代科学排版信息 (原子序号/类别、元素符号、相对原子质量)
			if font:
				# 顶部小标 (如 gas 53, 42, 61, 35)
				draw_string(font, center + Vector2(-25, -12), top_text, HORIZONTAL_ALIGNMENT_CENTER, 50.0, 9, Color(text_color.r, text_color.g, text_color.b, 0.75))
				
				# 中心宏大元素大符号 (如 H, C, O, Cu, Fe) - 仅在未放置资源实体时绘制，避免与实体图标重叠
				if res_key == "" or GameState.depleted_tiles.has(coord):
					draw_string(font, center + Vector2(-25, 7), sym, HORIZONTAL_ALIGNMENT_CENTER, 50.0, 20, text_color)
				
				# 底部科学原子量 (如 1.008, 12.011, 15.999)
				draw_string(font, center + Vector2(-30, 22), sub_text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 9, Color(text_color.r, text_color.g, text_color.b, 0.65))
				
		else:
			# === 未解锁地块：暗蓝科技微光透视线框 ===
			var card_radius = HexWorldGenerator.HEX_RADIUS * 0.90
			var dark_points = PackedVector2Array()
			for i in range(6):
				var angle = deg_to_rad(60.0 * i - 30.0)
				dark_points.append(center + Vector2(cos(angle), sin(angle)) * card_radius)
			dark_points.append(dark_points[0])
			
			draw_colored_polygon(dark_points, Color(0.08, 0.12, 0.18, 0.35))
			draw_polyline(dark_points, Color(0.18, 0.26, 0.38, 0.45), 1.0)
			
	# 4. 绘制领地外缘发光金色轮廓线 (Territory Outermost Border Glow)
	for coord in generated_hexes.keys():
		if GameState.is_hex_in_territory(coord.x, coord.y):
			var c = HexWorldGenerator.hex_to_pixel(coord.x, coord.y)
			for i in range(6):
				var neighbor = coord + HEX_EDGE_DIRS[i]
				if not GameState.is_hex_in_territory(neighbor.x, neighbor.y):
					var a1 = deg_to_rad(60.0 * i - 30.0)
					var a2 = deg_to_rad(60.0 * ((i + 1) % 6) - 30.0)
					var p1 = c + Vector2(cos(a1), sin(a1)) * HexWorldGenerator.HEX_RADIUS
					var p2 = c + Vector2(cos(a2), sin(a2)) * HexWorldGenerator.HEX_RADIUS
					draw_line(p1, p2, Color(0.22, 0.74, 0.97, 0.35), 6.0)
					draw_line(p1, p2, Color(0.22, 0.74, 0.97, 0.95), 2.2)

	# 5. 绘制外围立体悬浮云团 (Fluffy Atmospheric 3D Clouds)
	_draw_ambient_clouds()

# 绘制深海蓝图背景网格 (Scientific Blueprint Coordinate Grid)
func _draw_blueprint_grid() -> void:
	var grid_color = Color(0.12, 0.18, 0.28, 0.35)
	var extent = 1200.0
	var step = 48.0
	
	var start_x = -extent
	while start_x <= extent:
		draw_line(Vector2(start_x, -extent), Vector2(start_x, extent), grid_color, 1.0)
		start_x += step
		
	var start_y = -extent
	while start_y <= extent:
		draw_line(Vector2(-extent, start_y), Vector2(extent, start_y), grid_color, 1.0)
		start_y += step

# 绘制外向科学数据回路与浮动元素标牌 (Data Circuit Lines & Outer Nodes)
func _draw_data_circuit_lines() -> void:
	var line_col = Color(0.22, 0.74, 0.97, 0.65)
	var font = ThemeDB.fallback_font
	
	# 左侧外向数据线与 [H] / [C] 标牌
	var left_nodes = [
		{"pos": Vector2(-280, -90), "sym": "H", "border": Color(0.22, 0.74, 0.97, 0.95)},
		{"pos": Vector2(-360, 0), "sym": "H", "border": Color(0.22, 0.74, 0.97, 0.95)},
		{"pos": Vector2(-310, 95), "sym": "C", "border": Color(0.50, 0.60, 0.75, 0.85)},
		{"pos": Vector2(-260, 180), "sym": "O", "border": Color(0.95, 0.45, 0.48, 0.95)}
	]
	
	for n in left_nodes:
		var p = n.pos as Vector2
		# 连接水平导线
		draw_line(Vector2(p.x, p.y), Vector2(p.x + 120, p.y), Color(0.22, 0.74, 0.97, 0.35), 1.5)
		draw_circle(Vector2(p.x + 120, p.y), 3.0, Color(0.22, 0.74, 0.97, 0.8))
		
		# 浮动六边形小胶囊
		_draw_small_hex_pill(p, 22.0, n.border, n.sym, font)
		
	# 右侧外向数据线与 [H] / [C] / [O] 标牌
	var right_nodes = [
		{"pos": Vector2(280, -90), "sym": "H", "border": Color(0.22, 0.74, 0.97, 0.95)},
		{"pos": Vector2(330, 45), "sym": "C", "border": Color(0.50, 0.60, 0.75, 0.85)},
		{"pos": Vector2(350, 110), "sym": "O", "border": Color(0.95, 0.45, 0.48, 0.95)},
		{"pos": Vector2(270, 195), "sym": "H", "border": Color(0.22, 0.74, 0.97, 0.95)}
	]
	
	for n in right_nodes:
		var p = n.pos as Vector2
		draw_line(Vector2(p.x - 120, p.y), Vector2(p.x, p.y), Color(0.22, 0.74, 0.97, 0.35), 1.5)
		draw_circle(Vector2(p.x - 120, p.y), 3.0, Color(0.22, 0.74, 0.97, 0.8))
		_draw_small_hex_pill(p, 22.0, n.border, n.sym, font)

func _draw_small_hex_pill(center: Vector2, radius: float, border_col: Color, sym: String, font: Font) -> void:
	var pts = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var closed = pts.duplicate()
	closed.append(pts[0])
	
	draw_colored_polygon(pts, Color(0.08, 0.12, 0.18, 0.95))
	draw_polyline(closed, border_col, 2.0)
	if font:
		draw_string(font, center + Vector2(-15, 6), sym, HORIZONTAL_ALIGNMENT_CENTER, 30.0, 15, border_col)

# 计算元素卡片的详细科学参数 (严格对照效果图方案三视觉)
func _get_element_cell_info(biome: HexWorldGenerator.BiomeType, res: String) -> Dictionary:
	# 铜元素卡片 (Cu - 暖铜陶白)
	if res == "malachite":
		return {
			"fill": Color(0.98, 0.92, 0.86, 0.98),
			"border": Color(0.92, 0.55, 0.22, 0.95),
			"text_color": Color(0.68, 0.30, 0.08, 1.0),
			"symbol": "Cu",
			"top_text": "35",
			"sub_text": "63.55"
		}
	# 铁元素卡片 (Fe - 暖灰金属白)
	elif res == "iron_ore" or res == "pyrite":
		return {
			"fill": Color(0.94, 0.92, 0.88, 0.98),
			"border": Color(0.88, 0.65, 0.18, 0.95),
			"text_color": Color(0.55, 0.35, 0.08, 1.0),
			"symbol": "Fe",
			"top_text": "28",
			"sub_text": "55.85"
		}
	# 碳元素卡片 (C - 纯白冷灰)
	elif res == "wood" or res == "stick" or biome == HexWorldGenerator.BiomeType.DEEP_FOREST:
		return {
			"fill": Color(0.92, 0.94, 0.96, 0.98),
			"border": Color(0.40, 0.50, 0.65, 0.85),
			"text_color": Color(0.15, 0.20, 0.28, 1.0),
			"symbol": "C",
			"top_text": "42",
			"sub_text": "12.011"
		}
	# 氧/卤水卡片 (O - 柔和珊瑚白)
	elif res == "halite" or biome == HexWorldGenerator.BiomeType.SALT_LAKE:
		return {
			"fill": Color(0.98, 0.90, 0.91, 0.98),
			"border": Color(0.95, 0.45, 0.48, 0.95),
			"text_color": Color(0.75, 0.18, 0.22, 1.0),
			"symbol": "O",
			"top_text": "61",
			"sub_text": "15.999"
		}
	# 硫元素卡片 (S - 亮黄白)
	elif res == "sulfur":
		return {
			"fill": Color(0.98, 0.96, 0.85, 0.98),
			"border": Color(0.90, 0.75, 0.15, 0.95),
			"text_color": Color(0.60, 0.45, 0.05, 1.0),
			"symbol": "S",
			"top_text": "16",
			"sub_text": "32.06"
		}
	# 默认氢/气体原野卡片 (H - 冰蓝瓷白)
	else:
		return {
			"fill": Color(0.88, 0.96, 0.99, 0.98),
			"border": Color(0.22, 0.74, 0.97, 0.95),
			"text_color": Color(0.08, 0.45, 0.65, 1.0),
			"symbol": "H",
			"top_text": "gas 53",
			"sub_text": "1.008"
		}

# 绘制外围立体悬浮云团 (匹配效果图 Scheme 3 边缘蓬松云层)
func _draw_ambient_clouds() -> void:
	var cloud_clusters = [
		Vector2(-380, -220),
		Vector2(380, -210),
		Vector2(-430, 230),
		Vector2(400, 250)
	]
	for root in cloud_clusters:
		_draw_fluffy_cloud(root)

func _draw_fluffy_cloud(center: Vector2) -> void:
	var puffs = [
		{"off": Vector2(-42, 0), "r": 28.0, "a": 0.82},
		{"off": Vector2(-22, -14), "r": 36.0, "a": 0.90},
		{"off": Vector2(10, -18), "r": 40.0, "a": 0.95},
		{"off": Vector2(42, -6), "r": 32.0, "a": 0.88},
		{"off": Vector2(25, 12), "r": 28.0, "a": 0.85},
		{"off": Vector2(-15, 14), "r": 30.0, "a": 0.85},
		{"off": Vector2(0, 0), "r": 44.0, "a": 0.98}
	]
	# 1. 底层环境沉降阴影 (柔和深藏青)
	for p in puffs:
		draw_circle(center + p.off + Vector2(0, 10), p.r * 1.06, Color(0.02, 0.04, 0.08, 0.35))
	# 2. 主体纯净云朵质感
	for p in puffs:
		draw_circle(center + p.off, p.r, Color(0.96, 0.98, 1.0, p.a))
	# 3. 顶部微光高光
	for p in puffs:
		draw_circle(center + p.off + Vector2(-3, -5), p.r * 0.72, Color(1.0, 1.0, 1.0, 0.45))
