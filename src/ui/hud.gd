# hud.gd
# 游戏主界面 HUD
extends CanvasLayer

@onready var inventory_label = $Margin/HBox/LeftBox/InvPanel/Margin/VBox/InvLabel
@onready var notice_label = $Margin/TopBox/NoticeLabel
@onready var furnace_panel = $Margin/HBox/RightBox/FurnacePanel
@onready var furnace_info = $Margin/HBox/RightBox/FurnacePanel/Margin/VBox/FurnaceInfo
@onready var elements_label = $Margin/HBox/LeftBox/ElementsPanel/Margin/VBox/ElementsLabel

var current_nearby_furnace: Node2D = null

func _ready() -> void:
	GameState.notification_posted.connect(_on_notification_posted)
	GameState.element_discovered.connect(_on_element_discovered)
	GameState.inventory.item_changed.connect(_on_item_changed)
	
	furnace_panel.visible = false
	_update_inventory_ui()
	_update_elements_ui()

func _process(_delta: float) -> void:
	if current_nearby_furnace != null:
		var buf = current_nearby_furnace.buffer
		furnace_info.text = "【炉膛状态】\n温度: %d K (%d ℃)\n状态: %s\n物料: %s" % [
			int(buf.temperature),
			int(buf.temperature - 273.15),
			("🔥 燃烧中" if current_nearby_furnace.is_active_fire else "❄️ 未生火"),
			(str(buf.components) if buf.components.size() > 0 else "空")
		]

func _update_inventory_ui() -> void:
	var text = "🎒 玩家行囊:\n"
	if GameState.inventory.items.is_empty():
		text += "（空）\n"
	else:
		for k in GameState.inventory.items.keys():
			var item = DataDB.get_item(k)
			var iname = item.get("name", k)
			text += "• %s x%d\n" % [iname, GameState.inventory.items[k]]
	inventory_label.text = text

func _update_elements_ui() -> void:
	var text = "🌟 已点亮化学元素 (%d/118):\n" % GameState.discovered_elements.size()
	for num in GameState.discovered_elements:
		var elem = DataDB.get_element(num)
		text += "[#%d %s %s] " % [num, elem.get("symbol", ""), elem.get("name", "")]
	elements_label.text = text

func _on_item_changed(_key: String, _count: int) -> void:
	_update_inventory_ui()

func _on_element_discovered(_num: int, _key: String) -> void:
	_update_elements_ui()

func _on_notification_posted(msg: String, col: Color) -> void:
	notice_label.text = msg
	notice_label.modulate = col
	var tw = create_tween()
	notice_label.scale = Vector2(1.2, 1.2)
	tw.tween_property(notice_label, "scale", Vector2.ONE, 0.2)

func show_furnace_ui(furnace: Node2D) -> void:
	current_nearby_furnace = furnace
	furnace_panel.visible = true

func hide_furnace_ui() -> void:
	current_nearby_furnace = null
	furnace_panel.visible = false

func _on_btn_add_fuel_pressed() -> void:
	if current_nearby_furnace:
		current_nearby_furnace.add_fuel()

func _on_btn_add_malachite_pressed() -> void:
	if current_nearby_furnace:
		current_nearby_furnace.add_ore("malachite", 1)

func _on_btn_add_iron_ore_pressed() -> void:
	if current_nearby_furnace:
		current_nearby_furnace.add_ore("iron_ore", 1)
