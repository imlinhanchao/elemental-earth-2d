# settings_modal.gd
# 游戏全局设置弹窗: 左分类、右选项，滑条与开关均显示数值，无 emoji
extends Control

signal modal_closed

const SettingsManager = preload("res://src/core/settings_manager.gd")

@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose

# 侧边分类选项卡
@onready var tab_audio = $CenterPanel/VBox/Body/HBox/CategoryList/TabAudio
@onready var tab_display = $CenterPanel/VBox/Body/HBox/CategoryList/TabDisplay
@onready var tab_game = $CenterPanel/VBox/Body/HBox/CategoryList/TabGame

@onready var sec_audio = $CenterPanel/VBox/Body/HBox/RightContent/SecAudio
@onready var sec_display = $CenterPanel/VBox/Body/HBox/RightContent/SecDisplay
@onready var sec_game = $CenterPanel/VBox/Body/HBox/RightContent/SecGame

# 音频控件
@onready var slider_master = $CenterPanel/VBox/Body/HBox/RightContent/SecAudio/MasterBox/HSlider
@onready var label_master_val = $CenterPanel/VBox/Body/HBox/RightContent/SecAudio/MasterBox/ValLabel
@onready var slider_bgm = $CenterPanel/VBox/Body/HBox/RightContent/SecAudio/BgmBox/HSlider
@onready var label_bgm_val = $CenterPanel/VBox/Body/HBox/RightContent/SecAudio/BgmBox/ValLabel
@onready var slider_sfx = $CenterPanel/VBox/Body/HBox/RightContent/SecAudio/SfxBox/HSlider
@onready var label_sfx_val = $CenterPanel/VBox/Body/HBox/RightContent/SecAudio/SfxBox/ValLabel

# 显示与游戏控件
@onready var check_fullscreen = $CenterPanel/VBox/Body/HBox/RightContent/SecDisplay/CheckFullscreen
@onready var opt_theme = $CenterPanel/VBox/Body/HBox/RightContent/SecDisplay/ThemeBox/OptTheme
const THEME_MODES: Array[String] = ["light", "dark", "system"]
@onready var opt_autosave = $CenterPanel/VBox/Body/HBox/RightContent/SecGame/AutoSaveBox/OptAutoSave
@onready var slider_cam_speed = $CenterPanel/VBox/Body/HBox/RightContent/SecGame/CamSpeedBox/HSlider
@onready var label_cam_speed_val = $CenterPanel/VBox/Body/HBox/RightContent/SecGame/CamSpeedBox/ValLabel

# 底部按钮
@onready var btn_apply = $CenterPanel/VBox/Footer/HBox/BtnApply
@onready var btn_default = $CenterPanel/VBox/Footer/HBox/BtnDefault

func _ready() -> void:
	ModalStack.track(self)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	btn_close.pressed.connect(close)
	btn_apply.pressed.connect(_on_apply_pressed)
	btn_default.pressed.connect(_on_default_pressed)
	
	tab_audio.pressed.connect(func(): _switch_tab(0))
	tab_display.pressed.connect(func(): _switch_tab(1))
	tab_game.pressed.connect(func(): _switch_tab(2))
	
	_setup_options()
	_bind_slider_events()
	_switch_tab(0)

func open() -> void:
	SettingsManager.load_settings()
	_refresh_ui_from_settings()
	visible = true
	_switch_tab(0)
	btn_close.grab_focus()

func close() -> void:
	visible = false
	modal_closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or not ModalStack.is_top(self):
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		close()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER:
			_on_apply_pressed()
			get_viewport().set_input_as_handled()

func _switch_tab(index: int) -> void:
	sec_audio.visible = (index == 0)
	sec_display.visible = (index == 1)
	sec_game.visible = (index == 2)
	
	var accent = ThemeStyler.COLOR_ACCENT
	var def_col = Color.WHITE
	tab_audio.modulate = accent if index == 0 else def_col
	tab_display.modulate = accent if index == 1 else def_col
	tab_game.modulate = accent if index == 2 else def_col

func _setup_options() -> void:
	opt_theme.clear()
	opt_theme.add_item("浅色（纸面）", 0)
	opt_theme.add_item("深色（暖墨）", 1)
	opt_theme.add_item("跟随系统", 2)
	opt_autosave.clear()
	opt_autosave.add_item("每 30 秒自动保存", 0)
	opt_autosave.set_item_metadata(0, 30.0)
	opt_autosave.add_item("每 45 秒自动保存 (推荐)", 1)
	opt_autosave.set_item_metadata(1, 45.0)
	opt_autosave.add_item("每 60 秒自动保存", 2)
	opt_autosave.set_item_metadata(2, 60.0)
	opt_autosave.add_item("关闭自动保存", 3)
	opt_autosave.set_item_metadata(3, 0.0)

func _bind_slider_events() -> void:
	slider_master.value_changed.connect(func(v):
		label_master_val.text = "%d%%" % int(v * 100)
	)
	slider_bgm.value_changed.connect(func(v):
		label_bgm_val.text = "%d%%" % int(v * 100)
	)
	slider_sfx.value_changed.connect(func(v):
		label_sfx_val.text = "%d%%" % int(v * 100)
	)
	slider_cam_speed.value_changed.connect(func(v):
		label_cam_speed_val.text = "%.1fx" % v
	)

func _refresh_ui_from_settings() -> void:
	var m_vol = float(SettingsManager.get_setting("master_volume", 1.0))
	var b_vol = float(SettingsManager.get_setting("bgm_volume", 0.8))
	var s_vol = float(SettingsManager.get_setting("sfx_volume", 1.0))
	var is_fs = bool(SettingsManager.get_setting("fullscreen", false))
	var as_int = float(SettingsManager.get_setting("auto_save_interval", 45.0))
	var c_spd = float(SettingsManager.get_setting("camera_drag_speed", 1.0))
	
	slider_master.value = m_vol
	label_master_val.text = "%d%%" % int(m_vol * 100)
	
	slider_bgm.value = b_vol
	label_bgm_val.text = "%d%%" % int(b_vol * 100)
	
	slider_sfx.value = s_vol
	label_sfx_val.text = "%d%%" % int(s_vol * 100)
	
	check_fullscreen.button_pressed = is_fs
	opt_theme.selected = max(THEME_MODES.find(str(SettingsManager.get_setting("theme_mode", "light"))), 0)
	
	slider_cam_speed.value = c_spd
	label_cam_speed_val.text = "%.1fx" % c_spd
	
	var selected_idx = 1
	for i in range(opt_autosave.item_count):
		if abs(opt_autosave.get_item_metadata(i) - as_int) < 1.0:
			selected_idx = i
			break
	opt_autosave.selected = selected_idx

func _on_apply_pressed() -> void:
	SettingsManager.set_setting("master_volume", slider_master.value)
	SettingsManager.set_setting("bgm_volume", slider_bgm.value)
	SettingsManager.set_setting("sfx_volume", slider_sfx.value)
	SettingsManager.set_setting("fullscreen", check_fullscreen.button_pressed)
	
	var sel_meta = opt_autosave.get_item_metadata(opt_autosave.selected)
	SettingsManager.set_setting("auto_save_interval", float(sel_meta))
	SettingsManager.set_setting("camera_drag_speed", slider_cam_speed.value)
	
	SettingsManager.save_settings()
	close()
	# 主题最后应用：切换明暗会重新加载当前场景 (大世界中进度会先暂存再读回)
	GameState.switch_theme(THEME_MODES[opt_theme.selected])

func _on_default_pressed() -> void:
	slider_master.value = 1.0
	slider_bgm.value = 0.8
	slider_sfx.value = 1.0
	check_fullscreen.button_pressed = false
	opt_theme.selected = 0
	opt_autosave.selected = 1
	slider_cam_speed.value = 1.0
