# refine_sprites.gd
# 自动去除黑底与杂色背景，实现真正的完美透明像素资产
extends SceneTree

func _init() -> void:
	print("🧼 [Refine Sprites] 开始去除黑底与背景网格...")
	
	_refine_texture("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/malachite_ore.png")
	_refine_texture("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/hematite_ore.png")
	_refine_texture("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/oak_tree.png")
	_refine_texture("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/furnace_hot.png")
	_refine_texture("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/furnace_cold.png")
	_refine_texture("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/player.png")

	print("✅ 所有精灵贴图边缘与背景黑底已清洗干净！")
	quit(0)

func _refine_texture(path: String) -> void:
	var img = Image.load_from_file(path)
	if not img:
		return
		
	var w = img.get_width()
	var h = img.get_height()
	
	for x in range(w):
		for y in range(h):
			var c = img.get_pixel(x, y)
			# 如果是纯黑或近纯黑背景 (r, g, b 都极低)
			if c.r < 0.08 and c.g < 0.08 and c.b < 0.08:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			# 如果是纯白或灰白网格背景
			elif c.r > 0.94 and c.g > 0.94 and c.b > 0.94:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	img.save_png(path)
	print(" -> 已处理: ", path)
