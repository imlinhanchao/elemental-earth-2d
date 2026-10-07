# reactor_modal.gd
# 工业连续反应塔面板：列出已确证配方生成的工艺蓝图，点选装入；显示每批消耗、产出、周期与缺少的原料，可暂停 / 继续。
# 状态都在模拟层 (Simulation.built_reactors[hex])，这里只发命令、读状态。界面在代码中构建。
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const ItemIconManager = preload("res://src/ui/item_icon_manager.gd")

var hex: Vector2i = Vector2i(9999, 9999)
var _status: Label
var _bar: ProgressBar
var _io: RichTextLabel
var _btn_pause: Button
var _list: VBoxContainer
var _timer: float = 0.0

func _ready() -> void:
	ModalStack.track(self)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop = ColorRect.new()
	backdrop.color = ThemeStyler.COLOR_BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 520)
	panel.add_theme_stylebox_override("panel", _box(14, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER, 18))
	center.add_child(panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var head = HBoxContainer.new()
	var title = _label("工业连续反应塔", ThemeStyler.FONT_HEADING, ThemeStyler.COLOR_TEXT_PRIMARY)
	title.add_theme_font_override("font", ThemeStyler.get_font_sans_bold())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn = Button.new()
	close_btn.text = "关闭 [ESC]"
	close_btn.custom_minimum_size = Vector2(84, 28)
	close_btn.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	v.add_child(head)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(10, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER, 12))
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	var sh = HBoxContainer.new()
	_status = _label("", ThemeStyler.FONT_BODY, ThemeStyler.COLOR_TEXT_PRIMARY)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sh.add_child(_status)
	_btn_pause = Button.new()
	_btn_pause.custom_minimum_size = Vector2(84, 30)
	_btn_pause.pressed.connect(_on_pause_pressed)
	sh.add_child(_btn_pause)
	cv.add_child(sh)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.add_theme_stylebox_override("background", _box(4, ThemeStyler.COLOR_BG_SOLID, Color(0, 0, 0, 0), 0))
	_bar.add_theme_stylebox_override("fill", _box(4, ThemeStyler.COLOR_SUCCESS, Color(0, 0, 0, 0), 0))
	cv.add_child(_bar)
	_io = RichTextLabel.new()
	_io.bbcode_enabled = true
	_io.fit_content = true
	_io.add_theme_font_size_override("normal_font_size", ThemeStyler.FONT_CAPTION)
	cv.add_child(_io)
	v.add_child(card)

	var hint = _label("在实验台或炉体里第一次做成某个配方，就会得到它的工艺蓝图。反应塔每批直接从行囊取料、产物放回行囊。", ThemeStyler.FONT_CAPTION, ThemeStyler.COLOR_TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	v.add_child(scroll)

func _box(radius: int, bg: Color, border: Color, pad: int = 10) -> StyleBoxFlat:
	var b = ThemeStyler.create_card_box(radius, bg, border)
	for side in ["left", "top", "right", "bottom"]:
		b.set("content_margin_" + side, pad)
	return b

func _label(text: String, size: int, col: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _name(k: String) -> String:
	return DataDB.get_item(k).get("name", k)

func open(p_hex: Vector2i) -> void:
	hex = p_hex
	visible = true
	_refresh_list()
	_refresh_status()

func close() -> void:
	visible = false

func _input(event: InputEvent) -> void:
	if not visible or not ModalStack.is_top(self):
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		_refresh_status()

func _reactor() -> Dictionary:
	return GameState.built_reactors.get(hex, {})

func _blueprint():
	return GameState.unlocked_blueprints.get(_reactor().get("blueprint_id", ""))

# 「木炭 ×2、孔雀石 ×1」；缺的标红
func _fmt_items(d: Dictionary, missing: Dictionary = {}) -> String:
	var parts: Array = []
	var bad = ThemeStyler.COLOR_DANGER.to_html(false)
	for k in d.keys():
		var t = "%s ×%d" % [_name(k), int(ceil(d[k]))]
		parts.append("[color=%s]%s[/color]" % [bad, t] if missing.has(k) else t)
	return "、".join(parts) if not parts.is_empty() else "无"

func _refresh_status() -> void:
	var r = _reactor()
	var bp = _blueprint()
	_bar.visible = bp != null
	_io.visible = bp != null
	_btn_pause.visible = bp != null
	if bp == null:
		_status.text = "还没有装入蓝图。从下方选择一张"
		return
	var missing = GameState.sim.reactor_missing_inputs(hex)
	var paused = r.get("paused", false)
	_btn_pause.text = "继续" if paused else "暂停"
	var state = "已暂停" if paused else ("缺少原料，等待中" if not missing.is_empty() else "运转中")
	_status.text = "%s · %s · 已产出 %d" % [bp.display_name, state, int(r.get("total_produced", 0))]
	_bar.value = clampf(float(r.get("cycle_progress", 0.0)) / maxf(1.0, bp.duration_seconds), 0.0, 1.0)
	_io.text = "每批消耗：%s\n每批产出：%s\n周期：%d 秒" % [_fmt_items(bp.inputs, missing), _fmt_items(bp.outputs), int(bp.duration_seconds)]

func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var cur = _reactor().get("blueprint_id", "")
	var keys = GameState.unlocked_blueprints.keys()
	if keys.is_empty():
		_list.add_child(_label("还没有蓝图", ThemeStyler.FONT_BODY, ThemeStyler.COLOR_WARNING))
		return
	for k in keys:
		var bp = GameState.unlocked_blueprints[k]
		var b = Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 48)
		b.text = "%s\n%s → %s · %d 秒" % [bp.display_name, _fmt_plain(bp.inputs), _fmt_plain(bp.outputs), int(bp.duration_seconds)]
		b.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
		var out_keys = bp.outputs.keys()
		if not out_keys.is_empty():
			b.icon = ItemIconManager.get_icon(out_keys[0])
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 32)
		var on = k == cur
		b.add_theme_stylebox_override("normal", _box(8, ThemeStyler.TINT_SUCCESS if on else ThemeStyler.COLOR_BG_SOLID, ThemeStyler.COLOR_SUCCESS if on else ThemeStyler.COLOR_BORDER, 8))
		b.add_theme_stylebox_override("hover", _box(8, ThemeStyler.COLOR_CARD_HOVER, ThemeStyler.COLOR_ACCENT, 8))
		b.disabled = on
		b.pressed.connect(func():
			GameState.reactor_install_blueprint(hex, k)
			_refresh_list()
			_refresh_status()
		)
		_list.add_child(b)

func _fmt_plain(d: Dictionary) -> String:
	var parts: Array = []
	for k in d.keys():
		parts.append("%s ×%d" % [_name(k), int(ceil(d[k]))])
	return "、".join(parts)

func _on_pause_pressed() -> void:
	GameState.reactor_set_paused(hex, not _reactor().get("paused", false))
	_refresh_status()
