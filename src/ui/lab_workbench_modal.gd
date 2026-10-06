# lab_workbench_modal.gd
# 实验台界面：选操作 → 投料 → (点火 / 通电) → 观察反应 → 取回。手稿页列出已获得的配方线索。
# 规则与状态都在模拟层 (src/core/lab_bench.gd)，这里只发命令、读状态。界面在代码中构建。
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const ItemIconManager = preload("res://src/ui/item_icon_manager.gd")
const LabBench = preload("res://src/core/lab_bench.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")

@onready var btn_close: Button = $CenterPanel/VBox/Header/HBox/BtnClose
@onready var body: MarginContainer = $CenterPanel/VBox/Body

const GROUP_TITLES := ["常温", "点火", "通电"]
const THERMO_MAX_C := 1600.0
# 适合放进烧瓶的物品分类 (工具、建筑、奇观等不列出)
const REAGENT_CATEGORIES := ["材料", "矿石", "燃料", "酸碱", "物品", "液体", "气体", "化工", "元素"]

var lab # LabBench
var vessel_draw: Control
var op_buttons: Dictionary = {} # op key -> Button
var sensor_card: PanelContainer
var sensor_badge: Label
var sensor_text: Label
var sensor_bar: ProgressBar
var energy_box: VBoxContainer
var energy_title: Label
var energy_status: Label
var energy_items: HFlowContainer
var btn_fire: Button
var temp_label: Label
var tab_flask: Button
var tab_notes: Button
var view_flask: VBoxContainer
var view_notes: VBoxContainer
var contents_label: RichTextLabel
var btn_retrieve: Button
var reagent_flow: HFlowContainer
var log_label: RichTextLabel
var notes_list: VBoxContainer
var notes_hint: Label

var current_tab: int = 0
var bubble_phase: float = 0.0
var _refresh_timer: float = 0.0
var _dirty: bool = false

func _ready() -> void:
	ModalStack.track(self)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var p_box = ThemeStyler.create_card_box(12, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER)
	for side in ["left", "top", "right", "bottom"]:
		p_box.set("content_margin_" + side, 16)
	$CenterPanel.add_theme_stylebox_override("panel", p_box)
	lab = GameState.lab
	_build()

	btn_close.pressed.connect(close)
	lab.reacted.connect(_on_reacted)
	GameState.inventory.item_changed.connect(func(_k, _c): _mark_dirty())
	GameState.tech_researched.connect(func(_k): _mark_dirty())
	GameState.notification_posted.connect(func(t, _c):
		if visible and (t.begins_with("获得手稿") or t.begins_with("发现新工艺")):
			_add_log(t)
	)
	_switch_tab(0)

# ---------------------------------------------------------------- 构建

func _build() -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	body.add_child(hbox)

	# 左栏：操作、烧瓶、侦测卡、能源
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(500, 0)
	left.add_theme_constant_override("separation", 8)
	hbox.add_child(left)

	for g in range(3):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl = _label(GROUP_TITLES[g], ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED)
		lbl.custom_minimum_size = Vector2(32, 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)
		var flow = HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		row.add_child(flow)
		var any := false
		for op in LabBench.listed_operations():
			if LabBench.op_group(op) != g:
				continue
			any = true
			var b = Button.new()
			b.text = op["name"]
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(0, 28)
			b.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
			b.focus_mode = Control.FOCUS_NONE
			var k = op["key"]
			b.pressed.connect(func(): _on_op_pressed(k))
			flow.add_child(b)
			op_buttons[k] = b
		if any:
			left.add_child(row)

	var mid = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	left.add_child(mid)
	vessel_draw = Control.new()
	vessel_draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vessel_draw.custom_minimum_size = Vector2(0, 170)
	vessel_draw.draw.connect(_on_vessel_draw)
	mid.add_child(vessel_draw)

	sensor_card = PanelContainer.new()
	var sv = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	sensor_card.add_child(sv)
	var sh = HBoxContainer.new()
	sh.add_child(_label("反应侦测", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_ACCENT))
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sp)
	sensor_badge = _label("", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_SECONDARY)
	sh.add_child(sensor_badge)
	sv.add_child(sh)
	sensor_text = _label("", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_PRIMARY)
	sensor_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sensor_text)
	sensor_bar = ProgressBar.new()
	sensor_bar.custom_minimum_size = Vector2(0, 6)
	sensor_bar.show_percentage = false
	sensor_bar.max_value = 1.0
	sensor_bar.add_theme_stylebox_override("background", ThemeStyler.create_card_box(2, ThemeStyler.COLOR_CARD, Color(0, 0, 0, 0)))
	sensor_bar.add_theme_stylebox_override("fill", ThemeStyler.create_card_box(2, ThemeStyler.COLOR_SUCCESS, Color(0, 0, 0, 0)))
	sv.add_child(sensor_bar)
	left.add_child(sensor_card)

	var energy_card = PanelContainer.new()
	var ebox = ThemeStyler.create_card_box(8, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER)
	for side in ["left", "right"]:
		ebox.set("content_margin_" + side, 12)
	for side in ["top", "bottom"]:
		ebox.set("content_margin_" + side, 8)
	energy_card.add_theme_stylebox_override("panel", ebox)
	energy_box = VBoxContainer.new()
	energy_box.add_theme_constant_override("separation", 6)
	energy_card.add_child(energy_box)
	var eh = HBoxContainer.new()
	eh.add_theme_constant_override("separation", 10)
	energy_title = _label("", ThemeStyler.FONT_BODY, ThemeStyler.COLOR_TEXT_PRIMARY)
	eh.add_child(energy_title)
	energy_status = _label("", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_SECONDARY)
	energy_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eh.add_child(energy_status)
	temp_label = _label("", ThemeStyler.FONT_BODY, ThemeStyler.COLOR_ACCENT)
	temp_label.add_theme_font_override("font", ThemeStyler.get_font_mono())
	eh.add_child(temp_label)
	energy_box.add_child(eh)
	var erow = HBoxContainer.new()
	erow.add_theme_constant_override("separation", 8)
	energy_items = HFlowContainer.new()
	energy_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_items.add_theme_constant_override("h_separation", 6)
	energy_items.add_theme_constant_override("v_separation", 6)
	erow.add_child(energy_items)
	btn_fire = Button.new()
	btn_fire.custom_minimum_size = Vector2(88, 30)
	btn_fire.pressed.connect(_on_fire_pressed)
	erow.add_child(btn_fire)
	energy_box.add_child(erow)
	left.add_child(energy_card)

	hbox.add_child(VSeparator.new())

	# 右栏：烧瓶 / 手稿
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	hbox.add_child(right)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tab_flask = Button.new()
	tab_flask.text = "烧瓶"
	tab_flask.custom_minimum_size = Vector2(96, 30)
	tab_flask.pressed.connect(func(): _switch_tab(0))
	tabs.add_child(tab_flask)
	tab_notes = Button.new()
	tab_notes.custom_minimum_size = Vector2(96, 30)
	tab_notes.pressed.connect(func(): _switch_tab(1))
	tabs.add_child(tab_notes)
	right.add_child(tabs)

	view_flask = VBoxContainer.new()
	view_flask.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_flask.add_theme_constant_override("separation", 8)
	right.add_child(view_flask)
	var crow = HBoxContainer.new()
	contents_label = RichTextLabel.new()
	contents_label.bbcode_enabled = true
	contents_label.fit_content = true
	contents_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents_label.custom_minimum_size = Vector2(0, 60)
	crow.add_child(contents_label)
	btn_retrieve = Button.new()
	btn_retrieve.text = "全部取回"
	btn_retrieve.tooltip_text = "把烧瓶里的产物和没用完的原料放回行囊"
	btn_retrieve.custom_minimum_size = Vector2(96, 32)
	btn_retrieve.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn_retrieve.pressed.connect(_on_retrieve_pressed)
	crow.add_child(btn_retrieve)
	view_flask.add_child(crow)
	view_flask.add_child(_label("放入试剂（点击放入 1 份）", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED))
	var rscroll = ScrollContainer.new()
	rscroll.custom_minimum_size = Vector2(0, 150)
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reagent_flow = HFlowContainer.new()
	reagent_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reagent_flow.add_theme_constant_override("h_separation", 6)
	reagent_flow.add_theme_constant_override("v_separation", 6)
	rscroll.add_child(reagent_flow)
	view_flask.add_child(rscroll)
	view_flask.add_child(_label("实验记录", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", ThemeStyler.FONT_CAPTION)
	view_flask.add_child(log_label)

	view_notes = VBoxContainer.new()
	view_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_notes.add_theme_constant_override("separation", 8)
	right.add_child(view_notes)
	notes_hint = _label("", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED)
	notes_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view_notes.add_child(notes_hint)
	var nscroll = ScrollContainer.new()
	nscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notes_list = VBoxContainer.new()
	notes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_list.add_theme_constant_override("separation", 8)
	nscroll.add_child(notes_list)
	view_notes.add_child(nscroll)

func _label(text: String, size: int, col: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

# ---------------------------------------------------------------- 打开 / 关闭

func open() -> void:
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
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_L):
		close()
		get_viewport().set_input_as_handled()

func _switch_tab(idx: int) -> void:
	current_tab = idx
	view_flask.visible = idx == 0
	view_notes.visible = idx == 1
	tab_flask.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT if idx == 0 else ThemeStyler.COLOR_TEXT_SECONDARY)
	tab_notes.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT if idx == 1 else ThemeStyler.COLOR_TEXT_SECONDARY)
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
	for k in op_buttons.keys():
		var b: Button = op_buttons[k]
		var reason = lab.op_lock_reason(k)
		b.set_pressed_no_signal(lab.operation == k)
		b.modulate = Color(1, 1, 1, 0.45) if reason != "" else Color.WHITE
		b.tooltip_text = (DataDB.get_lab_op(k).get("description", "") + ("\n" + reason if reason != "" else "")).strip_edges()
		b.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT if lab.operation == k else ThemeStyler.COLOR_TEXT_PRIMARY)
	_refresh_energy_items()
	_refresh_reagents()
	_refresh_contents()
	tab_notes.text = "手稿 %d" % lab.fragments.size()
	if current_tab == 1:
		_refresh_notes()
	_refresh_status()

func _refresh_status() -> void:
	var v = lab.vessel
	temp_label.text = "%d ℃" % int(round(v.temperature - 273.15))
	if lab.needs_fire():
		energy_title.text = "炉火"
		if lab.fire_lit:
			energy_status.text = "%s 燃烧中，火焰 %d ℃，燃料还能烧 %d 秒" % [_name(lab.cur_fuel), int(lab.flame_temp() - 273.15), int(ceil(lab.fuel_seconds()))]
		elif lab.fuel_seconds() > 0.0:
			energy_status.text = "已放燃料 %d 秒，点火需要火种或燧石" % int(ceil(lab.fuel_seconds()))
		else:
			energy_status.text = "放入燃料后点火。燃料越好，火焰温度越高"
		btn_fire.visible = true
		btn_fire.text = "熄火" if lab.fire_lit else "点火"
		btn_fire.disabled = not lab.fire_lit and lab.fuel_seconds() <= 0.0
	elif lab.needs_power():
		energy_title.text = "电源"
		btn_fire.visible = false
		if lab.power_left > 0.0:
			energy_status.text = "%s %.0f V，剩余 %d 秒" % [_name(lab.power_key), lab.voltage(), int(ceil(lab.power_left))]
		else:
			energy_status.text = "接入一块电池开始通电，电量用完电池报废"
	else:
		energy_title.text = "常温"
		btn_fire.visible = lab.fire_lit
		btn_fire.text = "熄火"
		energy_status.text = "选择操作后开始实验。焙烧、干馏等需要点火，电解需要电池" if lab.operation == "" else "此操作不需要加热或通电"

	var d = lab.diagnose()
	var styles = {
		"empty": ["空烧瓶", ThemeStyler.COLOR_TEXT_SECONDARY, ThemeStyler.COLOR_CARD],
		"reacting": ["反应中", ThemeStyler.COLOR_SUCCESS, ThemeStyler.TINT_SUCCESS],
		"blocked": ["条件不足", ThemeStyler.COLOR_WARNING, ThemeStyler.TINT_WARNING],
		"partial": ["缺少原料", ThemeStyler.COLOR_INFO, ThemeStyler.TINT_INFO],
		"unknown": ["无反应", ThemeStyler.COLOR_TEXT_MUTED, ThemeStyler.COLOR_CARD],
		"inert": ["无反应", ThemeStyler.COLOR_TEXT_MUTED, ThemeStyler.COLOR_CARD],
	}
	var st = styles.get(d["state"], styles["inert"])
	var text: String = d["text"]
	if lab.operation == "" and d["state"] != "empty" and d["state"] != "reacting":
		text = "先在上方选择一种操作"
	sensor_badge.text = st[0]
	sensor_badge.add_theme_color_override("font_color", st[1])
	sensor_text.text = text
	sensor_bar.visible = d["state"] == "reacting"
	sensor_bar.value = float(d.get("progress", 0.0))
	var box = ThemeStyler.create_card_box(8, st[2], st[1])
	for side in ["left", "right"]:
		box.set("content_margin_" + side, 12)
	for side in ["top", "bottom"]:
		box.set("content_margin_" + side, 8)
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
			var b = _item_button(k, "%s ×%d" % [_name(k), GameState.inventory.get_count(k)])
			b.tooltip_text = "燃烧 %d 秒，最高 %d ℃" % [int(info["burn_time"]), int(info["max_temp"] - 273.15)]
			b.pressed.connect(func():
				if lab.add_fuel(k):
					_add_log("放入燃料 %s" % _name(k))
			)
			energy_items.add_child(b)
	elif lab.needs_power():
		var opts = lab.battery_options()
		if opts.is_empty():
			energy_items.add_child(_label("行囊里没有电池", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_WARNING))
		for k in opts:
			var info = LabBench.battery_info(k)
			var b = _item_button(k, "%s ×%d" % [_name(k), GameState.inventory.get_count(k)])
			b.tooltip_text = "%.0f V，可通电 %d 秒" % [info["voltage"], int(info["power_time"])]
			b.disabled = lab.power_left > 0.0
			b.pressed.connect(func():
				if lab.connect_power(k):
					_add_log("接入 %s（%.0f V）" % [_name(k), info["voltage"]])
					_refresh_all()
			)
			energy_items.add_child(b)

func _refresh_reagents() -> void:
	for c in reagent_flow.get_children():
		c.queue_free()
	var keys = GameState.inventory.items.keys()
	keys.sort_custom(func(a, b): return _name(a) < _name(b))
	var shown := 0
	for k in keys:
		var n = GameState.inventory.get_count(k)
		if n <= 0:
			continue
		var item = DataDB.get_item(k)
		var cat = str(item.get("category", ""))
		if not (cat in REAGENT_CATEGORIES or DataDB.is_pure_element(k) > 0):
			continue
		var b = _item_button(k, "%s ×%d" % [_name(k), n])
		b.pressed.connect(func(): add_reagent(k, 1.0))
		reagent_flow.add_child(b)
		shown += 1
	if shown == 0:
		reagent_flow.add_child(_label("行囊里没有可用的试剂，去地图上采集吧", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED))

func _item_button(key: String, text: String) -> Button:
	var b = Button.new()
	b.text = text
	b.icon = ItemIconManager.get_icon(key)
	b.expand_icon = true
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _refresh_contents() -> void:
	var v = lab.vessel
	if v.components.is_empty():
		contents_label.text = "[color=%s]烧瓶是空的[/color]" % ThemeStyler.COLOR_TEXT_MUTED.to_html(false)
		return
	var parts: Array = []
	for k in v.components.keys():
		var amt = float(v.components[k])
		var col = ThemeStyler.COLOR_SUCCESS if lab.produced.has(k) else ThemeStyler.COLOR_TEXT_PRIMARY
		parts.append("[color=%s]%s %s[/color]" % [col.to_html(false), _name(k), _fmt_amount(amt)])
	contents_label.text = "烧瓶内：" + "、".join(parts)

func _fmt_amount(a: float) -> String:
	return "×%d" % int(round(a)) if is_equal_approx(a, round(a)) else "×%.1f" % a

func _refresh_notes() -> void:
	for c in notes_list.get_children():
		c.queue_free()
	notes_hint.text = "手稿记录配方线索：采集时偶尔捡到，研发科技必得一份，第一次获得某种物品时也可能得到。没见过的物品写作 ???，做成一次后完整显示。"
	var known = ThemeStyler.COLOR_ACCENT.to_html(false)
	var opc = ThemeStyler.COLOR_INFO.to_html(false)
	var unk = ThemeStyler.COLOR_TEXT_MUTED.to_html(false)
	var keys: Array = lab.fragments.duplicate()
	keys.reverse() # 新得到的在前
	keys.sort_custom(func(a, b): return int(lab.proven.has(a)) < int(lab.proven.has(b)))
	for f_key in keys:
		var f = DataDB.get_formula(f_key)
		if f.is_empty():
			continue
		var proven = lab.proven.has(f_key)
		var card = PanelContainer.new()
		var box = ThemeStyler.create_card_box(8, ThemeStyler.TINT_SUCCESS if proven else ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_SUCCESS if proven else ThemeStyler.COLOR_BORDER)
		for side in ["left", "right"]:
			box.set("content_margin_" + side, 12)
		for side in ["top", "bottom"]:
			box.set("content_margin_" + side, 8)
		card.add_theme_stylebox_override("panel", box)
		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		card.add_child(vb)
		var head = HBoxContainer.new()
		var title = _label(f.get("name", f_key), ThemeStyler.FONT_BODY, ThemeStyler.COLOR_TEXT_PRIMARY)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var op_key = ChemistrySolver.formula_operation(f)
		var tags: Array = [DataDB.get_lab_op(op_key).get("name", "")]
		var t = ChemistrySolver.formula_min_temp(f)
		if t > 0.0:
			tags.append("%d ℃ 以上" % int(t - 273.15))
		var volt = ChemistrySolver.formula_min_voltage(f)
		if volt > 0.0:
			tags.append("%.0f V" % volt)
		tags.append("已确证" if proven else "残片")
		head.add_child(_label(" · ".join(tags), ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_SUCCESS if proven else ThemeStyler.COLOR_TEXT_MUTED))
		vb.add_child(head)
		var txt = RichTextLabel.new()
		txt.bbcode_enabled = true
		txt.fit_content = true
		txt.add_theme_font_size_override("normal_font_size", ThemeStyler.FONT_CAPTION)
		txt.text = lab.fragment_text(f_key, known, opc, unk)
		vb.add_child(txt)
		var btn = Button.new()
		btn.text = "按手稿备料"
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		btn.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
		btn.pressed.connect(func(): _prepare(f_key))
		vb.add_child(btn)
		notes_list.add_child(card)

# ---------------------------------------------------------------- 命令

func _on_op_pressed(key: String) -> void:
	var target = "" if lab.operation == key else key
	if lab.set_operation(target) and target != "":
		_add_log("操作：%s" % DataDB.get_lab_op(key).get("name", key))
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
		GameState.post_notification("行囊里没有%s" % _name(item_key), Color(1, 0.4, 0.4))
		return
	_add_log("放入 %s ×%d" % [_name(item_key), int(amount)])
	_refresh_contents()
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

func _prepare(f_key: String) -> void:
	var missing = lab.prepare_from_fragment(f_key)
	if missing.is_empty():
		_add_log("已按手稿「%s」备好原料" % DataDB.get_formula(f_key).get("name", f_key))
	else:
		GameState.post_notification("还缺：%s" % "、".join(missing), Color(1.0, 0.6, 0.3))
	_switch_tab(0)
	_refresh_all()

func _on_reacted(f_key: String, products: Array) -> void:
	if not visible:
		return
	var names: Array = []
	for p in products:
		names.append(_name(p))
	var f = DataDB.get_formula(f_key)
	_add_log("%s：生成 %s" % [f.get("name", "反应"), "、".join(names)])
	_refresh_contents()

func _add_log(msg: String) -> void:
	log_label.append_text("· %s\n" % msg)

func _name(k: String) -> String:
	return DataDB.get_item(k).get("name", k)

# ---------------------------------------------------------------- 绘制

func _solution_color() -> Color:
	var v = lab.vessel
	if v.components.is_empty():
		return ThemeStyler.adapt(Color(0.75, 0.82, 0.88, 0.25))
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
	c.a = 0.75
	return ThemeStyler.adapt(c)

func _on_vessel_draw() -> void:
	var sz = vessel_draw.size
	var cx = sz.x * 0.42
	var bot = sz.y - 46.0
	var neck_top = 10.0
	var neck_bot = bot - 70.0
	var ink = ThemeStyler.COLOR_TEXT_SECONDARY
	var v = lab.vessel

	# 烧瓶液体与轮廓
	var fill = PackedVector2Array([Vector2(cx - 14, neck_bot + 22), Vector2(cx - 52, bot), Vector2(cx + 52, bot), Vector2(cx + 14, neck_bot + 22)])
	if not v.components.is_empty():
		vessel_draw.draw_colored_polygon(fill, _solution_color())
	var outline = PackedVector2Array([Vector2(cx - 14, neck_top), Vector2(cx - 14, neck_bot), Vector2(cx - 54, bot), Vector2(cx + 54, bot), Vector2(cx + 14, neck_bot), Vector2(cx + 14, neck_top)])
	vessel_draw.draw_polyline(outline, ink, 2.0, true)
	vessel_draw.draw_line(Vector2(cx - 20, neck_top), Vector2(cx + 20, neck_top), ink, 2.0)
	# 反应时的气泡
	if v.active_formula != "":
		for i in range(5):
			var ph = fmod(bubble_phase * 0.25 + i * 0.2, 1.0)
			var p = Vector2(cx - 30 + i * 15 + sin(bubble_phase + i) * 3.0, bot - 6 - ph * 50.0)
			vessel_draw.draw_arc(p, 2.5 + i % 2, 0, TAU, 12, ThemeStyler.adapt(Color(1, 1, 1, 0.8 * (1.0 - ph))), 1.2)

	# 炉火：燃料床 + 随温度变色的火焰
	var base_y = bot + 10.0
	vessel_draw.draw_line(Vector2(cx - 60, bot + 4), Vector2(cx + 60, bot + 4), ink, 2.0) # 支架
	if lab.needs_fire() or lab.fire_lit:
		vessel_draw.draw_rect(Rect2(cx - 44, base_y + 18, 88, 8), ThemeStyler.adapt(Color(0.30, 0.26, 0.22)), true)
		if lab.fire_lit:
			var heat = clampf((lab.flame_temp() - 873.0) / 900.0, 0.0, 1.0)
			var outer = Color(0.90, 0.45, 0.15).lerp(Color(1.0, 0.85, 0.45), heat)
			for i in range(3):
				var fx = cx - 22 + i * 22
				var h = 22.0 + sin(bubble_phase * 1.3 + i * 2.0) * 4.0 + heat * 6.0
				vessel_draw.draw_colored_polygon(PackedVector2Array([Vector2(fx - 9, base_y + 18), Vector2(fx, base_y + 18 - h), Vector2(fx + 9, base_y + 18)]), outer)
				vessel_draw.draw_colored_polygon(PackedVector2Array([Vector2(fx - 4, base_y + 18), Vector2(fx, base_y + 18 - h * 0.55), Vector2(fx + 4, base_y + 18)]), Color(1.0, 0.95, 0.75))
	# 电极
	if lab.needs_power():
		var live = lab.power_left > 0.0
		var ec = ThemeStyler.COLOR_INFO if live else ink
		for dx in [-16.0, 16.0]:
			vessel_draw.draw_line(Vector2(cx + dx, neck_top - 4), Vector2(cx + dx, bot - 12), ec, 3.0)
		if live:
			var y = bot - 30 + sin(bubble_phase) * 6.0
			vessel_draw.draw_polyline(PackedVector2Array([Vector2(cx - 16, y), Vector2(cx - 5, y - 6), Vector2(cx + 4, y + 4), Vector2(cx + 16, y - 2)]), ec, 1.5)

	# 温度计：当前温度、火焰可达温度、手稿要求温度
	var tx = sz.x - 40.0
	var top = 12.0
	var tb = sz.y - 20.0
	var font = ThemeStyler.get_font_mono()
	vessel_draw.draw_rect(Rect2(tx - 5, top, 10, tb - top), ThemeStyler.COLOR_CARD, true)
	vessel_draw.draw_rect(Rect2(tx - 5, top, 10, tb - top), ink, false, 1.0)
	var to_y = func(k: float) -> float: return tb - clampf((k - 273.15) / THERMO_MAX_C, 0.0, 1.0) * (tb - top)
	var cy = to_y.call(v.temperature)
	vessel_draw.draw_rect(Rect2(tx - 3, cy, 6, tb - cy), ThemeStyler.COLOR_DANGER, true)
	vessel_draw.draw_circle(Vector2(tx, tb + 6), 7.0, ThemeStyler.COLOR_DANGER)
	for c in [0, 500, 1000, 1500]:
		var y = to_y.call(c + 273.15)
		vessel_draw.draw_line(Vector2(tx + 5, y), Vector2(tx + 10, y), ink, 1.0)
		vessel_draw.draw_string(font, Vector2(tx + 12, y + 4), str(c), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ThemeStyler.COLOR_TEXT_MUTED)
	if lab.fire_lit:
		var fy = to_y.call(lab.flame_temp())
		vessel_draw.draw_line(Vector2(tx - 12, fy), Vector2(tx - 5, fy), ThemeStyler.COLOR_ACCENT, 2.0)
