# test_music.gd
# 无头测试：音频总线、音量设置、主菜单 / 时代曲目切换、时代跃迁乐句与压低、读档不放乐句
# 用法: Godot --headless --path . res://tests/test_music.tscn
extends Node

const SettingsManager = preload("res://src/core/settings_manager.gd")
const SaveManager = preload("res://src/core/save_manager.gd")

var _failed := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		_failed += 1
		printerr("  ✗ ", msg)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _ready() -> void:
	print("\n[背景音乐测试]")
	SaveManager.suppress_auto_save = true
	await get_tree().process_frame

	# 总线与音量
	var bgm = AudioServer.get_bus_index("BGM")
	var sfx = AudioServer.get_bus_index("SFX")
	_check(bgm != -1 and sfx != -1, "BGM / SFX 总线存在")
	_check(AudioServer.get_bus_send(bgm) == &"Master", "BGM 总线输出到 Master")
	var old_bgm = float(SettingsManager.get_setting("bgm_volume", 0.8))
	SettingsManager.settings["bgm_volume"] = 0.5
	SettingsManager.apply_settings()
	_check(absf(AudioServer.get_bus_volume_db(bgm) - linear_to_db(0.5)) < 0.01, "BGM 音量滑块作用到总线")
	SettingsManager.settings["bgm_volume"] = 0.0
	SettingsManager.apply_settings()
	_check(AudioServer.is_bus_mute(bgm), "BGM 音量 0 时静音")
	SettingsManager.settings["bgm_volume"] = old_bgm
	SettingsManager.apply_settings()

	# 曲目资源
	for era in range(DataDB.eras.size()):
		var path = MusicManager.era_track(era)
		var s = load(path) if path != "" and ResourceLoader.exists(path) else null
		_check(s is AudioStreamOggVorbis and s.loop and s.get_length() > 60.0, "时代 %d 曲目可循环 (%s)" % [era, path.get_file()])
	var st = load(MusicManager.STINGER_ERA)
	_check(st is AudioStreamOggVorbis and not st.loop, "时代跃迁乐句不循环")

	# 主菜单
	MusicManager.play_menu()
	_check(MusicManager.current_track == MusicManager.MENU_TRACK, "主菜单播放主菜单曲目")

	# 进入大世界：播放当前时代曲目
	GameState.reset_to_new_game()
	var world = load("res://src/scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await _wait(0.3)
	_check(MusicManager.current_track == MusicManager.era_track(0), "大世界播放石器时代曲目")
	_check(not MusicManager.is_ducked(), "开局没有乐句")

	# 时代跃迁：放乐句、压低背景音乐，乐句结束后切到新时代曲目
	GameState.sim.advance_era(1)
	await get_tree().process_frame
	_check(MusicManager.is_ducked(), "时代跃迁时放乐句并压低背景音乐")
	_check(MusicManager.current_track == MusicManager.era_track(0), "乐句播放时先不切曲")
	MusicManager._stinger.stop()
	MusicManager._on_stinger_finished()
	_check(not MusicManager.is_ducked(), "乐句结束后恢复音量")
	_check(MusicManager.current_track == MusicManager.era_track(1), "乐句结束后切到炼金术时代曲目")

	# 存档 → 回到石器时代 → 读档：直接切曲，不放乐句
	SaveManager.save_to_slot("_music_test", world)
	GameState.reset_to_new_game()
	await get_tree().process_frame
	_check(MusicManager.current_track == MusicManager.era_track(0), "新游戏切回石器时代曲目")
	_check(not MusicManager.is_ducked(), "新游戏不放乐句")
	SaveManager.load_from_slot("_music_test", world, true)
	await get_tree().process_frame
	_check(GameState.current_era == 1, "读档恢复炼金术时代")
	_check(MusicManager.current_track == MusicManager.era_track(1), "读档切到存档时代曲目")
	_check(not MusicManager.is_ducked(), "读档不放时代跃迁乐句")
	SaveManager.delete_slot("_music_test")

	# 元素发现乐句
	GameState.element_discovered.emit(29, "copper")
	await get_tree().process_frame
	_check(MusicManager.is_ducked(), "元素发现时放乐句并压低背景音乐")
	MusicManager._stinger.stop()
	MusicManager._on_stinger_finished()

	world.queue_free()
	GameState.reset_to_new_game()
	SaveManager.suppress_auto_save = false
	if _failed == 0:
		print("🎉 背景音乐测试全部通过")
		get_tree().quit(0)
	else:
		printerr("背景音乐测试失败 %d 项" % _failed)
		get_tree().quit(1)
