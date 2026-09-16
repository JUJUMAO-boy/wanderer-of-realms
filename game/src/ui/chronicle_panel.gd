class_name ChroniclePanel
extends RefCounted

## 世界纪年史书的绘制与命中测试（M16）。
##
## 与城中大事面板同构，但只看一件事：左列一条纪年一行（最近在前），右列是选中
## 那条的详情（哪一年、因谁、发生了什么）。它不做任何数值加工，只消费
## ChronicleViewModel 的 rows / selected。可点元素的位置由 _row_rect / buttons 产出，
## draw 与 hit_test 都调它们，"画在这里、点在那里"不会发生。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const LIST_WIDTH: float = 430.0
const ROW_HEIGHT: float = 34.0
const ROW_TOP_PAD: float = 4.0
const BACK_BUTTON_TOP: float = 12.0
const BACK_BUTTON_RESERVE: float = 16.0


static func draw(
	canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}
) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	UiTheme.draw_panel(canvas, rect)

	_draw_header(canvas, font, view, rect)
	_draw_buttons(canvas, font, view, rect, hover)
	_draw_list(canvas, font, view, rect, hover)
	_draw_detail(canvas, font, view, rect)
	_draw_footer(canvas, font, view, rect)


# --- 布局（draw 与 hit_test 共用，同事件面板）---

static func list_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + MARGIN, rect.position.y + HEADER_HEIGHT),
		Vector2(LIST_WIDTH, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


static func column_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + LIST_WIDTH + MARGIN * 1.5,
			rect.position.y + HEADER_HEIGHT),
		Vector2(rect.size.x - LIST_WIDTH - MARGIN * 2.5, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


static func _visible_rows(view: Dictionary, list: Rect2) -> Dictionary:
	var rows: Array = view.get("rows", [])
	var cursor: int = int(view.get("cursor", 0))
	var visible: int = maxi(1, int(list.size.y / ROW_HEIGHT))
	var start: int = 0
	if rows.size() > visible:
		start = clampi(cursor - visible + 1, 0, rows.size() - visible)
	return {"start": start, "visible": visible, "count": rows.size()}


static func _row_rect(rect: Rect2, view: Dictionary, index: int) -> Rect2:
	var list: Rect2 = list_rect(rect)
	var window: Dictionary = _visible_rows(view, list)
	var offset: int = index - int(window["start"])
	return Rect2(
		Vector2(list.position.x, list.position.y + ROW_TOP_PAD + float(offset) * ROW_HEIGHT),
		Vector2(list.size.x, ROW_HEIGHT - 4.0)
	)


static func buttons(view: Dictionary, rect: Rect2) -> Array:
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + BACK_BUTTON_TOP,
		[{"id": "back", "label": "返回地图"}]
	)


static func _button_left(view: Dictionary, rect: Rect2) -> float:
	var list: Array = buttons(view, rect)
	if list.is_empty():
		return rect.position.x + rect.size.x - MARGIN
	return (list[0]["rect"] as Rect2).position.x


# --- 命中测试 ---

static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(view, rect), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": true}
	var index: int = row_at(view, rect, point)
	if index >= 0:
		return {"kind": "row", "index": index, "enabled": true}
	return {}


static func row_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var list: Rect2 = list_rect(rect)
	var window: Dictionary = _visible_rows(view, list)
	var last: int = mini(int(window["count"]), int(window["start"]) + int(window["visible"]))
	for index in range(int(window["start"]), last):
		if _row_rect(rect, view, index).has_point(point):
			return index
	return -1


# --- 绘制 ---

static func _draw_header(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	var counts: Dictionary = view.get("counts", {})
	var summary: String = "全史 %d 条 · 大事 %d · 跨档 %d · 转生 %d" % [
		int(view.get("rowCount", 0)),
		int(counts.get(Chronicle.KIND_CITY_EVENT, 0)),
		int(counts.get(Chronicle.KIND_TIER, 0)),
		int(counts.get(Chronicle.KIND_SOUL, 0)),
	]
	UiTheme.draw_panel_header(canvas, font, rect, {
		"left": MARGIN,
		"title": "世界纪年·史书",
		"titleY": 30.0,
		"titleColor": UiTheme.COLOR_ACCENT,
		"subtitle": summary,
		"subtitleY": 56.0,
		"subtitleColor": UiTheme.COLOR_DIM,
		"hint": "↑↓ 翻阅    回车 无操作（只读史书）",
		"hintY": 56.0,
		"hintRightX": _button_left(view, rect) - BACK_BUTTON_RESERVE,
		"hintColor": UiTheme.COLOR_DIM,
		"lineY": HEADER_HEIGHT - 8.0,
	})


static func _draw_buttons(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	for button in buttons(view, rect):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]), true, hovered)


static func _draw_list(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var list: Rect2 = list_rect(rect)
	canvas.draw_rect(list, UiTheme.COLOR_LIST_BG)
	var rows: Array = view.get("rows", [])
	if rows.is_empty():
		UiTheme.draw_text(canvas, font, list.position + Vector2(10.0, 26.0),
			"史书还是空白——这个世界还没出过值得被记住的事。",
			UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return
	var cursor: int = int(view.get("cursor", 0))
	var window: Dictionary = _visible_rows(view, list)
	var last: int = mini(rows.size(), int(window["start"]) + int(window["visible"]))
	for index in range(int(window["start"]), last):
		var row_rect: Rect2 = _row_rect(rect, view, index)
		var hovered: bool = str(hover.get("kind", "")) == "row" \
			and int(hover.get("index", -1)) == index
		if index == cursor:
			canvas.draw_rect(row_rect, UiTheme.COLOR_SELECTED)
		elif hovered:
			canvas.draw_rect(row_rect, Color(UiTheme.COLOR_SELECTED.r, UiTheme.COLOR_SELECTED.g,
				UiTheme.COLOR_SELECTED.b, 0.45))
		_draw_row(canvas, font, rows[index], row_rect, index == cursor)

	if rows.size() > int(window["visible"]):
		UiTheme.draw_text_right(canvas, font,
			Vector2(list.position.x + list.size.x - 6.0,
				list.position.y + list.size.y - 4.0),
			"%d / %d 条（↑↓ 翻阅）" % [cursor + 1, rows.size()],
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _kind_color(kind: String) -> Color:
	match kind:
		Chronicle.KIND_CITY_EVENT:
			return UiTheme.COLOR_DOWN
		Chronicle.KIND_TIER:
			return UiTheme.COLOR_ACCENT
		Chronicle.KIND_SOUL:
			return UiTheme.COLOR_WARN
	return UiTheme.COLOR_DIM


static func _draw_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2, selected: bool
) -> void:
	var badge_color: Color = _kind_color(str(row.get("kind", "")))
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 8.0, rect.position.y + 19.0),
		"[%s]" % str(row.get("kindLabel", "纪事")), badge_color, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 19.0),
		str(row.get("year", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 126.0, rect.position.y + 19.0),
		str(row.get("title", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 19.0),
		str(row.get("cityLabel", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_detail(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var column: Rect2 = column_rect(rect)
	canvas.draw_rect(column, UiTheme.COLOR_LIST_BG)
	var selected: Dictionary = view.get("selected", {})
	if selected.is_empty():
		UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
			"左边翻一条，这里写它的来龙去脉。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return

	var x: float = column.position.x + 12.0
	var y: float = column.position.y + 26.0
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		str(selected.get("title", "")),
		_kind_color(str(selected.get("kind", ""))), UiTheme.SIZE_TITLE)
	y += 26.0
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		"%s · %s" % [str(selected.get("year", "")), str(selected.get("attribution", ""))],
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	y += 24.0
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		str(selected.get("detail", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)


static func _draw_footer(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y + rect.size.y - FOOTER_HEIGHT
	var width: float = rect.size.x - MARGIN * 2.0
	canvas.draw_line(Vector2(left, top), Vector2(left + width, top),
		UiTheme.COLOR_BORDER, 1.0)
	UiTheme.draw_text(canvas, font, Vector2(left, top + 28.0),
		"这是世界的史书，跨代保留。↑↓ 翻阅；按 H 或「返回地图」回到大地图。",
		UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)