# item_icon_manager.gd
# 全局专属物品与建筑矢量图标管理器
# 所有图标均通过 Godot 导入管线加载并缓存
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
	"hematite": preload("res://assets/icons/res_hematite.svg"),
	"copper": preload("res://assets/icons/res_copper.svg"),
	"iron": preload("res://assets/icons/res_iron.svg"),
	"rock_salt": preload("res://assets/icons/res_salt.svg"),
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

# 纹理缓存：只使用导入管线产出的纹理 (svg/scale=3.0 + mipmaps)，
# 不在运行时用 ThorVG 栅格化 SVG (首次显示会卡顿，且导出包中原始 .svg 不存在)
static var _cache: Dictionary = {}

# 通用纹理加载 (带缓存)，供 HUD / 弹窗 / 主菜单加载 logo 与时代徽章
static func load_texture(path: String) -> Texture2D:
	var cache_key = "%s#%d" % [path, int(ThemeStyler.is_dark)]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	tex = themed(tex)
	_cache[cache_key] = tex
	return tex

static func get_icon(key: String) -> Texture2D:
	var cache_key = "key:%s#%d" % [key, int(ThemeStyler.is_dark)]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex = themed(_resolve_icon(key))
	_cache[cache_key] = tex
	return tex

# 深色模式下，墨色线稿图标换成 assets/icons/dark/ 下的浅色版本 (由 tools/make_dark_icons.py 生成)；
# 彩色物品图标两种模式通用，原样返回
static func themed(tex: Texture2D) -> Texture2D:
	if tex == null or not ThemeStyler.is_dark:
		return tex
	var path = tex.resource_path
	if not path.begins_with("res://assets/icons/") or path.begins_with("res://assets/icons/dark/"):
		return tex
	var dark_path = path.replace("res://assets/icons/", "res://assets/icons/dark/")
	if ResourceLoader.exists(dark_path):
		return load(dark_path)
	return tex

static func _resolve_icon(key: String) -> Texture2D:
	# 1. 按命名约定查找已导入的专属图标
	for path in [
		"res://assets/icons/res_%s.svg" % key,
		"res://assets/icons/bldg_%s.svg" % key,
		"res://assets/icons/tool_%s.svg" % key,
		"res://assets/icons/%s.svg" % key
	]:
		if ResourceLoader.exists(path):
			return load(path)

	# 2. 从已导入的基础基准图标表中匹配
	if BASE_ICONS.has(key):
		return BASE_ICONS[key]

	# 3. 科技：统一使用科技图标 (科技树卡片按科技 key 取图标)
	if DataDB.techs.has(key):
		return load("res://assets/icons/tech.svg")

	# 4. 词根匹配：工具、金属、建材等已有专属图标的大类
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

	# 5. 按 items.json 的物品分类选用分类图标，避免所有未知物品都显示成矿石
	var cat_icon = CATEGORY_ICONS.get(str(DataDB.get_item(key).get("category", "")), "")
	if cat_icon != "" and ResourceLoader.exists(cat_icon):
		return load(cat_icon)
	return BASE_ICONS["res_ore"]

const CATEGORY_ICONS: Dictionary = {
	"容器": "res://assets/icons/cat_container.svg",
	"工具": "res://assets/icons/cat_tool.svg",
	"材料": "res://assets/icons/cat_material.svg",
	"化工": "res://assets/icons/cat_material.svg",
	"液体": "res://assets/icons/cat_liquid.svg",
	"气体": "res://assets/icons/cat_gas.svg",
	"装置": "res://assets/icons/cat_device.svg",
	"火源": "res://assets/icons/cat_fire.svg",
	"燃料": "res://assets/icons/cat_fire.svg",
	"元素": "res://assets/icons/cat_element.svg",
	"奇观": "res://assets/icons/cat_wonder.svg",
	"矿石": "res://assets/icons/res_ore.svg",
}
