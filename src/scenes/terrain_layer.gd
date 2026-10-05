# terrain_layer.gd
# 领地内采用无缝融合自然群系地貌绘图；未解锁地貌采用暗色瓦片透视线框；领地仅描最外圈金边，无外围蓝色双框
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
	
	# 1. 绘制深海蓝图背景网格 (Scientific Blueprint Coordinate Grid)
	_draw_blueprint_grid()
	
	# 2. 遍历渲染全部六边形地块：
	# - 已解锁地块 (in_territory): 渲染真实的群系底色、连通地貌 (海浪/草丛/熔岩/森林) 与群系边缘线
	# - 未解锁地块 (not in_territory): 暗色瓦片显示 (暗蓝科技微光透视线框)
	for coord in generated_hexes.keys():
		var q = coord.x
		var r = coord.y
		var biome = generated_hexes[coord]
		var center = HexWorldGenerator.hex_to_pixel(q, r)
		var in_territory = GameState.is_hex_in_territory(q, r)
		
		# 计算六边形 6 个顶点
		var points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			points.append(center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS)
			
		if in_territory:
			# === 已解锁领地：渲染群系底色与无缝连通地貌 ===
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
				# 远景模式 (LOD 0)：采用极度柔和的微弱中心晕色，避免杂乱
				draw_circle(center, 10.0, Color(base_col.r * 1.15, base_col.g * 1.15, base_col.b * 1.15, 0.25))
			
			# 仅在领地内不同群系交界处绘制过渡海岸/崖线
			for e in range(6):
				var n_coord = coord + HEX_EDGE_DIRS[e]
				var is_same = generated_hexes.has(n_coord) and GameState.is_hex_in_territory(n_coord.x, n_coord.y) and generated_hexes[n_coord] == biome
				if not is_same:
					var p1 = points[e]
					var p2 = points[(e + 1) % 6]
					_draw_biome_border_edge(p1, p2, biome, center)
					
			# 战术六边形微弱顶点标记 (近景才渲染微光点)
			if current_lod >= 1:
				for pt in points:
					draw_circle(pt, 1.5, Color(1.0, 1.0, 1.0, 0.15))
		else:
			# === 未解锁地块：暗色瓦片显示 (暗蓝科技微光透视线框) ===
			var card_radius = HexWorldGenerator.HEX_RADIUS * 0.90
			var dark_points = PackedVector2Array()
			for i in range(6):
				var angle = deg_to_rad(60.0 * i - 30.0)
				dark_points.append(center + Vector2(cos(angle), sin(angle)) * card_radius)
			dark_points.append(dark_points[0])
			
			draw_colored_polygon(dark_points, Color(0.08, 0.12, 0.18, 0.35))
			draw_polyline(dark_points, Color(0.18, 0.26, 0.38, 0.45), 1.0)
			
	# 2. 绘制领地最外圈发光金边 (Territory Outermost Borders Only - 仅描最外圈，无外围蓝色双框)
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
					# 领地最外圈发光金色线条 (光晕底线 + 锐利金线)
					draw_line(p1, p2, Color(1.0, 0.85, 0.2, 0.35), 4.5)
					draw_line(p1, p2, Color(1.0, 0.90, 0.35, 0.95), 1.8)

# 群系连通融合绘制系统
func _draw_connected_biome_terrain(center: Vector2, points: PackedVector2Array, biome: HexWorldGenerator.BiomeType, same_neighbors: Array[int], _q: int, _r: int) -> void:
	match biome:
		HexWorldGenerator.BiomeType.VOLCANO:
			# 火山与地热：火山口与自然熔岩脉络 (自然主河道，避免蛛网杂乱)
			draw_circle(center + Vector2(0, 1), 12.0, Color(0.12, 0.04, 0.03, 0.9))
			draw_circle(center, 7.5, Color(0.85, 0.25, 0.08, 0.92))
			draw_circle(center, 3.5, Color(1.0, 0.85, 0.25, 0.98))
			draw_circle(center, 1.5, Color(1.0, 0.98, 0.80, 1.0))
			
			for e in same_neighbors:
				# 仅在自然主脉方向延伸熔岩流，避免每个六边形互联形成混乱蛛网
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
			# 盐湖水域：无缝相融的大片碧蓝矿湖，水波相连
			draw_arc(center + Vector2(-4, -2), 14.0, 0.2, PI - 0.2, 12, Color(0.55, 0.80, 0.95, 0.35), 2.2)
			draw_arc(center + Vector2(6, 4), 10.0, PI + 0.2, TAU - 0.2, 10, Color(0.65, 0.88, 1.0, 0.30), 2.0)
			
			for e in same_neighbors:
				var p1 = points[e]
				var p2 = points[(e + 1) % 6]
				var edge_mid = (p1 + p2) * 0.5
				var wave_center = (center + edge_mid) * 0.5
				draw_arc(wave_center, 9.0, 0, PI, 8, Color(0.60, 0.85, 1.0, 0.35), 1.8)
				
		HexWorldGenerator.BiomeType.DEEP_FOREST:
			# 原始森林：树冠茂密重叠，跨越格子连成苍翠林海
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
			# 生机原野：起伏舒缓的草地纹理与连贯原野小径
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

# 异群系交界处自然边缘 (海岸线 / 森林边缘 / 玄武岩断崖)
func _draw_biome_border_edge(p1: Vector2, p2: Vector2, biome: HexWorldGenerator.BiomeType, _center: Vector2) -> void:
	match biome:
		HexWorldGenerator.BiomeType.SALT_LAKE:
			draw_line(p1, p2, Color(0.35, 0.65, 0.85, 0.5), 6.5)
			draw_line(p1, p2, Color(0.88, 0.96, 1.0, 0.85), 3.5)
			draw_line(p1, p2, Color(1.0, 1.0, 1.0, 0.98), 1.4)
		HexWorldGenerator.BiomeType.VOLCANO:
			draw_line(p1, p2, Color(0.10, 0.04, 0.03, 0.95), 3.2)
			draw_line(p1, p2, Color(0.50, 0.16, 0.08, 0.5), 1.2)
		HexWorldGenerator.BiomeType.DEEP_FOREST:
			draw_line(p1, p2, Color(0.05, 0.12, 0.06, 0.7), 2.8)
		HexWorldGenerator.BiomeType.PLAINS:
			draw_line(p1, p2, Color(0.15, 0.26, 0.14, 0.45), 1.5)

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
