# tech_tree_modal.gd
# 缺氧 (Oxygen Not Included) 风格紧凑型科技树节点星图
# 紧凑高雅节点卡片 (190x74)、自由画布拖拽平移、平滑三次贝塞尔光晕连线、快捷梯队跳跃
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const DataDB = preload("res://src/core/data_db.gd")
const ItemIconManager = preload("res://src/ui/item_icon_manager.gd")

@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose
@onready var btn_reset_view = $CenterPanel/VBox/Header/HBox/BtnResetView
@onready var count_label = $CenterPanel/VBox/Header/HBox/CountLabel
@onready var era_filter_container = $CenterPanel/VBox/FilterBar/EraHBox

@onready var scroll = $CenterPanel/VBox/Body/Scroll
@onready var canvas = $CenterPanel/VBox/Body/Scroll/CanvasContainer
@onready var lines_layer = $CenterPanel/VBox/Body/Scroll/CanvasContainer/LinesLayer
@onready var headers_layer = $CenterPanel/VBox/Body/Scroll/CanvasContainer/HeadersLayer
@onready var nodes_layer = $CenterPanel/VBox/Body/Scroll/CanvasContainer/NodesLayer

# 9 大梯队紧凑名称
const TIER_TITLES: Array[String] = [
	"T1 初始石器",
	"T2 筑石耐火",
	"T3 古典建筑",
	"T4 合金机械",
	"T5 物理革新",
	"T6 工业连续流",
	"T7 现代能源",
	"T8 前沿宇航",
	"T9 星际推进"
]

# 紧凑型几何规格 (相比原先大幅压缩 50% 体积，使全局视野一览无余)
const CARD_WIDTH: float = 190.0
const CARD_HEIGHT: float = 74.0
const TIER_START_X: float = 40.0
const TIER_X_SPACING: float = 250.0
const ROW_START_Y: float = 55.0
const ROW_Y_SPACING: float = 95.0

# 科技专属领域行轨道映射表 (精心调优，实现零空间碰撞且流向顺畅)
const TRACK_MAP: Dictionary = {
	"stone_tool_crafting": 0, "stone_masonry": 0, "rammed_earth_technology": 0, "roman_architecture": 1, "steel_construction": 0,
	"wood_processing": 2, "bark_processing": 3, "sifting_technology": 2, "tenon_mortise_tech": 2,
	"pottery": 4, "refractory_materials": 3, "bronze_tool_crafting": 4,
	"high_temp_furnace": 3, "mold_making": 5, "iron_tool_crafting": 4,
	"brass_tool_crafting": 4, "manganese_alloy_smithing": 3,
	"titanium_alloy_smithing": 3, "chrome_alloy_smithing": 3,
	"fire_starting": 6, "explosives": 6, "high_explosive_tech": 6, "detonation_tech": 5,
	"gas_collection": 5, "glassworking": 4, "high_pressure_tech": 2,
	"advanced_chemical_equipment": 2, "crystallization_tech": 1, "production_tech": 4,
	"gas_liquefaction": 2,
	"electrochemistry": 5, "nickel_cadmium_battery_tech": 5, "lithium_battery_tech": 6,
	"solar_cell_manufacturing": 4,
	"precision_machinery": 1, "nuclear_physics": 0,
	"nuclear_reactor_tech": 0, "particle_accelerator_tech": 1, "magnesium_aluminum_alloying": 3,
	"jet_propulsion_tech": 2
}

var tech_positions: Dictionary = {} # key -> Vector2
var tech_tiers: Dictionary = {}    # key -> int (tier 0..8)
var tech_card_nodes: Dictionary = {} # key -> PanelContainer

# 画布鼠标拖拽平移状态
var is_dragging_canvas: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_scroll: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	lines_layer.tech_modal = self
	
	btn_close.pressed.connect(func(): visible = false)
	btn_reset_view.pressed.connect(func():
		scroll.scroll_horizontal = 0
		scroll.scroll_vertical = 0
	)
	
	scroll.gui_input.connect(_on_scroll_gui_input)
	canvas.gui_input.connect(_on_scroll_gui_input)
	
	GameState.tech_researched.connect(func(_k):
		_refresh_all()
	)
	
	_compute_topological_tiers()
	_setup_era_jump_buttons()
	_build_tech_tree_graph()
	_refresh_all()

func _compute_topological_tiers() -> void:
	tech_tiers.clear()
	tech_positions.clear()
	
	var techs = DataDB.techs
	for k in techs.keys():
		var tier = _calc_tech_tier(k, techs)
		tech_tiers[k] = tier
		var row = int(TRACK_MAP.get(k, 0))
		var pos = Vector2(TIER_START_X + tier * TIER_X_SPACING, ROW_START_Y + row * ROW_Y_SPACING)
		tech_positions[k] = pos

func _calc_tech_tier(key: String, tech_dict: Dictionary, visited: Dictionary = {}) -> int:
	if not tech_dict.has(key):
		return 0
	if visited.has(key):
		return 0
	visited[key] = true
	var tech = tech_dict[key]
	var reqs = tech.get("required_techs", tech.get("prerequisites", []))
	if reqs.is_empty():
		return 0
	var max_d = 0
	for r in reqs:
		var d = _calc_tech_tier(r, tech_dict, visited.duplicate())
		if d > max_d:
			max_d = d
	return max_d + 1

func _setup_era_jump_buttons() -> void:
	for child in era_filter_container.get_children():
		child.queue_free()
		
	var jump_data = [
		{"name": "初始石器", "tier": 0},
		{"name": "筑石前置", "tier": 1},
		{"name": "古典建筑", "tier": 2},
		{"name": "合金机械", "tier": 3},
		{"name": "物理革新", "tier": 4},
		{"name": "工业连续流", "tier": 5},
		{"name": "现代能源", "tier": 6},
		{"name": "前沿宇航", "tier": 7},
		{"name": "星际推进", "tier": 8}
	]
	
	for item in jump_data:
		var btn = Button.new()
		btn.text = item["name"]
		btn.custom_minimum_size = Vector2(88, 26)
		btn.add_theme_font_size_override("font_size", 11)
		var t_idx = int(item["tier"])
		btn.pressed.connect(func():
			var target_x = max(0, int(TIER_START_X + t_idx * TIER_X_SPACING - 30))
			var tween = create_tween()
			tween.tween_property(scroll, "scroll_horizontal", target_x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
		era_filter_container.add_child(btn)

func _build_tech_tree_graph() -> void:
	# 1. 构建列标题指示牌 (HeadersLayer)
	for child in headers_layer.get_children():
		child.queue_free()
	for child in nodes_layer.get_children():
		child.queue_free()
	tech_card_nodes.clear()
	
	for tier in range(TIER_TITLES.size()):
		var header_panel = PanelContainer.new()
		header_panel.custom_minimum_size = Vector2(CARD_WIDTH, 24)
		
		var h_style = StyleBoxFlat.new()
		h_style.bg_color = Color(0.10, 0.13, 0.17, 0.85)
		h_style.border_color = Color(0.25, 0.45, 0.70, 0.8)
		h_style.border_width_bottom = 2
		h_style.corner_radius_top_left = 3
		h_style.corner_radius_top_right = 3
		header_panel.add_theme_stylebox_override("panel", h_style)
		
		var lbl = Label.new()
		lbl.text = TIER_TITLES[tier]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
		header_panel.add_child(lbl)
		headers_layer.add_child(header_panel)
		header_panel.position = Vector2(TIER_START_X + tier * TIER_X_SPACING, 15)
		
	# 2. 生成 40 项紧凑科技卡片节点
	for tech in DataDB.techs.values():
		var k = str(tech.get("key", ""))
		if not tech_positions.has(k):
			continue
		var card = _create_oni_tech_card(tech)
		nodes_layer.add_child(card)
		card.position = tech_positions[k]
		tech_card_nodes[k] = card

func _create_oni_tech_card(tech: Dictionary) -> PanelContainer:
	var tech_key = str(tech.get("key", ""))
	var tech_name = str(tech.get("name", tech_key))
	var t_tier = int(tech_tiers.get(tech_key, 0))
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)
	
	# 顶部行: 图标 + 科技名 + 阶梯徽标
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(top_hbox)
	
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(20, 20)
	icon_rect.texture = ItemIconManager.get_icon(tech_key)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_hbox.add_child(icon_rect)
	
	var title_lbl = Label.new()
	title_lbl.text = tech_name
	title_lbl.name = "TitleLabel"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	top_hbox.add_child(title_lbl)
	
	var tier_badge = Label.new()
	tier_badge.text = "T%d" % (t_tier + 1)
	tier_badge.add_theme_font_size_override("font_size", 10)
	tier_badge.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	top_hbox.add_child(tier_badge)
	
	# 中间行: 消耗材料/前置/状态提示
	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(cost_label)
	
	# 底部行: 研发操作按钮
	var btn_action = Button.new()
	btn_action.name = "BtnAction"
	btn_action.custom_minimum_size = Vector2(0, 22)
	btn_action.add_theme_font_size_override("font_size", 10)
	vbox.add_child(btn_action)
	
	btn_action.pressed.connect(func():
		_on_tech_card_action(tech_key, tech)
	)
	
	return card

func _refresh_all() -> void:
	var total = DataDB.techs.size()
	var researched = GameState.researched_techs.size()
	count_label.text = "已研发: %d / %d 项核心科技" % [researched, total]
	
	for tech_key in tech_card_nodes.keys():
		var card = tech_card_nodes[tech_key]
		var tech = DataDB.techs[tech_key]
		_update_card_state(card, tech_key, tech)
		
	lines_layer.queue_redraw()

func _update_card_state(card: PanelContainer, tech_key: String, tech: Dictionary) -> void:
	var is_researched = GameState.researched_techs.has(tech_key)
	var req_techs = tech.get("required_techs", tech.get("prerequisites", []))
	var req_items = tech.get("required_items", [])
	
	# 检查前置是否全部满足
	var prereqs_met = true
	var missing_prereqs = []
	for p in req_techs:
		if not GameState.researched_techs.has(p):
			prereqs_met = false
			var p_name = DataDB.techs.get(p, {}).get("name", p)
			missing_prereqs.append(p_name)
			
	# 检查材料储备
	var items_met = true
	var cost_texts = []
	for req in req_items:
		var item_k = req.get("key", "")
		var item_qty = int(req.get("quantity", 1))
		var item_n = DataDB.get_item(item_k).get("name", item_k)
		var user_has = int(GameState.inventory.items.get(item_k, 0))
		if user_has < item_qty:
			items_met = false
			cost_texts.append("%s: %d/%d" % [item_n, user_has, item_qty])
		else:
			cost_texts.append("%s: %d" % [item_n, item_qty])
			
	var cost_lbl: Label = card.find_child("CostLabel", true, false)
	var btn_action: Button = card.find_child("BtnAction", true, false)
	
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
	
	if is_researched:
		# 已研发 (紧凑墨绿高雅质感)
		style.bg_color = Color(0.06, 0.14, 0.09, 0.92)
		style.border_color = Color(0.15, 0.75, 0.40, 0.9)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		card.modulate = Color.WHITE
		if cost_lbl:
			cost_lbl.text = "✓ 已研发完毕"
			cost_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.5))
		if btn_action:
			btn_action.visible = false
	elif prereqs_met:
		# 可研发 (科技蔚蓝呼吸光)
		style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
		style.border_color = Color(0.28, 0.65, 1.0, 1.0)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		card.modulate = Color.WHITE
		if cost_lbl:
			cost_lbl.text = ("需求: " + ", ".join(cost_texts)) if not cost_texts.is_empty() else "无消耗"
			cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5) if items_met else Color(0.95, 0.55, 0.45))
		if btn_action:
			btn_action.visible = true
			if items_met:
				btn_action.text = "🔬 启动研发"
				btn_action.disabled = false
				btn_action.modulate = Color(0.3, 0.9, 1.0)
			else:
				btn_action.text = "材料不足"
				btn_action.disabled = true
				btn_action.modulate = Color(0.85, 0.6, 0.5)
	else:
		# 未解锁 (缺氧灰暗受控)
		style.bg_color = Color(0.05, 0.06, 0.08, 0.70)
		style.border_color = Color(0.18, 0.20, 0.24, 0.7)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		card.modulate = Color(1, 1, 1, 0.55)
		if cost_lbl:
			cost_lbl.text = "🔒 需: " + " / ".join(missing_prereqs) if not missing_prereqs.is_empty() else "未解锁"
			cost_lbl.add_theme_color_override("font_color", Color(0.7, 0.45, 0.45))
		if btn_action:
			btn_action.visible = false
			
	card.add_theme_stylebox_override("panel", style)

func _on_tech_card_action(tech_key: String, tech: Dictionary) -> void:
	if GameState.researched_techs.has(tech_key):
		return
		
	var req_items = tech.get("required_items", [])
	# 扣除材料
	for req in req_items:
		var item_k = req.get("key", "")
		var item_qty = int(req.get("quantity", 1))
		GameState.inventory.remove_item(item_k, item_qty)
		
	# 登记已研发
	GameState.researched_techs.append(tech_key)
	GameState.tech_researched.emit(tech_key)
	
	var iname = tech.get("name", tech_key)
	GameState.post_notice("【科技突破】人类文明成功攻克【%s】！" % iname, Color(0.2, 0.9, 0.4))
	
	_refresh_all()

# 缺氧连线绘制系统: 从前置节点右侧针脚平滑弯曲连接至后继节点左侧针脚
func _draw_connecting_lines(canvas_ctrl: Control) -> void:
	for child_key in DataDB.techs.keys():
		if not tech_positions.has(child_key):
			continue
		var tech = DataDB.techs[child_key]
		var req_techs = tech.get("required_techs", tech.get("prerequisites", []))
		var c_pos = tech_positions[child_key]
		var is_child_done = GameState.researched_techs.has(child_key)
		
		var pin_in = c_pos + Vector2(0, CARD_HEIGHT * 0.5)
		
		for parent_key in req_techs:
			if not tech_positions.has(parent_key):
				continue
			var p_pos = tech_positions[parent_key]
			var is_parent_done = GameState.researched_techs.has(parent_key)
			var pin_out = p_pos + Vector2(CARD_WIDTH, CARD_HEIGHT * 0.5)
			
			# 生成三次贝塞尔平滑 S 曲线采样点
			var points = PackedVector2Array()
			var steps = 20
			var dx = pin_in.x - pin_out.x
			var p0 = pin_out
			var p1 = pin_out + Vector2(dx * 0.5, 0)
			var p2 = pin_in - Vector2(dx * 0.5, 0)
			var p3 = pin_in
			
			for s in range(steps + 1):
				var t = float(s) / float(steps)
				var u = 1.0 - t
				var pt = (u * u * u) * p0 + (3.0 * u * u * t) * p1 + (3.0 * u * t * t) * p2 + (t * t * t) * p3
				points.append(pt)
				
			if is_child_done and is_parent_done:
				# 双方均已完成: 璀璨电青色能量光晕
				canvas_ctrl.draw_polyline(points, Color(0.18, 0.75, 1.0, 0.28), 4.5)
				canvas_ctrl.draw_polyline(points, Color(0.35, 0.95, 1.0, 0.95), 1.8)
				canvas_ctrl.draw_circle(pin_out, 2.5, Color(0.35, 0.95, 1.0))
				canvas_ctrl.draw_circle(pin_in, 2.5, Color(0.35, 0.95, 1.0))
			elif is_parent_done:
				# 前置已满足可研发: 金色脉动能量流
				canvas_ctrl.draw_polyline(points, Color(1.0, 0.75, 0.20, 0.25), 3.5)
				canvas_ctrl.draw_polyline(points, Color(1.0, 0.85, 0.35, 0.90), 1.5)
				canvas_ctrl.draw_circle(pin_out, 2.0, Color(1.0, 0.85, 0.35))
				canvas_ctrl.draw_circle(pin_in, 2.0, Color(1.0, 0.85, 0.35))
			else:
				# 未解锁路径: 幽暗隐秘灰色虚线
				canvas_ctrl.draw_polyline(points, Color(0.24, 0.27, 0.33, 0.40), 1.2)

# 画布自由平移交互
func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			is_dragging_canvas = event.pressed
			drag_start_mouse = event.position
			drag_start_scroll = Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)
	elif event is InputEventMouseMotion and is_dragging_canvas:
		var delta_mouse = event.position - drag_start_mouse
		scroll.scroll_horizontal = int(drag_start_scroll.x - delta_mouse.x)
		scroll.scroll_vertical = int(drag_start_scroll.y - delta_mouse.y)

func open() -> void:
	visible = true
	_refresh_all()
	btn_close.grab_focus()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_all()
		btn_close.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not is_dragging_canvas:
		visible = false
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_K):
		visible = false
		get_viewport().set_input_as_handled()
