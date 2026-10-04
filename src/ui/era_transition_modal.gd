# era_transition_modal.gd
# 时代演进与文明跨越庆典动画 (扁平极简，无 emoji，快捷键跳过)
extends Control

@onready var anim_panel = $Center/Panel
@onready var title_label = $Center/Panel/Margin/VBox/EraTitle
@onready var desc_label = $Center/Panel/Margin/VBox/EraDesc
@onready var btn_continue = $Center/Panel/Margin/VBox/BtnContinue

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_continue.pressed.connect(func(): visible = false)
	GameState.era_advanced.connect(_on_era_advanced)

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		visible = false
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		visible = false
		get_viewport().set_input_as_handled()

func _on_era_advanced(old_era: int, new_era: int, era_name: String) -> void:
	if new_era <= old_era or new_era == 0:
		return
	title_label.text = "文 明 纪 元 跨 越\n【%s】" % era_name
	
	var desc = ""
	if new_era == 1:
		desc = "你已经成功炼制了人类第一块金属纯铜，突破了石器蒙昧！\n冶金术的大门轰然洞开，高炉、强酸与合金时代降临！"
	elif new_era == 2:
		desc = "你确证了质量守恒与高炉炼铁工业！\n近代连续流化工厂、玻璃导管与工业蓝图体系全面觉醒！"
	elif new_era == 3:
		desc = "伏打电堆与法拉第电解定律点亮了世界！\n活泼金属与纯氧纯氢的电化学时代正式开启！"
	else:
		desc = "人类科学力量迈向了深层物质与高能物理学新纪元！"
	desc_label.text = desc
	
	visible = true
	btn_continue.grab_focus()
	
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
