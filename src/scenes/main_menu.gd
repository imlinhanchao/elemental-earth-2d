# main_menu.gd
# 游戏主标题菜单控制器: 现代科学全息动态星图、玻尔原子天象仪、平滑交互与开机动效
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const SettingsManager = preload("res://src/core/settings_manager.gd")
const SaveManager = preload("res://src/core/save_manager.gd")
const SaveLoadModal = preload("res://src/ui/save_load_modal.gd")

@onready var main_panel = $SafeMargin/LayoutHBox/MainPanel
@onready var brand_row = $SafeMargin/LayoutHBox/MainPanel/TitleBox/BrandRow
@onready var logo_icon = $SafeMargin/LayoutHBox/MainPanel/TitleBox/BrandRow/LogoIcon
@onready var era_timeline = $SafeMargin/LayoutHBox/MainPanel/TitleBox/EraTimeline
@onready var menu_box = $SafeMargin/LayoutHBox/MainPanel/MenuBox

@onready var btn_continue = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnContinue
@onready var btn_new_game = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnNewGame
@onready var btn_tutorial = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnTutorial
@onready var btn_load_game = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnLoadGame
@onready var btn_settings = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnSettings
@onready var btn_guide = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnGuide
@onready var btn_quit = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnQuit

@onready var right_panel = $SafeMargin/LayoutHBox/RightPanel
@onready var archive_card = $SafeMargin/LayoutHBox/RightPanel/ArchiveCard

@onready var save_load_modal = $SaveLoadModal
@onready var settings_modal = $SettingsModal
@onready var guide_modal = $GuideModal

# 确认弹窗
@onready var confirm_dialog = $ConfirmDialog
@onready var confirm_text = $ConfirmDialog/Margin/VBox/ConfirmText
@onready var btn_confirm_ok = $ConfirmDialog/Margin/VBox/BtnHBox/BtnOk
@onready var btn_confirm_cancel = $ConfirmDialog/Margin/VBox/BtnHBox/BtnCancel

var pending_action: Callable
var bg_time: float = 0.0
var mouse_parallax: Vector2 = Vector2.ZERO

# 粒子系统与天象仪数据
var particles: Array[Dictionary] = []
const PARTICLE_COUNT: int = 38
const SATELLITE_ELEMENTS = [
	{"sym": "H", "num": 1, "name": "氢", "col": Color(0.38, 0.82, 1.0)},
	{"sym": "C", "num": 6, "name": "碳", "col": Color(0.25, 0.85, 0.55)},
	{"sym": "Fe", "num": 26, "name": "铁", "col": Color(0.85, 0.88, 0.95)},
	{"sym": "Cu", "num": 29, "name": "铜", "col": Color(1.0, 0.72, 0.35)},
	{"sym": "Nd", "num": 60, "name": "钕", "col": Color(0.75, 0.55, 1.0)},
	{"sym": "U", "num": 92, "name": "铀", "col": Color(0.4, 0.95, 0.45)}
]

func _ready() -> void:
	SettingsManager.load_settings()
	var theme = ThemeStyler.create_scientific_theme()
	self.theme = theme
	save_load_modal.theme = theme
	settings_modal.theme = theme
	guide_modal.theme = theme
	confirm_dialog.theme = theme
	
	save_load_modal.visible = false
	settings_modal.visible = false
	guide_modal.visible = false
	confirm_dialog.visible = false
	
	_init_particles()
	_setup_logo()
	_setup_era_timeline()
	_setup_buttons()
	_setup_archive_card()
	_bind_buttons()
	_refresh_continue_button()
	_play_entrance_animation()
	
	save_load_modal.slot_selected.connect(_on_slot_selected_from_modal)
	# 玩家看主菜单时在后台线程预载世界场景 (含 HUD 与全部弹窗)，点击进入时无需同步读盘
	ResourceLoader.load_threaded_request(WORLD_SCENE)
	
	# 默认聚焦
	if btn_continue.visible:
		btn_continue.grab_focus()
	else:
		btn_new_game.grab_focus()
		
	# 命令行参数抓取截图支持
	var all_args = OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for arg in all_args:
		if arg == "--screenshot-menu":
			_capture_screenshot_after_delay()
			return
		elif arg.contains("screenshot"):
			_enter_world()
			return

const WORLD_SCENE := "res://src/scenes/world.tscn"
var _entering_world: bool = false

func _enter_world() -> void:
	if _entering_world:
		return
	_entering_world = true
	set_process_input(false)
	# 预载尚未完成时逐帧等待 (通常在主菜单停留期间已完成)
	while ResourceLoader.load_threaded_get_status(WORLD_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed = ResourceLoader.load_threaded_get(WORLD_SCENE)
	if packed is PackedScene:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(WORLD_SCENE)

func _capture_screenshot_after_delay() -> void:
	await get_tree().create_timer(1.2).timeout
	var img = get_viewport().get_texture().get_image()
	if img:
		var out_path = ProjectSettings.globalize_path("res://screenshot_main_menu.png")
		img.save_png(out_path)
		print("[Screenshot] 主菜单截图成功生成: %s" % out_path)
	get_tree().quit(0)

func _process(delta: float) -> void:
	bg_time += delta
	
	# 平滑视差插值
	var vp_size = get_viewport_rect().size
	var mpos = get_viewport().get_mouse_position()
	var target_parallax = (mpos - vp_size * 0.5) * 0.03
	mouse_parallax = mouse_parallax.lerp(target_parallax, delta * 4.0)
	
	# 更新浮动粒子位置
	for p in particles:
		p["pos"] += p["vel"] * delta
		p["phase"] += delta * p["phase_speed"]
		if p["pos"].y < -20.0:
			p["pos"].y = vp_size.y + 20.0
			p["pos"].x = randf_range(0.0, vp_size.x)
		if p["pos"].x < -20.0:
			p["pos"].x = vp_size.x + 20.0
		elif p["pos"].x > vp_size.x + 20.0:
			p["pos"].x = -20.0
			
	# Logo 轻微呼吸悬浮
	if logo_icon:
		logo_icon.position.y = sin(bg_time * 2.2) * 3.0
		
	queue_redraw()

func _init_particles() -> void:
	particles.clear()
	var syms = ["H", "He", "Li", "C", "N", "O", "Fe", "Cu", "Au", "U", "Si", "P", ""]
	for i in range(PARTICLE_COUNT):
		var sym = syms[randi() % syms.size()] if i % 3 == 0 else ""
		particles.append({
			"pos": Vector2(randf_range(100.0, 1800.0), randf_range(50.0, 1050.0)),
			"vel": Vector2(randf_range(-12.0, 12.0), randf_range(-25.0, -8.0)),
			"size": randf_range(1.5, 3.8) if sym == "" else 10.0,
			"phase": randf_range(0.0, TAU),
			"phase_speed": randf_range(0.8, 2.2),
			"base_alpha": randf_range(0.15, 0.45) if sym == "" else randf_range(0.25, 0.55),
			"symbol": sym
		})

func _setup_logo() -> void:
	if not logo_icon:
		return
	var tex: Texture2D = ItemIconManager.load_texture("res://assets/icons/game_logo.png")
	if tex:
		logo_icon.texture = tex
		logo_icon.custom_minimum_size = Vector2(52, 52)

func _setup_era_timeline() -> void:
	if not era_timeline:
		return
	for c in era_timeline.get_children():
		c.queue_free()
		
	var eras = [
		{"name": "石器时代", "icon": "res://assets/icons/era_stone.svg", "col": Color(0.8, 0.8, 0.85)},
		{"name": "炼金时代", "icon": "res://assets/icons/era_alchemy.svg", "col": Color(0.95, 0.75, 0.35)},
		{"name": "近代化学", "icon": "res://assets/icons/era_modern_chem.svg", "col": Color(0.38, 0.82, 1.0)},
		{"name": "电化学", "icon": "res://assets/icons/era_electrochem.svg", "col": Color(0.35, 0.95, 0.75)},
		{"name": "稀土时代", "icon": "res://assets/icons/era_rare_earth.svg", "col": Color(0.8, 0.6, 1.0)},
		{"name": "原子时代", "icon": "res://assets/icons/era_atomic_age.svg", "col": Color(0.4, 0.95, 0.5)}
	]
	
	for i in range(eras.size()):
		var e = eras[i]
		var chip = PanelContainer.new()
		var chip_box = ThemeStyler.create_pill_box(10, Color(0.16, 0.145, 0.13, 0.85), Color(0.33, 0.30, 0.26, 0.65))
		chip_box.content_margin_left = 6
		chip_box.content_margin_right = 8
		chip_box.content_margin_top = 2
		chip_box.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", chip_box)
		
		var chip_hbox = HBoxContainer.new()
		chip_hbox.add_theme_constant_override("separation", 4)
		chip.add_child(chip_hbox)
		
		var chip_icon = TextureRect.new()
		chip_icon.custom_minimum_size = Vector2(14, 14)
		if ResourceLoader.exists(e["icon"]):
			chip_icon.texture = load(e["icon"])
		chip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip_hbox.add_child(chip_icon)
		
		var chip_lbl = Label.new()
		chip_lbl.text = e["name"]
		chip_lbl.add_theme_font_size_override("font_size", 12)
		chip_lbl.add_theme_color_override("font_color", e["col"])
		chip_hbox.add_child(chip_lbl)
		
		era_timeline.add_child(chip)
		
		if i < eras.size() - 1:
			var arrow = Label.new()
			arrow.text = "›"
			arrow.add_theme_font_size_override("font_size", 12)
			arrow.add_theme_color_override("font_color", Color(0.45, 0.41, 0.36))
			era_timeline.add_child(arrow)

func _setup_buttons() -> void:
	_configure_menu_btn(btn_continue, "继续游戏", "RESUME EXPLORATION", "res://assets/icons/save.svg", "ENTER")
	_configure_menu_btn(btn_new_game, "开启新程", "NEW CHRONICLE", "res://assets/icons/tab_craft.svg", "N")
	_configure_menu_btn(btn_tutorial, "新手教程", "GUIDED TUTORIAL", "res://assets/icons/tab_experiment.svg", "U")
	_configure_menu_btn(btn_load_game, "载入档案", "ARCHIVES & SLOTS", "res://assets/icons/load.svg", "L")
	_configure_menu_btn(btn_settings, "游戏设置", "SYSTEM SETTINGS", "res://assets/icons/settings.svg", "O")
	_configure_menu_btn(btn_guide, "拓荒图录", "SURVIVAL GUIDE", "res://assets/icons/periodic_table.svg", "H")
	_configure_menu_btn(btn_quit, "退出游戏", "EXIT TO DESKTOP", "res://assets/icons/tab_production.svg", "ESC")

func _configure_menu_btn(btn: Button, title: String, en_title: String, icon_res: String, key_hint: String) -> void:
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 48)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_ALL
	
	for c in btn.get_children():
		c.queue_free()
		
	var hbox = HBoxContainer.new()
	hbox.name = "ContentHBox"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 0
	hbox.offset_right = 0
	hbox.offset_top = 0
	hbox.offset_bottom = 0
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 14)
	btn.add_child(hbox)
	
	# 1. 左侧竖向电光青发光线柱 (Accent Indicator)
	var indicator = ColorRect.new()
	indicator.name = "Indicator"
	indicator.custom_minimum_size = Vector2(4, 28)
	indicator.color = Color(0.85, 0.60, 0.30, 0.0) # 默认隐藏
	indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(indicator)
	
	# 2. 专属矢量高清图标
	var icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(22, 22)
	if ResourceLoader.exists(icon_res):
		icon_rect.texture = load(icon_res)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)
	
	# 3. 双行文本区域 (中英文)
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_vbox.add_theme_constant_override("separation", 1)
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)
	
	var title_lbl = Label.new()
	title_lbl.name = "TitleLbl"
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(title_lbl)
	
	var en_lbl = Label.new()
	en_lbl.name = "EnLbl"
	en_lbl.text = en_title
	en_lbl.add_theme_font_size_override("font_size", 12)
	en_lbl.add_theme_color_override("font_color", Color(0.55, 0.51, 0.45))
	en_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(en_lbl)
	
	# 4. 右侧按键徽章
	var badge_margin = MarginContainer.new()
	badge_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_margin.add_theme_constant_override("margin_right", 12)
	badge_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(badge_margin)
	
	var badge_panel = PanelContainer.new()
	badge_panel.name = "KeyBadge"
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style = ThemeStyler.create_pill_box(6, Color(0.12, 0.11, 0.10, 0.95), Color(0.33, 0.30, 0.26, 0.7))
	badge_style.content_margin_left = 8
	badge_style.content_margin_right = 8
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	badge_margin.add_child(badge_panel)
	
	var key_lbl = Label.new()
	key_lbl.name = "KeyLbl"
	key_lbl.text = key_hint
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", Color(0.68, 0.63, 0.56))
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_child(key_lbl)
	
	# 按钮本体底板样式
	var norm_box = ThemeStyler.create_card_box(8, Color(0.14, 0.13, 0.12, 0.85), Color(0.30, 0.27, 0.23, 0.6))
	norm_box.content_margin_left = 0
	norm_box.content_margin_right = 0
	norm_box.content_margin_top = 0
	norm_box.content_margin_bottom = 0
	
	var hover_box = ThemeStyler.create_card_box(8, Color(0.20, 0.18, 0.16, 0.95), Color(0.85, 0.60, 0.30, 0.9))
	hover_box.content_margin_left = 0
	hover_box.content_margin_right = 0
	hover_box.content_margin_top = 0
	hover_box.content_margin_bottom = 0
	hover_box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	hover_box.shadow_size = 10
	
	btn.add_theme_stylebox_override("normal", norm_box)
	btn.add_theme_stylebox_override("hover", hover_box)
	btn.add_theme_stylebox_override("pressed", hover_box)
	btn.add_theme_stylebox_override("focus", hover_box)
	
	# 悬停与聚焦平移动效
	var on_enter = func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "position:x", 12.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(indicator, "color", Color(0.85, 0.60, 0.30, 1.0), 0.15)
		tw.tween_property(title_lbl, "theme_override_colors/font_color", Color(1.0, 1.0, 1.0), 0.15)
		tw.tween_property(en_lbl, "theme_override_colors/font_color", Color(0.93, 0.70, 0.40), 0.15)
		tw.tween_property(key_lbl, "theme_override_colors/font_color", Color(0.93, 0.70, 0.40), 0.15)
		
	var on_exit = func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "position:x", 0.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(indicator, "color", Color(0.85, 0.60, 0.30, 0.0), 0.15)
		tw.tween_property(title_lbl, "theme_override_colors/font_color", Color(0.96, 0.93, 0.87), 0.15)
		tw.tween_property(en_lbl, "theme_override_colors/font_color", Color(0.55, 0.51, 0.45), 0.15)
		tw.tween_property(key_lbl, "theme_override_colors/font_color", Color(0.68, 0.63, 0.56), 0.15)
		
	btn.mouse_entered.connect(on_enter)
	btn.mouse_exited.connect(on_exit)
	btn.focus_entered.connect(on_enter)
	btn.focus_exited.connect(on_exit)

func _setup_archive_card() -> void:
	if not archive_card:
		return
	var card_box = ThemeStyler.create_card_box(12, ThemeStyler.COLOR_BG_SOLID, Color(0.85, 0.60, 0.30, 0.6))
	card_box.content_margin_left = 18
	card_box.content_margin_top = 16
	card_box.content_margin_right = 18
	card_box.content_margin_bottom = 16
	card_box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	card_box.shadow_size = 14
	card_box.shadow_offset = Vector2(0, 4)
	archive_card.add_theme_stylebox_override("panel", card_box)
	
	var vbox = archive_card.get_node_or_null("CardMargin/CardVBox")
	if not vbox:
		return
		
	var header_lbl = vbox.get_node("CardHeader") as Label
	var body_lbl = vbox.get_node("CardBody") as Label
	var hint_lbl = vbox.get_node("CardHint") as Label
	
	var latest_slot = SaveManager.get_latest_save_slot()
	if latest_slot != "":
		var meta = SaveManager.get_slot_meta(latest_slot)
		header_lbl.text = "【开拓档案快照 · %s】" % meta.get("slot_name", "自动存档")
		header_lbl.add_theme_color_override("font_color", Color(0.93, 0.70, 0.40))
		
		var era_name = meta.get("era_name", "石器时代")
		var ptime = meta.get("playtime_formatted", "00:00")
		var dtime = meta.get("datetime", "")
		body_lbl.text = "当前时代：%s\n累计探索时长：%s   保存时间：%s" % [era_name, ptime, dtime]
		hint_lbl.text = "按 [ENTER] 或点击【继续游戏】无缝接入世界"
		hint_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.55))
	else:
		header_lbl.text = "【初临序章 · 元素宏图】"
		header_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
		body_lbl.text = "万物皆由 118 种元素筑就。\n拾取地表碎石与燧石，点亮属于人类文明的科学之火。"
		hint_lbl.text = "按 [N] 开启全新的拓荒征程"
		hint_lbl.add_theme_color_override("font_color", Color(0.93, 0.70, 0.40))

func _play_entrance_animation() -> void:
	# 入场级联展开动效
	main_panel.modulate.a = 0.0
	main_panel.position.x -= 30.0
	
	if archive_card:
		archive_card.modulate.a = 0.0
		archive_card.position.y += 20.0
		
	var tw = create_tween().set_parallel(true)
	tw.tween_property(main_panel, "modulate:a", 1.0, 0.45).set_delay(0.05)
	tw.tween_property(main_panel, "position:x", main_panel.position.x + 30.0, 0.55).set_delay(0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if archive_card:
		tw.tween_property(archive_card, "modulate:a", 1.0, 0.45).set_delay(0.30)
		tw.tween_property(archive_card, "position:y", archive_card.position.y - 20.0, 0.50).set_delay(0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var size = get_viewport_rect().size
	
	# 1. 深度夜蓝底色
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.070, 0.064, 0.058, 1.0))
	
	var center = Vector2(size.x * 0.71, size.y * 0.46) + mouse_parallax
	
	# 2. 径向多层天象仪能量微光
	var glow_layers = [
		{"r": 480.0, "col": Color(0.14, 0.10, 0.06, 0.08)},
		{"r": 320.0, "col": Color(0.22, 0.15, 0.08, 0.14)},
		{"r": 180.0, "col": Color(0.40, 0.26, 0.12, 0.22)},
		{"r": 90.0, "col": Color(0.85, 0.58, 0.28, 0.32)}
	]
	for g in glow_layers:
		draw_circle(center, g["r"] + sin(bg_time * 1.5) * 6.0, g["col"])
		
	# 3. 背景微弱六边形几何能量晶格
	_draw_background_hex_lattice(center, size)
	
	# 4. 浮动元素离子与能量微光粒子
	_draw_particles()
	
	# 5. 玻尔原子天象仪轨道与高速电子流
	_draw_atomic_orbitals(center)
	
	# 6. 外层量子环与 6 颗文明代表元素共振卫星
	_draw_elemental_satellites(center)

func _draw_background_hex_lattice(center: Vector2, size: Vector2) -> void:
	var hex_r = 72.0
	var w = hex_r * sqrt(3.0)
	var h = hex_r * 1.5
	var cols = int(ceil(size.x / w)) + 2
	var rows = int(ceil(size.y / h)) + 2
	
	for col in range(cols):
		for row in range(rows):
			var cx = col * w + (w * 0.5 if (row % 2 == 1) else 0.0)
			var cy = row * h
			var dist = (Vector2(cx, cy) - center).length()
			if dist < 650.0:
				var wave = sin(bg_time * 0.8 - dist * 0.008)
				var alpha = clampf(0.015 + 0.025 * wave, 0.005, 0.045) * (1.0 - dist / 650.0)
				_draw_hex_wire(Vector2(cx, cy), hex_r * 0.95, Color(0.85, 0.60, 0.30, alpha))

func _draw_particles() -> void:
	var font = get_theme_default_font()
	for p in particles:
		var pulse = sin(p["phase"]) * 0.3 + 0.7
		var alpha = p["base_alpha"] * pulse
		if p["symbol"] != "" and font:
			var col = Color(0.93, 0.70, 0.40, alpha)
			draw_string(font, p["pos"], p["symbol"], HORIZONTAL_ALIGNMENT_CENTER, -1, 11, col)
		else:
			var col = Color(0.38, 0.75, 1.0, alpha * 0.6)
			draw_circle(p["pos"], p["size"] * pulse, col)

func _draw_atomic_orbitals(center: Vector2) -> void:
	# 核心原子核
	var nuc_pulse = sin(bg_time * 2.5) * 3.0
	draw_circle(center, 26.0 + nuc_pulse, Color(0.60, 0.38, 0.18, 0.35))
	draw_circle(center, 15.0 + nuc_pulse * 0.5, Color(0.85, 0.60, 0.30, 0.75))
	draw_circle(center, 7.0, Color(0.98, 0.95, 0.88, 1.0))
	
	# 3 个核心互旋核子
	for k in range(3):
		var k_ang = bg_time * 1.8 + k * (TAU / 3.0)
		var k_pos = center + Vector2(cos(k_ang), sin(k_ang)) * 14.0
		var k_col = Color(0.93, 0.70, 0.40) if k % 2 == 0 else Color(1.0, 0.75, 0.35)
		draw_circle(k_pos, 4.0, k_col)
		
	# 4 条倾斜玻尔椭圆轨道与发光电子流
	var orbits = [
		{"tilt": deg_to_rad(32.0), "rx": 240.0, "ry": 90.0, "speed": 1.4, "electrons": 2},
		{"tilt": deg_to_rad(-42.0), "rx": 280.0, "ry": 105.0, "speed": -1.1, "electrons": 2},
		{"tilt": deg_to_rad(80.0), "rx": 210.0, "ry": 75.0, "speed": 1.7, "electrons": 1},
		{"tilt": deg_to_rad(-78.0), "rx": 320.0, "ry": 120.0, "speed": -0.85, "electrons": 1}
	]
	
	for o in orbits:
		# 绘制平滑椭圆轨道线
		var pts: PackedVector2Array = []
		var segs = 64
		for i in range(segs + 1):
			var a = (float(i) / float(segs)) * TAU
			var raw = Vector2(cos(a) * o["rx"], sin(a) * o["ry"])
			pts.append(center + raw.rotated(o["tilt"]))
		draw_polyline(pts, Color(0.85, 0.60, 0.30, 0.22), 1.0, true)
		
		# 绘制轨道上的高速电子与发光拖尾
		var num_e = o["electrons"]
		for e_idx in range(num_e):
			var base_t = bg_time * o["speed"] + e_idx * (TAU / float(num_e))
			
			# 电子拖尾 ribbons
			var trail_len = 10
			for t_step in range(trail_len):
				var past_t = base_t - float(t_step) * 0.035 * sign(o["speed"])
				var raw_p = Vector2(cos(past_t) * o["rx"], sin(past_t) * o["ry"]).rotated(o["tilt"])
				var trail_pos = center + raw_p
				var trail_alpha = (1.0 - float(t_step) / float(trail_len)) * 0.35
				draw_circle(trail_pos, 2.5 * (1.0 - float(t_step) / float(trail_len)), Color(0.85, 0.60, 0.30, trail_alpha))
				
			# 电子核心发光点
			var cur_p = Vector2(cos(base_t) * o["rx"], sin(base_t) * o["ry"]).rotated(o["tilt"])
			var e_pos = center + cur_p
			draw_circle(e_pos, 7.5, Color(0.85, 0.60, 0.30, 0.35))
			draw_circle(e_pos, 3.2, Color(1.0, 1.0, 1.0, 1.0))

func _draw_elemental_satellites(center: Vector2) -> void:
	var font = get_theme_default_font()
	var sat_r = 350.0 + sin(bg_time * 0.8) * 8.0
	
	# 外层量子共振环
	var ring_pts: PackedVector2Array = []
	for i in range(73):
		var a = (float(i) / 72.0) * TAU
		ring_pts.append(center + Vector2(cos(a), sin(a)) * sat_r)
	draw_polyline(ring_pts, Color(0.85, 0.60, 0.30, 0.14), 1.0, true)
	
	# 6 颗代表性元素公转卫星
	for idx in range(SATELLITE_ELEMENTS.size()):
		var info = SATELLITE_ELEMENTS[idx]
		var sat_angle = bg_time * 0.08 + idx * (TAU / float(SATELLITE_ELEMENTS.size()))
		var sat_pos = center + Vector2(cos(sat_angle), sin(sat_angle)) * sat_r
		
		# 核心连接脉冲光束
		draw_line(center, sat_pos, Color(0.85, 0.60, 0.30, 0.10), 1.0)
		var pulse_t = fmod(bg_time * 0.5 + idx * 0.16, 1.0)
		var pulse_pos = center.lerp(sat_pos, pulse_t)
		draw_circle(pulse_pos, 2.5, Color(0.93, 0.70, 0.40, 0.7))
		
		# 六边形卫星外框与底板
		var hex_size = 22.0
		_draw_hex_filled(sat_pos, hex_size, Color(0.14, 0.13, 0.12, 0.90))
		_draw_hex_wire(sat_pos, hex_size, info["col"])
		
		# 绘制元素符号与原子序数
		if font:
			draw_string(font, sat_pos + Vector2(0, 4), info["sym"], HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)
			draw_string(font, sat_pos + Vector2(0, 16), str(info["num"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 9, info["col"])

func _draw_hex_wire(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	pts.append(pts[0])
	draw_polyline(pts, color, 1.0, true)

func _draw_hex_filled(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(pts, color)

func _bind_buttons() -> void:
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_tutorial.pressed.connect(_on_tutorial_pressed)
	btn_load_game.pressed.connect(_on_load_game_pressed)
	btn_settings.pressed.connect(func(): settings_modal.open())
	btn_guide.pressed.connect(func(): guide_modal.visible = true)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	btn_confirm_cancel.pressed.connect(func(): confirm_dialog.visible = false)
	btn_confirm_ok.pressed.connect(func():
		confirm_dialog.visible = false
		if pending_action.is_valid():
			pending_action.call()
	)
	
	var btn_guide_close = guide_modal.get_node_or_null("GuideModal/VBox/Header/BtnClose")
	if not btn_guide_close:
		btn_guide_close = guide_modal.get_node_or_null("VBox/Header/HBox/BtnClose")
	if btn_guide_close:
		btn_guide_close.pressed.connect(func(): guide_modal.visible = false)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if confirm_dialog.visible:
			confirm_dialog.visible = false
			get_viewport().set_input_as_handled()
		elif guide_modal.visible:
			guide_modal.visible = false
			get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if confirm_dialog.visible:
				confirm_dialog.visible = false
			elif guide_modal.visible:
				guide_modal.visible = false
			elif not save_load_modal.visible and not settings_modal.visible:
				_on_quit_pressed()
			get_viewport().set_input_as_handled()
		elif not confirm_dialog.visible and not guide_modal.visible and not save_load_modal.visible and not settings_modal.visible:
			if event.keycode == KEY_ENTER and btn_continue.visible:
				_on_continue_pressed()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_N:
				_on_new_game_pressed()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_U:
				_on_tutorial_pressed()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_L:
				_on_load_game_pressed()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_O:
				settings_modal.open()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_H:
				guide_modal.visible = true
				get_viewport().set_input_as_handled()

func _refresh_continue_button() -> void:
	var latest_slot = SaveManager.get_latest_save_slot()
	if latest_slot != "":
		btn_continue.visible = true
	else:
		btn_continue.visible = false

func _on_continue_pressed() -> void:
	var latest_slot = SaveManager.get_latest_save_slot()
	if latest_slot == "":
		latest_slot = "auto"
		
	SaveManager.pending_load_slot = latest_slot
	_enter_world()

func _on_new_game_pressed() -> void:
	var latest_slot = SaveManager.get_latest_save_slot()
	if latest_slot != "":
		confirm_text.text = "开启新的征程将重置当前的探索环境。\n确认开启新游戏吗？"
		pending_action = func():
			GameState.reset_to_new_game()
			SaveManager.pending_load_slot = ""
			if not SettingsManager.is_tutorial_completed():
				GameState.start_tutorial()
			_enter_world()
		confirm_dialog.visible = true
		btn_confirm_ok.grab_focus()
	else:
		GameState.reset_to_new_game()
		SaveManager.pending_load_slot = ""
		if not SettingsManager.is_tutorial_completed():
			GameState.start_tutorial()
		_enter_world()

func _on_tutorial_pressed() -> void:
	var latest_slot = SaveManager.get_latest_save_slot()
	if latest_slot != "":
		confirm_text.text = "进入新手教程将重置当前世界状态以开启教学演练。\n确认开启新手教程吗？"
		pending_action = func():
			GameState.reset_to_new_game()
			SaveManager.pending_load_slot = ""
			GameState.start_tutorial()
			_enter_world()
		confirm_dialog.visible = true
		btn_confirm_ok.grab_focus()
	else:
		GameState.reset_to_new_game()
		SaveManager.pending_load_slot = ""
		GameState.start_tutorial()
		_enter_world()

func _on_load_game_pressed() -> void:
	save_load_modal.open(SaveLoadModal.Mode.LOAD)

func _on_slot_selected_from_modal(slot_id: String, _mode: int) -> void:
	SaveManager.pending_load_slot = slot_id
	_enter_world()

func _on_quit_pressed() -> void:
	confirm_text.text = "确认退出《元素纪元》并返回桌面吗？"
	pending_action = func():
		get_tree().quit(0)
	confirm_dialog.visible = true
	btn_confirm_ok.grab_focus()
