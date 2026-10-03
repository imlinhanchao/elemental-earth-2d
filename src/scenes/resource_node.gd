# resource_node.gd
# 像素自然资源节点：支持原始拾取物与硬度工具阶梯判定
extends Area2D

@export var item_key: String = "malachite"
@export var item_name: String = "孔雀石矿床"
@export var max_health: int = 4
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
		label.visible = false

func _setup_sprite() -> void:
	if sprite == null:
		return
		
	var tex_path = ""
	var s_scale = Vector2(0.5, 0.5)
	var s_pos = Vector2.ZERO
	
	if item_key == "malachite":
		tex_path = "res://assets/sprites/malachite_ore.png"
	elif item_key == "iron_ore":
		tex_path = "res://assets/sprites/hematite_ore.png"
	elif item_key == "wood":
		tex_path = "res://assets/sprites/oak_tree.png"
		s_scale = Vector2(0.28, 0.28)
		s_pos = Vector2(0, -40)
	elif item_key == "flint": # 散落碎石
		s_scale = Vector2(0.3, 0.3)
	elif item_key == "stick": # 地表断枝
		s_scale = Vector2(0.3, 0.3)
		
	if tex_path != "":
		var img = Image.load_from_file(ProjectSettings.globalize_path(tex_path))
		if img:
			sprite.texture = ImageTexture.create_from_image(img)
			sprite.scale = s_scale
			sprite.position = s_pos
	else:
		# 碎石与断枝使用轻量几何绘制或备用图
		queue_redraw()

func _draw() -> void:
	if item_key == "flint":
		# 绘制地表灰白碎石晶屑
		draw_circle(Vector2(-4, 2), 6.0, Color(0.75, 0.78, 0.8))
		draw_circle(Vector2(5, -2), 5.0, Color(0.6, 0.65, 0.7))
	elif item_key == "stick":
		# 绘制地表交叉小断枝
		draw_line(Vector2(-8, -4), Vector2(8, 4), Color(0.55, 0.35, 0.2), 3.0)
		draw_line(Vector2(-4, 6), Vector2(6, -6), Color(0.45, 0.28, 0.15), 2.5)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_player_nearby:
			mine_node()

func mine_node() -> void:
	# 检查玩家工具阶梯
	var axe = GameState.equipped_tools.get("axe", "bare_hands")
	var pick = GameState.equipped_tools.get("pickaxe", "bare_hands")

	# 1. 砍伐大橡树必须拥有斧头
	if item_key == "wood":
		if axe == "bare_hands":
			GameState.post_notice("❌ 橡树坚硬，徒手无法折断！请按 [C] 用收集的树枝与碎石制作【燧石手斧】！", Color(1.0, 0.4, 0.4))
			return
	
	# 2. 开采硬质矿石必须拥有石镐或更高级
	if item_key in ["malachite", "iron_ore", "sulfur", "halite", "coal"]:
		if pick == "bare_hands":
			GameState.post_notice("❌ 矿脉坚如磐石，徒手无法挖掘！请按 [C] 制作【粗制石镐】！", Color(1.0, 0.4, 0.4))
			return

	# 计算开采伤害
	var damage = 1
	if item_key == "wood":
		damage = 2 if axe == "flint_axe" else 4
	elif item_key in ["malachite", "iron_ore", "sulfur", "halite", "coal"]:
		if pick == "copper_pickaxe": damage = 2
		elif pick == "iron_pickaxe": damage = 4
		else: damage = 1 # 普通石镐
		
	# 地表碎石与断枝徒手一击即得
	if item_key in ["flint", "stick"]:
		damage = max_health

	current_health -= damage
	
	# 受击动画
	if sprite:
		var tw = create_tween()
		sprite.scale *= Vector2(1.25, 0.75)
		tw.tween_property(sprite, "scale", Vector2(0.5, 0.5) if item_key != "wood" else Vector2(0.28, 0.28), 0.12)

	if current_health <= 0:
		GameState.inventory.add_item(item_key, yield_amount)
		GameState.post_notice("✨ 获得: %s x%d！" % [item_name, yield_amount], Color(0.2, 0.9, 0.5))
		
		current_health = max_health
		visible = false
		await get_tree().create_timer(10.0).timeout
		visible = true
	else:
		GameState.post_notice("正在开采 %s... 耐久剩余: %d/%d" % [item_name, current_health, max_health], Color.LIGHT_GRAY)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		if label: label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		if label: label.visible = false
