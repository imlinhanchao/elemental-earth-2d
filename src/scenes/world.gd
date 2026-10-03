# world.gd
# 2D 开放大世界总场景
extends Node2D

const FurnaceScene = preload("res://src/scenes/furnace.tscn")

@onready var player = $Player
@onready var hud = $HUD
@onready var furnace = $Furnace

func _ready() -> void:
	_bind_furnace_events(furnace)
	hud.build_furnace_requested.connect(_on_build_furnace_requested)
	
	GameState.post_notice("欢迎来到《元素纪元 2D》！移动开采，炼铁炼铜，按 [P] 查看周期表，按 [C] 建造新熔炉！", Color.WHITE)

func _draw() -> void:
	# 绘制大世界网格地貌地面 (尺寸 3000x2000)
	var ground_rect = Rect2(-1500, -1000, 3000, 2000)
	draw_rect(ground_rect, Color(0.12, 0.16, 0.12)) # 苔原深绿底色
	
	# 装饰性网格线
	var grid_step = 64
	for x in range(-1500, 1500, grid_step):
		draw_line(Vector2(x, -1000), Vector2(x, 1000), Color(0.16, 0.20, 0.16), 1.0)
	for y in range(-1000, 1000, grid_step):
		draw_line(Vector2(-1500, y), Vector2(1500, y), Color(0.16, 0.20, 0.16), 1.0)

func _bind_furnace_events(f_node: Node2D) -> void:
	f_node.body_entered.connect(func(body):
		if body.is_in_group("player"):
			hud.show_furnace_ui(f_node)
			GameState.post_notice("靠近了【陶土熔炉】，可向右侧面板投入矿石冶炼！", Color.GOLD)
	)
	f_node.body_exited.connect(func(body):
		if body.is_in_group("player"):
			hud.hide_furnace_ui()
	)

func _on_build_furnace_requested() -> void:
	if GameState.inventory.remove_item("wood", 4):
		var new_f = FurnaceScene.instantiate()
		new_f.position = player.position + Vector2(40, 20)
		add_child(new_f)
		_bind_furnace_events(new_f)
		GameState.post_notice("🔨 现场施工完成！成功消耗 4 块木材建造了一座新的陶土熔炉！", Color.GREEN)
	else:
		GameState.post_notice("❌ 建造失败！需要至少 4 块木材 (先去砍伐橡树吧)", Color.RED)
