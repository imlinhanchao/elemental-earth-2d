# tutorial_dock.gd
# 现代化科学沉浸式新手教学悬浮导引坞: 动态步骤任务链、实时条件追踪、快捷键高亮、完成推进与跳过
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")

signal tutorial_finished
signal tutorial_skipped

@onready var panel_container = $PanelContainer
@onready var header_hbox = $PanelContainer/Margin/VBox/HeaderHBox
@onready var step_badge = $PanelContainer/Margin/VBox/HeaderHBox/StepBadge
@onready var step_badge_lbl = $PanelContainer/Margin/VBox/HeaderHBox/StepBadge/BadgeLbl
@onready var btn_skip = $PanelContainer/Margin/VBox/HeaderHBox/BtnSkip

@onready var title_lbl = $PanelContainer/Margin/VBox/TitleLabel
@onready var desc_lbl = $PanelContainer/Margin/VBox/DescLabel
@onready var goals_vbox = $PanelContainer/Margin/VBox/GoalsVBox

@onready var footer_hbox = $PanelContainer/Margin/VBox/FooterHBox
@onready var status_lbl = $PanelContainer/Margin/VBox/FooterHBox/StatusLbl
@onready var btn_next = $PanelContainer/Margin/VBox/FooterHBox/BtnNext

# 教学步骤元数据定义
const STAGES: Array[Dictionary] = [
	{
		"title": "初临大地 · 视野与地表拾取",
		"desc": "在这片原始大地上，万物皆由化学元素筑就。\n• 按住 [color=#9C5A1E][鼠标右键][/color] 拖拽地图平移视野\n• 滚动 [color=#9C5A1E][滚轮][/color] 缩放视野范围\n• 用 [color=#9C5A1E][鼠标左键][/color] 点击地表散落的【碎石】与【枯树枝】加入工作队列",
		"goals": [
			{"id": "stone", "text": "拾取碎石", "target": 2},
			{"id": "stick", "text": "拾取枯树枝", "target": 2}
		]
	},
	{
		"title": "锐利石刃 · 寻找燧石与盐湖汲水",
		"desc": "坚硬锐利的石刃是制作第一柄工具的关键：\n• 在原野中寻找带深色青蓝刃口的【燧石】并点击拾取\n• 前往西侧灰蓝色的水泊，点击【盐湖】汲取天然盐水",
		"goals": [
			{"id": "flint", "text": "拾取燧石", "target": 1},
			{"id": "water", "text": "盐湖汲水", "target": 1}
		]
	},
	{
		"title": "工匠破雾 · 打造手斧与橡树现形",
		"desc": "素材已齐备！正式迈向石器工匠时代：\n• 按键盘快捷键 [color=#9C5A1E][T][/color] 呼出底部【制作栏】\n• 打造你的第一件工具【原始燧石手斧】\n• 制作完成后工具将自动装配——观察大地图：深林处的【大橡树】破除迷雾显现了！",
		"goals": [
			{"id": "axe", "text": "打造并装备原始燧石斧", "target": 1}
		]
	},
	{
		"title": "伐木拓荒 · 采伐原木与构筑营地",
		"desc": "手斧赋予了你砍伐坚硬林木的生产力：\n• 点击显现的大橡树，采伐【原木】\n• 提示：右键单点地块可呼出【批次/无尽开采】菜单\n• 收集木材后，按快捷键 [color=#9C5A1E][C][/color] 建造一座【原始篝火堆】！",
		"goals": [
			{"id": "wood", "text": "砍伐获取原木", "target": 4},
			{"id": "structure", "text": "建造原始篝火堆或熔炉", "target": 1}
		]
	},
	{
		"title": "科学晨曦 · 科技星图与化学圣殿",
		"desc": "火与工具点燃了人类理性的第一缕晨光：\n• 按键盘 [color=#9C5A1E][K][/color] 查阅 40 项全景【科技星图】，研读前沿突破\n• 按键盘 [color=#9C5A1E][L][/color] 进入【微观化学实验台】，探秘 118 种元素合成之道\n• 恭喜你掌握了生存与科研之法，广袤的元素宇宙已为你敞开！",
		"goals": [
			{"id": "complete", "text": "启程迈入自由沙盒", "target": 1}
		]
	}
]

var current_stage_idx: int = 0
var goal_checkboxes: Array[Dictionary] = []
var stage_completed: bool = false
var pulse_time: float = 0.0

func _ready() -> void:
	_apply_styles()
	_bind_events()
	_load_stage(GameState.tutorial_step)
	
	GameState.tutorial_step_changed.connect(func(step):
		_load_stage(step)
	)
	GameState.tutorial_state_changed.connect(func(active):
		visible = active
	)

var _goal_timer: float = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	
	_goal_timer -= delta
	if _goal_timer <= 0.0:
		_goal_timer = 0.25
		_check_current_goals()
	
	if stage_completed and is_instance_valid(btn_next):
		pulse_time += delta * 4.0
		var glow = 0.85 + sin(pulse_time) * 0.15
		btn_next.modulate = Color(glow, 1.0, glow)

func _apply_styles() -> void:
	# 悬浮磨砂现代深蓝玻璃卡片
	var card_box = ThemeStyler.create_card_box(14, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER_FOCUS)
	card_box.content_margin_left = 18
	card_box.content_margin_top = 16
	card_box.content_margin_right = 18
	card_box.content_margin_bottom = 16
	card_box.shadow_color = Color(0.25, 0.20, 0.12, 0.22)
	card_box.shadow_size = 16
	card_box.shadow_offset = Vector2(0, 4)
	panel_container.add_theme_stylebox_override("panel", card_box)
	
	# 进度药丸徽章
	var badge_box = ThemeStyler.create_pill_box(6, Color(0.80, 0.86, 0.93, 0.95), Color(0.18, 0.62, 0.40, 0.80))
	badge_box.content_margin_left = 10
	badge_box.content_margin_right = 10
	badge_box.content_margin_top = 3
	badge_box.content_margin_bottom = 3
	step_badge.add_theme_stylebox_override("panel", badge_box)
	
	# 下一步按钮样式
	var next_box = ThemeStyler.create_pill_box(8, Color(0.80, 0.93, 0.89, 0.95), Color(0.16, 0.62, 0.42, 0.90))
	next_box.content_margin_left = 14
	next_box.content_margin_right = 14
	next_box.content_margin_top = 6
	next_box.content_margin_bottom = 6
	btn_next.add_theme_stylebox_override("normal", next_box)
	
	var next_hover = ThemeStyler.create_pill_box(8, Color(0.80, 0.93, 0.89, 1.00), Color(0.25, 0.62, 0.47, 1.00))
	next_hover.content_margin_left = 14
	next_hover.content_margin_right = 14
	next_hover.content_margin_top = 6
	next_hover.content_margin_bottom = 6
	btn_next.add_theme_stylebox_override("hover", next_hover)
	btn_next.add_theme_stylebox_override("pressed", next_hover)

func _bind_events() -> void:
	btn_next.pressed.connect(_on_next_pressed)
	btn_skip.pressed.connect(_on_skip_pressed)

func _load_stage(stage_idx: int) -> void:
	if stage_idx < 0: stage_idx = 0
	if stage_idx >= STAGES.size():
		_finish_tutorial()
		return
		
	current_stage_idx = stage_idx
	stage_completed = false
	pulse_time = 0.0
	btn_next.modulate = Color.WHITE
	
	var stage = STAGES[current_stage_idx]
	step_badge_lbl.text = "教学指引 · %d / %d" % [current_stage_idx + 1, STAGES.size()]
	title_lbl.text = stage["title"]
	desc_lbl.text = stage["desc"]
	
	# 重建目标清单
	for c in goals_vbox.get_children():
		c.queue_free()
	goal_checkboxes.clear()
	
	for g in stage["goals"]:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		
		var icon_lbl = Label.new()
		icon_lbl.name = "Icon"
		icon_lbl.text = "○"
		icon_lbl.add_theme_font_size_override("font_size", 14)
		icon_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_MUTED)
		hbox.add_child(icon_lbl)
		
		var text_lbl = Label.new()
		text_lbl.name = "Text"
		text_lbl.text = "%s (0 / %d)" % [g["text"], g["target"]]
		text_lbl.add_theme_font_size_override("font_size", 13)
		text_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
		hbox.add_child(text_lbl)
		
		goals_vbox.add_child(hbox)
		goal_checkboxes.append({
			"id": g["id"],
			"target": g["target"],
			"text": g["text"],
			"icon_lbl": icon_lbl,
			"text_lbl": text_lbl
		})
		
	if current_stage_idx == STAGES.size() - 1:
		btn_next.text = "完成教学"
	else:
		btn_next.text = "下一步 ›"
		
	_check_current_goals()

func _check_current_goals() -> void:
	if current_stage_idx >= STAGES.size():
		return
		
	var all_met = true
	
	for item in goal_checkboxes:
		var gid = item["id"]
		var target = item["target"]
		var current = 0
		
		match gid:
			"stone":
				current = GameState.inventory.get_count("stone")
			"stick":
				current = GameState.inventory.get_count("stick")
			"flint":
				current = GameState.inventory.get_count("flint")
			"water":
				current = GameState.inventory.get_count("water")
			"axe":
				current = 1 if GameState.equipped_tools.get("axe", "bare_hands") == "flint_axe" else 0
			"wood":
				current = GameState.inventory.get_count("wood")
			"structure":
				current = 1 if (GameState.built_furnaces.size() > 0 or GameState.inventory.get_count("fire_pit") > 0) else 0
			"complete":
				current = 1
		
		var met = (current >= target)
		if not met:
			all_met = false
			
		item["icon_lbl"].text = "✓" if met else "○"
		item["icon_lbl"].add_theme_color_override("font_color", ThemeStyler.COLOR_SUCCESS if met else ThemeStyler.COLOR_TEXT_MUTED)
		item["text_lbl"].text = "%s (%d / %d)" % [item["text"], min(current, target), target]
		item["text_lbl"].add_theme_color_override("font_color", ThemeStyler.COLOR_SUCCESS if met else ThemeStyler.COLOR_TEXT_PRIMARY)
		
	stage_completed = all_met
	btn_next.disabled = not stage_completed
	if stage_completed:
		status_lbl.text = "阶段目标已达成！点击进入下一步"
		status_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_SUCCESS)
	else:
		status_lbl.text = "请根据上方指引在世界中执行操作"
		status_lbl.add_theme_color_override("font_color", Color(0.28, 0.42, 0.62))

func _on_next_pressed() -> void:
	if not stage_completed:
		return
	if current_stage_idx < STAGES.size() - 1:
		GameState.next_tutorial_step()
	else:
		_finish_tutorial()

func _on_skip_pressed() -> void:
	GameState.skip_tutorial()
	visible = false
	tutorial_skipped.emit()

func _finish_tutorial() -> void:
	GameState.complete_tutorial()
	visible = false
	tutorial_finished.emit()
