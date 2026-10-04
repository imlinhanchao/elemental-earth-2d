# hud.gd
# 游戏主界面 HUD 控制器: 任务队列监控、上帝视角地貌、维多利亚科学工业 Theme
extends CanvasLayer

signal build_furnace_requested
signal build_reactor_requested
signal save_requested
signal load_requested
signal reset_requested

const ThemeStyler = preload("res://src/ui/theme_styler.gd")

@onready var inventory_label = $Margin/HBox/LeftBox/InvPanel/Margin/VBox/InvLabel
@onready var notice_label = $Margin/TopBox/NoticeLabel
@onready var era_label = $Margin/TopBox/EraPanel/HBox/EraLabel
@onready var territory_label = $Margin/TopBox/EraPanel/HBox/TerritoryLabel
@onready var biome_label = $Margin/TopBox/EraPanel/HBox/BiomeLabel
@onready var furnace_panel = $Margin/HBox/RightBox/FurnacePanel
@onready var furnace_info = $Margin/HBox/RightBox/FurnacePanel/Margin/VBox/FurnaceInfo
@onready var elements_label = $Margin/HBox/LeftBox/ElementsPanel/Margin/VBox/ElementsLabel

@onready var btn_save = $Margin/HBox/LeftBox/SaveHBox/BtnSave
@onready var btn_load = $Margin/HBox/LeftBox/SaveHBox/BtnLoad
@onready var btn_reset = $Margin/HBox/LeftBox/SaveHBox/BtnReset

# 任务队列 UI 控件
@onready var task_panel = $Margin/HBox/CenterSpacer/TaskQueuePanel
@onready var task_queue_count = $Margin/HBox/CenterSpacer/TaskQueuePanel/Margin/VBox/HeaderHBox/QueueCount
@onready var task_active_box = $Margin/HBox/CenterSpacer/TaskQueuePanel/Margin/VBox/ActiveTaskBox
@onready var task_active_title = $Margin/HBox/CenterSpacer/TaskQueuePanel/Margin/VBox/ActiveTaskBox/ActiveTitle
@onready var task_progress_bar = $Margin/HBox/CenterSpacer/TaskQueuePanel/Margin/VBox/ActiveTaskBox/ProgressBar
@onready var task_active_time = $Margin/HBox/CenterSpacer/TaskQueuePanel/Margin/VBox/ActiveTaskBox/ActiveTime
@onready var task_btn_cancel_active = $Margin/HBox/CenterSpacer/TaskQueuePanel/Margin/VBox/ActiveTaskBox/BtnCancelActive
@onready var task_queue_list = $Margin/HBox/CenterSpacer/TaskQueuePanel/Margin/VBox/QueueList

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
	
	btn_save.pressed.connect(func(): save_requested.emit())
	btn_load.pressed.connect(func(): load_requested.emit())
	btn_reset.pressed.connect(func(): reset_requested.emit())
	
	furnace_panel.visible = false
	_update_inventory_ui()
	_update_elements_ui()
	_update_era_label()
	_update_task_queue_ui()
	
	notice_label.text = "🖱️ 鼠标左键点击瓦片执行开采/砍树/打水 | 右键拖拽视野 | 滚轮缩放 | [L]实验台 [T]锻造 [P]周期表"

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

func _close_all_modals() -> void:
	if periodic_modal.visible: periodic_modal.visible = false
	if lab_modal.visible: lab_modal.visible = false
	if tool_modal.visible: tool_modal.visible = false
	if furnace_panel.visible: furnace_panel.visible = false

func _process(_delta: float) -> void:
	if current_nearby_furnace != null and furnace_panel.visible:
		var buf = current_nearby_furnace.buffer
		furnace_info.text = "【炉膛状态】\n温度: %d K (%d ℃)\n状态: %s\n物料: %s\n点击下方按钮投入原料" % [
			int(buf.temperature),
			int(buf.temperature - 273.15),
			("🔥 燃烧中" if current_nearby_furnace.is_active_fire else "❄️ 未生火"),
			(str(buf.components) if buf.components.size() > 0 else "空")
		]

func _update_task_queue_ui() -> void:
	task_queue_count.text = "排队: %d/%d" % [GameState.task_queue.size(), GameState.MAX_QUEUE_SIZE]
	
	# 更新当前活跃工作
	if GameState.active_task.is_empty():
		task_active_title.text = "⚪ 空闲中 (点击地图瓦片分配工作)"
		task_progress_bar.visible = false
		task_active_time.visible = false
		task_btn_cancel_active.visible = false
	else:
		var t = GameState.active_task
		task_active_title.text = "%s %s" % [t.get("icon", "🔨"), t.get("title", "作业中")]
		task_progress_bar.visible = true
		task_active_time.visible = true
		task_btn_cancel_active.visible = true
	
	# 刷新排队待办列表
	for child in task_queue_list.get_children():
		child.queue_free()
		
	for i in range(GameState.task_queue.size()):
		var q_task = GameState.task_queue[i]
		var task_id = q_task.get("id")
		var chip = Button.new()
		chip.text = "#%d %s %.1fs ✕" % [i + 1, q_task.get("title", "工作"), q_task.get("total_time", 1.0)]
		chip.add_theme_font_size_override("font_size", 11)
		chip.tooltip_text = "点击从队列中取消此工作"
		chip.pressed.connect(func(): GameState.cancel_task(task_id))
		task_queue_list.add_child(chip)

func _on_task_progress_updated(task: Dictionary, percent: float, remaining_time: float) -> void:
	if not GameState.active_task.is_empty():
		task_progress_bar.value = percent
		task_active_time.text = "%.1fs" % remaining_time

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
	if territory_label:
		territory_label.text = " | 🚩 领地: 半径 %d格" % GameState.get_current_territory_radius()

func update_current_biome(biome: int) -> void:
	var b_name = "生机原野平原"
	var col = Color(0.4, 0.9, 0.4)
	if biome == 1:
		b_name = "熔岩地热带 (赤铁矿/硫磺)"
		col = Color(1.0, 0.45, 0.3)
	elif biome == 2:
		b_name = "高盐卤水湖 (石盐矿藏)"
		col = Color(0.4, 0.8, 1.0)
	elif biome == 3:
		b_name = "原始古橡深林 (高产木材)"
		col = Color(0.2, 0.9, 0.3)
		
	if biome_label:
		biome_label.text = " | 📍 当前地貌: %s" % b_name
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
