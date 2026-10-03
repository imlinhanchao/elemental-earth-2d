# player.gd
# 玩家移动与交互控制器
extends CharacterBody2D

@export var speed: float = 240.0

@onready var camera = $Camera2D

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	
	velocity = dir.normalized() * speed
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	# 绘制极具辨识度的探险科研人员俯视形象
	# 阴影
	draw_circle(Vector2(0, 4), 16.0, Color(0, 0, 0, 0.25))
	# 身体/披肩 (复古科学蓝)
	draw_circle(Vector2.ZERO, 16.0, Color(0.18, 0.48, 0.72))
	# 头部/护目镜
	draw_circle(Vector2(0, -2), 10.0, Color(0.9, 0.8, 0.65))
	draw_rect(Rect2(-6, -6, 12, 4), Color(0.2, 0.7, 0.9)) # 护目镜
