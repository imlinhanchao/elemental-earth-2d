# industrial_reactor.gd
# 工业化连续流反应塔: 插装蓝图芯片实现全自动无人化批量生产
extends Area2D

const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")

var installed_blueprint: ProcessBlueprint = null
var is_running: bool = false
var cycle_progress: float = 0.0
var total_produced_count: int = 0

@onready var status_label = $StatusLabel
@onready var sprite = $Sprite2D

func _ready() -> void:
	add_to_group("industrial_machines")
	_update_ui()

func _process(delta: float) -> void:
	if installed_blueprint == null:
		return
		
	# 检查背包或供料池中是否有满足蓝图的全部输入物料
	var has_all_inputs = true
	for in_key in installed_blueprint.inputs.keys():
		var req = int(ceil(installed_blueprint.inputs[in_key]))
		if not GameState.inventory.has_item(in_key, req):
			has_all_inputs = false
			break
			
	if has_all_inputs:
		is_running = true
		cycle_progress += delta
		
		# 机器运转微颤动画
		if sprite:
			sprite.rotation = sin(Time.get_ticks_msec() * 0.03) * 0.04
			
		if cycle_progress >= installed_blueprint.duration_seconds:
			cycle_progress = 0.0
			_complete_production_cycle()
	else:
		is_running = false
		if sprite:
			sprite.rotation = 0.0
			
	_update_ui()

func _complete_production_cycle() -> void:
	# 消耗原料
	for in_key in installed_blueprint.inputs.keys():
		var req = int(ceil(installed_blueprint.inputs[in_key]))
		GameState.inventory.remove_item(in_key, req)
		
	# 批量产出目标物料
	for out_key in installed_blueprint.outputs.keys():
		var amount = int(ceil(installed_blueprint.outputs[out_key]))
		GameState.inventory.add_item(out_key, amount)
		total_produced_count += amount
		
	GameState.post_notice("⚙️ 工业反应塔批量产出: %s 完成！累计自动化产出: %d" % [installed_blueprint.display_name, total_produced_count], Color(0.3, 0.8, 1.0))

func install_blueprint(bp: ProcessBlueprint) -> void:
	installed_blueprint = bp
	cycle_progress = 0.0
	GameState.post_notice("📥 已向工业反应塔插装芯片: 【%s】" % bp.display_name, Color.CYAN)
	_update_ui()

func _update_ui() -> void:
	if status_label:
		if installed_blueprint == null:
			status_label.text = "工业连续反应塔\n[未装载蓝图芯片]\n按E插入蓝图"
		else:
			var state_str = "🔥 连续运转中 (%.1fs)" % (installed_blueprint.duration_seconds - cycle_progress) if is_running else "⏸️ 缺料待机中"
			status_label.text = "反应塔: %s\n%s\n已量产: %d" % [installed_blueprint.display_name, state_str, total_produced_count]

func _draw() -> void:
	# 绘制工业重型塔楼基座 (金属质感)
	draw_circle(Vector2.ZERO, 38.0, Color(0.2, 0.25, 0.3))
	draw_circle(Vector2.ZERO, 32.0, Color(0.35, 0.42, 0.5))
	# 顶部管道法兰盘螺栓点
	for i in range(6):
		var angle = i * (TAU / 6.0)
		var p = Vector2(cos(angle), sin(angle)) * 26.0
		draw_circle(p, 3.5, Color(0.8, 0.7, 0.3) if is_running else Color(0.5, 0.5, 0.5))
