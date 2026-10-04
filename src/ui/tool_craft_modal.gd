# tool_craft_modal.gd
# 随身原始手作与冶金锻造工坊 (一穷二白到工业装备全谱系)
extends PanelContainer

@onready var btn_close = $Margin/VBox/Header/BtnClose
@onready var current_tool_label = $Margin/VBox/CurrentToolLabel
@onready var craft_list = $Margin/VBox/Scroll/CraftList

func _ready() -> void:
	visible = false
	btn_close.pressed.connect(func(): visible = false)
	GameState.tool_equipped.connect(func(_k): _refresh_ui())
	_bind_buttons()
	_refresh_ui()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_ui()

func _bind_buttons() -> void:
	var b_flint_axe = craft_list.get_node("BtnFlintAxe")
	var b_stone_pick = craft_list.get_node("BtnStonePick")
	var b_make_charcoal = craft_list.get_node("BtnMakeCharcoal")
	var b_copper_pick = craft_list.get_node("BtnCopperPick")
	var b_iron_pick = craft_list.get_node("BtnIronPick")

	b_flint_axe.pressed.connect(_craft_flint_axe)
	b_stone_pick.pressed.connect(_craft_stone_pick)
	b_make_charcoal.pressed.connect(_craft_primitive_charcoal)
	b_copper_pick.pressed.connect(_craft_copper_pick)
	b_iron_pick.pressed.connect(_craft_iron_pick)

func _refresh_ui() -> void:
	var axe = GameState.equipped_tools.get("axe", "bare_hands")
	var pick = GameState.equipped_tools.get("pickaxe", "bare_hands")
	
	var axe_desc = "徒手 (无法砍树)" if axe == "bare_hands" else "原始燧石斧 (可伐木)"
	var pick_desc = "徒手 (无法采矿)"
	if pick == "stone_pickaxe": pick_desc = "粗制石镐 (伤害 1)"
	elif pick == "copper_pickaxe": pick_desc = "纯铜地质镐 (伤害 2)"
	elif pick == "iron_pickaxe": pick_desc = "精钢地质重锤 (伤害 4)"

	current_tool_label.text = "【当前装配】 斧具: %s | 镐具: %s" % [axe_desc, pick_desc]

func _craft_flint_axe() -> void:
	# 消耗: 断枝 x2 + 燧石/碎石 x2 (优先消耗锋利燧石)
	var has_flint = GameState.inventory.get_count("flint")
	var has_stone = GameState.inventory.get_count("stone")
	if GameState.inventory.has_item("stick", 2) and (has_flint + has_stone >= 2):
		GameState.inventory.remove_item("stick", 2)
		var needed = 2
		var take_flint = min(has_flint, needed)
		if take_flint > 0:
			GameState.inventory.remove_item("flint", take_flint)
			needed -= take_flint
		if needed > 0:
			GameState.inventory.remove_item("stone", needed)
		GameState.equip_tool("axe", "flint_axe")
		GameState.post_notice("🪓 制作成功！装备【原始燧石斧】，现在可以前往树林砍伐橡树！", Color.GREEN)
		_refresh_ui()
	else:
		GameState.post_notice("❌ 原料不足！制作【原始燧石斧】需要: 断枝 x2, 燧石/碎石 x2", Color.RED)

func _craft_stone_pick() -> void:
	# 消耗: 断枝 x3 + 碎石/燧石 x3 (优先消耗碎石)
	var has_stone = GameState.inventory.get_count("stone")
	var has_flint = GameState.inventory.get_count("flint")
	if GameState.inventory.has_item("stick", 3) and (has_stone + has_flint >= 3):
		GameState.inventory.remove_item("stick", 3)
		var needed = 3
		var take_stone = min(has_stone, needed)
		if take_stone > 0:
			GameState.inventory.remove_item("stone", take_stone)
			needed -= take_stone
		if needed > 0:
			GameState.inventory.remove_item("flint", needed)
		GameState.equip_tool("pickaxe", "stone_pickaxe")
		GameState.post_notice("⛏️ 制作成功！装备【粗制石镐】，现在可以前往矿脉开采孔雀石/赤铁矿！", Color.GREEN)
		_refresh_ui()
	else:
		GameState.post_notice("❌ 原料不足！制作【粗制石镐】需要: 断枝 x3, 碎石 x3", Color.RED)

func _craft_primitive_charcoal() -> void:
	# 原始土法闷火干馏: 原木 x2 -> 木炭 x2
	if GameState.inventory.has_item("wood", 2):
		GameState.inventory.remove_item("wood", 2)
		GameState.inventory.add_item("charcoal", 2)
		GameState.post_notice("🔥 原始火塘闷烧完成: 消耗原木 x2 焖制出【木炭 x2】！可用作熔炉燃料！", Color.ORANGE)
	else:
		GameState.post_notice("❌ 需要原木 x2 才能焖制木炭！请先用燧石斧砍伐橡树！", Color.RED)

func _craft_copper_pick() -> void:
	if GameState.inventory.has_item("copper", 3) and GameState.inventory.has_item("wood", 2):
		GameState.inventory.remove_item("copper", 3)
		GameState.inventory.remove_item("wood", 2)
		GameState.equip_tool("pickaxe", "copper_pickaxe")
		_refresh_ui()
	else:
		GameState.post_notice("❌ 锻造纯铜镐材料不足！需要: 金属铜 x3, 原木 x2", Color.RED)

func _craft_iron_pick() -> void:
	if GameState.inventory.has_item("iron", 4) and GameState.inventory.has_item("charcoal", 2):
		GameState.inventory.remove_item("iron", 4)
		GameState.inventory.remove_item("charcoal", 2)
		GameState.equip_tool("pickaxe", "iron_pickaxe")
		_refresh_ui()
	else:
		GameState.post_notice("❌ 锻造精钢重锤材料不足！需要: 金属铁 x4, 木炭 x2", Color.RED)
