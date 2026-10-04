# periodic_table_modal.gd
# 118 元素周期表图鉴 (扁平极简，无 emoji，ESC/右键返回)
extends Control

@onready var grid_container = $CenterPanel/VBox/Body/Scroll/Grid
@onready var count_label = $CenterPanel/VBox/Header/HBox/CountLabel
@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_close.pressed.connect(func(): visible = false)
	GameState.element_discovered.connect(func(_num, _key): _refresh_grid())
	_build_grid()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_grid()
		btn_close.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		visible = false
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
		visible = false
		get_viewport().set_input_as_handled()

func _build_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
		
	for i in range(1, 119):
		var elem = DataDB.get_element(i)
		var sym = elem.get("symbol", "?")
		var cname = elem.get("name", "?")
		
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(58, 64)
		panel.name = "Elem_%d" % i
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		
		var num_lbl = Label.new()
		num_lbl.text = "#%d" % i
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 10)
		num_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		
		var sym_lbl = Label.new()
		sym_lbl.text = sym
		sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sym_lbl.add_theme_font_size_override("font_size", 15)
		
		var name_lbl = Label.new()
		name_lbl.text = cname
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 10)
		
		vbox.add_child(num_lbl)
		vbox.add_child(sym_lbl)
		vbox.add_child(name_lbl)
		panel.add_child(vbox)
		grid_container.add_child(panel)

	_refresh_grid()

func _refresh_grid() -> void:
	var total_disc = GameState.discovered_elements.size()
	count_label.text = "已点亮: %d / 118" % total_disc
	
	for i in range(1, 119):
		var panel = grid_container.get_node_or_null("Elem_%d" % i)
		if not panel:
			continue
			
		var vbox = panel.get_child(0) as VBoxContainer
		var num_lbl = vbox.get_child(0) as Label
		var sym_lbl = vbox.get_child(1) as Label
		var name_lbl = vbox.get_child(2) as Label
		
		var is_disc = GameState.discovered_elements.has(i)
		var elem = DataDB.get_element(i)
		
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		
		if is_disc:
			style.bg_color = Color(0.12, 0.18, 0.28, 0.95)
			style.border_color = ThemeStyler.COLOR_ACCENT
			sym_lbl.text = elem.get("symbol", "?")
			name_lbl.text = elem.get("name", "?")
			sym_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
			name_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
		else:
			style.bg_color = Color(0.08, 0.09, 0.11, 0.6)
			style.border_color = Color(0.18, 0.20, 0.23, 0.5)
			sym_lbl.text = "?"
			name_lbl.text = "???"
			sym_lbl.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42))
			name_lbl.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42))
			
		panel.add_theme_stylebox_override("panel", style)
