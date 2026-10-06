# tile_context_menu.gd
# 区块资源开采右键上下文菜单 (现代科学极简风)
# 支持多资源筛选、开采次数选择 (5/10/20/100/1000/无尽) 与任务下发
extends PanelContainer

const ThemeStyler = preload("res://src/ui/theme_styler.gd")
const ItemIconManager = preload("res://src/ui/item_icon_manager.gd")
const DataDB = preload("res://src/core/data_db.gd")

signal harvest_requested(hex: Vector2i, item_key: String, count: int)

var current_hex: Vector2i = Vector2i(9999, 9999)
var current_resources: Array = []
var selected_item_key: String = ""

@onready var vbox: VBoxContainer = $Margin/VBox
@onready var title_label: Label = $Margin/VBox/Header/TitleLabel
@onready var btn_back: Button = $Margin/VBox/Header/BackButton
@onready var btn_close: Button = $Margin/VBox/Header/CloseButton
@onready var content_box: VBoxContainer = $Margin/VBox/ContentBox

func _ready() -> void:
	visible = false
	_apply_styling()
	btn_close.pressed.connect(close)
	btn_back.pressed.connect(_show_resource_selection)

func _apply_styling() -> void:
	var box = StyleBoxFlat.new()
	box.bg_color = ThemeStyler.COLOR_BG
	box.border_color = ThemeStyler.COLOR_BORDER
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", box)

func open_at(screen_pos: Vector2, hex: Vector2i, resources: Array) -> void:
	current_hex = hex
	current_resources = resources
	selected_item_key = ""
	
	if resources.is_empty():
		GameState.post_notice("该区块暂无可开采的资源储备！", ThemeStyler.COLOR_TEXT_MUTED)
		close()
		return
		
	visible = true
	
	if resources.size() > 1:
		_show_resource_selection()
	else:
		selected_item_key = resources[0].get("key", "")
		_show_count_selection(resources[0])
		
	# 确保不超出屏幕边界
	await get_tree().process_frame
	var vp_size = get_viewport_rect().size
	var m_size = size
	var target_x = clamp(screen_pos.x, 10.0, max(10.0, vp_size.x - m_size.x - 10.0))
	var target_y = clamp(screen_pos.y, 45.0, max(45.0, vp_size.y - m_size.y - 10.0))
	global_position = Vector2(target_x, target_y)

func close() -> void:
	visible = false

# 步骤 1: 若有多种资源，先选择目标资源
func _show_resource_selection() -> void:
	btn_back.visible = false
	title_label.text = "选择开采物料"
	_clear_content()
	
	for res in current_resources:
		var key = res.get("key", "")
		var iname = res.get("name", key)
		var amount = int(res.get("amount", 0))
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 32)
		btn.text = " %s  (剩余: %d)" % [iname, amount]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var icon_tex = ItemIconManager.get_icon(key)
		if icon_tex:
			btn.icon = icon_tex
			btn.expand_icon = true
			
		btn.add_theme_font_size_override("font_size", 12)
		var res_dict = res
		btn.pressed.connect(func():
			selected_item_key = key
			_show_count_selection(res_dict)
		)
		content_box.add_child(btn)

# 步骤 2: 选择开采次数 (5 / 10 / 20 / 100 / 1000 / 无尽)
func _show_count_selection(res_info: Dictionary) -> void:
	btn_back.visible = (current_resources.size() > 1)
	var iname = res_info.get("name", selected_item_key)
	var remaining = int(res_info.get("amount", 0))
	title_label.text = "开采 %s (%d)" % [iname, remaining]
	_clear_content()
	
	var desc_label = Label.new()
	desc_label.text = "选择作业循环次数:"
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
	content_box.add_child(desc_label)
	
	var grid = GridContainer.new()
	grid.columns = 3
	content_box.add_child(grid)
	
	var counts = [5, 10, 20, 100, 1000]
	for c in counts:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(58, 28)
		btn.text = "%d 次" % c
		btn.add_theme_font_size_override("font_size", 12)
		var this_count = c
		btn.pressed.connect(func():
			_dispatch_harvest(this_count)
		)
		grid.add_child(btn)
		
	# 无尽按钮 (加宽加亮)
	var btn_infinite = Button.new()
	btn_infinite.custom_minimum_size = Vector2(180, 30)
	btn_infinite.text = "∞ 无尽开采 (直到采空)"
	btn_infinite.add_theme_font_size_override("font_size", 12)
	btn_infinite.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
	btn_infinite.pressed.connect(func():
		_dispatch_harvest(-1)
	)
	content_box.add_child(btn_infinite)

func _dispatch_harvest(count: int) -> void:
	harvest_requested.emit(current_hex, selected_item_key, count)
	close()

func _clear_content() -> void:
	for c in content_box.get_children():
		c.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed:
		var local_pos = get_global_transform().affine_inverse() * event.position
		if not Rect2(Vector2.ZERO, size).has_point(local_pos):
			close()
	elif visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
