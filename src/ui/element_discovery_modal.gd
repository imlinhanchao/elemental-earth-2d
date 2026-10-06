# element_discovery_modal.gd
# 元素发现庆典全息弹窗 (高精度元素卡片 · 宏观科学史料 · 周期表联动)
class_name ElementDiscoveryModal
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")

# 元素族分类配色
const CATEGORY_COLORS: Dictionary = {
	"alkali-metal": Color(0.75, 0.22, 0.22),          # 碱金属
	"alkaline-earth-metal": Color(0.72, 0.45, 0.10),  # 碱土金属
	"transition-metal": Color(0.12, 0.45, 0.68),      # 过渡金属
	"post-transition-metal": Color(0.14, 0.52, 0.40), # 后过渡金属
	"metalloid": Color(0.42, 0.52, 0.14),             # 类金属
	"nonmetal": Color(0.18, 0.55, 0.26),              # 反应性非金属
	"halogen": Color(0.60, 0.25, 0.65),               # 卤素
	"noble-gas": Color(0.42, 0.30, 0.72),             # 稀有气体
	"lanthanide": Color(0.72, 0.26, 0.45),            # 镧系
	"actinide": Color(0.65, 0.20, 0.32)               # 锕系
}

const CATEGORY_NAMES: Dictionary = {
	"alkali-metal": "碱金属 Alkali Metal",
	"alkaline-earth-metal": "碱土金属 Alkaline Earth Metal",
	"transition-metal": "过渡金属 Transition Metal",
	"post-transition-metal": "后过渡金属 Post-transition Metal",
	"metalloid": "类金属 Metalloid",
	"nonmetal": "反应性非金属 Reactive Nonmetal",
	"halogen": "卤素 Halogen",
	"noble-gas": "稀有气体 Noble Gas",
	"lanthanide": "镧系金属 Lanthanide",
	"actinide": "锕系金属 Actinide"
}

signal open_periodic_table_requested
signal modal_closed

var current_elem_number: int = 1

# 节点引用
var backdrop: ColorRect
var center_box: CenterContainer
var card_panel: PanelContainer
var num_label: Label
var symbol_label: Label
var name_label: Label
var mass_label: Label
var category_badge: Label
var position_label: Label
var story_label: RichTextLabel
var progress_label: Label
var progress_bar: ProgressBar
var btn_view_pt: Button
var btn_confirm: Button

func _init() -> void:
	name = "ElementDiscoveryModal"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 100

func _ready() -> void:
	ModalStack.track(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	# 1. 全屏柔和暗色微光蒙版
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = ThemeStyler.adapt(Color(0.20, 0.17, 0.13, 0.35))
	add_child(backdrop)

	# 2. 居中容器
	center_box = CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_box)

	# 3. 核心全息卡片容器 (520 x 580)
	card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(500, 560)
	center_box.add_child(card_panel)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = ThemeStyler.COLOR_BG_SOLID
	card_style.border_color = ThemeStyler.COLOR_BORDER_FOCUS
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 18
	card_style.corner_radius_top_right = 18
	card_style.corner_radius_bottom_left = 18
	card_style.corner_radius_bottom_right = 18
	card_style.shadow_color = ThemeStyler.adapt(Color(0.25, 0.20, 0.12, 0.22))
	card_style.shadow_size = 28
	card_panel.add_theme_stylebox_override("panel", card_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	card_panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(main_vbox)

	# 顶部标题栏
	var top_hbox = HBoxContainer.new()
	main_vbox.add_child(top_hbox)

	var header_title = Label.new()
	header_title.text = "发现新元素"
	header_title.add_theme_font_size_override("font_size", 12)
	header_title.add_theme_color_override("font_color", ThemeStyler.adapt(Color(0.58, 0.49, 0.17)))
	top_hbox.add_child(header_title)

	var spacer_top = Control.new()
	spacer_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer_top)

	num_label = Label.new()
	num_label.text = "NO. 29"
	num_label.add_theme_font_size_override("font_size", 16)
	num_label.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
	top_hbox.add_child(num_label)

	# 中央元素大图示卡片 (内嵌发光框)
	var elem_box = PanelContainer.new()
	elem_box.custom_minimum_size = Vector2(0, 160)
	var e_box_style = StyleBoxFlat.new()
	e_box_style.bg_color = ThemeStyler.COLOR_CARD
	e_box_style.border_color = ThemeStyler.adapt(Color(0.30, 0.43, 0.62, 0.50))
	e_box_style.border_width_left = 1
	e_box_style.border_width_top = 1
	e_box_style.border_width_right = 1
	e_box_style.border_width_bottom = 1
	e_box_style.corner_radius_top_left = 12
	e_box_style.corner_radius_top_right = 12
	e_box_style.corner_radius_bottom_left = 12
	e_box_style.corner_radius_bottom_right = 12
	elem_box.add_theme_stylebox_override("panel", e_box_style)
	main_vbox.add_child(elem_box)

	var elem_vbox = VBoxContainer.new()
	elem_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	elem_vbox.add_theme_constant_override("separation", 4)
	elem_box.add_child(elem_vbox)

	symbol_label = Label.new()
	symbol_label.text = "Cu"
	symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol_label.add_theme_font_size_override("font_size", 62)
	symbol_label.add_theme_color_override("font_color", ThemeStyler.adapt(Color(0.14, 0.47, 0.62)))
	elem_vbox.add_child(symbol_label)

	name_label = Label.new()
	name_label.text = "铜 · Copper"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", ThemeStyler.adapt(Color(0.15, 0.14, 0.13)))
	elem_vbox.add_child(name_label)

	# 属性信息条
	var meta_hbox = HBoxContainer.new()
	meta_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_hbox.add_theme_constant_override("separation", 18)
	main_vbox.add_child(meta_hbox)

	mass_label = Label.new()
	mass_label.text = "原子量: 63.546"
	mass_label.add_theme_font_size_override("font_size", 12)
	mass_label.add_theme_color_override("font_color", ThemeStyler.adapt(Color(0.37, 0.34, 0.30)))
	meta_hbox.add_child(mass_label)

	category_badge = Label.new()
	category_badge.text = "[过渡金属]"
	category_badge.add_theme_font_size_override("font_size", 12)
	category_badge.add_theme_color_override("font_color", ThemeStyler.adapt(Color(0.24, 0.51, 0.62)))
	meta_hbox.add_child(category_badge)

	position_label = Label.new()
	position_label.text = "周期 4 · 族 11"
	position_label.add_theme_font_size_override("font_size", 12)
	position_label.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	meta_hbox.add_child(position_label)

	# 科学史料卡片
	var story_panel = PanelContainer.new()
	story_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var s_style = StyleBoxFlat.new()
	s_style.bg_color = ThemeStyler.adapt(Color(0.92, 0.89, 0.84, 0.70))
	s_style.border_color = ThemeStyler.adapt(Color(0.25, 0.40, 0.62, 0.40))
	s_style.border_width_left = 1
	s_style.border_width_top = 1
	s_style.border_width_right = 1
	s_style.border_width_bottom = 1
	s_style.corner_radius_top_left = 8
	s_style.corner_radius_top_right = 8
	s_style.corner_radius_bottom_left = 8
	s_style.corner_radius_bottom_right = 8
	story_panel.add_theme_stylebox_override("panel", s_style)
	main_vbox.add_child(story_panel)

	var story_margin = MarginContainer.new()
	story_margin.add_theme_constant_override("margin_left", 14)
	story_margin.add_theme_constant_override("margin_top", 10)
	story_margin.add_theme_constant_override("margin_right", 14)
	story_margin.add_theme_constant_override("margin_bottom", 10)
	story_panel.add_child(story_margin)

	story_label = RichTextLabel.new()
	story_label.bbcode_enabled = true
	story_label.fit_content = false
	story_label.scroll_active = true
	story_label.add_theme_font_size_override("normal_font_size", 12)
	story_label.add_theme_color_override("default_color", ThemeStyler.adapt(Color(0.15, 0.14, 0.13)))
	story_margin.add_child(story_label)

	# 进度指示栏
	var progress_vbox = VBoxContainer.new()
	progress_vbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(progress_vbox)

	var prog_head = HBoxContainer.new()
	progress_vbox.add_child(prog_head)

	var prog_title = Label.new()
	prog_title.text = "周期表进度"
	prog_title.add_theme_font_size_override("font_size", 12)
	prog_title.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	prog_head.add_child(prog_title)

	var sp_prog = Control.new()
	sp_prog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_head.add_child(sp_prog)

	progress_label = Label.new()
	progress_label.text = "已点亮 1 / 118"
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
	prog_head.add_child(progress_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 6)
	progress_bar.max_value = 118.0
	progress_bar.show_percentage = false
	progress_vbox.add_child(progress_bar)

	# 底部按钮栏
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 14)
	main_vbox.add_child(btn_hbox)

	btn_view_pt = Button.new()
	btn_view_pt.text = "查看周期表 [P]"
	btn_view_pt.custom_minimum_size = Vector2(170, 38)
	btn_view_pt.add_theme_font_size_override("font_size", 14)
	btn_view_pt.pressed.connect(_on_view_pt_pressed)
	btn_hbox.add_child(btn_view_pt)

	btn_confirm = Button.new()
	btn_confirm.text = "收录 [空格]"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size = Vector2(0, 38)
	btn_confirm.add_theme_font_size_override("font_size", 14)
	btn_confirm.pressed.connect(close)
	btn_hbox.add_child(btn_confirm)

func show_discovery(elem_num: int, item_key: String = "") -> void:
	current_elem_number = elem_num
	var elem = DataDB.get_element(elem_num)
	if elem.is_empty():
		return

	var sym = str(elem.get("symbol", "?"))
	var cname = str(elem.get("name", item_key))
	var ename = str(elem.get("nameEn", ""))
	var mass = str(elem.get("mass", "-"))
	var cat = str(elem.get("category", "transition-metal"))
	var row = int(elem.get("row", 1))
	var col = int(elem.get("col", 1))
	var story = str(elem.get("story", "人类在探索微观物质结构过程中，成功提纯并确证了此关键化学元素。"))

	var cat_color = CATEGORY_COLORS.get(cat, ThemeStyler.adapt(Color(0.12, 0.45, 0.68)))
	var cat_name = CATEGORY_NAMES.get(cat, cat.capitalize())

	num_label.text = "NO. %d" % elem_num
	num_label.add_theme_color_override("font_color", cat_color)

	symbol_label.text = sym
	symbol_label.add_theme_color_override("font_color", cat_color)

	name_label.text = "%s · %s" % [cname, ename] if ename != "" else cname
	mass_label.text = "原子量 %s" % mass
	category_badge.text = "[%s]" % cat_name
	category_badge.add_theme_color_override("font_color", cat_color)
	position_label.text = "周期 %d · 族 %d" % [row, col]

	story_label.text = "[color=#3D5A8A][b]发现史[/b][/color]\n" + story

	var total_disc = GameState.discovered_elements.size()
	progress_label.text = "已发现 %d / 118" % total_disc
	progress_bar.value = float(total_disc)

	# 卡片边框与辉光跟随元素族主题色
	var card_style = card_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if card_style:
		card_style.border_color = cat_color

	visible = true
	card_panel.pivot_offset = card_panel.custom_minimum_size * 0.5
	card_panel.scale = Vector2(0.85, 0.85)
	card_panel.modulate.a = 0.0

	var tw = create_tween().set_parallel(true)
	tw.tween_property(card_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_panel, "modulate:a", 1.0, 0.25)
	btn_confirm.grab_focus()

func close() -> void:
	visible = false
	modal_closed.emit()

func _on_view_pt_pressed() -> void:
	close()
	open_periodic_table_requested.emit()

func _input(event: InputEvent) -> void:
	if not visible or not ModalStack.is_top(self):
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P:
			_on_view_pt_pressed()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			close()
			get_viewport().set_input_as_handled()
