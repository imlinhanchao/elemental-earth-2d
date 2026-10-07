# hud.gd
# 游戏主界面 HUD 控制器: 现代战略范式，底部多分类动作坞，右侧作业队列，全套矢量美术图标
extends CanvasLayer

signal build_furnace_requested
signal build_reactor_requested
signal build_structure_requested(structure_key: String)
signal cancel_placement_requested
signal save_requested
signal load_requested
signal reset_requested

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const ItemIconManager = preload("res://src/ui/item_icon_manager.gd")
const ElementDiscoveryModal = preload("res://src/ui/element_discovery_modal.gd")

enum CategoryTab { NONE, LAB, TECH, CRAFT, BUILD, INVENTORY }
var current_tab: CategoryTab = CategoryTab.NONE

# 顶部导航与状态条
@onready var logo_icon = $Margin/MainVBox/TopBarPanel/Margin/HBox/LogoBox/LogoIcon
@onready var logo_title = $Margin/MainVBox/TopBarPanel/Margin/HBox/LogoBox/LogoTextVBox/LogoTitle
@onready var logo_sub = $Margin/MainVBox/TopBarPanel/Margin/HBox/LogoBox/LogoTextVBox/LogoSub
@onready var era_badge_btn = $Margin/MainVBox/TopBarPanel/Margin/HBox/LogoBox/EraBadgeBtn
@onready var save_dot = $Margin/MainVBox/TopBarPanel/Margin/HBox/SaveDot
@onready var btn_menu = $Margin/MainVBox/TopBarPanel/Margin/HBox/BtnMenu

# 顶部资源数值标签 (仅保留 5 项核心资源: 石头、木头、燧石、矿、燃料)
@onready var chip_stone = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipStone
@onready var val_stone = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipStone/Val

@onready var chip_wood = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipWood
@onready var val_wood = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipWood/Val

@onready var chip_flint = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipFlint
@onready var val_flint = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipFlint/Val

@onready var chip_ore = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipOre
@onready var val_ore = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipOre/Val

@onready var chip_fuel = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipFuel
@onready var val_fuel = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipFuel/Val

# 右侧作业队列面板 (Task Queue Dock)
@onready var right_box = $Margin/MainVBox/BodyHBox/RightBox
@onready var task_queue_count = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/Header/QueueCount
@onready var task_active_title = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/HBox/ActiveTitle
@onready var task_btn_cancel_active = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/HBox/BtnCancelActive
@onready var task_progress_box = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/ProgressHBox
@onready var task_progress_bar = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/ProgressHBox/ProgressBar
@onready var task_active_time = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/ProgressHBox/ActiveTime
@onready var task_hsep = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/HSep
@onready var task_queue_scroll = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/QueueScroll
@onready var task_queue_list = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/QueueScroll/QueueList

# 熔炉近场状态监测

# 底部多分类动作坞 (Bottom Categorized Action Dock)
@onready var action_drawer = $Margin/MainVBox/BottomArea/ActionDrawer
@onready var drawer_title = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Header/DrawerTitle
@onready var btn_close_drawer = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Header/BtnCloseDrawer
@onready var drawer_grid = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Scroll/DrawerGrid

@onready var btn_tab_lab = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabLab
@onready var btn_tab_tech = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabTech
@onready var btn_tab_craft = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabCraft
@onready var btn_tab_build = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabBuild
@onready var btn_tab_inventory = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabInventory
@onready var queue_badge = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/QueueBadge

# 模态弹窗系统
@onready var periodic_modal = $PeriodicTableModal
@onready var lab_modal = $LabWorkbenchModal
@onready var tech_modal = $TechTreeModal
@onready var era_modal = $EraTransitionModal
@onready var save_load_modal = $SaveLoadModal
@onready var settings_modal = $SettingsModal
@onready var pause_menu = $PauseMenu
@onready var inventory_modal = $InventoryModal
@onready var tutorial_dock = $TutorialDock
@onready var reactor_modal = $ReactorModal

var element_discovery_modal: ElementDiscoveryModal = null

func get_item_icon(key: String) -> Texture2D:
	return ItemIconManager.get_icon(key)

func _ready() -> void:
	var sc_theme = ThemeStyler.create_scientific_theme()
	$Margin.theme = sc_theme
	periodic_modal.theme = sc_theme
	lab_modal.theme = sc_theme
	reactor_modal.theme = sc_theme
	tech_modal.theme = sc_theme
	era_modal.theme = sc_theme
	save_load_modal.theme = sc_theme
	settings_modal.theme = sc_theme
	pause_menu.theme = sc_theme
	inventory_modal.theme = sc_theme
	tutorial_dock.theme = sc_theme
	tutorial_dock.visible = GameState.is_tutorial_active
	
	element_discovery_modal = ElementDiscoveryModal.new()
	element_discovery_modal.theme = sc_theme
	add_child(element_discovery_modal)
	element_discovery_modal.open_periodic_table_requested.connect(func(): periodic_modal.open(element_discovery_modal.current_elem_number))
	element_discovery_modal.modal_closed.connect(func():
		if era_modal and era_modal.has_method("on_element_discovery_closed"):
			era_modal.on_element_discovery_closed()
	)
	
	GameState.notification_posted.connect(_on_notification_posted)
	GameState.element_discovered.connect(_on_element_discovered)
	GameState.inventory.item_changed.connect(_on_item_changed)
	GameState.era_advanced.connect(_on_era_advanced)
	GameState.milestone_completed.connect(_on_milestone_completed)
	
	# 作业队列信号
	GameState.task_started.connect(func(_t): _update_task_queue_ui())
	GameState.task_progress_updated.connect(_on_task_progress_updated)
	GameState.task_completed.connect(func(_t): _update_task_queue_ui())
	GameState.task_cancelled.connect(func(_t): _update_task_queue_ui())
	GameState.task_queue_changed.connect(_update_task_queue_ui)
	
	task_btn_cancel_active.pressed.connect(func():
		if not GameState.active_task.is_empty():
			GameState.cancel_task(GameState.active_task.get("id"))
	)
	
	# 系统菜单
	btn_menu.pressed.connect(func(): pause_menu.open())
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
	
	# 底部动作分类按钮绑定
	btn_tab_lab.pressed.connect(func(): _toggle_category(CategoryTab.LAB))
	btn_tab_tech.pressed.connect(func(): _toggle_category(CategoryTab.TECH))
	btn_tab_craft.pressed.connect(func(): _toggle_category(CategoryTab.CRAFT))
	btn_tab_build.pressed.connect(func(): _toggle_category(CategoryTab.BUILD))
	btn_tab_inventory.pressed.connect(func(): _toggle_category(CategoryTab.INVENTORY))
	btn_close_drawer.pressed.connect(_close_drawer)
	
	# 悬停在行囊按钮上时动态显示全量资源详情提示
	btn_tab_inventory.mouse_entered.connect(_update_inventory_tooltip)
	
	# 存档状态点 (8px 圆点，默认灰色成功，失败红色)
	_setup_save_dot()
	
	if era_badge_btn:
		era_badge_btn.pressed.connect(_on_era_badge_pressed)
	
	_build_status_chips()
	GameState.tool_equipped.connect(func(_k): _update_status_chips())
	GameState.element_discovered.connect(func(_n, _k): _update_status_chips())
	_build_drawer_filters()
	
	action_drawer.visible = false
	_apply_scheme3_styling()
	_update_inventory_ui()
	_update_era_label()
	_update_task_queue_ui()
	_update_status_chips()

# --- 顶栏：当前装备与元素周期表 ---
# 装备胶囊显示斧、镐两个槽位 (未装备时半透明的工具图标 + 「徒手」)；元素按钮显示已发现数量，点击打开周期表
const TOOL_SLOTS: Array = [["axe", "斧"], ["pickaxe", "镐"]]
var _tool_chip: Button = null
var _tool_icons: Dictionary = {}   # slot -> TextureRect
var _tool_labels: Dictionary = {}  # slot -> Label
var _element_btn: Button = null

func _build_status_chips() -> void:
	var bar = $Margin/MainVBox/TopBarPanel/Margin/HBox
	_tool_chip = Button.new()
	_tool_chip.name = "ToolChip"
	_tool_chip.focus_mode = Control.FOCUS_NONE
	_tool_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tool_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tool_chip.custom_minimum_size = Vector2(0, 30)
	_tool_chip.pressed.connect(func():
		if ModalStack.is_empty(): _toggle_category(CategoryTab.CRAFT)
	)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	_tool_chip.add_child(row)
	for i in range(TOOL_SLOTS.size()):
		var slot: String = TOOL_SLOTS[i][0]
		if i > 0:
			var sep = VSeparator.new()
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(sep)
		var ic = TextureRect.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.custom_minimum_size = Vector2(20, 20)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
		var lbl = Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
		row.add_child(lbl)
		_tool_icons[slot] = ic
		_tool_labels[slot] = lbl
	bar.add_child(_tool_chip)
	bar.move_child(_tool_chip, 1)

	_element_btn = Button.new()
	_element_btn.name = "ElementBtn"
	_element_btn.focus_mode = Control.FOCUS_NONE
	_element_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_element_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_element_btn.icon = ItemIconManager.themed(ItemIconManager.load_texture("res://assets/icons/periodic_table.svg"))
	_element_btn.expand_icon = true
	_element_btn.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
	_element_btn.pressed.connect(func():
		if ModalStack.is_empty(): periodic_modal.open()
	)
	bar.add_child(_element_btn)
	bar.move_child(_element_btn, 2)

# 工具名优先取制作配方的中文名 (items.json 没有收录部分工具，get_item 会回退成内部键名)
func _tool_display_name(tool_key: String) -> String:
	var n = str(DataDB.get_crafting_recipe(tool_key).get("name", ""))
	if n == "" or n == tool_key:
		n = str(DataDB.get_item(tool_key).get("name", tool_key))
	return n

func _update_status_chips() -> void:
	if _tool_chip == null:
		return
	var tip: Array[String] = ["当前装备（点击打开制作 [T]）"]
	var font = _tool_chip.get_theme_font("font")
	var width := 24.0
	for i in range(TOOL_SLOTS.size()):
		var slot: String = TOOL_SLOTS[i][0]
		var tool_key = str(GameState.equipped_tools.get(slot, "bare_hands"))
		var bare = tool_key == "bare_hands"
		var ic: TextureRect = _tool_icons[slot]
		var lbl: Label = _tool_labels[slot]
		ic.texture = ItemIconManager.get_icon("flint_axe" if (bare and slot == "axe") else ("stone_pickaxe" if bare else tool_key))
		ic.modulate.a = 0.35 if bare else 1.0
		var nm = "徒手" if bare else _tool_display_name(tool_key)
		lbl.text = nm
		lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_MUTED if bare else ThemeStyler.PAPER_INK)
		var wt = "" if bare else "，作业 %.1f 秒" % float(DataDB.get_crafting_recipe(tool_key).get("work_time", 0.0))
		tip.append("%s：%s%s" % [TOOL_SLOTS[i][1], nm, wt if not bare and DataDB.get_crafting_recipe(tool_key).has("work_time") else ""])
		width += 20.0 + 6.0 + (font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, ThemeStyler.FONT_CAPTION).x if font else 48.0) + 6.0
	width += 14.0 * (TOOL_SLOTS.size() - 1)
	_tool_chip.custom_minimum_size = Vector2(ceil(width), 30)
	_tool_chip.tooltip_text = "\n".join(tip)

	var n = GameState.discovered_elements.size()
	_element_btn.text = "元素 %d/118" % n
	var tf = _element_btn.get_theme_font("font")
	var tw = tf.get_string_size(_element_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ThemeStyler.FONT_CAPTION).x if tf else 80.0
	_element_btn.custom_minimum_size = Vector2(ceil(tw + 18.0 + 6.0 + 28.0), 30)
	var names: Array[String] = []
	var sorted = GameState.discovered_elements.duplicate()
	sorted.sort()
	for num in sorted:
		var e = DataDB.get_element(num)
		names.append("%s %s" % [e.get("symbol", "?"), e.get("name", "")])
	_element_btn.tooltip_text = "已发现元素 %d/118（点击打开周期表 [P]）%s" % [n, ("\n" + "、".join(names)) if not names.is_empty() else "\n还没有发现元素"]

func _style_status_chips() -> void:
	if _tool_chip == null:
		return
	for b in [_tool_chip, _element_btn]:
		var normal = ThemeStyler.create_pill_box(15, ThemeStyler.adapt(Color(1, 1, 1, 0.35)), ThemeStyler.PAPER_BORDER)
		normal.content_margin_left = 14
		normal.content_margin_right = 14
		normal.content_margin_top = 4
		normal.content_margin_bottom = 4
		normal.shadow_size = 0
		var hover = normal.duplicate()
		hover.border_color = ThemeStyler.COLOR_ACCENT
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", ThemeStyler.PAPER_INK)
		b.add_theme_color_override("font_hover_color", ThemeStyler.PAPER_INK)

func _on_era_badge_pressed() -> void:
	if era_modal:
		era_modal.show_current_era_status()

func _toggle_category(tab: CategoryTab) -> void:
	# 实验、科技、行囊是完整弹窗，直接打开；制作、建造是底部抽屉
	if tab == CategoryTab.LAB:
		_close_drawer()
		lab_modal.toggle()
		return
	if tab == CategoryTab.TECH:
		_close_drawer()
		tech_modal.toggle()
		return
	if tab == CategoryTab.INVENTORY:
		_close_drawer()
		inventory_modal.toggle()
		return

	if current_tab == tab and action_drawer.visible:
		_close_drawer()
	else:
		current_tab = tab
		action_drawer.visible = true
		_populate_drawer(tab)
		drawer_grid.get_parent().scroll_vertical = 0

func _close_drawer() -> void:
	current_tab = CategoryTab.NONE
	action_drawer.visible = false

var placement_bar: PanelContainer = null
var placement_label: Label = null
var btn_cancel_placement: Button = null

func show_placement_mode(structure_name: String) -> void:
	_close_drawer()
	if not placement_bar:
		placement_bar = PanelContainer.new()
		placement_bar.custom_minimum_size = Vector2(460, 42)
		var sbox = StyleBoxFlat.new()
		sbox.bg_color = ThemeStyler.COLOR_BG
		sbox.border_color = ThemeStyler.COLOR_SUCCESS
		sbox.border_width_left = 2
		sbox.border_width_right = 2
		sbox.border_width_top = 2
		sbox.border_width_bottom = 2
		sbox.corner_radius_top_left = 8
		sbox.corner_radius_top_right = 8
		sbox.corner_radius_bottom_left = 8
		sbox.corner_radius_bottom_right = 8
		sbox.shadow_color = ThemeStyler.adapt(Color(0.25, 0.20, 0.12, 0.22))
		sbox.shadow_size = 6
		placement_bar.add_theme_stylebox_override("panel", sbox)
		
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 16)
		placement_bar.add_child(hbox)
		
		placement_label = Label.new()
		placement_label.add_theme_font_size_override("font_size", 14)
		placement_label.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
		hbox.add_child(placement_label)
		
		btn_cancel_placement = Button.new()
		btn_cancel_placement.text = "取消建造 [ESC]"
		btn_cancel_placement.custom_minimum_size = Vector2(120, 28)
		btn_cancel_placement.add_theme_font_size_override("font_size", 12)
		btn_cancel_placement.pressed.connect(func(): cancel_placement_requested.emit())
		hbox.add_child(btn_cancel_placement)
		
		var bottom_area = $Margin/MainVBox/BottomArea
		bottom_area.add_child(placement_bar)
		bottom_area.move_child(placement_bar, bottom_area.get_child_count() - 2)
	
	placement_label.text = "选择位置放置%s（右键或 ESC 取消）" % structure_name
	placement_bar.visible = true

func hide_placement_mode() -> void:
	if placement_bar:
		placement_bar.visible = false

func _populate_drawer(tab: CategoryTab) -> void:
	if _filter_bar:
		_filter_bar.visible = tab == CategoryTab.CRAFT
		_drawer_footer.text = ""
	for n in _drawer_extras:
		if is_instance_valid(n): n.queue_free()
	_drawer_extras.clear()
	_card_used = 0
	drawer_card_by_key.clear()
	_fill_drawer(tab)
	# 本次没有用到的池中卡片隐藏
	for i in range(_card_used, _card_pool.size()):
		_card_pool[i].visible = false
	_fit_drawer_height.call_deferred()

# 卡片按行自动换行；抽屉高度随行数增长，最多 3 行，超出时滚轮上下滚动 (从第一行开始)
const DRAWER_MAX_ROWS: int = 3
func _fit_drawer_height() -> void:
	var scroll: ScrollContainer = drawer_grid.get_parent()
	var width = scroll.size.x
	if width <= 0.0:
		return
	var per_row = maxi(1, int((width + 10.0) / (CARD_SIZE.x + 10.0)))
	var n = maxi(_card_used, 1 if not _drawer_extras.is_empty() else 0)
	var rows = clampi(ceili(float(n) / per_row), 1, DRAWER_MAX_ROWS)
	scroll.custom_minimum_size.y = rows * CARD_SIZE.y + (rows - 1) * 10.0

func _fill_drawer(tab: CategoryTab) -> void:
	match tab:
		CategoryTab.TECH:
			drawer_title.text = "科技"
			_add_tech_subitems()
		CategoryTab.CRAFT:
			drawer_title.text = "制作工具与器皿"
			_add_craft_subitems()
		CategoryTab.BUILD:
			drawer_title.text = "建造设施"
			_add_build_subitems()
		CategoryTab.INVENTORY:
			drawer_title.text = "行囊"
			_add_inventory_subitems()

# --- 2. 科技分类细项 ---
func _add_tech_subitems() -> void:
	var tech_count = GameState.researched_techs.size()
	var card_all = _create_action_card(
		"科技演进树全览 [K]",
		"查看全部 6 个时代 40 项核心科技演变星图",
		get_item_icon("tech"),
		"%d/40" % tech_count,
		true
	)
	card_all.pressed.connect(func():
		_close_drawer()
		tech_modal.open()
	)
	
	for tech in DataDB.techs.values():
		var t_key = str(tech.get("key", ""))
		var t_name = str(tech.get("name", t_key))
		var t_era = int(tech.get("era", 0))
		var req_techs = tech.get("required_techs", tech.get("prerequisites", []))
		var req_items = tech.get("required_items", [])
		
		var is_researched = GameState.researched_techs.has(t_key)
		
		var prereqs_met = true
		for p in req_techs:
			if not GameState.researched_techs.has(str(p)):
				prereqs_met = false
				break
				
		if not is_researched and t_era > GameState.current_era and not prereqs_met:
			continue
			
		var items_met = true
		var cost_desc_list = []
		for req in req_items:
			var r_key = req.get("key")
			var r_qty = int(req.get("quantity", 1))
			var owned = 0
			var mat_name = ""
			if r_key is Array:
				var found_max = 0
				for alt in r_key:
					var cnt = GameState.inventory.get_count(alt)
					if cnt > found_max: found_max = cnt
					var it = DataDB.get_item(alt)
					if mat_name == "": mat_name = it.get("name", alt)
				owned = found_max
			else:
				owned = GameState.inventory.get_count(r_key)
				var it = DataDB.get_item(r_key)
				mat_name = it.get("name", r_key)
			cost_desc_list.append("%s: %d/%d" % [mat_name, owned, r_qty])
			if owned < r_qty:
				items_met = false
				
		var can_res = (not is_researched) and prereqs_met and items_met and (GameState.current_era >= t_era)
		var status_text = "已研发" if is_researched else ("可突破" if can_res else ("时代未达" if GameState.current_era < t_era else ("缺少前置" if not prereqs_met else "缺少材料")))
		var cost_str = "已掌握" if is_researched else (" · ".join(cost_desc_list) if not cost_desc_list.is_empty() else "即时研发")
		
		var card = _create_action_card(
			t_name,
			cost_str,
			get_item_icon("tech"),
			status_text,
			can_res or is_researched
		)
		if can_res:
			card.pressed.connect(func():
				if GameState.research_tech(t_key):
					_populate_drawer(CategoryTab.TECH)
			)

# --- 3. 制作分类细项 ---
# 只列当前时代及以前的配方，可制作的排在前面；顶部按类别筛选，可只看能制作的
const CRAFT_FILTERS: Array = [["all", "全部"], ["工具", "工具"], ["容器", "容器"], ["材料", "材料"], ["other", "其他"]]
var craft_filter: String = "all"
var craft_only_available: bool = false
var _filter_bar: HBoxContainer = null
var _filter_buttons: Dictionary = {}
var _only_available_btn: CheckBox = null
var _drawer_footer: Label = null

func _build_drawer_filters() -> void:
	var header = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Header
	_filter_bar = HBoxContainer.new()
	_filter_bar.add_theme_constant_override("separation", 6)
	header.add_child(_filter_bar)
	header.move_child(_filter_bar, 1)
	var group = ButtonGroup.new()
	for f in CRAFT_FILTERS:
		var b = Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = f[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 26)
		b.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
		b.button_pressed = f[0] == craft_filter
		var key: String = f[0]
		b.pressed.connect(func():
			craft_filter = key
			_populate_drawer(current_tab)
		)
		_filter_bar.add_child(b)
		_filter_buttons[key] = b
	_only_available_btn = CheckBox.new()
	_only_available_btn.text = "只看能制作的"
	_only_available_btn.focus_mode = Control.FOCUS_NONE
	_only_available_btn.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
	_only_available_btn.toggled.connect(func(on):
		craft_only_available = on
		_populate_drawer(current_tab)
	)
	_filter_bar.add_child(_only_available_btn)

	_drawer_footer = Label.new()
	_drawer_footer.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
	_drawer_footer.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_MUTED)
	$Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox.add_child(_drawer_footer)

func _recipe_category(recipe: Dictionary) -> String:
	var res_key = str(recipe.get("result_item", recipe.get("result_tool", recipe.get("key", ""))))
	var cat = str(DataDB.get_item(res_key).get("category", ""))
	return cat if cat in ["工具", "容器", "材料"] else "other"

# 材料清单："名称 有/需"，任选材料取持有最多的一种
func _describe_cost(req_items: Array) -> Dictionary:
	var parts: Array = []
	var ok := true
	for req in req_items:
		var r_key = req.get("key")
		var r_qty = int(req.get("quantity", 1))
		var owned = 0
		var mat_name = ""
		if r_key is Array:
			for alt in r_key:
				owned = maxi(owned, GameState.inventory.get_count(alt))
				if mat_name == "": mat_name = DataDB.get_item(alt).get("name", alt)
		else:
			owned = GameState.inventory.get_count(r_key)
			mat_name = DataDB.get_item(r_key).get("name", r_key)
		parts.append("%s %d/%d" % [mat_name, owned, r_qty])
		if owned < r_qty:
			ok = false
	return {"text": " · ".join(parts), "ok": ok}

func _add_craft_subitems() -> void:
	var entries: Array = []
	var later_eras := 0
	for recipe in DataDB.crafting.values():
		var r_era = int(recipe.get("era", 0))
		if r_era > GameState.current_era:
			later_eras += 1
			continue
		var cat = _recipe_category(recipe)
		if craft_filter != "all" and cat != craft_filter:
			continue
		var reason = ""
		for req_t in recipe.get("required_techs", []):
			if not GameState.researched_techs.has(str(req_t)):
				reason = "需要研发%s" % DataDB.techs.get(str(req_t), {}).get("name", str(req_t))
				break
		var cost = _describe_cost(recipe.get("required_items", []))
		if reason == "" and not cost["ok"]:
			reason = "材料不足"
		if craft_only_available and reason != "":
			continue
		entries.append({"recipe": recipe, "reason": reason, "cost": cost["text"]})
	# 能制作的在前；同类按时代、原顺序
	entries.sort_custom(func(a, b):
		var ra = a["reason"] == ""
		var rb = b["reason"] == ""
		if ra != rb: return ra
		return int(a["recipe"].get("era", 0)) < int(b["recipe"].get("era", 0))
	)
	for e in entries:
		var recipe: Dictionary = e["recipe"]
		var recipe_key = str(recipe.get("key", ""))
		var can_craft: bool = e["reason"] == ""
		# 状态标签保持简短；缺科技时第二行写明要研发什么
		var tech_locked = str(e["reason"]).begins_with("需要研发")
		var card = _create_action_card(
			str(recipe.get("name", recipe_key)),
			e["reason"] if tech_locked else e["cost"],
			get_item_icon(recipe_key),
			"可制作" if can_craft else ("缺科技" if tech_locked else "缺材料"),
			can_craft
		)
		if tech_locked:
			card.tooltip_text += "\n材料：%s" % e["cost"]
		drawer_card_by_key[recipe_key] = card
		if can_craft:
			card.pressed.connect(func():
				if GameState.craft_tool(recipe_key):
					_populate_drawer(CategoryTab.CRAFT)
			)
	if entries.is_empty():
		var empty_label = Label.new()
		empty_label.text = "当前筛选下没有配方" if not craft_only_available else "现在还没有能制作的配方"
		empty_label.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		_add_drawer_extra(empty_label)
	_drawer_footer.text = "还有 %d 项配方在后续时代解锁" % later_eras if later_eras > 0 else ""

# --- 4. 建造分类细项 ---
func _add_build_subitems() -> void:
	var buildings = DataDB.buildings.values()
	for b in buildings:
		var b_key = b.get("key", "")
		if not GameState.sim.IMPLEMENTED_STRUCTURES.has(b_key):
			continue # 尚未实现运行逻辑的建筑暂不展示
		var b_name = b.get("name", b_key)
		var req_items = b.get("required_items", [])
		var req_techs = b.get("required_techs", [])
		var b_era = int(b.get("era", 0))
		
		var can_build = true
		var missing_reason = ""
		
		if b_era > GameState.current_era:
			can_build = false
			missing_reason = "时代未达"
			
		for req_t in req_techs:
			if not GameState.researched_techs.has(str(req_t)):
				can_build = false
				if missing_reason == "": missing_reason = "缺少科技"
				break
				
		var cost_desc_list = []
		for req in req_items:
			var r_key = req.get("key")
			var r_qty = int(req.get("quantity", 1))
			var owned = 0
			var mat_name = ""
			if r_key is Array:
				var found_max = 0
				for alt in r_key:
					var cnt = GameState.inventory.get_count(alt)
					if cnt > found_max:
						found_max = cnt
					var it = DataDB.get_item(alt)
					if mat_name == "": mat_name = it.get("name", alt)
				owned = found_max
			else:
				owned = GameState.inventory.get_count(r_key)
				var it = DataDB.get_item(r_key)
				mat_name = it.get("name", r_key)
				
			cost_desc_list.append("%s: %d/%d" % [mat_name, owned, r_qty])
			if owned < r_qty:
				can_build = false
				if missing_reason == "": missing_reason = "缺少材料"
				
		var cost_str = " · ".join(cost_desc_list)
		var status_text = "可建造" if can_build else missing_reason
		var card = _create_action_card(
			b_name,
			cost_str,
			get_item_icon(b_key),
			status_text,
			can_build
		)
		drawer_card_by_key[b_key] = card
		if can_build:
			card.pressed.connect(func():
				_on_build_structure_pressed(b_key)
				_close_drawer()
			)

# --- 5. 行囊分类细项 ---
func _add_inventory_subitems() -> void:
	if GameState.inventory.items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "行囊是空的，去地图上采集资源吧"
		empty_label.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		_add_drawer_extra(empty_label)
		return
		
	for k in GameState.inventory.items.keys():
		var count = GameState.inventory.items[k]
		if count <= 0:
			continue
		var item_data = DataDB.get_item(k)
		var iname = item_data.get("name", k)
		var desc = item_data.get("description", "化学物资标本")
		var icon = get_item_icon(k)
		
		var card = _create_action_card(
			iname,
			"储备数量: %d\n%s" % [count, desc],
			icon,
			"x%d" % count,
			true
		)

# 界面样式初始化 (地质测绘图 × 实验手稿：纸面 HUD + 暖墨弹窗)
func _apply_scheme3_styling() -> void:
	# 1. 顶栏悬浮胶囊 Ribbon (Floating Capsule Ribbon)
	var top_box = ThemeStyler.create_pill_box(22, ThemeStyler.PAPER_BG, ThemeStyler.PAPER_BORDER)
	top_box.shadow_color = ThemeStyler.adapt(Color(0.25, 0.20, 0.12, 0.18))
	top_box.content_margin_left = 20
	top_box.content_margin_top = 6
	top_box.content_margin_right = 20
	top_box.content_margin_bottom = 6
	$Margin/MainVBox/TopBarPanel.add_theme_stylebox_override("panel", top_box)
	
	if logo_icon:
		var logo_tex: Texture2D = ItemIconManager.load_texture("res://assets/icons/game_logo.png")
		if logo_tex:
			logo_icon.texture = logo_tex
			logo_icon.custom_minimum_size = Vector2(34, 34)
	
	if logo_title:
		logo_title.text = "元素纪元"
		logo_title.add_theme_color_override("font_color", ThemeStyler.PAPER_INK)
		logo_title.add_theme_font_size_override("font_size", 20)
	if logo_sub:
		logo_sub.visible = false
		logo_sub.text = ""
	if era_badge_btn:
		var era_col = ThemeStyler.get_era_accent(GameState.current_era)
		var pill_normal = StyleBoxFlat.new()
		pill_normal.bg_color = Color(era_col.r, era_col.g, era_col.b, 0.14)
		pill_normal.border_color = Color(era_col.r, era_col.g, era_col.b, 0.75)
		pill_normal.border_width_left = 1
		pill_normal.border_width_top = 1
		pill_normal.border_width_right = 1
		pill_normal.border_width_bottom = 1
		pill_normal.corner_radius_top_left = 15
		pill_normal.corner_radius_top_right = 15
		pill_normal.corner_radius_bottom_left = 15
		pill_normal.corner_radius_bottom_right = 15
		pill_normal.content_margin_left = 14
		pill_normal.content_margin_right = 14
		pill_normal.content_margin_top = 4
		pill_normal.content_margin_bottom = 4
		
		var pill_hover = pill_normal.duplicate()
		pill_hover.bg_color = Color(era_col.r, era_col.g, era_col.b, 0.26)
		pill_hover.border_color = era_col
		
		era_badge_btn.add_theme_stylebox_override("normal", pill_normal)
		era_badge_btn.add_theme_stylebox_override("hover", pill_hover)
		era_badge_btn.add_theme_stylebox_override("pressed", pill_hover)
		era_badge_btn.add_theme_color_override("font_color", ThemeStyler.deepen(era_col, 0.35))
		era_badge_btn.add_theme_color_override("font_hover_color", ThemeStyler.deepen(era_col, 0.5))
		era_badge_btn.add_theme_font_size_override("font_size", 14)
		era_badge_btn.custom_minimum_size = Vector2(0, 30)
	
	_style_status_chips()

	# 右侧资源数值字体放大
	for val_lbl in [val_stone, val_wood, val_flint, val_ore, val_fuel]:
		if val_lbl:
			val_lbl.add_theme_font_size_override("font_size", 16)
			val_lbl.add_theme_color_override("font_color", ThemeStyler.PAPER_INK)
			var mono = ThemeStyler.get_font_mono()
			if mono:
				val_lbl.add_theme_font_override("font", mono)
			
	# 右端菜单按钮：纯粹无框扁平图标 (Ghost Icon Button)，鼠标悬停微光轻抚
	if btn_menu:
		var empty_box = StyleBoxEmpty.new()
		btn_menu.add_theme_stylebox_override("normal", empty_box)
		btn_menu.add_theme_stylebox_override("focus", empty_box)
		btn_menu.add_theme_stylebox_override("disabled", empty_box)
		
		var menu_hover = StyleBoxFlat.new()
		menu_hover.bg_color = ThemeStyler.adapt(Color(0.92, 0.89, 0.84, 0.08))
		menu_hover.corner_radius_top_left = 6
		menu_hover.corner_radius_top_right = 6
		menu_hover.corner_radius_bottom_left = 6
		menu_hover.corner_radius_bottom_right = 6
		btn_menu.add_theme_stylebox_override("hover", menu_hover)
		
		var menu_pressed = StyleBoxFlat.new()
		menu_pressed.bg_color = ThemeStyler.adapt(Color(0.92, 0.89, 0.84, 0.16))
		menu_pressed.corner_radius_top_left = 6
		menu_pressed.corner_radius_top_right = 6
		menu_pressed.corner_radius_bottom_left = 6
		menu_pressed.corner_radius_bottom_right = 6
		btn_menu.add_theme_stylebox_override("pressed", menu_pressed)
	
	# 2. 底栏悬浮交互坞 (Floating Action Dock - 纯白亮瓷发光胶囊岛)
	var dock_box = StyleBoxFlat.new()
	dock_box.bg_color = ThemeStyler.PAPER_BG # 米白纸面悬浮卡片
	dock_box.border_color = ThemeStyler.PAPER_BORDER
	dock_box.border_width_left = 1
	dock_box.border_width_top = 1
	dock_box.border_width_right = 1
	dock_box.border_width_bottom = 1
	dock_box.corner_radius_top_left = 24
	dock_box.corner_radius_top_right = 24
	dock_box.corner_radius_bottom_left = 24
	dock_box.corner_radius_bottom_right = 24
	dock_box.shadow_color = ThemeStyler.adapt(Color(0.25, 0.20, 0.12, 0.22))
	dock_box.shadow_size = 14
	dock_box.shadow_offset = Vector2(0, 4)
	dock_box.content_margin_left = 16
	dock_box.content_margin_right = 16
	dock_box.content_margin_top = 4
	dock_box.content_margin_bottom = 4
	$Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel.add_theme_stylebox_override("panel", dock_box)
	
	# 底栏按钮悬停与激活态 (高对比冷灰极简深色文字与图标)
	var dock_accent = ThemeStyler.get_era_accent(GameState.current_era)
	var tab_buttons = [btn_tab_lab, btn_tab_tech, btn_tab_craft, btn_tab_build, btn_tab_inventory]
	for btn in tab_buttons:
		if btn:
			var btn_norm = StyleBoxFlat.new()
			btn_norm.bg_color = ThemeStyler.adapt(Color(0.92, 0.89, 0.84, 0.00))
			btn_norm.corner_radius_top_left = 12
			btn_norm.corner_radius_top_right = 12
			btn_norm.corner_radius_bottom_left = 12
			btn_norm.corner_radius_bottom_right = 12
			btn_norm.content_margin_left = 10
			btn_norm.content_margin_right = 10
			btn_norm.content_margin_top = 4
			btn_norm.content_margin_bottom = 4

			var btn_hov = StyleBoxFlat.new()
			btn_hov.bg_color = Color(dock_accent.r, dock_accent.g, dock_accent.b, 0.14)
			btn_hov.border_color = Color(dock_accent.r, dock_accent.g, dock_accent.b, 0.8)
			btn_hov.border_width_left = 1
			btn_hov.border_width_top = 1
			btn_hov.border_width_right = 1
			btn_hov.border_width_bottom = 1
			btn_hov.corner_radius_top_left = 12
			btn_hov.corner_radius_top_right = 12
			btn_hov.corner_radius_bottom_left = 12
			btn_hov.corner_radius_bottom_right = 12
			btn_hov.content_margin_left = 10
			btn_hov.content_margin_right = 10
			btn_hov.content_margin_top = 4
			btn_hov.content_margin_bottom = 4

			var btn_press = StyleBoxFlat.new()
			btn_press.bg_color = Color(dock_accent.r, dock_accent.g, dock_accent.b, 0.28)
			btn_press.corner_radius_top_left = 12
			btn_press.corner_radius_top_right = 12
			btn_press.corner_radius_bottom_left = 12
			btn_press.corner_radius_bottom_right = 12
			btn_press.content_margin_left = 10
			btn_press.content_margin_right = 10
			btn_press.content_margin_top = 4
			btn_press.content_margin_bottom = 4

			btn.add_theme_stylebox_override("normal", btn_norm)
			btn.add_theme_stylebox_override("hover", btn_hov)
			btn.add_theme_stylebox_override("pressed", btn_press)
			btn.add_theme_stylebox_override("focus", btn_hov)
			btn.add_theme_font_size_override("font_size", ThemeStyler.FONT_BODY)
			btn.add_theme_color_override("font_color", ThemeStyler.PAPER_INK)
			btn.add_theme_color_override("font_hover_color", ThemeStyler.deepen(dock_accent, 0.45))
			btn.add_theme_color_override("font_pressed_color", ThemeStyler.deepen(dock_accent, 0.45))
			btn.add_theme_color_override("icon_normal_color", ThemeStyler.PAPER_INK)
			btn.add_theme_color_override("icon_hover_color", ThemeStyler.deepen(dock_accent, 0.3))
	
	# 队列数字胶囊徽标 (Queue Badge)
	if queue_badge:
		var q_badge_box = StyleBoxFlat.new()
		q_badge_box.bg_color = Color(ThemeStyler.COLOR_ACCENT.r, ThemeStyler.COLOR_ACCENT.g, ThemeStyler.COLOR_ACCENT.b, 0.22)
		q_badge_box.border_color = ThemeStyler.COLOR_ACCENT
		q_badge_box.border_width_left = 1
		q_badge_box.border_width_top = 1
		q_badge_box.border_width_right = 1
		q_badge_box.border_width_bottom = 1
		q_badge_box.corner_radius_top_left = 8
		q_badge_box.corner_radius_top_right = 8
		q_badge_box.corner_radius_bottom_left = 8
		q_badge_box.corner_radius_bottom_right = 8
		q_badge_box.content_margin_left = 6
		q_badge_box.content_margin_right = 6
		q_badge_box.content_margin_top = 1
		q_badge_box.content_margin_bottom = 1
		queue_badge.add_theme_stylebox_override("normal", q_badge_box)
		queue_badge.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
	
	# 3. 悬浮作业管线卡片 (Task Dock)
	var task_box = ThemeStyler.create_card_box(10, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER)
	task_box.content_margin_left = 12
	task_box.content_margin_top = 10
	task_box.content_margin_right = 12
	task_box.content_margin_bottom = 10
	$Margin/MainVBox/BodyHBox/RightBox/TaskDock.add_theme_stylebox_override("panel", task_box)
	
	# 作业进度条细线科技化
	if task_progress_bar:
		var pb_bg = StyleBoxFlat.new()
		pb_bg.bg_color = ThemeStyler.COLOR_BG_SOLID
		pb_bg.border_color = ThemeStyler.COLOR_BORDER
		pb_bg.border_width_left = 1
		pb_bg.border_width_top = 1
		pb_bg.border_width_right = 1
		pb_bg.border_width_bottom = 1
		pb_bg.corner_radius_top_left = 3
		pb_bg.corner_radius_top_right = 3
		pb_bg.corner_radius_bottom_left = 3
		pb_bg.corner_radius_bottom_right = 3
		var pb_fill = StyleBoxFlat.new()
		pb_fill.bg_color = ThemeStyler.COLOR_ACCENT
		pb_fill.corner_radius_top_left = 3
		pb_fill.corner_radius_top_right = 3
		pb_fill.corner_radius_bottom_left = 3
		pb_fill.corner_radius_bottom_right = 3
		task_progress_bar.add_theme_stylebox_override("background", pb_bg)
		task_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	
	# 4. 底部动作抽屉面板 (Action Drawer)
	var drawer_box = ThemeStyler.create_card_box(14, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER)
	drawer_box.content_margin_left = 16
	drawer_box.content_margin_top = 12
	drawer_box.content_margin_right = 16
	drawer_box.content_margin_bottom = 14
	action_drawer.add_theme_stylebox_override("panel", drawer_box)
	

# 通用制作/操作卡片创建函数
# 抽屉卡片对象池：卡片节点只在首次需要时创建，之后每次刷新只改文字、图标与状态，
# 不再整组 queue_free + 重建 (制作抽屉 54 张卡片原需约 25ms)
# 本次刷新中配方 / 建筑 key -> 卡片 (教程高亮具体卡片用)
var drawer_card_by_key: Dictionary = {}
var _card_pool: Array[Button] = []
var _card_used: int = 0
var _drawer_extras: Array[Node] = []
var _card_styles: Dictionary = {}

func _card_style(kind: String) -> StyleBoxFlat:
	if not _card_styles.has(kind):
		var box: StyleBoxFlat
		match kind:
			"hover": box = ThemeStyler.create_card_box(8, ThemeStyler.COLOR_CARD_HOVER, ThemeStyler.COLOR_BORDER_FOCUS)
			"pressed": box = ThemeStyler.create_card_box(8, ThemeStyler.COLOR_BG_SOLID, ThemeStyler.COLOR_ACCENT)
			_: box = ThemeStyler.create_card_box(8, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER)
		box.content_margin_left = 12
		box.content_margin_top = 10
		box.content_margin_right = 12
		box.content_margin_bottom = 10
		_card_styles[kind] = box
	return _card_styles[kind]

const CARD_SIZE := Vector2(232, 64)

func _new_pool_card() -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.clip_contents = true
	btn.add_theme_stylebox_override("normal", _card_style("normal"))
	btn.add_theme_stylebox_override("hover", _card_style("hover"))
	btn.add_theme_stylebox_override("pressed", _card_style("pressed"))
	btn.add_theme_stylebox_override("focus", _card_style("hover"))
	btn.add_theme_stylebox_override("disabled", _card_style("normal"))
	
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	btn.add_child(margin)
	
	# 紧凑卡片：左侧 36px 图标；右侧第一行名称 + 状态，第二行材料 (过长时截断，完整内容在悬停提示中)
	var top_hbox = HBoxContainer.new()
	top_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_theme_constant_override("separation", 8)
	margin.add_child(top_hbox)
	
	var icon_rect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_hbox.add_child(icon_rect)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	top_hbox.add_child(vbox)
	
	var title_row = HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)
	
	var lbl_title = Label.new()
	lbl_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_title.clip_text = true
	lbl_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_title.add_theme_font_size_override("font_size", ThemeStyler.FONT_BODY)
	lbl_title.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
	title_row.add_child(lbl_title)
	
	var lbl_badge = Label.new()
	lbl_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_badge.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
	title_row.add_child(lbl_badge)
	
	var lbl_sub = Label.new()
	lbl_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_sub.clip_text = true
	lbl_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_sub.add_theme_font_size_override("font_size", ThemeStyler.FONT_CAPTION)
	lbl_sub.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	vbox.add_child(lbl_sub)
	
	btn.set_meta("icon", icon_rect)
	btn.set_meta("title", lbl_title)
	btn.set_meta("badge", lbl_badge)
	btn.set_meta("sub", lbl_sub)
	drawer_grid.add_child(btn)
	return btn

# 取一张池中卡片并填充内容 (卡片已挂在 drawer_grid 下)；调用方只需 card.pressed.connect(...)
func _create_action_card(title: String, subtitle: String, icon_tex: Texture2D, badge_text: String, is_enabled: bool) -> Button:
	var btn: Button
	if _card_used < _card_pool.size():
		btn = _card_pool[_card_used]
		# 上一次刷新挂上的点击回调全部断开
		for c in btn.pressed.get_connections():
			btn.pressed.disconnect(c["callable"])
	else:
		btn = _new_pool_card()
		_card_pool.append(btn)
	_card_used += 1
	
	btn.visible = true
	btn.tooltip_text = "%s\n%s" % [title, subtitle]
	btn.disabled = not is_enabled
	btn.modulate = Color(1.0, 1.0, 1.0, 1.0 if is_enabled else 0.45)
	(btn.get_meta("icon") as TextureRect).texture = icon_tex
	(btn.get_meta("title") as Label).text = title
	var lbl_badge: Label = btn.get_meta("badge")
	lbl_badge.text = badge_text
	lbl_badge.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT if is_enabled else ThemeStyler.COLOR_DANGER)
	(btn.get_meta("sub") as Label).text = subtitle
	# 按本次调用顺序排列
	drawer_grid.move_child(btn, _card_used - 1)
	return btn

# 抽屉中的非卡片节点 (如空背包提示) 记录下来，下次刷新时释放
func _add_drawer_extra(node: Node) -> void:
	_drawer_extras.append(node)
	drawer_grid.add_child(node)

# 鼠标是否在 HUD 的不透明面板上 (world 据此决定滚轮是否缩放地图)
func is_pointer_over_panel(screen_pos: Vector2) -> bool:
	var panels: Array = [$Margin/MainVBox/TopBarPanel, action_drawer, $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel,
		$Margin/MainVBox/BodyHBox/RightBox/TaskDock, tutorial_dock, placement_bar]
	for p in panels:
		if p != null and is_instance_valid(p) and p.is_visible_in_tree() and p.get_global_rect().has_point(screen_pos):
			return true
	return false

func _is_world_placing() -> bool:
	var w = get_parent()
	return w != null and "is_placing_structure" in w and w.is_placing_structure

func _unhandled_input(event: InputEvent) -> void:
	# 输入层级 (由上到下，每次只处理一层)：
	#   建造选址 (world 处理) > 弹窗栈最上层 (弹窗自身 _input 处理) > 抽屉 > 暂停菜单
	# 有弹窗打开时功能热键一律不响应，避免在弹窗上方再叠一个弹窗
	if _is_world_placing():
		return
	var right_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	var key = event is InputEventKey and event.pressed and not event.echo
	if not right_click and not key:
		return
	if right_click or (key and event.keycode == KEY_ESCAPE):
		if ModalStack.close_top() or _close_side_panels():
			get_viewport().set_input_as_handled()
		elif key:
			pause_menu.open()
			get_viewport().set_input_as_handled()
		return
	if not ModalStack.is_empty():
		return
	var handled = true
	match event.keycode:
		KEY_L: _toggle_category(CategoryTab.LAB)
		KEY_K: _toggle_category(CategoryTab.TECH)
		KEY_T: _toggle_category(CategoryTab.CRAFT)
		KEY_C: _toggle_category(CategoryTab.BUILD)
		KEY_B: _toggle_category(CategoryTab.INVENTORY)
		KEY_P: periodic_modal.open()
		KEY_F5: save_load_modal.open(0, get_parent())
		KEY_F9: save_load_modal.open(1, get_parent())
		KEY_O: settings_modal.open()
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()

# 关闭底部抽屉 (非模态的侧边面板)；有面板被关闭时返回 true
func _close_side_panels() -> bool:
	var closed = false
	if action_drawer.visible:
		_close_drawer()
		closed = true
	return closed

func _has_any_modal_open() -> bool:
	return not ModalStack.is_empty()

func _setup_save_dot() -> void:
	if save_dot:
		save_dot.custom_minimum_size = Vector2(8, 8)
		save_dot.mouse_filter = Control.MOUSE_FILTER_STOP
		save_dot.tooltip_text = "自动保存正常"
		_set_save_dot_status(true, "自动保存正常")
		
		# 监听保存信号与自定义绘制
		if not save_dot.is_connected("draw", _on_save_dot_draw):
			save_dot.draw.connect(_on_save_dot_draw)

var _save_dot_color: Color = Color(0.55, 0.58, 0.62, 1.0) # 默认灰

func _on_save_dot_draw() -> void:
	if save_dot:
		save_dot.draw_circle(Vector2(4, 4), 4.0, _save_dot_color)

func _set_save_dot_status(is_success: bool, status_tip: String) -> void:
	if is_success:
		_save_dot_color = Color(0.55, 0.58, 0.62, 1.0) # 成功用灰
	else:
		_save_dot_color = Color(0.92, 0.28, 0.28, 1.0) # 失败用红
	if save_dot:
		save_dot.tooltip_text = status_tip
		save_dot.queue_redraw()

func _update_task_queue_ui() -> void:
	var q_size = GameState.task_queue.size()
	var has_tasks = not GameState.active_task.is_empty() or q_size > 0
	
	# 更新底栏「行囊」旁的数字徽标
	if queue_badge:
		queue_badge.text = str(q_size + (1 if not GameState.active_task.is_empty() else 0))
		queue_badge.visible = has_tasks
		
	# 队列为空时不画右边面板；有任务时才从右侧展开 (宽 280)
	if right_box:
		right_box.visible = has_tasks
		
	if not has_tasks:
		return
		
	task_queue_count.text = "%d 待办" % q_size
	
	if GameState.active_task.is_empty():
		task_active_title.text = "空闲"
		task_progress_box.visible = false
		task_btn_cancel_active.visible = false
	else:
		var t = GameState.active_task
		var rep = int(t.get("repeat_count", 1))
		var cur_c = int(t.get("current_cycle", 1))
		var title_base = t.get("title", "作业中")
		if rep == -1:
			task_active_title.text = "%s（第 %d 次）" % [title_base, cur_c]
		elif rep > 1:
			task_active_title.text = "%s（%d/%d）" % [title_base, cur_c, rep]
		else:
			task_active_title.text = "%s" % title_base
		task_progress_box.visible = true
		task_btn_cancel_active.visible = true
	
	# 队列滚动区与分隔线：无额外待办时隐藏，减少屏幕占用
	if task_hsep:
		task_hsep.visible = (q_size > 0)
	if task_queue_scroll:
		task_queue_scroll.visible = (q_size > 0)
		if q_size > 0:
			# 限制最大高度为 84px (约 3 个待办条目)，内部滚动，绝不撑满全屏
			task_queue_scroll.custom_minimum_size = Vector2(0, min(q_size * 28, 84))
			
	for child in task_queue_list.get_children():
		child.queue_free()
		
	for i in range(q_size):
		var q_task = GameState.task_queue[i]
		var task_id = q_task.get("id")
		var rep = int(q_task.get("repeat_count", 1))
		var chip = Button.new()
		if rep == -1:
			chip.text = "%d. %s  ✕" % [i + 1, q_task.get("title", "作业")]
		elif rep > 1:
			chip.text = "%d. %s  ✕" % [i + 1, q_task.get("title", "作业")]
		else:
			chip.text = "%d. %s · %.1f 秒  ✕" % [i + 1, q_task.get("title", "作业"), q_task.get("time_required", 1.0)]
		chip.custom_minimum_size = Vector2(0, 24)
		chip.add_theme_font_size_override("font_size", 12)
		chip.tooltip_text = "点击取消此作业"
		chip.pressed.connect(func(): GameState.cancel_task(task_id))
		task_queue_list.add_child(chip)

func _on_task_progress_updated(_task: Dictionary, percent: float, remaining_time: float) -> void:
	if not GameState.active_task.is_empty():
		task_progress_bar.value = percent
		task_active_time.text = "%.1fs" % remaining_time

func _update_inventory_ui() -> void:
	# 顶栏只保留五个核心资源: 石头、木头、燧石、矿、燃料
	val_stone.text = str(GameState.inventory.get_count("stone"))
	chip_stone.tooltip_text = "碎石 %s\n基础建材，用于制作石镐、建造窑炉" % val_stone.text
	
	var wood_cnt = GameState.inventory.get_count("wood")
	var stick_cnt = GameState.inventory.get_count("stick")
	val_wood.text = str(wood_cnt + stick_cnt)
	chip_wood.tooltip_text = "木材 %s（原木 %d · 枯枝 %d）\n用于制作工具柄和生火" % [val_wood.text, wood_cnt, stick_cnt]
	
	val_flint.text = str(GameState.inventory.get_count("flint"))
	chip_flint.tooltip_text = "燧石 %s\n坚硬锋利，用于制作燧石斧和火种" % val_flint.text
	
	# 矿石统计 (孔雀石 + 赤铁矿 + 黄铁矿 + 闪锌矿 + 铝土矿 + 沥青铀矿)
	var total_ores = (
		GameState.inventory.get_count("malachite") +
		GameState.inventory.get_count("hematite") +
		GameState.inventory.get_count("pyrite") +
		GameState.inventory.get_count("sphalerite") +
		GameState.inventory.get_count("bauxite") +
		GameState.inventory.get_count("pitchblende")
	)
	val_ore.text = str(total_ores)
	chip_ore.tooltip_text = "矿石 %s\n孔雀石（铜矿）、赤铁矿（铁矿）等金属矿物合计" % val_ore.text
	
	# 燃料统计 (木炭 + 煤炭 + 焦炭)
	var total_fuels = (
		GameState.inventory.get_count("charcoal") +
		GameState.inventory.get_count("coal") +
		GameState.inventory.get_count("coke")
	)
	val_fuel.text = str(total_fuels)
	chip_fuel.tooltip_text = "燃料 %s\n木炭、煤炭、焦炭合计，用于熔炉冶炼" % val_fuel.text
	
	# 悬停在行囊上显示全量资源
	_update_inventory_tooltip()
	
	# 如果当前抽屉打开，刷新抽屉内容 (同一帧内多次物品变化合并为一次重建)
	if action_drawer.visible and not _drawer_refresh_pending:
		_drawer_refresh_pending = true
		_refresh_drawer_deferred.call_deferred()

var _drawer_refresh_pending: bool = false

func _refresh_drawer_deferred() -> void:
	_drawer_refresh_pending = false
	if action_drawer.visible and current_tab != CategoryTab.NONE:
		_populate_drawer(current_tab)

func _update_inventory_tooltip() -> void:
	if not btn_tab_inventory:
		return
	var items = GameState.inventory.items
	var lines: Array[String] = ["【行囊物资储备清单】[B]"]
	if items.is_empty():
		lines.append("当前行囊空空如也")
	else:
		var count_shown = 0
		for k in items.keys():
			var cnt = items[k]
			if cnt > 0:
				var iname = DataDB.get_item(k).get("name", k)
				lines.append("• %s: %d" % [iname, cnt])
				count_shown += 1
				if count_shown >= 25:
					lines.append("... (更多按 [B] 打开网格背包查看)")
					break
	btn_tab_inventory.tooltip_text = "\n".join(lines)

func _update_era_label() -> void:
	if not era_badge_btn:
		return
	var terr_radius = GameState.get_current_territory_radius()
	var terr_count = (3 * terr_radius * (terr_radius + 1) + 1)
	var disc_count = GameState.discovered_elements.size()
	var cur_era = GameState.current_era
	var era_def = DataDB.get_era(cur_era)
	var era_name = str(era_def.get("name", GameState.ERA_NAMES[cur_era])).split(" (")[0]
	var milestones = era_def.get("milestones", [])
	var total_ms = milestones.size()
	var done_ms = 0
	for m in milestones:
		if GameState.completed_milestones.has(str(m.get("key", ""))):
			done_ms += 1
	
	if total_ms > 0:
		era_badge_btn.text = "%s  %d/%d" % [era_name, done_ms, total_ms]
	else:
		era_badge_btn.text = era_name
		
	var era_icon_path = "res://assets/icons/era_%s.svg" % era_def.get("key", "stone")
	var era_tex: Texture2D = ItemIconManager.load_texture(era_icon_path)
	if not era_tex:
		era_tex = ItemIconManager.load_texture("res://assets/icons/era.svg")
	if era_tex:
		era_badge_btn.icon = era_tex
		era_badge_btn.expand_icon = true
	# expand_icon 的图标不计入按钮最小宽度，按钮只按文字宽度排版会把图标挤没；
	# 这里按「文字 + 图标 + 间距 + 左右内边距」显式给出宽度
	var font = era_badge_btn.get_theme_font("font")
	var fsize = era_badge_btn.get_theme_font_size("font_size")
	var text_w = font.get_string_size(era_badge_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x if font else 80.0
	var icon_w = 20.0 if era_tex else 0.0
	era_badge_btn.custom_minimum_size = Vector2(ceil(text_w + icon_w + 6.0 + 28.0), 30)
		
	var tooltip_lines: Array[String] = [
		"%s" % era_name,
		"领地 %d 格 · 已发现元素 %d/118" % [terr_count, disc_count],
		""
	]
	if total_ms > 0:
		tooltip_lines.append("进入下一时代需要：")
		for m in milestones:
			var m_k = str(m.get("key", ""))
			var m_desc = str(m.get("description", m_k))
			var is_done = GameState.completed_milestones.has(m_k)
			tooltip_lines.append("  %s %s" % ["✓" if is_done else "○", m_desc])
	else:
		tooltip_lines.append("已是最后一个时代")
	tooltip_lines.append("\n点击查看详情")
	era_badge_btn.tooltip_text = "\n".join(tooltip_lines)

func update_current_biome(_biome: int) -> void:
	pass

func _on_era_advanced(_old: int, _new: int, _name: String) -> void:
	_apply_scheme3_styling() # 时代强调色随纪元切换
	_update_era_label()

func _on_milestone_completed(_key: String) -> void:
	_update_era_label()
	if era_badge_btn:
		era_badge_btn.pivot_offset = era_badge_btn.size * 0.5
		var tw = create_tween()
		tw.tween_property(era_badge_btn, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(era_badge_btn, "scale", Vector2.ONE, 0.2)
	if era_modal and era_modal.visible:
		era_modal.show_current_era_status()

func _on_item_changed(_key: String, _count: int) -> void:
	_update_inventory_ui()

func _on_element_discovered(num: int, key: String) -> void:
	if element_discovery_modal:
		element_discovery_modal.show_discovery(num, key)

var toast_container: VBoxContainer = null

func _on_notification_posted(msg: String, col: Color) -> void:
	# 检查是否为存档成功或失败通知
	if msg.contains("存档") or msg.contains("保存"):
		var is_fail = msg.contains("失败") or col == Color.RED
		_set_save_dot_status(not is_fail, msg)
	else:
		if save_dot:
			save_dot.tooltip_text = msg
	show_toast(msg, col)

func show_toast(msg: String, col: Color = Color.WHITE) -> void:
	if not toast_container:
		var toast_wrapper = Control.new()
		toast_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toast_wrapper.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		toast_wrapper.offset_top = 70
		toast_wrapper.offset_bottom = 280
		add_child(toast_wrapper)
		
		var center = CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		toast_wrapper.add_child(center)
		
		toast_container = VBoxContainer.new()
		toast_container.custom_minimum_size = Vector2(460, 0)
		toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toast_container.alignment = BoxContainer.ALIGNMENT_CENTER
		toast_container.add_theme_constant_override("separation", 6)
		center.add_child(toast_container)

	# 最多同时展示 4 条 toast，多余的平滑移除最老的一条
	if toast_container.get_child_count() >= 4:
		var oldest = toast_container.get_child(0)
		oldest.queue_free()

	var toast_panel = PanelContainer.new()
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = ThemeStyler.COLOR_BG
	sbox.border_color = col
	sbox.border_width_left = 3
	sbox.border_width_top = 1
	sbox.border_width_right = 1
	sbox.border_width_bottom = 1
	sbox.corner_radius_top_left = 6
	sbox.corner_radius_top_right = 6
	sbox.corner_radius_bottom_left = 6
	sbox.corner_radius_bottom_right = 6
	sbox.content_margin_left = 14
	sbox.content_margin_top = 6
	sbox.content_margin_right = 16
	sbox.content_margin_bottom = 6
	sbox.shadow_color = ThemeStyler.adapt(Color(0.25, 0.20, 0.12, 0.22))
	sbox.shadow_size = 8
	toast_panel.add_theme_stylebox_override("panel", sbox)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	toast_panel.add_child(hbox)

	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(6, 6)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = col
	hbox.add_child(dot)

	var lbl = Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
	hbox.add_child(lbl)

	toast_container.add_child(toast_panel)
	toast_panel.modulate.a = 0.0

	var tw = create_tween()
	tw.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.2)
	tw.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(toast_panel.queue_free)

# 点击地图上的炉体：打开炉体模式的实验台 (炉膛即容器，只能做加热类操作)
func open_furnace(hex: Vector2i) -> void:
	var bench = GameState.get_furnace_bench(hex)
	if bench == null:
		return
	_close_drawer()
	lab_modal.open_bench(bench)

func open_reactor(hex: Vector2i) -> void:
	_close_drawer()
	reactor_modal.open(hex)

func _on_build_structure_pressed(structure_key: String) -> void:
	build_structure_requested.emit(structure_key)
	if structure_key == "furnace":
		build_furnace_requested.emit()
	elif structure_key == "industrial_reactor":
		build_reactor_requested.emit()

func _on_btn_build_furnace_pressed() -> void:
	_on_build_structure_pressed("furnace")

func _on_btn_build_reactor_requested() -> void:
	_on_build_structure_pressed("industrial_reactor")
