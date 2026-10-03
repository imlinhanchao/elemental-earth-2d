# furnace.gd
# 放置型实体化化学冶炼熔炉
extends Area2D

const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

signal open_workbench_requested(furnace_entity: Node2D)

var buffer: MixtureBuffer
var is_player_nearby: bool = false
var is_active_fire: bool = false
var burn_timer: float = 0.0

@onready var label_status = $StatusLabel

func _ready() -> void:
	buffer = MixtureBuffer.new()
	buffer.temperature = 293.15 # 初始室温
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_label()

func _process(delta: float) -> void:
	# 燃烧逻辑：如果有燃料正在燃烧，维持/升高温度
	if is_active_fire:
		burn_timer -= delta
		buffer.temperature = move_toward(buffer.temperature, 1100.0, 150.0 * delta)
		if burn_timer <= 0.0:
			is_active_fire = false
	else:
		# 无火源自然降温回室温
		buffer.temperature = move_toward(buffer.temperature, 293.15, 30.0 * delta)
	
	# 驱动化学反应
	if buffer.total_moles() > 0:
		var res = GameState.solver.solve(buffer, delta)
		if res["occurred"]:
			queue_redraw()
			_update_label()
			# 检查是否炼出了金属铜
			if buffer.has_substance("copper", 0.1):
				var cu_amount = buffer.consume_substance("copper", 10.0)
				GameState.inventory.add_item("copper", int(ceil(cu_amount)))
				GameState.post_notice("✨ 熔炉炼制完成！成功收获金属铜 x%d，已收入背包！" % int(ceil(cu_amount)), Color(0.9, 0.6, 0.2))

	queue_redraw()
	_update_label()

func _draw() -> void:
	# 绘制圆形熔炉基座
	draw_circle(Vector2.ZERO, 36.0, Color(0.4, 0.26, 0.15))
	draw_circle(Vector2.ZERO, 30.0, Color(0.2, 0.12, 0.06))
	
	# 炉膛火光
	if buffer.temperature > 500.0:
		var glow_intensity = clamp((buffer.temperature - 500.0) / 600.0, 0.2, 1.0)
		var fire_color = Color(1.0, 0.4 * glow_intensity, 0.0, glow_intensity)
		draw_circle(Vector2(0, 4), 16.0 * (0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.01)), fire_color)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_player_nearby:
			open_workbench_requested.emit(self)

func add_fuel() -> bool:
	if GameState.inventory.remove_item("charcoal", 1) or GameState.inventory.remove_item("wood", 2):
		is_active_fire = true
		burn_timer += 15.0 # 燃烧 15 秒
		buffer.add_substance("charcoal", 1.0)
		GameState.post_notice("🔥 向熔炉添加了燃料，火势熊熊燃烧！", Color.ORANGE)
		return true
	else:
		GameState.post_notice("背包中没有木炭或木材可用作燃料！", Color.RED)
		return false

func add_ore(key: String = "malachite", amount: int = 1) -> bool:
	if GameState.inventory.remove_item(key, amount):
		buffer.add_substance(key, float(amount))
		GameState.post_notice("📥 投入原料 %s x%d 到炉膛中" % [key, amount], Color.CYAN)
		return true
	else:
		GameState.post_notice("背包中没有足够的 %s！" % key, Color.RED)
		return false

func _update_label() -> void:
	if label_status:
		label_status.text = "陶土熔炉\n%d K\n物料: %d" % [int(buffer.temperature), int(buffer.total_moles())]

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
