# world.gd
# 2D 开放大世界总场景
extends Node2D

@onready var player = $Player
@onready var hud = $HUD
@onready var furnace = $Furnace

func _ready() -> void:
	furnace.body_entered.connect(_on_furnace_body_entered)
	furnace.body_exited.connect(_on_furnace_body_exited)
	
	GameState.post_notice("欢迎来到《元素纪元 2D》！使用 [W/A/S/D] 移动角色探索世界。", Color.WHITE)

func _draw() -> void:
	# 绘制大世界网格地貌地面 (尺寸 2400x1600)
	var ground_rect = Rect2(-1200, -800, 2400, 1600)
	draw_rect(ground_rect, Color(0.14, 0.18, 0.14)) # 苔原绿底色
	
	# 装饰性网格线
	var grid_step = 64
	for x in range(-1200, 1200, grid_step):
		draw_line(Vector2(x, -800), Vector2(x, 800), Color(0.18, 0.22, 0.18), 1.0)
	for y in range(-800, 800, grid_step):
		draw_line(Vector2(-1200, y), Vector2(1200, y), Color(0.18, 0.22, 0.18), 1.0)

func _on_furnace_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		hud.show_furnace_ui(furnace)
		GameState.post_notice("靠近了【陶土熔炉】，可向右侧面板投入矿石与木炭冶炼！", Color.GOLD)

func _on_furnace_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		hud.hide_furnace_ui()
