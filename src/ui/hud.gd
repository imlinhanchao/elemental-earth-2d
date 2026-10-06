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

enum CategoryTab { NONE, LAB, TECH, CRAFT, BUILD, PRODUCTION, INVENTORY }
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
@onready var furnace_panel = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel
@onready var furnace_info = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/FurnaceInfo
@onready var btn_add_fuel = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/BtnAddFuel
@onready var btn_add_malachite = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/BtnAddMalachite
@onready var btn_add_hematite = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/BtnAddIronOre

# 底部多分类动作坞 (Bottom Categorized Action Dock)
@onready var action_drawer = $Margin/MainVBox/BottomArea/ActionDrawer
@onready var drawer_title = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Header/DrawerTitle
@onready var btn_close_drawer = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Header/BtnCloseDrawer
@onready var drawer_grid = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Scroll/DrawerGrid

@onready var btn_tab_lab = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabLab
@onready var btn_tab_tech = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabTech
@onready var btn_tab_craft = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabCraft
@onready var btn_tab_build = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabBuild
@onready var btn_tab_production = $Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel/Margin/DockHBox/BtnTabProduction
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

var element_discovery_modal: ElementDiscoveryModal = null
var current_nearby_furnace: Node2D = null

func get_item_icon(key: String) -> Texture2D:
	return ItemIconManager.get_icon(key)

func _ready() -> void:
	var sc_theme = ThemeStyler.create_scientific_theme()
	$Margin.theme = sc_theme
	periodic_modal.theme = sc_theme
	lab_modal.theme = sc_theme
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
	element_discovery_modal.open_periodic_table_requested.connect(func(): periodic_modal.open())
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
	btn_tab_production.pressed.connect(func(): _toggle_category(CategoryTab.PRODUCTION))
	btn_tab_inventory.pressed.connect(func(): _toggle_category(CategoryTab.INVENTORY))
	btn_close_drawer.pressed.connect(_close_drawer)
	
	# 悬停在行囊按钮上时动态显示全量资源详情提示
	btn_tab_inventory.mouse_entered.connect(_update_inventory_tooltip)
	
	# 存档状态点 (8px 圆点，默认灰色成功，失败红色)
	_setup_save_dot()
	
	# 熔炉快速操作
	btn_add_fuel.pressed.connect(_on_btn_add_fuel_pressed)
	btn_add_malachite.pressed.connect(_on_btn_add_malachite_pressed)
	btn_add_hematite.pressed.connect(_on_btn_add_hematite_pressed)
	
	if era_badge_btn:
		era_badge_btn.pressed.connect(_on_era_badge_pressed)
	
	furnace_panel.visible = false
	action_drawer.visible = false
	_apply_scheme3_styling()
	_update_inventory_ui()
	_update_era_label()
	_update_task_queue_ui()

func _on_era_badge_pressed() -> void:
	if era_modal:
		era_modal.show_current_era_status()

func _toggle_category(tab: CategoryTab) -> void:
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
		sbox.shadow_color = Color(0, 0, 0, 0.45)
		sbox.shadow_size = 6
		placement_bar.add_theme_stylebox_override("panel", sbox)
		
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 16)
		placement_bar.add_child(hbox)
		
		placement_label = Label.new()
		placement_label.add_theme_font_size_override("font_size", 13)
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
	
	placement_label.text = "建造选址: 点击领地空闲地块安放【%s】(右键或ESC取消)" % structure_name
	placement_bar.visible = true

func hide_placement_mode() -> void:
	if placement_bar:
		placement_bar.visible = false

func _populate_drawer(tab: CategoryTab) -> void:
	for child in drawer_grid.get_children():
		child.queue_free()
		
	match tab:
		CategoryTab.LAB:
			drawer_title.text = "【实验】微观化学反应与元素圣殿"
			_add_lab_subitems()
		CategoryTab.TECH:
			drawer_title.text = "【科技】人类文明科学与技术突破演进"
			_add_tech_subitems()
		CategoryTab.CRAFT:
			drawer_title.text = "【制作】工具与装备锻造工坊"
			_add_craft_subitems()
		CategoryTab.BUILD:
			drawer_title.text = "【建造】基础设施与工业巨构施工"
			_add_build_subitems()
		CategoryTab.PRODUCTION:
			drawer_title.text = "【生产】高炉冶炼与工业自动化调度"
			_add_production_subitems()
		CategoryTab.INVENTORY:
			drawer_title.text = "【行囊】当前全量物资与化学试剂储备"
			_add_inventory_subitems()

# --- 1. 实验分类细项 ---
func _add_lab_subitems() -> void:
	var card_lab = _create_action_card(
		"微观实验工作台",
		"调配烧瓶物料、加热干馏与导出蓝图 [L]",
		get_item_icon("lab"),
		"可用",
		true
	)
	card_lab.pressed.connect(func():
		_close_drawer()
		lab_modal.open()
	)
	drawer_grid.add_child(card_lab)
	
	var disc_count = GameState.discovered_elements.size()
	var card_pt = _create_action_card(
		"118 元素周期表",
		"探索宇宙物质本源 (已点亮 %d/118) [P]" % disc_count,
		get_item_icon("periodic_table"),
		"谱系",
		true
	)
	card_pt.pressed.connect(func():
		_close_drawer()
		periodic_modal.open()
	)
	drawer_grid.add_child(card_pt)

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
	drawer_grid.add_child(card_all)
	
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
		drawer_grid.add_child(card)

# --- 3. 制作分类细项 ---
func _add_craft_subitems() -> void:
	var recipes = DataDB.crafting.values()
	for recipe in recipes:
		var recipe_key = recipe.get("key", "")
		var recipe_name = recipe.get("name", recipe_key)
		var req_items = recipe.get("required_items", [])
		var req_techs = recipe.get("required_techs", [])
		var r_era = int(recipe.get("era", 0))
		
		var can_craft = true
		var missing_reason = ""
		
		if r_era > GameState.current_era:
			can_craft = false
			missing_reason = "时代未达"
			
		for req_t in req_techs:
			if not GameState.researched_techs.has(str(req_t)):
				can_craft = false
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
				can_craft = false
				if missing_reason == "": missing_reason = "缺少材料"
				
		var cost_str = " · ".join(cost_desc_list)
		var status_text = "可打造" if can_craft else missing_reason
		var card = _create_action_card(
			recipe_name,
			cost_str,
			get_item_icon(recipe_key),
			status_text,
			can_craft
		)
		if can_craft:
			card.pressed.connect(func():
				if GameState.craft_tool(recipe_key):
					_populate_drawer(CategoryTab.CRAFT)
			)
		drawer_grid.add_child(card)

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
				if missing_reason == "": missing_reason = "缺少建材"
				
		var cost_str = " · ".join(cost_desc_list)
		var status_text = "可施工" if can_build else missing_reason
		var card = _create_action_card(
			b_name,
			cost_str,
			get_item_icon(b_key),
			status_text,
			can_build
		)
		if can_build:
			card.pressed.connect(func():
				_on_build_structure_pressed(b_key)
				_close_drawer()
			)
		drawer_grid.add_child(card)

# --- 4. 生产分类细项 ---
func _add_production_subitems() -> void:
	# 1. 木炭投掷生火
	var charcoal_cnt = GameState.inventory.get_count("charcoal")
	var can_fuel = charcoal_cnt >= 1 and current_nearby_furnace != null
	var fuel_card = _create_action_card(
		"熔炉加料生火",
		"消耗木炭 x1 维持炉膛高温 (存量: %d)" % charcoal_cnt,
		get_item_icon("fuel_fire"),
		("可投料" if can_fuel else ("无就近熔炉" if current_nearby_furnace == null else "缺少木炭")),
		can_fuel
	)
	if can_fuel:
		fuel_card.pressed.connect(func():
			_on_btn_add_fuel_pressed()
			_populate_drawer(CategoryTab.PRODUCTION)
		)
	drawer_grid.add_child(fuel_card)
	
	# 2. 孔雀石冶炼铜
	var mala_cnt = GameState.inventory.get_count("malachite")
	var can_smelt_copper = mala_cnt >= 1 and current_nearby_furnace != null
	var copper_card = _create_action_card(
		"孔雀石冶铜",
		"投入孔雀石 x1 冶炼金属铜 (存量: %d)" % mala_cnt,
		get_item_icon("malachite"),
		("可投入" if can_smelt_copper else ("无就近熔炉" if current_nearby_furnace == null else "缺少孔雀石")),
		can_smelt_copper
	)
	if can_smelt_copper:
		copper_card.pressed.connect(func():
			_on_btn_add_malachite_pressed()
			_populate_drawer(CategoryTab.PRODUCTION)
		)
	drawer_grid.add_child(copper_card)
	
	# 3. 赤铁矿冶炼铁
	var hematite_cnt = GameState.inventory.get_count("hematite")
	var can_smelt_iron = hematite_cnt >= 1 and current_nearby_furnace != null
	var iron_card = _create_action_card(
		"赤铁矿冶铁",
		"投入赤铁矿 x1 冶炼金属铁 (存量: %d)" % hematite_cnt,
		get_item_icon("hematite"),
		("可投入" if can_smelt_iron else ("无就近熔炉" if current_nearby_furnace == null else "缺少赤铁矿")),
		can_smelt_iron
	)
	if can_smelt_iron:
		iron_card.pressed.connect(func():
			_on_btn_add_hematite_pressed()
			_populate_drawer(CategoryTab.PRODUCTION)
		)
	drawer_grid.add_child(iron_card)
	
	# 4. 工业反应塔蓝图自动化
	var bp_count = GameState.unlocked_blueprints.size()
	var bp_card = _create_action_card(
		"反应塔自动化调度",
		"已解锁 %d 项工艺流转芯片蓝图" % bp_count,
		get_item_icon("blueprint"),
		"蓝图库",
		true
	)
	drawer_grid.add_child(bp_card)

# --- 5. 行囊分类细项 ---
func _add_inventory_subitems() -> void:
	if GameState.inventory.items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "当前行囊空空如也，请前往大世界开采采集资源。"
		empty_label.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		drawer_grid.add_child(empty_label)
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
		drawer_grid.add_child(card)

# 界面样式初始化 (地质测绘图 × 实验手稿：纸面 HUD + 暖墨弹窗)
func _apply_scheme3_styling() -> void:
	# 1. 顶栏悬浮胶囊 Ribbon (Floating Capsule Ribbon)
	var top_box = ThemeStyler.create_pill_box(22, ThemeStyler.PAPER_BG, ThemeStyler.PAPER_BORDER)
	top_box.shadow_color = Color(0.25, 0.20, 0.12, 0.18)
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
		logo_title.add_theme_font_size_override("font_size", 18)
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
		era_badge_btn.add_theme_color_override("font_color", era_col.darkened(0.35))
		era_badge_btn.add_theme_color_override("font_hover_color", era_col.darkened(0.5))
		era_badge_btn.add_theme_font_size_override("font_size", 13)
		era_badge_btn.custom_minimum_size = Vector2(0, 30)
	
	# 右侧资源数值字体放大
	for val_lbl in [val_stone, val_wood, val_flint, val_ore, val_fuel]:
		if val_lbl:
			val_lbl.add_theme_font_size_override("font_size", 15)
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
		menu_hover.bg_color = Color(0.15, 0.14, 0.13, 0.08)
		menu_hover.corner_radius_top_left = 6
		menu_hover.corner_radius_top_right = 6
		menu_hover.corner_radius_bottom_left = 6
		menu_hover.corner_radius_bottom_right = 6
		btn_menu.add_theme_stylebox_override("hover", menu_hover)
		
		var menu_pressed = StyleBoxFlat.new()
		menu_pressed.bg_color = Color(0.15, 0.14, 0.13, 0.16)
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
	dock_box.shadow_color = Color(0.25, 0.20, 0.12, 0.22)
	dock_box.shadow_size = 14
	dock_box.shadow_offset = Vector2(0, 4)
	dock_box.content_margin_left = 16
	dock_box.content_margin_right = 16
	dock_box.content_margin_top = 4
	dock_box.content_margin_bottom = 4
	$Margin/MainVBox/BottomArea/BottomCenterRow/BottomDockPanel.add_theme_stylebox_override("panel", dock_box)
	
	# 底栏按钮悬停与激活态 (高对比冷灰极简深色文字与图标)
	var dock_accent = ThemeStyler.get_era_accent(GameState.current_era)
	var tab_buttons = [btn_tab_lab, btn_tab_tech, btn_tab_craft, btn_tab_build, btn_tab_production, btn_tab_inventory]
	for btn in tab_buttons:
		if btn:
			var btn_norm = StyleBoxFlat.new()
			btn_norm.bg_color = Color(0, 0, 0, 0.0)
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
			btn.add_theme_font_size_override("font_size", 12)
			btn.add_theme_font_size_override("font_size", 13)
			btn.add_theme_color_override("font_color", ThemeStyler.PAPER_INK)
			btn.add_theme_color_override("font_hover_color", dock_accent.darkened(0.45))
			btn.add_theme_color_override("font_pressed_color", dock_accent.darkened(0.45))
			btn.add_theme_color_override("icon_normal_color", ThemeStyler.PAPER_INK)
			btn.add_theme_color_override("icon_hover_color", dock_accent.darkened(0.3))
	
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
	
	# 5. 熔炉监控面板 (Furnace Panel)
	var f_box = ThemeStyler.create_card_box(10, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER)
	f_box.content_margin_left = 12
	f_box.content_margin_top = 10
	f_box.content_margin_right = 12
	f_box.content_margin_bottom = 10
	furnace_panel.add_theme_stylebox_override("panel", f_box)

# 通用制作/操作卡片创建函数
func _create_action_card(title: String, subtitle: String, icon_tex: Texture2D, badge_text: String, is_enabled: bool) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(210, 110)
	btn.size_flags_vertical = 3
	btn.tooltip_text = "%s\n%s" % [title, subtitle]
	
	var card_norm = ThemeStyler.create_card_box(8, ThemeStyler.COLOR_CARD, ThemeStyler.COLOR_BORDER)
	card_norm.content_margin_left = 12
	card_norm.content_margin_top = 10
	card_norm.content_margin_right = 12
	card_norm.content_margin_bottom = 10
	
	var card_hover = ThemeStyler.create_card_box(8, ThemeStyler.COLOR_CARD_HOVER, ThemeStyler.COLOR_BORDER_FOCUS)
	card_hover.content_margin_left = 12
	card_hover.content_margin_top = 10
	card_hover.content_margin_right = 12
	card_hover.content_margin_bottom = 10
	
	var card_press = ThemeStyler.create_card_box(8, ThemeStyler.COLOR_BG_SOLID, ThemeStyler.COLOR_ACCENT)
	card_press.content_margin_left = 12
	card_press.content_margin_top = 10
	card_press.content_margin_right = 12
	card_press.content_margin_bottom = 10
	
	btn.add_theme_stylebox_override("normal", card_norm)
	btn.add_theme_stylebox_override("hover", card_hover)
	btn.add_theme_stylebox_override("pressed", card_press)
	btn.add_theme_stylebox_override("focus", card_hover)
	
	# 半透明禁用状态处理
	if not is_enabled:
		btn.disabled = true
		btn.modulate = Color(1.0, 1.0, 1.0, 0.45)
	else:
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	btn.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	var top_hbox = HBoxContainer.new()
	top_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(top_hbox)
	
	var icon_rect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.texture = icon_tex
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_hbox.add_child(icon_rect)
	
	var title_vbox = VBoxContainer.new()
	title_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_vbox)
	
	var lbl_title = Label.new()
	lbl_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_title.text = title
	lbl_title.add_theme_font_size_override("font_size", 13)
	lbl_title.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
	title_vbox.add_child(lbl_title)
	
	var lbl_badge = Label.new()
	lbl_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_badge.text = badge_text
	lbl_badge.add_theme_font_size_override("font_size", 12)
	if is_enabled:
		lbl_badge.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
	else:
		lbl_badge.add_theme_color_override("font_color", ThemeStyler.COLOR_DANGER)
	title_vbox.add_child(lbl_badge)
	
	var lbl_sub = Label.new()
	lbl_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_sub.text = subtitle
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	vbox.add_child(lbl_sub)
	
	return btn

func _is_world_placing() -> bool:
	var w = get_parent()
	return w != null and "is_placing_structure" in w and w.is_placing_structure

func _unhandled_input(event: InputEvent) -> void:
	# 输入层级：建造选址 > 抽屉 > 弹窗 > 暂停菜单。选址模式下 ESC / 右键由 world 处理
	if _is_world_placing():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if action_drawer.visible:
			_close_drawer()
			get_viewport().set_input_as_handled()
			return
		if _has_any_modal_open():
			_close_all_modals()
			get_viewport().set_input_as_handled()
			return
		
	if event is InputEventKey and event.pressed and not event.echo:
		# 暂停菜单打开时只响应 ESC
		if pause_menu.visible and event.keycode != KEY_ESCAPE:
			return
		if event.keycode == KEY_L:
			_toggle_category(CategoryTab.LAB)
		elif event.keycode == KEY_K:
			tech_modal.toggle()
		elif event.keycode == KEY_T:
			_toggle_category(CategoryTab.CRAFT)
		elif event.keycode == KEY_C:
			_toggle_category(CategoryTab.BUILD)
		elif event.keycode == KEY_R:
			_toggle_category(CategoryTab.PRODUCTION)
		elif event.keycode == KEY_B:
			_toggle_category(CategoryTab.INVENTORY)
		elif event.keycode == KEY_P:
			periodic_modal.toggle()
		elif event.keycode == KEY_F5:
			save_load_modal.open(0, get_parent())
		elif event.keycode == KEY_F9:
			save_load_modal.open(1, get_parent())
		elif event.keycode == KEY_O:
			settings_modal.open()
		elif event.keycode == KEY_ESCAPE:
			if action_drawer.visible:
				_close_drawer()
			else:
				_close_all_modals()

func _has_any_modal_open() -> bool:
	return periodic_modal.visible or lab_modal.visible or tech_modal.visible or furnace_panel.visible or save_load_modal.visible or settings_modal.visible or pause_menu.visible or inventory_modal.visible

func _close_all_modals() -> void:
	var closed_any = false
	if periodic_modal.visible: periodic_modal.visible = false; closed_any = true
	if lab_modal.visible: lab_modal.visible = false; closed_any = true
	if tech_modal.visible: tech_modal.visible = false; closed_any = true
	if inventory_modal.visible: inventory_modal.close(); closed_any = true
	if furnace_panel.visible: furnace_panel.visible = false; closed_any = true
	if save_load_modal.visible: save_load_modal.close(); closed_any = true
	if settings_modal.visible: settings_modal.close(); closed_any = true
	if not closed_any:
		pause_menu.toggle()

var _furnace_info_timer: float = 0.0

func _process(delta: float) -> void:
	if current_nearby_furnace != null and furnace_panel.visible:
		_furnace_info_timer -= delta
		if _furnace_info_timer > 0.0:
			return
		_furnace_info_timer = 0.25
		var buf = current_nearby_furnace.buffer
		furnace_info.text = "温度: %d K (%d ℃)\n状态: %s\n物料: %s" % [
			int(buf.temperature),
			int(buf.temperature - 273.15),
			("燃烧中" if current_nearby_furnace.is_active_fire else "未生火"),
			_describe_components(buf.components)
		]

# 熔炉物料以「名称 数量」列出，而不是直接打印字典
func _describe_components(components: Dictionary) -> String:
	if components.is_empty():
		return "空"
	var parts: Array[String] = []
	for k in components.keys():
		var amt = float(components[k])
		if amt < 0.01:
			continue
		parts.append("%s %.1f" % [DataDB.get_item(k).get("name", k), amt])
	return "空" if parts.is_empty() else "、".join(parts)

func _setup_save_dot() -> void:
	if save_dot:
		save_dot.custom_minimum_size = Vector2(8, 8)
		save_dot.mouse_filter = Control.MOUSE_FILTER_STOP
		save_dot.tooltip_text = "自动存档就绪 (正常运行)"
		_set_save_dot_status(true, "自动存档就绪 (正常运行)")
		
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
		task_active_title.text = "空闲中"
		task_progress_box.visible = false
		task_btn_cancel_active.visible = false
	else:
		var t = GameState.active_task
		var rep = int(t.get("repeat_count", 1))
		var cur_c = int(t.get("current_cycle", 1))
		var title_base = t.get("title", "作业中")
		if rep == -1:
			task_active_title.text = "%s (第 %d 轮 · 无尽)" % [title_base, cur_c]
		elif rep > 1:
			task_active_title.text = "%s (%d/%d)" % [title_base, cur_c, rep]
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
			chip.text = "#%d %s (无尽) ✕" % [i + 1, q_task.get("title", "工作")]
		elif rep > 1:
			chip.text = "#%d %s x%d ✕" % [i + 1, q_task.get("title", "工作"), rep]
		else:
			chip.text = "#%d %s (%.1fs) ✕" % [i + 1, q_task.get("title", "工作"), q_task.get("time_required", 1.0)]
		chip.custom_minimum_size = Vector2(0, 24)
		chip.add_theme_font_size_override("font_size", 12)
		chip.tooltip_text = "点击从队列中撤销此工作"
		chip.pressed.connect(func(): GameState.cancel_task(task_id))
		task_queue_list.add_child(chip)

func _on_task_progress_updated(_task: Dictionary, percent: float, remaining_time: float) -> void:
	if not GameState.active_task.is_empty():
		task_progress_bar.value = percent
		task_active_time.text = "%.1fs" % remaining_time

func _update_inventory_ui() -> void:
	# 顶栏只保留五个核心资源: 石头、木头、燧石、矿、燃料
	val_stone.text = str(GameState.inventory.get_count("stone"))
	chip_stone.tooltip_text = "【碎石】当前储量: %s\n基础建材，用于制造石镐与陶窑" % val_stone.text
	
	var wood_cnt = GameState.inventory.get_count("wood")
	var stick_cnt = GameState.inventory.get_count("stick")
	val_wood.text = str(wood_cnt + stick_cnt)
	chip_wood.tooltip_text = "【木材/断枝】原木 %d, 枯枝 %d (合计 %s)\n用于工具把柄打造与生火" % [wood_cnt, stick_cnt, val_wood.text]
	
	val_flint.text = str(GameState.inventory.get_count("flint"))
	chip_flint.tooltip_text = "【燧石】当前储量: %s\n高硬度锋利岩块，用于制造燧石斧与击石取火" % val_flint.text
	
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
	chip_ore.tooltip_text = "【各类金属矿石】总计储量: %s\n包含孔雀石(铜矿)、赤铁矿(铁矿)等金属矿物" % val_ore.text
	
	# 燃料统计 (木炭 + 煤炭 + 焦炭)
	var total_fuels = (
		GameState.inventory.get_count("charcoal") +
		GameState.inventory.get_count("coal") +
		GameState.inventory.get_count("coke")
	)
	val_fuel.text = str(total_fuels)
	chip_fuel.tooltip_text = "【熔炉燃料】总计储量: %s\n包含木炭、煤炭与焦炭，用于供给陶土熔炉高温冶炼" % val_fuel.text
	
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
		era_badge_btn.custom_minimum_size = Vector2(0, 30)
		
	var tooltip_lines: Array[String] = [
		"【当前文明纪元】%s" % era_name,
		"领地范围: %d 瓦片  |  已发现元素: %d/118" % [terr_count, disc_count],
		""
	]
	if total_ms > 0:
		tooltip_lines.append("【时代跃迁目标】")
		for m in milestones:
			var m_k = str(m.get("key", ""))
			var m_desc = str(m.get("description", m_k))
			var is_done = GameState.completed_milestones.has(m_k)
			tooltip_lines.append("  %s %s" % ["✓" if is_done else "○", m_desc])
	else:
		tooltip_lines.append("深入探索大世界并冶炼新金属以突破新纪元！")
	tooltip_lines.append("\n(点击打开纪元详情面板)")
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
	var elem = DataDB.get_element(num)
	var sym = elem.get("symbol", "?")
	var cname = elem.get("name", key)
	show_toast("元素周期表突破: 成功点亮第 %d 号元素【%s (%s)】！" % [num, cname, sym], ThemeStyler.COLOR_ACCENT)

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
	sbox.shadow_color = Color(0, 0, 0, 0.45)
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
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
	hbox.add_child(lbl)

	toast_container.add_child(toast_panel)
	toast_panel.modulate.a = 0.0

	var tw = create_tween()
	tw.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.2)
	tw.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(toast_panel.queue_free)

func show_furnace_ui(furnace: Node2D) -> void:
	current_nearby_furnace = furnace
	furnace_panel.visible = true
	var b_name = DataDB.get_building_recipe(furnace.building_type).get("name", "熔炉") if "building_type" in furnace else "熔炉"
	if furnace_info:
		furnace_info.text = "【%s】现场控制台\n温度: %d ℃" % [b_name, int(furnace.buffer.temperature - 273.15)]

func hide_furnace_ui() -> void:
	current_nearby_furnace = null
	furnace_panel.visible = false

func _on_btn_add_fuel_pressed() -> void:
	if current_nearby_furnace:
		current_nearby_furnace.add_fuel()

func _on_btn_add_malachite_pressed() -> void:
	if current_nearby_furnace:
		current_nearby_furnace.add_ore("malachite", 1)

func _on_btn_add_hematite_pressed() -> void:
	if current_nearby_furnace:
		current_nearby_furnace.add_ore("hematite", 1)

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
