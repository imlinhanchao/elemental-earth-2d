# furnace.gd
# 严丝合缝对齐六边形网格的陶土熔炉实体
extends Area2D

const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

signal open_workbench_requested(furnace_entity: Node2D)

var buffer: MixtureBuffer
var is_player_nearby: bool = false
var is_active_fire: bool = false
var burn_timer: float = 0.0

@onready var label_status = $StatusLabel

func _ready() -> void:
	add_to_group("furnace")
	buffer = MixtureBuffer.new()
	buffer.container_type = "furnace"
	buffer.temperature = 293.15
	queue_redraw()

func _process(delta: float) -> void:
	if is_active_fire:
		burn_timer -= delta
		buffer.temperature = move_toward(buffer.temperature, 1100.0, 180.0 * delta)
		if burn_timer <= 0.0:
			is_active_fire = false
	else:
		buffer.temperature = move_toward(buffer.temperature, 293.15, 35.0 * delta)
	
	# 驱动化学反应
	if buffer.total_moles() > 0:
		var res = GameState.solver.solve(buffer, delta)
		if res["occurred"]:
			# 炉膛为敞开燃烧环境，气态副产物自然逸散
			buffer.consume_substance("carbon_dioxide", 999.0)
			buffer.consume_substance("carbon_monoxide", 999.0)
			
			for prod_key in res.get("products", []):
				if buffer.has_substance(prod_key, 0.1):
					var p_amount = buffer.consume_substance(prod_key, 999.0)
					var p_int = int(ceil(p_amount))
					if p_int > 0:
						GameState.inventory.add_item(prod_key, p_int)
						var iname = DataDB.get_item(prod_key).get("name", prod_key)
						GameState.post_notice("✨ 熔炉炼制完成！成功收获 %s x%d，已收入背包！" % [iname, p_int], Color(0.9, 0.65, 0.2))

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
		draw_circle(Vector2(0, 0), fire_r * 0.6, Color(1.0, 0.85, 0.2, 1.0)) # 白炽金内焰

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		open_workbench_requested.emit(self)

func add_fuel() -> bool:
	if GameState.inventory.remove_item("charcoal", 1) or GameState.inventory.remove_item("wood", 2):
		is_active_fire = true
		burn_timer += 18.0
		buffer.add_substance("charcoal", 1.0)
		GameState.post_notice("🔥 向熔炉投入木炭燃料，炉膛升起熊熊烈火！", Color.ORANGE)
		return true
	else:
		GameState.post_notice("背包中没有木炭或木材可用作燃料！", Color.RED)
		return false

func add_ore(key: String, amount: int = 1) -> bool:
	if GameState.inventory.remove_item(key, amount):
		buffer.add_substance(key, float(amount))
		var iname = DataDB.get_item(key).get("name", key)
		GameState.post_notice("📥 投入原料: %s x%d 到炉膛中" % [iname, amount], Color.CYAN)
		return true
	else:
		GameState.post_notice("背包中没有足够的原料！", Color.RED)
		return false
