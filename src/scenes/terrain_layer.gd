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
	var vp = get_viewport()
	var vp_rect = vp.get_visible_rect() if vp else Rect2(-1920, -1080, 3840, 2160)
	var inv_xform = get_canvas_transform().affine_inverse()
	
	var corners = [
		inv_xform * vp_rect.position,
		inv_xform * Vector2(vp_rect.end.x, vp_rect.position.y),
		inv_xform * vp_rect.end,
		inv_xform * Vector2(vp_rect.position.x, vp_rect.end.y)
	]
	var min_x = corners[0].x
	var max_x = corners[0].x
	var min_y = corners[0].y
	var max_y = corners[0].y
	for c in corners:
		min_x = min(min_x, c.x)
		max_x = max(max_x, c.x)
		min_y = min(min_y, c.y)
		max_y = max(max_y, c.y)
		
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
				# === 已解锁领地：渲染自然群系底色与连通地貌 ===
				var biome = generated_hexes.get(coord, HexWorldGenerator.BiomeType.PLAINS)
				var base_col = HexWorldGenerator.get_biome_color(biome)
				draw_colored_polygon(points, base_col)
				
				if current_lod >= 1:
					var same_biome_neighbors: Array[int] = []
					for e in range(6):
						var n_coord = coord + HEX_EDGE_DIRS[e]
						if generated_hexes.has(n_coord) and GameState.is_hex_in_territory(n_coord.x, n_coord.y) and generated_hexes[n_coord] == biome:
							same_biome_neighbors.append(e)
					_draw_connected_biome_terrain(center, points, biome, same_biome_neighbors, q, r)
				else:
					draw_circle(center, 10.0, Color(base_col.r * 1.15, base_col.g * 1.15, base_col.b * 1.15, 0.25))
				
				# 领地内不同群系交界处的柔和自然羽化过渡
				for e in range(6):
					var n_coord = coord + HEX_EDGE_DIRS[e]
					if generated_hexes.has(n_coord) and GameState.is_hex_in_territory(n_coord.x, n_coord.y):
						var n_biome = generated_hexes[n_coord]
						if n_biome != biome:
							var p1 = points[e]
							var p2 = points[(e + 1) % 6]
							_draw_natural_biome_transition(p1, p2, biome, n_biome, center)
						
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

# 异群系交界处自然柔和羽化过渡 (去除生硬锯齿白线，采用滩涂沙洲、林缘树荫、焦灰过渡带)
func _draw_natural_biome_transition(p1: Vector2, p2: Vector2, my_biome: HexWorldGenerator.BiomeType, n_biome: HexWorldGenerator.BiomeType, center: Vector2) -> void:
	var edge_mid = (p1 + p2) * 0.5
	var inward = (center - edge_mid).normalized()
	
	# 1. 盐湖与陆地 (原野/森林/火山) 交界：柔和滩涂湖岸与湿地浅水过渡带
	if my_biome == HexWorldGenerator.BiomeType.SALT_LAKE or n_biome == HexWorldGenerator.BiomeType.SALT_LAKE:
		# 浅滩泥沙底晕 (柔和沙褐色，消除纯白硬边)
		draw_line(p1, p2, Color(0.42, 0.54, 0.50, 0.45), 5.5)
		# 湿润潮汐微波
		draw_line(p1 + inward * 2.0, p2 + inward * 2.0, Color(0.50, 0.68, 0.76, 0.35), 2.5)
		# 岸边微量盐结晶与卵石点缀 (随缩放自适应)
		if current_lod >= 1:
			draw_circle(edge_mid + inward * 1.5, 2.2, Color(0.78, 0.88, 0.90, 0.50))
		return
		
	# 2. 火山与原野/森林交界：焦土落灰过渡带
	if my_biome == HexWorldGenerator.BiomeType.VOLCANO or n_biome == HexWorldGenerator.BiomeType.VOLCANO:
		# 焦黑浮灰晕线
		draw_line(p1, p2, Color(0.22, 0.18, 0.15, 0.55), 4.0)
		if current_lod >= 1:
			draw_circle(edge_mid, 2.0, Color(0.38, 0.22, 0.16, 0.40))
		return
		
	# 3. 原始森林与原野交界：林缘苔草树荫自然过渡
	if my_biome == HexWorldGenerator.BiomeType.DEEP_FOREST or n_biome == HexWorldGenerator.BiomeType.DEEP_FOREST:
		draw_line(p1, p2, Color(0.14, 0.25, 0.15, 0.50), 3.8)

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
