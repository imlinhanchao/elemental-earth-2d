# save_load_modal.gd
# 业界标准多槽位存档与读档交互面板
extends PanelContainer

const SaveManager = preload("res://src/core/save_manager.gd")

signal slot_selected(slot_id: String, mode: int)
signal modal_closed

enum Mode {
	SAVE,
	LOAD
}

var current_mode: Mode = Mode.LOAD
var world_ref: Node2D = null

@onready var title_label = $Margin/VBox/Header/TitleLabel
@onready var btn_close = $Margin/VBox/Header/BtnClose
@onready var slots_container = $Margin/VBox/Scroll/SlotsContainer

# 确认对话框控件
@onready var confirm_dialog = $ConfirmDialog
@onready var confirm_text = $ConfirmDialog/Margin/VBox/ConfirmText
@onready var btn_confirm_ok = $ConfirmDialog/Margin/VBox/BtnHBox/BtnOk
@onready var btn_confirm_cancel = $ConfirmDialog/Margin/VBox/BtnHBox/BtnCancel

var pending_action: Callable

func _ready() -> void:
	visible = false
	btn_close.pressed.connect(close)
	confirm_dialog.visible = false
	btn_confirm_cancel.pressed.connect(func(): confirm_dialog.visible = false)
	btn_confirm_ok.pressed.connect(_on_confirm_ok)

func open(mode: Mode, world_node: Node2D = null) -> void:
	current_mode = mode
	world_ref = world_node
	visible = true
	confirm_dialog.visible = false
	
	if current_mode == Mode.SAVE:
		title_label.text = "💾 档案库管理器 -【保存游戏进度】"
	else:
		title_label.text = "📂 档案库管理器 -【读取历史进度】"
		
	refresh_slots()

func close() -> void:
	visible = false
	confirm_dialog.visible = false
	modal_closed.emit()

func refresh_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
		
	var all_slots = SaveManager.get_all_slots()
	for slot_meta in all_slots:
		# 在保存模式下，不建议手动覆盖系统自动存档 (auto)
		if current_mode == Mode.SAVE and slot_meta["slot_id"] == "auto":
			continue
			
		var card = _create_slot_card(slot_meta)
		slots_container.add_child(card)

func _create_slot_card(meta: Dictionary) -> PanelContainer:
	var slot_id: String = meta["slot_id"]
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 75)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)
	
	# 左侧信息区
	var info_box = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 4)
	hbox.add_child(info_box)
	
	var header_hbox = HBoxContainer.new()
	info_box.add_child(header_hbox)
	
	var name_lbl = Label.new()
	name_lbl.text = meta["slot_name"]
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	name_lbl.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(name_lbl)
	
	if meta["exists"]:
		var dt_lbl = Label.new()
		dt_lbl.text = " | 🕒 %s (游玩 %s)" % [meta["datetime"], meta["playtime_formatted"]]
		dt_lbl.add_theme_font_size_override("font_size", 12)
		dt_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		header_hbox.add_child(dt_lbl)
		
		var detail_lbl = Label.new()
		detail_lbl.text = "🏛️ %s  |  🌟 元素: %d/118  |  🚩 领地: 半径 %d格  |  🎒 物资: %d种" % [
			meta["era_name"],
			meta["elements_count"],
			meta["territory_radius"],
			meta["inventory_count"]
		]
		detail_lbl.add_theme_font_size_override("font_size", 12)
		detail_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		info_box.add_child(detail_lbl)
	else:
		var empty_lbl = Label.new()
		empty_lbl.text = "【空白归档槽位】暂无记录"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		info_box.add_child(empty_lbl)
		
	# 右侧操作按钮区
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 8)
	hbox.add_child(btn_box)
	
	if current_mode == Mode.SAVE:
		var btn_save = Button.new()
		btn_save.custom_minimum_size = Vector2(100, 36)
		if meta["exists"]:
			btn_save.text = "💾 覆盖保存"
			btn_save.pressed.connect(func(): _prompt_overwrite(slot_id, meta["slot_name"]))
		else:
			btn_save.text = "💾 保存此槽"
			btn_save.pressed.connect(func(): _execute_save(slot_id))
		btn_box.add_child(btn_save)
	else: # LOAD 模式
		var btn_load = Button.new()
		btn_load.custom_minimum_size = Vector2(90, 36)
		btn_load.text = "▶️ 载入进度"
		btn_load.disabled = not meta["exists"]
		if meta["exists"]:
			btn_load.pressed.connect(func(): _prompt_load(slot_id, meta["slot_name"]))
		btn_box.add_child(btn_load)
		
		# 自动存档不允许手动删除
		if meta["exists"] and not meta.get("is_auto", false):
			var btn_del = Button.new()
			btn_del.custom_minimum_size = Vector2(70, 36)
			btn_del.text = "🗑️ 删除"
			btn_del.pressed.connect(func(): _prompt_delete(slot_id, meta["slot_name"]))
			btn_box.add_child(btn_del)
			
	return card

func _prompt_overwrite(slot_id: String, slot_name: String) -> void:
	confirm_text.text = "⚠️ 确认覆盖【%s】吗？\n原有的存档数据将被永久替换。" % slot_name
	pending_action = func(): _execute_save(slot_id)
	confirm_dialog.visible = true

func _prompt_load(slot_id: String, slot_name: String) -> void:
	confirm_text.text = "📂 确认载入【%s】吗？\n未保存的当前游戏进度将会丢失。" % slot_name
	pending_action = func(): _execute_load(slot_id)
	confirm_dialog.visible = true

func _prompt_delete(slot_id: String, slot_name: String) -> void:
	confirm_text.text = "🗑️ 确认彻底删除【%s】吗？\n该操作无法撤销！" % slot_name
	pending_action = func():
		SaveManager.delete_slot(slot_id)
		GameState.post_notice("🗑️ 已清空【%s】存档！" % slot_name, Color.GRAY)
		refresh_slots()
	confirm_dialog.visible = true

func _on_confirm_ok() -> void:
	confirm_dialog.visible = false
	if pending_action.is_valid():
		pending_action.call()
		pending_action = Callable()

func _execute_save(slot_id: String) -> void:
	var success = SaveManager.save_to_slot(slot_id, world_ref)
	if success:
		refresh_slots()
		slot_selected.emit(slot_id, current_mode)

func _execute_load(slot_id: String) -> void:
	slot_selected.emit(slot_id, current_mode)
	if world_ref != null:
		SaveManager.load_from_slot(slot_id, world_ref)
		close()
