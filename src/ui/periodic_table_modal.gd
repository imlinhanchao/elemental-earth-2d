# periodic_table_modal.gd
# 元素图鉴：按标准周期表布局排列 118 种元素 (参考 Web 版 PeriodicTable.vue)。
# - 18 列 × 7 周期，镧系 / 锕系单独放在下方两行，与主表之间留一道空隙；主表第 3 列第 6、7 周期放「57-71」「89-103」占位格；
# - 已发现的元素以元素族颜色填充；未发现的为灰色，游戏中能获得的 45% 透明度，其余 20%；
# - 底部为元素族图例；悬停显示序号、符号、中英文名与原子量。ESC / 右键 / [P] 关闭。
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const ElementDiscoveryModal = preload("res://src/ui/element_discovery_modal.gd")

@onready var scroll: ScrollContainer = $CenterPanel/VBox/Body/Scroll
@onready var count_label = $CenterPanel/VBox/Header/HBox/CountLabel
@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose

const CELL := Vector2(58, 58)
const GAP := 3.0
const F_BLOCK_SPACER := 12.0 # 主表与镧系 / 锕系之间的空隙
const LEGEND_ORDER := ["alkali-metal", "alkaline-earth-metal", "transition-metal", "post-transition-metal",
	"metalloid", "nonmetal", "halogen", "noble-gas", "lanthanide", "actinide"]
const LEGEND_LABELS := {
	"alkali-metal": "碱金属", "alkaline-earth-metal": "碱土金属", "transition-metal": "过渡金属",
	"post-transition-metal": "后过渡金属", "metalloid": "类金属", "nonmetal": "非金属",
	"halogen": "卤素", "noble-gas": "稀有气体", "lanthanide": "镧系元素", "actinide": "锕系元素",
}

var _cells: Dictionary = {} # 原子序数 -> {panel, num, sym, name}
var _implemented: Dictionary = {} # 游戏中能获得单质的原子序数
var _highlight: int = 0
var _built: bool = false

func _ready() -> void:
	ModalStack.track(self)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var p_box = ThemeStyler.create_card_box(12, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER)
	for side in ["left", "top", "right", "bottom"]:
		p_box.set("content_margin_" + side, 16)
	$CenterPanel.add_theme_stylebox_override("panel", p_box)
	btn_close.pressed.connect(close)
	GameState.element_discovered.connect(func(_num, _key):
		if _built: _refresh_grid()
	)

# 元素格在第一次打开时才创建，避免进入游戏时一次性构建
# highlight > 0 时用铜色描边标出该元素 (从元素发现弹窗跳转过来)
func open(highlight: int = 0) -> void:
	_highlight = highlight
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
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
		close()
		get_viewport().set_input_as_handled()

static func category_color(cat: String) -> Color:
	return ThemeStyler.adapt(ElementDiscoveryModal.CATEGORY_COLORS.get(cat, Color(0.45, 0.42, 0.38)))

# 周期表第 row 行、第 col 列 (均从 1 起；row 9、10 为镧系 / 锕系) 的左上角坐标
static func cell_position(row: int, col: int) -> Vector2:
	var y = (row - 1) * (CELL.y + GAP)
	if row >= 9:
		y = 7 * (CELL.y + GAP) + F_BLOCK_SPACER + (row - 9) * (CELL.y + GAP)
	return Vector2((col - 1) * (CELL.x + GAP), y)

func _label(text: String, size: int, bold: bool = false) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	if bold:
		l.add_theme_font_override("font", ThemeStyler.get_font_sans_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_grid() -> void:
	for k in DataDB.items.keys():
		var n = DataDB.is_pure_element(k)
		if n > 0:
			_implemented[n] = true

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	scroll.add_child(v)

	var table = Control.new()
	table.custom_minimum_size = cell_position(10, 18) + CELL
	v.add_child(table)

	# 镧系 / 锕系在主表中的占位格
	for ph in [[6, "57-71"], [7, "89-103"]]:
		var p = Panel.new()
		p.position = cell_position(ph[0], 3)
		p.size = CELL
		p.add_theme_stylebox_override("panel", _cell_box(ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER))
		p.modulate.a = 0.5
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l = _label(ph[1], ThemeStyler.FONT_CAPTION, true)
		l.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		table.add_child(p)

	for i in range(1, 119):
		var elem = DataDB.get_element(i)
		if elem.is_empty():
			continue
		var panel = Panel.new()
		panel.name = "Elem_%d" % i
		panel.position = cell_position(int(elem.get("row", 1)), int(elem.get("col", 1)))
		panel.size = CELL
		panel.tooltip_text = "%d %s · %s · %s%s" % [i, elem.get("symbol", "?"), elem.get("name", "?"), elem.get("nameEn", ""),
			(" · " + str(elem["mass"])) if str(elem.get("mass", "")) != "" else ""]
		var num = _label(str(i), ThemeStyler.FONT_CAPTION)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		num.position = Vector2(4, 0)
		num.size = Vector2(CELL.x - 8, 16)
		var sym = _label(elem.get("symbol", "?"), ThemeStyler.FONT_TITLE, true)
		sym.position = Vector2(0, 12)
		sym.size = Vector2(CELL.x, 28)
		var nm = _label(elem.get("name", "?"), ThemeStyler.FONT_CAPTION)
		nm.position = Vector2(0, 38)
		nm.size = Vector2(CELL.x, 18)
		for c in [num, sym, nm]:
			panel.add_child(c)
		table.add_child(panel)
		_cells[i] = {"panel": panel, "num": num, "sym": sym, "name": nm}

	# 图例：元素族颜色 + 未点亮
	var legend = HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 8)
	legend.add_theme_constant_override("v_separation", 6)
	for cat in LEGEND_ORDER:
		legend.add_child(_legend_chip(LEGEND_LABELS[cat], category_color(cat), ThemeStyler.COLOR_TEXT_ON_ACCENT))
	legend.add_child(_legend_chip("未点亮", ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_TEXT_SECONDARY))
	v.add_child(legend)

func _legend_chip(text: String, bg: Color, fg: Color) -> PanelContainer:
	var chip = PanelContainer.new()
	var box = _cell_box(bg, bg)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", box)
	var l = _label(text, ThemeStyler.FONT_CAPTION)
	l.add_theme_color_override("font_color", fg)
	chip.add_child(l)
	return chip

func _cell_box(bg: Color, border: Color, border_w: int = 0) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_corner_radius_all(4)
	b.set_border_width_all(border_w)
	return b

func _refresh_grid() -> void:
	count_label.text = "已发现 %d / 118" % GameState.discovered_elements.size()
	for i in _cells.keys():
		var c = _cells[i]
		var panel: Panel = c["panel"]
		var lit = GameState.discovered_elements.has(i)
		var focus = i == _highlight
		var cat = str(DataDB.get_element(i).get("category", ""))
		var bg = category_color(cat) if lit else ThemeStyler.COLOR_CARD
		var border = ThemeStyler.COLOR_ACCENT if focus else bg
		panel.add_theme_stylebox_override("panel", _cell_box(bg, border, 3 if focus else 0))
		var fg = ThemeStyler.COLOR_TEXT_ON_ACCENT if lit else ThemeStyler.COLOR_TEXT_PRIMARY
		for k in ["num", "sym", "name"]:
			c[k].add_theme_color_override("font_color", fg)
		c["num"].modulate.a = 0.8
		# 未点亮：游戏中能获得的元素 45%，其余 20%
		panel.modulate.a = 1.0 if lit or focus else (0.45 if _implemented.has(i) else 0.2)
		panel.z_index = 1 if focus else 0
