# settings_manager.gd
# 游戏全局设置管理器: 负责音量、画质、全屏、自动保存频率与输入灵敏度的持久化与应用
class_name SettingsManager
extends RefCounted

const SETTINGS_FILE: String = "user://game_settings.json"

static var settings: Dictionary = {
	"master_volume": 1.0,
	"bgm_volume": 0.8,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"auto_save_interval": 45.0,
	"camera_drag_speed": 1.0
}

static var _initialized: bool = false

static func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		save_settings()
		apply_settings()
		_initialized = true
		return
		
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file:
		var txt = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(txt)
		if parsed is Dictionary:
			for k in parsed.keys():
				settings[k] = parsed[k]
	apply_settings()
	_initialized = true

static func save_settings() -> void:
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

static func get_setting(key: String, default_val = null):
	if not _initialized:
		load_settings()
	return settings.get(key, default_val)

static func set_setting(key: String, val) -> void:
	settings[key] = val
	apply_settings()
	save_settings()

static func apply_settings() -> void:
	# 1. 窗口全屏模式应用
	var is_fs = bool(settings.get("fullscreen", false))
	if is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			
	# 2. 音频总线音量应用 (如果有对应 AudioBus 则应用，否则跳过)
	_apply_audio_volume("Master", float(settings.get("master_volume", 1.0)))
	_apply_audio_volume("BGM", float(settings.get("bgm_volume", 0.8)))
	_apply_audio_volume("SFX", float(settings.get("sfx_volume", 1.0)))

static func _apply_audio_volume(bus_name: String, linear_vol: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		linear_vol = clamp(linear_vol, 0.0, 1.0)
		var db = linear_to_db(linear_vol) if linear_vol > 0.001 else -80.0
		AudioServer.set_bus_volume_db(idx, db)
		AudioServer.set_bus_mute(idx, linear_vol <= 0.001)
