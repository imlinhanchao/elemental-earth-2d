# furnace.gd
# 严丝合缝对齐六边形网格的陶土熔炉实体: 纯表现层节点，模拟运算交由 Simulation 一秒时钟
extends Area2D

const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

signal open_workbench_requested(furnace_entity: Node2D)

var hex_coord: Vector2i = Vector2i(9999, 9999)
var buffer: MixtureBuffer:
	get:
		if GameState.built_furnaces.has(hex_coord):
			return GameState.built_furnaces[hex_coord]["buffer"]
		if _fallback_buffer == null:
			_fallback_buffer = MixtureBuffer.new()
			_fallback_buffer.container_type = "furnace"
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
	_sync_simulation_state()
	queue_redraw()

func _sync_simulation_state() -> void:
	if not GameState.built_furnaces.has(hex_coord):
		var f_buf = MixtureBuffer.new()
		f_buf.container_type = "furnace"
		f_buf.temperature = 293.15
		GameState.built_furnaces[hex_coord] = {
			"buffer": f_buf,
			"burn_timer": 0.0,
			"is_active_fire": false
		}

func _process(_delta: float) -> void:
	if label_status:
		label_status.text = "陶土熔炉\n%d K (%d ℃)\n[点击打开]" % [int(buffer.temperature), int(buffer.temperature - 273.15)]
	queue_redraw()

func _draw() -> void:
	# 绘制贴合六边形尺寸的陶土圆窑 (底座半径 24.0)
	draw_circle(Vector2(0, 4), 26.0, Color(0.1, 0.08, 0.06, 0.5)) # 地面阴影
	draw_circle(Vector2.ZERO, 25.0, Color(0.42, 0.26, 0.15))       # 粗陶土外壁
	draw_circle(Vector2.ZERO, 21.0, Color(0.55, 0.35, 0.20))       # 耐火砖层
	draw_circle(Vector2.ZERO, 15.0, Color(0.15, 0.10, 0.08))       # 炉膛深处暗腔
	
	# 炉膛火焰动态效果
	if buffer.temperature > 500.0:
		var intensity = clamp((buffer.temperature - 500.0) / 600.0, 0.3, 1.0)
		var fire_r = 13.0 * (0.9 + 0.12 * sin(Time.get_ticks_msec() * 0.02))
		draw_circle(Vector2(0, 1), fire_r, Color(1.0, 0.4 * intensity, 0.05, 0.95))
		draw_circle(Vector2.ZERO, fire_r * 0.6, Color(1.0, 0.85, 0.2, 1.0)) # 白炽金内焰

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		open_workbench_requested.emit(self)

func add_fuel() -> bool:
	return GameState.furnace_add_fuel(hex_coord)

func add_ore(key: String, amount: int = 1) -> bool:
	return GameState.furnace_add_ore(hex_coord, key, amount)
