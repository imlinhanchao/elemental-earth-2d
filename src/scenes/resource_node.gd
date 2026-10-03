# resource_node.gd
# 像素自然资源节点：矿脉与古代橡树
extends Area2D

@export var item_key: String = "malachite"
@export var item_name: String = "孔雀石矿床"
@export var max_health: int = 3
@export var yield_amount: int = 2

var current_health: int
var is_player_nearby: bool = false

@onready var sprite = $Sprite2D
@onready var label = $NameLabel

func _ready() -> void:
	current_health = max_health
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_setup_sprite()
	if label:
		label.text = item_name

func _setup_sprite() -> void:
	if sprite == null:
		return
		
	if item_key == "malachite":
		sprite.texture = load("res://assets/sprites/malachite_ore.png")
		sprite.scale = Vector2(0.5, 0.5)
	elif item_key == "iron_ore":
		sprite.texture = load("res://assets/sprites/hematite_ore.png")
		sprite.scale = Vector2(0.5, 0.5)
	elif item_key == "wood":
		sprite.texture = load("res://assets/sprites/oak_tree.png")
		sprite.scale = Vector2(0.28, 0.28)
		sprite.position = Vector2(0, -40) # 向上偏移树冠

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_player_nearby:
			mine_node()

func mine_node() -> void:
	current_health -= 1
	
	# 受击弹性挤压动画
	if sprite:
		var tw = create_tween()
		sprite.scale *= Vector2(1.25, 0.8)
		tw.tween_property(sprite, "scale", Vector2(0.5, 0.5) if item_key != "wood" else Vector2(0.28, 0.28), 0.15)

	if current_health <= 0:
		GameState.inventory.add_item(item_key, yield_amount)
		GameState.post_notice("⛏️ 成功开采获得: %s x%d" % [item_name, yield_amount], Color(0.2, 0.9, 0.5))
		
		current_health = max_health
		visible = false
		await get_tree().create_timer(8.0).timeout
		visible = true
	else:
		GameState.post_notice("正在开采 %s... 耐久剩余: %d/%d" % [item_name, current_health, max_health], Color.LIGHT_GRAY)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
