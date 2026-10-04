# hud.gd
# 游戏主界面 HUD 控制器: 现代战略 4X 范式，纯图标动作坞，顶部横向资源胶囊栏，微型作业胶囊
extends CanvasLayer

signal build_furnace_requested
signal build_reactor_requested
signal save_requested
signal load_requested
signal reset_requested

const ThemeStyler = preload("res://src/ui/theme_styler.gd")

# 顶部导航与状态条
@onready var era_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/EraLabel
@onready var territory_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/TerritoryLabel
@onready var biome_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/BiomeLabel
@onready var notice_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/NoticeLabel
@onready var elements_summary_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/ElementsChip/ElementsSummaryLabel
@onready var btn_menu = $Margin/MainVBox/TopBarPanel/Margin/HBox/BtnMenu

# 顶部资源胶囊数值标签
@onready var val_wood = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipWood/Val
@onready var val_stone = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipStone/Val
@onready var val_water = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipWater/Val
@onready var val_charcoal = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipCharcoal/Val
@onready var val_ore = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipOre/Val
@onready var val_copper = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipCopper/Val
@onready var val_iron = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipIron/Val
@onready var val_salt = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipSalt/Val
@onready var val_sulfur = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipSulfur/Val

# 左侧紧凑图标动作坞 (Icon Action Dock)
@onready var btn_lab = $Margin/MainVBox/BodyHBox/ActionDock/Margin/DockVBox/BtnLab
@onready var btn_tools = $Margin/MainVBox/BodyHBox/ActionDock/Margin/DockVBox/BtnTools
@onready var btn_periodic = $Margin/MainVBox/BodyHBox/ActionDock/Margin/DockVBox/BtnPeriodic
@onready var btn_build = $Margin/MainVBox/BodyHBox/ActionDock/Margin/DockVBox/BtnBuild
@onready var btn_build_reactor = $Margin/MainVBox/BodyHBox/ActionDock/Margin/DockVBox/BtnBuildReactor
@onready var btn_backpack = $Margin/MainVBox/BodyHBox/ActionDock/Margin/DockVBox/BtnBackpack
@onready var btn_save = $Margin/MainVBox/BodyHBox/ActionDock/Margin/DockVBox/BtnSave
@onready var btn_load = $Margin/MainVBox/BodyHBox/ActionDock/Margin/DockVBox/BtnLoad
@onready var btn_settings = $Margin/MainVBox/BodyHBox/ActionDock/Margin/DockVBox/BtnSettings

# 行囊明细浮窗 (可随时折叠抽屉)
@onready var inv_drawer = $Margin/MainVBox/BodyHBox/InvDrawer
@onready var inv_label = $Margin/MainVBox/BodyHBox/InvDrawer/Margin/VBox/Scroll/InvLabel
@onready var btn_close_inv = $Margin/MainVBox/BodyHBox/InvDrawer/Margin/VBox/Header/BtnCloseInv

# 底部微型作业胶囊 (Task Capsule)
@onready var task_capsule = $Margin/MainVBox/BodyHBox/CenterSpacer/TaskCapsule
@onready var task_active_box = $Margin/MainVBox/BodyHBox/CenterSpacer/TaskCapsule/Margin/VBox/ActiveTaskBox
@onready var task_active_title = $Margin/MainVBox/BodyHBox/CenterSpacer/TaskCapsule/Margin/VBox/ActiveTaskBox/ActiveTitle
@onready var task_progress_bar = $Margin/MainVBox/BodyHBox/CenterSpacer/TaskCapsule/Margin/VBox/ActiveTaskBox/ProgressBar
@onready var task_active_time = $Margin/MainVBox/BodyHBox/CenterSpacer/TaskCapsule/Margin/VBox/ActiveTaskBox/ActiveTime
@onready var task_btn_cancel_active = $Margin/MainVBox/BodyHBox/CenterSpacer/TaskCapsule/Margin/VBox/ActiveTaskBox/BtnCancelActive
@onready var task_queue_list = $Margin/MainVBox/BodyHBox/CenterSpacer/TaskCapsule/Margin/VBox/QueueList

# 熔炉状态监测
@onready var furnace_panel = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel
@onready var furnace_info = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/FurnaceInfo
@onready var btn_add_fuel = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/BtnAddFuel
@onready var btn_add_malachite = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/BtnAddMalachite
@onready var btn_add_iron_ore = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/BtnAddIronOre

# 模态弹窗系统
@onready var periodic_modal = $PeriodicTableModal
@onready var lab_modal = $LabWorkbenchModal
@onready var tool_modal = $ToolCraftModal
@onready var era_modal = $EraTransitionModal
@onready var save_load_modal = $SaveLoadModal
@onready var settings_modal = $SettingsModal
@onready var pause_menu = $PauseMenu

var current_nearby_furnace: Node2D = null

func _ready() -> void:
	var sc_theme = ThemeStyler.create_scientific_theme()
	$Margin.theme = sc_theme
	periodic_modal.theme = sc_theme
	lab_modal.theme = sc_theme
	tool_modal.theme = sc_theme
	era_modal.theme = sc_theme
	save_load_modal.theme = sc_theme
	settings_modal.theme = sc_theme
	pause_menu.theme = sc_theme
	
	GameState.notification_posted.connect(_on_notification_posted)
	GameState.element_discovered.connect(_on_element_discovered)
	GameState.inventory.item_changed.connect(_on_item_changed)
	GameState.era_advanced.connect(_on_era_advanced)
	
	# 任务作业队列信号绑定
	GameState.task_started.connect(func(_t): _update_task_queue_ui())
	GameState.task_progress_updated.connect(_on_task_progress_updated)
	GameState.task_completed.connect(func(_t): _update_task_queue_ui())
	GameState.task_cancelled.connect(func(_t): _update_task_queue_ui())
	GameState.task_queue_changed.connect(_update_task_queue_ui)
	
	task_btn_cancel_active.pressed.connect(func():
		if not GameState.active_task.is_empty():
			GameState.cancel_task(GameState.active_task.get("id"))
	)
	
	# 顶部系统菜单按钮
	btn_menu.pressed.connect(func(): pause_menu.open())
	
	# 动作坞按钮绑定
	btn_lab.pressed.connect(func(): lab_modal.toggle())
	btn_tools.pressed.connect(func(): tool_modal.toggle())
	btn_periodic.pressed.connect(func(): periodic_modal.toggle())
	btn_build.pressed.connect(_on_btn_build_furnace_pressed)
	btn_build_reactor.pressed.connect(_on_btn_build_reactor_requested)
	btn_backpack.pressed.connect(func(): inv_drawer.visible = not inv_drawer.visible)
	btn_close_inv.pressed.connect(func(): inv_drawer.visible = false)
	btn_save.pressed.connect(func(): save_load_modal.open(0, get_parent()))
	btn_load.pressed.connect(func(): save_load_modal.open(1, get_parent()))
	btn_settings.pressed.connect(func(): settings_modal.open())
	
	btn_add_fuel.pressed.connect(_on_btn_add_fuel_pressed)
	btn_add_malachite.pressed.connect(_on_btn_add_malachite_pressed)
	btn_add_iron_ore.pressed.connect(_on_btn_add_iron_ore_pressed)
	
	pause_menu.save_requested.connect(func():
		pause_menu.close()
		save_load_modal.open(0, get_parent())
	)
	pause_menu.load_requested.connect(func():
		pause_menu.close()
		save_load_modal.open(1, get_parent())
	)
	pause_menu.settings_requested.connect(func():
		pause_menu.close()
		settings_modal.open()
	)
	
	furnace_panel.visible = false
	inv_drawer.visible = false
	_update_inventory_ui()
	_update_elements_ui()
	_update_era_label()
	_update_task_queue_ui()
	
	notice_label.text = "左键瓦片排队作业 · 右键拖拽视野 · 滚轮缩放 · [ESC]菜单"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _has_any_modal_open():
			_close_all_modals()
			get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			periodic_modal.toggle()
		elif event.keycode == KEY_L:
			lab_modal.toggle()
		elif event.keycode == KEY_T:
			tool_modal.toggle()
		elif event.keycode == KEY_B:
			inv_drawer.visible = not inv_drawer.visible
		elif event.keycode == KEY_F or event.keycode == KEY_C:
			_on_btn_build_furnace_pressed()
		elif event.keycode == KEY_R:
			_on_btn_build_reactor_requested()
		elif event.keycode == KEY_F5:
			save_load_modal.open(0, get_parent())
		elif event.keycode == KEY_F9:
			save_load_modal.open(1, get_parent())
		elif event.keycode == KEY_O:
			settings_modal.open()
		elif event.keycode == KEY_ESCAPE:
			_close_all_modals()

func _has_any_modal_open() -> bool:
	return periodic_modal.visible or lab_modal.visible or tool_modal.visible or furnace_panel.visible or save_load_modal.visible or settings_modal.visible or pause_menu.visible or inv_drawer.visible

func _close_all_modals() -> void:
	var closed_any = false
	if periodic_modal.visible: periodic_modal.visible = false; closed_any = true
	if lab_modal.visible: lab_modal.visible = false; closed_any = true
	if tool_modal.visible: tool_modal.visible = false; closed_any = true
	if inv_drawer.visible: inv_drawer.visible = false; closed_any = true
	if furnace_panel.visible: furnace_panel.visible = false; closed_any = true
	if save_load_modal.visible: save_load_modal.close(); closed_any = true
	if settings_modal.visible: settings_modal.close(); closed_any = true
	if not closed_any:
		pause_menu.toggle()

func _process(_delta: float) -> void:
	if current_nearby_furnace != null and furnace_panel.visible:
		var buf = current_nearby_furnace.buffer
		furnace_info.text = "【炉膛状态】\n温度: %d K (%d ℃)\n状态: %s\n物料: %s" % [
			int(buf.temperature),
			int(buf.temperature - 273.15),
			("燃烧中" if current_nearby_furnace.is_active_fire else "未生火"),
			(str(buf.components) if buf.components.size() > 0 else "空")
		]

func _update_task_queue_ui() -> void:
	if GameState.active_task.is_empty():
		task_active_title.text = "作业队列 空闲中"
		task_progress_bar.visible = false
		task_active_time.visible = false
		task_btn_cancel_active.visible = false
	else:
		var t = GameState.active_task
		task_active_title.text = "%s" % t.get("title", "作业中")
		task_progress_bar.visible = true
		task_active_time.visible = true
		task_btn_cancel_active.visible = true
	
	for child in task_queue_list.get_children():
		child.queue_free()
		
	for i in range(GameState.task_queue.size()):
		var q_task = GameState.task_queue[i]
		var task_id = q_task.get("id")
		var chip = Button.new()
		chip.text = "#%d %s %.1fs ✕" % [i + 1, q_task.get("title", "工作"), q_task.get("time_required", 1.0)]
		chip.custom_minimum_size = Vector2(0, 24)
		chip.add_theme_font_size_override("font_size", 11)
		chip.tooltip_text = "点击从队列中取消此工作"
		chip.pressed.connect(func(): GameState.cancel_task(task_id))
		task_queue_list.add_child(chip)

func _on_task_progress_updated(_task: Dictionary, percent: float, remaining_time: float) -> void:
	if not GameState.active_task.is_empty():
		task_progress_bar.value = percent
		task_active_time.text = "%.1fs" % remaining_time

func _update_inventory_ui() -> void:
	# 1. 刷新顶部资源胶囊数值
	val_wood.text = str(GameState.inventory.get_count("wood"))
	val_stone.text = str(GameState.inventory.get_count("stone"))
	val_water.text = str(GameState.inventory.get_count("water"))
	val_charcoal.text = str(GameState.inventory.get_count("charcoal"))
	val_ore.text = str(GameState.inventory.get_count("malachite") + GameState.inventory.get_count("iron_ore"))
	val_copper.text = str(GameState.inventory.get_count("copper"))
	val_iron.text = str(GameState.inventory.get_count("iron"))
	val_salt.text = str(GameState.inventory.get_count("halite"))
	val_sulfur.text = str(GameState.inventory.get_count("sulfur"))
	
	# 2. 刷新行囊抽屉完整列表
	var text = ""
	if GameState.inventory.items.is_empty():
		text = "（空）\n"
	else:
		for k in GameState.inventory.items.keys():
			var item = DataDB.get_item(k)
			var iname = item.get("name", k)
			text += "• %s: %d\n" % [iname, GameState.inventory.items[k]]
	inv_label.text = text

func _update_elements_ui() -> void:
	elements_summary_label.text = "%d/118" % GameState.discovered_elements.size()

func _update_era_label() -> void:
	era_label.text = "%s" % GameState.ERA_NAMES[GameState.current_era]
	if territory_label:
		territory_label.text = "领地: %d 格" % GameState.get_current_territory_radius()

func update_current_biome(biome: int) -> void:
	var b_name = "生机原野平原"
	var col = Color(0.4, 0.9, 0.4)
	if biome == 1:
		b_name = "熔岩地热带"
		col = Color(1.0, 0.45, 0.3)
	elif biome == 2:
		b_name = "高盐卤水湖"
		col = Color(0.4, 0.8, 1.0)
	elif biome == 3:
		b_name = "原始古橡林"
		col = Color(0.2, 0.9, 0.3)
		
	if biome_label:
		biome_label.text = b_name
		biome_label.modulate = col

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
	notice_label.scale = Vector2(1.08, 1.08)
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
