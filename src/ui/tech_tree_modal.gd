# tech_tree_modal.gd
# 科技演进树模态弹窗: 涵盖全部 6 个时代 40 项核心科技，文明6范式扁平高级设计
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const DataDB = preload("res://src/core/data_db.gd")

@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose
@onready var count_label = $CenterPanel/VBox/Header/HBox/CountLabel
@onready var era_filter_container = $CenterPanel/VBox/FilterBar/EraHBox
@onready var tech_grid = $CenterPanel/VBox/Body/Scroll/TechGrid

var current_filter_era: int = -1 # -1 = 全部

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_close.pressed.connect(func(): visible = false)
	GameState.tech_researched.connect(func(_k): _refresh_ui())
	_setup_filters()
	_refresh_ui()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_ui()
		btn_close.grab_focus()

func open() -> void:
	visible = true
	_refresh_ui()
	btn_close.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		visible = false
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_K):
		visible = false
		get_viewport().set_input_as_handled()

func _setup_filters() -> void:
	for child in era_filter_container.get_children():
		child.queue_free()
		
	var btn_all = Button.new()
	btn_all.text = "全部时代"
	btn_all.custom_minimum_size = Vector2(90, 32)
	btn_all.pressed.connect(func():
		current_filter_era = -1
		_refresh_ui()
	)
	era_filter_container.add_child(btn_all)
	
	for i in range(GameState.ERA_NAMES.size()):
		var btn = Button.new()
		var e_name = GameState.ERA_NAMES[i].split(" ")[0]
		btn.text = e_name
		btn.custom_minimum_size = Vector2(100, 32)
		var era_idx = i
		btn.pressed.connect(func():
			current_filter_era = era_idx
			_refresh_ui()
		)
		era_filter_container.add_child(btn)

func _refresh_ui() -> void:
	var total_count = DataDB.techs.size()
	var researched_count = GameState.researched_techs.size()
	count_label.text = "已研发: %d / %d" % [researched_count, total_count]
	
	for child in tech_grid.get_children():
		child.queue_free()
		
	for tech in DataDB.techs.values():
		var t_era = int(tech.get("era", 0))
		if current_filter_era != -1 and t_era != current_filter_era:
			continue
			
		var card = _create_tech_card(tech)
		tech_grid.add_child(card)

func _create_tech_card(tech: Dictionary) -> PanelContainer:
	var tech_key = str(tech.get("key", ""))
	var tech_name = str(tech.get("name", tech_key))
	var desc = str(tech.get("description", ""))
	var req_techs = tech.get("required_techs", tech.get("prerequisites", []))
	var req_items = tech.get("required_items", [])
	var t_era = int(tech.get("era", 0))
	
	var is_researched = GameState.researched_techs.has(tech_key)
	
	# 检查前置科技
	var prereqs_met = true
	var prereq_names = []
	for p in req_techs:
		var p_str = str(p)
		var p_tech = DataDB.get_tech(p_str)
		var p_name = p_tech.get("name", p_str)
		if not GameState.researched_techs.has(p_str):
			prereqs_met = false
			prereq_names.append("✕ %s" % p_name)
		else:
			prereq_names.append("✓ %s" % p_name)
			
	# 检查材料消耗
	var items_met = true
	var cost_desc_list = []
	for req in req_items:
		var r_key = req.get("key")
		var r_qty = int(req.get("quantity", 1))
		var owned = 0
		var mat_name = ""
		if r_key is Array:
			var found_max = 0
			for alt in r_key:
				var cnt = GameState.inventory.get_count(alt)
				if cnt > found_max:
					found_max = cnt
				var it = DataDB.get_item(alt)
				if mat_name == "": mat_name = it.get("name", alt)
			owned = found_max
		else:
			owned = GameState.inventory.get_count(r_key)
			var it = DataDB.get_item(r_key)
			mat_name = it.get("name", r_key)
		cost_desc_list.append("%s: %d/%d" % [mat_name, owned, r_qty])
		if owned < r_qty:
			items_met = false

	var era_met = (GameState.current_era >= t_era)
	var can_research = (not is_researched) and prereqs_met and items_met and era_met

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 140)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# 标题栏
	var top_box = HBoxContainer.new()
	vbox.add_child(top_box)
	
	var title_lbl = Label.new()
	title_lbl.text = tech_name
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 15)
	if is_researched:
		title_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	else:
		title_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
	top_box.add_child(title_lbl)
	
	var era_badge = Label.new()
	var era_str = "时代 %d" % t_era
	if t_era < GameState.ERA_NAMES.size():
		era_str = GameState.ERA_NAMES[t_era].split(" ")[0]
	era_badge.text = "[%s]" % era_str
	era_badge.add_theme_font_size_override("font_size", 12)
	era_badge.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
	top_box.add_child(era_badge)
	
	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	vbox.add_child(desc_lbl)
	
	# 前置与材料
	if not prereq_names.is_empty():
		var pre_lbl = Label.new()
		pre_lbl.text = "前置科技: " + " · ".join(prereq_names)
		pre_lbl.add_theme_font_size_override("font_size", 11)
		pre_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5) if prereqs_met else Color(0.9, 0.4, 0.4))
		vbox.add_child(pre_lbl)
		
	var cost_lbl = Label.new()
	cost_lbl.text = "研发消耗: " + ("无" if cost_desc_list.is_empty() else " · ".join(cost_desc_list))
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	vbox.add_child(cost_lbl)
	
	# 动作栏
	var act_box = HBoxContainer.new()
	act_box.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(act_box)
	
	var btn_action = Button.new()
	btn_action.custom_minimum_size = Vector2(110, 32)
	
	if is_researched:
		btn_action.text = "✓ 已研发"
		btn_action.disabled = true
		btn_action.modulate = Color(1.0, 1.0, 1.0, 0.7)
	elif not era_met:
		btn_action.text = "时代未达"
		btn_action.disabled = true
		btn_action.modulate = Color(1.0, 1.0, 1.0, 0.4)
	elif not prereqs_met:
		btn_action.text = "缺少前置"
		btn_action.disabled = true
		btn_action.modulate = Color(1.0, 1.0, 1.0, 0.4)
	elif not items_met:
		btn_action.text = "材料不足"
		btn_action.disabled = true
		btn_action.modulate = Color(1.0, 1.0, 1.0, 0.4)
	else:
		btn_action.text = "研发突破"
		btn_action.disabled = false
		btn_action.modulate = Color(1.0, 1.0, 1.0, 1.0)
		btn_action.pressed.connect(func():
			if GameState.research_tech(tech_key):
				_refresh_ui()
		)
		
	act_box.add_child(btn_action)
	return panel
