# lab_workbench_modal.gd
# 微观化学实验台全功能视口: 烧瓶组装、化学演变与工业蓝图固化导出 (扁平极简，无 emoji)
extends Control

const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")
const ThemeStyler = preload("res://src/ui/theme_styler.gd")

@onready var vessel_draw = $CenterPanel/VBox/Body/HBox/LeftView/VesselDrawArea
@onready var btn_burner = $CenterPanel/VBox/Body/HBox/LeftView/Controls/BtnBurner
@onready var temp_label = $CenterPanel/VBox/Body/HBox/LeftView/Controls/TempLabel
@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose

# 方案 1: 反应活性探测仪节点
@onready var sensor_card = $CenterPanel/VBox/Body/HBox/LeftView/SensorCard
@onready var sensor_title = $CenterPanel/VBox/Body/HBox/LeftView/SensorCard/SensorMargin/SensorVBox/SensorHeader/SensorTitle
@onready var sensor_badge = $CenterPanel/VBox/Body/HBox/LeftView/SensorCard/SensorMargin/SensorVBox/SensorHeader/SensorStateBadge
@onready var sensor_detail = $CenterPanel/VBox/Body/HBox/LeftView/SensorCard/SensorMargin/SensorVBox/SensorDetail

# 试剂栏
@onready var reagent_bar = $CenterPanel/VBox/Body/HBox/LeftView/ReagentScroll/ReagentBar
@onready var btn_clear = $CenterPanel/VBox/Body/HBox/LeftView/ReagentScroll/ReagentBar/BtnClear

# 方案 3: 视图切换与配方灵感图鉴节点
@onready var btn_tab_monitor = $CenterPanel/VBox/Body/HBox/RightView/TabSwitchHBox/BtnTabMonitor
@onready var btn_tab_codex = $CenterPanel/VBox/Body/HBox/RightView/TabSwitchHBox/BtnTabCodex
@onready var view_monitor = $CenterPanel/VBox/Body/HBox/RightView/ViewMonitor
@onready var view_codex = $CenterPanel/VBox/Body/HBox/RightView/ViewCodex
@onready var codex_list = $CenterPanel/VBox/Body/HBox/RightView/ViewCodex/CodexScroll/CodexList

@onready var btn_collect_prods = $CenterPanel/VBox/Body/HBox/RightView/ViewMonitor/ActionHBox/BtnCollectProducts
@onready var contents_label = $CenterPanel/VBox/Body/HBox/RightView/ViewMonitor/ContentsLabel
@onready var log_label = $CenterPanel/VBox/Body/HBox/RightView/ViewMonitor/LogLabel

var lab_vessel: MixtureBuffer
var is_burner_on: bool = false
var bubble_phase: float = 0.0
var solution_color: Color = Color(0.8, 0.9, 1.0, 0.2)
var current_tab_index: int = 0 # 0: 实验台监控, 1: 配方灵感图鉴

# 方案 3: 未确证配方的历史科学探索笔记与猜想
const FORMULA_CLUES: Dictionary = {
	"charcoal_production": {
		"title": "木材隔绝空气干馏",
		"clue": "古籍札记：“凡烧炭者，以木实置密穴或固器，加火炽烈而塞其孔，不令通气。木液与气尽出，余者纯黑坚致，火之不烈而延久。”",
		"materials_hint": "原木 x1 + 密闭烧瓶/窑炉",
		"temp_hint": "需持续加热至 500℃ 以上",
		"field_hint": "推荐探索：荒野森林、伐木地带"
	},
	"smelt_copper": {
		"title": "孔雀石木炭固相还原炼铜",
		"clue": "炼金家记闻：“火山与翠岩之脉，生有绿石孔雀文。碎之，杂以木炭碎末，投诸烈焰熏蒸。待其沸涌变黑，赤金之液下坠凝为铜。”",
		"materials_hint": "孔雀石矿 + 高温还原剂(木炭) + 烧瓶/坩埚",
		"temp_hint": "需持续加热至 600℃ 以上",
		"field_hint": "推荐探索：东部火山群系、森林干馏木炭"
	},
	"clay_production": {
		"title": "水润胶泥揉制粘土",
		"clue": "陶工笔谈：“深滩潮润之处，取黑褐黏泥滤去粗砂，调以清泉细细揉碾，得致密陶泥。”",
		"materials_hint": "泥土/高岭土 + 洁净水相",
		"temp_hint": "常温水相搅拌混合",
		"field_hint": "推荐探索：盐湖滩涂、湿地河畔"
	},
	"halite_evaporation": {
		"title": "盐湖苦泉煎熬结晶",
		"clue": "“取盐湖卤水煎煮，水汽蒸腾化白雾，底结莹白之盐块。”",
		"materials_hint": "盐湖卤水/石盐水",
		"temp_hint": "需沸腾蒸发 (100℃ 以上)",
		"field_hint": "推荐探索：西北盐湖群系"
	},
	"smelt_iron": {
		"title": "赤铁矿高温还原海绵铁",
		"clue": "“坚红之铁石不可直熔。唯以多量焦炭共炽于千度狂火，得灰黑多孔之海绵块，百炼始能成钢。”",
		"materials_hint": "赤铁矿 + 充沛木炭还原剂",
		"temp_hint": "需超高温加热至 800℃ 以上",
		"field_hint": "推荐探索：深部铁矿脉、耐火窑炉"
	}
}

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
	vessel_draw.draw.connect(_on_vessel_draw)
	GameState.solver.reaction_occurred.connect(_on_reaction_occurred)
	
	btn_clear.pressed.connect(clear_vessel)
	
	btn_tab_monitor.pressed.connect(func(): _switch_tab(0))
	btn_tab_codex.pressed.connect(func(): _switch_tab(1))
	_switch_tab(0)

func _switch_tab(tab_idx: int) -> void:
	current_tab_index = tab_idx
	view_monitor.visible = (tab_idx == 0)
	view_codex.visible = (tab_idx == 1)
	
	if tab_idx == 0:
		btn_tab_monitor.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
		btn_tab_codex.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	else:
		btn_tab_monitor.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		btn_tab_codex.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
		_refresh_codex_view()

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
	_update_sensor_probe()

func _on_burner_toggled(button_pressed: bool) -> void:
	is_burner_on = button_pressed
	if is_burner_on:
		btn_burner.text = "熄灭酒精灯"
		_add_log("点燃实验室酒精喷灯，温度迅速升高...")
	else:
		btn_burner.text = "点燃酒精灯"
		_add_log("熄灭酒精喷灯，体系逐步自然冷却。")
	_update_sensor_probe()

func add_reagent(item_key: String, amount: float) -> void:
	if not GameState.inventory.has_item(item_key, int(amount)):
		GameState.post_notification("行囊中缺少试剂: %s" % item_key, Color(1, 0.4, 0.4))
		return
		
	GameState.inventory.remove_item(item_key, int(amount))
	lab_vessel.add_substance(item_key, amount)
	_add_log("向烧瓶投入试剂 [%s] x%.1f" % [item_key, amount])
	_refresh_ui()

func clear_vessel() -> void:
	lab_vessel.clear()
	_add_log("彻底倒空并清洗实验烧瓶。")
	_refresh_ui()

func _refresh_ui() -> void:
	_refresh_reagent_bar()
	_update_sensor_probe()
	
	var text = "【微观烧瓶物料组分】\n"
	if lab_vessel.components.is_empty():
		text += "（空烧瓶）\n"
		solution_color = Color(0.8, 0.9, 1.0, 0.2)
	else:
		for k in lab_vessel.components.keys():
			var item = DataDB.get_item(k)
			var iname = item.get("name", k)
			text += "• %s (%s): %.2f mol/单位\n" % [iname, k, lab_vessel.components[k]]
			
		if lab_vessel.has_substance("copper"):
			solution_color = Color(0.85, 0.55, 0.35, 0.85)
		elif lab_vessel.has_substance("charcoal"):
			solution_color = Color(0.2, 0.2, 0.25, 0.9)
		elif lab_vessel.has_substance("malachite"):
			solution_color = Color(0.1, 0.75, 0.5, 0.6)
		elif lab_vessel.has_substance("water"):
			solution_color = Color(0.3, 0.6, 0.9, 0.5)
		else:
			solution_color = Color(0.6, 0.6, 0.65, 0.5)
			
	contents_label.text = text
	vessel_draw.queue_redraw()
	if current_tab_index == 1:
		_refresh_codex_view()

# 动态生成玩家拥有的可行试剂按钮
func _refresh_reagent_bar() -> void:
	for child in reagent_bar.get_children():
		if child != btn_clear:
			child.queue_free()
			
	var inv = GameState.inventory.items
	for k in inv.keys():
		var count = int(inv[k])
		if count <= 0:
			continue
		var item = DataDB.get_item(k)
		var iname = item.get("name", k)
		var cat = str(item.get("category", ""))
		
		# 仅展示适合实验的材料、矿石、燃料与单质
		if cat in ["材料", "矿石", "燃料", "酸碱", "物品"] or DataDB.is_pure_element(k) > 0 or not DataDB.get_item_chemical_tags(k).is_empty():
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(0, 36)
			btn.text = "+%s (%d)" % [iname, count]
			btn.pressed.connect(func(): add_reagent(k, 1.0))
			reagent_bar.add_child(btn)
			# 保持清空按钮在最后
			reagent_bar.move_child(btn_clear, reagent_bar.get_child_count() - 1)

# 方案 1: 实验室反应活性与条件探测器
func _update_sensor_probe() -> void:
	if not sensor_card:
		return
		
	var comp_keys = lab_vessel.components.keys()
	if comp_keys.is_empty():
		_set_sensor_ui("❄️ 待命中", "烧瓶洁净放空中，请从下方快捷投入试剂以启动化学侦测", ThemeStyler.COLOR_TEXT_SECONDARY, Color(0.25, 0.23, 0.20, 0.5))
		return
		
	var best_match_formula: Dictionary = {}
	var has_full_match: bool = false
	var has_partial_match: bool = false
	var temp_needed: float = 0.0
	
	# 遍历所有配方匹配
	for f_key in DataDB.formulas.keys():
		var f = DataDB.formulas[f_key]
		var req_items = f.get("required_items", [])
		if req_items.is_empty():
			continue
			
		var req_keys: Array = []
		for r in req_items:
			req_keys.append(str(r.get("key", "")))
			
		# 检查是否原料全匹配
		var all_present = true
		for rk in req_keys:
			if not lab_vessel.has_substance(rk):
				all_present = false
				break
				
		if all_present:
			has_full_match = true
			best_match_formula = f
			temp_needed = float(f.get("min_temp", f.get("min_temperature", 0.0)))
			break
		else:
			# 检查部分原料匹配 (烧瓶里投入了该配方的至少一种原料)
			var overlap = 0
			for ck in comp_keys:
				if ck in req_keys:
					overlap += 1
			if overlap > 0 and overlap < req_keys.size():
				has_partial_match = true
				if best_match_formula.is_empty():
					best_match_formula = f
					temp_needed = float(f.get("min_temp", f.get("min_temperature", 0.0)))
	
	var cur_temp = lab_vessel.temperature
	if has_full_match:
		var f_name = best_match_formula.get("name", "未知化合反应")
		if temp_needed > 0.0 and cur_temp < temp_needed:
			var target_c = int(temp_needed - 273.15)
			var cur_c = int(cur_temp - 273.15)
			_set_sensor_ui("⚠️ 潜在活性 (温度不足)", "【%s】原料齐备！但温度不足，请点燃喷灯加热至 %d ℃ 以上 (当前 %d ℃)" % [f_name, target_c, cur_c], Color(1.0, 0.78, 0.25), Color(0.4, 0.3, 0.08, 0.8))
		else:
			_set_sensor_ui("⚡ 反应进行中！", "【%s】微观分子剧烈转化与重构中，产物正在生成析出..." % f_name, Color(0.25, 0.95, 0.65), Color(0.08, 0.4, 0.2, 0.8))
	elif has_partial_match:
		_set_sensor_ui("🔍 微弱化学亲和力", "投入的试剂为某已知未知反应的部分原料，尚需尝试添加还原剂、矿石或水相溶剂", Color(0.35, 0.80, 1.0), Color(0.10, 0.25, 0.45, 0.7))
	else:
		_set_sensor_ui("❄️ 惰性混合体系", "当前混合试剂在当前工艺下未侦测到任何已知化学反应迹象", Color(0.60, 0.65, 0.72), Color(0.12, 0.16, 0.22, 0.7))

func _set_sensor_ui(badge_text: String, detail_text: String, accent_color: Color, bg_color: Color) -> void:
	sensor_badge.text = "[%s]" % badge_text
	sensor_badge.add_theme_color_override("font_color", accent_color)
	sensor_detail.text = detail_text
	sensor_detail.add_theme_color_override("font_color", Color(accent_color.r * 0.8 + 0.2, accent_color.g * 0.8 + 0.2, accent_color.b * 0.8 + 0.2))
	
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = accent_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	sensor_card.add_theme_stylebox_override("panel", style)

# 方案 3: 配方灵感图鉴 (Formula Codex) 清单填充
func _refresh_codex_view() -> void:
	for child in codex_list.get_children():
		child.queue_free()
		
	for f_key in FORMULA_CLUES.keys():
		var clue_data = FORMULA_CLUES[f_key]
		var f_data = DataDB.get_formula(f_key)
		var is_proven = GameState.unlocked_blueprints.has(f_key)
		
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		if is_proven:
			card_style.bg_color = Color(0.12, 0.16, 0.11, 0.85)
			card_style.border_color = Color(0.20, 0.80, 0.55, 0.8)
		else:
			card_style.bg_color = ThemeStyler.COLOR_CARD
			card_style.border_color = Color(0.25, 0.45, 0.70, 0.6)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.corner_radius_top_left = 10
		card_style.corner_radius_top_right = 10
		card_style.corner_radius_bottom_left = 10
		card_style.corner_radius_bottom_right = 10
		card.add_theme_stylebox_override("panel", card_style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		margin.add_child(vbox)
		
		# 标题行
		var title_row = HBoxContainer.new()
		var lbl_title = Label.new()
		lbl_title.text = ( "✓ " if is_proven else "🔬 [猜想] " ) + clue_data.get("title", f_key)
		lbl_title.add_theme_font_size_override("font_size", 13)
		lbl_title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6) if is_proven else Color(0.4, 0.85, 1.0))
		lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(lbl_title)
		
		var lbl_tag = Label.new()
		lbl_tag.text = "[已确证工艺]" if is_proven else "[探索猜想中]"
		lbl_tag.add_theme_font_size_override("font_size", 10)
		lbl_tag.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6) if is_proven else Color(0.95, 0.75, 0.3))
		title_row.add_child(lbl_tag)
		vbox.add_child(title_row)
		
		# 科学探索随笔线索
		var lbl_clue = Label.new()
		lbl_clue.text = clue_data.get("clue", "")
		lbl_clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_clue.add_theme_font_size_override("font_size", 11)
		lbl_clue.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
		vbox.add_child(lbl_clue)
		
		# 原料与条件标签行
		var cond_row = HBoxContainer.new()
		cond_row.add_theme_constant_override("separation", 12)
		
		var lbl_mat = Label.new()
		lbl_mat.text = "🧪 所需原料: " + clue_data.get("materials_hint", "未知")
		lbl_mat.add_theme_font_size_override("font_size", 11)
		lbl_mat.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
		cond_row.add_child(lbl_mat)
		
		var lbl_temp = Label.new()
		lbl_temp.text = "🌡️ " + clue_data.get("temp_hint", "")
		lbl_temp.add_theme_font_size_override("font_size", 11)
		lbl_temp.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35))
		cond_row.add_child(lbl_temp)
		
		var lbl_field = Label.new()
		lbl_field.text = "🗺️ " + clue_data.get("field_hint", "")
		lbl_field.add_theme_font_size_override("font_size", 11)
		lbl_field.add_theme_color_override("font_color", Color(0.35, 0.75, 0.95))
		cond_row.add_child(lbl_field)
		vbox.add_child(cond_row)
		
		# 快速投料按钮 (若玩家手头有相关原料)
		if f_data.has("required_items"):
			var btn_fill = Button.new()
			btn_fill.text = "尝试投入此配方原料至烧瓶"
			btn_fill.custom_minimum_size = Vector2(0, 26)
			btn_fill.add_theme_font_size_override("font_size", 11)
			btn_fill.pressed.connect(func():
				var reqs = f_data.get("required_items", [])
				var filled = 0
				for r in reqs:
					var rk = str(r.get("key", ""))
					if GameState.inventory.has_item(rk, 1):
						add_reagent(rk, 1.0)
						filled += 1
				if filled > 0:
					_switch_tab(0)
				else:
					GameState.post_notification("随身行囊中暂无对应原料！请前往大世界开采", Color(1.0, 0.6, 0.3))
			)
			vbox.add_child(btn_fill)
			
		codex_list.add_child(card)

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

