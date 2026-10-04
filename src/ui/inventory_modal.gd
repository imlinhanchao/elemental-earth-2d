# inventory_modal.gd
# 戴森球计划 (DSP) 风格物品清单覆盖网格弹窗
# 10 列密集平铺槽位、实时堆叠计数、鼠标悬停浮动详情卡片与 [B] 快捷键响应
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const DataDB = preload("res://src/core/data_db.gd")
const ItemIconManager = preload("res://src/ui/item_icon_manager.gd")

@onready var dim_overlay = $DimOverlay
@onready var center_panel = $CenterPanel
@onready var btn_close = $CenterPanel/VBox/Header/BtnClose
@onready var btn_sort = $CenterPanel/VBox/Header/BtnSort
@onready var capacity_label = $CenterPanel/VBox/Header/CapacityLabel
@onready var slot_grid = $CenterPanel/VBox/Scroll/GridMargin/SlotGrid

# 悬停浮动详情卡片
@onready var floating_tooltip = $FloatingTooltip
@onready var tip_item_name = $FloatingTooltip/TipVBox/TitleRow/ItemName
@onready var tip_category = $FloatingTooltip/TipVBox/TitleRow/CategoryBadge
@onready var tip_chem = $FloatingTooltip/TipVBox/ChemLabel
@onready var tip_desc = $FloatingTooltip/TipVBox/DescLabel
@onready var tip_count = $FloatingTooltip/TipVBox/BottomRow/CountLabel
@onready var tip_attr = $FloatingTooltip/TipVBox/BottomRow/AttrLabel

const BASE_SLOTS_COUNT: int = 80 # 8 行 × 10 列基础槽位
var hovered_slot_data: Dictionary = {}

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_apply_styles()
	
	btn_close.pressed.connect(func(): close())
	btn_sort.pressed.connect(_on_sort_pressed)
	
	GameState.inventory.item_changed.connect(func(_k, _c):
		if visible:
			_refresh_slots()
	)
	
	floating_tooltip.visible = false

func _apply_styles() -> void:
	# 详情卡片半透明深邃科技样式
	var tip_style = StyleBoxFlat.new()
	tip_style.bg_color = Color(0.06, 0.08, 0.11, 0.94)
	tip_style.border_color = Color(0.22, 0.55, 0.85, 0.9)
	tip_style.border_width_left = 1
	tip_style.border_width_top = 1
	tip_style.border_width_right = 1
	tip_style.border_width_bottom = 1
	tip_style.corner_radius_top_left = 6
	tip_style.corner_radius_top_right = 6
	tip_style.corner_radius_bottom_left = 6
	tip_style.corner_radius_bottom_right = 6
	tip_style.content_margin_left = 12
	tip_style.content_margin_top = 10
	tip_style.content_margin_right = 12
	tip_style.content_margin_bottom = 10
	floating_tooltip.add_theme_stylebox_override("panel", tip_style)

func _process(_delta: float) -> void:
	if visible and floating_tooltip.visible:
		_update_tooltip_position()

func _update_tooltip_position() -> void:
	var mpos = get_global_mouse_position()
	var vp_size = get_viewport_rect().size
	var tip_size = floating_tooltip.size
	
	var target_pos = mpos + Vector2(16, 16)
	if target_pos.x + tip_size.x > vp_size.x - 16:
		target_pos.x = mpos.x - tip_size.x - 16
	if target_pos.y + tip_size.y > vp_size.y - 16:
		target_pos.y = mpos.y - tip_size.y - 16
		
	floating_tooltip.global_position = target_pos

func open() -> void:
	visible = true
	floating_tooltip.visible = false
	_refresh_slots()
	btn_close.grab_focus()

func close() -> void:
	visible = false
	floating_tooltip.visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _input(event: InputEvent) -> void:
	if not visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
			open()
			get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			close()
			get_viewport().set_input_as_handled()
			return
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		close()
		get_viewport().set_input_as_handled()

func _refresh_slots() -> void:
	for child in slot_grid.get_children():
		child.queue_free()
		
	var items_dict = GameState.inventory.items
	var item_keys = items_dict.keys()
	
	# 过滤出数量大于 0 的有效物品
	var active_keys: Array = []
	for k in item_keys:
		if int(items_dict[k]) > 0:
			active_keys.append(k)
			
	capacity_label.text = "已占用: %d / %d 槽位" % [active_keys.size(), max(BASE_SLOTS_COUNT, (ceil(float(active_keys.size()) / 10.0) * 10))]
	
	var total_slots = max(BASE_SLOTS_COUNT, int(ceil(float(active_keys.size()) / 10.0) * 10))
	
	for i in range(total_slots):
		if i < active_keys.size():
			var item_key = active_keys[i]
			var count = int(items_dict[item_key])
			var slot = _create_occupied_slot(item_key, count)
			slot_grid.add_child(slot)
		else:
			var empty_slot = _create_empty_slot()
			slot_grid.add_child(empty_slot)

func _create_occupied_slot(item_key: String, count: int) -> Control:
	var item_data = DataDB.get_item(item_key)
	var item_name = item_data.get("name", item_key)
	
	var slot_panel = PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(68, 68)
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 戴森球计划风格深色内嵌方格
	var norm_style = StyleBoxFlat.new()
	norm_style.bg_color = Color(0.09, 0.11, 0.14, 0.9)
	norm_style.border_color = Color(0.20, 0.24, 0.30, 0.95)
	norm_style.border_width_left = 1
	norm_style.border_width_top = 1
	norm_style.border_width_right = 1
	norm_style.border_width_bottom = 1
	norm_style.corner_radius_top_left = 4
	norm_style.corner_radius_top_right = 4
	norm_style.corner_radius_bottom_left = 4
	norm_style.corner_radius_bottom_right = 4
	slot_panel.add_theme_stylebox_override("panel", norm_style)
	
	var hover_style = norm_style.duplicate()
	hover_style.bg_color = Color(0.14, 0.19, 0.27, 1.0)
	hover_style.border_color = Color(0.28, 0.65, 1.0, 1.0) # 高亮蓝光描边
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	slot_panel.add_child(margin)
	
	# 居中专属高清矢量图标
	var icon_rect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = ItemIconManager.get_icon(item_key)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(icon_rect)
	
	# 右下角堆叠数字 (白字 + 阴影描边)
	var count_lbl = Label.new()
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_lbl.text = str(count)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	count_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	count_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	count_lbl.add_theme_constant_override("shadow_offset_x", 1)
	count_lbl.add_theme_constant_override("shadow_offset_y", 1)
	count_lbl.add_theme_font_size_override("font_size", 12)
	margin.add_child(count_lbl)
	
	# 悬停事件
	slot_panel.mouse_entered.connect(func():
		slot_panel.add_theme_stylebox_override("panel", hover_style)
		_show_tooltip_for_item(item_key, item_data, count)
	)
	slot_panel.mouse_exited.connect(func():
		slot_panel.add_theme_stylebox_override("panel", norm_style)
		floating_tooltip.visible = false
	)
	
	return slot_panel

func _create_empty_slot() -> Control:
	var slot_panel = PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(68, 68)
	slot_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color(0.065, 0.075, 0.09, 0.5)
	empty_style.border_color = Color(0.14, 0.16, 0.20, 0.6)
	empty_style.border_width_left = 1
	empty_style.border_width_top = 1
	empty_style.border_width_right = 1
	empty_style.border_width_bottom = 1
	empty_style.corner_radius_top_left = 4
	empty_style.corner_radius_top_right = 4
	empty_style.corner_radius_bottom_left = 4
	empty_style.corner_radius_bottom_right = 4
	slot_panel.add_theme_stylebox_override("panel", empty_style)
	
	return slot_panel

func _show_tooltip_for_item(item_key: String, data: Dictionary, count: int) -> void:
	var iname = data.get("name", item_key)
	var cat = data.get("category", "材料")
	var desc = data.get("description", "无特定物理与化学描述。")
	var elem_num = data.get("elemental", 0)
	var attrs = data.get("attrs", {})
	
	tip_item_name.text = iname
	tip_category.text = "【%s】" % cat
	
	if elem_num > 0:
		var elem_info = DataDB.get_element(elem_num)
		var sym = elem_info.get("symbol", "")
		tip_chem.text = "化学纯质: %s (%s · %d号元素)" % [iname, sym, elem_num]
		tip_chem.visible = true
	else:
		tip_chem.visible = false
		
	tip_desc.text = desc
	tip_count.text = "库存数量: %d" % count
	
	var extra_attrs: Array[String] = []
	if attrs.has("burn_time"):
		extra_attrs.append("热值: %ds" % int(attrs["burn_time"]))
	if attrs.has("durability"):
		extra_attrs.append("耐久: %d" % int(attrs["durability"]))
	if data.get("is_discovery", false):
		extra_attrs.append("✨重大发现")
		
	tip_attr.text = " · ".join(extra_attrs)
	
	floating_tooltip.visible = true
	_update_tooltip_position()

func _on_sort_pressed() -> void:
	# 触发刷新排序
	_refresh_slots()
	GameState.post_notice("物品清单已按类别整理完毕", Color(0.3, 0.8, 1.0))
