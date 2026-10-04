# item_icon_manager.gd
# 全局专属物品与建筑矢量图标管理器: 杜绝同类重复占位，完全对齐实际物品与建筑特质
class_name ItemIconManager
extends RefCounted

const ICONS: Dictionary = {
	# 基础材料与燃料
	"wood": preload("res://assets/icons/res_wood.svg"),
	"stick": preload("res://assets/icons/res_stick.svg"),
	"stone": preload("res://assets/icons/res_stone.svg"),
	"cut_stone": preload("res://assets/icons/res_cut_stone.svg"),
	"flint": preload("res://assets/icons/res_flint.svg"),
	"water": preload("res://assets/icons/res_water.svg"),
	"charcoal": preload("res://assets/icons/res_charcoal.svg"),
	"clay": preload("res://assets/icons/res_clay.svg"),
	"glass": preload("res://assets/icons/res_glass.svg"),
	
	# 矿石与天然矿物
	"malachite": preload("res://assets/icons/res_malachite.svg"),
	"iron_ore": preload("res://assets/icons/res_hematite.svg"),
	"hematite": preload("res://assets/icons/res_hematite.svg"),
	"bauxite": preload("res://assets/icons/res_bauxite.svg"),
	"pyrite": preload("res://assets/icons/res_pyrite.svg"),
	"galena": preload("res://assets/icons/res_galena.svg"),
	"sphalerite": preload("res://assets/icons/res_sphalerite.svg"),
	"monazite": preload("res://assets/icons/res_monazite.svg"),
	"pitchblende": preload("res://assets/icons/res_pitchblende.svg"),
	"halite": preload("res://assets/icons/res_salt.svg"),
	"salt": preload("res://assets/icons/res_salt.svg"),
	"sulfur": preload("res://assets/icons/res_sulfur.svg"),
	
	# 精炼金属与合金
	"copper": preload("res://assets/icons/res_copper.svg"),
	"iron": preload("res://assets/icons/res_iron.svg"),
	"bronze": preload("res://assets/icons/res_bronze.svg"),
	"brass": preload("res://assets/icons/res_brass.svg"),
	"steel": preload("res://assets/icons/res_steel.svg"),
	"titanium": preload("res://assets/icons/res_titanium.svg"),
	"gold": preload("res://assets/icons/res_gold.svg"),
	"silver": preload("res://assets/icons/res_silver.svg"),
	
	# 气体与挥发物
	"gas": preload("res://assets/icons/res_gas.svg"),
	"carbon_monoxide": preload("res://assets/icons/res_gas_bottle.svg"),
	"carbon_dioxide": preload("res://assets/icons/res_gas_bottle.svg"),
	"hydrogen": preload("res://assets/icons/res_gas.svg"),
	"oxygen": preload("res://assets/icons/res_gas.svg"),
	
	# 电力与科技部件
	"battery": preload("res://assets/icons/res_battery.svg"),
	"lead_acid_battery": preload("res://assets/icons/res_battery.svg"),
	"lithium_battery": preload("res://assets/icons/res_battery.svg"),
	"circuit": preload("res://assets/icons/res_circuit.svg"),
	"gear": preload("res://assets/icons/res_gear.svg"),
	"blueprint": preload("res://assets/icons/blueprint.svg"),
	"fuel_fire": preload("res://assets/icons/fuel_fire.svg"),
	
	# 工具与装备
	"flint_axe": preload("res://assets/icons/tool_flint_axe.svg"),
	"stone_pickaxe": preload("res://assets/icons/tool_stone_pickaxe.svg"),
	"copper_pickaxe": preload("res://assets/icons/tool_copper_pickaxe.svg"),
	"iron_pickaxe": preload("res://assets/icons/tool_iron_hammer.svg"),
	"steel_pickaxe": preload("res://assets/icons/tool_iron_hammer.svg"),
	
	# 建筑与宏观巨构
	"furnace": preload("res://assets/icons/furnace.svg"),
	"clay_furnace": preload("res://assets/icons/furnace.svg"),
	"high_temp_furnace": preload("res://assets/icons/bldg_high_temp_furnace.svg"),
	"industrial_reactor": preload("res://assets/icons/reactor.svg"),
	"nuclear_reactor": preload("res://assets/icons/bldg_nuclear_reactor.svg"),
	"giza_pyramid": preload("res://assets/icons/bldg_pyramid.svg"),
	
	# 系统与科技
	"lab": preload("res://assets/icons/lab.svg"),
	"tech": preload("res://assets/icons/tech.svg"),
	"tab_tech": preload("res://assets/icons/tab_tech.svg"),
	"periodic_table": preload("res://assets/icons/periodic_table.svg"),
	"backpack": preload("res://assets/icons/backpack.svg")
}

static func get_icon(key: String) -> Texture2D:
	if ICONS.has(key):
		return ICONS[key]
		
	# 智能启发式分类匹配，防止通用 ore 泛滥
	var k_lower = key.to_lower()
	if k_lower.contains("pickaxe") or k_lower.contains("hammer") or k_lower.contains("chisel"):
		return ICONS["stone_pickaxe"]
	elif k_lower.contains("axe"):
		return ICONS["flint_axe"]
	elif k_lower.contains("gas") or k_lower.contains("oxide") or k_lower.contains("hydrogen"):
		return ICONS["carbon_dioxide"]
	elif k_lower.contains("battery") or k_lower.contains("volt"):
		return ICONS["battery"]
	elif k_lower.contains("furnace") or k_lower.contains("kiln"):
		return ICONS["high_temp_furnace"]
	elif k_lower.contains("reactor"):
		return ICONS["industrial_reactor"]
	elif k_lower.contains("pyramid") or k_lower.contains("monument"):
		return ICONS["giza_pyramid"]
	elif k_lower.contains("gear") or k_lower.contains("machine") or k_lower.contains("motor"):
		return ICONS["gear"]
	elif k_lower.contains("circuit") or k_lower.contains("chip"):
		return ICONS["circuit"]
	elif k_lower.contains("stone") or k_lower.contains("brick"):
		return ICONS["cut_stone"]
	elif k_lower.contains("copper"):
		return ICONS["copper"]
	elif k_lower.contains("iron") or k_lower.contains("steel"):
		return ICONS["steel"]
	elif k_lower.contains("gold"):
		return ICONS["gold"]
	elif k_lower.contains("silver"):
		return ICONS["silver"]
	elif k_lower.contains("bronze"):
		return ICONS["bronze"]
		
	return preload("res://assets/icons/res_ore.svg")
