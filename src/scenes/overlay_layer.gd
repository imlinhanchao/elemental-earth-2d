# overlay_layer.gd
# 负责高频动态指示物渲染: 鼠标悬停高亮框、任务执行进度环、排队任务指示器
# 极轻量级 (总计 <10 个矢量图元)，瞬时响应鼠标与帧级更新，绝不重绘大世界底图
extends Node2D

const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")
const ThemeStyler = preload("res://src/ui/theme_styler.gd")

var world: Node2D = null

func _draw() -> void:
	if not world:
		return
		
	# 1. 建造选址模式 (最高视觉优先级: 半透明多边形、建筑虚影与可放置指示)
	if "is_placing_structure" in world and world.is_placing_structure and world.generated_hexes.has(world.hovered_hex):
		_draw_placement_preview(world.hovered_hex)
	elif world.generated_hexes.has(world.hovered_hex):
		# 普通模式下的鼠标悬停高亮框
		var h_center = HexWorldGenerator.hex_to_pixel(world.hovered_hex.x, world.hovered_hex.y)
		var h_points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			var pt = h_center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS
			h_points.append(pt)
		h_points.append(h_points[0])
		# 浅色测绘底图上使用深墨描边 + 纸白内衬，保证悬停框清晰
		var in_terr = GameState.is_hex_in_territory(world.hovered_hex.x, world.hovered_hex.y)
		var h_col = ThemeStyler.PAPER_INK if in_terr else ThemeStyler.COLOR_DANGER
		draw_polyline(h_points, Color(1, 1, 1, 0.55), 4.5)
		draw_polyline(h_points, h_col, 2.0)
	
	# 教程目标地块：铜色脉动圆环 + 下落箭头
	if GameState.is_tutorial_active and GameState.tutorial_marker_hex != Vector2i(9999, 9999):
		_draw_tutorial_marker(GameState.tutorial_marker_hex)

	# 2. 绘制当前正在进行的任务的世界地块指示器
	if not GameState.active_task.is_empty():
		var t_pos = Vector2(
			float(GameState.active_task.get("world_pos_x", GameState.active_task.get("world_pos", Vector2.ZERO).x)),
			float(GameState.active_task.get("world_pos_y", GameState.active_task.get("world_pos", Vector2.ZERO).y))
		)
		var total = float(GameState.active_task.get("time_required", GameState.active_task.get("total_time", 1.0)))
		var begin_time = int(GameState.active_task.get("begin_time", 0))
		var elapsed = (Time.get_ticks_msec() - begin_time) / 1000.0 if begin_time != 0 else float(GameState.active_task.get("elapsed_time", 0.0))
		var pct = clamp(elapsed / max(total, 0.001), 0.0, 1.0)
		var ring_col = ThemeStyler.get_era_accent(GameState.current_era).darkened(0.15)
		draw_arc(t_pos, 28.0, 0, TAU, 32, Color(0.15, 0.14, 0.13, 0.25), 4.0)
		draw_arc(t_pos, 28.0, -PI/2, -PI/2 + pct * TAU, 32, ring_col, 5.0)

	# 3. 绘制排队中任务的地块指示环
	for i in range(GameState.task_queue.size()):
		var q_task = GameState.task_queue[i]
		var q_pos = Vector2(
			float(q_task.get("world_pos_x", q_task.get("world_pos", Vector2.ZERO).x)),
			float(q_task.get("world_pos_y", q_task.get("world_pos", Vector2.ZERO).y))
		)
		draw_circle(q_pos, 16.0, Color(0.96, 0.94, 0.90, 0.35))
		draw_arc(q_pos, 20.0, 0, TAU, 24, Color(0.15, 0.14, 0.13, 0.55), 1.5)

func _draw_placement_preview(hex: Vector2i) -> void:
	var check = world.get_build_validity(hex) if world.has_method("get_build_validity") else {"valid": true, "reason": ""}
	var is_valid: bool = check.get("valid", false)
	var reason: String = check.get("reason", "")
	var h_center = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
	
	# 六边形多边形顶点
	var h_points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * i - 30.0)
		var pt = h_center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS
		h_points.append(pt)
	
	var poly_outline = h_points.duplicate()
	poly_outline.append(h_points[0])
	
	var font = ThemeStyler.get_font_sans() if ThemeStyler.get_font_sans() else ThemeDB.fallback_font
	
	if is_valid:
		# 翡翠绿发光填充与边框
		draw_colored_polygon(h_points, Color(0.42, 0.66, 0.42, 0.30))
		draw_polyline(poly_outline, ThemeStyler.COLOR_SUCCESS.darkened(0.3), 3.0)
		
		# 虚影建筑预览
		var p_key = world.placing_structure_key if "placing_structure_key" in world else "fire_pit"
		match p_key:
			"fire_pit":
				_draw_ghost_fire_pit(h_center)
			"furnace":
				_draw_ghost_furnace(h_center)
			"industrial_reactor":
				_draw_ghost_reactor(h_center)
			_:
				_draw_ghost_fire_pit(h_center)
		
		# 提示文字
		if font:
			draw_string_outline(font, h_center + Vector2(0, -HexWorldGenerator.HEX_RADIUS - 8), "点击左键安放", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, 5, Color(0.96, 0.94, 0.90, 0.95))
			draw_string(font, h_center + Vector2(0, -HexWorldGenerator.HEX_RADIUS - 8), "点击左键安放", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, ThemeStyler.COLOR_SUCCESS.darkened(0.45))
	else:
		# 红色警示填充与边框
		draw_colored_polygon(h_points, Color(0.80, 0.33, 0.27, 0.25))
		draw_polyline(poly_outline, ThemeStyler.COLOR_DANGER.darkened(0.2), 3.0)
		
		if font:
			draw_string_outline(font, h_center + Vector2(0, -HexWorldGenerator.HEX_RADIUS - 8), reason, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, 5, Color(0.96, 0.94, 0.90, 0.95))
			draw_string(font, h_center + Vector2(0, -HexWorldGenerator.HEX_RADIUS - 8), reason, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, ThemeStyler.COLOR_DANGER.darkened(0.3))

func _draw_ghost_fire_pit(pos: Vector2) -> void:
	# 8 块半透明小河卵石环
	var stone_count = 8
	var ring_r = 16.0
	for i in range(stone_count):
		var angle = (TAU / stone_count) * i
		var stone_pos = pos + Vector2(cos(angle) * ring_r, sin(angle) * ring_r * 0.72)
		draw_circle(stone_pos, 4.2, Color(0.75, 0.8, 0.85, 0.65))
		draw_arc(stone_pos, 4.2, 0, TAU, 12, Color(0.9, 0.95, 1.0, 0.7), 1.0)
	# 交叉烧焦柴木虚影
	draw_line(pos + Vector2(-10, -5), pos + Vector2(10, 5), Color(0.65, 0.42, 0.22, 0.75), 3.5)
	draw_line(pos + Vector2(-9, 5), pos + Vector2(9, -5), Color(0.55, 0.35, 0.18, 0.75), 3.0)
	# 温暖火苗发光虚影
	draw_circle(pos + Vector2(0, -2), 7.0, Color(1.0, 0.65, 0.15, 0.8))
	draw_circle(pos + Vector2(0, -4), 4.0, Color(1.0, 0.92, 0.35, 0.9))

func _draw_ghost_furnace(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x - 12, pos.y - 10, 24, 20), Color(0.85, 0.45, 0.25, 0.7))
	draw_rect(Rect2(pos.x - 6, pos.y - 18, 12, 8), Color(0.70, 0.35, 0.20, 0.7))
	draw_circle(pos + Vector2(0, 3), 6.0, Color(1.0, 0.6, 0.1, 0.85))

func _draw_ghost_reactor(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x - 14, pos.y - 16, 28, 30), Color(0.2, 0.6, 0.9, 0.65))
	draw_rect(Rect2(pos.x - 10, pos.y - 24, 20, 8), Color(0.3, 0.7, 1.0, 0.75))
	draw_circle(pos + Vector2(0, 0), 7.0, Color(0.2, 0.9, 1.0, 0.85))

func _draw_tutorial_marker(hex: Vector2i) -> void:
	var c = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
	var t = Time.get_ticks_msec() / 1000.0
	var col = ThemeStyler.COLOR_ACCENT
	var r = HexWorldGenerator.HEX_RADIUS * (0.95 + 0.08 * sin(t * 4.0))
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.7), 5.0)
	draw_arc(c, r, 0, TAU, 40, col, 2.5)
	# 外扩涟漪
	var phase = fmod(t, 1.2) / 1.2
	draw_arc(c, r + phase * 18.0, 0, TAU, 40, Color(col.r, col.g, col.b, 0.5 * (1.0 - phase)), 2.0)
	# 指向地块的下落箭头
	var tip = c + Vector2(0, -r - 4.0 - absf(sin(t * 3.0)) * 6.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-9, -14), tip + Vector2(9, -14)]), col)
