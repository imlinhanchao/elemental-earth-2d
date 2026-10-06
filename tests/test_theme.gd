# test_theme.gd
# 无头测试：在大世界中切换浅色 / 深色主题，进度、背包、教程状态保持不变，临时存档被清理
# 用法: Godot --headless --path . res://tests/test_theme.tscn
extends Node

const SettingsManager = preload("res://src/core/settings_manager.gd")
const SaveManager = preload("res://src/core/save_manager.gd")
const ThemeStyler = preload("res://src/ui/theme_styler.gd")

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
	print("\n[主题切换测试]")
	var old_mode = str(SettingsManager.get_setting("theme_mode", "light"))
	SaveManager.suppress_auto_save = true # 不写玩家的自动存档
	await get_tree().process_frame

	# 切换主题会重新加载「当前场景」：把大世界实例设为当前场景，测试节点作为它的兄弟节点留在 root 下
	GameState.reset_to_new_game()
	GameState.start_tutorial()
	GameState.set_tutorial_step(1)
	var world = load("res://src/scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await _wait(0.5)
	GameState.inventory.add_item("stone", 7)
	GameState.inventory.add_item("flint", 3)

	GameState.switch_theme("dark")
	await _wait(0.6)
	_check(ThemeStyler.is_dark, "切换后进入深色模式")
	_check(ThemeStyler.COLOR_BG.get_luminance() < 0.2 and ThemeStyler.COLOR_TEXT_PRIMARY.get_luminance() > 0.8, "深色令牌：暗底、亮字")
	_check(GameState.inventory.get_count("stone") == 7 and GameState.inventory.get_count("flint") == 3, "切换主题后背包保持不变")
	_check(GameState.is_tutorial_active and GameState.tutorial_step == 1, "切换主题后教程进度保持不变")
	_check(not FileAccess.file_exists(SaveManager.get_slot_path(GameState.THEME_RELOAD_SLOT)), "临时存档已清理")
	var w = get_tree().current_scene
	_check(w != null and w.has_method("serialize_world_state"), "切换后仍在大世界")
	_check(str(SettingsManager.get_setting("theme_mode", "")) == "dark", "主题设置已保存")

	GameState.switch_theme("light")
	await _wait(0.6)
	_check(not ThemeStyler.is_dark and ThemeStyler.COLOR_BG.get_luminance() > 0.8, "切回浅色模式")
	_check(GameState.inventory.get_count("stone") == 7, "切回后背包保持不变")

	GameState.reset_to_new_game()
	SettingsManager.set_setting("theme_mode", old_mode)
	SaveManager.suppress_auto_save = false
	if _failed == 0:
		print("🎉 主题切换测试全部通过")
		get_tree().quit(0)
	else:
		printerr("❌ %d 项失败" % _failed)
		get_tree().quit(1)
