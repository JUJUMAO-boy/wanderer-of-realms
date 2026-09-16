class_name EncounterPanel
extends RefCounted

## 世界遭遇的面板（《技术设计文档》9.12 节，D-60）。零状态、全静态：只消费视图模型
## 给的字典，自己不算任何数值。
##
## 与别的面板有一处刻意的不同：**这里没有「返回地图」按钮**。遭遇的三个做法就是全部
## 出口（迎战 / 绕开 / 交涉），给一个免费的返回键，遭遇就退化成一道随手能关掉的
## 提示框，"路上有危险"这件事也就不成立了。绕开要花时间、交涉只对人形有效，
## 所以任何一条路都通向结果，不会把人卡住。
##
## 绘制与命中测试共用同一组布局函数（list_rect / column_rect / choice_rect），
## 所以"画在这里、点在那里"这类漂移不可能发生。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const LIST_WIDTH: float = 430.0
const ROW_HEIGHT: float = 34.0
const CHOICE_HEIGHT: float = 68.0
const ROW_TOP_PAD: float = 4.0
const STORY_TOP: float = 118.0
const STORY_LINE_HEIGHT: float = 20.0
const CHOICES_TOP: float = 236.0


static func draw(
	canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}
) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	canvas.draw_rect(rect, UiTheme.COLOR_BG)
	canvas.draw_rect(rect, UiTheme.COLOR_BORDER, false, 1.0)
	_draw_header(canvas, font, view, rect)
	_draw_list(canvas, font, view, rect, hover)
	_draw_story(canvas, font, view, rect)
	_draw_choices(canvas, font, view, rect, hover)
	_draw_footer(canvas, font, view, rect)


static func list_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + MARGIN, rect.position.y + HEADER_HEIGHT),
		Vector2(LIST_WIDTH, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


static func column_rect(rect: Rect2) -> Rect2:
	var left: Rect2 = list_rect(rect)
	return Rect2(
		Vector2(left.position.x + LIST_WIDTH + MARGIN, rect.position.y + HEADER_HEIGHT),
		Vector2(rect.size.x - LIST_WIDTH - MARGIN * 3.0, left.size.y)
	)


static func choice_rect(rect: Rect2, index: int) -> Rect2:
	var column: Rect2 = column_rect(rect)
	var top: float = column.position.y + CHOICES_TOP + index * CHOICE_HEIGHT
	return Rect2(
		Vector2(column.position.x, top),
		Vector2(column.size.x, CHOICE_HEIGHT - 6.0)
	)


## 遭遇里没有按钮。留这个函数是为了让面板的契约与其他面板一致
## （测试与主场景都按同一组方法调用），也把"为什么是空的"写在代码里。
static func buttons(_view: Dictionary, _rect: Rect2) -> Array:
	return []


## 返回的 kind 只有一种：choice（三个做法之一）。左列是对手，只看不能点。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var index: int = choice_at(view, rect, point)
	if index >= 0:
		return {"kind": "choice", "index": index, "enabled": choice_enabled(view, index)}
	return {}


static func choice_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var choices: Array = _array_of(view.get("choices", null))
	for i in range(choices.size()):
		if choice_rect(rect, i).has_point(point):
			return i
	return -1


static func choice_enabled(view: Dictionary, index: int) -> bool:
	var choices: Array = _array_of(view.get("choices", null))
	if index < 0 or index >= choices.size():
		return false
	return bool((choices[index] as Dictionary).get("enabled", false))


# --- 绘制 ---

static func _draw_header(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	UiTheme.draw_text(canvas, font, Vector2(left, top + 30.0),
		"遇上「%s」" % str(view.get("title", "")), UiTheme.COLOR_WARN, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, Vector2(left, top + 56.0),
		"%s · %s · %s" % [
			str(view.get("contextLabel", "")), str(view.get("cityLabel", "")),
			str(view.get("tierLabel", "")),
		],
		UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
	var danger_color: Color = UiTheme.COLOR_WARN if bool(view.get("outmatched", false)) \
		else UiTheme.COLOR_TEXT
	UiTheme.draw_text(canvas, font, Vector2(left, top + 76.0),
		"对手最高 TL %d ｜ 你 TL %d ｜ %s" % [
			int(view.get("threatLevel", 0)), int(view.get("playerThreat", 0)),
			str(view.get("dangerLabel", "")),
		],
		danger_color, UiTheme.SIZE_SMALL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - MARGIN, top + 30.0),
		str(view.get("reputationLabel", "")), UiTheme.COLOR_ACCENT, UiTheme.SIZE_NORMAL)


static func _draw_list(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var list: Rect2 = list_rect(rect)
	canvas.draw_rect(list, UiTheme.COLOR_LIST_BG)
	var rows: Array = _array_of(view.get("rows", null))
	if rows.is_empty():
		UiTheme.draw_text(canvas, font, list.position + Vector2(10.0, 26.0),
			"对面没人——这一场不该发生。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return
	for i in range(rows.size()):
		_draw_row(canvas, font, rows[i], _row_rect(rect, i))


static func _row_rect(rect: Rect2, index: int) -> Rect2:
	var list: Rect2 = list_rect(rect)
	return Rect2(
		Vector2(list.position.x, list.position.y + ROW_TOP_PAD + index * ROW_HEIGHT),
		Vector2(list.size.x, ROW_HEIGHT)
	)


static func _draw_row(canvas: CanvasItem, font: Font, row: Dictionary, row_rect: Rect2) -> void:
	UiTheme.draw_text(canvas, font, Vector2(row_rect.position.x + 8.0, row_rect.position.y + 22.0),
		"[%s]" % str(row.get("categoryLabel", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(row_rect.position.x + 62.0, row_rect.position.y + 22.0),
		str(row.get("name", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(row_rect.position.x + row_rect.size.x - 8.0, row_rect.position.y + 22.0),
		"%s · %s" % [str(row.get("threatLabel", "")), str(row.get("hpLabel", ""))],
		UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)


static func _draw_story(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var column: Rect2 = column_rect(rect)
	var left: float = column.position.x
	var top: float = column.position.y + STORY_TOP
	UiTheme.draw_text(canvas, font, Vector2(left, top),
		str(view.get("story", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	var raw: Variant = view.get("pos", null)
	var pos: Array = raw if raw is Array else []
	var x: int = int(pos[0]) if pos.size() >= 2 else 0
	var y: int = int(pos[1]) if pos.size() >= 2 else 0
	UiTheme.draw_text(canvas, font, Vector2(left, top + STORY_LINE_HEIGHT),
		"%s · 位置 (%d, %d)" % [str(view.get("contextLabel", "")), x, y],
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_choices(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var column: Rect2 = column_rect(rect)
	UiTheme.draw_section_title(canvas, font,
		Vector2(column.position.x, column.position.y + CHOICES_TOP - 24.0),
		"怎么办", column.size.x)
	var choices: Array = _array_of(view.get("choices", null))
	var cursor: int = int(view.get("cursor", 0))
	var hover_index: int = int(hover.get("index", -1)) \
		if str(hover.get("kind", "")) == "choice" else -1
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var box: Rect2 = choice_rect(rect, i)
		var enabled: bool = bool(choice.get("enabled", false))
		var selected: bool = i == cursor
		if selected or i == hover_index:
			canvas.draw_rect(box, UiTheme.COLOR_SELECTED)
		var label_color: Color = UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM
		if selected and enabled:
			label_color = UiTheme.COLOR_ACCENT
		UiTheme.draw_text(canvas, font, box.position + Vector2(10.0, 24.0),
			str(choice.get("label", "")), label_color, UiTheme.SIZE_TITLE)
		UiTheme.draw_text_right(canvas, font,
			Vector2(box.position.x + box.size.x - 10.0, box.position.y + 24.0),
			str(choice.get("effectLabel", "")),
			UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text(canvas, font, box.position + Vector2(10.0, 46.0),
			str(choice.get("detail", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		if not enabled:
			UiTheme.draw_text(canvas, font, box.position + Vector2(10.0, 62.0),
				str(choice.get("blockedReason", "")), UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)


static func _draw_footer(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var top: float = rect.position.y + rect.size.y - FOOTER_HEIGHT
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + MARGIN, top + 28.0),
		"↑↓ 选做法　回车 执行　点做法行也行",
		UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - MARGIN, top + 28.0),
		"遭遇里没有回头路：迎战、绕开、交涉，总得选一个。",
		UiTheme.COLOR_WARN, UiTheme.SIZE_NORMAL)


static func _array_of(value: Variant) -> Array:
	return value if value is Array else []
