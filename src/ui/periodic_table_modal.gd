# periodic_table_modal.gd
# 全屏 118 元素周期表圣殿图鉴
extends PanelContainer

@onready var grid_container = $Margin/VBox/Scroll/Grid
@onready var count_label = $Margin/VBox/Header/CountLabel
@onready var btn_close = $Margin/VBox/Header/BtnClose

func _ready() -> void:
	visible = false
	btn_close.pressed.connect(func(): visible = false)
	GameState.element_discovered.connect(func(_num, _key): _refresh_grid())
	_build_grid()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_grid()

func _build_grid() -> void:
	# 清空现有子项
	for child in grid_container.get_children():
		child.queue_free()
		
	# 遍历 1 到 118 元素
	for i in range(1, 119):
		var elem = DataDB.get_element(i)
		var sym = elem.get("symbol", "?")
		var cname = elem.get("name", "?")
		
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(58, 64)
		panel.name = "Elem_%d" % i
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var num_lbl = Label.new()
		num_lbl.text = "#%d" % i
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 10)
		
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
	count_label.text = "已点亮人类化学元素: %d / 118" % GameState.discovered_elements.size()
	for i in range(1, 119):
		var panel = grid_container.get_node_or_null("Elem_%d" % i)
		if panel:
			var is_lit = GameState.discovered_elements.has(i)
			if is_lit:
				panel.modulate = Color(1.0, 0.88, 0.3) # 闪耀金光
			else:
				panel.modulate = Color(0.4, 0.42, 0.45, 0.6) # 暗灰色
