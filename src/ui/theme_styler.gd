# theme_styler.gd
# 方案三：现代科学信息图 · 极简冷灰几何风 (Modern Scientific Minimalist & Infographic)
class_name ThemeStyler
extends RefCounted

# 基础色板：深海夜蓝与冷灰几何基调
const COLOR_BG = Color(0.055, 0.075, 0.115, 0.90)       # #0E131D 深海夜蓝磨砂
const COLOR_BG_SOLID = Color(0.065, 0.090, 0.135, 1.0) # #111722 纯色深底
const COLOR_CARD = Color(0.085, 0.115, 0.170, 0.85)    # #161D2B 卡片与子容器背景
const COLOR_CARD_HOVER = Color(0.120, 0.165, 0.240, 0.95)

# 结构边框：1px 极细冷灰发丝线与电光青蓝激活态
const COLOR_BORDER = Color(0.19, 0.26, 0.36, 0.75)     # #30425C 1px 极细冷灰发丝线
const COLOR_BORDER_HOVER = Color(0.28, 0.40, 0.58, 0.9)
const COLOR_BORDER_FOCUS = Color(0.22, 0.74, 0.97, 0.9) # #38BDF8 电光青蓝辉光

# 文字与信息层级
const COLOR_TEXT_PRIMARY = Color(0.96, 0.97, 0.98, 1.0)   # #F5F7FA 主信息与数值
const COLOR_TEXT_SECONDARY = Color(0.58, 0.65, 0.75, 1.0) # #94A6BF 辅助说明与标签
const COLOR_TEXT_MUTED = Color(0.38, 0.44, 0.54, 1.0)     # #61708A 弱化注释与空状态

# 科技主题强调色
const COLOR_ACCENT = Color(0.22, 0.74, 0.97, 1.0)        # #38BDF8 现代科学电光青
const COLOR_ACCENT_HOVER = Color(0.35, 0.82, 1.0, 1.0)  # #59D1FF
const COLOR_ACCENT_PRESSED = Color(0.15, 0.60, 0.80, 1.0)
const COLOR_WARNING = Color(0.96, 0.62, 0.04, 1.0)       # #F59E0B 琥珀橙 (警示/待突破)
const COLOR_SUCCESS = Color(0.10, 0.75, 0.55, 1.0)       # #1AE08C 翡翠绿 (已完成/产物)
const COLOR_DANGER = Color(0.95, 0.28, 0.38, 1.0)        # #F43F5E 晶红 (取消/危险)

static func create_scientific_theme() -> Theme:
	var theme = Theme.new()
	
	# 1. 面板容器样式 (PanelContainer) - 现代浮动卡片
	var panel_box = StyleBoxFlat.new()
	panel_box.bg_color = COLOR_BG
	panel_box.border_color = COLOR_BORDER
	panel_box.border_width_left = 1
	panel_box.border_width_top = 1
	panel_box.border_width_right = 1
	panel_box.border_width_bottom = 1
	panel_box.corner_radius_top_left = 10
	panel_box.corner_radius_top_right = 10
	panel_box.corner_radius_bottom_left = 10
	panel_box.corner_radius_bottom_right = 10
	panel_box.content_margin_left = 14
	panel_box.content_margin_top = 14
	panel_box.content_margin_right = 14
	panel_box.content_margin_bottom = 14
	panel_box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel_box.shadow_size = 8
	panel_box.shadow_offset = Vector2(0, 3)
	theme.set_stylebox("panel", "PanelContainer", panel_box)

	# 2. 按钮样式 (Button Normal / Hover / Pressed / Focus / Disabled) - 几何扁平与青蓝微光
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.09, 0.12, 0.18, 0.9)
	btn_normal.border_color = COLOR_BORDER
	btn_normal.border_width_left = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_bottom = 1
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_left = 10
	btn_normal.content_margin_top = 6
	btn_normal.content_margin_right = 10
	btn_normal.content_margin_bottom = 6
	theme.set_stylebox("normal", "Button", btn_normal)

	# 悬停整行/按钮高亮 (青蓝发丝线)
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.13, 0.18, 0.26, 0.95)
	btn_hover.border_color = COLOR_ACCENT
	btn_hover.border_width_left = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_bottom = 1
	theme.set_stylebox("hover", "Button", btn_hover)

	# 按下样式
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.06, 0.09, 0.14, 1.0)
	btn_pressed.border_color = COLOR_ACCENT_PRESSED
	theme.set_stylebox("pressed", "Button", btn_pressed)

	# 焦点样式
	var btn_focus = btn_normal.duplicate()
	btn_focus.bg_color = Color(0.11, 0.15, 0.22, 0.95)
	btn_focus.border_color = COLOR_BORDER_FOCUS
	btn_focus.border_width_left = 1
	btn_focus.border_width_top = 1
	btn_focus.border_width_right = 1
	btn_focus.border_width_bottom = 1
	theme.set_stylebox("focus", "Button", btn_focus)

	# 禁用样式
	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.06, 0.08, 0.11, 0.4)
	btn_disabled.border_color = Color(0.14, 0.18, 0.24, 0.4)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# 3. 进度条样式 (ProgressBar) - 极简青蓝能量流
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	bar_bg.border_color = Color(0.16, 0.22, 0.30, 0.8)
	bar_bg.border_width_left = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_bottom = 1
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	theme.set_stylebox("background", "ProgressBar", bar_bg)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = COLOR_ACCENT
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	theme.set_stylebox("fill", "ProgressBar", bar_fill)

	# 4. 文字颜色与字体配置
	theme.set_color("font_color", "Label", COLOR_TEXT_PRIMARY)
	theme.set_color("font_color", "Button", COLOR_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color(0.85, 0.90, 0.95, 1.0))
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	theme.set_color("font_color", "RichTextLabel", COLOR_TEXT_PRIMARY)

	# 5. 分割线 (HSeparator / VSeparator)
	var sep_box = StyleBoxLine.new()
	sep_box.color = COLOR_BORDER
	sep_box.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep_box)
	theme.set_stylebox("separator", "VSeparator", sep_box)

	return theme

# 快速创建方案三胶囊容器样式 (Pill / Capsule Box)
static func create_pill_box(radius: int = 18, bg: Color = COLOR_BG, border: Color = COLOR_BORDER) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	return box

# 快速创建方案三悬浮卡片样式 (Card Box)
static func create_card_box(radius: int = 8, bg: Color = COLOR_CARD, border: Color = COLOR_BORDER) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box
