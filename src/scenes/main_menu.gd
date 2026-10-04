# main_menu.gd
# 游戏主标题菜单控制器: 业界通用开始、继续、读档、设置、图鉴与退出交互
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const SettingsManager = preload("res://src/core/settings_manager.gd")
const SaveManager = preload("res://src/core/save_manager.gd")
const SaveLoadModalScene = preload("res://src/ui/save_load_modal.gd")

@onready var btn_continue = $CenterContainer/VBox/MenuBox/BtnContinue
@onready var btn_new_game = $CenterContainer/VBox/MenuBox/BtnNewGame
@onready var btn_load_game = $CenterContainer/VBox/MenuBox/BtnLoadGame
@onready var btn_settings = $CenterContainer/VBox/MenuBox/BtnSettings
@onready var btn_guide = $CenterContainer/VBox/MenuBox/BtnGuide
@onready var btn_quit = $CenterContainer/VBox/MenuBox/BtnQuit

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
	
	_bind_buttons()
	_refresh_continue_button()
	
	save_load_modal.slot_selected.connect(_on_slot_selected_from_modal)
	
	for arg in OS.get_cmdline_user_args():
		if arg == "--screenshot":
			_capture_screenshot_after_delay()

func _capture_screenshot_after_delay() -> void:
	await get_tree().create_timer(0.8).timeout
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("/Users/hancel/Documents/project/elemental-earth-2d/screenshot_main_menu.png")
		print("✅ [Screenshot] 主菜单截图成功生成: /Users/hancel/Documents/project/elemental-earth-2d/screenshot_main_menu.png")
	get_tree().quit(0)

func _process(delta: float) -> void:
	bg_time += delta
	queue_redraw()

func _draw() -> void:
	# 绘制背景深色渐变与典雅微观元素环境微粒
	var size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.12, 1.0))
	
	# 绘制装饰性金色科技六边形几何纹路
	var center = size * 0.5
	for r in range(1, 4):
		var rad = 140.0 * r + sin(bg_time * 0.8 + r) * 6.0
		var col = Color(0.78, 0.58, 0.22, 0.06 + 0.02 * r)
		_draw_hex_wire(center, rad, col)

func _draw_hex_wire(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	pts.append(pts[0])
	draw_polyline(pts, color, 1.5, true)

func _bind_buttons() -> void:
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_new_game.pressed.connect(_on_new_game_pressed)
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
	
	var btn_guide_close = guide_modal.get_node("Margin/VBox/Header/BtnClose")
	if btn_guide_close:
		btn_guide_close.pressed.connect(func(): guide_modal.visible = false)

func _refresh_continue_button() -> void:
	var latest_slot = SaveManager.get_latest_save_slot()
	if latest_slot != "":
		var meta = SaveManager.get_slot_meta(latest_slot)
		btn_continue.disabled = false
		btn_continue.text = "▶️ 继续游戏 (%s · %s)" % [meta["era_name"], meta["playtime_formatted"]]
	else:
		btn_continue.disabled = true
		btn_continue.text = "▶️ 继续游戏 (暂无存档)"

func _on_continue_pressed() -> void:
	var latest = SaveManager.get_latest_save_slot()
	if latest != "":
		SaveManager.pending_load_slot = latest
		get_tree().change_scene_to_file("res://src/scenes/world.tscn")

func _on_new_game_pressed() -> void:
	if SaveManager.has_any_save():
		confirm_text.text = "⚠️ 确认开始新游戏吗？\n你将开启一段全新的石器时代拓荒之旅。"
		pending_action = func():
			GameState.reset_to_new_game()
			SaveManager.pending_load_slot = ""
			get_tree().change_scene_to_file("res://src/scenes/world.tscn")
		confirm_dialog.visible = true
	else:
		GameState.reset_to_new_game()
		SaveManager.pending_load_slot = ""
		get_tree().change_scene_to_file("res://src/scenes/world.tscn")

func _on_load_game_pressed() -> void:
	save_load_modal.open(SaveLoadModalScene.Mode.LOAD)

func _on_slot_selected_from_modal(slot_id: String, mode: int) -> void:
	if mode == SaveLoadModalScene.Mode.LOAD:
		SaveManager.pending_load_slot = slot_id
		get_tree().change_scene_to_file("res://src/scenes/world.tscn")

func _on_quit_pressed() -> void:
	confirm_text.text = "✕ 确认退出《元素纪元 2D》吗？"
	pending_action = func():
		get_tree().quit(0)
	confirm_dialog.visible = true
