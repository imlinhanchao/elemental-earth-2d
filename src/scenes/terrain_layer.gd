# terrain_layer.gd
# 负责渲染全部六边形地貌、无缝群系特征、自然海岸边缘、战术顶点与领地发光金线
# 仅在地图生成、时代晋升、读档时重绘 (静态高性能缓存，绝不在鼠标悬停或任务时重绘)
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

const HEX_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)
]

var world: Node2D = null
var current_lod: int = 1 # 0: 远景简略 (zoom < 0.85), 1: 近景精细 (zoom >= 0.85)

var cloud_texture: Texture2D = null

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_get_cloud_texture()

func _get_cloud_texture() -> Texture2D:
	if cloud_texture:
		return cloud_texture
	if ResourceLoader.exists("res://assets/tilesets/cloud_tile.png"):
		cloud_texture = load("res://assets/tilesets/cloud_tile.png")
	if not cloud_texture:
		var img = Image.new()
		var global_path = ProjectSettings.globalize_path("res://assets/tilesets/cloud_tile.png")
		if img.load(global_path) == OK:
			cloud_texture = ImageTexture.create_from_image(img)
	return cloud_texture

func _draw() -> void:
	if not world or world.generated_hexes.is_empty():
		return
		
	var generated_hexes = world.generated_hexes
	
	# 1. 遍历渲染全部六边形地块：
	# - 已解锁地块 (in_territory): 渲染真实的群系底色、连通地貌 (海浪/草丛/熔岩/森林) 与海岸边缘线
	# - 未解锁地块 (not in_territory): 使用无缝云朵瓦片 (Seamless Cloud Tiles)
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
			# === 已解锁领地：渲染文明地貌与无缝连通群系 ===
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
				# 远景模式 (LOD 0)：采用极度柔和的微弱中心晕色
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
			# === 未解锁地块：使用无缝云朵瓦片 (Seamless Cloud Tiles) ===
			_draw_seamless_cloud_tile(center, points, coord)
			
	# 2. 绘制文明领地最外圈发光金边 (Territory Outermost Borders Only)
	# 严格判别：仅当该格在领地内，而相邻格处于领地之外时，才描画该分界边，内部无缝无任何金边
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
					draw_line(p1, p2, Color(1.0, 0.85, 0.2, 0.35), 5.0)
					draw_line(p1, p2, Color(1.0, 0.92, 0.40, 0.98), 2.2)

# 群系连通融合绘制系统
func _draw_connected_biome_terrain(center: Vector2, points: PackedVector2Array, biome: HexWorldGenerator.BiomeType, same_neighbors: Array[int], _q: int, _r: int) -> void:
	match biome:
		HexWorldGenerator.BiomeType.VOLCANO:
			# 火山与地热：相互连通成片的赤红熔岩河流网络与炽热火山口
			draw_circle(center + Vector2(0, 2), 14.0, Color(0.12, 0.04, 0.03, 0.9))
			draw_circle(center, 9.0, Color(0.85, 0.25, 0.08, 0.92))
			draw_circle(center, 4.5, Color(1.0, 0.85, 0.25, 0.98))
			draw_circle(center, 2.0, Color(1.0, 0.98, 0.80, 1.0))
			
			# 向相同火山邻居延伸蜿蜒自然的熔岩大河，跨越格子连为一体！
			for e in same_neighbors:
				var p1 = points[e]
				var p2 = points[(e + 1) % 6]
				var edge_mid = (p1 + p2) * 0.5
				# 自然弯曲中继点
				var delta_v = edge_mid - center
				var norm = Vector2(-delta_v.y, delta_v.x).normalized()
				var bend_mag = sin(float(_q * 43 + _r * 71 + e * 23)) * 4.5
				var waypoint = (center + edge_mid) * 0.5 + norm * bend_mag
				
				# 熔岩红光晕
				draw_polyline([center, waypoint, edge_mid], Color(0.85, 0.20, 0.05, 0.35), 8.0)
				# 焦黑玄武岩河床
				draw_polyline([center, waypoint, edge_mid], Color(0.12, 0.05, 0.04, 0.95), 5.5)
				# 炽热流动岩浆
				draw_polyline([center, waypoint, edge_mid], Color(1.0, 0.42, 0.10, 0.95), 3.2)
				# 中心金黄高能核
				draw_polyline([center, waypoint, edge_mid], Color(1.0, 0.90, 0.45, 1.0), 1.4)
				
		HexWorldGenerator.BiomeType.SALT_LAKE:
			# 盐湖水域：无缝相融的大片碧蓝矿湖，水波相连
			# 湖心柔和深水光影
			draw_arc(center + Vector2(-4, -2), 14.0, 0.2, PI - 0.2, 12, Color(0.55, 0.80, 0.95, 0.35), 2.2)
			draw_arc(center + Vector2(6, 4), 10.0, PI + 0.2, TAU - 0.2, 10, Color(0.65, 0.88, 1.0, 0.30), 2.0)
			
			# 相邻盐湖之间连通平滑水波
			for e in same_neighbors:
				var p1 = points[e]
				var p2 = points[(e + 1) % 6]
				var edge_mid = (p1 + p2) * 0.5
				var wave_center = (center + edge_mid) * 0.5
				draw_arc(wave_center, 9.0, 0, PI, 8, Color(0.60, 0.85, 1.0, 0.35), 1.8)
				
		HexWorldGenerator.BiomeType.DEEP_FOREST:
			# 原始森林：树冠茂密重叠，跨越格子连成苍翠林海！
			# 中心饱满树冠组 (阴影 + 深绿 + 茂盛绿 + 向阳嫩绿)
			draw_circle(center + Vector2(0, 4), 18.0, Color(0.04, 0.10, 0.05, 0.45))
			draw_circle(center, 16.0, Color(0.07, 0.16, 0.09))
			draw_circle(center + Vector2(-2, -3), 13.0, Color(0.13, 0.30, 0.15))
			draw_circle(center + Vector2(-3, -5), 8.5, Color(0.22, 0.48, 0.22))
			draw_circle(center + Vector2(2, -6), 5.5, Color(0.35, 0.65, 0.32))
			
			# 向相邻森林格子延伸交织树冠群，密织成林！
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
			# 盐湖与陆地交界的天然白色盐晶滩与浅水岸
			draw_line(p1, p2, Color(0.35, 0.65, 0.85, 0.5), 6.5)
			draw_line(p1, p2, Color(0.88, 0.96, 1.0, 0.85), 3.5)
			draw_line(p1, p2, Color(1.0, 1.0, 1.0, 0.98), 1.4)
		HexWorldGenerator.BiomeType.VOLCANO:
			# 火山与外侧交界的暗色玄武岩断崖
			draw_line(p1, p2, Color(0.10, 0.04, 0.03, 0.95), 3.2)
			draw_line(p1, p2, Color(0.50, 0.16, 0.08, 0.5), 1.2)
		HexWorldGenerator.BiomeType.DEEP_FOREST:
			# 森林外沿深邃绿荫边缘
			draw_line(p1, p2, Color(0.05, 0.12, 0.06, 0.7), 2.8)
		HexWorldGenerator.BiomeType.PLAINS:
			# 平原外缘自然过渡线
			draw_line(p1, p2, Color(0.15, 0.26, 0.14, 0.45), 1.5)

# 未解锁地块无缝云海瓦片渲染 (Seamless Cloud Tiles)
func _draw_seamless_cloud_tile(center: Vector2, points: PackedVector2Array, coord: Vector2i) -> void:
	var tex = _get_cloud_texture()
	if tex:
		var uvs = PackedVector2Array()
		# 采用世界坐标对齐映射 UV (除以贴图分辨率 256.0)，实现相邻六边形 100% 无缝平铺连成片
		for pt in points:
			uvs.append(pt / 256.0)
		var cols = PackedColorArray()
		for _i in range(6):
			cols.append(Color(1.0, 1.0, 1.0, 1.0))
		draw_polygon(points, cols, uvs, tex)
	else:
		draw_colored_polygon(points, Color(0.88, 0.92, 0.97, 1.0))

	# 检查 6 个邻居：仅当邻居处于已解锁领地内时（即文明与未探索云海交界），描画蓬松卷曲云团边缘
	var generated_hexes = world.generated_hexes
	for e in range(6):
		var n_coord = coord + HEX_EDGE_DIRS[e]
		var neighbor_is_territory = generated_hexes.has(n_coord) and GameState.is_hex_in_territory(n_coord.x, n_coord.y)
		if neighbor_is_territory:
			var p1 = points[e]
			var p2 = points[(e + 1) % 6]
			if current_lod >= 1:
				_draw_cloud_boundary_edge(p1, p2, center)
			else:
				draw_line(p1, p2, Color(0.92, 0.95, 0.99, 0.6), 3.0)

# 云海与领地交界处的蓬松卷曲云团外沿
func _draw_cloud_boundary_edge(p1: Vector2, p2: Vector2, center: Vector2) -> void:
	var edge_vec = p2 - p1
	var edge_len = edge_vec.length()
	var edge_dir = edge_vec.normalized()
	var mid = (p1 + p2) * 0.5
	var inward = (center - mid).normalized()
	
	# 沿该边在云海一侧绘制 3 个自然交错重叠的蓬松积云泡
	var t_vals = [0.22, 0.52, 0.82]
	var radii = [11.0, 14.0, 12.0]
	for i in range(3):
		var puff_center = p1 + edge_dir * (edge_len * t_vals[i]) + inward * 2.5
		var r = radii[i]
		# 底部柔和粉蓝阴影轮廓
		draw_circle(puff_center - inward * 1.5, r + 2.0, Color(0.65, 0.75, 0.86, 0.35))
		# 饱满纯白云核
		draw_circle(puff_center, r, Color(0.95, 0.97, 1.0, 0.88))
		# 顶部向阳高光晕
		draw_circle(puff_center + inward * 1.5, r * 0.55, Color(1.0, 1.0, 1.0, 0.55))

