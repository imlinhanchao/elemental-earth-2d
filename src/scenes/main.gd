# main.gd
# 游戏主场景：包含大世界与微观化学实验台原型
extends Control

const DataDB = preload("res://src/core/data_db.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")

var solver: ChemistrySolver
var current_vessel: MixtureBuffer
var discovered_elements: Array[int] = []

@onready var temp_slider = $HBox/LeftPanel/VesselBox/TempSlider
@onready var temp_label = $HBox/LeftPanel/VesselBox/TempLabel
@onready var volt_slider = $HBox/LeftPanel/VesselBox/VoltSlider
@onready var volt_label = $HBox/LeftPanel/VesselBox/VoltLabel
@onready var contents_text = $HBox/LeftPanel/ContentsBox/ContentsText
@onready var log_text = $HBox/RightPanel/LogBox/LogText
@onready var elements_label = $HBox/RightPanel/ElementsBox/ElementsLabel

func _ready() -> void:
	DataDB.initialize()
	solver = ChemistrySolver.new()
	current_vessel = MixtureBuffer.new()

	solver.reaction_occurred.connect(_on_reaction_occurred)
	solver.element_discovered.connect(_on_element_discovered)

	_update_ui()
	_log("[系统] 元素纪元 2D 实验室已就绪。请添加原料并调整温度/电压。")

func _process(delta: float) -> void:
	if current_vessel != null and current_vessel.total_moles() > 0:
		# 实时模拟化学反应
		var res = solver.solve(current_vessel, delta)
		if res["occurred"]:
			_update_ui()

func _update_ui() -> void:
	temp_label.text = "温度: %d K (%d ℃)" % [int(current_vessel.temperature), int(current_vessel.temperature - 273.15)]
	volt_label.text = "电解电压: %.1f V" % [current_vessel.applied_voltage]
	
	var text = ""
	if current_vessel.components.is_empty():
		text = "（容器为空）"
	else:
		for k in current_vessel.components.keys():
			var item = DataDB.get_item(k)
			var item_name = item.get("name", k)
			var moles = current_vessel.components[k]
			text += "• %s: %.2f mol\n" % [item_name, moles]
	contents_text.text = text

	var elem_text = "已点亮元素 (%d / 118):\n" % discovered_elements.size()
	for num in discovered_elements:
		var elem = DataDB.get_element(num)
		var sym = elem.get("symbol", "?")
		var cname = elem.get("name", "?")
		elem_text += "[#%d %s %s] " % [num, sym, cname]
	elements_label.text = elem_text

func _on_temp_slider_value_changed(value: float) -> void:
	current_vessel.temperature = value
	_update_ui()

func _on_volt_slider_value_changed(value: float) -> void:
	current_vessel.applied_voltage = value
	_update_ui()

func _on_btn_add_smelt_pressed() -> void:
	current_vessel.add_substance("malachite", 2.0)
	current_vessel.add_substance("charcoal", 2.0)
	_log("[操作] 投入孔雀石 x2.0 mol, 木炭 x2.0 mol")
	_update_ui()

func _on_btn_add_water_pressed() -> void:
	current_vessel.add_substance("water", 5.0)
	_log("[操作] 注入水 H2O x5.0 mol")
	_update_ui()

func _on_btn_clear_pressed() -> void:
	current_vessel.clear()
	_log("[操作] 清空反应容器")
	_update_ui()

func _on_reaction_occurred(rx_name: String, products: Array) -> void:
	_log("⚡ 发生化学反应: %s -> 生成产物: %s" % [rx_name, str(products)])

func _on_element_discovered(elem_num: int, item_key: String) -> void:
	if not discovered_elements.has(elem_num):
		discovered_elements.append(elem_num)
		discovered_elements.sort()
		var elem = DataDB.get_element(elem_num)
		_log("🌟 【重大发现】成功提纯点亮第 %d 号元素: %s (%s)！" % [elem_num, elem.get("name", item_key), elem.get("symbol", "")])
		_update_ui()

func _log(msg: String) -> void:
	if log_text:
		log_text.text += msg + "\n"
