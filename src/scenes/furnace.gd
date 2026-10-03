# furnace.gd
# 像素陶土熔炉实体
extends Area2D

const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

signal open_workbench_requested(furnace_entity: Node2D)

var buffer: MixtureBuffer
var is_player_nearby: bool = false
var is_active_fire: bool = false
var burn_timer: float = 0.0

@onready var sprite = $Sprite2D
@onready var label_status = $StatusLabel

var tex_hot: Texture2D
var tex_cold: Texture2D

func _ready() -> void:
	add_to_group("furnace")
	tex_hot = load("res://assets/sprites/furnace_hot.png")
	tex_cold = load("res://assets/sprites/furnace_cold.png")
	
	buffer = MixtureBuffer.new()
	buffer.temperature = 293.15
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visuals()

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
			# 检查是否炼出单质铜 (Cu)
			if buffer.has_substance("copper", 0.1):
				var cu_amount = buffer.consume_substance("copper", 10.0)
				GameState.inventory.add_item("copper", int(ceil(cu_amount)))
				GameState.post_notice("✨ 熔炉炼制完成！成功收获金属铜 x%d，已收入背包！" % int(ceil(cu_amount)), Color(0.9, 0.6, 0.2))

			# 检查是否炼出单质铁 (Fe)
			if buffer.has_substance("iron", 0.1):
				var fe_amount = buffer.consume_substance("iron", 10.0)
				GameState.inventory.add_item("iron", int(ceil(fe_amount)))
				GameState.post_notice("⚒️ 高炉炼铁完成！成功收获金属铁 x%d，已收入背包！" % int(ceil(fe_amount)), Color(0.7, 0.8, 0.9))

	_update_visuals()

func _update_visuals() -> void:
	if sprite != null:
		if buffer.temperature > 500.0:
			sprite.texture = tex_hot
			sprite.scale = Vector2(0.32, 0.32) * (1.0 + 0.03 * sin(Time.get_ticks_msec() * 0.01))
		else:
			sprite.texture = tex_cold
			sprite.scale = Vector2(0.32, 0.32)

	if label_status != null:
		var fuel_hint = " [E 打开/按1加火]" if is_player_nearby else ""
		label_status.text = "陶土熔炉\n%d K (%d ℃)%s" % [int(buffer.temperature), int(buffer.temperature - 273.15), fuel_hint]

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_player_nearby:
			open_workbench_requested.emit(self)

func add_fuel() -> bool:
	if GameState.inventory.remove_item("charcoal", 1) or GameState.inventory.remove_item("wood", 2):
		is_active_fire = true
		burn_timer += 18.0
		buffer.add_substance("charcoal", 1.0)
		GameState.post_notice("🔥 [按键1] 向熔炉投入木炭燃料，炉膛升起熊熊烈火！", Color.ORANGE)
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

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
