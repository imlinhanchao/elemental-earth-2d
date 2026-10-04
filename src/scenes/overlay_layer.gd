# overlay_layer.gd
# 负责高频动态指示物渲染: 鼠标悬停高亮框、任务执行进度环、排队任务指示器
# 极轻量级 (总计 <10 个矢量图元)，瞬时响应鼠标与帧级更新，绝不重绘大世界底图
extends Node2D

const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")

var world: Node2D = null

func _draw() -> void:
	if not world:
		return
		
	# 1. 绘制鼠标当前悬停的六边形高亮框
	if world.generated_hexes.has(world.hovered_hex):
		var h_center = HexWorldGenerator.hex_to_pixel(world.hovered_hex.x, world.hovered_hex.y)
		var h_points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60.0 * i - 30.0)
			var pt = h_center + Vector2(cos(angle), sin(angle)) * HexWorldGenerator.HEX_RADIUS
			h_points.append(pt)
		h_points.append(h_points[0])
		var h_col = Color(0.3, 0.9, 1.0, 0.85) if GameState.is_hex_in_territory(world.hovered_hex.x, world.hovered_hex.y) else Color(1.0, 0.4, 0.4, 0.7)
		draw_polyline(h_points, h_col, 2.5)
	
	# 2. 绘制当前正在进行的任务的世界地块指示器
	if not GameState.active_task.is_empty():
		var t_pos = Vector2(
			float(GameState.active_task.get("world_pos_x", GameState.active_task.get("world_pos", Vector2.ZERO).x)),
			float(GameState.active_task.get("world_pos_y", GameState.active_task.get("world_pos", Vector2.ZERO).y))
		)
		var total = float(GameState.active_task.get("time_required", GameState.active_task.get("total_time", 1.0)))
		var begin_time = int(GameState.active_task.get("begin_time", 0))
		var elapsed = (Time.get_ticks_msec() - begin_time) / 1000.0 if begin_time > 0 else float(GameState.active_task.get("elapsed_time", 0.0))
		var pct = clamp(elapsed / max(total, 0.001), 0.0, 1.0)
		draw_arc(t_pos, 28.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.35), 4.0)
		draw_arc(t_pos, 28.0, -PI/2, -PI/2 + pct * TAU, 32, Color(1.0, 0.88, 0.3, 0.95), 5.0)

	# 3. 绘制排队中任务的地块指示环
	for i in range(GameState.task_queue.size()):
		var q_task = GameState.task_queue[i]
		var q_pos = Vector2(
			float(q_task.get("world_pos_x", q_task.get("world_pos", Vector2.ZERO).x)),
			float(q_task.get("world_pos_y", q_task.get("world_pos", Vector2.ZERO).y))
		)
		draw_circle(q_pos, 16.0, Color(0.1, 0.2, 0.3, 0.3))
		draw_arc(q_pos, 20.0, 0, TAU, 24, Color(0.8, 0.8, 0.3, 0.5), 2.0)
