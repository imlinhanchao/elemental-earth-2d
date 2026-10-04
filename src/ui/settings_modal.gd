# settings_modal.gd
# 游戏全局设置弹窗: 调节声音、显示模式、自动保存与输入参数
extends PanelContainer

signal modal_closed

const SettingsManager = preload("res://src/core/settings_manager.gd")

@onready var btn_close = $Margin/VBox/Header/BtnClose
@onready var slider_master = $Margin/VBox/Scroll/VBox/AudioSec/MasterBox/HSlider
@onready var label_master_val = $Margin/VBox/Scroll/VBox/AudioSec/MasterBox/ValLabel

@onready var slider_bgm = $Margin/VBox/Scroll/VBox/AudioSec/BgmBox/HSlider
@onready var label_bgm_val = $Margin/VBox/Scroll/VBox/AudioSec/BgmBox/ValLabel

@onready var slider_sfx = $Margin/VBox/Scroll/VBox/AudioSec/SfxBox/HSlider
@onready var label_sfx_val = $Margin/VBox/Scroll/VBox/AudioSec/SfxBox/ValLabel

@onready var check_fullscreen = $Margin/VBox/Scroll/VBox/DisplaySec/CheckFullscreen
@onready var opt_autosave = $Margin/VBox/Scroll/VBox/GameSec/AutoSaveBox/OptAutoSave
@onready var slider_cam_speed = $Margin/VBox/Scroll/VBox/GameSec/CamSpeedBox/HSlider
@onready var label_cam_speed_val = $Margin/VBox/Scroll/VBox/GameSec/CamSpeedBox/ValLabel

@onready var btn_apply = $Margin/VBox/BottomHBox/BtnApply
@onready var btn_default = $Margin/VBox/BottomHBox/BtnDefault

func _ready() -> void:
	visible = false
	btn_close.pressed.connect(close)
	btn_apply.pressed.connect(_on_apply_pressed)
	btn_default.pressed.connect(_on_default_pressed)
	
	_setup_options()
	_bind_slider_events()

func open() -> void:
	SettingsManager.load_settings()
	_refresh_ui_from_settings()
	visible = true

func close() -> void:
	visible = false
	modal_closed.emit()

func _setup_options() -> void:
	opt_autosave.clear()
	opt_autosave.add_item("⏱️ 每 30 秒自动保存", 0)
	opt_autosave.set_item_metadata(0, 30.0)
	opt_autosave.add_item("⏱️ 每 45 秒自动保存 (推荐)", 1)
	opt_autosave.set_item_metadata(1, 45.0)
	opt_autosave.add_item("⏱️ 每 60 秒自动保存", 2)
	opt_autosave.set_item_metadata(2, 60.0)
	opt_autosave.add_item("🚫 关闭自动保存", 3)
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
	
	slider_cam_speed.value = c_spd
	label_cam_speed_val.text = "%.1fx" % c_spd
	
	# 设置自动保存索引
	var selected_idx = 1
	for i in range(opt_autosave.item_count):
		if abs(opt_autosave.get_item_metadata(i) - as_int) < 1.0:
			selected_idx = i
			break
	opt_autosave.selected = selected_idx

func _on_apply_pressed() -> void:
	var sel_idx = opt_autosave.selected
	var auto_save_val = opt_autosave.get_item_metadata(sel_idx)
	
	SettingsManager.set_setting("master_volume", slider_master.value)
	SettingsManager.set_setting("bgm_volume", slider_bgm.value)
	SettingsManager.set_setting("sfx_volume", slider_sfx.value)
	SettingsManager.set_setting("fullscreen", check_fullscreen.button_pressed)
	SettingsManager.set_setting("auto_save_interval", auto_save_val)
	SettingsManager.set_setting("camera_drag_speed", slider_cam_speed.value)
	
	SettingsManager.save_settings()
	SettingsManager.apply_settings()
	GameState.post_notice("⚙️ 游戏设置已成功保存并立即生效！", Color.GREEN)
	close()

func _on_default_pressed() -> void:
	slider_master.value = 1.0
	slider_bgm.value = 0.8
	slider_sfx.value = 1.0
	check_fullscreen.button_pressed = false
	slider_cam_speed.value = 1.0
	opt_autosave.selected = 1
