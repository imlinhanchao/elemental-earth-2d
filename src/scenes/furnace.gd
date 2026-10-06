# furnace.gd
# 严丝合缝对齐六边形网格的陶土熔炉/原始篝火堆实体: 纯表现层节点，模拟运算交由 Simulation 一秒时钟
extends Area2D

const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

signal open_workbench_requested(furnace_entity: Node2D)

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
			return GameState.built_furnaces[hex_coord].get("is_active_fire", false)
		return false

var burn_timer: float:
	get:
		if GameState.built_furnaces.has(hex_coord):
			return GameState.built_furnaces[hex_coord].get("burn_timer", 0.0)
		return 0.0

var _fallback_buffer: MixtureBuffer = null

@onready var label_status = $StatusLabel

func _ready() -> void:
	add_to_group("furnace")
	if GameState.built_furnaces.has(hex_coord):
		building_type = GameState.built_furnaces[hex_coord].get("type", building_type)
	queue_redraw()

func _process(_delta: float) -> void:
	if label_status:
		var b_name = DataDB.get_building_recipe(building_type).get("name", "熔炉")
		label_status.text = "%s\n%d K (%d ℃)\n[点击打开]" % [b_name, int(buffer.temperature), int(buffer.temperature - 273.15)]
	queue_redraw()

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

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	var world_node = get_tree().get_first_node_in_group("world")
	if world_node and "is_placing_structure" in world_node and world_node.is_placing_structure:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		open_workbench_requested.emit(self)

func add_fuel() -> bool:
	return GameState.furnace_add_fuel(hex_coord)

func add_ore(key: String, amount: int = 1) -> bool:
	return GameState.furnace_add_ore(hex_coord, key, amount)
