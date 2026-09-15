class_name UiTheme
extends RefCounted

## 界面字体与主题。
##
## 这个类存在的唯一理由是：**Godot 自带的默认字体不含 CJK 字形**。直接用它，
## 所有中文标签会渲染成空白——不是报错、不是方块，就是什么都没有，界面看起来
## 像坏了却找不到原因。对一个全中文的游戏，这是必须在开工时就钉死的前提。
##
## 不给目标平台打包字体文件，而是取系统里已有的中文字体：Windows 上黑体、
## 等线、雅黑总有一款在，省下 10 MB 以上的字体资源，也省掉字体授权问题。
##
## 三条实现上的注意（都是实测踩出来的）：
##   1. **无头环境不加载字体**。解压并解析一个 10–20 MB 的中文字体，在没有
##      渲染上下文的进程里实测跑不完（测试挂住不返回）。无头下本来也不渲染
##      文字，直接返回引擎默认字体即可。判定用 DisplayServer 的名字。
##   2. **优先普通 TTF，TTC 放最后**。msyh.ttc 是字体集合，体积近 20 MB，
##      解析代价远高于单文件字体。
##   3. **SystemFont 关掉 allow_system_fallback**。打开它等于让引擎扫全系统
##      字体库，同样会在无头环境下卡住。

const HEADLESS_SERVER_NAME: String = "headless"

const SOURCE_HEADLESS: String = "headless-skip"
const SOURCE_SYSTEM_FAMILY: String = "SystemFont:"
const SOURCE_ENGINE_DEFAULT: String = "engine-default"

const CJK_FONT_PATHS: Array = [
	"C:/Windows/Fonts/simhei.ttf",  # 黑体（单文件，优先）
	"C:/Windows/Fonts/Deng.ttf",    # 等线
	"C:/Windows/Fonts/msyh.ttf",    # 微软雅黑
	"C:/Windows/Fonts/simsun.ttc",  # 宋体
	"C:/Windows/Fonts/msyh.ttc",
]

const CJK_FAMILIES: Array = [
	"Microsoft YaHei UI",
	"Microsoft YaHei",
	"SimHei",
	"DengXian",
	"SimSun",
	"Noto Sans CJK SC",
	"Source Han Sans SC",
]

## 用于验证字形覆盖的样本。取界面里真实会用到的字，而不是随便点几个——
## "能显示中文"这句话要被证伪得掉，就得拿实际用字去测。
const PROBE_TEXT: String = "轮回之书城市财富人口治安文化势力"

const DEFAULT_FONT_SIZE: int = 14

## 行距。见 theme() 里的说明。
const LINE_SPACING: int = 0

## 界面配色。城市面板、开局界面、角色面板、战斗面板共用这一张表——
## 分开各定义一份的话，"次要文字灰"这种值两边会慢慢漂开，看起来像两种状态。
const COLOR_BG: Color = Color(0.055, 0.062, 0.075, 0.98)
const COLOR_LIST_BG: Color = Color(0.085, 0.092, 0.108, 0.98)
const COLOR_SELECTED: Color = Color(0.16, 0.20, 0.26)
const COLOR_BORDER: Color = Color(0.20, 0.22, 0.26)
const COLOR_TEXT: Color = Color(0.86, 0.87, 0.89)
const COLOR_DIM: Color = Color(0.52, 0.55, 0.59)
const COLOR_UP: Color = Color(0.40, 0.78, 0.48)
const COLOR_DOWN: Color = Color(0.87, 0.44, 0.41)
const COLOR_BAR_BG: Color = Color(0.13, 0.14, 0.17)
const COLOR_BAR: Color = Color(0.42, 0.58, 0.82)
const COLOR_BAR_LOW: Color = Color(0.80, 0.46, 0.32)
const COLOR_ACCENT: Color = Color(0.85, 0.72, 0.35)
const COLOR_WARN: Color = Color(0.92, 0.66, 0.30)
const COLOR_LINE: Color = Color(0.32, 0.62, 0.85)

## 字号。三档够用：标题、正文、注解。
const SIZE_TITLE: int = 22
const SIZE_NORMAL: int = 14
const SIZE_SMALL: int = 12

## 按钮尺寸。四个面板的按钮共用这几个数，免得"这个面板的按钮高一点"
## 这种差异在四个地方各写一遍。
const BUTTON_HEIGHT: float = 26.0
const BUTTON_MIN_WIDTH: float = 84.0
const BUTTON_GAP: float = 8.0
const BUTTON_PADDING: float = 14.0
## 无头环境没有字体可用时的每字宽度估算。只用于无头下的命中测试，
## 窗口里一律走真实字宽——见 button_row 的说明。
const ESTIMATED_CHAR_WIDTH: float = 13.0

static var _font: Font = null
static var _font_source: String = ""
static var _theme: Theme = null


## 界面字体。首次调用时确定来源，之后复用。无头环境返回 null（见文件头说明）。
static func font() -> Font:
	if _font != null:
		return _font
	if is_headless():
		_font_source = SOURCE_HEADLESS
		return null
	var by_path: Dictionary = _load_by_path()
	if not by_path.is_empty():
		_font = by_path["font"]
		_font_source = str(by_path["source"])
		return _font
	var by_family: Font = _load_by_family()
	if by_family != null:
		_font = by_family
		_font_source = SOURCE_SYSTEM_FAMILY + str(CJK_FAMILIES[0])
		return _font
	push_warning("[UiTheme] 未找到中文字体，界面中文会显示为空白")
	_font = ThemeDB.fallback_font
	_font_source = SOURCE_ENGINE_DEFAULT
	return _font


static func is_headless() -> bool:
	return DisplayServer.get_name() == HEADLESS_SERVER_NAME


## 系统里是否存在候选的中文字体文件。只看文件是否存在，不解析字体内容——
## 解析在无头环境下会卡住，而这个判断本身已足够回答"装载时找不找得到字体"。
static func first_available_font_path() -> String:
	for path in CJK_FONT_PATHS:
		var file_path: String = str(path)
		if FileAccess.file_exists(file_path):
			return file_path
	return ""


## 字体来源，供测试与排查用。
static func font_source() -> String:
	if _font == null:
		font()
	return _font_source


## 当前字体是否来自已知的中文字体。界面中文能不能显示，取决于它。
## 只比对来源字符串，不碰字体数据，因此在任何环境下都是廉价的。
static func is_cjk_capable() -> bool:
	font_source()
	return _font_source.begins_with("C:/Windows/Fonts/") \
		or _font_source.begins_with(SOURCE_SYSTEM_FAMILY)


static func _load_by_path() -> Dictionary:
	for path in CJK_FONT_PATHS:
		var file_path: String = str(path)
		if not FileAccess.file_exists(file_path):
			continue
		var file := FontFile.new()
		if file.load_dynamic_font(file_path) != OK:
			continue
		return {"font": file, "source": file_path}
	return {}


static func _load_by_family() -> Font:
	var system := SystemFont.new()
	system.font_names = PackedStringArray(CJK_FAMILIES)
	system.allow_system_fallback = false
	return system


## 整棵界面树共用的主题。挂在 Window 上可让全部子控件继承，
## 不必逐个控件设字体覆盖——漏一个就漏一处空白。
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var f: Font = font()
	t.default_font_size = DEFAULT_FONT_SIZE
	# 行距设为 0：中文字体的行盒本身就很宽松（黑体在 size 14 下单行已占 23px），
	# 再叠引擎默认的 3px 行距，一个 1280×720 的界面会白白丢掉一整行的高度。
	t.set_constant("line_spacing", "Label", LINE_SPACING)
	t.set_constant("line_spacing", "RichTextLabel", LINE_SPACING)
	if f != null:
		t.default_font = f
		# RichTextLabel 的四种字形要分别指定：只设 default_font 的话，
		# [b] 标记会退回引擎默认主题里的粗体（不含中文），加粗那段就变空白。
		t.set_font("normal_font", "RichTextLabel", f)
		t.set_font("bold_font", "RichTextLabel", f)
		t.set_font("italics_font", "RichTextLabel", f)
		t.set_font("mono_font", "RichTextLabel", f)
		t.set_font("font", "Label", f)
	_theme = t
	return _theme


## 供 _draw 用的字体与尺寸。CanvasItem.draw_string 不接受主题继承，
## 必须显式传字体，所以绘图代码统一从这里取。
static func draw_font() -> Font:
	return font()


static func draw_font_size() -> int:
	return DEFAULT_FONT_SIZE


## 画一行文字。三个面板都要写这几行 draw_string，集中在这里，
## 免得行距、对齐这类细节在四处各写一遍然后慢慢走样。
static func draw_text(
	canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color, size: int
) -> void:
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## 右对齐到 pos.x。宽度由字体实测，不估。
static func draw_text_right(
	canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color, size: int
) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, Vector2(pos.x - width, pos.y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## 以 pos.x 为中心居中。
static func draw_text_center(
	canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color, size: int
) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, Vector2(pos.x - width * 0.5, pos.y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## 一根横线 + 文字的小节标题。四个面板的段落分界都长这样。
static func draw_section_title(
	canvas: CanvasItem, font: Font, pos: Vector2, text: String, width: float
) -> void:
	draw_text(canvas, font, pos, text, COLOR_ACCENT, SIZE_NORMAL)
	canvas.draw_line(
		Vector2(pos.x, pos.y + 6.0),
		Vector2(pos.x + width, pos.y + 6.0),
		COLOR_BORDER, 1.0
	)


## 进度条。ratio 会被钳到 0–1；低于 30% 用警示色，高于 75% 用正向色。
##
## recolor 用来关掉那套比例配色。属性分配条就必须关掉：那里 0 点是常态
## （20 点分给七维，总有几项是 0），一律标红会让界面看着像处处出错。
static func draw_bar(
	canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color = COLOR_BAR,
	recolor: bool = true
) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	canvas.draw_rect(rect, COLOR_BAR_BG)
	var color: Color = fill
	if recolor and fill == COLOR_BAR:
		if clamped < 0.3:
			color = COLOR_BAR_LOW
		elif clamped > 0.75:
			color = COLOR_UP
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamped, rect.size.y)), color)


static func reset_cache() -> void:
	_font = null
	_font_source = ""
	_theme = null


# --- 按钮 ---
#
# 鼠标交互要求"绘制"与"命中测试"用同一份位置。之前的做法是绘制时顺手算一遍
# 坐标——一旦按钮也要能被点到，两边就会各算一遍然后慢慢走样（按钮画在这里、
# 点在那里）。所以按钮的位置统一由 measure_button 与 button_row 产出，
# 绘制与命中测试都调它们。

## 按钮文字宽度。窗口里按字体实测，无头下按字数估算——无头没有字体可用，
## 但 hit_test 是纯函数、要能在无头测试里跑，所以给一个可用的兜底。
static func measure_button(font: Font, label: String) -> float:
	if font == null:
		return maxf(BUTTON_MIN_WIDTH,
			float(label.length()) * ESTIMATED_CHAR_WIDTH + BUTTON_PADDING * 2.0)
	var width: float = font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE_SMALL
	).x
	return maxf(BUTTON_MIN_WIDTH, width + BUTTON_PADDING * 2.0)


## 一排右对齐的按钮。specs 是 [{id, label, enabled}]，从左到右给出，
## 返回的数组保持同样的顺序，每项多一个 rect。
##
## right 是这排按钮的右边界，baseline_y 是按钮上沿。
static func button_row(
	font: Font, right: float, baseline_y: float, specs: Array
) -> Array:
	var buttons: Array = []
	var cursor_x: float = right
	# 从右往左排：宽度由文字决定，只有先知道宽度才能定出左边界
	for index in range(specs.size() - 1, -1, -1):
		var spec: Dictionary = specs[index]
		var label: String = str(spec.get("label", ""))
		var width: float = measure_button(font, label)
		cursor_x -= width
		buttons.append({
			"id": str(spec.get("id", "")),
			"label": label,
			"enabled": bool(spec.get("enabled", true)),
			"rect": Rect2(Vector2(cursor_x, baseline_y), Vector2(width, BUTTON_HEIGHT)),
		})
		cursor_x -= BUTTON_GAP
	buttons.reverse()
	return buttons


## 在按钮排里找一个按钮。命中测试与测试用例都靠它拿位置，
## 于是"点击某个按钮"这件事不需要在测试里硬编码坐标。
static func find_button(buttons: Array, button_id: String) -> Dictionary:
	for button in buttons:
		if str(button["id"]) == button_id:
			return button
	return {}


## 画一个按钮。enabled 为假时变灰且不接受点击；hovered 时用强调色描边。
static func draw_button(
	canvas: CanvasItem, font: Font, rect: Rect2, label: String,
	enabled: bool = true, hovered: bool = false
) -> void:
	canvas.draw_rect(rect, COLOR_SELECTED if hovered else COLOR_LIST_BG)
	var border: Color = COLOR_BORDER
	if not enabled:
		border = COLOR_BORDER
	elif hovered:
		border = COLOR_ACCENT
	canvas.draw_rect(rect, border, false, 1.0)
	var color: Color = COLOR_DIM
	if enabled:
		color = COLOR_ACCENT if hovered else COLOR_TEXT
	draw_text_center(canvas, font,
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5 + 5.0),
		label, color, SIZE_SMALL)


## 命中测试的公共入口：point 落在哪个按钮里。找不到返回空字典。
static func hit_button(buttons: Array, point: Vector2) -> Dictionary:
	for button in buttons:
		if (button["rect"] as Rect2).has_point(point):
			return button
	return {}
