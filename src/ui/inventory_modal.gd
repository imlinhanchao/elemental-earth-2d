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
	# 居中主面板浮动暗蓝磨砂几何样式
	var panel_style = ThemeStyler.create_card_box(12, ThemeStyler.COLOR_BG, ThemeStyler.COLOR_BORDER)
	panel_style.content_margin_left = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_bottom = 16
	center_panel.add_theme_stylebox_override("panel", panel_style)

	# 悬停卡片方案三电光青微光毛玻璃样式 (纯色深底保证不透光穿帮)
	var tip_style = ThemeStyler.create_card_box(10, ThemeStyler.COLOR_BG_SOLID, ThemeStyler.COLOR_BORDER_FOCUS)
	tip_style.content_margin_left = 14
	tip_style.content_margin_top = 12
	tip_style.content_margin_right = 14
	tip_style.content_margin_bottom = 12
	tip_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	tip_style.shadow_size = 14
	tip_style.shadow_offset = Vector2(0, 4)
	floating_tooltip.add_theme_stylebox_override("panel", tip_style)
	
	tip_desc.custom_minimum_size = Vector2(252, 0)

func _process(_delta: float) -> void:
	if visible and floating_tooltip.visible:
		_update_tooltip_position()

func _update_tooltip_position() -> void:
	var mpos = get_global_mouse_position()
	var vp_size = get_viewport_rect().size
	var tip_size = floating_tooltip.size
	
	var target_pos = mpos + Vector2(16, 16)
	if target_pos.x + tip_size.x > vp_size.x - 16.0:
		target_pos.x = mpos.x - tip_size.x - 16.0
	if target_pos.y + tip_size.y > vp_size.y - 16.0:
		target_pos.y = mpos.y - tip_size.y - 16.0
		
	# 边缘安全边界钳制：绝不溢出屏幕任何边缘 (特别是顶部)
	target_pos.x = clampf(target_pos.x, 16.0, max(16.0, vp_size.x - tip_size.x - 16.0))
	target_pos.y = clampf(target_pos.y, 16.0, max(16.0, vp_size.y - tip_size.y - 16.0))
		
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
	
	# 方案三现代科学信息槽位
	var norm_style = StyleBoxFlat.new()
	norm_style.bg_color = ThemeStyler.COLOR_CARD
	norm_style.border_color = ThemeStyler.COLOR_BORDER
	norm_style.border_width_left = 1
	norm_style.border_width_top = 1
	norm_style.border_width_right = 1
	norm_style.border_width_bottom = 1
	norm_style.corner_radius_top_left = 8
	norm_style.corner_radius_top_right = 8
	norm_style.corner_radius_bottom_left = 8
	norm_style.corner_radius_bottom_right = 8
	slot_panel.add_theme_stylebox_override("panel", norm_style)
	
	var hover_style = norm_style.duplicate()
	hover_style.bg_color = ThemeStyler.COLOR_CARD_HOVER
	hover_style.border_color = ThemeStyler.COLOR_BORDER_FOCUS # 电光青发光细描边
	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	
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
	empty_style.bg_color = Color(0.065, 0.085, 0.125, 0.5)
	empty_style.border_color = Color(0.16, 0.22, 0.30, 0.5)
	empty_style.border_width_left = 1
	empty_style.border_width_top = 1
	empty_style.border_width_right = 1
	empty_style.border_width_bottom = 1
	empty_style.corner_radius_top_left = 8
	empty_style.corner_radius_top_right = 8
	empty_style.corner_radius_bottom_left = 8
	empty_style.corner_radius_bottom_right = 8
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
	
	# 方案 2: 渲染化学特性标签胶囊 (用于直观启发玩家反应潜能)
	var tags_box = $FloatingTooltip/TipVBox.get_node_or_null("TagsHBox")
	if not tags_box:
		tags_box = HBoxContainer.new()
		tags_box.name = "TagsHBox"
		tags_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tags_box.add_theme_constant_override("separation", 6)
		$FloatingTooltip/TipVBox.add_child(tags_box)
		$FloatingTooltip/TipVBox.move_child(tags_box, tip_chem.get_index() + 1)
		
	for c in tags_box.get_children():
		c.queue_free()
		
	var chem_tags = DataDB.get_item_chemical_tags(item_key)
	if chem_tags.is_empty():
		tags_box.visible = false
	else:
		tags_box.visible = true
		for t_info in chem_tags:
			var tag_panel = PanelContainer.new()
			tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tag_style = StyleBoxFlat.new()
			var col = t_info.get("color", Color(0.3, 0.7, 0.9))
			tag_style.bg_color = Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.9)
			tag_style.border_color = Color(col.r, col.g, col.b, 0.65)
			tag_style.border_width_left = 1
			tag_style.border_width_top = 1
			tag_style.border_width_right = 1
			tag_style.border_width_bottom = 1
			tag_style.corner_radius_top_left = 4
			tag_style.corner_radius_top_right = 4
			tag_style.corner_radius_bottom_left = 4
			tag_style.corner_radius_bottom_right = 4
			tag_style.content_margin_left = 6
			tag_style.content_margin_top = 2
			tag_style.content_margin_right = 6
			tag_style.content_margin_bottom = 2
			tag_panel.add_theme_stylebox_override("panel", tag_style)
			
			var tag_lbl = Label.new()
			tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tag_lbl.text = t_info.get("text", "")
			tag_lbl.add_theme_font_size_override("font_size", 10)
			tag_lbl.add_theme_color_override("font_color", col)
			tag_panel.add_child(tag_lbl)
			tags_box.add_child(tag_panel)
	
	var extra_attrs: Array[String] = []
	if attrs.has("burn_time"):
		extra_attrs.append("热值: %ds" % int(attrs["burn_time"]))
	if attrs.has("durability"):
		extra_attrs.append("耐久: %d" % int(attrs["durability"]))
	if data.get("is_discovery", false):
		extra_attrs.append("✨重大发现")
		
	tip_attr.text = " · ".join(extra_attrs)
	
	floating_tooltip.visible = true
	floating_tooltip.reset_size()
	_update_tooltip_position()

func _on_sort_pressed() -> void:
	# 触发刷新排序
	_refresh_slots()
	GameState.post_notice("物品清单已按类别整理完毕", Color(0.3, 0.8, 1.0))
