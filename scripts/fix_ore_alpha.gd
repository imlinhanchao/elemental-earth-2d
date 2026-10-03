# fix_ore_alpha.gd
# 彻底清洗所有黑底，只保留纯净的晶体与树冠像素
extends SceneTree

func _init() -> void:
	print("✨ [Deep Alpha Cleaner] 正在深度剔除黑色网格背景...")
	_deep_clean("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/malachite_ore.png", true)
	_deep_clean("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/hematite_ore.png", false)
	_deep_clean_tree("/Users/hancel/Documents/project/elemental-earth-2d/assets/sprites/oak_tree.png")
	print("✅ 深度清洗完毕！")
	quit(0)

func _deep_clean(path: String, is_green: bool) -> void:
	var img = Image.load_from_file(path)
	if not img: return
	var w = img.get_width()
	var h = img.get_height()
	
	for x in range(w):
		for y in range(h):
			var c = img.get_pixel(x, y)
			# 如果是较暗的背景/边框/网格线 (亮度较低)
			if c.r < 0.24 and c.g < 0.24 and c.b < 0.24:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.r > 0.82 and c.g > 0.82 and c.b > 0.82:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif is_green and not (c.g > c.r * 1.1 or c.g > 0.45):
				# 如果不是绿色晶体
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif not is_green and not (c.r > c.g * 1.1 or c.r > 0.45):
				# 如果不是红色铁矿石
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	img.save_png(path)

func _deep_clean_tree(path: String) -> void:
	var img = Image.load_from_file(path)
	if not img: return
	var w = img.get_width()
	var h = img.get_height()
	
	for x in range(w):
		for y in range(h):
			var c = img.get_pixel(x, y)
			if c.r < 0.18 and c.g < 0.18 and c.b < 0.18:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.r > 0.85 and c.g > 0.85 and c.b > 0.85:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var is_leaf = (c.g > 0.28 and c.g > c.r * 1.05) or (c.g > 0.45)
				var is_bark = (c.r > 0.25 and c.r > c.b * 1.3 and c.g > 0.15)
				if not is_leaf and not is_bark:
					img.set_pixel(x, y, Color(0, 0, 0, 0))

	img.save_png(path)
