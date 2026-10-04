# pause_menu.gd
# 局内暂停与系统菜单
extends PanelContainer

signal resume_requested
signal save_requested
signal load_requested
signal settings_requested
signal return_to_main_menu_requested
signal quit_game_requested

@onready var btn_resume = $Margin/VBox/BtnResume
@onready var btn_save = $Margin/VBox/BtnSave
@onready var btn_load = $Margin/VBox/BtnLoad
@onready var btn_settings = $Margin/VBox/BtnSettings
@onready var btn_main_menu = $Margin/VBox/BtnMainMenu
@onready var btn_quit = $Margin/VBox/BtnQuit

# 退出与返回主菜单确认框
@onready var confirm_dialog = $ConfirmDialog
@onready var confirm_label = $ConfirmDialog/Margin/VBox/ConfirmLabel
@onready var btn_confirm_ok = $ConfirmDialog/Margin/VBox/BtnHBox/BtnOk
@onready var btn_confirm_cancel = $ConfirmDialog/Margin/VBox/BtnHBox/BtnCancel

var pending_action: Callable

func _ready() -> void:
	visible = false
	confirm_dialog.visible = false
	
	btn_resume.pressed.connect(func():
		visible = false
		resume_requested.emit()
	)
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
	visible = not visible
	confirm_dialog.visible = false

func open() -> void:
	visible = true
	confirm_dialog.visible = false

func close() -> void:
	visible = false
	confirm_dialog.visible = false

func _on_main_menu_pressed() -> void:
	confirm_label.text = "🏛️ 确认返回主标题菜单吗？\n请确保当前进度已妥善保存！"
	pending_action = func():
		visible = false
		return_to_main_menu_requested.emit()
		get_tree().change_scene_to_file("res://src/scenes/main_menu.tscn")
	confirm_dialog.visible = true

func _on_quit_pressed() -> void:
	confirm_label.text = "✕ 确认直接退出游戏吗？\n未保存的数据可能会丢失！"
	pending_action = func():
		quit_game_requested.emit()
		get_tree().quit(0)
	confirm_dialog.visible = true
