# hud.gd
# 游戏主界面 HUD 控制器 (纯键盘/手柄全功能支持)
extends CanvasLayer

signal build_furnace_requested

@onready var inventory_label = $Margin/HBox/LeftBox/InvPanel/Margin/VBox/InvLabel
@onready var notice_label = $Margin/TopBox/NoticeLabel
@onready var furnace_panel = $Margin/HBox/RightBox/FurnacePanel
@onready var furnace_info = $Margin/HBox/RightBox/FurnacePanel/Margin/VBox/FurnaceInfo
@onready var elements_label = $Margin/HBox/LeftBox/ElementsPanel/Margin/VBox/ElementsLabel
@onready var periodic_modal = $PeriodicTableModal

var current_nearby_furnace: Node2D = null

func _ready() -> void:
	GameState.notification_posted.connect(_on_notification_posted)
	GameState.element_discovered.connect(_on_element_discovered)
	GameState.inventory.item_changed.connect(_on_item_changed)
	
	furnace_panel.visible = false
	_update_inventory_ui()
	_update_elements_ui()

func _unhandled_input(event: InputEvent) -> void:
	# 周期表快捷键 (P 键 / 手柄 Select)
	if event.is_action_pressed("open_periodic"):
		periodic_modal.toggle()
	# 建造快捷键 (C 键 / B 键 / 手柄 Y)
	elif event.is_action_pressed("open_build"):
		_on_btn_build_furnace_pressed()
	# ESC 关闭打开的弹窗
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if periodic_modal.visible:
			periodic_modal.visible = false
		elif furnace_panel.visible:
			furnace_panel.visible = false
	# 熔炉快捷投料键 (1 / 2 / 3 数字键)
	elif current_nearby_furnace != null:
		if event.is_action_pressed("quick_action_1"):
			current_nearby_furnace.add_fuel()
		elif event.is_action_pressed("quick_action_2"):
			current_nearby_furnace.add_ore("malachite", 1)
		elif event.is_action_pressed("quick_action_3"):
			current_nearby_furnace.add_ore("iron_ore", 1)
		elif event.is_action_pressed("interact"):
			furnace_panel.visible = not furnace_panel.visible

func _process(_delta: float) -> void:
	if current_nearby_furnace != null and furnace_panel.visible:
		var buf = current_nearby_furnace.buffer
		furnace_info.text = "【炉膛状态】\n温度: %d K (%d ℃)\n状态: %s\n物料: %s\n快捷键: [1]生火 [2]铜 [3]铁" % [
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
	var text = "🌟 已点亮化学元素 (%d/118) [按 P 查看]:\n" % GameState.discovered_elements.size()
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
	notice_label.scale = Vector2(1.15, 1.15)
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

func _on_btn_build_furnace_pressed() -> void:
	build_furnace_requested.emit()

func _on_btn_periodic_table_pressed() -> void:
	periodic_modal.toggle()
