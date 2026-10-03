# take_screenshot.gd
# 启动游戏并自动截取实机画面
extends SceneTree

func _init() -> void:
	print("📸 [Screenshot Tool] 正在加载世界场景并渲染实机画面...")
	
	# 加载世界场景
	var world_scene = load("res://src/scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	
	# 运行几个逻辑物理帧使画面完整呈现
	for i in range(10):
		await process_frame
		
	# 捕获画面
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("/Users/hancel/Documents/project/elemental-earth-2d/screenshot_current.png")
		print("✅ 截图已保存至: /Users/hancel/Documents/project/elemental-earth-2d/screenshot_current.png")
	else:
		print("❌ 截图失败: 无法获取视口图像")
		
	quit(0)
