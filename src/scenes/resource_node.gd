# resource_node.gd
# 严丝合缝对齐六边形网格的纯手绘级像素矿脉与植被图元
extends Area2D

@export var item_key: String = "malachite"
@export var item_name: String = "孔雀石矿床"
@export var max_health: int = 4
@export var yield_amount: int = 2
@export var hex_coord: Vector2i = Vector2i(9999, 9999)

var current_health: int
var is_hovered: bool = false
var anim_scale: Vector2 = Vector2.ONE
var anim_rotation: float = 0.0
var _is_working: bool = false

@onready var label = $NameLabel

func _ready() -> void:
	current_health = max_health
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	GameState.tile_depleted.connect(_on_tile_depleted)
	GameState.tile_respawned.connect(_on_tile_respawned)
	GameState.task_completed.connect(_on_task_finished)
	GameState.task_cancelled.connect(_on_task_finished)
	GameState.task_queue_changed.connect(_on_task_queue_changed)
	
	if label:
		label.text = item_name
		label.visible = false
	queue_redraw()

func _on_task_finished(_t: Dictionary) -> void:
	if _is_working:
		_is_working = false
		queue_redraw()

func _on_task_queue_changed() -> void:
	var active_hex = GameState.get_active_task_hex()
	if _is_working and (active_hex != hex_coord or active_hex == Vector2i(9999, 9999)):
		_is_working = false
		queue_redraw()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	var world_node = get_tree().get_first_node_in_group("world")
	if world_node and "is_placing_structure" in world_node and world_node.is_placing_structure:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		request_mine_task()

func _on_mouse_entered() -> void:
	is_hovered = true
	if label: label.visible = true
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	if label: label.visible = false
	queue_redraw()

func request_mine_task() -> void:
	if not visible:
		return
	GameState.queue_hex_mine(hex_coord, item_key, 1, global_position)

func _on_tile_depleted(hex: Vector2i) -> void:
	if hex == hex_coord:
		harvest_complete()

func _on_tile_respawned(hex: Vector2i) -> void:
	if hex == hex_coord:
		visible = true
		var tw = create_tween()
		scale = Vector2.ZERO
		tw.tween_property(self, "scale", Vector2.ONE, 0.25)
		queue_redraw()

func harvest_complete() -> void:
	# 受击弹性挤压与暂时隐匿动画
	var tw = create_tween()
	anim_scale = Vector2(1.3, 0.6)
	anim_rotation = randf_range(-0.15, 0.15)
	tw.tween_property(self, "anim_scale", Vector2.ZERO, 0.15)
	tw.parallel().tween_property(self, "anim_rotation", 0.0, 0.15)
	await tw.finished
	visible = false
	anim_scale = Vector2.ONE

func _process(_delta: float) -> void:
	# 动态根据领地状态调暗超出领地的节点
	if not GameState.is_pos_in_territory(global_position):
		modulate = Color(0.65, 0.65, 0.75, 0.55)
	else:
		modulate = Color.WHITE

	# 若当前节点正是正在开工的目标，持续重绘显示工作环；开工结束时立即触发单次重绘擦除绿圈
	var active_hex = GameState.get_active_task_hex()
	var is_active = (active_hex == hex_coord and active_hex != Vector2i(9999, 9999))
	if is_active:
		_is_working = true
		queue_redraw()
	elif _is_working:
		_is_working = false
		queue_redraw()
	elif anim_scale != Vector2.ONE or anim_rotation != 0.0:
		queue_redraw()

func _draw() -> void:
	# 若当前节点被选中且正由任务作业，先绘制环形发光进度环
	var active_hex = GameState.get_active_task_hex()
	if active_hex == hex_coord and active_hex != Vector2i(9999, 9999):
		var total = float(GameState.active_task.get("time_required", GameState.active_task.get("total_time", 1.0)))
		var begin_time = int(GameState.active_task.get("begin_time", 0))
		var elapsed = (Time.get_ticks_msec() - begin_time) / 1000.0 if begin_time > 0 else float(GameState.active_task.get("elapsed_time", 0.0))
		var pct = clamp(elapsed / max(total, 0.001), 0.0, 1.0)
		# 阴影发光底环
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 32, Color(0.1, 0.6, 0.8, 0.35), 4.0)
		# 充能进度环
		draw_arc(Vector2.ZERO, 24.0, -PI/2, -PI/2 + pct * TAU, 32, Color(0.3, 1.0, 0.6, 0.95), 4.5)

	# 鼠标悬停时的微光光圈
	if is_hovered:
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(1.0, 0.88, 0.4, 0.4), 2.0)

	# 应用弹性受击变换
	draw_set_transform(Vector2.ZERO, anim_rotation, anim_scale)
	
	# 绘制严密契合六边形（覆盖全瓦片）的高精度晶簇与地貌资源资产
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
		"stone":
			_draw_loose_stone()
		"flint":
			_draw_loose_flint()
		"stick":
			_draw_fallen_stick()
		"bauxite":
			_draw_bauxite_deposit()
		"pyrite":
			_draw_pyrite_crystals()
		"galena":
			_draw_galena_cubes()
		"sphalerite":
			_draw_sphalerite_crystals()
		"monazite":
			_draw_monazite_pegmatite()
		"pitchblende":
			_draw_pitchblende_nodules()
		"clay":
			_draw_clay_bank()
		"charcoal":
			_draw_charcoal_bed()
		_:
			_draw_loose_stone()

# 1. 孔雀石晶簇 (Emerald Green Hex Crystals)
func _draw_malachite_crystals() -> void:
	_draw_crystal_poly(Vector2(-7, -2), Vector2(13, 26), Color(0.12, 0.65, 0.35), Color(0.25, 0.92, 0.52))
	_draw_crystal_poly(Vector2(7, 2), Vector2(11, 20), Color(0.08, 0.52, 0.28), Color(0.20, 0.82, 0.45))
	_draw_crystal_poly(Vector2(-1, 8), Vector2(9, 14), Color(0.16, 0.75, 0.42), Color(0.35, 0.98, 0.60))

# 2. 赤铁矿多面岩 (Metallic Hematite Rocks)
func _draw_hematite_rocks() -> void:
	draw_colored_polygon([
		Vector2(-14, 6), Vector2(-10, -10), Vector2(4, -14),
		Vector2(14, -4), Vector2(15, 10), Vector2(2, 13)
	], Color(0.55, 0.16, 0.14))
	draw_colored_polygon([
		Vector2(-10, -10), Vector2(4, -14), Vector2(14, -4), Vector2(2, -2)
	], Color(0.78, 0.28, 0.22))
	draw_line(Vector2(-10, -10), Vector2(2, -2), Color(0.95, 0.55, 0.45), 1.8)
	draw_line(Vector2(4, -14), Vector2(2, -2), Color(0.95, 0.55, 0.45), 1.8)

# 3. 六边形饱满橡树 (Hexagon-Fitted Oak Tree)
func _draw_hex_oak_tree() -> void:
	draw_circle(Vector2(0, 14), 16.0, Color(0.05, 0.12, 0.06, 0.35))
	draw_rect(Rect2(-4, 0, 8, 14), Color(0.38, 0.22, 0.12))
	draw_circle(Vector2(0, -6), 20.0, Color(0.12, 0.28, 0.14))
	draw_circle(Vector2(0, -9), 17.0, Color(0.22, 0.48, 0.20))
	draw_circle(Vector2(-3, -12), 12.0, Color(0.35, 0.65, 0.28))
	draw_circle(Vector2(4, -13), 8.0, Color(0.45, 0.75, 0.35))

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

# 6. 散落碎石块 (Loose Stones - 灰白色天然碎石与伴生岩屑)
func _draw_loose_stone() -> void:
	# 石块阴影
	draw_circle(Vector2(0, 4), 10.0, Color(0.08, 0.10, 0.12, 0.40))
	# 主原石 (带切面的暖灰多面花岗岩/石灰岩块)
	draw_colored_polygon([
		Vector2(-8, 3), Vector2(-6, -7), Vector2(2, -9),
		Vector2(8, -2), Vector2(6, 6), Vector2(-3, 7)
	], Color(0.56, 0.54, 0.50))
	# 向阳受光面
	draw_colored_polygon([
		Vector2(-6, -7), Vector2(2, -9), Vector2(8, -2), Vector2(0, -1)
	], Color(0.78, 0.76, 0.72))
	# 伴生小石块
	draw_colored_polygon([
		Vector2(-10, 5), Vector2(-7, 1), Vector2(-4, 6)
	], Color(0.66, 0.64, 0.60))
	draw_colored_polygon([
		Vector2(5, 4), Vector2(9, 2), Vector2(10, 7)
	], Color(0.68, 0.65, 0.62))
	# 白色钝感风化石棱线
	draw_line(Vector2(-6, -7), Vector2(0, -1), Color(0.92, 0.90, 0.86), 1.5)

# 6.5 坚硬锋利燧石 (Flint - 深黑玄武岩质、断面贝壳状带有锐利锋芒)
func _draw_loose_flint() -> void:
	# 锐利阴影
	draw_circle(Vector2(0, 4), 9.0, Color(0.04, 0.05, 0.08, 0.55))
	# 主燧石 (深青灰致密块体)
	draw_colored_polygon([
		Vector2(-9, 4), Vector2(-4, -9), Vector2(4, -8),
		Vector2(9, 1), Vector2(5, 7), Vector2(-2, 8)
	], Color(0.24, 0.26, 0.30))
	# 锋利贝壳状断口受光面
	draw_colored_polygon([
		Vector2(-4, -9), Vector2(4, -8), Vector2(9, 1), Vector2(1, -2)
	], Color(0.44, 0.48, 0.54))
	# 晶莹锐角小碎块
	draw_colored_polygon([
		Vector2(-8, -2), Vector2(-6, -6), Vector2(-4, -3)
	], Color(0.35, 0.38, 0.45))
	# 燧石刃口极亮冰蓝高光线 (如刃割物)
	draw_line(Vector2(-4, -9), Vector2(1, -2), Color(0.75, 0.90, 1.0), 1.8)
	draw_line(Vector2(1, -2), Vector2(9, 1), Color(0.85, 0.95, 1.0), 1.8)

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

# 梯形钢锭辅助绘制函数 (方案三 Fe 元素瓷卡标准图元)
func _draw_metallic_ingot(pos: Vector2, size: Vector2, base_col: Color) -> void:
	var w = size.x
	var h = size.y
	var pts = [
		pos + Vector2(-w * 0.5, h * 0.5),
		pos + Vector2(w * 0.5, h * 0.5),
		pos + Vector2(w * 0.4, -h * 0.5),
		pos + Vector2(-w * 0.4, -h * 0.5)
	]
	draw_colored_polygon(pts, base_col)
	var top_pts = [
		pos + Vector2(-w * 0.4, -h * 0.5),
		pos + Vector2(w * 0.4, -h * 0.5),
		pos + Vector2(w * 0.35, -h * 0.5 - 2.5),
		pos + Vector2(-w * 0.35, -h * 0.5 - 2.5)
	]
	draw_colored_polygon(top_pts, base_col.lightened(0.35))
	draw_line(pos + Vector2(-w * 0.4, -h * 0.5), pos + Vector2(w * 0.4, -h * 0.5), Color(0.9, 0.95, 1.0, 0.9), 1.5)

# 富勒烯碳环分子结构辅助绘制函数 (方案三 C 元素瓷卡标准图元)
func _draw_carbon_molecule() -> void:
	var center = Vector2.ZERO
	var r = 11.0
	var ring_pts = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * i)
		ring_pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	for i in range(6):
		var p1 = ring_pts[i]
		var p2 = ring_pts[(i + 1) % 6]
		draw_line(p1, p2, Color(0.25, 0.32, 0.42), 2.0)
		draw_line(center, p1, Color(0.35, 0.45, 0.58), 1.5)
	draw_circle(center, 5.0, Color(0.15, 0.20, 0.28))
	draw_arc(center, 5.0, 0.0, TAU, 24, Color(0.50, 0.60, 0.75), 1.2)
	for pt in ring_pts:
		draw_circle(pt, 3.5, Color(0.20, 0.28, 0.38))
		draw_circle(pt, 1.5, Color(0.80, 0.90, 1.0))

# 8. 铝土矿床 (Bauxite Deposit - 温暖陶土红与圆润鲕状结核矿层)
func _draw_bauxite_deposit() -> void:
	draw_circle(Vector2(0, 4), 22.0, Color(0.20, 0.08, 0.04, 0.55))
	draw_colored_polygon([
		Vector2(-16, 6), Vector2(-10, -12), Vector2(6, -15),
		Vector2(16, -4), Vector2(14, 10), Vector2(-2, 14)
	], Color(0.72, 0.28, 0.12))
	# 受光亮面
	draw_colored_polygon([
		Vector2(-10, -12), Vector2(6, -15), Vector2(16, -4), Vector2(2, -2)
	], Color(0.92, 0.44, 0.20))
	# 鲕状圆形铝矿颗粒
	draw_circle(Vector2(-4, 0), 4.5, Color(0.85, 0.38, 0.16))
	draw_circle(Vector2(6, 4), 3.8, Color(0.88, 0.42, 0.18))
	draw_circle(Vector2(2, -8), 3.2, Color(1.0, 0.55, 0.28))

# 9. 黄铁矿晶簇 (Pyrite - 璀璨黄铜金光、锐利立方晶体 Fool's Gold)
func _draw_pyrite_crystals() -> void:
	draw_circle(Vector2(0, 4), 22.0, Color(0.18, 0.14, 0.04, 0.6))
	# 主黄铜立方晶体
	_draw_cube(Vector2(-6, 0), 16.0, Color(0.88, 0.72, 0.15))
	_draw_cube(Vector2(8, 4), 12.0, Color(0.95, 0.82, 0.22))
	_draw_cube(Vector2(2, -8), 10.0, Color(0.80, 0.65, 0.12))
	# 耀眼金色金属倒角光泽
	draw_line(Vector2(-14, -8), Vector2(2, -8), Color(1.0, 0.95, 0.60), 2.0)
	draw_line(Vector2(2, -8), Vector2(2, 8), Color(1.0, 0.95, 0.60), 1.5)

# 10. 方铅矿方块 (Galena - 蓝灰重金属解理立方矿石，致密反光)
func _draw_galena_cubes() -> void:
	draw_circle(Vector2(0, 4), 22.0, Color(0.08, 0.10, 0.14, 0.65))
	_draw_cube(Vector2(-7, 2), 15.0, Color(0.32, 0.36, 0.42))
	_draw_cube(Vector2(7, -4), 13.0, Color(0.40, 0.45, 0.52))
	_draw_cube(Vector2(-1, 9), 9.0, Color(0.28, 0.32, 0.38))
	# 银亮金属高光棱线
	draw_line(Vector2(-14, -5), Vector2(0, -5), Color(0.85, 0.90, 0.98), 2.0)
	draw_line(Vector2(1, -10), Vector2(13, -10), Color(0.92, 0.95, 1.0), 2.0)

# 11. 闪锌矿晶体 (Sphalerite - 金刚光泽黑褐色树脂感结晶)
func _draw_sphalerite_crystals() -> void:
	draw_circle(Vector2(0, 4), 22.0, Color(0.15, 0.10, 0.04, 0.6))
	_draw_crystal_poly(Vector2(-6, -2), Vector2(13, 24), Color(0.42, 0.22, 0.08), Color(0.85, 0.48, 0.14))
	_draw_crystal_poly(Vector2(6, 3), Vector2(11, 20), Color(0.35, 0.18, 0.06), Color(0.75, 0.40, 0.12))
	_draw_crystal_poly(Vector2(-1, 9), Vector2(8, 14), Color(0.50, 0.26, 0.10), Color(0.95, 0.60, 0.20))

# 12. 独居石伟晶岩 (Monazite - 稀土璀璨宝石砂与深紫伴生矿)
func _draw_monazite_pegmatite() -> void:
	draw_circle(Vector2(0, 4), 22.0, Color(0.18, 0.06, 0.20, 0.65))
	_draw_crystal_poly(Vector2(-7, -1), Vector2(13, 26), Color(0.55, 0.14, 0.58), Color(0.92, 0.38, 0.95))
	_draw_crystal_poly(Vector2(7, 3), Vector2(11, 22), Color(0.42, 0.10, 0.48), Color(0.80, 0.30, 0.85))
	# 荧光稀土微粒星芒
	draw_circle(Vector2(-2, 10), 2.5, Color(0.98, 0.70, 1.0, 0.95))
	draw_circle(Vector2(4, -10), 2.0, Color(0.80, 0.95, 1.0, 0.95))

# 13. 沥青铀矿 (Pitchblende - 沥青黑葡萄状铀矿伴随荧光黄绿铀华)
func _draw_pitchblende_nodules() -> void:
	draw_circle(Vector2(0, 4), 24.0, Color(0.04, 0.08, 0.04, 0.7))
	# 沥青黑色葡萄状圆瘤球
	draw_circle(Vector2(-8, 2), 12.0, Color(0.14, 0.16, 0.15))
	draw_circle(Vector2(8, -2), 11.0, Color(0.16, 0.18, 0.17))
	draw_circle(Vector2(0, 8), 9.0, Color(0.12, 0.14, 0.13))
	# 荧光黄绿放射性铀华水解光晕
	draw_arc(Vector2(-8, 2), 9.0, -1.2, 0.8, 12, Color(0.45, 0.98, 0.35, 0.9), 2.5)
	draw_arc(Vector2(8, -2), 8.0, 0.5, 2.6, 12, Color(0.55, 1.0, 0.42, 0.9), 2.2)
	draw_circle(Vector2(0, 2), 3.0, Color(0.70, 1.0, 0.45, 0.95))

# 14. 黏土沉积层 (Clay Bank - 肥沃暖黄赤土河岸沉积)
func _draw_clay_bank() -> void:
	draw_circle(Vector2(0, 4), 22.0, Color(0.20, 0.12, 0.06, 0.5))
	draw_colored_polygon([
		Vector2(-18, 4), Vector2(-12, -8), Vector2(10, -10),
		Vector2(18, 2), Vector2(12, 12), Vector2(-8, 14)
	], Color(0.78, 0.45, 0.22))
	# 阶梯状沉积纹路
	draw_line(Vector2(-14, -2), Vector2(14, -4), Color(0.92, 0.58, 0.30), 2.5)
	draw_line(Vector2(-10, 5), Vector2(10, 3), Color(0.68, 0.38, 0.18), 2.0)

# 15. 木炭/煤层露头 (Charcoal / Coal Bed - 黝黑焦炭与解理层)
func _draw_charcoal_bed() -> void:
	draw_circle(Vector2(0, 4), 20.0, Color(0.04, 0.04, 0.05, 0.7))
	draw_colored_polygon([
		Vector2(-14, 5), Vector2(-9, -10), Vector2(7, -12),
		Vector2(15, -2), Vector2(10, 11), Vector2(-4, 12)
	], Color(0.18, 0.18, 0.20))
	draw_colored_polygon([
		Vector2(-9, -10), Vector2(7, -12), Vector2(15, -2), Vector2(2, -4)
	], Color(0.32, 0.32, 0.36))
	# 碳质解理闪光线
	draw_line(Vector2(-9, -10), Vector2(2, -4), Color(0.65, 0.65, 0.72), 1.5)

# 相互连接成片的矿脉延伸 (Connecting Mineral Veins)
func _draw_connecting_mineral_veins() -> void:
	if hex_coord == Vector2i(9999, 9999) or GameState.world_resources.is_empty():
		return
		
	var hex_dirs = [
		Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
		Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0)
	]
	
	for e in range(6):
		var n_coord = hex_coord + hex_dirs[e]
		if GameState.world_resources.has(n_coord):
			var n_res = GameState.world_resources[n_coord]
			if n_res == item_key:
				# 相邻地块也是同种资源：延伸矿脉晶簇与地表裂痕连接线！
				var angle = deg_to_rad(60.0 * e)
				var vein_dir = Vector2(cos(angle), sin(angle)) * 34.0
				var v_col = _get_mineral_vein_color(item_key)
				draw_line(Vector2.ZERO, vein_dir, v_col.darkened(0.2), 4.5)
				draw_line(Vector2.ZERO, vein_dir, v_col, 2.2)
				draw_circle(vein_dir * 0.7, 2.5, v_col.lightened(0.3))

func _get_mineral_vein_color(key: String) -> Color:
	match key:
		"malachite": return Color(0.20, 0.85, 0.45)
		"iron_ore": return Color(0.85, 0.25, 0.18)
		"sulfur": return Color(0.95, 0.85, 0.20)
		"halite": return Color(0.65, 0.85, 0.98)
		"pyrite": return Color(0.95, 0.82, 0.25)
		"galena": return Color(0.55, 0.60, 0.70)
		"bauxite": return Color(0.90, 0.45, 0.20)
		"monazite": return Color(0.85, 0.35, 0.90)
		"pitchblende": return Color(0.45, 0.95, 0.30)
		"wood": return Color(0.22, 0.48, 0.20)
		_: return Color(0.60, 0.60, 0.65)

