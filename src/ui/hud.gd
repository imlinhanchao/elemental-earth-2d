# hud.gd
# 游戏主界面 HUD 控制器: 现代战略范式，底部多分类动作坞，右侧作业队列，全套矢量美术图标
extends CanvasLayer

signal build_furnace_requested
signal build_reactor_requested
signal save_requested
signal load_requested
signal reset_requested

const ThemeStyler = preload("res://src/ui/theme_styler.gd")

enum CategoryTab { NONE, LAB, TECH, CRAFT, BUILD, PRODUCTION, INVENTORY }
var current_tab: CategoryTab = CategoryTab.NONE

# 顶部导航与状态条
@onready var era_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/EraLabel
@onready var territory_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/TerritoryLabel
@onready var biome_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/BiomeLabel
@onready var notice_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/NoticeLabel
@onready var elements_summary_label = $Margin/MainVBox/TopBarPanel/Margin/HBox/ElementsChip/ElementsSummaryLabel
@onready var btn_menu = $Margin/MainVBox/TopBarPanel/Margin/HBox/BtnMenu

# 顶部资源胶囊数值标签
@onready var val_wood = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipWood/Val
@onready var val_stick = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipStick/Val
@onready var val_stone = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipStone/Val
@onready var val_flint = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipFlint/Val
@onready var val_water = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipWater/Val
@onready var val_charcoal = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipCharcoal/Val
@onready var val_malachite = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipMalachite/Val
@onready var val_copper = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipCopper/Val
@onready var val_iron = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipIron/Val
@onready var val_salt = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipSalt/Val
@onready var val_sulfur = $Margin/MainVBox/TopBarPanel/Margin/HBox/ResourceRibbon/ChipSulfur/Val

# 右侧作业队列面板 (Task Queue Dock)
@onready var task_queue_count = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/Header/QueueCount
@onready var task_active_title = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/HBox/ActiveTitle
@onready var task_btn_cancel_active = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/HBox/BtnCancelActive
@onready var task_progress_box = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/ProgressHBox
@onready var task_progress_bar = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/ProgressHBox/ProgressBar
@onready var task_active_time = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/ActiveTaskBox/ProgressHBox/ActiveTime
@onready var task_queue_list = $Margin/MainVBox/BodyHBox/RightBox/TaskDock/Margin/VBox/QueueScroll/QueueList

# 熔炉近场状态监测
@onready var furnace_panel = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel
@onready var furnace_info = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/FurnaceInfo
@onready var btn_add_fuel = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/BtnAddFuel
@onready var btn_add_malachite = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/BtnAddMalachite
@onready var btn_add_iron_ore = $Margin/MainVBox/BodyHBox/RightBox/FurnacePanel/Margin/VBox/BtnAddIronOre

# 底部多分类动作坞 (Bottom Categorized Action Dock)
@onready var action_drawer = $Margin/MainVBox/BottomArea/ActionDrawer
@onready var drawer_title = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Header/DrawerTitle
@onready var btn_close_drawer = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Header/BtnCloseDrawer
@onready var drawer_grid = $Margin/MainVBox/BottomArea/ActionDrawer/Margin/VBox/Scroll/DrawerGrid

@onready var btn_tab_lab = $Margin/MainVBox/BottomArea/BottomDockPanel/Margin/DockHBox/BtnTabLab
@onready var btn_tab_tech = $Margin/MainVBox/BottomArea/BottomDockPanel/Margin/DockHBox/BtnTabTech
@onready var btn_tab_craft = $Margin/MainVBox/BottomArea/BottomDockPanel/Margin/DockHBox/BtnTabCraft
@onready var btn_tab_build = $Margin/MainVBox/BottomArea/BottomDockPanel/Margin/DockHBox/BtnTabBuild
@onready var btn_tab_production = $Margin/MainVBox/BottomArea/BottomDockPanel/Margin/DockHBox/BtnTabProduction
@onready var btn_tab_inventory = $Margin/MainVBox/BottomArea/BottomDockPanel/Margin/DockHBox/BtnTabInventory

# 模态弹窗系统
@onready var periodic_modal = $PeriodicTableModal
@onready var lab_modal = $LabWorkbenchModal
@onready var tool_modal = $ToolCraftModal
@onready var tech_modal = $TechTreeModal
@onready var era_modal = $EraTransitionModal
@onready var save_load_modal = $SaveLoadModal
@onready var settings_modal = $SettingsModal
@onready var pause_menu = $PauseMenu

var current_nearby_furnace: Node2D = null

# 图标资源预加载映射表 (与参考美术风格保持完全一致)
const ICON_MAP = {
	"wood": preload("res://assets/icons/res_wood.svg"),
	"stick": preload("res://assets/icons/res_stick.svg"),
	"stone": preload("res://assets/icons/res_stone.svg"),
	"flint": preload("res://assets/icons/res_flint.svg"),
	"water": preload("res://assets/icons/res_water.svg"),
	"charcoal": preload("res://assets/icons/res_charcoal.svg"),
	"malachite": preload("res://assets/icons/res_malachite.svg"),
	"iron_ore": preload("res://assets/icons/res_hematite.svg"),
	"copper": preload("res://assets/icons/res_copper.svg"),
	"iron": preload("res://assets/icons/res_iron.svg"),
	"halite": preload("res://assets/icons/res_salt.svg"),
	"salt": preload("res://assets/icons/res_salt.svg"),
	"sulfur": preload("res://assets/icons/res_sulfur.svg"),
	"gas": preload("res://assets/icons/res_gas.svg"),
	"carbon_monoxide": preload("res://assets/icons/res_gas.svg"),
	"carbon_dioxide": preload("res://assets/icons/res_gas.svg"),
	"hydrogen": preload("res://assets/icons/res_gas.svg"),
	"oxygen": preload("res://assets/icons/res_gas.svg"),
	"flint_axe": preload("res://assets/icons/tool_flint_axe.svg"),
	"stone_pickaxe": preload("res://assets/icons/tool_stone_pickaxe.svg"),
	"copper_pickaxe": preload("res://assets/icons/tool_copper_pickaxe.svg"),
	"iron_pickaxe": preload("res://assets/icons/tool_iron_hammer.svg"),
	"furnace": preload("res://assets/icons/furnace.svg"),
	"industrial_reactor": preload("res://assets/icons/reactor.svg"),
	"fuel_fire": preload("res://assets/icons/fuel_fire.svg"),
	"blueprint": preload("res://assets/icons/blueprint.svg"),
	"lab": preload("res://assets/icons/lab.svg"),
	"tech": preload("res://assets/icons/tech.svg"),
	"tab_tech": preload("res://assets/icons/tab_tech.svg"),
	"periodic_table": preload("res://assets/icons/periodic_table.svg"),
}

func get_item_icon(key: String) -> Texture2D:
	if ICON_MAP.has(key):
		return ICON_MAP[key]
	return preload("res://assets/icons/res_ore.svg")

func _ready() -> void:
	var sc_theme = ThemeStyler.create_scientific_theme()
	$Margin.theme = sc_theme
	periodic_modal.theme = sc_theme
	lab_modal.theme = sc_theme
	tool_modal.theme = sc_theme
	tech_modal.theme = sc_theme
	era_modal.theme = sc_theme
	save_load_modal.theme = sc_theme
	settings_modal.theme = sc_theme
	pause_menu.theme = sc_theme
	
	GameState.notification_posted.connect(_on_notification_posted)
	GameState.element_discovered.connect(_on_element_discovered)
	GameState.inventory.item_changed.connect(_on_item_changed)
	GameState.era_advanced.connect(_on_era_advanced)
	
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
	
	# 熔炉快速操作
	btn_add_fuel.pressed.connect(_on_btn_add_fuel_pressed)
	btn_add_malachite.pressed.connect(_on_btn_add_malachite_pressed)
	btn_add_iron_ore.pressed.connect(_on_btn_add_iron_ore_pressed)
	
	furnace_panel.visible = false
	action_drawer.visible = false
	_update_inventory_ui()
	_update_elements_ui()
	_update_era_label()
	_update_task_queue_ui()
	
	notice_label.text = "点击地表排队作业 · 下方分类菜单建造与制作 · [ESC]系统菜单"

func _toggle_category(tab: CategoryTab) -> void:
	if current_tab == tab and action_drawer.visible:
		_close_drawer()
	else:
		current_tab = tab
		action_drawer.visible = true
		_populate_drawer(tab)

func _close_drawer() -> void:
	current_tab = CategoryTab.NONE
	action_drawer.visible = false

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
				if b_key == "furnace":
					_on_btn_build_furnace_pressed()
				elif b_key == "industrial_reactor":
					_on_btn_build_reactor_requested()
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
	var iron_ore_cnt = GameState.inventory.get_count("iron_ore")
	var can_smelt_iron = iron_ore_cnt >= 1 and current_nearby_furnace != null
	var iron_card = _create_action_card(
		"赤铁矿冶铁",
		"投入赤铁矿 x1 冶炼金属铁 (存量: %d)" % iron_ore_cnt,
		get_item_icon("iron_ore"),
		("可投入" if can_smelt_iron else ("无就近熔炉" if current_nearby_furnace == null else "缺少赤铁矿")),
		can_smelt_iron
	)
	if can_smelt_iron:
		iron_card.pressed.connect(func():
			_on_btn_add_iron_ore_pressed()
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
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
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

# 通用制作/操作卡片创建函数 (严格遵循半透明禁用规范)
func _create_action_card(title: String, subtitle: String, icon_tex: Texture2D, badge_text: String, is_enabled: bool) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(210, 110)
	btn.size_flags_vertical = 3
	btn.tooltip_text = "%s\n%s" % [title, subtitle]
	
	# 半透明禁用状态处理
	if not is_enabled:
		btn.disabled = true
		btn.modulate = Color(1.0, 1.0, 1.0, 0.4)
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
	lbl_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.94))
	title_vbox.add_child(lbl_title)
	
	var lbl_badge = Label.new()
	lbl_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_badge.text = badge_text
	lbl_badge.add_theme_font_size_override("font_size", 11)
	if is_enabled:
		lbl_badge.add_theme_color_override("font_color", Color(0.3, 0.55, 1.0))
	else:
		lbl_badge.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	title_vbox.add_child(lbl_badge)
	
	var lbl_sub = Label.new()
	lbl_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_sub.text = subtitle
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sub.add_theme_font_size_override("font_size", 11)
	lbl_sub.add_theme_color_override("font_color", Color(0.60, 0.62, 0.65))
	vbox.add_child(lbl_sub)
	
	return btn

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if action_drawer.visible:
			_close_drawer()
			get_viewport().set_input_as_handled()
			return
		if _has_any_modal_open():
			_close_all_modals()
			get_viewport().set_input_as_handled()
			return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_L:
			_toggle_category(CategoryTab.LAB)
		elif event.keycode == KEY_K:
			tech_modal.toggle()
		elif event.keycode == KEY_T:
			_toggle_category(CategoryTab.CRAFT)
		elif event.keycode == KEY_C or event.keycode == KEY_F:
			_toggle_category(CategoryTab.BUILD)
		elif event.keycode == KEY_R:
			_toggle_category(CategoryTab.PRODUCTION)
		elif event.keycode == KEY_B or event.keycode == KEY_I:
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
	return periodic_modal.visible or lab_modal.visible or tool_modal.visible or tech_modal.visible or furnace_panel.visible or save_load_modal.visible or settings_modal.visible or pause_menu.visible

func _close_all_modals() -> void:
	var closed_any = false
	if periodic_modal.visible: periodic_modal.visible = false; closed_any = true
	if lab_modal.visible: lab_modal.visible = false; closed_any = true
	if tool_modal.visible: tool_modal.visible = false; closed_any = true
	if tech_modal.visible: tech_modal.visible = false; closed_any = true
	if furnace_panel.visible: furnace_panel.visible = false; closed_any = true
	if save_load_modal.visible: save_load_modal.close(); closed_any = true
	if settings_modal.visible: settings_modal.close(); closed_any = true
	if not closed_any:
		pause_menu.toggle()

func _process(_delta: float) -> void:
	if current_nearby_furnace != null and furnace_panel.visible:
		var buf = current_nearby_furnace.buffer
		furnace_info.text = "温度: %d K (%d ℃)\n状态: %s\n物料: %s" % [
			int(buf.temperature),
			int(buf.temperature - 273.15),
			("燃烧中" if current_nearby_furnace.is_active_fire else "未生火"),
			(str(buf.components) if buf.components.size() > 0 else "空")
		]

func _update_task_queue_ui() -> void:
	var q_size = GameState.task_queue.size()
	task_queue_count.text = "%d 待办" % q_size
	
	if GameState.active_task.is_empty():
		task_active_title.text = "作业队列 空闲中"
		task_progress_box.visible = false
		task_btn_cancel_active.visible = false
	else:
		var t = GameState.active_task
		task_active_title.text = "%s" % t.get("title", "作业中")
		task_progress_box.visible = true
		task_btn_cancel_active.visible = true
	
	for child in task_queue_list.get_children():
		child.queue_free()
		
	for i in range(q_size):
		var q_task = GameState.task_queue[i]
		var task_id = q_task.get("id")
		var chip = Button.new()
		chip.text = "#%d %s (%.1fs) ✕" % [i + 1, q_task.get("title", "工作"), q_task.get("time_required", 1.0)]
		chip.custom_minimum_size = Vector2(0, 26)
		chip.add_theme_font_size_override("font_size", 11)
		chip.tooltip_text = "点击从队列中撤销此工作"
		chip.pressed.connect(func(): GameState.cancel_task(task_id))
		task_queue_list.add_child(chip)

func _on_task_progress_updated(_task: Dictionary, percent: float, remaining_time: float) -> void:
	if not GameState.active_task.is_empty():
		task_progress_bar.value = percent
		task_active_time.text = "%.1fs" % remaining_time

func _update_inventory_ui() -> void:
	# 刷新顶部资源胶囊数值
	val_wood.text = str(GameState.inventory.get_count("wood"))
	val_stick.text = str(GameState.inventory.get_count("stick"))
	val_stone.text = str(GameState.inventory.get_count("stone"))
	val_flint.text = str(GameState.inventory.get_count("flint"))
	val_water.text = str(GameState.inventory.get_count("water"))
	val_charcoal.text = str(GameState.inventory.get_count("charcoal"))
	val_malachite.text = str(GameState.inventory.get_count("malachite"))
	val_copper.text = str(GameState.inventory.get_count("copper"))
	val_iron.text = str(GameState.inventory.get_count("iron"))
	val_salt.text = str(GameState.inventory.get_count("halite"))
	val_sulfur.text = str(GameState.inventory.get_count("sulfur"))
	
	# 如果当前抽屉打开，实时刷新抽屉内容
	if action_drawer.visible:
		_populate_drawer(current_tab)

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
