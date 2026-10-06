# theme_styler.gd
# 美术方向：「地质测绘图 × 实验手稿」(Survey Map & Lab Notebook)
# 全局只有一种明度：浅色模式下大世界、HUD、弹窗、主菜单都是米白纸 + 墨色文字；
# 深色模式下统一为暖墨底 + 纸白文字 (地图一起变暗)。强调色随文明时代演进 (get_era_accent)。
class_name ThemeStyler
extends RefCounted

# 主题模式：浅色 (纸面) / 深色 (暖墨)。所有颜色令牌都是可切换的静态变量，
# 由 apply_mode() 在启动时按设置写入；切换主题后重新加载当前场景生效 (GameState.switch_theme)。
static var is_dark: bool = false

# 底色 (模态弹窗与浮层)
static var COLOR_BG: Color
static var COLOR_BG_SOLID: Color
static var COLOR_CARD: Color
static var COLOR_CARD_HOVER: Color
# 细线框
static var COLOR_BORDER: Color
static var COLOR_BORDER_HOVER: Color
static var COLOR_BORDER_FOCUS: Color
# 文字层级
static var COLOR_TEXT_PRIMARY: Color
static var COLOR_TEXT_SECONDARY: Color
static var COLOR_TEXT_MUTED: Color
static var COLOR_TEXT_ON_ACCENT: Color
# 功能色
static var COLOR_ACCENT: Color
static var COLOR_ACCENT_HOVER: Color
static var COLOR_ACCENT_PRESSED: Color
static var COLOR_WARNING: Color
static var COLOR_SUCCESS: Color
static var COLOR_DANGER: Color
static var COLOR_INFO: Color
# 功能色浅底 / 深底 (状态卡片背景)
static var TINT_SUCCESS: Color
static var TINT_WARNING: Color
static var TINT_DANGER: Color
static var TINT_INFO: Color
# 浮层阴影与遮罩
static var COLOR_SHADOW: Color
static var COLOR_BACKDROP: Color
# HUD 顶栏 / 底栏表面
static var PAPER_BG: Color
static var PAPER_BG_HOVER: Color
static var PAPER_BORDER: Color
static var PAPER_INK: Color
static var PAPER_INK_SOFT: Color
# 大世界清屏色
static var COLOR_CLEAR: Color
# 时代强调色：石器赭石 → 炼金铜褐 → 近代墨绿 → 电化学钴蓝 → 稀土紫 → 原子切伦科夫蓝
static var ERA_ACCENTS: Array[Color] = []

const LIGHT: Dictionary = {
	"COLOR_BG": Color(0.957, 0.937, 0.898, 0.98),        # #F4EFE5 米白纸
	"COLOR_BG_SOLID": Color(0.976, 0.961, 0.929, 1.0),   # #F9F5ED
	"COLOR_CARD": Color(0.922, 0.894, 0.839, 0.95),      # #EBE4D6
	"COLOR_CARD_HOVER": Color(0.886, 0.851, 0.780, 1.0), # #E2D9C7
	"COLOR_BORDER": Color(0.76, 0.71, 0.64, 0.9),        # #C2B5A3 铅笔线
	"COLOR_BORDER_HOVER": Color(0.60, 0.55, 0.48, 0.95),
	"COLOR_BORDER_FOCUS": Color(0.69, 0.41, 0.16, 0.95), # #B0692A 铜色焦点
	"COLOR_TEXT_PRIMARY": Color(0.15, 0.14, 0.13, 1.0),  # #262421 墨色
	"COLOR_TEXT_SECONDARY": Color(0.37, 0.34, 0.30, 1.0),
	"COLOR_TEXT_MUTED": Color(0.54, 0.50, 0.44, 1.0),
	"COLOR_TEXT_ON_ACCENT": Color(0.99, 0.97, 0.93, 1.0),
	"COLOR_ACCENT": Color(0.69, 0.41, 0.16, 1.0),        # #B0692A 铜赭
	"COLOR_ACCENT_HOVER": Color(0.78, 0.49, 0.22, 1.0),
	"COLOR_ACCENT_PRESSED": Color(0.56, 0.32, 0.12, 1.0),
	"COLOR_WARNING": Color(0.69, 0.49, 0.06, 1.0),
	"COLOR_SUCCESS": Color(0.25, 0.50, 0.27, 1.0),
	"COLOR_DANGER": Color(0.70, 0.23, 0.18, 1.0),
	"COLOR_INFO": Color(0.20, 0.40, 0.58, 1.0),
	"TINT_SUCCESS": Color(0.86, 0.91, 0.84, 1.0),
	"TINT_WARNING": Color(0.96, 0.91, 0.78, 1.0),
	"TINT_DANGER": Color(0.96, 0.86, 0.83, 1.0),
	"TINT_INFO": Color(0.85, 0.90, 0.94, 1.0),
	"COLOR_SHADOW": Color(0.25, 0.20, 0.12, 0.20),
	"COLOR_BACKDROP": Color(0.20, 0.17, 0.13, 0.35),
	"PAPER_BG": Color(0.957, 0.937, 0.898, 0.97),
	"PAPER_BG_HOVER": Color(0.918, 0.890, 0.835, 1.0),
	"PAPER_BORDER": Color(0.72, 0.67, 0.59, 0.9),
	"PAPER_INK": Color(0.15, 0.14, 0.13, 1.0),
	"PAPER_INK_SOFT": Color(0.40, 0.37, 0.33, 1.0),
	"COLOR_CLEAR": Color(0.925, 0.905, 0.862, 1.0),      # #ECE7DC 图纸底色
	"ERA_ACCENTS": [Color(0.80, 0.52, 0.25), Color(0.72, 0.42, 0.24), Color(0.20, 0.55, 0.45),
		Color(0.20, 0.42, 0.75), Color(0.55, 0.36, 0.75), Color(0.10, 0.56, 0.74)],
}

const DARK: Dictionary = {
	"COLOR_BG": Color(0.106, 0.098, 0.090, 0.97),        # #1B1917 暖墨
	"COLOR_BG_SOLID": Color(0.130, 0.120, 0.110, 1.0),
	"COLOR_CARD": Color(0.165, 0.152, 0.138, 0.95),      # #2A2723
	"COLOR_CARD_HOVER": Color(0.215, 0.198, 0.178, 1.0),
	"COLOR_BORDER": Color(0.33, 0.30, 0.26, 0.9),        # #544C42
	"COLOR_BORDER_HOVER": Color(0.48, 0.44, 0.38, 0.95),
	"COLOR_BORDER_FOCUS": Color(0.85, 0.60, 0.30, 0.95), # #D9994D
	"COLOR_TEXT_PRIMARY": Color(0.95, 0.92, 0.86, 1.0),  # #F2EBDB 纸白
	"COLOR_TEXT_SECONDARY": Color(0.74, 0.69, 0.61, 1.0),
	"COLOR_TEXT_MUTED": Color(0.55, 0.51, 0.45, 1.0),
	"COLOR_TEXT_ON_ACCENT": Color(0.11, 0.10, 0.09, 1.0),
	"COLOR_ACCENT": Color(0.85, 0.60, 0.30, 1.0),        # #D9994D 铜赭 (提亮)
	"COLOR_ACCENT_HOVER": Color(0.93, 0.70, 0.40, 1.0),
	"COLOR_ACCENT_PRESSED": Color(0.68, 0.46, 0.22, 1.0),
	"COLOR_WARNING": Color(0.89, 0.70, 0.30, 1.0),
	"COLOR_SUCCESS": Color(0.47, 0.72, 0.47, 1.0),
	"COLOR_DANGER": Color(0.90, 0.45, 0.38, 1.0),
	"COLOR_INFO": Color(0.48, 0.67, 0.86, 1.0),
	"TINT_SUCCESS": Color(0.15, 0.22, 0.15, 1.0),
	"TINT_WARNING": Color(0.26, 0.21, 0.10, 1.0),
	"TINT_DANGER": Color(0.28, 0.14, 0.12, 1.0),
	"TINT_INFO": Color(0.12, 0.18, 0.25, 1.0),
	"COLOR_SHADOW": Color(0.0, 0.0, 0.0, 0.45),
	"COLOR_BACKDROP": Color(0.0, 0.0, 0.0, 0.50),
	"PAPER_BG": Color(0.130, 0.120, 0.110, 0.96),
	"PAPER_BG_HOVER": Color(0.180, 0.165, 0.150, 1.0),
	"PAPER_BORDER": Color(0.33, 0.30, 0.26, 0.9),
	"PAPER_INK": Color(0.93, 0.90, 0.84, 1.0),
	"PAPER_INK_SOFT": Color(0.70, 0.65, 0.58, 1.0),
	"COLOR_CLEAR": Color(0.075, 0.070, 0.065, 1.0),
	"ERA_ACCENTS": [Color(0.86, 0.60, 0.33), Color(0.84, 0.55, 0.35), Color(0.33, 0.72, 0.60),
		Color(0.40, 0.60, 0.90), Color(0.68, 0.52, 0.88), Color(0.20, 0.75, 0.93)],
}

static func _static_init() -> void:
	apply_mode(false)

# 写入一套配色；返回值表示模式是否发生变化
static func apply_mode(dark: bool) -> bool:
	var changed := dark != is_dark
	is_dark = dark
	var pal: Dictionary = DARK if dark else LIGHT
	COLOR_BG = pal["COLOR_BG"]; COLOR_BG_SOLID = pal["COLOR_BG_SOLID"]
	COLOR_CARD = pal["COLOR_CARD"]; COLOR_CARD_HOVER = pal["COLOR_CARD_HOVER"]
	COLOR_BORDER = pal["COLOR_BORDER"]; COLOR_BORDER_HOVER = pal["COLOR_BORDER_HOVER"]; COLOR_BORDER_FOCUS = pal["COLOR_BORDER_FOCUS"]
	COLOR_TEXT_PRIMARY = pal["COLOR_TEXT_PRIMARY"]; COLOR_TEXT_SECONDARY = pal["COLOR_TEXT_SECONDARY"]
	COLOR_TEXT_MUTED = pal["COLOR_TEXT_MUTED"]; COLOR_TEXT_ON_ACCENT = pal["COLOR_TEXT_ON_ACCENT"]
	COLOR_ACCENT = pal["COLOR_ACCENT"]; COLOR_ACCENT_HOVER = pal["COLOR_ACCENT_HOVER"]; COLOR_ACCENT_PRESSED = pal["COLOR_ACCENT_PRESSED"]
	COLOR_WARNING = pal["COLOR_WARNING"]; COLOR_SUCCESS = pal["COLOR_SUCCESS"]
	COLOR_DANGER = pal["COLOR_DANGER"]; COLOR_INFO = pal["COLOR_INFO"]
	TINT_SUCCESS = pal["TINT_SUCCESS"]; TINT_WARNING = pal["TINT_WARNING"]
	TINT_DANGER = pal["TINT_DANGER"]; TINT_INFO = pal["TINT_INFO"]
	COLOR_SHADOW = pal["COLOR_SHADOW"]; COLOR_BACKDROP = pal["COLOR_BACKDROP"]
	PAPER_BG = pal["PAPER_BG"]; PAPER_BG_HOVER = pal["PAPER_BG_HOVER"]; PAPER_BORDER = pal["PAPER_BORDER"]
	PAPER_INK = pal["PAPER_INK"]; PAPER_INK_SOFT = pal["PAPER_INK_SOFT"]
	COLOR_CLEAR = pal["COLOR_CLEAR"]
	ERA_ACCENTS.clear()
	for c in pal["ERA_ACCENTS"]:
		ERA_ACCENTS.append(c)
	return changed

# 按设置值 ("light" / "dark" / "system") 判断是否使用深色
static func resolve_dark(mode: String) -> bool:
	if mode == "dark":
		return true
	if mode == "system":
		return DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode()
	return false

# 把为浅色纸面设计的颜色换算到当前主题：浅色模式原样返回；
# 深色模式下浅色表面变暗、墨色文字变亮、彩色提亮，色相与透明度保持不变。
# 只用于界面与地图上零散的颜色字面量；主要配色请直接使用上面的令牌。
static func adapt(c: Color) -> Color:
	if not is_dark:
		return c
	var mx = maxf(c.r, maxf(c.g, c.b))
	var mn = minf(c.r, minf(c.g, c.b))
	var l = (mx + mn) * 0.5
	var s = 0.0 if mx == mn else (mx - mn) / (1.0 - absf(2.0 * l - 1.0))
	var nl: float
	if s < 0.35:
		if l < 0.5:
			nl = 0.98 - 0.6 * l          # 墨色文字 → 纸白
		elif l < 0.8:
			nl = 1.0 - l                 # 铅笔线 → 暖灰线
		else:
			nl = 0.10 + (1.0 - l) * 0.6  # 纸面 → 暖墨
	else:
		if l > 0.75:
			nl = 0.10 + (1.0 - l) * 0.8  # 浅色状态底 → 深色状态底
			s *= 0.6
		elif l < 0.5:
			nl = minf(l + 0.2, 0.72)     # 彩色文字 / 线条提亮
		else:
			nl = minf(l + 0.08, 0.78)
	return _from_hsl(c.h, clampf(s, 0.0, 1.0), clampf(nl, 0.0, 1.0), c.a)

static func _from_hsl(h: float, s: float, l: float, a: float) -> Color:
	var v = l + s * minf(l, 1.0 - l)
	var sv = 0.0 if v <= 0.0 else 2.0 * (1.0 - l / v)
	return Color.from_hsv(h, sv, v, a)

# 「加深」一个强调色：浅色模式变暗、深色模式变亮，保证与底色的对比方向一致
static func deepen(c: Color, amount: float) -> Color:
	return c.lightened(amount) if is_dark else c.darkened(amount)

# 场景文件 (.tscn) 中写死的文字颜色与遮罩：节点进入场景树时按当前主题换算一次
const _ADAPT_COLOR_NAMES: Array[String] = ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
	"font_disabled_color", "font_outline_color", "default_color"]

static func adapt_scene_node(n: Node) -> void:
	if n is ColorRect:
		# 全屏遮罩统一使用当前主题的遮罩色
		n.color = COLOR_BACKDROP if n.color.a < 0.9 else adapt(n.color)
	if n is Control:
		for nm in _ADAPT_COLOR_NAMES:
			if n.has_theme_color_override(nm):
				n.add_theme_color_override(nm, adapt(n.get_theme_color(nm)))
		if n.has_theme_color_override("font_shadow_color"):
			n.add_theme_color_override("font_shadow_color", COLOR_SHADOW)
	if n is Button and n.icon:
		n.icon = ItemIconManager.themed(n.icon)
	elif n is TextureRect and n.texture:
		n.texture = ItemIconManager.themed(n.texture)

static func get_era_accent(era: int) -> Color:
	return ERA_ACCENTS[clampi(era, 0, ERA_ACCENTS.size() - 1)]

# 字号四档 (界面只使用这四档；主菜单标题、元素符号等展示字号除外)
const FONT_CAPTION = 12  # 注释、标签、快捷键提示
const FONT_BODY = 14     # 正文、按钮、列表
const FONT_HEADING = 16  # 弹窗标题、卡片标题、数值
const FONT_TITLE = 20    # 顶栏品牌、时代名、元素名

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
	btn_pressed.bg_color = adapt(Color(0.84, 0.79, 0.71, 1.0))
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
	btn_disabled.bg_color = Color(COLOR_CARD.r, COLOR_CARD.g, COLOR_CARD.b, 0.6)
	btn_disabled.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
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
	theme.default_font_size = FONT_BODY
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
	var track = create_card_box(4, Color(COLOR_TEXT_PRIMARY.r, COLOR_TEXT_PRIMARY.g, COLOR_TEXT_PRIMARY.b, 0.06), Color(0, 0, 0, 0))
	var grab = create_card_box(4, Color(COLOR_TEXT_SECONDARY.r, COLOR_TEXT_SECONDARY.g, COLOR_TEXT_SECONDARY.b, 0.35), Color(0, 0, 0, 0))
	var grab_hi = create_card_box(4, Color(COLOR_TEXT_SECONDARY.r, COLOR_TEXT_SECONDARY.g, COLOR_TEXT_SECONDARY.b, 0.60), Color(0, 0, 0, 0))
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
