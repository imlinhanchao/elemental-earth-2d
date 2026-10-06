# periodic_table_modal.gd
# 118 元素周期表图鉴 (扁平极简，无 emoji，ESC/右键返回)
extends Control

@onready var grid_container = $CenterPanel/VBox/Body/Scroll/Grid
@onready var count_label = $CenterPanel/VBox/Header/HBox/CountLabel
@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose

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
	btn_close.pressed.connect(func(): visible = false)
	GameState.element_discovered.connect(func(_num, _key):
		if _built: _refresh_grid()
	)

# 118 个元素格在第一次打开时才创建，避免进入游戏时一次性构建
var _built: bool = false

func open() -> void:
	if not _built:
		_built = true
		_build_grid()
	visible = true
	_refresh_grid()
	btn_close.grab_focus()

func close() -> void:
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _input(event: InputEvent) -> void:
	if not visible or not ModalStack.is_top(self):
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
		num_lbl.add_theme_font_size_override("font_size", 12)
		num_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		
		var sym_lbl = Label.new()
		sym_lbl.text = sym
		sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sym_lbl.add_theme_font_size_override("font_size", 16)
		
		var name_lbl = Label.new()
		name_lbl.text = cname
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		
		vbox.add_child(num_lbl)
		vbox.add_child(sym_lbl)
		vbox.add_child(name_lbl)
		panel.add_child(vbox)
		grid_container.add_child(panel)

	_refresh_grid()

func _refresh_grid() -> void:
	var total_disc = GameState.discovered_elements.size()
	count_label.text = "已发现 %d / 118" % total_disc
	
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
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		
		if is_disc:
			style.bg_color = ThemeStyler.COLOR_CARD_HOVER
			style.border_color = ThemeStyler.COLOR_BORDER_FOCUS
			sym_lbl.text = elem.get("symbol", "?")
			name_lbl.text = elem.get("name", "?")
			sym_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
			name_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
		else:
			style.bg_color = Color(0.92, 0.89, 0.84, 0.50)
			style.border_color = ThemeStyler.COLOR_BORDER
			sym_lbl.text = "?"
			name_lbl.text = "???"
			sym_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_MUTED)
			name_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_MUTED)
			
		panel.add_theme_stylebox_override("panel", style)
