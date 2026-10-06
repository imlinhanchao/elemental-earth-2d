# theme_styler.gd
# 美术方向：「地质测绘图 × 实验手稿」(Survey Map & Lab Notebook)
# - 大世界：浅底地质测绘地图；HUD 顶/底栏：米白纸面卡片 (PAPER_*)
# - 模态弹窗：暖墨深色纸板 (COLOR_BG / COLOR_CARD)，保证长文阅读对比度
# - 强调色随文明时代演进 (get_era_accent)
class_name ThemeStyler
extends RefCounted

# 暖墨深底 (模态弹窗与浮层)
const COLOR_BG = Color(0.106, 0.098, 0.090, 0.96)       # #1B1917 暖墨
const COLOR_BG_SOLID = Color(0.118, 0.110, 0.100, 1.0)  # #1E1C19
const COLOR_CARD = Color(0.157, 0.145, 0.133, 0.95)     # #282522 二级卡片
const COLOR_CARD_HOVER = Color(0.208, 0.192, 0.172, 1.0)

# 细线框
const COLOR_BORDER = Color(0.33, 0.30, 0.26, 0.85)      # #544C42 暖灰细线
const COLOR_BORDER_HOVER = Color(0.48, 0.44, 0.38, 0.95)
const COLOR_BORDER_FOCUS = Color(0.83, 0.58, 0.29, 0.95) # #D4944A 铜色焦点

# 文字层级 (深底上)
const COLOR_TEXT_PRIMARY = Color(0.95, 0.92, 0.86, 1.0)   # #F2EBDB 纸白
const COLOR_TEXT_SECONDARY = Color(0.72, 0.67, 0.59, 1.0) # #B8AB96
const COLOR_TEXT_MUTED = Color(0.50, 0.46, 0.41, 1.0)     # #807569

# 主强调色 (默认铜赭，时代强调色见 get_era_accent)
const COLOR_ACCENT = Color(0.85, 0.60, 0.30, 1.0)        # #D9994D 铜赭
const COLOR_ACCENT_HOVER = Color(0.93, 0.70, 0.40, 1.0)
const COLOR_ACCENT_PRESSED = Color(0.68, 0.46, 0.22, 1.0)
const COLOR_WARNING = Color(0.89, 0.66, 0.20, 1.0)       # #E3A833 赭黄
const COLOR_SUCCESS = Color(0.42, 0.66, 0.42, 1.0)       # #6BA86B 苔绿
const COLOR_DANGER = Color(0.80, 0.33, 0.27, 1.0)        # #CC5545 朱砂

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
	Color(0.15, 0.72, 0.92), # 5 原子 · 切伦科夫蓝 #26B8EB
]

static func get_era_accent(era: int) -> Color:
	return ERA_ACCENTS[clampi(era, 0, ERA_ACCENTS.size() - 1)]

# 字体：Noto Sans SC 正文 + JetBrains Mono 数值
const FONT_SANS_PATH = "res://assets/fonts/NotoSansSC.ttf"
const FONT_MONO_PATH = "res://assets/fonts/JetBrainsMono.ttf"
static var _font_sans: Font = null
static var _font_mono: Font = null

static func get_font_sans() -> Font:
	if _font_sans == null and ResourceLoader.exists(FONT_SANS_PATH):
		_font_sans = load(FONT_SANS_PATH)
	return _font_sans

static func get_font_mono() -> Font:
	if _font_mono == null and ResourceLoader.exists(FONT_MONO_PATH):
		var base: Font = load(FONT_MONO_PATH)
		# 数值字体缺字时回退到中文正文字体
		var sans = get_font_sans()
		if base and sans:
			base.fallbacks = [sans]
		_font_mono = base
	return _font_mono

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

	# 悬停整行/按钮高亮 (青蓝发丝线)
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
	btn_pressed.bg_color = COLOR_BG_SOLID
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
	btn_disabled.bg_color = Color(0.12, 0.11, 0.10, 0.5)
	btn_disabled.border_color = Color(0.25, 0.23, 0.20, 0.5)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# 3. 进度条样式 (ProgressBar) - 极简青蓝能量流
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = COLOR_BG_SOLID
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
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", COLOR_TEXT_SECONDARY)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	theme.set_color("font_color", "RichTextLabel", COLOR_TEXT_PRIMARY)

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

	# 7. 浮动提示 (TooltipPanel)
	var tip_box = create_card_box(6, COLOR_BG_SOLID, COLOR_BORDER)
	tip_box.content_margin_left = 10
	tip_box.content_margin_right = 10
	tip_box.content_margin_top = 6
	tip_box.content_margin_bottom = 6
	theme.set_stylebox("panel", "TooltipPanel", tip_box)
	theme.set_color("font_color", "TooltipLabel", COLOR_TEXT_PRIMARY)

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
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
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
