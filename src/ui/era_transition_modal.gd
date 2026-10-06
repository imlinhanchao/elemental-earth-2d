# era_transition_modal.gd
# 文明史册与时代跃迁大典 (高级科技纪元视效 · 时代专属矢量大徽章 · 动态里程碑卡片)
extends Control

const ThemeStyler = preload("res://src/ui/theme_styler.gd")

const ERA_ICONS: Dictionary = {
	0: "res://assets/icons/era_stone.svg",
	1: "res://assets/icons/era_alchemy.svg",
	2: "res://assets/icons/era_modern_chem.svg",
	3: "res://assets/icons/era_electrochem.svg",
	4: "res://assets/icons/era_rare_earth.svg",
	5: "res://assets/icons/era_atomic_age.svg",
	6: "res://assets/icons/era_future.svg"
}

const ERA_ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII"]

const ERA_THEME_COLORS: Dictionary = {
	0: Color(0.96, 0.62, 0.04), # 琥珀金 (石器)
	1: Color(0.95, 0.35, 0.15), # 烈焰赤 (炼金)
	2: Color(0.08, 0.75, 0.55), # 翡翠青 (近代化学)
	3: Color(0.12, 0.65, 0.95), # 电光蓝 (电化学)
	4: Color(0.72, 0.40, 0.98), # 紫晶辉 (稀土)
	5: Color(0.60, 0.45, 0.98), # 裂变紫 (原子能)
	6: Color(0.15, 0.85, 0.95)  # 量子青 (未来)
}

const ERA_TAGS: Dictionary = {
	0: "原始物质改造与燧石工具",
	1: "窑炉冶炼、强酸与合金创制",
	2: "气体收集、定量称量与连续流化工厂",
	3: "伏打电堆、法拉第定律与活泼金属电解",
	4: "镧系元素精密萃取与催化裂化新材料",
	5: "同位素嬗变、质能方程与核能微观深空",
	6: "聚变能源与星际化学新纪元"
}

@onready var panel = $Center/Panel
@onready var header_title = $Center/Panel/Margin/MainVBox/HeaderHBox/HeaderTitle
@onready var btn_close = $Center/Panel/Margin/MainVBox/HeaderHBox/BtnClose
@onready var emblem_container = $Center/Panel/Margin/MainVBox/HeroPanel/HeroMargin/HeroHBox/EmblemContainer
@onready var emblem_icon = $Center/Panel/Margin/MainVBox/HeroPanel/HeroMargin/HeroHBox/EmblemContainer/EmblemIcon
@onready var era_order_tag = $Center/Panel/Margin/MainVBox/HeroPanel/HeroMargin/HeroHBox/HeroVBox/EraOrderTag
@onready var era_name_label = $Center/Panel/Margin/MainVBox/HeroPanel/HeroMargin/HeroHBox/HeroVBox/EraNameLabel
@onready var era_desc_label = $Center/Panel/Margin/MainVBox/HeroPanel/HeroMargin/HeroHBox/HeroVBox/EraDescLabel
@onready var territory_badge = $Center/Panel/Margin/MainVBox/TelemetryHBox/TerritoryBadge
@onready var territory_label = $Center/Panel/Margin/MainVBox/TelemetryHBox/TerritoryBadge/Margin/TerritoryLabel
@onready var elements_badge = $Center/Panel/Margin/MainVBox/TelemetryHBox/ElementsBadge
@onready var elements_label = $Center/Panel/Margin/MainVBox/TelemetryHBox/ElementsBadge/Margin/ElementsLabel
@onready var progress_percent = $Center/Panel/Margin/MainVBox/TelemetryHBox/ProgressVBox/ProgressHeaderHBox/ProgressPercent
@onready var progress_bar = $Center/Panel/Margin/MainVBox/TelemetryHBox/ProgressVBox/ProgressBar
@onready var section_title = $Center/Panel/Margin/MainVBox/MilestonesSection/SectionTitle
@onready var milestones_list = $Center/Panel/Margin/MainVBox/MilestonesSection/ScrollContainer/MilestonesList
@onready var btn_continue = $Center/Panel/Margin/MainVBox/FooterHBox/BtnContinue

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_visual_styling()
	
	btn_close.pressed.connect(func(): visible = false)
	btn_continue.pressed.connect(func(): visible = false)
	GameState.era_advanced.connect(_on_era_advanced)
	GameState.milestone_completed.connect(_on_milestone_completed)

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

func _apply_visual_styling() -> void:
	# 1. 核心大面板深空微光卡片
	var main_box = StyleBoxFlat.new()
	main_box.bg_color = ThemeStyler.COLOR_BG
	main_box.border_color = Color(0.22, 0.55, 0.85, 0.8)
	main_box.border_width_left = 1
	main_box.border_width_top = 1
	main_box.border_width_right = 1
	main_box.border_width_bottom = 1
	main_box.corner_radius_top_left = 20
	main_box.corner_radius_top_right = 20
	main_box.corner_radius_bottom_left = 20
	main_box.corner_radius_bottom_right = 20
	main_box.shadow_color = Color(0, 0, 0, 0.6)
	main_box.shadow_size = 24
	panel.add_theme_stylebox_override("panel", main_box)
	
	# 2. Hero 展区深冷玻璃卡
	var hero_box = StyleBoxFlat.new()
	hero_box.bg_color = ThemeStyler.COLOR_CARD
	hero_box.border_color = Color(0.25, 0.48, 0.75, 0.5)
	hero_box.border_width_left = 1
	hero_box.border_width_top = 1
	hero_box.border_width_right = 1
	hero_box.border_width_bottom = 1
	hero_box.corner_radius_top_left = 14
	hero_box.corner_radius_top_right = 14
	hero_box.corner_radius_bottom_left = 14
	hero_box.corner_radius_bottom_right = 14
	$Center/Panel/Margin/MainVBox/HeroPanel.add_theme_stylebox_override("panel", hero_box)
	
	# 3. 关闭按钮极简胶囊
	var close_box = StyleBoxFlat.new()
	close_box.bg_color = Color(0.14, 0.20, 0.32, 0.6)
	close_box.border_color = Color(0.35, 0.50, 0.70, 0.5)
	close_box.border_width_left = 1
	close_box.border_width_top = 1
	close_box.border_width_right = 1
	close_box.border_width_bottom = 1
	close_box.corner_radius_top_left = 13
	close_box.corner_radius_top_right = 13
	close_box.corner_radius_bottom_left = 13
	close_box.corner_radius_bottom_right = 13
	btn_close.add_theme_stylebox_override("normal", close_box)
	btn_close.add_theme_color_override("font_color", Color(0.70, 0.82, 0.95))
	
	# 4. 指标胶囊外观
	var kpi_box = StyleBoxFlat.new()
	kpi_box.bg_color = Color(0.16, 0.15, 0.13, 0.7)
	kpi_box.border_color = Color(0.20, 0.40, 0.65, 0.45)
	kpi_box.border_width_left = 1
	kpi_box.border_width_top = 1
	kpi_box.border_width_right = 1
	kpi_box.border_width_bottom = 1
	kpi_box.corner_radius_top_left = 12
	kpi_box.corner_radius_top_right = 12
	kpi_box.corner_radius_bottom_left = 12
	kpi_box.corner_radius_bottom_right = 12
	territory_badge.add_theme_stylebox_override("panel", kpi_box)
	elements_badge.add_theme_stylebox_override("panel", kpi_box.duplicate())
	
	# 5. 进度条质感
	var prog_bg = StyleBoxFlat.new()
	prog_bg.bg_color = ThemeStyler.COLOR_BG_SOLID
	prog_bg.corner_radius_top_left = 4
	prog_bg.corner_radius_top_right = 4
	prog_bg.corner_radius_bottom_left = 4
	prog_bg.corner_radius_bottom_right = 4
	progress_bar.add_theme_stylebox_override("background", prog_bg)
	
	var prog_fill = StyleBoxFlat.new()
	prog_fill.bg_color = ThemeStyler.COLOR_ACCENT
	prog_fill.corner_radius_top_left = 4
	prog_fill.corner_radius_top_right = 4
	prog_fill.corner_radius_bottom_left = 4
	prog_fill.corner_radius_bottom_right = 4
	progress_bar.add_theme_stylebox_override("fill", prog_fill)
	
	# 6. 继续/确认按钮质感
	var btn_box = StyleBoxFlat.new()
	btn_box.bg_color = Color(0.18, 0.45, 0.78, 0.9)
	btn_box.border_color = Color(0.35, 0.75, 1.0, 0.95)
	btn_box.border_width_left = 1
	btn_box.border_width_top = 1
	btn_box.border_width_right = 1
	btn_box.border_width_bottom = 1
	btn_box.corner_radius_top_left = 16
	btn_box.corner_radius_top_right = 16
	btn_box.corner_radius_bottom_left = 16
	btn_box.corner_radius_bottom_right = 16
	btn_continue.add_theme_stylebox_override("normal", btn_box)
	btn_continue.add_theme_color_override("font_color", Color.WHITE)

# 动态加载时代专属大徽章图标
func _load_era_emblem(era_order: int) -> Texture2D:
	var path = ERA_ICONS.get(era_order, "res://assets/icons/era.svg")
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var svg_text = file.get_as_text()
			file.close()
			var img = Image.new()
			if img.load_svg_from_string(svg_text, 3.0) == OK:
				return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		return load(path)
	return null

# 查看当前时代进程面板
func show_current_era_status() -> void:
	var cur_era = GameState.current_era
	_render_era_view(cur_era, false)

var pending_era_celebration: int = -1

# 时代升级庆典触发
func _on_era_advanced(old_era: int, new_era: int, _era_name: String) -> void:
	if new_era <= old_era or new_era == 0:
		return
	var hud = get_parent()
	if hud and "element_discovery_modal" in hud and hud.element_discovery_modal and hud.element_discovery_modal.visible:
		pending_era_celebration = new_era
		return
	_render_era_view(new_era, true)

func on_element_discovery_closed() -> void:
	if pending_era_celebration > 0:
		var target_era = pending_era_celebration
		pending_era_celebration = -1
		_render_era_view(target_era, true)

func _on_milestone_completed(_key: String) -> void:
	if visible and pending_era_celebration < 0:
		show_current_era_status()

func _render_era_view(era_order: int, is_celebration: bool) -> void:
	var era_def = DataDB.get_era(era_order)
	var era_name = str(era_def.get("name", "石器时代")).split(" (")[0]
	var era_desc = str(era_def.get("description", ""))
	var milestones = era_def.get("milestones", [])
	var accent_color = ERA_THEME_COLORS.get(era_order, ThemeStyler.COLOR_ACCENT)
	var roman_num = ERA_ROMAN[clamp(era_order, 0, ERA_ROMAN.size() - 1)]
	
	# 1. 顶栏标题与标识
	if is_celebration:
		header_title.text = "文明纪元跃迁"
		header_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		btn_continue.text = "迈向新纪元 [ENTER]"
	else:
		header_title.text = "文明纪元史册"
		header_title.add_theme_color_override("font_color", ThemeStyler.COLOR_ACCENT)
		btn_continue.text = "返回大世界 [ESC]"
	
	# 2. 时代专属发光大徽章
	var emblem_tex = _load_era_emblem(era_order)
	if emblem_tex:
		emblem_icon.texture = emblem_tex
	
	# 徽章容器边框按时代主色调发光
	var emblem_box = StyleBoxFlat.new()
	emblem_box.bg_color = ThemeStyler.COLOR_CARD_HOVER
	emblem_box.border_color = accent_color
	emblem_box.border_width_left = 2
	emblem_box.border_width_top = 2
	emblem_box.border_width_right = 2
	emblem_box.border_width_bottom = 2
	emblem_box.corner_radius_top_left = 16
	emblem_box.corner_radius_top_right = 16
	emblem_box.corner_radius_bottom_left = 16
	emblem_box.corner_radius_bottom_right = 16
	emblem_box.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.4)
	emblem_box.shadow_size = 12
	emblem_container.add_theme_stylebox_override("panel", emblem_box)
	
	# 3. 时代名称与描述
	era_order_tag.text = "第 %s 纪元 · %s" % [roman_num, ERA_TAGS.get(era_order, "科学演进时代")]
	era_order_tag.add_theme_color_override("font_color", accent_color)
	
	era_name_label.text = "【%s】 %s" % [era_name, era_def.get("key", "").capitalize()]
	era_name_label.add_theme_color_override("font_color", Color.WHITE)
	
	era_desc_label.text = era_desc
	
	# 4. 核心宏观指标
	var terr_radius = GameState.get_current_territory_radius()
	var terr_count = (3 * terr_radius * (terr_radius + 1) + 1)
	territory_label.text = "领地半径: %d 瓦片 (%d 格已拓荒)" % [terr_radius, terr_count]
	elements_label.text = "点亮元素: %d / 118 种" % GameState.discovered_elements.size()
	
	# 5. 里程碑完成度计算
	var total_ms = milestones.size()
	var done_ms = 0
	for m in milestones:
		if GameState.completed_milestones.has(str(m.get("key", ""))):
			done_ms += 1
	
	var pct = 100 if total_ms == 0 else int(float(done_ms) / float(total_ms) * 100.0)
	if total_ms > 0:
		progress_percent.text = "%d%% (%d/%d)" % [pct, done_ms, total_ms]
	else:
		progress_percent.text = "探明更高级矿物中"
	progress_bar.value = pct
	
	# 6. 里程碑卡片清单生成
	for child in milestones_list.get_children():
		child.queue_free()
	
	if milestones.size() > 0:
		section_title.text = "【时代跃迁关键里程碑】 (达成全部目标后即可迈向新纪元)"
		for m in milestones:
			var m_k = str(m.get("key", ""))
			var m_desc = str(m.get("description", m_k))
			var is_done = GameState.completed_milestones.has(m_k)
			var card = _create_milestone_card(m_k, m_desc, is_done, accent_color)
			milestones_list.add_child(card)
	else:
		section_title.text = "【时代宏观演进要求】"
		var card = _create_milestone_card("explore_deep", "深入拓荒大世界群落，在微观实验台突破新反应以晋阶下一纪元！", false, accent_color)
		milestones_list.add_child(card)
	
	visible = true
	btn_continue.grab_focus()
	
	# 渐入动效
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# 方案 4: 时代纪元里程碑科研攻关指南与大世界探索线索
const MILESTONE_GUIDES: Dictionary = {
	"craft_stone_pickaxe": {
		"title": "制作第一把石镐",
		"guide": "在碎石地表开采【碎石】与干燥【枯树枝】，按 [T] 打开制作台打磨装配出原始石镐。装备后可开采深层坚硬矿物。",
		"field": "碎石平原、荒野林带",
		"route": "制作栏 [T] ➔ 原始石镐"
	},
	"craft_fire_seed": {
		"title": "制作第一个火种",
		"guide": "开采深黑色贝壳状【燧石】与【枯树枝】，按 [T] 打开制作台击石引火制作文明火种。火种是后续一切冶炼与加热的核心！",
		"field": "火山边缘、碎石滩涂",
		"route": "制作栏 [T] ➔ 燧石火种"
	},
	"build_kiln": {
		"title": "建造第一个窑炉",
		"guide": "在湿润滩涂采集高岭土与黏土，配合坚实石块，按 [C] 在建造坞筑造耐受千度高温的高大窑炉，开启大宗冶金时代。",
		"field": "湿地泥沼、高岭土矿脉",
		"route": "建造坞 [C] ➔ 土法窑炉"
	},
	"first_smelt": {
		"title": "完成第一次焙烧",
		"guide": "在微观实验台 [L] 或熔炉中，投入孔雀石与木炭，点燃酒精喷灯持续加温至 600℃ 以上固相还原出第一块金属铜！",
		"field": "东部火山群系、林地干馏木炭",
		"route": "实验台 [L] 或 熔炉 ➔ 固相热还原"
	},
	"research_pottery": {
		"title": "研究陶器制作科技",
		"guide": "按 [K] 打开科技树研习火与土的转化之道，掌握耐火陶罐烧制。陶器容器可耐受酸碱腐蚀并承载液体实验。",
		"field": "科技树 [K]",
		"route": "科技树 [K] ➔ 陶器制作"
	}
}

# 构建单个里程碑高质感横向卡片
func _create_milestone_card(key: String, desc: String, is_done: bool, accent: Color) -> PanelContainer:
	var p = PanelContainer.new()
	var box = StyleBoxFlat.new()
	if is_done:
		box.bg_color = Color(0.12, 0.16, 0.11, 0.85) # 达成后柔和苔绿
		box.border_color = Color(0.15, 0.65, 0.45, 0.8)
	else:
		box.bg_color = ThemeStyler.COLOR_CARD # 进行中暖墨
		box.border_color = Color(0.25, 0.45, 0.68, 0.6)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	p.add_theme_stylebox_override("panel", box)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	p.add_child(margin)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(card_vbox)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card_vbox.add_child(hbox)
	
	# 状态图标
	var mark = Label.new()
	mark.text = "✓" if is_done else "○"
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_theme_font_size_override("font_size", 14)
	mark.add_theme_color_override("font_color", ThemeStyler.COLOR_SUCCESS if is_done else ThemeStyler.COLOR_TEXT_SECONDARY)
	hbox.add_child(mark)
	
	# 里程碑描述
	var lbl_desc = Label.new()
	lbl_desc.text = desc
	lbl_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_desc.add_theme_font_size_override("font_size", 13)
	lbl_desc.add_theme_color_override("font_color", ThemeStyler.COLOR_TEXT_PRIMARY if is_done else ThemeStyler.COLOR_TEXT_SECONDARY)
	hbox.add_child(lbl_desc)
	
	# 右侧状态胶囊标签
	var tag = Label.new()
	tag.text = "[已确证达成]" if is_done else "[待科研攻关]"
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color(0.30, 0.95, 0.65) if is_done else accent)
	hbox.add_child(tag)
	
	# 方案 4: 注入科研攻关详细指引卡片
	if MILESTONE_GUIDES.has(key):
		var g_info = MILESTONE_GUIDES[key]
		var guide_panel = PanelContainer.new()
		var g_style = StyleBoxFlat.new()
		g_style.bg_color = Color(0.10, 0.09, 0.08, 0.7)
		g_style.border_color = Color(accent.r * 0.4, accent.g * 0.4, accent.b * 0.4, 0.5)
		g_style.border_width_left = 2
		g_style.corner_radius_top_left = 4
		g_style.corner_radius_bottom_left = 4
		g_style.content_margin_left = 10
		g_style.content_margin_top = 6
		g_style.content_margin_right = 10
		g_style.content_margin_bottom = 6
		guide_panel.add_theme_stylebox_override("panel", g_style)
		
		var g_vbox = VBoxContainer.new()
		g_vbox.add_theme_constant_override("separation", 3)
		guide_panel.add_child(g_vbox)
		
		var lbl_guide = Label.new()
		lbl_guide.text = "攻关指引：" + str(g_info.get("guide", ""))
		lbl_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_guide.add_theme_font_size_override("font_size", 12)
		lbl_guide.add_theme_color_override("font_color", Color(0.40, 0.90, 0.65) if is_done else Color(0.95, 0.80, 0.45))
		g_vbox.add_child(lbl_guide)
		
		var lbl_meta = Label.new()
		lbl_meta.text = "建议探索：%s   ·   关键途径：%s" % [g_info.get("field", ""), g_info.get("route", "")]
		lbl_meta.add_theme_font_size_override("font_size", 12)
		lbl_meta.add_theme_color_override("font_color", Color(0.40, 0.75, 0.95))
		g_vbox.add_child(lbl_meta)
		
		card_vbox.add_child(guide_panel)
	
	return p
