# main_menu.gd
# 游戏主标题菜单控制器: 扁平极简战略规范，键盘导航，ESC/右键返回
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const SettingsManager = preload("res://src/core/settings_manager.gd")
const SaveManager = preload("res://src/core/save_manager.gd")
const SaveLoadModal = preload("res://src/ui/save_load_modal.gd")

@onready var btn_continue = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnContinue
@onready var btn_new_game = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnNewGame
@onready var btn_load_game = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnLoadGame
@onready var btn_settings = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnSettings
@onready var btn_guide = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnGuide
@onready var btn_quit = $SafeMargin/LayoutHBox/MainPanel/MenuBox/BtnQuit

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
	
	# 默认聚焦
	if btn_continue.visible:
		btn_continue.grab_focus()
	else:
		btn_new_game.grab_focus()
		
	for arg in OS.get_cmdline_args():
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
	# 绘制深色极简背景面板与科技网格
	var size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 1.0))
	
	# 右侧大区域绘制典雅扁平几何六边形星图
	var center = Vector2(size.x * 0.72, size.y * 0.5)
	for r in range(1, 5):
		var rad = 120.0 * r + sin(bg_time * 0.5 + r) * 5.0
		var col = Color(0.298, 0.553, 1.0, 0.04 + 0.02 * (5 - r))
		_draw_hex_wire(center, rad, col)

func _draw_hex_wire(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	pts.append(pts[0])
	draw_polyline(pts, color, 1.0, true)

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
	
	var btn_guide_close = guide_modal.get_node("GuideModal/VBox/Header/BtnClose") if guide_modal.has_node("GuideModal/VBox/Header/BtnClose") else guide_modal.get_node("VBox/Header/HBox/BtnClose")
	if btn_guide_close:
		btn_guide_close.pressed.connect(func(): guide_modal.visible = false)

func _input(event: InputEvent) -> void:
	# 右键返回或取消
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if confirm_dialog.visible:
			confirm_dialog.visible = false
			get_viewport().set_input_as_handled()
		elif guide_modal.visible:
			guide_modal.visible = false
			get_viewport().set_input_as_handled()
		return
		
	# 键盘快捷键响应
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
	get_tree().change_scene_to_file("res://src/scenes/world.tscn")

func _on_new_game_pressed() -> void:
	var latest_slot = SaveManager.get_latest_save_slot()
	if latest_slot != "":
		confirm_text.text = "开启新的征程将重置当前的探索环境。\n确认开启新游戏吗？"
		pending_action = func():
			GameState.reset_to_new_game()
			SaveManager.pending_load_slot = ""
			get_tree().change_scene_to_file("res://src/scenes/world.tscn")
		confirm_dialog.visible = true
		btn_confirm_ok.grab_focus()
	else:
		GameState.reset_to_new_game()
		SaveManager.pending_load_slot = ""
		get_tree().change_scene_to_file("res://src/scenes/world.tscn")

func _on_load_game_pressed() -> void:
	save_load_modal.open(SaveLoadModal.Mode.LOAD)

func _on_slot_selected_from_modal(slot_id: String, _mode: int) -> void:
	SaveManager.pending_load_slot = slot_id
	get_tree().change_scene_to_file("res://src/scenes/world.tscn")

func _on_quit_pressed() -> void:
	confirm_text.text = "确认退出《元素纪元》并返回桌面吗？"
	pending_action = func():
		get_tree().quit(0)
	confirm_dialog.visible = true
	btn_confirm_ok.grab_focus()
