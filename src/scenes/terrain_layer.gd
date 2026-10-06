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

# 地图符号 (草丛 / 林地 / 晕滃线 / 顶点) 单独放在子画布：切换 LOD 只改 visible，不重建任何绘制指令
var detail_layer: Node2D = null

func _ready() -> void:
	detail_layer = preload("res://src/scenes/terrain_detail_layer.gd").new()
	detail_layer.terrain = self
	add_child(detail_layer)

# 地形内容变化 (世界生成 / 时代跃迁 / 读档) 时调用；镜头移动与 LOD 切换不需要
func refresh() -> void:
	queue_redraw()
	if detail_layer:
		detail_layer.queue_redraw()

func set_lod(lod: int) -> void:
	current_lod = lod
	if detail_layer:
		detail_layer.visible = lod >= 1

# 批量几何缓冲：所有填充三角形合并为一次 canvas_item_add_triangle_array，
# 线段按 (颜色, 线宽) 分桶合并为 draw_multiline，避免逐瓦片数千次绘制调用
var _tri_verts := PackedVector2Array()
var _tri_cols := PackedColorArray()
var _tri_idx := PackedInt32Array()
var _line_buckets: Dictionary = {} # [Color, width] -> PackedVector2Array

func _add_tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	var base = _tri_verts.size()
	_tri_verts.append(a); _tri_verts.append(b); _tri_verts.append(c)
	_tri_cols.append(ca); _tri_cols.append(cb); _tri_cols.append(cc)
	_tri_idx.append(base); _tri_idx.append(base + 1); _tri_idx.append(base + 2)

func _add_hex_fill(center: Vector2, pts: PackedVector2Array, col: Color) -> void:
	for i in range(6):
		_add_tri(center, pts[i], pts[(i + 1) % 6], col, col, col)

func _add_line(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var key = [col, width]
	if not _line_buckets.has(key):
		_line_buckets[key] = PackedVector2Array()
	var arr: PackedVector2Array = _line_buckets[key]
	arr.append(a); arr.append(b)
	_line_buckets[key] = arr

static var _unit_hex: PackedVector2Array = PackedVector2Array()

static func _hex_corners(center: Vector2, radius: float) -> PackedVector2Array:
	if _unit_hex.is_empty():
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			_unit_hex.append(Vector2(cos(angle), sin(angle)))
	var pts = PackedVector2Array()
	pts.resize(6)
	for i in range(6):
		pts[i] = center + _unit_hex[i] * radius
	return pts

func _draw() -> void:
	if not world or world.generated_hexes.is_empty():
		return
	var generated_hexes: Dictionary = world.generated_hexes
	_tri_verts.clear(); _tri_cols.clear(); _tri_idx.clear(); _line_buckets.clear()

	# 1. 绘制固定范围 (与镜头无关)：仅在世界生成 / 时代跃迁 / 读档时重绘，
	#    镜头平移与缩放只移动 Camera2D，复用 CanvasItem 已缓存的绘制指令，不再逐帧重建。
	_draw_blueprint_grid(-GRID_EXTENT, GRID_EXTENT, -GRID_EXTENT, GRID_EXTENT)

	var unexplored_fill = Color(0.95, 0.93, 0.89, 0.85)
	var unexplored_line = Color(0.55, 0.50, 0.43, 0.30)

	# 2. 遍历固定半径内的全部六边形 (地图 + 外围未解锁图纸区)，只收集几何
	for r in range(-DRAW_HEX_RADIUS, DRAW_HEX_RADIUS + 1):
		var q_lo = max(-DRAW_HEX_RADIUS, -r - DRAW_HEX_RADIUS)
		var q_hi = min(DRAW_HEX_RADIUS, -r + DRAW_HEX_RADIUS)
		for q in range(q_lo, q_hi + 1):
			var coord = Vector2i(q, r)
			var center = HexWorldGenerator.hex_to_pixel(q, r)
			if GameState.is_hex_in_territory(q, r):
				# === 已解锁领地：群系平滑渐变底色 + 异群系交界线 ===
				var points = _hex_corners(center, HexWorldGenerator.HEX_RADIUS)
				var biome = generated_hexes.get(coord, HexWorldGenerator.BiomeType.PLAINS)
				_draw_gradient_biome_hex(center, coord, biome, points, generated_hexes)
				for e in range(6):
					var n_coord = coord + HEX_EDGE_DIRS[e]
					if generated_hexes.has(n_coord) and GameState.is_hex_in_territory(n_coord.x, n_coord.y):
						var n_biome = generated_hexes[n_coord]
						if n_biome != biome:
							_draw_natural_biome_transition(points[e], points[(e + 1) % 6], biome, n_biome, center, coord, e)
			else:
				# === 未解锁地块：图纸白六边形 + 铅笔细线 ===
				var dark_points = _hex_corners(center, HexWorldGenerator.HEX_RADIUS * 0.90)
				_add_hex_fill(center, dark_points, unexplored_fill)
				for i in range(6):
					_add_line(dark_points[i], dark_points[(i + 1) % 6], unexplored_line, 1.0)

	# 3. 提交合并后的填充与线段
	if not _tri_idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _tri_idx, _tri_verts, _tri_cols)
	for key in _line_buckets.keys():
		draw_multiline(_line_buckets[key], key[0], key[1])
	_tri_verts.clear(); _tri_cols.clear(); _tri_idx.clear(); _line_buckets.clear()

	# 4. 绘制领地最外圈边界 (仅描最外圈，颜色随时代强调色)
	var border_col: Color = ThemeStyler.get_era_accent(GameState.current_era)
	var halo = PackedVector2Array()
	var dash_col = border_col.darkened(0.25)
	for coord in generated_hexes.keys():
		if GameState.is_hex_in_territory(coord.x, coord.y):
			var pts = _hex_corners(HexWorldGenerator.hex_to_pixel(coord.x, coord.y), HexWorldGenerator.HEX_RADIUS)
			for i in range(6):
				var neighbor = coord + HEX_EDGE_DIRS[i]
				if not GameState.is_hex_in_territory(neighbor.x, neighbor.y):
					var p1 = pts[i]
					var p2 = pts[(i + 1) % 6]
					# 测绘图行政边界：时代色柔晕 + 深色虚线
					halo.append(p1); halo.append(p2)
					draw_dashed_line(p1, p2, dash_col, 2.2, 7.0)
	if not halo.is_empty():
		draw_multiline(halo, Color(border_col.r, border_col.g, border_col.b, 0.28), 6.0)

# 渐变过渡群系绘图系统：中心保持本群系核心纯色，外周裙边通过三角扇面 Gouraud 顶点色彩平滑过渡至邻居群系
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
	
	# 1. 瓦片中心核心 (半径 38% 的纯本群系核心，外周 62% 均为平滑渐变裙边)
	var inner_pts = _hex_corners(center, HexWorldGenerator.HEX_RADIUS * 0.38)
	_add_hex_fill(center, inner_pts, center_col)
	
	# 2. 每个方向邻居的颜色 (领地外或无地块时取自身颜色)
	var n_cols: Array[Color] = []
	for e in range(6):
		var n_e = coord + HEX_EDGE_DIRS[e]
		if generated_hexes.has(n_e) and GameState.is_hex_in_territory(n_e.x, n_e.y):
			n_cols.append(HexWorldGenerator.get_biome_color(generated_hexes[n_e]))
		else:
			n_cols.append(base_col)
	
	# 3. 顶点取三向均值、边中点取双向均值，相邻瓦片在共享边上颜色完全一致
	for e in range(6):
		var next_e = (e + 1) % 6
		var ip1 = inner_pts[e]
		var ip2 = inner_pts[next_e]
		var op1 = outer_pts[e]
		var op2 = outer_pts[next_e]
		var edge_mid = (op1 + op2) * 0.5
		var v_col1 = (base_col + n_cols[(e + 5) % 6] + n_cols[e]) / 3.0
		var v_col2 = (base_col + n_cols[e] + n_cols[next_e]) / 3.0
		var m_col = (base_col + n_cols[e]) * 0.5
		_add_tri(ip1, op1, edge_mid, center_col, v_col1, m_col)
		_add_tri(ip1, edge_mid, ip2, center_col, m_col, center_col)
		_add_tri(ip2, edge_mid, op2, center_col, m_col, v_col2)

# 异群系交界：测绘图式岸线与轮廓 (仅在一侧绘制，避免重复描边)
func _draw_natural_biome_transition(p1: Vector2, p2: Vector2, my_biome: HexWorldGenerator.BiomeType, n_biome: HexWorldGenerator.BiomeType, center: Vector2, _coord: Vector2i, _edge_idx: int) -> void:
	var inward = (center - (p1 + p2) * 0.5).normalized()
	# 盐湖岸线：水域一侧深蓝细岸线 + 内侧浅色复线
	if my_biome == HexWorldGenerator.BiomeType.SALT_LAKE:
		_add_line(p1 + inward * 1.0, p2 + inward * 1.0, Color(0.22, 0.38, 0.48, 0.65), 1.3)
		_add_line(p1 + inward * 4.0, p2 + inward * 4.0, Color(0.30, 0.48, 0.58, 0.25), 1.0)
		return
	if n_biome == HexWorldGenerator.BiomeType.SALT_LAKE:
		return
	# 火山边缘：短晕滃线
	if my_biome == HexWorldGenerator.BiomeType.VOLCANO:
		for k in range(3):
			var pt = p1.lerp(p2, 0.25 + 0.25 * float(k)) + inward * 2.0
			_add_line(pt, pt + inward * 4.0, Color(0.40, 0.22, 0.15, 0.40), 1.0)
		return
	# 林缘：森林一侧浅墨细线
	if my_biome == HexWorldGenerator.BiomeType.DEEP_FOREST:
		_add_line(p1 + inward * 1.5, p2 + inward * 1.5, Color(0.22, 0.32, 0.22, 0.30), 1.0)

# 绘制测绘图纸经纬网格 (根据视口坐标范围动态平铺)
func _draw_blueprint_grid(start_x: float, end_x: float, start_y: float, end_y: float) -> void:
	var grid_color = Color(0.55, 0.50, 0.43, 0.14)
	var step = 96.0
	var segs = PackedVector2Array()
	var cur_x = floor(start_x / step) * step
	while cur_x <= end_x:
		segs.append(Vector2(cur_x, start_y)); segs.append(Vector2(cur_x, end_y))
		cur_x += step
	var cur_y = floor(start_y / step) * step
	while cur_y <= end_y:
		segs.append(Vector2(start_x, cur_y)); segs.append(Vector2(end_x, cur_y))
		cur_y += step
	draw_multiline(segs, grid_color, 1.0)
