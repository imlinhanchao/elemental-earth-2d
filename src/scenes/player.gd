# player.gd
# 严丝合缝契合六边形尺寸、零黑框、精准交互的像素科考探险员
extends CharacterBody2D

@export var speed: float = 240.0

@onready var camera = $Camera2D
@onready var interact_detector = $InteractDetector

var facing_vector: Vector2 = Vector2.DOWN
var is_moving: bool = false
var walk_anim_timer: float = 0.0
var primary_anim_time: float = 0.0
var last_target_name: String = ""

func _ready() -> void:
	add_to_group("player")
	queue_redraw()

func _physics_process(delta: float) -> void:
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		is_moving = true
		facing_vector = input_vector.normalized()
		walk_anim_timer += delta * 12.0
		if interact_detector:
			interact_detector.position = facing_vector * 24.0
	else:
		is_moving = false
		walk_anim_timer = 0.0

	velocity = input_vector * speed
	move_and_slide()

	# 实时追踪离玩家最近的目标并给出精准拾取/开采提示
	var target = get_best_target()
	if target != null and target.has_method("mine_node"):
		var iname = target.get("item_name")
		if iname != last_target_name:
			last_target_name = iname
			GameState.post_notice("接近了【%s】，按 [空格] 或 [J] 采集！" % iname, Color(1.0, 0.9, 0.4))
	elif target == null and last_target_name != "":
		last_target_name = ""

	# 攻击/敲击挤压动画衰减
	if primary_anim_time > 0.0:
		primary_anim_time = max(0.0, primary_anim_time - delta * 8.0)

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action_primary"):
		_perform_primary_action()
	elif event.is_action_pressed("interact"):
		_perform_interact()

# 核心算法: 寻找距离玩家最近的可交互对象 (优先脚下重叠的，次选正前方的)
func get_best_target() -> Area2D:
	var candidates: Array[Area2D] = []
	
	# 1. 检查正前方探测器内的对象
	if interact_detector:
		for a in interact_detector.get_overlapping_areas():
			candidates.append(a)
			
	# 2. 检查玩家自身碰撞体脚下重叠的对象 (比如正踩在断枝或碎石上)
	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = global_position
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var results = space.intersect_point(params, 8)
	for res in results:
		var collider = res.get("collider")
		if collider is Area2D and not candidates.has(collider):
			candidates.append(collider)

	if candidates.is_empty():
		return null

	# 选出离玩家中心距离最近的那一个
	var best_target: Area2D = candidates[0]
	var best_dist = global_position.distance_squared_to(best_target.global_position)
	for i in range(1, candidates.size()):
		var d = global_position.distance_squared_to(candidates[i].global_position)
		if d < best_dist:
			best_dist = d
			best_target = candidates[i]

	return best_target

func _perform_primary_action() -> void:
	primary_anim_time = 1.0 # 触发敲击前冲动画
	var target = get_best_target()
	
	if target != null:
		if target.has_method("mine_node"):
			target.mine_node()
		elif target.has_method("add_fuel"):
			target.add_fuel()
	else:
		GameState.post_notice("（面前或脚下空空如也，走近树枝或碎石按空格拾取）", Color(0.7, 0.7, 0.7, 0.6))

func _perform_interact() -> void:
	var target = get_best_target()
	if target != null:
		if target.is_in_group("furnace") or target.name.begins_with("Furnace"):
			target.open_workbench_requested.emit(target)
		elif target.has_method("mine_node"):
			target.mine_node()

func _draw() -> void:
	# 敲击时的弹性挤压
	var punch_offset = facing_vector * (primary_anim_time * 6.0)
	var scale_y = 1.0 - (primary_anim_time * 0.15)
	
	draw_set_transform(punch_offset, 0.0, Vector2(1.0, scale_y))

	# 1. 脚下自然柔和阴影 (适配六边形地表，零黑方块！)
	draw_circle(Vector2(0, 16), 14.0, Color(0, 0, 0, 0.28))

	# 2. 双腿与鞋子 (根据行走交替迈步动画)
	var leg_offset_left = sin(walk_anim_timer) * 4.0 if is_moving else 0.0
	var leg_offset_right = -sin(walk_anim_timer) * 4.0 if is_moving else 0.0
	# 左腿/鞋 (暗棕色皮靴)
	draw_rect(Rect2(-7, 10 + leg_offset_left, 5, 8), Color(0.28, 0.18, 0.12))
	# 右腿/鞋
	draw_rect(Rect2(2, 10 + leg_offset_right, 5, 8), Color(0.28, 0.18, 0.12))

	# 3. 探险家双排扣学者风衣 (深海墨蓝与黄铜皮带)
	draw_rect(Rect2(-9, -4, 18, 16), Color(0.16, 0.28, 0.44)) # 大衣主身
	draw_line(Vector2(-9, 4), Vector2(9, 4), Color(0.55, 0.38, 0.18), 2.5) # 腰部皮带
	draw_circle(Vector2(0, 4), 2.5, Color(0.9, 0.75, 0.3)) # 金色皮带扣

	# 4. 背包轮廓 (侧后方皮质行囊)
	draw_rect(Rect2(-12, -2, 4, 12), Color(0.42, 0.26, 0.16)) # 左侧背包带

	# 5. 面部与皮肤
	draw_rect(Rect2(-6, -14, 12, 10), Color(0.92, 0.80, 0.68))

	# 6. 圆形黄铜护目镜 (两只透亮小圆镜，带青色反光)
	var look_dir = facing_vector.x * 2.0
	draw_circle(Vector2(-3 + look_dir, -10), 3.5, Color(0.85, 0.65, 0.25)) # 铜框
	draw_circle(Vector2(-3 + look_dir, -10), 2.0, Color(0.25, 0.85, 0.95)) # 镜片反光
	draw_circle(Vector2(3 + look_dir, -10), 3.5, Color(0.85, 0.65, 0.25))
	draw_circle(Vector2(3 + look_dir, -10), 2.0, Color(0.25, 0.85, 0.95))

	# 7. 宽檐探险家软毡帽 (卡其棕色)
	draw_rect(Rect2(-13, -16, 26, 4), Color(0.45, 0.32, 0.20)) # 宽大帽檐
	draw_rect(Rect2(-8, -22, 16, 7), Color(0.52, 0.38, 0.24))  # 帽顶
	draw_line(Vector2(-8, -16), Vector2(8, -16), Color(0.25, 0.16, 0.10), 2.0) # 帽子黑束带
