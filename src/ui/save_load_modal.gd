# save_load_modal.gd
# 业界标准多槽位存档与读档交互面板 (扁平极简，无 emoji，ESC/右键返回)
class_name SaveLoadModal
extends Control

const SaveManager = preload("res://src/core/save_manager.gd")

signal slot_selected(slot_id: String, mode: int)
signal modal_closed

enum Mode {
	SAVE,
	LOAD
}

var current_mode: Mode = Mode.LOAD
var world_ref: Node2D = null

@onready var title_label = $CenterPanel/VBox/Header/HBox/TitleLabel
@onready var btn_close = $CenterPanel/VBox/Header/HBox/BtnClose
@onready var slots_container = $CenterPanel/VBox/Body/Scroll/SlotsContainer

# 确认对话框控件
@onready var confirm_dialog = $ConfirmDialog
@onready var confirm_text = $ConfirmDialog/Margin/VBox/ConfirmText
@onready var btn_confirm_ok = $ConfirmDialog/Margin/VBox/BtnHBox/BtnOk
@onready var btn_confirm_cancel = $ConfirmDialog/Margin/VBox/BtnHBox/BtnCancel

var pending_action: Callable

func _ready() -> void:
	ModalStack.track(self)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		title_label.text = "保存游戏"
	else:
		title_label.text = "载入游戏"
		
	refresh_slots()
	btn_close.grab_focus()

func close() -> void:
	visible = false
	confirm_dialog.visible = false
	modal_closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or not ModalStack.is_top(self):
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if confirm_dialog.visible:
			confirm_dialog.visible = false
		else:
			close()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if confirm_dialog.visible:
				confirm_dialog.visible = false
			else:
				close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and confirm_dialog.visible:
			_on_confirm_ok()
			get_viewport().set_input_as_handled()

func refresh_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
		
	var all_slots = SaveManager.get_all_slots()
	for slot_meta in all_slots:
		if current_mode == Mode.SAVE and slot_meta["slot_id"] == "auto":
			continue
			
		var card = _create_slot_card(slot_meta)
		slots_container.add_child(card)

func _create_slot_card(meta: Dictionary) -> PanelContainer:
	var slot_id: String = meta["slot_id"]
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
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
	name_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY)
	name_lbl.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(name_lbl)
	
	if meta["exists"]:
		var dt_lbl = Label.new()
		dt_lbl.text = "   保存时间: %s" % meta["timestamp"]
		dt_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		dt_lbl.add_theme_font_size_override("font_size", 12)
		header_hbox.add_child(dt_lbl)
		
		var sub_lbl = Label.new()
		sub_lbl.text = "%s · 已发现元素 %d" % [
			meta.get("era_name", "未知时代"),
			meta.get("discovered_elements_count", 0)
		]
		sub_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		sub_lbl.add_theme_font_size_override("font_size", 12)
		info_box.add_child(sub_lbl)
	else:
		var empty_lbl = Label.new()
		empty_lbl.text = "空存档位"
		empty_lbl.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_SECONDARY)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		info_box.add_child(empty_lbl)
		
	# 右侧操作按钮区
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 10)
	hbox.add_child(btn_box)
	
	if current_mode == Mode.SAVE:
		var btn_save = Button.new()
		btn_save.text = "保存到此处" if meta["exists"] else "存入此槽"
		btn_save.custom_minimum_size = Vector2(90, 36)
		btn_save.pressed.connect(func(): _prompt_save_action(slot_id, meta["exists"]))
		btn_box.add_child(btn_save)
	else:
		var btn_load = Button.new()
		btn_load.text = "载入"
		btn_load.custom_minimum_size = Vector2(90, 36)
		btn_load.disabled = not meta["exists"]
		btn_load.pressed.connect(func(): _prompt_load_action(slot_id))
		btn_box.add_child(btn_load)
		
	if meta["exists"] and slot_id != "auto":
		var btn_del = Button.new()
		btn_del.text = "删除"
		btn_del.custom_minimum_size = Vector2(60, 36)
		btn_del.pressed.connect(func(): _prompt_delete_action(slot_id))
		btn_box.add_child(btn_del)
		
	return card

func _prompt_save_action(slot_id: String, exists: bool) -> void:
	if exists:
		confirm_text.text = "%s已有存档，确定覆盖吗？" % slot_id
		pending_action = func(): _execute_save(slot_id)
		confirm_dialog.visible = true
		btn_confirm_ok.grab_focus()
	else:
		_execute_save(slot_id)

func _execute_save(slot_id: String) -> void:
	var success = false
	if world_ref and world_ref.has_method("save_game_state_to_slot"):
		success = world_ref.save_game_state_to_slot(slot_id)
	else:
		success = SaveManager.save_to_slot(slot_id, world_ref)
		
	if success:
		GameState.post_notification("已保存到%s" % slot_id, ThemeStyler.COLOR_ACCENT)
		refresh_slots()
		close()

func _prompt_load_action(slot_id: String) -> void:
	confirm_text.text = "载入%s？未保存的进度会丢失。" % slot_id
	pending_action = func(): _execute_load(slot_id)
	confirm_dialog.visible = true
	btn_confirm_ok.grab_focus()

func _execute_load(slot_id: String) -> void:
	slot_selected.emit(slot_id, int(current_mode))
	close()

func _prompt_delete_action(slot_id: String) -> void:
	confirm_text.text = "删除%s？删除后无法恢复。" % slot_id
	pending_action = func():
		SaveManager.delete_slot(slot_id)
		refresh_slots()
	confirm_dialog.visible = true
	btn_confirm_ok.grab_focus()

func _on_confirm_ok() -> void:
	confirm_dialog.visible = false
	if pending_action.is_valid():
		pending_action.call()
