# theme_styler.gd
# 美术方向：「地质测绘图 × 实验手稿」(Survey Map & Lab Notebook)
# 全局统一浅色纸面：大世界测绘图、HUD、模态弹窗、主菜单都使用米白纸 + 墨色文字，
# 避免玩家在浅色地图与深色弹窗之间反复切换明暗。强调色随文明时代演进 (get_era_accent)。
class_name ThemeStyler
extends RefCounted

# 纸面底色 (模态弹窗与浮层)
const COLOR_BG = Color(0.957, 0.937, 0.898, 0.98)       # #F4EFE5 米白纸
const COLOR_BG_SOLID = Color(0.976, 0.961, 0.929, 1.0)  # #F9F5ED 提示框 / 输入底
const COLOR_CARD = Color(0.922, 0.894, 0.839, 0.95)     # #EBE4D6 二级卡片 (稍深纸)
const COLOR_CARD_HOVER = Color(0.886, 0.851, 0.780, 1.0) # #E2D9C7

# 细线框 (铅笔线)
const COLOR_BORDER = Color(0.76, 0.71, 0.64, 0.9)       # #C2B5A3
const COLOR_BORDER_HOVER = Color(0.60, 0.55, 0.48, 0.95)
const COLOR_BORDER_FOCUS = Color(0.69, 0.41, 0.16, 0.95) # #B0692A 铜色焦点

# 文字层级 (纸面上)
const COLOR_TEXT_PRIMARY = Color(0.15, 0.14, 0.13, 1.0)   # #262421 墨色
const COLOR_TEXT_SECONDARY = Color(0.37, 0.34, 0.30, 1.0) # #5E574C
const COLOR_TEXT_MUTED = Color(0.54, 0.50, 0.44, 1.0)     # #8A7F70
const COLOR_TEXT_ON_ACCENT = Color(0.99, 0.97, 0.93, 1.0) # 强调色实底按钮上的文字

# 功能色 (已加深，保证在纸面上的文字对比度)
const COLOR_ACCENT = Color(0.69, 0.41, 0.16, 1.0)        # #B0692A 铜赭
const COLOR_ACCENT_HOVER = Color(0.78, 0.49, 0.22, 1.0)
const COLOR_ACCENT_PRESSED = Color(0.56, 0.32, 0.12, 1.0)
const COLOR_WARNING = Color(0.69, 0.49, 0.06, 1.0)       # #B07D10 赭黄
const COLOR_SUCCESS = Color(0.25, 0.50, 0.27, 1.0)       # #408045 苔绿
const COLOR_DANGER = Color(0.70, 0.23, 0.18, 1.0)        # #B33B2E 朱砂
const COLOR_INFO = Color(0.20, 0.40, 0.58, 1.0)          # #336694 靛蓝

# 功能色浅底 (状态卡片背景)
const TINT_SUCCESS = Color(0.86, 0.91, 0.84, 1.0)
const TINT_WARNING = Color(0.96, 0.91, 0.78, 1.0)
const TINT_DANGER = Color(0.96, 0.86, 0.83, 1.0)
const TINT_INFO = Color(0.85, 0.90, 0.94, 1.0)

# 浮层阴影与遮罩 (暖墨，低不透明度)
const COLOR_SHADOW = Color(0.25, 0.20, 0.12, 0.20)
const COLOR_BACKDROP = Color(0.20, 0.17, 0.13, 0.35)

# 纸面 (HUD 顶栏/底栏 · 浅色表面)
const PAPER_BG = Color(0.957, 0.937, 0.898, 0.97)        # #F4EFE5 米白纸
const PAPER_BG_HOVER = Color(0.918, 0.890, 0.835, 1.0)
const PAPER_BORDER = Color(0.72, 0.67, 0.59, 0.9)        # #B8AB96 铅笔线
const PAPER_INK = Color(0.15, 0.14, 0.13, 1.0)           # #262421 墨色正文
const PAPER_INK_SOFT = Color(0.40, 0.37, 0.33, 1.0)      # #665E54 次级墨色

# 时代强调色：石器赭石 → 炼金铜褐 → 近代墨绿 → 电化学钴蓝 → 稀土紫 → 原子切伦科夫蓝
const ERA_ACCENTS: Array[Color] = [
	Color(0.80, 0.52, 0.25), # 0 石器 · 赭石 #CC8540
	Color(0.72, 0.42, 0.24), # 1 炼金 · 铜褐 #B86B3D
	Color(0.20, 0.55, 0.45), # 2 近代化学 · 墨绿 #338C73
	Color(0.20, 0.42, 0.75), # 3 电化学 · 钴蓝 #336BBF
	Color(0.55, 0.36, 0.75), # 4 稀土 · 紫晶 #8C5CBF
	Color(0.10, 0.56, 0.74), # 5 原子 · 切伦科夫蓝 #1A8FBD (加深以适配纸面)
]

static func get_era_accent(era: int) -> Color:
	return ERA_ACCENTS[clampi(era, 0, ERA_ACCENTS.size() - 1)]

# 字体：Noto Sans SC 正文 + JetBrains Mono 数值
# 注意：两者均为可变字体，Noto Sans SC 的 wght 轴默认值为 100 (Thin)，
# 必须通过 FontVariation 显式指定字重，否则全局文字会以极细字重渲染而显得发虚。
const FONT_SANS_PATH = "res://assets/fonts/NotoSansSC.ttf"
const FONT_MONO_PATH = "res://assets/fonts/JetBrainsMono.ttf"
const WGHT_TAG = 2003265652 # OpenType 'wght' 轴标签
static var _font_cache: Dictionary = {}

static func _make_variation(path: String, weight: int, fallback: Font = null) -> Font:
	var key = "%s#%d" % [path, weight]
	if _font_cache.has(key):
		return _font_cache[key]
	if not ResourceLoader.exists(path):
		return null
	var fv = FontVariation.new()
	fv.base_font = load(path)
	fv.variation_opentype = {WGHT_TAG: weight}
	if fallback:
		fv.fallbacks = [fallback]
	_font_cache[key] = fv
	return fv

static func get_font_sans() -> Font:
	return _make_variation(FONT_SANS_PATH, 400)

static func get_font_sans_bold() -> Font:
	return _make_variation(FONT_SANS_PATH, 700)

static func get_font_mono() -> Font:
	# 数值字体缺字时回退到中文正文字体
	return _make_variation(FONT_MONO_PATH, 500, get_font_sans())

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
	panel_box.shadow_color = COLOR_SHADOW
	panel_box.shadow_size = 8
	panel_box.shadow_offset = Vector2(0, 3)
	theme.set_stylebox("panel", "PanelContainer", panel_box)

	# 2. 按钮样式 (Button Normal / Hover / Pressed / Focus / Disabled) - 纸面扁平按钮，悬停铜色细线
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = COLOR_CARD
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

	# 悬停高亮 (铜色细线)
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = COLOR_CARD_HOVER
	btn_hover.border_color = COLOR_ACCENT
	btn_hover.border_width_left = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_bottom = 1
	theme.set_stylebox("hover", "Button", btn_hover)

	# 按下样式
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.84, 0.79, 0.71, 1.0)
	btn_pressed.border_color = COLOR_ACCENT_PRESSED
	theme.set_stylebox("pressed", "Button", btn_pressed)

	# 焦点样式
	var btn_focus = btn_normal.duplicate()
	btn_focus.bg_color = COLOR_CARD_HOVER
	btn_focus.border_color = COLOR_BORDER_FOCUS
	btn_focus.border_width_left = 1
	btn_focus.border_width_top = 1
	btn_focus.border_width_right = 1
	btn_focus.border_width_bottom = 1
	theme.set_stylebox("focus", "Button", btn_focus)

	# 禁用样式
	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.90, 0.88, 0.84, 0.6)
	btn_disabled.border_color = Color(0.76, 0.71, 0.64, 0.5)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# 3. 进度条样式 (ProgressBar)
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = COLOR_CARD
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
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	theme.set_stylebox("fill", "ProgressBar", bar_fill)

	# 4. 文字颜色与字体配置
	theme.set_color("font_color", "Label", COLOR_TEXT_PRIMARY)
	theme.set_color("font_color", "Button", COLOR_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", COLOR_TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "Button", COLOR_TEXT_PRIMARY)
	theme.set_color("font_focus_color", "Button", COLOR_TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	theme.set_color("font_color", "RichTextLabel", COLOR_TEXT_PRIMARY)
	# RichTextLabel 实际读取 default_color (Godot 默认为白色)
	theme.set_color("default_color", "RichTextLabel", COLOR_TEXT_PRIMARY)

	# 5. 分割线 (HSeparator / VSeparator)
	var sep_box = StyleBoxLine.new()
	sep_box.color = COLOR_BORDER
	sep_box.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep_box)
	theme.set_stylebox("separator", "VSeparator", sep_box)

	# 6. 全局默认字体
	var sans = get_font_sans()
	if sans:
		theme.default_font = sans
	theme.default_font_size = 14
	# 按钮文字使用中粗字重，提升可点击元素辨识度
	var bold = get_font_sans_bold()
	if bold:
		theme.set_font("font", "Button", bold)

	# 7. 浮动提示 (TooltipPanel)
	var tip_box = create_card_box(6, COLOR_BG_SOLID, COLOR_BORDER)
	tip_box.content_margin_left = 10
	tip_box.content_margin_right = 10
	tip_box.content_margin_top = 6
	tip_box.content_margin_bottom = 6
	theme.set_stylebox("panel", "TooltipPanel", tip_box)
	theme.set_color("font_color", "TooltipLabel", COLOR_TEXT_PRIMARY)

	# 8. 下拉菜单 / 弹出菜单 / 输入框 / 滚动条 / 复选框 (默认主题为深色，需统一为纸面)
	var popup_box = create_card_box(6, COLOR_BG_SOLID, COLOR_BORDER)
	popup_box.content_margin_left = 6
	popup_box.content_margin_right = 6
	popup_box.content_margin_top = 4
	popup_box.content_margin_bottom = 4
	popup_box.shadow_color = COLOR_SHADOW
	popup_box.shadow_size = 6
	theme.set_stylebox("panel", "PopupMenu", popup_box)
	var popup_hover = create_card_box(4, COLOR_CARD_HOVER, Color(0, 0, 0, 0))
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_color", "PopupMenu", COLOR_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "PopupMenu", COLOR_TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "PopupMenu", COLOR_TEXT_MUTED)
	for cls in ["OptionButton", "CheckButton", "CheckBox", "MenuButton"]:
		theme.set_color("font_color", cls, COLOR_TEXT_PRIMARY)
		theme.set_color("font_hover_color", cls, COLOR_TEXT_PRIMARY)
		theme.set_color("font_pressed_color", cls, COLOR_TEXT_PRIMARY)
		theme.set_color("font_focus_color", cls, COLOR_TEXT_PRIMARY)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(st, "OptionButton", theme.get_stylebox(st, "Button"))
	var flat = StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		theme.set_stylebox(st, "CheckButton", flat)
		theme.set_stylebox(st, "CheckBox", flat)
	var edit_box = create_card_box(6, COLOR_BG_SOLID, COLOR_BORDER)
	edit_box.content_margin_left = 8
	edit_box.content_margin_right = 8
	theme.set_stylebox("normal", "LineEdit", edit_box)
	var edit_focus = create_card_box(6, COLOR_BG_SOLID, COLOR_BORDER_FOCUS)
	edit_focus.content_margin_left = 8
	edit_focus.content_margin_right = 8
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_color("font_color", "LineEdit", COLOR_TEXT_PRIMARY)
	theme.set_color("caret_color", "LineEdit", COLOR_TEXT_PRIMARY)
	var track = create_card_box(4, Color(0.15, 0.14, 0.13, 0.06), Color(0, 0, 0, 0))
	var grab = create_card_box(4, Color(0.37, 0.34, 0.30, 0.35), Color(0, 0, 0, 0))
	var grab_hi = create_card_box(4, Color(0.37, 0.34, 0.30, 0.60), Color(0, 0, 0, 0))
	for cls in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", cls, track)
		theme.set_stylebox("grabber", cls, grab)
		theme.set_stylebox("grabber_highlight", cls, grab_hi)
		theme.set_stylebox("grabber_pressed", cls, grab_hi)
	var slider_track = create_card_box(3, COLOR_CARD, COLOR_BORDER)
	slider_track.content_margin_top = 2
	slider_track.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", slider_track)
	var slider_fill = create_card_box(3, COLOR_ACCENT, Color(0, 0, 0, 0))
	slider_fill.content_margin_top = 2
	slider_fill.content_margin_bottom = 2
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	return theme

# 快速创建胶囊容器样式 (Pill / Capsule Box)
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
	box.shadow_color = COLOR_SHADOW
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	return box

# 快速创建悬浮卡片样式 (Card Box)
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
