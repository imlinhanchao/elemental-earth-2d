# tutorial_dock.gd
# 新手教程：每一步只有一个目标。地图上标出要点击的地块，界面上高亮要按的按钮，
# 达成目标后自动进入下一步，全程约 5 分钟。
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")

signal tutorial_finished
signal tutorial_skipped

const NO_HEX := Vector2i(9999, 9999)
const ADVANCE_DELAY := 0.8 # 目标达成后停留多久再进入下一步 (秒)

# text: 一句话指令；hint: 补充说明；goal / target: 完成条件；
# resource: 要在地图上标出的资源；ui: 要高亮的界面元素 ("craft:<配方>" / "build:<建筑>" / "tech")
const STAGES: Array[Dictionary] = [
	{"text": "点击地图上标出的碎石，采集 2 块", "hint": "左键点击地块加入作业队列。右键拖拽移动视野，滚轮缩放。", "goal": "stone", "target": 2, "resource": "stone"},
	{"text": "采集 2 根枯树枝", "hint": "作业会排队依次完成，可以连续点击多个地块。", "goal": "stick", "target": 2, "resource": "stick"},
	{"text": "制作燧石手斧", "hint": "打开制作 [T]，点击「原始燧石手斧」。制作后自动装备。", "goal": "axe", "target": 1, "ui": "craft:flint_axe"},
	{"text": "砍伐 4 根原木", "hint": "装备斧头后，树木出现在地图上。右键点击树可以一次安排多次砍伐。", "goal": "wood", "target": 4, "resource": "wood"},
	{"text": "再采集 4 块碎石", "hint": "篝火堆需要 4 根原木和 4 块碎石（燧石也可以）。", "goal": "stone_or_flint", "target": 4, "resource": "stone"},
	{"text": "建造篝火堆", "hint": "打开建造 [C]，点击「原始篝火堆」，再在领地内点一块空地放下。", "goal": "structure", "target": 1, "ui": "build:fire_pit"},
	{"text": "打开科技树，看看下一步研发什么", "hint": "研发科技可以解锁新的工具和建筑。按 [K] 或点击底栏「科技」。", "goal": "tech_opened", "target": 1, "ui": "tech"},
]

@onready var panel_container: PanelContainer = $PanelContainer
@onready var step_lbl: Label = $PanelContainer/Margin/VBox/HeaderHBox/StepLbl
@onready var btn_skip: Button = $PanelContainer/Margin/VBox/HeaderHBox/BtnSkip
@onready var step_bar: ProgressBar = $PanelContainer/Margin/VBox/StepBar
@onready var title_lbl: Label = $PanelContainer/Margin/VBox/TitleLabel
@onready var hint_lbl: Label = $PanelContainer/Margin/VBox/HintLabel
@onready var goal_lbl: Label = $PanelContainer/Margin/VBox/GoalLabel

var current_stage_idx: int = 0
var _advancing: bool = false
var _tech_seen: bool = false
var _check_timer: float = 0.0
var _highlight: Control = null
var _highlight_target: Control = null

func _ready() -> void:
	_apply_styles()
	btn_skip.pressed.connect(_on_skip_pressed)
	# 界面高亮框：挂在 HUD (CanvasLayer) 下、绘制在所有界面之上，不拦截鼠标
	_highlight = Control.new()
	_highlight.name = "TutorialHighlight"
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highlight.visible = false
	_highlight.draw.connect(_on_highlight_draw)
	get_parent().add_child.call_deferred(_highlight)

	GameState.tutorial_step_changed.connect(_load_stage)
	GameState.tutorial_state_changed.connect(func(active): visible = active)
	_load_stage(GameState.tutorial_step)

func _process(delta: float) -> void:
	if not visible or not GameState.is_tutorial_active:
		if _highlight: _highlight.visible = false
		return
	var hud = get_parent()
	if hud.tech_modal.visible:
		_tech_seen = true

	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.25
		_check_goal()

	# 地图标记与界面高亮需要逐帧动画
	if GameState.tutorial_marker_hex != NO_HEX:
		var w = _world()
		if w: w.overlay_layer.queue_redraw()
	_highlight_target = _resolve_ui_target()
	if _highlight:
		_highlight.visible = _highlight_target != null
		if _highlight.visible:
			_highlight.queue_redraw()

func _apply_styles() -> void:
	var card_box = ThemeStyler.create_card_box(12, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER_FOCUS)
	card_box.content_margin_left = 16
	card_box.content_margin_top = 12
	card_box.content_margin_right = 16
	card_box.content_margin_bottom = 14
	card_box.shadow_color = ThemeStyler.COLOR_SHADOW
	card_box.shadow_size = 12
	card_box.shadow_offset = Vector2(0, 3)
	panel_container.add_theme_stylebox_override("panel", card_box)

	var bar_bg = ThemeStyler.create_card_box(2, ThemeStyler.COLOR_CARD, ThemeStyler.adapt(Color(0, 0, 0, 0)))
	var bar_fill = ThemeStyler.create_card_box(2, ThemeStyler.COLOR_ACCENT, ThemeStyler.adapt(Color(0, 0, 0, 0)))
	step_bar.add_theme_stylebox_override("background", bar_bg)
	step_bar.add_theme_stylebox_override("fill", bar_fill)
	step_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
	hint_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	btn_skip.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_MUTED)
	btn_skip.add_theme_color_override("font_hover_color", ThemeStyler.COLOR_DANGER)

func _load_stage(stage_idx: int) -> void:
	if stage_idx >= STAGES.size():
		_finish_tutorial()
		return
	current_stage_idx = max(stage_idx, 0)
	_advancing = false
	_tech_seen = false
	var stage = STAGES[current_stage_idx]
	step_lbl.text = "教程 %d / %d" % [current_stage_idx + 1, STAGES.size()]
	step_bar.max_value = STAGES.size()
	step_bar.value = current_stage_idx
	title_lbl.text = stage["text"]
	hint_lbl.text = stage["hint"]
	GameState.tutorial_marker_hex = NO_HEX
	_check_goal()
	if GameState.tutorial_marker_hex != NO_HEX:
		_focus_camera(GameState.tutorial_marker_hex)

func _goal_progress(stage: Dictionary) -> int:
	var inv = GameState.inventory
	match stage["goal"]:
		"stone", "stick", "wood":
			return inv.get_count(stage["goal"])
		"stone_or_flint":
			return inv.get_count("stone") + inv.get_count("flint")
		"axe":
			return 1 if GameState.equipped_tools.get("axe", "bare_hands") != "bare_hands" else 0
		"structure":
			return GameState.built_furnaces.size()
		"tech_opened":
			return 1 if _tech_seen else 0
	return 0

func _check_goal() -> void:
	if current_stage_idx >= STAGES.size():
		return
	var stage = STAGES[current_stage_idx]
	var target = int(stage["target"])
	var cur = _goal_progress(stage)
	var done = cur >= target

	if target > 1:
		goal_lbl.text = "%s %d / %d" % ["已完成" if done else "进度", min(cur, target), target]
	else:
		goal_lbl.text = "已完成" if done else "未完成"
	goal_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_SUCCESS if done else ThemeStyler.COLOR_TEXT_PRIMARY)

	if done:
		GameState.tutorial_marker_hex = NO_HEX
		if not _advancing:
			_advancing = true
			step_bar.value = current_stage_idx + 1
			get_tree().create_timer(ADVANCE_DELAY).timeout.connect(_advance)
		return

	# 地图标记：当前标记地块仍有资源就保持不动，否则找最近的一块
	var res_key = str(stage.get("resource", ""))
	if res_key == "":
		GameState.tutorial_marker_hex = NO_HEX
		return
	var mk = GameState.tutorial_marker_hex
	if mk == NO_HEX or int(GameState.tile_resources.get(mk, {}).get(res_key, 0)) <= 0:
		var from = mk if mk != NO_HEX else Vector2i.ZERO
		GameState.tutorial_marker_hex = GameState.sim.find_nearest_resource(res_key, from)

func _advance() -> void:
	if not GameState.is_tutorial_active:
		return
	if current_stage_idx < STAGES.size() - 1:
		GameState.next_tutorial_step()
	else:
		_finish_tutorial()

# 目标地块不在视野中央附近时，把镜头平移过去
func _focus_camera(hex: Vector2i) -> void:
	var w = _world()
	if w == null:
		return
	var p = HexWorldGenerator.hex_to_pixel(hex.x, hex.y)
	var view = w.get_viewport_rect().size / w.camera.zoom
	if absf(p.x - w.camera.position.x) < view.x * 0.3 and absf(p.y - w.camera.position.y) < view.y * 0.25:
		return
	var tw = w.create_tween()
	tw.tween_property(w.camera, "position", w._clamp_camera(p), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _world() -> Node:
	return get_tree().get_first_node_in_group("world")

# 当前步骤要高亮的界面元素：先指向底栏按钮，抽屉打开后指向具体卡片
func _resolve_ui_target() -> Control:
	if _advancing or current_stage_idx >= STAGES.size():
		return null
	var ui = str(STAGES[current_stage_idx].get("ui", ""))
	if ui == "":
		return null
	var hud = get_parent()
	var w = _world()
	if w and w.is_placing_structure:
		return null
	var parts = ui.split(":")
	var target: Control = null
	match parts[0]:
		"craft", "build":
			if not ModalStack.is_empty():
				return null
			var tab = hud.CategoryTab.CRAFT if parts[0] == "craft" else hud.CategoryTab.BUILD
			if hud.action_drawer.visible and hud.current_tab == tab:
				target = hud.drawer_card_by_key.get(parts[1])
			else:
				target = hud.btn_tab_craft if parts[0] == "craft" else hud.btn_tab_build
		"tech":
			if hud.tech_modal.visible or not ModalStack.is_empty():
				return null
			target = hud.btn_tab_tech
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return null
	return target

func _on_highlight_draw() -> void:
	if _highlight_target == null or not is_instance_valid(_highlight_target):
		return
	var t = Time.get_ticks_msec() / 1000.0
	var col = ThemeStyler.COLOR_ACCENT
	var rect = _highlight_target.get_global_rect().grow(4.0 + sin(t * 4.0) * 1.5)
	_highlight.draw_rect(rect.grow(2.0), ThemeStyler.adapt(Color(1, 1, 1, 0.6)), false, 4.0)
	_highlight.draw_rect(rect, col, false, 2.5)
	# 上方指示箭头
	var tip = Vector2(rect.get_center().x, rect.position.y - 6.0 - absf(sin(t * 3.0)) * 5.0)
	var tri = PackedVector2Array([tip, tip + Vector2(-8, -12), tip + Vector2(8, -12)])
	_highlight.draw_colored_polygon(tri, col)

func _on_skip_pressed() -> void:
	GameState.skip_tutorial()
	visible = false
	tutorial_skipped.emit()

func _finish_tutorial() -> void:
	if not GameState.is_tutorial_active:
		return
	GameState.complete_tutorial()
	visible = false
	tutorial_finished.emit()
