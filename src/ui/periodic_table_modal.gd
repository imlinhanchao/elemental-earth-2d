# periodic_table_modal.gd
# 元素图鉴：按标准周期表布局排列 118 种元素 (参考 Web 版 PeriodicTable.vue)。
# - 18 列 × 7 周期，镧系 / 锕系单独放在下方两行，与主表之间留一道空隙；主表第 3 列第 6、7 周期放「57-71」「89-103」占位格；
# - 已发现的元素以元素族颜色填充；未发现的为灰色，游戏中能获得的 45% 透明度，其余 20%；
# - 底部为元素族图例；悬停显示序号、符号、中英文名与原子量。
# - 点击已点亮的元素弹出详情浮窗 (元素卡、英文名、原子量、分类与探索笔记)，再点一次、点空白处或 ESC / 右键收起；
#   浮窗紧贴元素格，右侧列向左展开、下方行向上展开 (与 Web 版 ExploreView 一致)。ESC / 右键 / [P] 关闭图鉴。
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
var _table: Control
var _popover: PanelContainer
var _pop_card: PanelContainer
var _pop_num: Label
var _pop_sym: Label
var _pop_cn: Label
var _pop_en: Label
var _pop_meta: Label
var _pop_story: Label
var _pop_elem: int = 0
const POPOVER_W := 320.0

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
	_hide_popover()
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _input(event: InputEvent) -> void:
	if not visible or not ModalStack.is_top(self):
		return
	var dismiss = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P))
	if dismiss:
		# 先收起元素浮窗，再关闭图鉴 ([P] 直接关闭)
		if _popover and _popover.visible and not (event is InputEventKey and event.keycode == KEY_P):
			_hide_popover()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_left_click(event.position)

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
	_table = table

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
	_build_popover()

# 元素详情浮窗：左侧族色竖条，元素卡 + 英文名 / 原子量 / 分类，下方「探索笔记」
func _build_popover() -> void:
	_popover = PanelContainer.new()
	_popover.visible = false
	_popover.z_index = 10
	_popover.custom_minimum_size = Vector2(POPOVER_W, 0)
	_popover.mouse_filter = Control.MOUSE_FILTER_STOP
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_popover.add_child(v)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_pop_card = PanelContainer.new()
	_pop_card.custom_minimum_size = Vector2(64, 80)
	var cv = VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 0)
	_pop_num = _label("", ThemeStyler.FONT_CAPTION)
	_pop_sym = _label("", 26, true)
	_pop_cn = _label("", ThemeStyler.FONT_BODY)
	for l in [_pop_num, _pop_sym, _pop_cn]:
		l.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_ON_ACCENT)
		cv.add_child(l)
	_pop_num.modulate.a = 0.8
	_pop_card.add_child(cv)
	head.add_child(_pop_card)
	var info = VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	_pop_en = _label("", ThemeStyler.FONT_HEADING, true)
	_pop_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pop_en.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
	_pop_en.clip_text = true
	info.add_child(_pop_en)
	_pop_meta = _label("", ThemeStyler.FONT_CAPTION)
	_pop_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pop_meta.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	info.add_child(_pop_meta)
	head.add_child(info)
	v.add_child(head)
	v.add_child(HSeparator.new())
	var note = _label("探索笔记", ThemeStyler.FONT_CAPTION, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_MUTED)
	v.add_child(note)
	_pop_story = _label("", ThemeStyler.FONT_BODY)
	_pop_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pop_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pop_story.custom_minimum_size = Vector2(POPOVER_W - 36, 0)
	_pop_story.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
	_pop_story.add_theme_constant_override("line_spacing", 4)
	v.add_child(_pop_story)
	_table.add_child(_popover)

func _on_left_click(screen_pos: Vector2) -> void:
	if _popover == null:
		return
	if _popover.visible and _popover.get_global_rect().has_point(screen_pos):
		return
	for i in _cells.keys():
		var panel: Panel = _cells[i]["panel"]
		if panel.get_global_rect().has_point(screen_pos):
			# 只有点亮的元素能查看；再点一次同一格收起
			if GameState.discovered_elements.has(i) and i != _pop_elem:
				show_element(i)
			else:
				_hide_popover()
			get_viewport().set_input_as_handled()
			return
	_hide_popover()

func show_element(i: int) -> void:
	var elem = DataDB.get_element(i)
	var col = category_color(str(elem.get("category", "")))
	_pop_elem = i
	_pop_num.text = str(i)
	_pop_sym.text = elem.get("symbol", "?")
	_pop_cn.text = elem.get("name", "?")
	_pop_en.text = elem.get("nameEn", "")
	_pop_meta.text = "原子量：%s\n分类：%s" % [elem.get("mass", "—"), LEGEND_LABELS.get(str(elem.get("category", "")), "—")]
	_pop_story.text = str(elem.get("story", ""))
	_pop_card.add_theme_stylebox_override("panel", _cell_box(col, col))
	var box = ThemeStyler.create_card_box(10, ThemeStyler.COLOR_BG_SOLID, ThemeStyler.COLOR_BORDER)
	box.set_border_width_all(1)
	box.border_width_left = 4
	box.border_color = col
	for side in ["left", "top", "right", "bottom"]:
		box.set("content_margin_" + side, 14)
	box.shadow_color = ThemeStyler.COLOR_SHADOW
	box.shadow_size = 12
	_popover.add_theme_stylebox_override("panel", box)
	_popover.reset_size()
	_popover.visible = true
	_place_popover.call_deferred(i)

# 位置：默认在元素格下方左对齐；第 13 列以后向左展开，第 10~12 列居中；第 6 行以后放到格子上方
func _place_popover(i: int) -> void:
	_popover.reset_size()
	var elem = DataDB.get_element(i)
	var row = int(elem.get("row", 1))
	var col = int(elem.get("col", 1))
	var cell = cell_position(row, col)
	var sz = _popover.size
	var x = cell.x
	if col > 12:
		x = cell.x + CELL.x - sz.x
	elif col > 9:
		x = cell.x + CELL.x * 0.5 - sz.x * 0.5
	var y = cell.y + CELL.y + 8.0
	if row > 5:
		y = cell.y - sz.y - 8.0
	var limit = _table.size - sz
	_popover.position = Vector2(clampf(x, 0.0, maxf(0.0, limit.x)), clampf(y, -40.0, maxf(0.0, limit.y + 40.0)))

func _hide_popover() -> void:
	_pop_elem = 0
	if _popover:
		_popover.visible = false

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
	count_label.text = "已发现 %d / 118 · 点击已点亮的元素查看探索笔记" % GameState.discovered_elements.size()
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
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if lit else Control.CURSOR_ARROW
