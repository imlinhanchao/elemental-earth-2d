# terrain_detail_layer.gd
# 领地内的地图符号层：仅在地形内容变化时重绘；LOD 切换由 terrain_layer.set_lod 控制 visible
extends Node2D

const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")
const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const HEX_EDGE_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]

var terrain: Node2D = null

func _draw() -> void:
	if terrain == null or terrain.world == null:
		return
	var generated_hexes: Dictionary = terrain.world.generated_hexes
	for coord in generated_hexes.keys():
		if not GameState.is_hex_in_territory(coord.x, coord.y):
			continue
		var center = HexWorldGenerator.hex_to_pixel(coord.x, coord.y)
		var points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			points.append(center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS)
		var biome = generated_hexes[coord]
		var same_biome_neighbors: Array[int] = []
		for e in range(6):
			var n_coord = coord + HEX_EDGE_DIRS[e]
			if generated_hexes.has(n_coord) and GameState.is_hex_in_territory(n_coord.x, n_coord.y) and generated_hexes[n_coord] == biome:
				same_biome_neighbors.append(e)
		_draw_connected_biome_terrain(center, points, biome, same_biome_neighbors, coord.x, coord.y)
		# 战术六边形微弱顶点标记
		for pt in points:
			draw_circle(pt, 1.2, ThemeStyler.adapt(Color(0.20, 0.18, 0.15, 0.12)))

# 群系地图符号绘制 (地质测绘图图例风格：墨线符号，低对比、少而精)
func _draw_connected_biome_terrain(center: Vector2, points: PackedVector2Array, biome: HexWorldGenerator.BiomeType, same_neighbors: Array[int], _q: int, _r: int) -> void:
	var seed_f = float(_q * 73 + _r * 151)
	match biome:
		HexWorldGenerator.BiomeType.VOLCANO:
			# 火山：晕滃线 (hachure) 山体符号 + 熔岩脉细红线
			var peak = center + Vector2(0, -2)
			draw_colored_polygon(PackedVector2Array([peak + Vector2(-9, 7), peak + Vector2(0, -7), peak + Vector2(9, 7)]), ThemeStyler.adapt(Color(0.55, 0.32, 0.24, 0.45)))
			for k in range(5):
				var base_pt = peak + Vector2(-9, 7).lerp(Vector2(9, 7), float(k) / 4.0)
				var top_pt = (peak + Vector2(0, -7)).lerp(base_pt, 0.35)
				draw_line(top_pt, base_pt, ThemeStyler.adapt(Color(0.35, 0.18, 0.12, 0.55)), 1.0)
			draw_circle(peak + Vector2(0, -7), 1.8, ThemeStyler.adapt(Color(0.80, 0.30, 0.18, 0.9)))
			for e in same_neighbors:
				if (e + _q * 2 + _r) % 3 == 0:
					var edge_mid = (points[e] + points[(e + 1) % 6]) * 0.5
					var delta_v = edge_mid - center
					var norm = Vector2(-delta_v.y, delta_v.x).normalized()
					var waypoint = (center + edge_mid) * 0.5 + norm * sin(seed_f + e * 23.0) * 3.0
					draw_polyline([center + Vector2(0, 6), waypoint, edge_mid], ThemeStyler.adapt(Color(0.75, 0.28, 0.16, 0.55)), 1.4)

		HexWorldGenerator.BiomeType.SALT_LAKE:
			# 盐湖：水域平行波纹 (地图水体符号) + 盐渍白点
			var wave_col = ThemeStyler.adapt(Color(0.28, 0.45, 0.55, 0.45))
			for k in range(3):
				var y = -8.0 + float(k) * 8.0
				var x0 = -11.0 + sin(seed_f + k) * 2.0
				var pts = PackedVector2Array()
				for j in range(7):
					pts.append(center + Vector2(x0 + float(j) * 3.6, y + (1.2 if j % 2 == 0 else -1.2)))
				draw_polyline(pts, wave_col, 1.0)
			draw_circle(center + Vector2(9, 9), 1.4, ThemeStyler.adapt(Color(1, 1, 1, 0.7)))
			draw_circle(center + Vector2(-10, 6), 1.1, ThemeStyler.adapt(Color(1, 1, 1, 0.6)))

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
			var grass = ThemeStyler.adapt(Color(0.36, 0.45, 0.28, 0.55))
			for k in range(2):
				var gp = center + Vector2(cos(seed_f + k * 2.4), sin(seed_f + k * 2.4)) * 9.0
				draw_line(gp, gp + Vector2(0, -4), grass, 1.0)
				draw_line(gp, gp + Vector2(-2.5, -3), grass, 1.0)
				draw_line(gp, gp + Vector2(2.5, -3), grass, 1.0)

func _draw_tree_symbol(pos: Vector2) -> void:
	draw_line(pos + Vector2(0, 2), pos + Vector2(0, 6), ThemeStyler.adapt(Color(0.30, 0.25, 0.18, 0.7)), 1.2)
	draw_circle(pos, 4.5, ThemeStyler.adapt(Color(0.30, 0.45, 0.30, 0.55)))
	draw_arc(pos, 4.5, 0, TAU, 12, ThemeStyler.adapt(Color(0.18, 0.28, 0.18, 0.75)), 1.0)
