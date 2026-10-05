# lab_workbench_modal.gd
# 微观化学实验台全功能视口: 烧瓶组装、化学演变与工业蓝图固化导出 (扁平极简，无 emoji)
extends Control

const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")

@onready var vessel_draw = $CenterPanel/VBox/Body/HBox/LeftView/VesselDrawArea
@onready var btn_burner = $CenterPanel/VBox/Body/HBox/LeftView/Controls/BtnBurner
@onready var temp_label = $CenterPanel/VBox/Body/HBox/LeftView/Controls/TempLabel
@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose

@onready var btn_collect_prods = $CenterPanel/VBox/Body/HBox/RightView/ActionHBox/BtnCollectProducts
@onready var btn_export_bp = $CenterPanel/VBox/Body/HBox/RightView/ActionHBox/BtnExportBlueprint
@onready var contents_label = $CenterPanel/VBox/Body/HBox/RightView/ContentsLabel
@onready var log_label = $CenterPanel/VBox/Body/HBox/RightView/LogLabel

var lab_vessel: MixtureBuffer
var is_burner_on: bool = false
var bubble_phase: float = 0.0
var solution_color: Color = Color(0.8, 0.9, 1.0, 0.2)

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var p_box = ThemeStyler.create_card_box(12, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER)
	p_box.content_margin_left = 16
	p_box.content_margin_top = 16
	p_box.content_margin_right = 16
	p_box.content_margin_bottom = 16
	$CenterPanel.add_theme_stylebox_override("panel", p_box)
	lab_vessel = GameState.lab_vessel
	lab_vessel.container_type = "flask"
	
	btn_close.pressed.connect(func(): visible = false)
	btn_burner.toggled.connect(_on_burner_toggled)
	btn_collect_prods.pressed.connect(_on_collect_products_pressed)
	btn_export_bp.pressed.connect(_on_export_blueprint_pressed)
	vessel_draw.draw.connect(_on_vessel_draw)
	GameState.solver.reaction_occurred.connect(_on_reaction_occurred)

	var bar = $CenterPanel/VBox/Body/HBox/LeftView/ReagentBar
	if bar.has_node("BtnAddWood"):
		bar.get_node("BtnAddWood").pressed.connect(func(): add_reagent("wood", 1.0))
	bar.get_node("BtnAddMalachite").pressed.connect(func(): add_reagent("malachite", 1.0))
	bar.get_node("BtnAddIron").pressed.connect(func(): add_reagent("iron_ore", 1.0))
	bar.get_node("BtnAddCharcoal").pressed.connect(func(): add_reagent("charcoal", 1.0))
	bar.get_node("BtnClear").pressed.connect(clear_vessel)

func _on_reaction_occurred(rx_name: String, _prods: Array) -> void:
	if visible:
		_add_log("实验台发生化学反应: %s" % rx_name)
		_refresh_ui()

func open() -> void:
	visible = true
	_refresh_ui()
	btn_close.grab_focus()

func close() -> void:
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		visible = false
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_L):
		visible = false
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
		
	if is_burner_on:
		lab_vessel.temperature = move_toward(lab_vessel.temperature, 950.0, 160.0 * delta)
		bubble_phase += delta * 8.0
	else:
		lab_vessel.temperature = move_toward(lab_vessel.temperature, 293.15, 45.0 * delta)
		bubble_phase += delta * 1.5
		
	temp_label.text = "烧瓶温度: %d K (%d ℃)" % [int(lab_vessel.temperature), int(lab_vessel.temperature - 273.15)]
	vessel_draw.queue_redraw()

func _on_burner_toggled(button_pressed: bool) -> void:
	is_burner_on = button_pressed
	if is_burner_on:
		btn_burner.text = "熄灭酒精灯"
		_add_log("点燃实验室酒精喷灯，温度迅速升高...")
	else:
		btn_burner.text = "点燃酒精灯"
		_add_log("熄灭酒精喷灯，体系逐步自然冷却。")

func add_reagent(item_key: String, amount: float) -> void:
	if not GameState.inventory.has_item(item_key, int(amount)):
		GameState.post_notification("行囊中缺少试剂: %s" % item_key, Color(1, 0.4, 0.4))
		return
		
	GameState.inventory.remove_item(item_key, int(amount))
	lab_vessel.add_component(item_key, amount)
	_add_log("向烧瓶投入试剂 [%s] x%.1f" % [item_key, amount])
	_refresh_ui()

func clear_vessel() -> void:
	lab_vessel.clear()
	_add_log("彻底倒空并清洗实验烧瓶。")
	_refresh_ui()

func _refresh_ui() -> void:
	var text = "【微观烧瓶物料组分】\n"
	if lab_vessel.components.is_empty():
		text += "（空烧瓶）\n"
		solution_color = Color(0.8, 0.9, 1.0, 0.2)
	else:
		for k in lab_vessel.components.keys():
			var item = DataDB.get_item(k)
			var iname = item.get("name", k)
			text += "• %s (%s): %.2f mol/单位\n" % [iname, k, lab_vessel.components[k]]
			
		if lab_vessel.has_component("copper"):
			solution_color = Color(0.85, 0.55, 0.35, 0.85)
		elif lab_vessel.has_component("charcoal"):
			solution_color = Color(0.2, 0.2, 0.25, 0.9)
		elif lab_vessel.has_component("malachite"):
			solution_color = Color(0.1, 0.75, 0.5, 0.6)
		elif lab_vessel.has_component("water"):
			solution_color = Color(0.3, 0.6, 0.9, 0.5)
		else:
			solution_color = Color(0.6, 0.6, 0.65, 0.5)
			
	contents_label.text = text
	vessel_draw.queue_redraw()

func _on_collect_products_pressed() -> void:
	var harvested = 0
	for k in lab_vessel.components.keys():
		var amt = int(lab_vessel.components[k])
		if amt > 0:
			GameState.inventory.add_item(k, amt)
			lab_vessel.components[k] -= amt
			harvested += amt
			_add_log("回收物料 [%s] x%d 至随身行囊" % [k, amt])
	
	if harvested == 0:
		GameState.post_notification("烧瓶中暂无整数结晶产物可提取", Color(1, 0.8, 0.4))
	_refresh_ui()

func _on_export_blueprint_pressed() -> void:
	var bp = ProcessBlueprint.new()
	bp.id = "bp_charcoal"
	bp.title = "隔绝空气干馏木炭工艺"
	bp.required_inputs = {"wood": 1.0}
	bp.catalysts_or_burners = ["burner"]
	bp.target_products = {"charcoal": 1.0, "water": 1.0}
	bp.min_temp = 500.0
	bp.target_apparatus = "furnace"
	
	GameState.unlock_blueprint(bp)
	_add_log("成功将当前实验小试转化为可自动化工业蓝图: %s" % bp.title)

func _add_log(msg: String) -> void:
	log_label.text += "• " + msg + "\n"

func _on_vessel_draw() -> void:
	var rect = vessel_draw.get_rect()
	var center = rect.size * 0.5
	var neck_top = center.y - 70.0
	var neck_bot = center.y - 20.0
	var flask_bot = center.y + 60.0
	
	# 绘制烧瓶底座液体
	var poly: PackedVector2Array = [
		Vector2(center.x - 18, neck_bot),
		Vector2(center.x - 55, flask_bot),
		Vector2(center.x + 55, flask_bot),
		Vector2(center.x + 18, neck_bot)
	]
	vessel_draw.draw_colored_polygon(poly, solution_color)
	
	# 绘制烧瓶轮廓线
	var outline: PackedVector2Array = [
		Vector2(center.x - 18, neck_top),
		Vector2(center.x - 18, neck_bot),
		Vector2(center.x - 55, flask_bot),
		Vector2(center.x + 55, flask_bot),
		Vector2(center.x + 18, neck_bot),
		Vector2(center.x + 18, neck_top),
		Vector2(center.x - 18, neck_top)
	]
	vessel_draw.draw_polyline(outline, ThemeStyler.COLOR_BORDER, 2.0)
	
	# 绘制酒精灯火焰示意
	if is_burner_on:
		var flame_pts: PackedVector2Array = [
			Vector2(center.x - 14, flask_bot + 16),
			Vector2(center.x, flask_bot + 4 + sin(bubble_phase) * 3),
			Vector2(center.x + 14, flask_bot + 16)
		]
		vessel_draw.draw_colored_polygon(flame_pts, Color(0.298, 0.553, 1.0, 0.8))
