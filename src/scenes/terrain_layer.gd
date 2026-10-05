# terrain_layer.gd
# 领地内采用无缝融合自然群系地貌绘图；未解锁地貌采用全屏动态暗色瓦片透视线框；领地仅描最外圈金边
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
var current_lod: int = 1 # 0: 远景简略 (zoom < 0.85), 1: 近景精细 (zoom >= 0.85)

func _draw() -> void:
	if not world or world.generated_hexes.is_empty():
		return
		
	var generated_hexes = world.generated_hexes
	
	# 1. 计算视口在世界坐标系下的包围盒，确保整个屏幕完全铺满六边形
	var cam = world.camera if world else null
	var center_pos = cam.get_screen_center_position() if cam else Vector2.ZERO
	var vp_size = get_viewport_rect().size if get_viewport() else Vector2(1920, 1080)
	var cam_zoom = cam.zoom if (cam and cam.zoom.x > 0.01) else Vector2.ONE
	var half_w = (vp_size.x / cam_zoom.x) * 0.5
	var half_h = (vp_size.y / cam_zoom.y) * 0.5
	
	var min_x = center_pos.x - half_w
	var max_x = center_pos.x + half_w
	var min_y = center_pos.y - half_h
	var max_y = center_pos.y + half_h
		
	# 绘制深海蓝图背景网格 (动态全屏覆盖)
	_draw_blueprint_grid(min_x - 300.0, max_x + 300.0, min_y - 300.0, max_y + 300.0)
	
	# 2. 遍历整个屏幕可见范围内的所有六边形 (q, r)，实现 100% 铺满全屏
	var pad = HexWorldGenerator.HEX_RADIUS * 2.5
	var r_min = int(floor((min_y - pad) / (HexWorldGenerator.HEX_RADIUS * 1.5)))
	var r_max = int(ceil((max_y + pad) / (HexWorldGenerator.HEX_RADIUS * 1.5)))
	var col_w = HexWorldGenerator.HEX_RADIUS * sqrt(3.0)
	var sqrt3_half = HexWorldGenerator.HEX_RADIUS * (sqrt(3.0) / 2.0)
	
	for r in range(r_min, r_max + 1):
		var r_shift = sqrt3_half * float(r)
		var q_min = int(floor((min_x - pad - r_shift) / col_w))
		var q_max = int(ceil((max_x + pad - r_shift) / col_w))
		for q in range(q_min, q_max + 1):
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
					draw_circle(center, 10.0, Color(base_col.r * 1.15, base_col.g * 1.15, base_col.b * 1.15, 0.25))
				
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
						draw_circle(pt, 1.5, Color(1.0, 1.0, 1.0, 0.15))
			else:
				# === 未解锁地块：暗色瓦片透视线框 (铺满整个视野与全图) ===
				var card_radius = HexWorldGenerator.HEX_RADIUS * 0.90
				var dark_points = PackedVector2Array()
				for i in range(6):
					var angle = deg_to_rad(60.0 * i - 30.0)
					dark_points.append(center + Vector2(cos(angle), sin(angle)) * card_radius)
				dark_points.append(dark_points[0])
				
				draw_colored_polygon(dark_points, Color(0.08, 0.12, 0.18, 0.35))
				draw_polyline(dark_points, Color(0.18, 0.26, 0.38, 0.45), 1.0)
				
	# 3. 绘制领地最外圈发光金边 (仅描最外圈边界)
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
					draw_line(p1, p2, Color(1.0, 0.85, 0.2, 0.35), 4.5)
					draw_line(p1, p2, Color(1.0, 0.90, 0.35, 0.95), 1.8)

# 群系连通融合绘制系统
func _draw_connected_biome_terrain(center: Vector2, points: PackedVector2Array, biome: HexWorldGenerator.BiomeType, same_neighbors: Array[int], _q: int, _r: int) -> void:
	match biome:
		HexWorldGenerator.BiomeType.VOLCANO:
			draw_circle(center + Vector2(0, 1), 12.0, Color(0.12, 0.04, 0.03, 0.9))
			draw_circle(center, 7.5, Color(0.85, 0.25, 0.08, 0.92))
			draw_circle(center, 3.5, Color(1.0, 0.85, 0.25, 0.98))
			draw_circle(center, 1.5, Color(1.0, 0.98, 0.80, 1.0))
			
			for e in same_neighbors:
				if (e + _q * 2 + _r) % 3 == 0:
					var p1 = points[e]
					var p2 = points[(e + 1) % 6]
					var edge_mid = (p1 + p2) * 0.5
					var delta_v = edge_mid - center
					var norm = Vector2(-delta_v.y, delta_v.x).normalized()
					var bend_mag = sin(float(_q * 43 + _r * 71 + e * 23)) * 3.0
					var waypoint = (center + edge_mid) * 0.5 + norm * bend_mag
					
					draw_polyline([center, waypoint, edge_mid], Color(0.85, 0.20, 0.05, 0.25), 5.0)
					draw_polyline([center, waypoint, edge_mid], Color(0.12, 0.05, 0.04, 0.85), 3.2)
					draw_polyline([center, waypoint, edge_mid], Color(1.0, 0.45, 0.12, 0.95), 1.8)
					draw_polyline([center, waypoint, edge_mid], Color(1.0, 0.90, 0.45, 0.95), 0.8)
				
		HexWorldGenerator.BiomeType.SALT_LAKE:
			draw_arc(center + Vector2(-4, -2), 14.0, 0.2, PI - 0.2, 12, Color(0.55, 0.80, 0.95, 0.35), 2.2)
			draw_arc(center + Vector2(6, 4), 10.0, PI + 0.2, TAU - 0.2, 10, Color(0.65, 0.88, 1.0, 0.30), 2.0)
			
			for e in same_neighbors:
				var p1 = points[e]
				var p2 = points[(e + 1) % 6]
				var edge_mid = (p1 + p2) * 0.5
				var wave_center = (center + edge_mid) * 0.5
				draw_arc(wave_center, 9.0, 0, PI, 8, Color(0.60, 0.85, 1.0, 0.35), 1.8)
				
		HexWorldGenerator.BiomeType.DEEP_FOREST:
			draw_circle(center + Vector2(0, 4), 18.0, Color(0.04, 0.10, 0.05, 0.45))
			draw_circle(center, 16.0, Color(0.07, 0.16, 0.09))
			draw_circle(center + Vector2(-2, -3), 13.0, Color(0.13, 0.30, 0.15))
			draw_circle(center + Vector2(-3, -5), 8.5, Color(0.22, 0.48, 0.22))
			draw_circle(center + Vector2(2, -6), 5.5, Color(0.35, 0.65, 0.32))
			
			for e in same_neighbors:
				var p1 = points[e]
				var p2 = points[(e + 1) % 6]
				var edge_mid = (p1 + p2) * 0.5
				var bridge_pos = center * 0.45 + edge_mid * 0.55
				draw_circle(bridge_pos + Vector2(0, 3), 12.0, Color(0.04, 0.10, 0.05, 0.4))
				draw_circle(bridge_pos, 11.0, Color(0.08, 0.18, 0.10))
				draw_circle(bridge_pos + Vector2(-2, -2), 8.0, Color(0.15, 0.34, 0.17))
				draw_circle(bridge_pos + Vector2(-3, -3), 5.0, Color(0.25, 0.54, 0.25))
				
		HexWorldGenerator.BiomeType.PLAINS:
			draw_arc(center + Vector2(-6, -4), 12.0, 0.3, PI - 0.3, 10, Color(0.28, 0.44, 0.24, 0.40), 1.5)
			draw_arc(center + Vector2(8, 6), 9.0, PI + 0.3, TAU - 0.3, 8, Color(0.32, 0.48, 0.26, 0.35), 1.5)
			for e in same_neighbors:
				var p1 = points[e]
				var p2 = points[(e + 1) % 6]
				var edge_mid = (p1 + p2) * 0.5
				var mid_pos = center * 0.5 + edge_mid * 0.5
				draw_line(mid_pos + Vector2(-3, 0), mid_pos + Vector2(-4, -5), Color(0.34, 0.54, 0.28), 1.3)
				draw_line(mid_pos + Vector2(-3, 0), mid_pos + Vector2(-1, -6), Color(0.36, 0.58, 0.30), 1.3)
				draw_circle(mid_pos + Vector2(3, 2), 1.8, Color(0.95, 0.88, 0.38, 0.70))

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

# 异群系交界处自然有机过渡散落系统 (水草沙洲、泥泞湿地、落灰熔岩纹、林缘苔藓)
func _draw_natural_biome_transition(p1: Vector2, p2: Vector2, my_biome: HexWorldGenerator.BiomeType, n_biome: HexWorldGenerator.BiomeType, center: Vector2, coord: Vector2i, edge_idx: int) -> void:
	var edge_mid = (p1 + p2) * 0.5
	var inward = (center - edge_mid).normalized()
	var tangent = (p2 - p1).normalized()
	var edge_seed = float(coord.x * 53 + coord.y * 97 + edge_idx * 13)
	
	# 1. 盐湖与陆地 (原野/森林/火山) 交界：滩涂湖岸与浅水沙洲柔和微观结构
	if my_biome == HexWorldGenerator.BiomeType.SALT_LAKE or n_biome == HexWorldGenerator.BiomeType.SALT_LAKE:
		# 渐变过渡带微波水纹
		if my_biome == HexWorldGenerator.BiomeType.SALT_LAKE:
			# 水域一侧微弧水纹
			var wave_center = edge_mid + inward * 4.0
			draw_arc(wave_center, 8.0, -0.6, 0.6, 6, Color(0.65, 0.85, 0.98, 0.28), 1.5)
		else:
			# 陆地一侧湿润泥沙斑与微小卵石
			if current_lod >= 1:
				for k in range(2):
					var t = 0.35 + 0.3 * float(k) + sin(edge_seed + k) * 0.1
					var pos = p1.lerp(p2, t) + inward * (2.0 + sin(edge_seed * 2.0 + k) * 1.5)
					draw_circle(pos, 1.6, Color(0.55, 0.68, 0.60, 0.35))
		return
		
	# 2. 火山与原野/森林交界：焦土落灰与岩缝地貌
	if my_biome == HexWorldGenerator.BiomeType.VOLCANO or n_biome == HexWorldGenerator.BiomeType.VOLCANO:
		if my_biome == HexWorldGenerator.BiomeType.VOLCANO:
			# 火山一侧微弱地表温热发丝裂纹
			var crack_pt = edge_mid + inward * 5.0 + tangent * sin(edge_seed) * 4.0
			draw_line(edge_mid, crack_pt, Color(0.85, 0.35, 0.12, 0.30), 1.0)
		else:
			# 陆地一侧炭黑灰斑
			if current_lod >= 1:
				var ash_pos = edge_mid + inward * 2.5
				draw_circle(ash_pos, 2.0, Color(0.18, 0.14, 0.12, 0.25))
		return
		
	# 3. 原始森林与原野交界：林缘树荫苔草自然过渡
	if my_biome == HexWorldGenerator.BiomeType.DEEP_FOREST or n_biome == HexWorldGenerator.BiomeType.DEEP_FOREST:
		if my_biome == HexWorldGenerator.BiomeType.DEEP_FOREST:
			# 树荫投影半弧
			draw_arc(edge_mid + inward * 2.0, 9.0, 0, PI, 6, Color(0.06, 0.14, 0.08, 0.30), 1.6)

# 绘制深海蓝图背景网格 (根据视口坐标范围动态平铺)
func _draw_blueprint_grid(start_x: float, end_x: float, start_y: float, end_y: float) -> void:
	var grid_color = Color(0.12, 0.18, 0.28, 0.35)
	var step = 48.0
	
	var cur_x = floor(start_x / step) * step
	while cur_x <= end_x:
		draw_line(Vector2(cur_x, start_y), Vector2(cur_x, end_y), grid_color, 1.0)
		cur_x += step
		
	var cur_y = floor(start_y / step) * step
	while cur_y <= end_y:
		draw_line(Vector2(start_x, cur_y), Vector2(end_x, cur_y), grid_color, 1.0)
		cur_y += step
