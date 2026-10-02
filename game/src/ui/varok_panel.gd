class_name VarokPanel
extends RefCounted

## 古龙瓦洛克试炼的对话面板（第三阶段 B2，D-185~D-186）。零状态、全静态：
## 只消费 VarokTrial.node_view 产出的字典（title / lines / branches / tempLabel），
## 自己不算任何数值、不碰规则层。
##
## 与别的面板的差别只在形态：这是**对话**，不是列表也不是遭遇。所以中间一大块
## 是逐行台词（lines），下方是可选应答（branches，label=玩家能说的话、
## detail=瓦洛克或旁白的回应、effectLabel=后果预览）。面板不判撒谎、不掷骰——
## 那都是 VarokTrial.choose 的事。
##
## 绘制与命中测试共用同一组布局函数，所以"画在这里、点在那里"不会发生。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const STORY_TOP: float = 118.0
const STORY_LINE_HEIGHT: float = 20.0
const CHOICES_TOP: float = 236.0
const CHOICE_HEIGHT: float = 68.0


static func draw(
	canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}
) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	UiTheme.draw_panel(canvas, rect)
	_draw_header(canvas, font, view, rect)
	_draw_story(canvas, font, view, rect)
	_draw_choices(canvas, font, view, rect, hover)
	_draw_footer(canvas, font, view, rect)


# --- 布局（draw 与 hit_test 共用）---

static func story_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + MARGIN, rect.position.y + STORY_TOP),
		Vector2(rect.size.x - MARGIN * 2.0, rect.size.y - STORY_TOP - FOOTER_HEIGHT)
	)


static func choice_rect(rect: Rect2, index: int) -> Rect2:
	var story: Rect2 = story_rect(rect)
	var top: float = story.position.y + CHOICES_TOP - STORY_TOP + float(index) * CHOICE_HEIGHT
	return Rect2(
		Vector2(story.position.x, top),
		Vector2(story.size.x, CHOICE_HEIGHT - 6.0)
	)


## 对话里没有按钮。留这个函数是为了让面板契约与其他面板一致。
static func buttons(_view: Dictionary, _rect: Rect2) -> Array:
	return []


## 返回的 kind 只有一种：choice（可选应答之一）。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var index: int = choice_at(view, rect, point)
	if index >= 0:
		return {"kind": "choice", "index": index, "enabled": choice_enabled(view, index)}
	return {}


static func choice_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var branches: Array = _array_of(view.get("branches", null))
	for i in range(branches.size()):
		if choice_rect(rect, i).has_point(point):
			return i
	return -1


static func choice_enabled(view: Dictionary, index: int) -> bool:
	var branches: Array = _array_of(view.get("branches", null))
	if index < 0 or index >= branches.size():
		return false
	return bool((branches[index] as Dictionary).get("enabled", true))


# --- 绘制 ---

static func _draw_header(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	UiTheme.draw_text(canvas, font, Vector2(left, top + 30.0),
		"「%s」" % str(view.get("title", "")), UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	var temp: String = str(view.get("tempLabel", ""))
	if not temp.is_empty():
		UiTheme.draw_text(canvas, font, Vector2(left, top + 56.0),
			"限时 · %s——风雪里每一寸热度都在作数。" % temp,
			UiTheme.COLOR_WARN, UiTheme.SIZE_NORMAL)
	else:
		UiTheme.draw_text(canvas, font, Vector2(left, top + 56.0),
			"古龙瓦洛克 · 三幕试炼", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - MARGIN, top + 30.0),
		"龙骸冰川最深处", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)


static func _draw_story(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var story: Rect2 = story_rect(rect)
	canvas.draw_rect(story, UiTheme.COLOR_LIST_BG)
	var lines: Array = _array_of(view.get("lines", null))
	if lines.is_empty():
		UiTheme.draw_text(canvas, font, story.position + Vector2(10.0, 26.0),
			"这里安静得不像有话要说。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return
	for i in range(lines.size()):
		var y: float = story.position.y + 24.0 + float(i) * STORY_LINE_HEIGHT
		if y > story.position.y + story.size.y - 12.0:
			break
		UiTheme.draw_text(canvas, font, Vector2(story.position.x + 10.0, y),
			str(lines[i]), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)


static func _draw_choices(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var story: Rect2 = story_rect(rect)
	UiTheme.draw_section_title(canvas, font,
		Vector2(story.position.x, story.position.y + CHOICES_TOP - STORY_TOP - 24.0),
		"你开口", story.size.x)
	var branches: Array = _array_of(view.get("branches", null))
	var hover_index: int = int(hover.get("index", -1)) \
		if str(hover.get("kind", "")) == "choice" else -1
	for i in range(branches.size()):
		var branch: Dictionary = branches[i]
		var box: Rect2 = choice_rect(rect, i)
		if i == hover_index:
			canvas.draw_rect(box, UiTheme.COLOR_SELECTED)
		canvas.draw_rect(box, UiTheme.COLOR_BORDER, false, 1.0)
		UiTheme.draw_text(canvas, font, box.position + Vector2(10.0, 22.0),
			str(branch.get("label", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_TITLE)
		UiTheme.draw_text_right(canvas, font,
			Vector2(box.position.x + box.size.x - 10.0, box.position.y + 22.0),
			str(branch.get("effectLabel", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		UiTheme.draw_text(canvas, font, box.position + Vector2(10.0, 44.0),
			str(branch.get("effect", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_footer(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var top: float = rect.position.y + rect.size.y - FOOTER_HEIGHT
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + MARGIN, top + 28.0),
		"↑↓ 选应答　回车 开口　点应答行也行",
		UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - MARGIN, top + 28.0),
		"瓦洛克不教人，只考验人。", UiTheme.COLOR_WARN, UiTheme.SIZE_NORMAL)


static func _array_of(value: Variant) -> Array:
	return value if value is Array else []
