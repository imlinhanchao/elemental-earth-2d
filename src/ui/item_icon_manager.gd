# item_icon_manager.gd
# 全局专属物品与建筑矢量图标管理器
# 基础预加载确保语法解析零失败，ThorVG 动态渲染支持任意新专属矢量 SVG
class_name ItemIconManager
extends RefCounted

# 仅预加载经由 Godot 官方编译具备 .import 文件的基准图标，保证 GDScript 解析零失败
const BASE_ICONS: Dictionary = {
	"wood": preload("res://assets/icons/res_wood.svg"),
	"stick": preload("res://assets/icons/res_stick.svg"),
	"stone": preload("res://assets/icons/res_stone.svg"),
	"flint": preload("res://assets/icons/res_flint.svg"),
	"water": preload("res://assets/icons/res_water.svg"),
	"charcoal": preload("res://assets/icons/res_charcoal.svg"),
	"malachite": preload("res://assets/icons/res_malachite.svg"),
	"iron_ore": preload("res://assets/icons/res_hematite.svg"),
	"hematite": preload("res://assets/icons/res_hematite.svg"),
	"copper": preload("res://assets/icons/res_copper.svg"),
	"iron": preload("res://assets/icons/res_iron.svg"),
	"halite": preload("res://assets/icons/res_salt.svg"),
	"salt": preload("res://assets/icons/res_salt.svg"),
	"sulfur": preload("res://assets/icons/res_sulfur.svg"),
	"gas": preload("res://assets/icons/res_gas.svg"),
	"flint_axe": preload("res://assets/icons/tool_flint_axe.svg"),
	"stone_pickaxe": preload("res://assets/icons/tool_stone_pickaxe.svg"),
	"copper_pickaxe": preload("res://assets/icons/tool_copper_pickaxe.svg"),
	"iron_pickaxe": preload("res://assets/icons/tool_iron_hammer.svg"),
	"furnace": preload("res://assets/icons/furnace.svg"),
	"industrial_reactor": preload("res://assets/icons/reactor.svg"),
	"fuel_fire": preload("res://assets/icons/fuel_fire.svg"),
	"blueprint": preload("res://assets/icons/blueprint.svg"),
	"lab": preload("res://assets/icons/lab.svg"),
	"tech": preload("res://assets/icons/tech.svg"),
	"tab_tech": preload("res://assets/icons/tab_tech.svg"),
	"periodic_table": preload("res://assets/icons/periodic_table.svg"),
	"backpack": preload("res://assets/icons/backpack.svg"),
	"res_ore": preload("res://assets/icons/res_ore.svg")
}

# 运行时动态加载与缓存字典 (利用 Godot 4 内核 ThorVG 瞬时解析任意未导入 SVG)
static var _dynamic_cache: Dictionary = {}

static func get_icon(key: String) -> Texture2D:
	if _dynamic_cache.has(key):
		return _dynamic_cache[key]
		
	# 1. 尝试从本地 SVG 资源文件中直接加载 (支持自定义或新增加的矢量图标)
	var possible_paths = [
		"res://assets/icons/res_%s.svg" % key,
		"res://assets/icons/bldg_%s.svg" % key,
		"res://assets/icons/tool_%s.svg" % key,
		"res://assets/icons/%s.svg" % key
	]
	
	for path in possible_paths:
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var svg_text = file.get_as_text()
				file.close()
				var img = Image.new()
				var err = img.load_svg_from_string(svg_text, 3.0)
				if err == OK:
					img.generate_mipmaps()
					var tex = ImageTexture.create_from_image(img)
					_dynamic_cache[key] = tex
					return tex

	# 2. 从已导入的基础基准图标表中匹配
	if BASE_ICONS.has(key):
		return BASE_ICONS[key]

	# 3. 智能启发式分类匹配 (词根降级)
	var k_lower = key.to_lower()
	if k_lower.contains("pickaxe") or k_lower.contains("hammer") or k_lower.contains("chisel"):
		return BASE_ICONS["stone_pickaxe"]
	elif k_lower.contains("axe"):
		return BASE_ICONS["flint_axe"]
	elif k_lower.contains("gas") or k_lower.contains("oxide") or k_lower.contains("hydrogen") or k_lower.contains("oxygen"):
		return BASE_ICONS["gas"]
	elif k_lower.contains("furnace") or k_lower.contains("kiln"):
		return BASE_ICONS["furnace"]
	elif k_lower.contains("reactor"):
		return BASE_ICONS["industrial_reactor"]
	elif k_lower.contains("copper"):
		return BASE_ICONS["copper"]
	elif k_lower.contains("iron") or k_lower.contains("steel"):
		return BASE_ICONS["iron"]
	elif k_lower.contains("stone") or k_lower.contains("brick"):
		return BASE_ICONS["stone"]
	elif k_lower.contains("wood") or k_lower.contains("tree"):
		return BASE_ICONS["wood"]
		
	return BASE_ICONS["res_ore"]
