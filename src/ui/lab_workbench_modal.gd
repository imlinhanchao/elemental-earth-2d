# lab_workbench_modal.gd
# 微观化学实验台全功能视口: 包含烧瓶组装、化学动画演变与工业蓝图固化导出
extends PanelContainer

const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")

@onready var vessel_draw = $Margin/HBox/LeftView/VesselDrawArea
@onready var btn_burner = $Margin/HBox/LeftView/Controls/BtnBurner
@onready var btn_export_bp = $Margin/HBox/RightView/BtnExportBlueprint
@onready var contents_label = $Margin/HBox/RightView/ContentsLabel
@onready var log_label = $Margin/HBox/RightView/LogLabel
@onready var temp_label = $Margin/HBox/LeftView/Controls/TempLabel
@onready var btn_close = $Margin/HBox/RightView/Header/BtnClose

var lab_vessel: MixtureBuffer
var is_burner_on: bool = false
var bubble_phase: float = 0.0
var solution_color: Color = Color(0.8, 0.9, 1.0, 0.2) # 初始纯水半透明色

func _ready() -> void:
	visible = false
	lab_vessel = MixtureBuffer.new()
	lab_vessel.temperature = 293.15
	
	btn_close.pressed.connect(func(): visible = false)
	btn_burner.toggled.connect(_on_burner_toggled)
	btn_export_bp.pressed.connect(_on_export_blueprint_pressed)
	vessel_draw.draw.connect(_on_vessel_draw)

	var bar = $Margin/HBox/LeftView/ReagentBar
	bar.get_node("BtnAddMalachite").pressed.connect(func(): add_reagent("malachite", 1.0))
	bar.get_node("BtnAddIron").pressed.connect(func(): add_reagent("iron_ore", 1.0))
	bar.get_node("BtnAddCharcoal").pressed.connect(func(): add_reagent("charcoal", 1.0))
	bar.get_node("BtnClear").pressed.connect(clear_vessel)

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_ui()

func _process(delta: float) -> void:
	if not visible:
		return
		
	# 酒精灯加热模拟
	if is_burner_on:
		lab_vessel.temperature = move_toward(lab_vessel.temperature, 950.0, 160.0 * delta)
		bubble_phase += delta * 8.0
	else:
		lab_vessel.temperature = move_toward(lab_vessel.temperature, 293.15, 30.0 * delta)
		bubble_phase += delta * 1.5

	# 驱动化学求解
	if lab_vessel.total_moles() > 0:
		var res = GameState.solver.solve(lab_vessel, delta)
		if res["occurred"]:
			_add_log("⚡ 实验台发生化学反应: %s" % str(res["reactions"]))
			_refresh_ui()

	_update_solution_color()
	temp_label.text = "烧瓶温度: %d K (%d ℃)" % [int(lab_vessel.temperature), int(lab_vessel.temperature - 273.15)]
	vessel_draw.queue_redraw()

func _update_solution_color() -> void:
	if lab_vessel.has_substance("copper", 0.1):
		solution_color = solution_color.lerp(Color(0.85, 0.45, 0.25, 0.85), 0.05) # 亮铜红沉淀
	elif lab_vessel.has_substance("malachite", 0.1):
		solution_color = solution_color.lerp(Color(0.12, 0.75, 0.42, 0.75), 0.05) # 孔雀石翠绿
	elif lab_vessel.has_substance("iron_ore", 0.1) or lab_vessel.has_substance("iron", 0.1):
		solution_color = solution_color.lerp(Color(0.65, 0.25, 0.18, 0.8), 0.05)  # 铁红深暗
	elif lab_vessel.has_substance("charcoal", 0.1):
		solution_color = solution_color.lerp(Color(0.2, 0.2, 0.22, 0.9), 0.05)    # 悬浮炭黑
	else:
		solution_color = solution_color.lerp(Color(0.85, 0.92, 1.0, 0.25), 0.05) # 清澈水色

func _on_vessel_draw() -> void:
	var center = vessel_draw.size / 2.0
	var flask_radius = 65.0
	
	# 1. 绘制三脚架与酒精灯
	var burner_pos = center + Vector2(0, 95)
	vessel_draw.draw_rect(Rect2(burner_pos.x - 22, burner_pos.y, 44, 25), Color(0.4, 0.45, 0.5)) # 酒精灯座
	if is_burner_on:
		# 动态火苗 (多层黄色/淡蓝火焰)
		var fire_h = 24.0 + sin(Time.get_ticks_msec() * 0.02) * 4.0
		vessel_draw.draw_colored_polygon([
			burner_pos + Vector2(-12, 0),
			burner_pos + Vector2(12, 0),
			burner_pos + Vector2(0, -fire_h)
		], Color(1.0, 0.6, 0.1))
		vessel_draw.draw_circle(burner_pos + Vector2(0, -6), 6.0, Color(0.2, 0.7, 1.0)) # 焰心内蓝

	# 2. 绘制圆底烧瓶玻璃外轮廓与瓶颈
	var neck_rect = Rect2(center.x - 14, center.y - 110, 28, 60)
	vessel_draw.draw_rect(neck_rect, Color(0.6, 0.7, 0.8, 0.25)) # 瓶颈
	vessel_draw.draw_rect(neck_rect, Color(0.7, 0.8, 0.9, 0.8), false, 2.0) # 瓶颈边线
	
	# 烧瓶圆底流体
	if lab_vessel.total_moles() > 0:
		vessel_draw.draw_circle(center, flask_radius - 2.0, solution_color)
		
		# 3. 沸腾气泡动画粒子
		if lab_vessel.temperature > 373.0: # 超过沸点
			for i in range(7):
				var bx = center.x - 30.0 + (i * 10.0)
				var by = center.y + 35.0 - fmod(bubble_phase * 20.0 + i * 15.0, 70.0)
				vessel_draw.draw_circle(Vector2(bx, by), 3.0 + fmod(i, 2.0), Color(1.0, 1.0, 1.0, 0.7))

	# 烧瓶玻璃外壳高光反光线
	vessel_draw.draw_circle(center, flask_radius, Color(0.6, 0.7, 0.8, 0.15))
	vessel_draw.draw_arc(center, flask_radius, 0.0, TAU, 32, Color(0.8, 0.9, 1.0, 0.9), 2.5)
	# 45度玻璃高光弧
	vessel_draw.draw_arc(center - Vector2(10, 10), flask_radius * 0.7, -PI * 0.75, -PI * 0.25, 16, Color(1, 1, 1, 0.6), 2.0)

func _refresh_ui() -> void:
	var text = "【微观烧瓶物料组分】\n"
	if lab_vessel.components.is_empty():
		text += "（空烧瓶，请从下方注入试剂）\n"
	else:
		for k in lab_vessel.components.keys():
			var item = DataDB.get_item(k)
			var iname = item.get("name", k)
			text += "• %s: %.2f mol\n" % [iname, lab_vessel.components[k]]
	contents_label.text = text

func _on_burner_toggled(toggled: bool) -> void:
	is_burner_on = toggled
	if is_burner_on:
		_add_log("🔥 点燃酒精灯，烧瓶开始升温...")
	else:
		_add_log("❄️ 熄灭酒精灯，自然冷却。")

func add_reagent(key: String, moles: float = 1.0) -> void:
	if GameState.inventory.remove_item(key, int(ceil(moles))):
		lab_vessel.add_substance(key, moles)
		var iname = DataDB.get_item(key).get("name", key)
		_add_log("🧪 注入试剂: %s x%.1f mol" % [iname, moles])
		_refresh_ui()
	else:
		GameState.post_notice("背包中没有足够的原料: %s！" % key, Color.RED)

func clear_vessel() -> void:
	lab_vessel.clear()
	_add_log("🧹 清空并清洗了烧瓶。")
	_refresh_ui()

func _on_export_blueprint_pressed() -> void:
	# 检查当前烧瓶中是否成功合成出有价值的目标物
	if lab_vessel.has_substance("copper", 0.5):
		var bp = ProcessBlueprint.new("bp_smelt_copper", "工业连续熔炼金属铜", {"malachite": 1.0, "charcoal": 0.5}, {"copper": 0.9}, 850.0)
		GameState.unlock_blueprint(bp)
	elif lab_vessel.has_substance("iron", 0.5):
		var bp = ProcessBlueprint.new("bp_smelt_iron", "工业高炉连续炼铁", {"iron_ore": 1.0, "charcoal": 1.5}, {"iron": 1.0}, 900.0)
		GameState.unlock_blueprint(bp)
	else:
		GameState.post_notice("当前烧瓶中尚未析出稳定的高价值目标单质，无法固化工艺！", Color.YELLOW)

func _add_log(msg: String) -> void:
	if log_label:
		log_label.text += msg + "\n"
