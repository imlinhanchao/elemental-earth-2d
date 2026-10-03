# player.gd
# 像素科考探险员角色控制器
extends CharacterBody2D

@export var speed: float = 240.0

@onready var sprite = $Sprite2D
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
	
	# 根据移动方向平滑翻转朝向
	if dir.x != 0 and sprite != null:
		sprite.flip_h = dir.x < 0
		
	# 行走微小摆动动画
	if dir != Vector2.ZERO and sprite != null:
		sprite.rotation = sin(Time.get_ticks_msec() * 0.015) * 0.08
	elif sprite != null:
		sprite.rotation = move_toward(sprite.rotation, 0.0, 0.05)
