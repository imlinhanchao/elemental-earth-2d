# pause_menu.gd
# 局内暂停与系统菜单 (扁平极简规范，ESC/右键返回，暂停物理时间)
extends Control

signal resume_requested
signal save_requested
signal load_requested
signal settings_requested
signal return_to_main_menu_requested
signal quit_game_requested

@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose
@onready var btn_resume = $CenterPanel/VBox/Content/MenuBox/BtnResume
@onready var btn_save = $CenterPanel/VBox/Content/MenuBox/BtnSave
@onready var btn_load = $CenterPanel/VBox/Content/MenuBox/BtnLoad
@onready var btn_settings = $CenterPanel/VBox/Content/MenuBox/BtnSettings
@onready var btn_main_menu = $CenterPanel/VBox/Content/MenuBox/BtnMainMenu
@onready var btn_quit = $CenterPanel/VBox/Content/MenuBox/BtnQuit

# 退出与返回主菜单确认框
@onready var confirm_dialog = $ConfirmDialog
@onready var confirm_label = $ConfirmDialog/Margin/VBox/ConfirmLabel
@onready var btn_confirm_ok = $ConfirmDialog/Margin/VBox/BtnHBox/BtnOk
@onready var btn_confirm_cancel = $ConfirmDialog/Margin/VBox/BtnHBox/BtnCancel

var pending_action: Callable

func _ready() -> void:
	ModalStack.track(self)
	visible = false
	confirm_dialog.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	btn_close.pressed.connect(close)
	btn_resume.pressed.connect(close)
	
	btn_save.pressed.connect(func():
		save_requested.emit()
	)
	btn_load.pressed.connect(func():
		load_requested.emit()
	)
	btn_settings.pressed.connect(func():
		settings_requested.emit()
	)
	
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	btn_confirm_cancel.pressed.connect(func(): confirm_dialog.visible = false)
	btn_confirm_ok.pressed.connect(func():
		confirm_dialog.visible = false
		if pending_action.is_valid():
			pending_action.call()
	)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	confirm_dialog.visible = false
	get_tree().paused = true
	btn_resume.grab_focus()

func close() -> void:
	visible = false
	confirm_dialog.visible = false
	get_tree().paused = false
	resume_requested.emit()

func _input(event: InputEvent) -> void:
	if not visible or not ModalStack.is_top(self):
		return
		
	# 右键返回或取消
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if confirm_dialog.visible:
			confirm_dialog.visible = false
			get_viewport().set_input_as_handled()
		else:
			close()
			get_viewport().set_input_as_handled()
		return
		
	# 键盘 ESC 关当前层
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if confirm_dialog.visible:
				confirm_dialog.visible = false
			else:
				close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and confirm_dialog.visible:
			btn_confirm_ok.emit_signal("pressed")
			get_viewport().set_input_as_handled()
		elif not confirm_dialog.visible:
			if event.keycode == KEY_F5:
				btn_save.emit_signal("pressed")
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_F9:
				btn_load.emit_signal("pressed")
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_O:
				btn_settings.emit_signal("pressed")
				get_viewport().set_input_as_handled()

func _on_main_menu_pressed() -> void:
	confirm_label.text = "返回主菜单？\n未保存的进度会丢失。"
	pending_action = func():
		close()
		return_to_main_menu_requested.emit()
		get_tree().change_scene_to_file("res://src/scenes/main_menu.tscn")
	confirm_dialog.visible = true
	btn_confirm_ok.grab_focus()

func _on_quit_pressed() -> void:
	confirm_label.text = "退出游戏？\n未保存的进度会丢失。"
	pending_action = func():
		quit_game_requested.emit()
		get_tree().quit(0)
	confirm_dialog.visible = true
	btn_confirm_ok.grab_focus()
