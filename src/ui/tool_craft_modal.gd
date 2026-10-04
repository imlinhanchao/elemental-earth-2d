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
	var b_copper_pick = craft_list.get_node("BtnCopperPick")
	var b_iron_pick = craft_list.get_node("BtnIronPick")

	b_flint_axe.pressed.connect(_craft_flint_axe)
	b_stone_pick.pressed.connect(_craft_stone_pick)
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
	if GameState.craft_tool("flint_axe"):
		_refresh_ui()

func _craft_stone_pick() -> void:
	if GameState.craft_tool("stone_pickaxe"):
		_refresh_ui()

func _craft_copper_pick() -> void:
	if GameState.craft_tool("copper_pickaxe"):
		_refresh_ui()

func _craft_iron_pick() -> void:
	if GameState.craft_tool("iron_pickaxe"):
		_refresh_ui()
