# lab_workbench_modal.gd
# 实验台界面 (三栏)：左侧操作面板 (常温 / 点火 / 通电 / 追加) → 中间实验装置与炉火 → 右侧烧瓶与行囊格子。
# 规则与状态都在模拟层 (src/core/lab_bench.gd)，这里只发命令、读状态。界面在代码中构建。
# 同一个界面也用于地图上的炉体 (open_bench)：炉膛就是容器，只列出加热类操作，标题换成炉体名称。
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const ItemIconManager = preload("res://src/ui/item_icon_manager.gd")
const LabBench = preload("res://src/core/lab_bench.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")

@onready var btn_close: Button = $CenterPanel/VBox/Header/HBox/BtnClose
@onready var body: MarginContainer = $CenterPanel/VBox/Body
@onready var title_label: Label = $CenterPanel/VBox/Header/HBox/Title

const GROUP_TITLES := ["常温", "点火", "通电", "追加操作"]
const THERMO_MAX_C := 1600.0
const SLOT := 56
# 适合放进烧瓶的物品分类 (工具、建筑、奇观等不列出)
const REAGENT_CATEGORIES := ["材料", "矿石", "燃料", "酸碱", "物品", "液体", "气体", "化工", "元素"]

var lab # LabBench
var op_tiles: Dictionary = {}   # op key -> Button
var op_badges: Dictionary = {}  # op key -> Label (锁定原因)
var hidden_ops_label: Label
var group_heads: Array = [] # [Label, [op keys]]
var stage_icon: TextureRect
var stage_title: Label
var stage_desc: Label
var vessel_draw: Control
var sensor_card: PanelContainer
var sensor_badge: Label
var sensor_text: Label
var sensor_bar: ProgressBar
var energy_title: Label
var energy_status: Label
var energy_items: HFlowContainer
var temp_label: Label
var btn_fire: Button
var tab_flask: Button
var tab_notes: Button
var view_flask: VBoxContainer
var view_notes: VBoxContainer
var flask_slots: HFlowContainer
var flask_title: Label
var container_slots: HFlowContainer
var container_head: Label
var btn_retrieve: Button
var reagent_grid: GridContainer
var log_label: RichTextLabel
var notes_list: VBoxContainer
var reagent_search: LineEdit
var notes_search: LineEdit

var current_tab: int = 0
var bubble_phase: float = 0.0
var _refresh_timer: float = 0.0
var _dirty: bool = false

func _ready() -> void:
	ModalStack.track(self)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$CenterPanel.add_theme_stylebox_override("panel", _box(14, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER, 16))
	_build()
	btn_close.pressed.connect(close)
	_bind(GameState.lab)
	GameState.inventory.item_changed.connect(func(_k, _c): _mark_dirty())
	GameState.tech_researched.connect(func(_k): _mark_dirty())
	GameState.era_advanced.connect(func(_a, _b, _c): _mark_dirty())
	GameState.notification_posted.connect(func(t, _c):
		if visible and (t.begins_with("获得手稿") or t.begins_with("发现新工艺")):
			_add_log(t)
	)
	_switch_tab(0)

# 切换到实验台或某座炉体的 LabBench
func _bind(bench) -> void:
	if lab == bench:
		return
	if lab != null and lab.reacted.is_connected(_on_reacted):
		lab.reacted.disconnect(_on_reacted)
	lab = bench
	lab.reacted.connect(_on_reacted)
	log_label.clear()
	var furnace = lab.is_furnace()
	title_label.text = DataDB.get_building_recipe(lab.furnace_type).get("name", "炉体") if furnace else "实验台"
	container_head.visible = not furnace
	container_slots.visible = not furnace

# 手稿、已确证工艺的那一份 (炉体共用实验台的)
func _book():
	return lab.book()

# ---------------------------------------------------------------- 样式工具

func _box(radius: int, bg: Color, border: Color, pad: int = 10, border_w: int = 1) -> StyleBoxFlat:
	var b = ThemeStyler.create_card_box(radius, bg, border)
	for side in ["left", "top", "right", "bottom"]:
		b.set("content_margin_" + side, pad)
		b.set("border_width_" + side, border_w)
	return b

func _label(text: String, size: int, col: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

# 主行动按钮：铜色实底
func _style_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _box(8, ThemeStyler.COLOR_ACCENT, ThemeStyler.COLOR_ACCENT, 8))
	b.add_theme_stylebox_override("hover", _box(8, ThemeStyler.COLOR_ACCENT_HOVER, ThemeStyler.COLOR_ACCENT_HOVER, 8))
	b.add_theme_stylebox_override("pressed", _box(8, ThemeStyler.COLOR_ACCENT_PRESSED, ThemeStyler.COLOR_ACCENT_PRESSED, 8))
	b.add_theme_stylebox_override("disabled", _box(8, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER, 8))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, ThemeStyler.COLOR_TEXT_ON_ACCENT)
	b.add_theme_font_override("font", ThemeStyler.get_font_sans_bold())

func _op_icon(key: String) -> Texture2D:
	return ItemIconManager.load_texture("res://assets/icons/%s.svg" % DataDB.get_lab_op(key).get("icon", "lab"))

# 物品格子：图标 + 右下角数量；selected 时铜色描边
func _slot(key: String, count: int, highlight: Color = Color(0, 0, 0, 0)) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.icon = ItemIconManager.get_icon(key)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = _name(key)
	var border = highlight if highlight.a > 0.0 else ThemeStyler.COLOR_BORDER
	b.add_theme_stylebox_override("normal", _box(8, ThemeStyler.COLOR_BG_SOLID, border, 9, 2 if highlight.a > 0.0 else 1))
	b.add_theme_stylebox_override("hover", _box(8, ThemeStyler.COLOR_CARD_HOVER, ThemeStyler.COLOR_ACCENT, 9, 2))
	b.add_theme_stylebox_override("pressed", _box(8, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_ACCENT_PRESSED, 9, 2))
	if count > 0:
		var c = _label(str(count), ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_PRIMARY)
		c.add_theme_font_override("font", ThemeStyler.get_font_mono())
		c.add_theme_constant_override("outline_size", 4)
		c.add_theme_color_override("font_outline_color", ThemeStyler.COLOR_BG_SOLID)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.anchor_left = 1.0; c.anchor_top = 1.0; c.anchor_right = 1.0; c.anchor_bottom = 1.0
		c.offset_left = -44; c.offset_top = -18; c.offset_right = -4; c.offset_bottom = -1
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(c)
	return b

func _search_box(placeholder: String) -> LineEdit:
	var e = LineEdit.new()
	e.placeholder_text = placeholder
	e.clear_button_enabled = true
	e.custom_minimum_size = Vector2(150, 28)
	e.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
	return e

# 搜索匹配：中文名或 key 包含关键字 (不区分大小写)
func _match(query: String, texts: Array) -> bool:
	var q = query.strip_edges().to_lower()
	if q == "":
		return true
	for t in texts:
		if str(t).to_lower().contains(q):
			return true
	return false

func _section(text: String) -> Label:
	var l = _label(text, ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED)
	l.add_theme_font_override("font", ThemeStyler.get_font_sans_bold())
	return l

# ---------------------------------------------------------------- 构建

func _build() -> void:
	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	body.add_child(cols)
	cols.add_child(_build_ops_panel())
	cols.add_child(_build_stage())
	cols.add_child(_build_side())

# 左栏：操作卡片
func _build_ops_panel() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	panel.add_theme_stylebox_override("panel", _box(10, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER, 10))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	scroll.add_child(v)
	var groups: Array = [[], [], [], LabBench.listed_chain_operations()]
	for op in LabBench.listed_operations():
		groups[LabBench.op_group(op)].append(op)
	for g in range(4):
		if groups[g].is_empty():
			continue
		var head = _section(GROUP_TITLES[g])
		if g > 0:
			head.add_theme_constant_override("line_spacing", 0)
			v.add_child(Control.new())
		v.add_child(head)
		var ks: Array = []
		for op in groups[g]:
			v.add_child(_make_op_tile(op["key"], g == 3))
			ks.append(op["key"])
		group_heads.append([head, ks])
	hidden_ops_label = _label("", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED)
	hidden_ops_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hidden_ops_label)
	return panel

func _make_op_tile(key: String, is_chain: bool) -> Button:
	var b = Button.new()
	b.text = DataDB.get_lab_op(key).get("name", key)
	b.icon = _op_icon(key)
	b.expand_icon = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_constant_override("icon_max_width", 22)
	b.add_theme_constant_override("h_separation", 10)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): _on_chain_pressed(key) if is_chain else _on_op_pressed(key))
	var badge = _label("", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.offset_right = -10
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)
	op_tiles[key] = b
	op_badges[key] = badge
	return b

# 中栏：当前操作、实验装置、侦测卡、炉火 / 电源
func _build_stage() -> Control:
	var stage = PanelContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", _box(10, ThemeStyler.COLOR_BG_SOLID, ThemeStyler.COLOR_BORDER, 14))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	stage.add_child(v)

	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	stage_icon = TextureRect.new()
	stage_icon.custom_minimum_size = Vector2(40, 40)
	stage_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(stage_icon)
	var hv = VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 0)
	stage_title = _label("", ThemeStyler.FONT_TITLE, ThemeStyler.COLOR_TEXT_PRIMARY)
	stage_title.add_theme_font_override("font", ThemeStyler.get_font_sans_bold())
	hv.add_child(stage_title)
	stage_desc = _label("", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_SECONDARY)
	stage_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(stage_desc)
	head.add_child(hv)
	temp_label = _label("", ThemeStyler.FONT_TITLE, ThemeStyler.COLOR_ACCENT)
	temp_label.add_theme_font_override("font", ThemeStyler.get_font_mono())
	head.add_child(temp_label)
	v.add_child(head)

	vessel_draw = Control.new()
	vessel_draw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vessel_draw.custom_minimum_size = Vector2(0, 220)
	vessel_draw.draw.connect(_on_vessel_draw)
	v.add_child(vessel_draw)

	sensor_card = PanelContainer.new()
	var sv = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	sensor_card.add_child(sv)
	var sh = HBoxContainer.new()
	sh.add_child(_section("反应侦测"))
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sp)
	sensor_badge = _label("", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_SECONDARY)
	sensor_badge.add_theme_font_override("font", ThemeStyler.get_font_sans_bold())
	sh.add_child(sensor_badge)
	sv.add_child(sh)
	sensor_text = _label("", ThemeStyler.FONT_BODY, ThemeStyler.COLOR_TEXT_PRIMARY)
	sensor_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sensor_text)
	sensor_bar = ProgressBar.new()
	sensor_bar.custom_minimum_size = Vector2(0, 8)
	sensor_bar.show_percentage = false
	sensor_bar.max_value = 1.0
	sensor_bar.add_theme_stylebox_override("background", _box(4, ThemeStyler.COLOR_CARD, Color(0, 0, 0, 0), 0))
	sensor_bar.add_theme_stylebox_override("fill", _box(4, ThemeStyler.COLOR_SUCCESS, Color(0, 0, 0, 0), 0))
	sv.add_child(sensor_bar)
	v.add_child(sensor_card)

	var dock = PanelContainer.new()
	dock.add_theme_stylebox_override("panel", _box(10, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER, 10))
	var dh = HBoxContainer.new()
	dh.add_theme_constant_override("separation", 12)
	dock.add_child(dh)
	var dl = VBoxContainer.new()
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.add_theme_constant_override("separation", 6)
	var dt = HBoxContainer.new()
	dt.add_theme_constant_override("separation", 10)
	energy_title = _label("", ThemeStyler.FONT_HEADING, ThemeStyler.COLOR_TEXT_PRIMARY)
	energy_title.add_theme_font_override("font", ThemeStyler.get_font_sans_bold())
	dt.add_child(energy_title)
	energy_status = _label("", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_SECONDARY)
	energy_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dt.add_child(energy_status)
	dl.add_child(dt)
	energy_items = HFlowContainer.new()
	energy_items.add_theme_constant_override("h_separation", 6)
	energy_items.add_theme_constant_override("v_separation", 6)
	dl.add_child(energy_items)
	dh.add_child(dl)
	btn_fire = Button.new()
	btn_fire.custom_minimum_size = Vector2(120, 56)
	btn_fire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_fire.add_theme_font_size_override("font_size", ThemeStyler.FONT_HEADING)
	_style_primary(btn_fire)
	btn_fire.pressed.connect(_on_fire_pressed)
	dh.add_child(btn_fire)
	v.add_child(dock)
	return stage

# 右栏：烧瓶 / 手稿
func _build_side() -> Control:
	var side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	side.add_theme_constant_override("separation", 10)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	tab_flask = Button.new()
	tab_notes = Button.new()
	for b in [tab_flask, tab_notes]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		b.focus_mode = Control.FOCUS_NONE
		tabs.add_child(b)
	tab_flask.text = "容器"
	tab_flask.pressed.connect(func(): _switch_tab(0))
	tab_notes.pressed.connect(func(): _switch_tab(1))
	side.add_child(tabs)

	view_flask = VBoxContainer.new()
	view_flask.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_flask.add_theme_constant_override("separation", 8)
	side.add_child(view_flask)
	container_head = _section("选择容器 · 不同实验要用不同容器，每次反应消耗 1 点耐久")
	view_flask.add_child(container_head)
	container_slots = HFlowContainer.new()
	container_slots.add_theme_constant_override("h_separation", 6)
	container_slots.add_theme_constant_override("v_separation", 6)
	view_flask.add_child(container_slots)
	var fh = HBoxContainer.new()
	flask_title = _section("容器内")
	flask_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(flask_title)
	btn_retrieve = Button.new()
	btn_retrieve.text = "全部取回"
	btn_retrieve.tooltip_text = "把容器里的产物和没用完的原料放回行囊"
	btn_retrieve.custom_minimum_size = Vector2(96, 30)
	_style_primary(btn_retrieve)
	btn_retrieve.pressed.connect(_on_retrieve_pressed)
	fh.add_child(btn_retrieve)
	view_flask.add_child(fh)
	var fp = PanelContainer.new()
	fp.custom_minimum_size = Vector2(0, SLOT + 20)
	fp.add_theme_stylebox_override("panel", _box(10, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER, 8))
	flask_slots = HFlowContainer.new()
	flask_slots.add_theme_constant_override("h_separation", 6)
	flask_slots.add_theme_constant_override("v_separation", 6)
	fp.add_child(flask_slots)
	view_flask.add_child(fp)
	var rh = HBoxContainer.new()
	rh.add_theme_constant_override("separation", 8)
	var rl = _section("行囊试剂 · 点击放入 1 份")
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(rl)
	reagent_search = _search_box("搜索试剂")
	reagent_search.text_changed.connect(func(_t): _refresh_reagents())
	rh.add_child(reagent_search)
	view_flask.add_child(rh)
	var rs = ScrollContainer.new()
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reagent_grid = GridContainer.new()
	reagent_grid.columns = 5
	reagent_grid.add_theme_constant_override("h_separation", 6)
	reagent_grid.add_theme_constant_override("v_separation", 6)
	rs.add_child(reagent_grid)
	view_flask.add_child(rs)
	view_flask.add_child(_section("实验记录"))
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, 96)
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", ThemeStyler.FONT_CAPTION)
	view_flask.add_child(log_label)

	view_notes = VBoxContainer.new()
	view_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_notes.add_theme_constant_override("separation", 8)
	side.add_child(view_notes)
	var hint = _label("采集时偶尔捡到，研发科技必得一份，第一次获得某种物品时也可能得到。没见过的物品写作 ???，做成一次后完整显示。", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view_notes.add_child(hint)
	notes_search = _search_box("搜索手稿：名称、原料或产物")
	notes_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_search.text_changed.connect(func(_t): _refresh_notes())
	view_notes.add_child(notes_search)
	var ns = ScrollContainer.new()
	ns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ns.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notes_list = VBoxContainer.new()
	notes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_list.add_theme_constant_override("separation", 8)
	ns.add_child(notes_list)
	view_notes.add_child(ns)
	return side

# ---------------------------------------------------------------- 打开 / 关闭

func open() -> void:
	open_bench(GameState.lab)

# 打开实验台或炉体 (bench 为 Simulation.built_furnaces[hex].bench)
func open_bench(bench) -> void:
	_bind(bench)
	visible = true
	_refresh_all()
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
		# 右键容器内的物品：全部取回该物品；其余位置右键关闭弹窗
		var k = _flask_key_at(event.position)
		if k != "":
			_retrieve_item(k, -1)
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_L):
		close()
		get_viewport().set_input_as_handled()

func _switch_tab(idx: int) -> void:
	current_tab = idx
	view_flask.visible = idx == 0
	view_notes.visible = idx == 1
	for i in 2:
		var b: Button = [tab_flask, tab_notes][i]
		var on = i == idx
		var st = _box(0, ThemeStyler.COLOR_BG_SOLID if on else ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER, 6)
		st.border_width_bottom = 3 if on else 1
		st.border_color = ThemeStyler.COLOR_ACCENT if on else ThemeStyler.COLOR_BORDER
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		b.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT if on else ThemeStyler.COLOR_TEXT_SECONDARY)
		b.add_theme_color_override("font_hover_color", ThemeStyler.COLOR_ACCENT)
	if idx == 1:
		_refresh_notes()

func _mark_dirty() -> void:
	if visible and not _dirty:
		_dirty = true
		call_deferred("_refresh_all")

func _process(delta: float) -> void:
	if not visible:
		return
	bubble_phase += delta * (8.0 if lab.vessel.active_formula != "" else 1.5)
	vessel_draw.queue_redraw()
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.25
		_refresh_status()

# ---------------------------------------------------------------- 刷新

func _refresh_all() -> void:
	_dirty = false
	_refresh_ops()
	_refresh_energy_items()
	_refresh_containers()
	_refresh_reagents()
	_refresh_flask()
	tab_notes.text = "手稿  %d" % _book().fragments.size()
	if current_tab == 1:
		_refresh_notes()
	_refresh_status()

# 操作卡片：选中为铜色实底；未到时代的隐藏并汇总成一行；缺科技 / 工具的显示锁定原因
func _refresh_ops() -> void:
	var hidden := 0
	for k in op_tiles.keys():
		var b: Button = op_tiles[k]
		var reason = lab.op_lock_reason(k)
		var future = LabBench.unlock_era(k) > GameState.current_era
		# 炉体只列出能在炉内完成的加热类操作
		var unusable = lab.is_furnace() and (ChemistrySolver.CHAIN_OPS.has(k) or not LabBench.furnace_operations(lab.furnace_type).has(k))
		b.visible = not future and not unusable
		if future and not unusable:
			hidden += 1
		if future or unusable:
			continue
		var is_chain = ChemistrySolver.CHAIN_OPS.has(k)
		var on = lab.chain_ops.has(k) if is_chain else lab.operation == k
		var locked = reason != ""
		var op = DataDB.get_lab_op(k)
		var bg = ThemeStyler.COLOR_ACCENT if on else ThemeStyler.COLOR_BG_SOLID
		var bd = ThemeStyler.COLOR_ACCENT if on else ThemeStyler.COLOR_BORDER
		b.add_theme_stylebox_override("normal", _box(8, bg, bd, 8))
		b.add_theme_stylebox_override("hover", _box(8, ThemeStyler.COLOR_ACCENT_HOVER if on else ThemeStyler.COLOR_CARD_HOVER, ThemeStyler.COLOR_ACCENT, 8))
		b.add_theme_stylebox_override("pressed", _box(8, ThemeStyler.COLOR_ACCENT_PRESSED, ThemeStyler.COLOR_ACCENT_PRESSED, 8))
		var fc = ThemeStyler.COLOR_TEXT_ON_ACCENT if on else (ThemeStyler.COLOR_TEXT_MUTED if locked else ThemeStyler.COLOR_TEXT_PRIMARY)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, fc)
		b.icon = ItemIconManager.load_texture("res://assets/icons/ui_lock.svg") if locked else _op_icon(k)
		b.modulate = Color(1, 1, 1, 0.6) if locked else Color.WHITE
		var badge: Label = op_badges[k]
		badge.text = reason.replace("需要研发", "需 ").replace("需要", "需 ") if locked else ("✓" if is_chain and on else "")
		badge.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_ON_ACCENT if on else ThemeStyler.COLOR_TEXT_MUTED)
		var tip = str(op.get("description", ""))
		if locked:
			tip += "\n" + reason
		b.tooltip_text = tip
	hidden_ops_label.text = "还有 %d 种操作在后续时代解锁" % hidden if hidden > 0 else ""
	for gh in group_heads:
		var any := false
		for k in gh[1]:
			if op_tiles[k].visible:
				any = true
		gh[0].visible = any

func _refresh_status() -> void:
	var v = lab.vessel
	var op = DataDB.get_lab_op(lab.operation)
	if lab.operation == "":
		stage_icon.texture = ItemIconManager.load_texture("res://assets/icons/lab.svg")
		stage_title.text = "选择一种操作"
		if lab.is_furnace():
			var top_c = int(GameState.sim.FURNACE_MAX_TEMP.get(lab.furnace_type, 1100.0) - 273.15)
			stage_desc.text = "炉膛就是容器，不耗耐久，最高约 %d ℃。左侧选一种加热操作，放入原料和燃料后点火" % top_c
		else:
			stage_desc.text = "左侧挑选操作，右侧先放一件容器再放入试剂。焙烧、干馏等要点火，电解要接电池。"
	else:
		stage_icon.texture = _op_icon(lab.operation)
		var chains: Array = []
		for c in lab.chain_ops:
			chains.append(DataDB.get_lab_op(c).get("name", c))
		stage_title.text = op.get("name", "") + ("  +  " + " + ".join(chains) if not chains.is_empty() else "")
		stage_desc.text = op.get("description", "")
	temp_label.text = "%d ℃" % int(round(v.temperature - 273.15))

	if lab.needs_fire():
		energy_title.text = "炉火"
		if lab.fire_lit:
			energy_status.text = "%s燃烧中 · 火焰 %d ℃ · 还能烧 %d 秒" % [_name(lab.cur_fuel), int(lab.flame_temp() - 273.15), int(ceil(lab.fuel_seconds()))]
		elif lab.fuel_seconds() > 0.0:
			energy_status.text = "已放燃料 %d 秒 · 点火需要火种或燧石" % int(ceil(lab.fuel_seconds()))
		else:
			energy_status.text = "点击下方燃料放入炉膛。燃料越好，火焰越热"
		btn_fire.visible = true
		btn_fire.text = "熄火" if lab.fire_lit else "点火"
		btn_fire.disabled = not lab.fire_lit and (lab.fuel_seconds() <= 0.0 or lab.container == "" or not lab.container_can_heat())
		if not lab.fire_lit and lab.container != "" and not lab.container_can_heat():
			energy_status.text = "%s不耐热，换陶罐、坩埚等耐热容器才能点火" % _name(lab.container)
	elif lab.needs_power():
		energy_title.text = "电源"
		btn_fire.visible = false
		if lab.power_left > 0.0:
			energy_status.text = "%s · %.0f V · 剩余 %d 秒" % [_name(lab.power_key), lab.voltage(), int(ceil(lab.power_left))]
		else:
			energy_status.text = "接入一块电池开始通电，电量用完电池报废"
	else:
		energy_title.text = "常温"
		btn_fire.visible = lab.fire_lit
		btn_fire.text = "熄火"
		energy_status.text = "此操作不需要加热或通电" if lab.operation != "" else ("炉内的操作都需要点火" if lab.is_furnace() else "还没有选择操作")

	var d = lab.diagnose()
	var styles = {
		"empty": ["待备料", ThemeStyler.COLOR_TEXT_SECONDARY, ThemeStyler.COLOR_CARD],
		"reacting": ["反应中", ThemeStyler.COLOR_SUCCESS, ThemeStyler.TINT_SUCCESS],
		"blocked": ["条件不足", ThemeStyler.COLOR_WARNING, ThemeStyler.TINT_WARNING],
		"partial": ["缺少原料", ThemeStyler.COLOR_INFO, ThemeStyler.TINT_INFO],
		"unknown": ["无反应", ThemeStyler.COLOR_TEXT_MUTED, ThemeStyler.COLOR_CARD],
		"inert": ["无反应", ThemeStyler.COLOR_TEXT_MUTED, ThemeStyler.COLOR_CARD],
	}
	var st = styles.get(d["state"], styles["inert"])
	var text: String = d["text"]
	if lab.operation == "" and d["state"] != "empty" and d["state"] != "reacting":
		text = "先在左侧选择一种操作"
	sensor_badge.text = st[0]
	sensor_badge.add_theme_color_override("font_color", st[1])
	sensor_text.text = text
	sensor_bar.visible = d["state"] == "reacting"
	sensor_bar.value = float(d.get("progress", 0.0))
	var box = _box(10, st[2], st[1], 10)
	box.border_width_left = 4
	sensor_card.add_theme_stylebox_override("panel", box)
	btn_retrieve.disabled = v.components.is_empty()

func _refresh_energy_items() -> void:
	for c in energy_items.get_children():
		c.queue_free()
	if lab.needs_fire():
		var opts = lab.fuel_options()
		if opts.is_empty():
			energy_items.add_child(_label("行囊里没有燃料（枯树枝、原木、木炭…）", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_WARNING))
		for k in opts:
			var info = LabBench.fuel_info(k)
			var s = _slot(k, GameState.inventory.get_count(k))
			s.custom_minimum_size = Vector2(46, 46)
			s.tooltip_text = "%s：燃烧 %d 秒，在这里最高 %d ℃" % [_name(k), int(info["burn_time"]), int(lab.fuel_flame_temp(k) - 273.15)]
			s.pressed.connect(func():
				if lab.add_fuel(k):
					_add_log("放入燃料 %s" % _name(k))
			)
			energy_items.add_child(s)
	elif lab.needs_power():
		var opts = lab.battery_options()
		if opts.is_empty():
			energy_items.add_child(_label("行囊里没有电池", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_WARNING))
		for k in opts:
			var info = LabBench.battery_info(k)
			var s = _slot(k, GameState.inventory.get_count(k))
			s.custom_minimum_size = Vector2(46, 46)
			s.tooltip_text = "%s：%.0f V，可通电 %d 秒" % [_name(k), info["voltage"], int(info["power_time"])]
			s.disabled = lab.power_left > 0.0
			s.pressed.connect(func():
				if lab.connect_power(k):
					_add_log("接入 %s（%.0f V）" % [_name(k), info["voltage"]])
					_refresh_all()
			)
			energy_items.add_child(s)

# 容器格子：右下角为剩余耐久，选中为铜色描边；不耐热的容器在加热类操作下半透明
func _refresh_containers() -> void:
	for c in container_slots.get_children():
		c.queue_free()
	if lab.is_furnace():
		return
	var opts = lab.container_options()
	if opts.is_empty():
		container_slots.add_child(_label("行囊里没有容器。在制作栏 [T] 做一个木桶、陶罐或坩埚", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_WARNING))
		return
	for k in opts:
		var on = lab.container == k
		var heat = LabBench.can_heat(k)
		var s = _slot(k, 0, ThemeStyler.COLOR_ACCENT if on else Color(0, 0, 0, 0))
		s.custom_minimum_size = Vector2(52, 52)
		var left = lab.durability_left(k)
		var c = _label(str(left), ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_PRIMARY)
		c.add_theme_font_override("font", ThemeStyler.get_font_mono())
		c.add_theme_constant_override("outline_size", 4)
		c.add_theme_color_override("font_outline_color", ThemeStyler.COLOR_BG_SOLID)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		c.offset_left = -40; c.offset_top = -18; c.offset_right = -3; c.offset_bottom = -1
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(c)
		s.tooltip_text = "%s ×%d · 剩余耐久 %d%s%s" % [_name(k), GameState.inventory.get_count(k), left,
			"" if heat else " · 不耐热，不能加热", "\n点击撤下" if on else "\n点击放上实验台"]
		if lab.needs_fire() and not heat:
			s.modulate = Color(1, 1, 1, 0.5)
		s.pressed.connect(func():
			if lab.set_container("" if lab.container == k else k):
				_add_log("撤下%s" % _name(k) if lab.container == "" else "放上%s" % _name(k))
			_refresh_all()
		)
		container_slots.add_child(s)

func _refresh_reagents() -> void:
	for c in reagent_grid.get_children():
		c.queue_free()
	var keys = GameState.inventory.items.keys()
	keys.sort()
	var shown := 0
	for k in keys:
		var n = GameState.inventory.get_count(k)
		if n <= 0:
			continue
		var cat = str(DataDB.get_item(k).get("category", ""))
		if not (cat in REAGENT_CATEGORIES or DataDB.is_pure_element(k) > 0) or LabBench.is_container(k):
			continue
		if not _match(reagent_search.text, [_name(k), k]):
			continue
		var s = _slot(k, n)
		s.tooltip_text = "%s ×%d（点击放入 1 份）" % [_name(k), n]
		s.pressed.connect(func(): add_reagent(k, 1.0))
		reagent_grid.add_child(s)
		shown += 1
	# 补足空格，保持格子网格完整
	if shown == 0 and reagent_search.text.strip_edges() != "":
		var none = _label("行囊里没有匹配「%s」的试剂" % reagent_search.text.strip_edges(), ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED)
		reagent_grid.add_child(none)
		return
	for i in range(max(0, 15 - shown)):
		var e = Panel.new()
		e.custom_minimum_size = Vector2(SLOT, SLOT)
		e.add_theme_stylebox_override("panel", _box(8, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER, 0))
		e.modulate = Color(1, 1, 1, 0.5)
		reagent_grid.add_child(e)

func _refresh_flask() -> void:
	for c in flask_slots.get_children():
		c.queue_free()
	var v = lab.vessel
	flask_title.text = "%s内" % _name(lab.container) if lab.container != "" else "还没放容器"
	if v.components.is_empty():
		flask_slots.add_child(_label("空", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED))
		return
	for k in v.components.keys():
		var amt = float(v.components[k])
		var produced = lab.produced.has(k)
		var s = _slot(k, 0, ThemeStyler.COLOR_SUCCESS if produced else Color(0, 0, 0, 0))
		s.custom_minimum_size = Vector2(48, 48)
		s.tooltip_text = "%s %s%s\n左键取回 1 份，右键全部取回" % [_name(k), _fmt_amount(amt), "（产物）" if produced else ""]
		s.set_meta("item_key", k)
		s.pressed.connect(func(): _retrieve_item(k, 1))
		var c = _label(_fmt_amount(amt).trim_prefix("×"), ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_SUCCESS if produced else ThemeStyler.COLOR_TEXT_PRIMARY)
		c.add_theme_font_override("font", ThemeStyler.get_font_mono())
		c.add_theme_constant_override("outline_size", 4)
		c.add_theme_color_override("font_outline_color", ThemeStyler.COLOR_BG_SOLID)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		c.offset_left = -40; c.offset_top = -18; c.offset_right = -3; c.offset_bottom = -1
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(c)
		flask_slots.add_child(s)

func _fmt_amount(a: float) -> String:
	return "×%d" % int(round(a)) if is_equal_approx(a, round(a)) else "×%.1f" % a

func _refresh_notes() -> void:
	for c in notes_list.get_children():
		c.queue_free()
	var known = ThemeStyler.COLOR_ACCENT.to_html(false)
	var opc = ThemeStyler.COLOR_INFO.to_html(false)
	var unk = ThemeStyler.COLOR_TEXT_MUTED.to_html(false)
	var pending: Array = []
	var done: Array = []
	var book = _book()
	for i in range(book.fragments.size() - 1, -1, -1): # 新得到的在前，已确证的排在后面
		var k = book.fragments[i]
		(done if book.proven.has(k) else pending).append(k)
	var shown := 0
	for f_key in pending + done:
		var f = DataDB.get_formula(f_key)
		if f.is_empty():
			continue
		if not _match(notes_search.text, _note_search_texts(f, book)):
			continue
		shown += 1
		var proven = book.proven.has(f_key)
		var card = PanelContainer.new()
		var box = _box(10, ThemeStyler.TINT_SUCCESS if proven else ThemeStyler.COLOR_BG_SOLID, ThemeStyler.COLOR_SUCCESS if proven else ThemeStyler.COLOR_BORDER, 10)
		box.border_width_left = 4
		box.border_color = ThemeStyler.COLOR_SUCCESS if proven else ThemeStyler.COLOR_ACCENT
		card.add_theme_stylebox_override("panel", box)
		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		card.add_child(vb)
		var head = HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var op_key = ChemistrySolver.formula_operation(f)
		var ic = TextureRect.new()
		ic.custom_minimum_size = Vector2(20, 20)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = _op_icon(op_key)
		head.add_child(ic)
		var title = _label(f.get("name", f_key), ThemeStyler.FONT_BODY, ThemeStyler.COLOR_TEXT_PRIMARY)
		title.add_theme_font_override("font", ThemeStyler.get_font_sans_bold())
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		head.add_child(title)
		head.add_child(_label("已确证" if proven else "残片", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_SUCCESS if proven else ThemeStyler.COLOR_ACCENT))
		vb.add_child(head)
		var tags: Array = [DataDB.get_lab_op(op_key).get("name", "")]
		for c in LabBench.chain_needed(f):
			tags.append("+" + DataDB.get_lab_op(c).get("name", c))
		var t = ChemistrySolver.formula_min_temp(f)
		if t > 0.0:
			tags.append("%d ℃ 以上" % int(t - 273.15))
		var volt = ChemistrySolver.formula_min_voltage(f)
		if volt > 0.0:
			tags.append("%.0f V" % volt)
		vb.add_child(_label(" · ".join(tags), ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_SECONDARY))
		var txt = RichTextLabel.new()
		txt.bbcode_enabled = true
		txt.fit_content = true
		txt.add_theme_font_size_override("normal_font_size", ThemeStyler.FONT_CAPTION)
		txt.text = lab.fragment_text(f_key, known, opc, unk)
		vb.add_child(txt)
		# 容器、操作、原料都满足才能按手稿备料，否则写明还缺什么
		var missing = lab.fragment_missing(f_key)
		var foot = HBoxContainer.new()
		foot.add_theme_constant_override("separation", 8)
		var lack = _label("还缺：" + "、".join(missing) if not missing.is_empty() else "原料齐全", ThemeStyler.FONT_CAPTION,
			ThemeStyler.COLOR_WARNING if not missing.is_empty() else ThemeStyler.COLOR_SUCCESS)
		lack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		foot.add_child(lack)
		var btn = Button.new()
		btn.text = "按手稿备料"
		btn.custom_minimum_size = Vector2(110, 28)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
		_style_primary(btn)
		btn.disabled = not missing.is_empty()
		btn.tooltip_text = "还缺：" + "、".join(missing) if not missing.is_empty() else "换上容器、切换操作并放入原料"
		btn.pressed.connect(func(): _prepare(f_key))
		foot.add_child(btn)
		vb.add_child(foot)
		notes_list.add_child(card)
	if shown == 0:
		var t = "没有匹配「%s」的手稿" % notes_search.text.strip_edges() if notes_search.text.strip_edges() != "" else "还没有手稿"
		notes_list.add_child(_label(t, ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED))

# 手稿可搜索的文字：配方名、操作名，以及见过的原料 / 产物名 (没见过的不参与搜索，避免剧透)
func _note_search_texts(f: Dictionary, book) -> Array:
	var texts: Array = [f.get("name", ""), DataDB.get_lab_op(ChemistrySolver.formula_operation(f)).get("name", "")]
	var proven = book.proven.has(f.get("key", ""))
	for req in f.get("required_items", []):
		for k in (req["key"] if req["key"] is Array else [req["key"]]):
			if proven or book.seen_items.has(k):
				texts.append(_name(k))
	for p in f.get("products", []):
		if proven or book.seen_items.has(p["key"]):
			texts.append(_name(p["key"]))
	return texts

# ---------------------------------------------------------------- 命令

func _on_op_pressed(key: String) -> void:
	var target = "" if lab.operation == key else key
	if lab.set_operation(target) and target != "":
		_add_log("操作：%s" % DataDB.get_lab_op(key).get("name", key))
	_refresh_all()

func _on_chain_pressed(key: String) -> void:
	var was_on = lab.chain_ops.has(key)
	if lab.toggle_chain(key):
		_add_log("%s%s" % ["取消" if was_on else "追加 ", DataDB.get_lab_op(key).get("name", key)])
	_refresh_all()

func _on_fire_pressed() -> void:
	if lab.fire_lit:
		lab.extinguish()
		_add_log("熄火")
	elif lab.ignite():
		_add_log("点火，%s开始燃烧" % _name(lab.cur_fuel))
	_refresh_status()

func add_reagent(item_key: String, amount: float) -> void:
	if not lab.add_reagent(item_key, int(amount)):
		if lab.container != "":
			GameState.post_notification("行囊里没有%s" % _name(item_key), Color(1, 0.4, 0.4))
		return
	_add_log("放入 %s ×%d" % [_name(item_key), int(amount)])
	_refresh_flask()
	_refresh_status()

func _on_retrieve_pressed() -> void:
	var got = lab.retrieve_all()
	if got.is_empty():
		_add_log("烧瓶里的东西太少，没有可取回的")
	else:
		var parts: Array = []
		for k in got.keys():
			parts.append("%s ×%d" % [_name(k), got[k]])
		_add_log("取回 " + "、".join(parts))
	_refresh_all()

# 容器内某种物品取回 n 份 (n < 0 为全部)
func _retrieve_item(key: String, n: int) -> void:
	var got = lab.retrieve(key, n)
	if got > 0:
		_add_log("取回 %s ×%d" % [_name(key), got])
	else:
		_add_log("%s不足一份，已倒掉" % _name(key))
	_refresh_all()

func _flask_key_at(screen_pos: Vector2) -> String:
	if not view_flask.is_visible_in_tree():
		return ""
	for s in flask_slots.get_children():
		if s.has_meta("item_key") and s.get_global_rect().has_point(screen_pos):
			return str(s.get_meta("item_key"))
	return ""

func _prepare(f_key: String) -> void:
	var missing = lab.prepare_from_fragment(f_key)
	if missing.is_empty():
		_add_log("已按手稿「%s」备好原料" % DataDB.get_formula(f_key).get("name", f_key))
		_switch_tab(0)
	else:
		GameState.post_notification("还缺：%s" % "、".join(missing), Color(1.0, 0.6, 0.3))
	_refresh_all()

func _on_reacted(f_key: String, products: Array, lost: Array) -> void:
	if not visible:
		return
	var names: Array = []
	for p in products:
		names.append(_name(p))
	var f = DataDB.get_formula(f_key)
	var msg = "%s：生成 %s" % [f.get("name", "反应"), "、".join(names) if not names.is_empty() else "无"]
	if not lost.is_empty():
		var ln: Array = []
		for p in lost:
			ln.append(_name(p))
		msg += "（%s逸散，追加集气或冷凝可收集）" % "、".join(ln)
	_add_log(msg)
	_refresh_flask()

func _add_log(msg: String) -> void:
	log_label.append_text("· %s\n" % msg)

func _name(k: String) -> String:
	return DataDB.get_item(k).get("name", k)

# ---------------------------------------------------------------- 绘制

func _solution_color() -> Color:
	var v = lab.vessel
	var best := ""
	var best_amt := 0.0
	for k in v.components.keys():
		if float(v.components[k]) > best_amt:
			best_amt = float(v.components[k])
			best = k
	var palette = {
		"copper": Color(0.80, 0.48, 0.30), "charcoal": Color(0.22, 0.22, 0.24), "malachite": Color(0.18, 0.62, 0.45),
		"water": Color(0.35, 0.60, 0.85), "wood": Color(0.62, 0.45, 0.28), "iron": Color(0.45, 0.45, 0.48),
		"sulfur": Color(0.90, 0.80, 0.25), "rock_salt": Color(0.88, 0.88, 0.85), "clay": Color(0.66, 0.50, 0.38),
	}
	var c: Color = palette.get(best, Color.from_hsv(float(best.hash() % 360) / 360.0, 0.35, 0.70))
	c.a = 0.78
	return ThemeStyler.adapt(c)

# 容器简笔图：左右对称的半宽轮廓 Vector2(半宽, 距底高度)，自上而下排列；没登记的容器画成烧瓶
const CONTAINER_PROFILES := {
	"flask": [Vector2(16, 150), Vector2(16, 86), Vector2(66, 0)],
	"wooden_bucket": [Vector2(58, 104), Vector2(47, 0)],
	"clay_pot": [Vector2(26, 120), Vector2(22, 110), Vector2(36, 96), Vector2(55, 72), Vector2(60, 46), Vector2(52, 18), Vector2(34, 0)],
	"crucible": [Vector2(46, 86), Vector2(38, 30), Vector2(26, 0)],
	"kiln": [Vector2(22, 128), Vector2(22, 116), Vector2(46, 100), Vector2(60, 70), Vector2(64, 0)],
	"fire_pit": [Vector2(70, 34), Vector2(66, 0)],
	"furnace": [Vector2(26, 132), Vector2(26, 120), Vector2(50, 104), Vector2(66, 72), Vector2(70, 0)],
	"blast_furnace": [Vector2(30, 150), Vector2(30, 136), Vector2(50, 104), Vector2(56, 40), Vector2(46, 0)],
	"gas_bottle": [Vector2(20, 124), Vector2(20, 110), Vector2(46, 98), Vector2(50, 88), Vector2(50, 0)],
	"beaker": [Vector2(48, 128), Vector2(48, 6), Vector2(44, 0)],
	"test_tube": [Vector2(13, 168), Vector2(13, 16), Vector2(9, 5), Vector2(0, 0)],
	"iron_tank": [Vector2(56, 112), Vector2(56, 0)],
	"distilling_flask": [Vector2(12, 152), Vector2(12, 86), Vector2(28, 80), Vector2(44, 70), Vector2(53, 52), Vector2(52, 32), Vector2(42, 14), Vector2(24, 3), Vector2(0, 0)],
	"evaporating_dish": [Vector2(72, 36), Vector2(58, 16), Vector2(32, 0)],
	"sealed_tube": [Vector2(12, 156), Vector2(12, 12), Vector2(8, 3), Vector2(0, 0)],
	"reaction_kettle": [Vector2(54, 116), Vector2(54, 24), Vector2(42, 6), Vector2(22, 0)],
	"autoclave": [Vector2(42, 124), Vector2(42, 0)],
	"graphite_electrolytic_cell": [Vector2(68, 92), Vector2(68, 0)],
	"fractionating_column": [Vector2(9, 170), Vector2(9, 120), Vector2(16, 112), Vector2(9, 104), Vector2(16, 96), Vector2(9, 88), Vector2(12, 80), Vector2(42, 62), Vector2(48, 40), Vector2(38, 14), Vector2(18, 2), Vector2(0, 0)],
	"sieve": [Vector2(68, 40), Vector2(64, 0)],
	"reactor_vessel": [Vector2(18, 150), Vector2(44, 138), Vector2(58, 112), Vector2(60, 0)],
}
# 顶部封闭的容器 (画盖子)，以及画玻璃高光的容器
const CLOSED_CONTAINERS := ["sealed_tube", "autoclave", "reaction_kettle", "reactor_vessel"]
const GLASS_CONTAINERS := ["flask", "beaker", "test_tube", "gas_bottle", "distilling_flask", "sealed_tube", "fractionating_column"]

func _container_profile(key: String) -> Array:
	return CONTAINER_PROFILES.get(key, CONTAINER_PROFILES["flask"])

# 轮廓在某高度处的半宽
func _profile_width(prof: Array, h: float) -> float:
	for i in range(prof.size() - 1):
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		if h <= a.y and h >= b.y:
			return lerpf(b.x, a.x, 0.0 if is_equal_approx(a.y, b.y) else (h - b.y) / (a.y - b.y))
	return prof[0].x if h > prof[0].y else prof[-1].x

func _on_vessel_draw() -> void:
	var sz = vessel_draw.size
	var cx = sz.x * 0.40
	var bot = sz.y - 56.0
	var ink = ThemeStyler.COLOR_TEXT_SECONDARY
	var v = lab.vessel

	# 实验台台面
	vessel_draw.draw_rect(Rect2(16, sz.y - 10, sz.x - 32, 4), ThemeStyler.COLOR_BORDER, true)

	# 炉火光晕
	if lab.fire_lit:
		var heat = clampf((lab.flame_temp() - 873.0) / 900.0, 0.0, 1.0)
		for i in range(4):
			var r = 70.0 + i * 22.0
			vessel_draw.draw_circle(Vector2(cx, bot + 20), r, Color(1.0, 0.55 + heat * 0.3, 0.2, 0.05))

	# 没放容器：只留台面与炉膛，中间给一行提示
	var mouth_y: float = bot - 60.0
	if lab.container == "":
		var font = ThemeStyler.get_font_sans()
		vessel_draw.draw_string(font, Vector2(cx - 120, bot - 50), "在右侧选择一件容器", HORIZONTAL_ALIGNMENT_CENTER, 240, ThemeStyler.FONT_BODY, ThemeStyler.COLOR_TEXT_MUTED)
	else:
		mouth_y = _draw_container(lab.container, cx, bot, ink)

	# 追加操作：集气导管与集气瓶 / 冷凝管
	if lab.container != "" and not lab.chain_ops.is_empty():
		var tube = PackedVector2Array([Vector2(cx + 6, mouth_y + 4), Vector2(cx + 6, mouth_y - 4), Vector2(cx + 110, mouth_y - 4), Vector2(cx + 110, bot - 40)])
		vessel_draw.draw_polyline(tube, ink, 2.0)
		var jar = Rect2(cx + 88, bot - 60, 44, 60)
		vessel_draw.draw_rect(jar, ThemeStyler.COLOR_INFO.lerp(Color(1, 1, 1, 0), 0.75), true)
		vessel_draw.draw_rect(jar, ink, false, 2.0)
		if v.active_formula != "":
			var ph = fmod(bubble_phase * 0.3, 1.0)
			vessel_draw.draw_arc(Vector2(cx + 110, bot - 40 - ph * 16), 3.0, 0, TAU, 10, ThemeStyler.COLOR_INFO, 1.4)

	# 炉膛、燃料与火焰
	vessel_draw.draw_line(Vector2(cx - 74, bot + 4), Vector2(cx + 74, bot + 4), ink, 3.0)
	if lab.needs_fire() or lab.fire_lit:
		var grate_y = bot + 40
		vessel_draw.draw_line(Vector2(cx - 60, bot + 4), Vector2(cx - 60, grate_y + 8), ink, 2.0)
		vessel_draw.draw_line(Vector2(cx + 60, bot + 4), Vector2(cx + 60, grate_y + 8), ink, 2.0)
		var fuel_n = min(5, lab.fuel_queue.size() + (1 if lab.cur_fuel_left > 0.0 else 0))
		for i in range(fuel_n):
			vessel_draw.draw_rect(Rect2(cx - 46 + i * 19, grate_y, 16, 8), ThemeStyler.adapt(Color(0.32, 0.26, 0.22)), true)
		if lab.fire_lit:
			var heat = clampf((lab.flame_temp() - 873.0) / 900.0, 0.0, 1.0)
			var outer = Color(0.92, 0.42, 0.14).lerp(Color(1.0, 0.82, 0.40), heat)
			for i in range(4):
				var fx = cx - 33 + i * 22
				var h = 26.0 + sin(bubble_phase * 1.3 + i * 2.0) * 5.0 + heat * 8.0
				vessel_draw.draw_colored_polygon(PackedVector2Array([Vector2(fx - 10, grate_y), Vector2(fx + sin(bubble_phase + i) * 3.0, grate_y - h), Vector2(fx + 10, grate_y)]), outer)
				vessel_draw.draw_colored_polygon(PackedVector2Array([Vector2(fx - 4, grate_y), Vector2(fx, grate_y - h * 0.55), Vector2(fx + 4, grate_y)]), Color(1.0, 0.96, 0.78))
	# 电极与电弧
	if lab.needs_power() and lab.container != "":
		var live = lab.power_left > 0.0
		var ec = ThemeStyler.COLOR_INFO if live else ink
		var ex = clampf(_container_profile(lab.container)[0].x - 5.0, 4.0, 18.0)
		for dx in [-ex, ex]:
			vessel_draw.draw_line(Vector2(cx + dx, mouth_y - 6), Vector2(cx + dx, bot - 14), ec, 4.0)
		if live:
			var y = bot - 36 + sin(bubble_phase) * 8.0
			vessel_draw.draw_polyline(PackedVector2Array([Vector2(cx - ex, y), Vector2(cx - ex * 0.33, y - 7), Vector2(cx + ex * 0.28, y + 5), Vector2(cx + ex, y - 2)]), ec, 2.0)

	# 温度计：当前温度、火焰可达温度、手稿配方的目标温度
	var tx = sz.x - 54.0
	var top = 16.0
	var tb = sz.y - 30.0
	var font = ThemeStyler.get_font_mono()
	vessel_draw.draw_rect(Rect2(tx - 6, top, 12, tb - top), ThemeStyler.COLOR_CARD, true)
	vessel_draw.draw_rect(Rect2(tx - 6, top, 12, tb - top), ink, false, 1.5)
	var span = tb - top
	var cy = tb - clampf((v.temperature - 273.15) / THERMO_MAX_C, 0.0, 1.0) * span
	vessel_draw.draw_rect(Rect2(tx - 3, cy, 6, tb - cy), ThemeStyler.COLOR_DANGER, true)
	vessel_draw.draw_circle(Vector2(tx, tb + 8), 9.0, ThemeStyler.COLOR_DANGER)
	for c in [0, 400, 800, 1200, 1600]:
		var y = tb - c / THERMO_MAX_C * span
		vessel_draw.draw_line(Vector2(tx + 6, y), Vector2(tx + 12, y), ink, 1.0)
		vessel_draw.draw_string(font, Vector2(tx + 14, y + 4), str(c), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ThemeStyler.COLOR_TEXT_MUTED)
	if lab.fire_lit:
		var fy = tb - clampf((lab.flame_temp() - 273.15) / THERMO_MAX_C, 0.0, 1.0) * span
		vessel_draw.draw_colored_polygon(PackedVector2Array([Vector2(tx - 8, fy), Vector2(tx - 16, fy - 5), Vector2(tx - 16, fy + 5)]), ThemeStyler.COLOR_ACCENT)

# 画出容器 (液体、气泡、轮廓与细节)，返回容器口的 y 坐标
func _draw_container(key: String, cx: float, bot: float, ink: Color) -> float:
	var v = lab.vessel
	var prof = _container_profile(key)
	var height: float = prof[0].y
	var k = minf(1.0, (bot - 18.0) / height) # 画布不够高时整体缩小
	var top = bot - height * k
	var pt = func(w: float, h: float, side: float) -> Vector2: return Vector2(cx + side * w * k, bot - h * k)

	# 液体：液面高度随内容物多少变化
	if not v.components.is_empty():
		var level = height * clampf(0.22 + v.total_moles() * 0.05, 0.22, 0.6)
		var fill := PackedVector2Array()
		for i in range(prof.size() - 1, -1, -1):
			if prof[i].y < level:
				fill.append(pt.call(prof[i].x, prof[i].y, -1.0))
		var lw = _profile_width(prof, level)
		fill.append(pt.call(lw, level, -1.0))
		fill.append(pt.call(lw, level, 1.0))
		for i in range(prof.size()):
			if prof[i].y < level and prof[i].x > 0.0:
				fill.append(pt.call(prof[i].x, prof[i].y, 1.0))
		vessel_draw.draw_colored_polygon(fill, _solution_color())
		var wave: PackedVector2Array = []
		for i in range(17):
			var x = lerpf(cx - lw * k, cx + lw * k, i / 16.0)
			wave.append(Vector2(x, bot - level * k + sin(bubble_phase + i * 0.8) * 1.5))
		vessel_draw.draw_polyline(wave, Color(1, 1, 1, 0.5), 1.5)
		if v.active_formula != "":
			var bw = _profile_width(prof, 8.0) * k * 0.6
			for i in range(6):
				var ph = fmod(bubble_phase * 0.25 + i * 0.17, 1.0)
				var p = Vector2(cx + lerpf(-bw, bw, i / 5.0) + sin(bubble_phase + i) * 2.0, bot - 6 - ph * (level * k - 8.0))
				vessel_draw.draw_arc(p, 2.5 + i % 2, 0, TAU, 12, ThemeStyler.adapt(Color(1, 1, 1, 0.85 * (1.0 - ph))), 1.4)

	# 轮廓：左侧自上而下，再沿右侧回到顶部
	var outline := PackedVector2Array()
	for q in prof:
		outline.append(pt.call(q.x, q.y, -1.0))
	# 尖底的最低点 (半宽 0) 只出现一次；平底由左右两个底角相连成底边
	for i in range(prof.size() - 1, -1, -1):
		if prof[i].x > 0.0:
			outline.append(pt.call(prof[i].x, prof[i].y, 1.0))
	vessel_draw.draw_polyline(outline, ink, 2.5, true)
	var mw = prof[0].x * k
	if CLOSED_CONTAINERS.has(key):
		vessel_draw.draw_line(Vector2(cx - mw - 4, top), Vector2(cx + mw + 4, top), ink, 4.0)
	elif mw < 30.0:
		vessel_draw.draw_line(Vector2(cx - mw - 6, top), Vector2(cx + mw + 6, top), ink, 2.5) # 瓶口外沿
	if GLASS_CONTAINERS.has(key):
		var h1 = height * 0.18
		var h2 = minf(height * 0.5, height - 10.0)
		vessel_draw.draw_line(pt.call(_profile_width(prof, h1) * 0.72, h1, -1.0), pt.call(_profile_width(prof, h2) * 0.72, h2, -1.0), Color(1, 1, 1, 0.45), 3.0)
	_draw_container_details(key, cx, bot, top, k, ink)
	return top

# 各容器的识别细节：箍、提手、刻度、铆钉、搅拌桨等
func _draw_container_details(key: String, cx: float, bot: float, top: float, k: float, ink: Color) -> void:
	var prof = _container_profile(key)
	var at = func(h: float) -> float: return _profile_width(prof, h) * k
	var y = func(h: float) -> float: return bot - h * k
	match key:
		"wooden_bucket":
			for h in [18.0, 84.0]:
				vessel_draw.draw_line(Vector2(cx - at.call(h), y.call(h)), Vector2(cx + at.call(h), y.call(h)), ink, 3.0)
			for i in range(1, 5):
				var t = i / 5.0
				vessel_draw.draw_line(Vector2(cx + lerpf(-at.call(100.0), at.call(100.0), t), y.call(100.0)), Vector2(cx + lerpf(-at.call(4.0), at.call(4.0), t), y.call(4.0)), ink.lerp(Color(1, 1, 1, 0), 0.6), 1.0)
			vessel_draw.draw_arc(Vector2(cx, top), at.call(104.0) * 0.9, PI, TAU, 24, ink, 2.0)
		"clay_pot", "kiln":
			if key == "kiln":
				vessel_draw.draw_arc(Vector2(cx, y.call(0.0)), 18.0 * k, PI, TAU, 16, ink, 2.0)
				for h in [24.0, 48.0, 72.0]:
					vessel_draw.draw_line(Vector2(cx - at.call(h), y.call(h)), Vector2(cx + at.call(h), y.call(h)), ink.lerp(Color(1, 1, 1, 0), 0.6), 1.0)
			else:
				var hh = 60.0
				var pts: PackedVector2Array = []
				for i in range(13):
					var x = lerpf(-at.call(hh), at.call(hh), i / 12.0)
					pts.append(Vector2(cx + x, y.call(hh) + sin(i * 1.4) * 3.0))
				vessel_draw.draw_polyline(pts, ink.lerp(Color(1, 1, 1, 0), 0.5), 1.5)
		"beaker", "test_tube", "gas_bottle":
			var steps = 4 if key == "beaker" else 3
			var mh: float = prof[0].y
			for i in range(1, steps + 1):
				var h = mh * 0.82 * i / (steps + 1)
				var w = at.call(h)
				vessel_draw.draw_line(Vector2(cx + w - 10.0 * k, y.call(h)), Vector2(cx + w, y.call(h)), ink, 1.2)
			if key == "beaker":
				vessel_draw.draw_line(Vector2(cx - at.call(128.0), top), Vector2(cx - at.call(128.0) - 8, top - 5), ink, 2.5) # 杯嘴
		"iron_tank", "autoclave", "graphite_electrolytic_cell":
			var w = at.call(10.0)
			for h in [10.0, prof[0].y - 10.0]:
				for i in range(5):
					vessel_draw.draw_circle(Vector2(cx + lerpf(-w + 8, w - 8, i / 4.0), y.call(h)), 2.2, ink)
			if key == "autoclave":
				vessel_draw.draw_circle(Vector2(cx + 20 * k, top - 12), 8.0, ThemeStyler.COLOR_BG_SOLID)
				vessel_draw.draw_arc(Vector2(cx + 20 * k, top - 12), 8.0, 0, TAU, 16, ink, 2.0)
				vessel_draw.draw_line(Vector2(cx + 20 * k, top - 12), Vector2(cx + 20 * k + 5, top - 16), ThemeStyler.COLOR_DANGER, 1.5)
				vessel_draw.draw_line(Vector2(cx + 20 * k, top), Vector2(cx + 20 * k, top - 4), ink, 2.0)
			elif key == "graphite_electrolytic_cell":
				for dx in [-0.5, 0.5]:
					vessel_draw.draw_rect(Rect2(cx + dx * at.call(40.0) - 5, top - 14, 10, 70 * k), ThemeStyler.adapt(Color(0.25, 0.25, 0.27)), true)
		"reaction_kettle":
			vessel_draw.draw_rect(Rect2(cx - 12, top - 22, 24, 18), ink, false, 2.0)
			vessel_draw.draw_line(Vector2(cx, top - 4), Vector2(cx, y.call(18.0)), ink, 2.0)
			var r = sin(bubble_phase * 0.8) * 16.0 * k
			vessel_draw.draw_line(Vector2(cx - absf(r) - 6, y.call(18.0)), Vector2(cx + absf(r) + 6, y.call(18.0)), ink, 3.0)
		"distilling_flask":
			vessel_draw.draw_line(Vector2(cx + at.call(120.0), y.call(120.0)), Vector2(cx + 54 * k, y.call(104.0)), ink, 2.5) # 支管
		"evaporating_dish":
			vessel_draw.draw_line(Vector2(cx - at.call(36.0) - 6, top), Vector2(cx - at.call(36.0) + 4, top + 4), ink, 2.0)
		"sealed_tube":
			vessel_draw.draw_arc(Vector2(cx, top), at.call(150.0), PI, TAU, 12, ink, 2.5)
		"fractionating_column":
			vessel_draw.draw_line(Vector2(cx + at.call(160.0), y.call(160.0)), Vector2(cx + 44 * k, y.call(150.0)), ink, 2.5)
		"sieve":
			var w = at.call(20.0)
			for i in range(1, 8):
				var x = lerpf(-w, w, i / 8.0)
				vessel_draw.draw_line(Vector2(cx + x, y.call(4.0)), Vector2(cx + x + 6, y.call(36.0)), ink.lerp(Color(1, 1, 1, 0), 0.5), 1.0)
				vessel_draw.draw_line(Vector2(cx + x + 6, y.call(4.0)), Vector2(cx + x, y.call(36.0)), ink.lerp(Color(1, 1, 1, 0), 0.5), 1.0)
		"reactor_vessel":
			var cyp = Vector2(cx, y.call(60.0))
			vessel_draw.draw_arc(cyp, 14.0, 0, TAU, 20, ThemeStyler.COLOR_INFO, 2.0)
			for i in range(3):
				vessel_draw.draw_line(cyp, cyp + Vector2.from_angle(i * TAU / 3.0 + bubble_phase * 0.2) * 10.0, ThemeStyler.COLOR_INFO, 2.0)
		"blast_furnace":
			for h in [30.0, 70.0, 110.0]:
				vessel_draw.draw_line(Vector2(cx - at.call(h), y.call(h)), Vector2(cx + at.call(h), y.call(h)), ink.lerp(Color(1, 1, 1, 0), 0.6), 1.0)
