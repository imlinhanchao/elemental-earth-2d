# furnace.gd
# 篝火堆 / 陶土熔炉 / 鼓风高炉的地图表现节点。点击由 world 按地块分发，打开炉体模式的实验台；
# 炉温、燃料与反应都在模拟层 (built_furnaces[hex].bench)。
extends Node2D

const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

var hex_coord: Vector2i = Vector2i(9999, 9999)
var building_type: String = "furnace" # "fire_pit" / "furnace" / "blast_furnace"

var buffer: MixtureBuffer:
	get:
		if GameState.built_furnaces.has(hex_coord):
			return GameState.built_furnaces[hex_coord]["buffer"]
		if _fallback_buffer == null:
			_fallback_buffer = MixtureBuffer.new()
			_fallback_buffer.container_type = building_type
			_fallback_buffer.temperature = 293.15
		return _fallback_buffer

var is_active_fire: bool:
	get:
		if GameState.built_furnaces.has(hex_coord):
			return GameState.built_furnaces[hex_coord]["bench"].fire_lit
		return false

var _fallback_buffer: MixtureBuffer = null

@onready var label_status = $StatusLabel

func _ready() -> void:
	add_to_group("furnace")
	if GameState.built_furnaces.has(hex_coord):
		building_type = GameState.built_furnaces[hex_coord].get("type", building_type)
	queue_redraw()

var _last_label: String = ""
var _was_burning: bool = true
var is_hovered: bool = false

# 鼠标悬停时才显示「点击使用」(world 按地块调用)
func set_hovered(v: bool) -> void:
	is_hovered = v

# 地表标签：名称 + 状态 (燃烧中显示温度与剩余燃料，反应中显示配方名)
func _status_text() -> String:
	var b_name = DataDB.get_building_recipe(building_type).get("name", "熔炉")
	if not GameState.built_furnaces.has(hex_coord):
		return b_name
	var bench = GameState.built_furnaces[hex_coord]["bench"]
	var lines: Array = [b_name]
	if bench.fire_lit:
		lines.append("%d ℃ · 燃料 %d 秒" % [int(buffer.temperature - 273.15), int(ceil(bench.fuel_seconds()))])
	elif buffer.temperature > 323.15:
		lines.append("冷却中 %d ℃" % int(buffer.temperature - 273.15))
	elif is_hovered:
		lines.append("点击使用")
	if buffer.active_formula != "":
		lines.append(DataDB.get_formula(buffer.active_formula).get("name", "反应") if bench.has_clue(buffer.active_formula) else "反应中")
	elif not buffer.components.is_empty():
		lines.append("炉内有物料")
	return "\n".join(lines)

func _process(_delta: float) -> void:
	var txt = _status_text()
	if label_status and txt != _last_label:
		_last_label = txt
		label_status.text = txt
	# 火焰动画只在燃烧时逐帧重绘；熄火后补画一帧静态图
	var burning = is_active_fire
	if burning or _was_burning:
		queue_redraw()
	_was_burning = burning

func _draw() -> void:
	if building_type == "fire_pit":
		_draw_fire_pit()
	elif building_type == "blast_furnace":
		_draw_blast_furnace()
	else:
		_draw_furnace()

# 1. 原始篝火堆绘制 (石圈围拢、炭床、交叉焦柴、熊熊野火与升腾火星)
func _draw_fire_pit() -> void:
	# 地面灰烬焦痕阴影
	draw_circle(Vector2(0, 4), 22.0, Color(0.06, 0.05, 0.04, 0.45))
	# 灰黑炭床
	draw_circle(Vector2.ZERO, 15.0, Color(0.18, 0.15, 0.14))
	# 围绕一圈天然野外鹅卵石块 (8 颗天然石块)
	for i in range(8):
		var angle = i * TAU / 8.0
		var stone_pos = Vector2(cos(angle), sin(angle)) * 17.0
		draw_circle(stone_pos, 5.0, Color(0.48, 0.46, 0.42))
		draw_circle(stone_pos + Vector2(-1.2, -1.2), 3.0, Color(0.68, 0.66, 0.62)) # 暖白受光高光面
	# 交叉焦柴
	draw_line(Vector2(-10, -7), Vector2(10, 7), Color(0.32, 0.20, 0.12), 4.0)
	draw_line(Vector2(-10, 7), Vector2(10, -7), Color(0.26, 0.16, 0.10), 4.0)
	# 熊熊燃烧的营火烈焰与升腾火星
	if buffer.temperature > 320.0 or is_active_fire:
		var t = Time.get_ticks_msec() * 0.015
		var fire_r = 11.0 * (0.85 + 0.18 * sin(t))
		draw_circle(Vector2(0, -2), fire_r, Color(1.0, 0.38, 0.05, 0.92))
		draw_circle(Vector2(0, -3), fire_r * 0.62, Color(1.0, 0.88, 0.22, 1.0)) # 亮金内焰
		for i in range(3):
			var spark_pos = Vector2(sin(t + i * 2.2) * 8.0, -8.0 - fmod(t * 8.0 + i * 5.0, 16.0))
			draw_circle(spark_pos, 1.8, Color(1.0, 0.92, 0.35, 0.85))

# 2. 陶土熔炉绘制 (圆窑底座、粗陶外壁、耐火砖层与炉膛暗腔)
func _draw_furnace() -> void:
	draw_circle(Vector2(0, 4), 26.0, Color(0.1, 0.08, 0.06, 0.5)) # 地面阴影
	draw_circle(Vector2.ZERO, 25.0, Color(0.42, 0.26, 0.15))       # 粗陶土外壁
	draw_circle(Vector2.ZERO, 21.0, Color(0.55, 0.35, 0.20))       # 耐火砖层
	draw_circle(Vector2.ZERO, 15.0, Color(0.15, 0.10, 0.08))       # 炉膛深处暗腔
	
	if buffer.temperature > 500.0 or is_active_fire:
		var intensity = clamp((buffer.temperature - 500.0) / 600.0, 0.3, 1.0)
		var fire_r = 13.0 * (0.9 + 0.12 * sin(Time.get_ticks_msec() * 0.02))
		draw_circle(Vector2(0, 1), fire_r, Color(1.0, 0.4 * intensity, 0.05, 0.95))
		draw_circle(Vector2.ZERO, fire_r * 0.6, Color(1.0, 0.85, 0.2, 1.0)) # 白炽金内焰

# 3. 鼓风高炉绘制 (耐火砖方形竖炉、铁箍、鼓风管与炽白炉口)
func _draw_blast_furnace() -> void:
	draw_circle(Vector2(0, 5), 27.0, Color(0.1, 0.08, 0.06, 0.5)) # 地面阴影
	draw_rect(Rect2(-20, -22, 40, 42), Color(0.58, 0.40, 0.26))      # 耐火砖炉身
	for row in range(5):
		var y = -22.0 + row * 8.4
		draw_line(Vector2(-20, y), Vector2(20, y), Color(0.40, 0.26, 0.16), 1.0) # 砖缝
	draw_rect(Rect2(-22, -10, 44, 3), Color(0.30, 0.30, 0.32))       # 铁箍
	draw_rect(Rect2(-22, 6, 44, 3), Color(0.30, 0.30, 0.32))
	draw_line(Vector2(20, 12), Vector2(30, 12), Color(0.35, 0.33, 0.30), 4.0) # 鼓风管
	draw_rect(Rect2(-9, 4, 18, 12), Color(0.12, 0.08, 0.06))         # 出铁口暗腔
	if buffer.temperature > 600.0 or is_active_fire:
		var intensity = clamp((buffer.temperature - 600.0) / 900.0, 0.3, 1.0)
		var flick = 0.9 + 0.12 * sin(Time.get_ticks_msec() * 0.02)
		draw_rect(Rect2(-7, 6, 14, 9), Color(1.0, 0.45 * intensity + 0.3, 0.1, 0.95))
		draw_circle(Vector2(0, -24), 7.0 * flick, Color(1.0, 0.75, 0.25, 0.85)) # 炉口火焰
