# resource_node.gd
# 自然资源节点：支持玩家点击敲击采集
extends Area2D

@export var item_key: String = "malachite"
@export var item_name: String = "孔雀石矿脉"
@export var node_color: Color = Color(0.12, 0.75, 0.45)
@export var max_health: int = 3
@export var yield_amount: int = 2

var current_health: int

@onready var shape = $CollisionShape2D
var is_player_nearby: bool = false

func _ready() -> void:
	current_health = max_health
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

func _draw() -> void:
	# 绘制独特的资源图标图形
	draw_circle(Vector2.ZERO, 24.0, node_color)
	draw_circle(Vector2.ZERO, 20.0, node_color.darkened(0.2))
	# 内部高光晶体斑纹
	draw_rect(Rect2(-8, -8, 16, 16), node_color.lightened(0.3))

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_player_nearby:
			mine_node()

func mine_node() -> void:
	current_health -= 1
	# 简单的敲击受击缩放动画
	var tw = create_tween()
	scale = Vector2(1.2, 0.8)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15)
	
	if current_health <= 0:
		# 采集完毕
		GameState.inventory.add_item(item_key, yield_amount)
		GameState.post_notice("⛏️ 成功开采获得: %s x%d" % [item_name, yield_amount], node_color)
		
		# 播放粉碎动画后重生或消失
		current_health = max_health
		visible = false
		await get_tree().create_timer(5.0).timeout
		visible = true
	else:
		GameState.post_notice("正在开采 %s... (%d/%d)" % [item_name, current_health, max_health], Color.GRAY)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
