# theme_styler.gd
# 维多利亚复古科学与工业黑金 UI 样式构建器
class_name ThemeStyler
extends RefCounted

static func create_scientific_theme() -> Theme:
	var theme = Theme.new()
	
	# 1. 面板容器样式 (PanelContainer)
	var panel_box = StyleBoxFlat.new()
	panel_box.bg_color = Color(0.07, 0.10, 0.15, 0.92) # 深暗墨水板岩色
	panel_box.border_color = Color(0.78, 0.58, 0.22, 1.0) # 氧化黄铜金边
	panel_box.border_width_left = 2
	panel_box.border_width_top = 2
	panel_box.border_width_right = 2
	panel_box.border_width_bottom = 2
	panel_box.corner_radius_top_left = 8
	panel_box.corner_radius_top_right = 8
	panel_box.corner_radius_bottom_left = 8
	panel_box.corner_radius_bottom_right = 8
	panel_box.shadow_color = Color(0, 0, 0, 0.45)
	panel_box.shadow_size = 6
	panel_box.content_margin_left = 12
	panel_box.content_margin_top = 10
	panel_box.content_margin_right = 12
	panel_box.content_margin_bottom = 10
	theme.set_stylebox("panel", "PanelContainer", panel_box)

	# 2. 按钮样式 (Button Normal)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.11, 0.16, 0.22, 0.95)
	btn_normal.border_color = Color(0.55, 0.40, 0.20, 0.9)
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

	# 按钮样式 (Button Hover)
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.16, 0.24, 0.34, 1.0)
	btn_hover.border_color = Color(1.0, 0.82, 0.35, 1.0) # 耀金边框
	btn_hover.border_width_left = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_bottom = 2
	theme.set_stylebox("hover", "Button", btn_hover)

	# 按钮样式 (Button Pressed)
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.06, 0.09, 0.13, 1.0)
	btn_pressed.border_color = Color(0.9, 0.7, 0.25, 1.0)
	theme.set_stylebox("pressed", "Button", btn_pressed)

	# 3. 文字颜色规范
	theme.set_color("font_color", "Button", Color(0.92, 0.92, 0.95))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.55))
	theme.set_color("font_color", "Label", Color(0.90, 0.92, 0.95))

	return theme
