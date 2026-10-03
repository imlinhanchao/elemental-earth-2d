# hud.gd
# 游戏主界面 HUD 控制器 (注入复古科学工业 Theme)
extends CanvasLayer

signal build_furnace_requested
signal build_reactor_requested

const ThemeStyler = preload("res://src/ui/theme_styler.gd")

@onready var inventory_label = $Margin/HBox/LeftBox/InvPanel/Margin/VBox/InvLabel
@onready var notice_label = $Margin/TopBox/NoticeLabel
@onready var era_label = $Margin/TopBox/EraPanel/EraLabel
@onready var furnace_panel = $Margin/HBox/RightBox/FurnacePanel
@onready var furnace_info = $Margin/HBox/RightBox/FurnacePanel/Margin/VBox/FurnaceInfo
@onready var elements_label = $Margin/HBox/LeftBox/ElementsPanel/Margin/VBox/ElementsLabel

@onready var periodic_modal = $PeriodicTableModal
@onready var lab_modal = $LabWorkbenchModal
@onready var tool_modal = $ToolCraftModal
@onready var era_modal = $EraTransitionModal

var current_nearby_furnace: Node2D = null

func _ready() -> void:
	# 全局注入维多利亚科学 UI 主题
	var sc_theme = ThemeStyler.create_scientific_theme()
	$Margin.theme = sc_theme
	periodic_modal.theme = sc_theme
	lab_modal.theme = sc_theme
	tool_modal.theme = sc_theme
	era_modal.theme = sc_theme
	
	GameState.notification_posted.connect(_on_notification_posted)
	GameState.element_discovered.connect(_on_element_discovered)
	GameState.inventory.item_changed.connect(_on_item_changed)
	GameState.era_advanced.connect(_on_era_advanced)
	
	furnace_panel.visible = false
	_update_inventory_ui()
	_update_elements_ui()
	_update_era_label()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			periodic_modal.toggle()
		elif event.keycode == KEY_L:
			lab_modal.toggle()
		elif event.keycode == KEY_T:
			tool_modal.toggle()
		elif event.keycode == KEY_C or event.keycode == KEY_B:
			_on_btn_build_furnace_pressed()
		elif event.keycode == KEY_R:
			_on_btn_build_reactor_requested()
		elif event.keycode == KEY_ESCAPE:
			_close_all_modals()
	
	# 熔炉快捷键 1/2/3
	if current_nearby_furnace != null:
		if event.is_action_pressed("quick_action_1"):
			current_nearby_furnace.add_fuel()
		elif event.is_action_pressed("quick_action_2"):
			current_nearby_furnace.add_ore("malachite", 1)
		elif event.is_action_pressed("quick_action_3"):
			current_nearby_furnace.add_ore("iron_ore", 1)
		elif event.is_action_pressed("interact"):
			furnace_panel.visible = not furnace_panel.visible

func _close_all_modals() -> void:
	if periodic_modal.visible: periodic_modal.visible = false
	if lab_modal.visible: lab_modal.visible = false
	if tool_modal.visible: tool_modal.visible = false
	if furnace_panel.visible: furnace_panel.visible = false

func _process(_delta: float) -> void:
	if current_nearby_furnace != null and furnace_panel.visible:
		var buf = current_nearby_furnace.buffer
		furnace_info.text = "【炉膛状态】\n温度: %d K (%d ℃)\n状态: %s\n物料: %s\n快捷键: [1]加柴生火 [2]铜 [3]铁" % [
			int(buf.temperature),
			int(buf.temperature - 273.15),
			("🔥 燃烧中" if current_nearby_furnace.is_active_fire else "❄️ 未生火"),
			(str(buf.components) if buf.components.size() > 0 else "空")
		]

func _update_inventory_ui() -> void:
	var text = "🎒 行囊清单:\n"
	if GameState.inventory.items.is_empty():
		text += "（空）\n"
	else:
		for k in GameState.inventory.items.keys():
			var item = DataDB.get_item(k)
			var iname = item.get("name", k)
			text += "• %s: %d\n" % [iname, GameState.inventory.items[k]]
	inventory_label.text = text

func _update_elements_ui() -> void:
	var text = "🌟 点亮元素 (%d/118) [P]:\n" % GameState.discovered_elements.size()
	for num in GameState.discovered_elements:
		var elem = DataDB.get_element(num)
		text += "[#%d %s] " % [num, elem.get("symbol", "")]
	elements_label.text = text

func _update_era_label() -> void:
	era_label.text = "  🏛️ 文明纪元: %s  " % GameState.ERA_NAMES[GameState.current_era]

func _on_era_advanced(_old: int, _new: int, _name: String) -> void:
	_update_era_label()

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

func _on_btn_build_reactor_requested() -> void:
	build_reactor_requested.emit()

func _on_btn_periodic_table_pressed() -> void:
	periodic_modal.toggle()

func _on_btn_lab_pressed() -> void:
	lab_modal.toggle()

func _on_btn_tools_pressed() -> void:
	tool_modal.toggle()
