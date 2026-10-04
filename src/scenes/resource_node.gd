# resource_node.gd
# 严丝合缝对齐六边形网格的纯手绘级像素矿脉与植被图元
extends Area2D

@export var item_key: String = "malachite"
@export var item_name: String = "孔雀石矿床"
@export var max_health: int = 4
@export var yield_amount: int = 2

var current_health: int
var is_player_nearby: bool = false
var anim_scale: Vector2 = Vector2.ONE
var anim_rotation: float = 0.0

@onready var label = $NameLabel

func _ready() -> void:
	current_health = max_health
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if label:
		label.text = item_name
		label.visible = false
	queue_redraw()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_player_nearby:
			mine_node()

func mine_node() -> void:
	var axe = GameState.equipped_tools.get("axe", "bare_hands")
	var pick = GameState.equipped_tools.get("pickaxe", "bare_hands")

	if item_key == "wood":
		if axe == "bare_hands":
			GameState.post_notice("❌ 橡树坚硬，徒手无法折断！请按 [C] 制作【原始燧石手斧】！", Color(1.0, 0.4, 0.4))
			return
	
	if item_key in ["malachite", "iron_ore", "sulfur", "halite", "coal"]:
		if pick == "bare_hands":
			GameState.post_notice("❌ 矿脉坚如磐石，徒手无法挖掘！请按 [C] 制作【粗制石镐】！", Color(1.0, 0.4, 0.4))
			return

	var damage = 1
	if item_key == "wood":
		damage = 2 if axe == "flint_axe" else 4
	elif item_key in ["malachite", "iron_ore", "sulfur", "halite", "coal"]:
		if pick == "copper_pickaxe": damage = 2
		elif pick == "iron_pickaxe": damage = 4
		else: damage = 1
		
	if item_key in ["flint", "stick"]:
		damage = max_health

	current_health -= damage
	
	# 受击弹性挤压动画反馈
	var tw = create_tween()
	anim_scale = Vector2(1.3, 0.7)
	anim_rotation = randf_range(-0.15, 0.15)
	tw.tween_property(self, "anim_scale", Vector2.ONE, 0.12)
	tw.parallel().tween_property(self, "anim_rotation", 0.0, 0.12)

	if current_health <= 0:
		GameState.inventory.add_item(item_key, yield_amount)
		GameState.post_notice("✨ 获得: %s x%d！" % [item_name, yield_amount], Color(0.2, 0.9, 0.5))
		
		current_health = max_health
		visible = false
		await get_tree().create_timer(10.0).timeout
		visible = true
	else:
		GameState.post_notice("正在开采 %s... 耐久剩余: %d/%d" % [item_name, current_health, max_health], Color.LIGHT_GRAY)
		
	queue_redraw()

func _process(_delta: float) -> void:
	if anim_scale != Vector2.ONE or anim_rotation != 0.0:
		queue_redraw()

func _draw() -> void:
	# 应用弹性受击变换
	draw_set_transform(Vector2.ZERO, anim_rotation, anim_scale)
	
	# 绘制严密契合六边形（半径约 24~28px）的高精度像素艺术资产
	match item_key:
		"malachite":
			_draw_malachite_crystals()
		"iron_ore":
			_draw_hematite_rocks()
		"wood":
			_draw_hex_oak_tree()
		"sulfur":
			_draw_sulfur_crystals()
		"halite":
			_draw_halite_cubes()
		"flint":
			_draw_loose_flint()
		"stick":
			_draw_fallen_stick()
		_:
			draw_circle(Vector2.ZERO, 16.0, Color.WHITE)

# 1. 孔雀石晶簇 (Emerald Green Hex Crystals)
func _draw_malachite_crystals() -> void:
	# 地面暗绿色矿脉阴影
	draw_circle(Vector2(0, 4), 22.0, Color(0.06, 0.18, 0.10, 0.6))
	# 主晶簇 1: 向上凸起的晶尖棱柱
	_draw_crystal_poly(Vector2(-8, -2), Vector2(14, 28), Color(0.12, 0.65, 0.35), Color(0.25, 0.92, 0.52))
	# 主晶簇 2: 斜向晶簇
	_draw_crystal_poly(Vector2(8, 2), Vector2(12, 22), Color(0.08, 0.52, 0.28), Color(0.20, 0.82, 0.45))
	# 前置小晶簇
	_draw_crystal_poly(Vector2(-2, 10), Vector2(10, 16), Color(0.16, 0.75, 0.42), Color(0.35, 0.98, 0.60))

# 2. 赤铁矿多面岩 (Metallic Dark Red Hematite Rocks)
func _draw_hematite_rocks() -> void:
	draw_circle(Vector2(0, 4), 22.0, Color(0.15, 0.05, 0.05, 0.6)) # 阴影
	# 主矿块
	draw_colored_polygon([
		Vector2(-16, 8), Vector2(-12, -14), Vector2(4, -18),
		Vector2(16, -6), Vector2(18, 12), Vector2(2, 16)
	], Color(0.55, 0.16, 0.14))
	# 受光亮面
	draw_colored_polygon([
		Vector2(-12, -14), Vector2(4, -18), Vector2(16, -6), Vector2(2, -4)
	], Color(0.78, 0.28, 0.22))
	# 金属高光棱线
	draw_line(Vector2(-12, -14), Vector2(2, -4), Color(0.95, 0.55, 0.45), 2.0)
	draw_line(Vector2(4, -18), Vector2(2, -4), Color(0.95, 0.55, 0.45), 2.0)

# 3. 六边形饱满橡树 (Hexagon-Fitted Oak Tree)
func _draw_hex_oak_tree() -> void:
	# 树荫投影 (平铺半透明阴影)
	draw_circle(Vector2(0, 14), 18.0, Color(0.05, 0.12, 0.06, 0.4))
	# 树干
	draw_rect(Rect2(-5, 0, 10, 16), Color(0.38, 0.22, 0.12))
	draw_line(Vector2(-6, 20), Vector2(-12, 24), Color(0.32, 0.18, 0.10), 3.0) # 树根
	draw_line(Vector2(6, 20), Vector2(12, 24), Color(0.32, 0.18, 0.10), 3.0)
	# 蓬松树冠 (深层阴影绿)
	draw_circle(Vector2(0, -6), 25.0, Color(0.14, 0.32, 0.16))
	# 主树冠 (茂盛原野绿)
	draw_circle(Vector2(0, -10), 22.0, Color(0.24, 0.52, 0.22))
	# 顶部高光层 (向阳淡绿)
	draw_circle(Vector2(-4, -14), 16.0, Color(0.38, 0.70, 0.30))
	draw_circle(Vector2(5, -16), 11.0, Color(0.48, 0.78, 0.38))

# 4. 硫磺结晶 (Bright Yellow Sulfur)
func _draw_sulfur_crystals() -> void:
	draw_circle(Vector2(0, 4), 20.0, Color(0.2, 0.18, 0.05, 0.6))
	_draw_crystal_poly(Vector2(-6, 0), Vector2(12, 24), Color(0.85, 0.75, 0.12), Color(1.0, 0.95, 0.35))
	_draw_crystal_poly(Vector2(6, 4), Vector2(10, 18), Color(0.75, 0.65, 0.10), Color(0.95, 0.88, 0.30))

# 5. 石盐立方晶体 (Halite / Salt)
func _draw_halite_cubes() -> void:
	draw_circle(Vector2(0, 4), 20.0, Color(0.1, 0.15, 0.2, 0.5))
	# 立方体 1
	_draw_cube(Vector2(-8, -4), 14.0, Color(0.70, 0.82, 0.92, 0.9))
	# 立方体 2
	_draw_cube(Vector2(6, 4), 12.0, Color(0.80, 0.90, 0.98, 0.9))

# 6. 散落多面原石/碎石 (Loose Stones - 棱角分明的石块与投影)
func _draw_loose_flint() -> void:
	# 石块阴影
	draw_circle(Vector2(0, 4), 10.0, Color(0.08, 0.10, 0.12, 0.45))
	# 主原石 (带切面的多面岩块)
	draw_colored_polygon([
		Vector2(-8, 3), Vector2(-6, -7), Vector2(2, -9),
		Vector2(8, -2), Vector2(6, 6), Vector2(-3, 7)
	], Color(0.48, 0.52, 0.56))
	# 向阳受光面
	draw_colored_polygon([
		Vector2(-6, -7), Vector2(2, -9), Vector2(8, -2), Vector2(0, -1)
	], Color(0.72, 0.76, 0.82))
	# 伴生小石块
	draw_colored_polygon([
		Vector2(-10, 5), Vector2(-7, 1), Vector2(-4, 6)
	], Color(0.60, 0.65, 0.70))
	draw_colored_polygon([
		Vector2(5, 4), Vector2(9, 2), Vector2(10, 7)
	], Color(0.62, 0.66, 0.72))
	# 石头白色锋利高光棱
	draw_line(Vector2(-6, -7), Vector2(0, -1), Color(0.92, 0.95, 0.98), 1.5)

# 7. 枯树枝 (Fallen Sticks - 明亮原木色多叉枯枝)
func _draw_fallen_stick() -> void:
	# 树枝小投影
	draw_line(Vector2(-12, -4), Vector2(12, 8), Color(0.08, 0.12, 0.08, 0.4), 4.5)
	# 主枯枝 (暖棕色)
	draw_line(Vector2(-12, -6), Vector2(12, 6), Color(0.58, 0.38, 0.22), 4.0)
	# 侧分叉枝 1
	draw_line(Vector2(-2, -1), Vector2(6, -9), Color(0.68, 0.45, 0.26), 3.0)
	# 侧分叉枝 2
	draw_line(Vector2(2, 1), Vector2(-4, 9), Color(0.50, 0.32, 0.18), 3.0)
	# 树枝高光倒棱线
	draw_line(Vector2(-10, -7), Vector2(8, 4), Color(0.82, 0.60, 0.38), 1.5)

# 晶簇绘制辅助函数
func _draw_crystal_poly(pos: Vector2, size: Vector2, base_col: Color, light_col: Color) -> void:
	var hw = size.x / 2.0
	var hh = size.y / 2.0
	# 暗面多边形
	draw_colored_polygon([
		pos + Vector2(0, -hh), pos + Vector2(-hw, -hh * 0.3),
		pos + Vector2(-hw, hh), pos + Vector2(0, hh * 0.8)
	], base_col.darkened(0.2))
	# 亮面多边形
	draw_colored_polygon([
		pos + Vector2(0, -hh), pos + Vector2(hw, -hh * 0.3),
		pos + Vector2(hw, hh), pos + Vector2(0, hh * 0.8)
	], light_col)
	# 晶尖高光
	draw_line(pos + Vector2(0, -hh), pos + Vector2(0, hh * 0.8), light_col.lightened(0.4), 1.5)

# 立方体绘制辅助函数
func _draw_cube(pos: Vector2, s: float, col: Color) -> void:
	draw_rect(Rect2(pos.x - s/2, pos.y - s/2, s, s), col)
	draw_rect(Rect2(pos.x - s/2, pos.y - s/2, s, s), col.lightened(0.3), false, 1.5)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		if label: label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		if label: label.visible = false
