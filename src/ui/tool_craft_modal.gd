# tool_craft_modal.gd
# 工具与冶金装备锻造工坊
extends PanelContainer

@onready var btn_craft_copper_pick = $Margin/VBox/ItemList/BtnCraftCopperPick
@onready var btn_craft_iron_pick = $Margin/VBox/ItemList/BtnCraftIronPick
@onready var btn_close = $Margin/VBox/Header/BtnClose
@onready var current_tool_label = $Margin/VBox/CurrentToolLabel

func _ready() -> void:
	visible = false
	btn_close.pressed.connect(func(): visible = false)
	btn_craft_copper_pick.pressed.connect(_on_craft_copper_pick)
	btn_craft_iron_pick.pressed.connect(_on_craft_iron_pick)
	GameState.tool_equipped.connect(func(_k): _refresh_ui())
	_refresh_ui()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_ui()

func _refresh_ui() -> void:
	var curr = GameState.equipped_tools.get("pickaxe", "stone_pickaxe")
	var t_name = "简易石镐 (开采伤害: 1)"
	if curr == "copper_pickaxe":
		t_name = "✨ 纯铜地质镐 (开采伤害: 2, 速度提升 100%)"
	elif curr == "iron_pickaxe":
		t_name = "⚡ 精钢地质重锤 (开采伤害: 4, 瞬间崩解矿脉)"
	current_tool_label.text = "当前装备主工具: %s" % t_name

func _on_craft_copper_pick() -> void:
	# 消耗 3 块金属铜 + 2 块木材
	if GameState.inventory.has_item("copper", 3) and GameState.inventory.has_item("wood", 2):
		GameState.inventory.remove_item("copper", 3)
		GameState.inventory.remove_item("wood", 2)
		GameState.equip_tool("pickaxe", "copper_pickaxe")
	else:
		GameState.post_notice("❌ 锻造纯铜镐材料不足！需要: 金属铜 x3, 木材 x2", Color.RED)

func _on_craft_iron_pick() -> void:
	# 消耗 4 块金属铁 + 2 块木炭
	if GameState.inventory.has_item("iron", 4) and GameState.inventory.has_item("charcoal", 2):
		GameState.inventory.remove_item("iron", 4)
		GameState.inventory.remove_item("charcoal", 2)
		GameState.equip_tool("pickaxe", "iron_pickaxe")
	else:
		GameState.post_notice("❌ 锻造精钢重锤材料不足！需要: 金属铁 x4, 木炭 x2", Color.RED)
