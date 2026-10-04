# theme_styler.gd
# 扁平极简现代战略 UI 规范构建器 (参考文明6范式)
class_name ThemeStyler
extends RefCounted

const COLOR_BG = Color(0.071, 0.078, 0.094, 0.85)       # #121418 @ 85% 不透明
const COLOR_BG_SOLID = Color(0.071, 0.078, 0.094, 1.0) # #121418 纯色
const COLOR_BORDER = Color(0.227, 0.247, 0.282, 1.0)   # #3A3F48 细描边
const COLOR_TEXT_PRIMARY = Color(0.949, 0.949, 0.941, 1.0)   # #F2F2F0 主字
const COLOR_TEXT_SECONDARY = Color(0.604, 0.620, 0.651, 1.0) # #9A9EA6 次字
const COLOR_ACCENT = Color(0.298, 0.553, 1.0, 1.0)     # #4C8DFF 经典科技强调蓝
const COLOR_ACCENT_HOVER = Color(0.38, 0.62, 1.0, 1.0)

static func create_scientific_theme() -> Theme:
	var theme = Theme.new()
	
	# 1. 面板容器样式 (PanelContainer)
	var panel_box = StyleBoxFlat.new()
	panel_box.bg_color = COLOR_BG
	panel_box.border_color = COLOR_BORDER
	panel_box.border_width_left = 1
	panel_box.border_width_top = 1
	panel_box.border_width_right = 1
	panel_box.border_width_bottom = 1
	panel_box.corner_radius_top_left = 4
	panel_box.corner_radius_top_right = 4
	panel_box.corner_radius_bottom_left = 4
	panel_box.corner_radius_bottom_right = 4
	panel_box.content_margin_left = 16
	panel_box.content_margin_top = 16
	panel_box.content_margin_right = 16
	panel_box.content_margin_bottom = 16
	theme.set_stylebox("panel", "PanelContainer", panel_box)

	# 2. 按钮样式 (Button Normal / Hover / Pressed / Focus / Disabled)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.14, 0.17, 0.9)
	btn_normal.border_color = COLOR_BORDER
	btn_normal.border_width_left = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_bottom = 1
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_left = 4
	btn_normal.corner_radius_bottom_right = 4
	btn_normal.content_margin_left = 12
	btn_normal.content_margin_top = 6
	btn_normal.content_margin_right = 12
	btn_normal.content_margin_bottom = 6
	theme.set_stylebox("normal", "Button", btn_normal)

	# 悬停整行/按钮高亮
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.18, 0.22, 0.28, 1.0)
	btn_hover.border_color = COLOR_ACCENT
	btn_hover.border_width_left = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_bottom = 1
	theme.set_stylebox("hover", "Button", btn_hover)

	# 按下样式
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.09, 0.11, 0.14, 1.0)
	btn_pressed.border_color = COLOR_ACCENT
	theme.set_stylebox("pressed", "Button", btn_pressed)

	# 焦点 2px 描边，支持键盘导航
	var btn_focus = btn_normal.duplicate()
	btn_focus.bg_color = Color(0.15, 0.19, 0.25, 0.9)
	btn_focus.border_color = COLOR_ACCENT
	btn_focus.border_width_left = 2
	btn_focus.border_width_top = 2
	btn_focus.border_width_right = 2
	btn_focus.border_width_bottom = 2
	theme.set_stylebox("focus", "Button", btn_focus)

	# 禁用样式
	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.08, 0.09, 0.11, 0.5)
	btn_disabled.border_color = Color(0.18, 0.20, 0.23, 0.5)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# 3. 进度条样式 (ProgressBar)
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.09, 0.11, 0.14, 0.9)
	bar_bg.border_color = COLOR_BORDER
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
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	theme.set_stylebox("fill", "ProgressBar", bar_fill)

	# 4. 文字颜色与字体配置
	theme.set_color("font_color", "Label", COLOR_TEXT_PRIMARY)
	theme.set_color("font_color", "Button", COLOR_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color(0.85, 0.88, 0.92, 1.0))
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.40, 0.42, 0.45, 1.0))
	theme.set_color("font_color", "RichTextLabel", COLOR_TEXT_PRIMARY)

	# 5. 分割线 (HSeparator)
	var sep_box = StyleBoxLine.new()
	sep_box.color = COLOR_BORDER
	sep_box.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep_box)
	theme.set_stylebox("separator", "VSeparator", sep_box)

	return theme
