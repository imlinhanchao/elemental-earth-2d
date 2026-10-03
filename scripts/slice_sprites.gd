# slice_sprites.gd
# 自动使用 Godot Image API 将生成的图集切片并去除白色背景
extends SceneTree

func _init() -> void:
	print("✂️ [Sprite Slicer] 开始提取与透明化像素精灵贴图...")

	_slice_player()
	_slice_ores_and_tree()
	_slice_furnace()

	print("🎉 所有精灵已切片并保存至 res://assets/sprites/")
	quit(0)

# 去除近白色背景并将透明度设为 0
func _make_transparent(img: Image, tolerance: float = 0.15) -> void:
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var c = img.get_pixel(x, y)
			# 如果是白色背景
			if c.r > (1.0 - tolerance) and c.g > (1.0 - tolerance) and c.b > (1.0 - tolerance):
				img.set_pixel(x, y, Color(0, 0, 0, 0))

func _slice_player() -> void:
	var img = Image.load_from_file("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/player_spritesheet.png")
	if img:
		# 提取左上角第一个正面站立/行走的角色 (约 45, 110, 110, 180)
		var sub = img.get_region(Rect2i(40, 110, 120, 180))
		_make_transparent(sub)
		sub.save_png("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/player.png")
		print(" -> player.png 提取完成")

func _slice_ores_and_tree() -> void:
	var img = Image.load_from_file("/Users/hancel/Documents/project/elemental-earth-2d/assets/tilesets/nature_ores_tileset.png")
	if img:
		# 1. 孔雀石矿 (约左侧中间 M3 区域 x: 195, y: 300, w: 105, h: 105)
		var malachite = img.get_region(Rect2i(190, 290, 110, 110))
		_make_transparent(malachite)
		malachite.save_png("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/malachite_ore.png")
		print(" -> malachite_ore.png 提取完成")

		# 2. 赤铁矿 (约中间 H2 区域 x: 590, y: 290, w: 110, h: 110)
		var hematite = img.get_region(Rect2i(590, 290, 110, 110))
		_make_transparent(hematite)
		hematite.save_png("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/hematite_ore.png")
		print(" -> hematite_ore.png 提取完成")

		# 3. 橡树 (约底部右侧整棵大树 x: 500, y: 500, w: 500, h: 500)
		var tree = img.get_region(Rect2i(500, 500, 500, 500))
		_make_transparent(tree)
		tree.save_png("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/oak_tree.png")
		print(" -> oak_tree.png 提取完成")

func _slice_furnace() -> void:
	var img = Image.load_from_file("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/apparatus_spritesheet.png")
	if img:
		# 1. 燃烧熔炉 (左上第一台 x: 20, y: 15, w: 220, h: 240)
		var hot = img.get_region(Rect2i(20, 15, 220, 240))
		_make_transparent(hot)
		hot.save_png("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/furnace_hot.png")
		print(" -> furnace_hot.png 提取完成")

		# 2. 熄灭冷熔炉 (右上第四台 x: 770, y: 15, w: 220, h: 240)
		var cold = img.get_region(Rect2i(770, 15, 220, 240))
		_make_transparent(cold)
		cold.save_png("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/furnace_cold.png")
		print(" -> furnace_cold.png 提取完成")
