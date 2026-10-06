# terrain_layer.gd
# 地质测绘图风格：领地内为浅色群系底色 + 墨线地图符号；未解锁区域为图纸白与铅笔网格；领地仅描最外圈边界
extends Node2D

const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")
const ThemeStyler = preload("res://src/ui/theme_styler.gd")

const HEX_EDGE_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),   # edge 0: vertex 0 -> 1 (East)
	Vector2i(0, 1),   # edge 1: vertex 1 -> 2 (Southeast)
	Vector2i(-1, 1),  # edge 2: vertex 2 -> 3 (Southwest)
	Vector2i(-1, 0),  # edge 3: vertex 3 -> 4 (West)
	Vector2i(0, -1),  # edge 4: vertex 4 -> 5 (Northwest)
	Vector2i(1, -1)   # edge 5: vertex 5 -> 0 (Northeast)
]

# 六边形绘制半径：地图 (18 圈) 外再铺 8 圈未解锁图纸格；更远处只画廉价的测绘网格线
const DRAW_HEX_RADIUS: int = 26
const GRID_EXTENT: float = 4200.0

var world: Node2D = null
var current_lod: int = 1 # 0: 远景简略 (zoom < 0.85), 1: 近景精细 (zoom >= 0.85)

func _draw() -> void:
	if not world or world.generated_hexes.is_empty():
		return
		
	var generated_hexes = world.generated_hexes
	
	# 1. 绘制固定范围 (与镜头无关)：仅在世界生成 / 时代跃迁 / LOD 切换 / 读档时重绘，
	#    镜头平移与缩放只移动 Camera2D，复用 CanvasItem 已缓存的绘制指令，不再逐帧重建。
	_draw_blueprint_grid(-GRID_EXTENT, GRID_EXTENT, -GRID_EXTENT, GRID_EXTENT)
	
	# 2. 遍历固定半径内的全部六边形 (地图 + 外围未解锁图纸区)
	for r in range(-DRAW_HEX_RADIUS, DRAW_HEX_RADIUS + 1):
		var q_lo = max(-DRAW_HEX_RADIUS, -r - DRAW_HEX_RADIUS)
		var q_hi = min(DRAW_HEX_RADIUS, -r + DRAW_HEX_RADIUS)
		for q in range(q_lo, q_hi + 1):
			var coord = Vector2i(q, r)
			var center = HexWorldGenerator.hex_to_pixel(q, r)
			var in_territory = GameState.is_hex_in_territory(q, r)
			
			# 六边形 6 个基础顶点
			var points = PackedVector2Array()
			for i in range(6):
				var angle = deg_to_rad(60.0 * i - 30.0)
				points.append(center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS)
				
			if in_territory:
				# === 已解锁领地：渲染自然群系平滑渐变底色与连通地貌 ===
				var biome = generated_hexes.get(coord, HexWorldGenerator.BiomeType.PLAINS)
				_draw_gradient_biome_hex(center, coord, biome, points, generated_hexes)
				
				if current_lod >= 1:
					var same_biome_neighbors: Array[int] = []
					for e in range(6):
						var n_coord = coord + HEX_EDGE_DIRS[e]
						if generated_hexes.has(n_coord) and GameState.is_hex_in_territory(n_coord.x, n_coord.y) and generated_hexes[n_coord] == biome:
							same_biome_neighbors.append(e)
					_draw_connected_biome_terrain(center, points, biome, same_biome_neighbors, q, r)
				else:
					var base_col = HexWorldGenerator.get_biome_color(biome)
					draw_circle(center, 3.0, base_col.darkened(0.35))
				
				# 领地内不同群系交界处的自然有机散落过渡
				for e in range(6):
					var n_coord = coord + HEX_EDGE_DIRS[e]
					if generated_hexes.has(n_coord) and GameState.is_hex_in_territory(n_coord.x, n_coord.y):
						var n_biome = generated_hexes[n_coord]
						if n_biome != biome:
							var p1 = points[e]
							var p2 = points[(e + 1) % 6]
							_draw_natural_biome_transition(p1, p2, biome, n_biome, center, coord, e)
						
				# 战术六边形微弱顶点标记
				if current_lod >= 1:
					for pt in points:
						draw_circle(pt, 1.2, Color(0.20, 0.18, 0.15, 0.12))
			else:
				# === 未解锁地块：暗色瓦片透视线框 (铺满整个视野与全图) ===
				var card_radius = HexWorldGenerator.HEX_RADIUS * 0.90
				var dark_points = PackedVector2Array()
				for i in range(6):
					var angle = deg_to_rad(60.0 * i - 30.0)
					dark_points.append(center + Vector2(cos(angle), sin(angle)) * card_radius)
				dark_points.append(dark_points[0])
				
				draw_colored_polygon(dark_points, Color(0.95, 0.93, 0.89, 0.85))
				draw_polyline(dark_points, Color(0.55, 0.50, 0.43, 0.30), 1.0)
				
	# 3. 绘制领地最外圈边界 (仅描最外圈，颜色随时代强调色)
	var border_col: Color = ThemeStyler.get_era_accent(GameState.current_era)
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
					# 测绘图行政边界：时代色柔晕 + 深色虚线
					draw_line(p1, p2, Color(border_col.r, border_col.g, border_col.b, 0.28), 6.0)
					draw_dashed_line(p1, p2, border_col.darkened(0.25), 2.2, 7.0)

# 群系地图符号绘制 (地质测绘图图例风格：墨线符号，低对比、少而精)
func _draw_connected_biome_terrain(center: Vector2, points: PackedVector2Array, biome: HexWorldGenerator.BiomeType, same_neighbors: Array[int], _q: int, _r: int) -> void:
	var seed_f = float(_q * 73 + _r * 151)
	match biome:
		HexWorldGenerator.BiomeType.VOLCANO:
			# 火山：晕滃线 (hachure) 山体符号 + 熔岩脉细红线
			var peak = center + Vector2(0, -2)
			draw_colored_polygon(PackedVector2Array([peak + Vector2(-9, 7), peak + Vector2(0, -7), peak + Vector2(9, 7)]), Color(0.55, 0.32, 0.24, 0.45))
			for k in range(5):
				var base_pt = peak + Vector2(-9, 7).lerp(Vector2(9, 7), float(k) / 4.0)
				var top_pt = (peak + Vector2(0, -7)).lerp(base_pt, 0.35)
				draw_line(top_pt, base_pt, Color(0.35, 0.18, 0.12, 0.55), 1.0)
			draw_circle(peak + Vector2(0, -7), 1.8, Color(0.80, 0.30, 0.18, 0.9))
			for e in same_neighbors:
				if (e + _q * 2 + _r) % 3 == 0:
					var edge_mid = (points[e] + points[(e + 1) % 6]) * 0.5
					var delta_v = edge_mid - center
					var norm = Vector2(-delta_v.y, delta_v.x).normalized()
					var waypoint = (center + edge_mid) * 0.5 + norm * sin(seed_f + e * 23.0) * 3.0
					draw_polyline([center + Vector2(0, 6), waypoint, edge_mid], Color(0.75, 0.28, 0.16, 0.55), 1.4)

		HexWorldGenerator.BiomeType.SALT_LAKE:
			# 盐湖：水域平行波纹 (地图水体符号) + 盐渍白点
			var wave_col = Color(0.28, 0.45, 0.55, 0.45)
			for k in range(3):
				var y = -8.0 + float(k) * 8.0
				var x0 = -11.0 + sin(seed_f + k) * 2.0
				var pts = PackedVector2Array()
				for j in range(7):
					pts.append(center + Vector2(x0 + float(j) * 3.6, y + (1.2 if j % 2 == 0 else -1.2)))
				draw_polyline(pts, wave_col, 1.0)
			draw_circle(center + Vector2(9, 9), 1.4, Color(1, 1, 1, 0.7))
			draw_circle(center + Vector2(-10, 6), 1.1, Color(1, 1, 1, 0.6))

		HexWorldGenerator.BiomeType.DEEP_FOREST:
			# 深林：林地符号 (圆冠 + 树干)，向相邻林地延伸
			_draw_tree_symbol(center + Vector2(-6, 2))
			_draw_tree_symbol(center + Vector2(6, -3))
			for e in same_neighbors:
				if e % 2 == 0:
					var edge_mid = (points[e] + points[(e + 1) % 6]) * 0.5
					_draw_tree_symbol(center * 0.45 + edge_mid * 0.55)

		HexWorldGenerator.BiomeType.PLAINS:
			# 原野：稀疏草丛符号 (ψ 形短笔触)
			var grass = Color(0.36, 0.45, 0.28, 0.55)
			for k in range(2):
				var gp = center + Vector2(cos(seed_f + k * 2.4), sin(seed_f + k * 2.4)) * 9.0
				draw_line(gp, gp + Vector2(0, -4), grass, 1.0)
				draw_line(gp, gp + Vector2(-2.5, -3), grass, 1.0)
				draw_line(gp, gp + Vector2(2.5, -3), grass, 1.0)

func _draw_tree_symbol(pos: Vector2) -> void:
	draw_line(pos + Vector2(0, 2), pos + Vector2(0, 6), Color(0.30, 0.25, 0.18, 0.7), 1.2)
	draw_circle(pos, 4.5, Color(0.30, 0.45, 0.30, 0.55))
	draw_arc(pos, 4.5, 0, TAU, 12, Color(0.18, 0.28, 0.18, 0.75), 1.0)

# 渐变过渡群系绘图系统：中心保持本群系核心纯色，外周多边形通过三角扇面 Gouraud 顶点色彩平滑过渡至邻居群系
func _draw_gradient_biome_hex(center: Vector2, coord: Vector2i, biome: HexWorldGenerator.BiomeType, outer_pts: PackedVector2Array, generated_hexes: Dictionary) -> void:
	var base_col = HexWorldGenerator.get_biome_color(biome)
	
	# 微观地质随机微扰动，赋予每个瓦片独特的生命力 (避免绝对死板纯色)
	var tile_hash = sin(float(coord.x * 374761393 + coord.y * 668265263)) * 43758.5453
	var perturb = (tile_hash - floor(tile_hash)) * 0.04 - 0.02
	var center_col = Color(
		clampf(base_col.r + perturb, 0.0, 1.0),
		clampf(base_col.g + perturb, 0.0, 1.0),
		clampf(base_col.b + perturb * 0.7, 0.0, 1.0),
		1.0
	)
	
	# 1. 瓦片中心核心多边形 (半径 38% 的纯本群系核心，外周 62% 均为平滑渐变裙边)
	var inner_r = HexWorldGenerator.HEX_RADIUS * 0.38
	var inner_pts = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * i - 30.0)
		inner_pts.append(center + Vector2(cos(angle), sin(angle)) * inner_r)
	draw_colored_polygon(inner_pts, center_col)
	
	# 2. 计算 6 个外圈顶点的 3 向交界融合色彩 (数学对称完全消除色差缝隙)
	var vertex_cols: Array[Color] = []
	for i in range(6):
		var dir_prev = HEX_EDGE_DIRS[(i + 5) % 6]
		var dir_curr = HEX_EDGE_DIRS[i]
		
		var n_prev = coord + dir_prev
		var n_curr = coord + dir_curr
		
		var col_prev = base_col
		if generated_hexes.has(n_prev) and GameState.is_hex_in_territory(n_prev.x, n_prev.y):
			col_prev = HexWorldGenerator.get_biome_color(generated_hexes[n_prev])
			
		var col_curr = base_col
		if generated_hexes.has(n_curr) and GameState.is_hex_in_territory(n_curr.x, n_curr.y):
			col_curr = HexWorldGenerator.get_biome_color(generated_hexes[n_curr])
			
		# 三向交界处平滑渐变色彩 (三方均权，跨地块完全连续无跳变)
		var v_col = (base_col + col_prev + col_curr) / 3.0
		vertex_cols.append(v_col)
		
	# 3. 计算 6 条外圈边中点的双向交界融合色彩 (双方各 50%，交界线颜色 100% 严格一致)
	var edge_mid_cols: Array[Color] = []
	for e in range(6):
		var dir_e = HEX_EDGE_DIRS[e]
		var n_e = coord + dir_e
		var col_e = base_col
		if generated_hexes.has(n_e) and GameState.is_hex_in_territory(n_e.x, n_e.y):
			col_e = HexWorldGenerator.get_biome_color(generated_hexes[n_e])
		var m_col = (base_col + col_e) * 0.5
		edge_mid_cols.append(m_col)
		
	# 4. 构建外周过渡裙边的三角扇面，施加 Gouraud 硬件顶点色彩渐变插值
	for e in range(6):
		var next_e = (e + 1) % 6
		var ip1 = inner_pts[e]
		var ip2 = inner_pts[next_e]
		var op1 = outer_pts[e]
		var op2 = outer_pts[next_e]
		var edge_mid = (op1 + op2) * 0.5
		
		var v_col1 = vertex_cols[e]
		var v_col2 = vertex_cols[next_e]
		var m_col = edge_mid_cols[e]
		
		# 三角片 1: [ip1, op1, edge_mid]
		draw_polygon(
			PackedVector2Array([ip1, op1, edge_mid]),
			PackedColorArray([center_col, v_col1, m_col])
		)
		# 三角片 2: [ip1, edge_mid, ip2]
		draw_polygon(
			PackedVector2Array([ip1, edge_mid, ip2]),
			PackedColorArray([center_col, m_col, center_col])
		)
		# 三角片 3: [ip2, edge_mid, op2]
		draw_polygon(
			PackedVector2Array([ip2, edge_mid, op2]),
			PackedColorArray([center_col, m_col, v_col2])
		)

# 异群系交界：测绘图式岸线与轮廓 (仅在一侧绘制，避免重复描边)
func _draw_natural_biome_transition(p1: Vector2, p2: Vector2, my_biome: HexWorldGenerator.BiomeType, n_biome: HexWorldGenerator.BiomeType, center: Vector2, _coord: Vector2i, _edge_idx: int) -> void:
	var inward = (center - (p1 + p2) * 0.5).normalized()
	# 盐湖岸线：水域一侧深蓝细岸线 + 内侧浅色复线
	if my_biome == HexWorldGenerator.BiomeType.SALT_LAKE:
		draw_line(p1 + inward * 1.0, p2 + inward * 1.0, Color(0.22, 0.38, 0.48, 0.65), 1.3)
		draw_line(p1 + inward * 4.0, p2 + inward * 4.0, Color(0.30, 0.48, 0.58, 0.25), 1.0)
		return
	if n_biome == HexWorldGenerator.BiomeType.SALT_LAKE:
		return
	# 火山边缘：短晕滃线
	if my_biome == HexWorldGenerator.BiomeType.VOLCANO:
		for k in range(3):
			var pt = p1.lerp(p2, 0.25 + 0.25 * float(k)) + inward * 2.0
			draw_line(pt, pt + inward * 4.0, Color(0.40, 0.22, 0.15, 0.40), 1.0)
		return
	# 林缘：森林一侧浅墨细线
	if my_biome == HexWorldGenerator.BiomeType.DEEP_FOREST:
		draw_line(p1 + inward * 1.5, p2 + inward * 1.5, Color(0.22, 0.32, 0.22, 0.30), 1.0)

# 绘制测绘图纸经纬网格 (根据视口坐标范围动态平铺)
func _draw_blueprint_grid(start_x: float, end_x: float, start_y: float, end_y: float) -> void:
	var grid_color = Color(0.55, 0.50, 0.43, 0.14)
	var step = 96.0
	
	var cur_x = floor(start_x / step) * step
	while cur_x <= end_x:
		draw_line(Vector2(cur_x, start_y), Vector2(cur_x, end_y), grid_color, 1.0)
		cur_x += step
		
	var cur_y = floor(start_y / step) * step
	while cur_y <= end_y:
		draw_line(Vector2(start_x, cur_y), Vector2(end_x, cur_y), grid_color, 1.0)
		cur_y += step
