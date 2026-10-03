# player.gd
# 键盘优先 & 手柄原生兼容的科考探险员控制器
extends CharacterBody2D

@export var speed: float = 240.0

@onready var sprite = $Sprite2D
@onready var camera = $Camera2D
@onready var interact_detector = $InteractDetector

var facing_vector: Vector2 = Vector2.DOWN
var current_target: Area2D = null

func _ready() -> void:
	add_to_group("player")
	if interact_detector:
		interact_detector.area_entered.connect(_on_detector_area_entered)
		interact_detector.area_exited.connect(_on_detector_area_exited)

func _physics_process(_delta: float) -> void:
	# 原生支持键盘 WASD/方向键与手柄摇杆
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		facing_vector = input_vector.normalized()
		# 更新交互探测器朝向
		if interact_detector:
			interact_detector.position = facing_vector * 32.0
			
		# 精灵左右朝向与行走摇摆
		if sprite:
			if input_vector.x != 0:
				sprite.flip_h = input_vector.x < 0
			sprite.rotation = sin(Time.get_ticks_msec() * 0.015) * 0.08
	else:
		if sprite:
			sprite.rotation = move_toward(sprite.rotation, 0.0, 0.05)

	velocity = input_vector * speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# 动作键 1: 开采/敲击 (空格 / J / 手柄 A键)
	if event.is_action_pressed("action_primary"):
		_perform_primary_action()
	# 动作键 2: 交互 (E / 手柄 X键)
	elif event.is_action_pressed("interact"):
		_perform_interact()

func _perform_primary_action() -> void:
	# 敲击动画 (微小缩放与前冲反馈)
	if sprite:
		var tw = create_tween()
		sprite.scale = Vector2(0.42, 0.28)
		tw.tween_property(sprite, "scale", Vector2(0.35, 0.35), 0.12)
		
	if current_target != null:
		if current_target.has_method("mine_node"):
			current_target.mine_node()
		elif current_target.has_method("add_fuel"):
			# 面向熔炉敲击空格快速添柴加火
			current_target.add_fuel()
	else:
		GameState.post_notice("（面前空空如也，面向树木或矿脉按空格采集）", Color(0.7, 0.7, 0.7, 0.6))

func _perform_interact() -> void:
	if current_target != null:
		if current_target.is_in_group("furnace") or current_target.name.begins_with("Furnace"):
			# 触发熔炉交互事件
			current_target.open_workbench_requested.emit(current_target)
		elif current_target.has_method("mine_node"):
			current_target.mine_node()

func _on_detector_area_entered(area: Area2D) -> void:
	current_target = area
	if area.has_method("mine_node"):
		GameState.post_notice("💡 面向了【%s】，按 [空格] 或 [J] 开采！" % area.get("item_name"), Color.YELLOW)
	elif area.is_in_group("furnace") or area.name.begins_with("Furnace"):
		GameState.post_notice("💡 面向了【陶土熔炉】，按 [E] 打开控制台，按 [1/2/3] 投料！", Color.GOLD)

func _on_detector_area_exited(area: Area2D) -> void:
	if current_target == area:
		current_target = null
