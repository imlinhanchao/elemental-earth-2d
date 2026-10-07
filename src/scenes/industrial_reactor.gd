# industrial_reactor.gd
# 工业连续反应塔的地图表现节点。点击由 world 按地块分发，打开反应塔面板 (reactor_modal.gd)；
# 蓝图、周期与产出都在模拟层 (built_reactors[hex])。
extends Node2D

const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")

var hex_coord: Vector2i = Vector2i(9999, 9999)

var blueprint_id: String:
	get:
		if GameState.built_reactors.has(hex_coord):
			return GameState.built_reactors[hex_coord].get("blueprint_id", "")
		return _local_bp_id

var installed_blueprint: ProcessBlueprint:
	get:
		if blueprint_id != "" and GameState.unlocked_blueprints.has(blueprint_id):
			return GameState.unlocked_blueprints[blueprint_id]
		return null

var total_produced_count: int:
	get:
		if GameState.built_reactors.has(hex_coord):
			return int(GameState.built_reactors[hex_coord].get("total_produced", 0))
		return _local_produced

var cycle_progress: float:
	get:
		if GameState.built_reactors.has(hex_coord):
			return float(GameState.built_reactors[hex_coord].get("cycle_progress", 0.0))
		return 0.0

var _local_bp_id: String = ""
var _local_produced: int = 0

@onready var status_label = $StatusLabel
@onready var sprite = $Sprite2D

func _ready() -> void:
	add_to_group("industrial_machines")
	_update_ui()

func _process(_delta: float) -> void:
	if installed_blueprint != null:
		# 机器运转微颤动画
		if sprite:
			sprite.rotation = sin(Time.get_ticks_msec() * 0.03) * 0.04
	else:
		if sprite:
			sprite.rotation = 0.0
			
	_update_ui()

func install_blueprint(bp: ProcessBlueprint) -> void:
	_local_bp_id = bp.id
	GameState.reactor_install_blueprint(hex_coord, bp.id)
	_update_ui()

var _last_status: String = ""

func _set_status(txt: String) -> void:
	if txt != _last_status:
		_last_status = txt
		status_label.text = txt

func _update_ui() -> void:
	if not status_label:
		return
	var r = GameState.built_reactors.get(hex_coord, {})
	if installed_blueprint == null:
		_set_status("工业连续反应塔\n点击装入蓝图")
	elif r.get("paused", false):
		_set_status("%s\n已暂停" % installed_blueprint.display_name)
	elif not GameState.sim.reactor_missing_inputs(hex_coord).is_empty():
		_set_status("%s\n缺少原料" % installed_blueprint.display_name)
	else:
		_set_status("%s\n%d 秒后产出 · 已产 %d" % [installed_blueprint.display_name,
			int(ceil(max(0.0, installed_blueprint.duration_seconds - cycle_progress))), total_produced_count])

func _draw() -> void:
	# 绘制工业重型塔楼基座 (金属质感)
	draw_circle(Vector2.ZERO, 38.0, Color(0.2, 0.25, 0.3))
	draw_circle(Vector2.ZERO, 32.0, Color(0.35, 0.42, 0.5))
	# 顶部管道法兰盘螺栓点
	for i in range(6):
		var angle = i * (TAU / 6.0)
		var p = Vector2(cos(angle), sin(angle)) * 26.0
		draw_circle(p, 3.5, Color(0.8, 0.7, 0.3) if installed_blueprint != null else Color(0.5, 0.5, 0.5))
