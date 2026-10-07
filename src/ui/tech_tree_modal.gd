# tech_tree_modal.gd
# 科技树：卡片位置由 tech_tree_layout.gd 按前置关系自动分层排布 (减少连线交叉、跨列连线走卡片间空隙)。
# 卡片右上角用时代色标出所属时代；悬停卡片时高亮它的前置与后续连线，其余连线淡出。
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const DataDB = preload("res://src/core/data_db.gd")
const ItemIconManager = preload("res://src/ui/item_icon_manager.gd")
const TechTreeLayout = preload("res://src/ui/tech_tree_layout.gd")

@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose
@onready var btn_reset_view = $CenterPanel/VBox/Header/HBox/BtnResetView
@onready var count_label = $CenterPanel/VBox/Header/HBox/CountLabel
@onready var era_filter_container = $CenterPanel/VBox/FilterBar/EraHBox

@onready var scroll = $CenterPanel/VBox/Body/Scroll
@onready var canvas = $CenterPanel/VBox/Body/Scroll/CanvasContainer
@onready var lines_layer = $CenterPanel/VBox/Body/Scroll/CanvasContainer/LinesLayer
@onready var headers_layer = $CenterPanel/VBox/Body/Scroll/CanvasContainer/HeadersLayer
@onready var nodes_layer = $CenterPanel/VBox/Body/Scroll/CanvasContainer/NodesLayer

const CARD_WIDTH: float = TechTreeLayout.CARD_W
const CARD_HEIGHT: float = TechTreeLayout.CARD_H

var tech_positions: Dictionary = {} # key -> Vector2
var tech_routes: Dictionary = {}   # "子|父" -> 跨列连线途经点
var _hover_key: String = ""       # 鼠标悬停的科技，用于高亮相关连线
var tech_card_nodes: Dictionary = {} # key -> PanelContainer

# 画布鼠标拖拽平移状态
var is_dragging_canvas: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_scroll: Vector2 = Vector2.ZERO

func _ready() -> void:
	ModalStack.track(self)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var p_box = ThemeStyler.create_card_box(12, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER)
	p_box.content_margin_left = 16
	p_box.content_margin_top = 16
	p_box.content_margin_right = 16
	p_box.content_margin_bottom = 16
	$CenterPanel.add_theme_stylebox_override("panel", p_box)
	
	lines_layer.tech_modal = self
	
	btn_close.pressed.connect(func(): visible = false)
	btn_reset_view.pressed.connect(func():
		scroll.scroll_horizontal = 0
		scroll.scroll_vertical = 0
	)
	
	scroll.gui_input.connect(_on_scroll_gui_input)
	canvas.gui_input.connect(_on_scroll_gui_input)
	
	GameState.tech_researched.connect(func(_k):
		if _built: _refresh_all()
	)

# 科技卡片与连线在第一次打开时才构建，避免进入游戏时一次性生成 40 张卡片
var _built: bool = false

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_compute_layout()
	_setup_era_jump_buttons()
	_build_tech_tree_graph()

func _compute_layout() -> void:
	var layout = TechTreeLayout.compute(DataDB.techs)
	tech_positions = layout["positions"]
	tech_routes = layout["routes"]
	canvas.custom_minimum_size = layout["size"]

# 时代跳转：滚动到该时代最靠左的科技
func _setup_era_jump_buttons() -> void:
	for child in era_filter_container.get_children():
		child.queue_free()
	var era_x := {}
	for k in tech_positions.keys():
		var era = DataDB.get_tech_era(k)
		era_x[era] = min(float(era_x.get(era, INF)), tech_positions[k].x)
	var eras = era_x.keys()
	eras.sort()
	for era in eras:
		var btn = Button.new()
		btn.text = GameState.ERA_NAMES[era] if era < GameState.ERA_NAMES.size() else "时代 %d" % era
		btn.custom_minimum_size = Vector2(88, 26)
		btn.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
		btn.add_theme_color_override("font_color", ThemeStyler.get_era_accent(era))
		var target_x = max(0, int(era_x[era] - 24))
		btn.pressed.connect(func():
			var tween = create_tween()
			tween.tween_property(scroll, "scroll_horizontal", target_x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
		era_filter_container.add_child(btn)

func _build_tech_tree_graph() -> void:
	for child in headers_layer.get_children():
		child.queue_free()
	for child in nodes_layer.get_children():
		child.queue_free()
	tech_card_nodes.clear()
	
	# 生成科技卡片节点
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
	var t_era = DataDB.get_tech_era(tech_key)
	
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
	title_lbl.add_theme_color_override("font_color", ThemeStyler.adapt(Color(0.15, 0.14, 0.13)))
	top_hbox.add_child(title_lbl)
	
	var era_badge = Label.new()
	var era_name = GameState.ERA_NAMES[t_era] if t_era < GameState.ERA_NAMES.size() else ""
	era_badge.text = era_name.trim_suffix("时代")
	era_badge.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
	era_badge.add_theme_color_override("font_color", ThemeStyler.get_era_accent(t_era))
	top_hbox.add_child(era_badge)
	
	# 中间行: 消耗材料/前置/状态提示
	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(cost_label)
	
	# 底部行: 研发操作按钮
	var btn_action = Button.new()
	btn_action.name = "BtnAction"
	btn_action.custom_minimum_size = Vector2(0, 22)
	btn_action.add_theme_font_size_override("font_size", 12)
	vbox.add_child(btn_action)
	
	btn_action.pressed.connect(func():
		_on_tech_card_action(tech_key, tech)
	)
	
	return card

func _refresh_all() -> void:
	var total = DataDB.techs.size()
	var researched = GameState.researched_techs.size()
	count_label.text = "已研发 %d / %d" % [researched, total]
	
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
			
	# 时代未到时按未解锁处理，提示所需时代
	var era_met = GameState.current_era >= DataDB.get_tech_era(tech_key)
	if not era_met:
		prereqs_met = false
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
		# 已研发 (现代科学翡翠绿细线)
		style.bg_color = ThemeStyler.adapt(Color(0.83, 0.93, 0.80, 0.92))
		style.border_color = ThemeStyler.COLOR_SUCCESS
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		card.modulate = Color.WHITE
		if cost_lbl:
			cost_lbl.text = "已研发"
			cost_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_SUCCESS)
		if btn_action:
			btn_action.visible = false
	elif prereqs_met:
		# 可研发 (电光青发丝线与辉光)
		style.bg_color = ThemeStyler.COLOR_CARD_HOVER
		style.border_color = ThemeStyler.COLOR_BORDER_FOCUS
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		card.modulate = Color.WHITE
		if cost_lbl:
			cost_lbl.text = ("需要 " + "、".join(cost_texts)) if not cost_texts.is_empty() else "无需材料"
			cost_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_SUCCESS if items_met else ThemeStyler.COLOR_WARNING)
		if btn_action:
			btn_action.visible = true
			if items_met:
				btn_action.text = "研发"
				btn_action.disabled = false
				btn_action.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				btn_action.text = "材料不足"
				btn_action.disabled = true
				btn_action.modulate = Color(0.85, 0.6, 0.5, 0.8)
	else:
		# 未解锁 (极简冷灰受控状态)
		style.bg_color = ThemeStyler.adapt(Color(0.92, 0.89, 0.84, 0.70))
		style.border_color = ThemeStyler.COLOR_BORDER
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		card.modulate = Color(1, 1, 1, 0.5)
		if cost_lbl:
			cost_lbl.text = "需要先研发：" + " / ".join(missing_prereqs) if not missing_prereqs.is_empty() else "需要进入" + GameState.sim.ERA_NAMES[DataDB.get_tech_era(tech_key)]
			cost_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_MUTED)
		if btn_action:
			btn_action.visible = false
			
	card.add_theme_stylebox_override("panel", style)

func _on_tech_card_action(tech_key: String, _tech: Dictionary) -> void:
	# 统一走模拟层：扣除材料、登记科技、完成里程碑并检查时代跃迁
	if GameState.research_tech(tech_key):
		_refresh_all()

# 悬停检测按卡片矩形判断 (卡片内的按钮会让 mouse_exited 提前触发)
func _process(_delta: float) -> void:
	if not visible or not _built:
		return
	var m = canvas.get_local_mouse_position()
	var key := ""
	if scroll.get_global_rect().has_point(get_global_mouse_position()):
		for k in tech_positions.keys():
			if Rect2(tech_positions[k], Vector2(CARD_WIDTH, CARD_HEIGHT)).has_point(m):
				key = k
				break
	_set_hover(key)

func _set_hover(key: String) -> void:
	if _hover_key == key:
		return
	_hover_key = key
	lines_layer.queue_redraw()

# 连线：从前置卡片右侧中点到后续卡片左侧中点。跨多列时经过布局算出的途经点，
# 在列中的直线段穿过卡片之间的空隙，列间用三次贝塞尔平滑过渡。
func _draw_connecting_lines(canvas_ctrl: Control) -> void:
	var col_done = ThemeStyler.COLOR_SUCCESS
	var col_ready = ThemeStyler.COLOR_ACCENT
	var col_locked = ThemeStyler.adapt(Color(0.54, 0.50, 0.44, 0.45))
	var hovering = _hover_key != ""
	# 先画普通连线，再画高亮连线，保证高亮的在上层
	for pass_idx in range(2):
		for child_key in DataDB.techs.keys():
			if not tech_positions.has(child_key):
				continue
			var tech = DataDB.techs[child_key]
			var is_child_done = GameState.researched_techs.has(child_key)
			var pin_in = tech_positions[child_key] + Vector2(0, CARD_HEIGHT * 0.5)
			for parent_key in tech.get("required_techs", []):
				if not tech_positions.has(parent_key):
					continue
				var related = hovering and (child_key == _hover_key or parent_key == _hover_key)
				if (pass_idx == 1) != related:
					continue
				var is_parent_done = GameState.researched_techs.has(parent_key)
				var pin_out = tech_positions[parent_key] + Vector2(CARD_WIDTH, CARD_HEIGHT * 0.5)
				var pts = _route_points(pin_out, tech_routes.get("%s|%s" % [child_key, parent_key], PackedVector2Array()), pin_in)
				var col: Color
				var width: float
				if is_child_done and is_parent_done:
					col = col_done; width = 2.0
				elif is_parent_done:
					col = col_ready; width = 2.0
				else:
					col = col_locked; width = 1.2
				if related:
					width += 1.5
					if col == col_locked:
						col = ThemeStyler.COLOR_TEXT_SECONDARY
				elif hovering:
					col.a *= 0.25
				canvas_ctrl.draw_polyline(pts, col, width, true)
				if related or is_parent_done:
					canvas_ctrl.draw_circle(pin_out, width + 0.5, col)
					canvas_ctrl.draw_circle(pin_in, width + 0.5, col)

# 把「针脚 → 途经点对 → 针脚」连成折线：途经点对之间是水平直线，其余段用贝塞尔曲线
func _route_points(start: Vector2, via: PackedVector2Array, end: Vector2) -> PackedVector2Array:
	var anchors = PackedVector2Array([start])
	anchors.append_array(via)
	anchors.append(end)
	var pts = PackedVector2Array()
	for i in range(anchors.size() - 1):
		var a = anchors[i]
		var b = anchors[i + 1]
		if i % 2 == 1:
			# 列内的水平直线段
			if pts.is_empty(): pts.append(a)
			pts.append(b)
			continue
		var dx = (b.x - a.x) * 0.5
		var steps = 16
		for s in range(steps + 1):
			if s == 0 and not pts.is_empty():
				continue
			var t = float(s) / steps
			var u = 1.0 - t
			pts.append(u * u * u * a + 3.0 * u * u * t * (a + Vector2(dx, 0)) + 3.0 * u * t * t * (b - Vector2(dx, 0)) + t * t * t * b)
	return pts

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
	_ensure_built()
	visible = true
	_refresh_all()
	btn_close.grab_focus()

func toggle() -> void:
	visible = not visible
	if visible:
		_ensure_built()
		_refresh_all()
		btn_close.grab_focus()

var _right_press_pos: Vector2 = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not visible or not ModalStack.is_top(self):
		return
	# 右键：按下记录位置；抬起时位移 < 6px 视为单击关闭，否则为拖拽平移画布
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_right_press_pos = event.position
		elif (event.position - _right_press_pos).length() < 6.0:
			visible = false
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_K):
		visible = false
		get_viewport().set_input_as_handled()
