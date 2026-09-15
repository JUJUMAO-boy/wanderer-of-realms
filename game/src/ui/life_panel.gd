class_name LifePanel
extends RefCounted

## 世代记录的绘制与命中测试。
##
## 与其它面板同构：只消费 LifeViewModel 产出的行与段落，不做数值加工；可点元素的
## 位置由 _row_rect / buttons 产出，draw 与 hit_test 都调它们，"画在这里、点在那里"
## 因此不会发生。
##
## 右列的功绩段落在分成两栏之前先按高度排一遍（_detail_layout）：一世的功绩有八段、
## 三十来行，塞进一栏会溢出——溢出的部分不会报错，只是看不见，而"看不见"在
## 记录界面上等于信息丢了。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const LIST_WIDTH: float = 430.0
const ROW_HEIGHT: float = 34.0
const ROW_TOP_PAD: float = 4.0
const BACK_BUTTON_TOP: float = 12.0
const BACK_BUTTON_RESERVE: float = 16.0

## 右列排成几栏、栏间距、段落与行的高度。
const DETAIL_COLUMNS: int = 2
const DETAIL_TOP_PAD: float = 6.0
const DETAIL_GAP: float = 14.0
const SECTION_TITLE_HEIGHT: float = 24.0
const SECTION_GAP: float = 10.0
const DETAIL_LINE_HEIGHT: float = 18.0


static func draw(
	canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}
) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	canvas.draw_rect(rect, UiTheme.COLOR_BG)
	canvas.draw_rect(rect, UiTheme.COLOR_BORDER, false, 1.0)

	_draw_header(canvas, font, view, rect)
	_draw_buttons(canvas, font, view, rect, hover)
	_draw_list(canvas, font, view, rect, hover)
	_draw_detail(canvas, font, view, rect)
	_draw_footer(canvas, font, view, rect)


# --- 布局（draw 与 hit_test 共用）---

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


## 按钮排。转生态只有「转生」——这一屏没有"返回地图"可去，那一步没有人可操作。
## 在世时给「结束这一生」与「返回地图」，两者相差一个"再按一次"的确认。
static func buttons(view: Dictionary, rect: Rect2) -> Array:
	var specs: Array = []
	if bool(view.get("canRebirth", false)):
		specs = [{"id": "rebirth", "label": "转生"}]
	elif bool(view.get("canRetire", false)):
		specs = [
			{
				"id": "retire",
				"label": "再按一次就结束这一生" if bool(view.get("retireArmed", false))
					else "结束这一生",
			},
			{"id": "back", "label": "返回地图"},
		]
	else:
		specs = [{"id": "back", "label": "返回地图"}]
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + BACK_BUTTON_TOP,
		specs
	)


static func _button_left(view: Dictionary, rect: Rect2) -> float:
	var list: Array = buttons(view, rect)
	if list.is_empty():
		return rect.position.x + rect.size.x - MARGIN
	return (list[0]["rect"] as Rect2).position.x


## 右列段落的排布：先往第一栏里放，放不下就换第二栏。返回
## [{section, position, width}]，绘制按它画，段落顺序保持不变。
static func _detail_layout(view: Dictionary, rect: Rect2) -> Array:
	var column: Rect2 = column_rect(rect)
	var sections: Array = view.get("sections", [])
	if sections.is_empty() or DETAIL_COLUMNS <= 0:
		return []
	var column_width: float = (column.size.x - DETAIL_GAP * float(DETAIL_COLUMNS - 1)) \
		/ float(DETAIL_COLUMNS)
	var bottom: float = column.position.y + column.size.y - DETAIL_LINE_HEIGHT
	var out: Array = []
	var sub: int = 0
	var y: float = column.position.y + DETAIL_TOP_PAD
	for section in sections:
		var height: float = _section_height(section)
		if sub < DETAIL_COLUMNS - 1 and y + height > bottom:
			sub += 1
			y = column.position.y + DETAIL_TOP_PAD
		out.append({
			"section": section,
			"position": Vector2(
				column.position.x + float(sub) * (column_width + DETAIL_GAP), y
			),
			"width": column_width,
		})
		y += height
	return out


static func _section_height(section: Dictionary) -> float:
	var lines: Array = section.get("lines", [])
	return SECTION_TITLE_HEIGHT + float(lines.size()) * DETAIL_LINE_HEIGHT + SECTION_GAP


# --- 命中测试 ---

## 返回的 kind：button / row（index）。
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


# --- 绘制：表头与按钮 ---

static func _draw_header(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	var width: float = rect.size.x - MARGIN * 2.0
	UiTheme.draw_text(canvas, font, Vector2(left, top + 30.0),
		"世代记录", UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, Vector2(left + 112.0, top + 30.0),
		"已转生 %d 次" % int(view.get("reincarnationCount", 0)),
		UiTheme.COLOR_TEXT, UiTheme.SIZE_TITLE)

	var alive: String = str(view.get("aliveLine", ""))
	UiTheme.draw_text(canvas, font, Vector2(left, top + 56.0),
		alive if not alive.is_empty() else "这一世已经结束，还没有下一世",
		UiTheme.COLOR_TEXT if not alive.is_empty() else UiTheme.COLOR_WARN,
		UiTheme.SIZE_SMALL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(_button_left(view, rect) - BACK_BUTTON_RESERVE, top + 56.0),
		"↑↓ 翻看历代", UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	canvas.draw_line(
		Vector2(left, top + HEADER_HEIGHT - 8.0),
		Vector2(left + width, top + HEADER_HEIGHT - 8.0),
		UiTheme.COLOR_BORDER, 1.0
	)


static func _draw_buttons(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	for button in buttons(view, rect):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]),
			bool(button.get("enabled", true)), hovered)


# --- 绘制：左列 ---

static func _draw_list(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var list: Rect2 = list_rect(rect)
	canvas.draw_rect(list, UiTheme.COLOR_LIST_BG)
	var rows: Array = view.get("rows", [])
	if rows.is_empty():
		UiTheme.draw_text(canvas, font, list.position + Vector2(10.0, 26.0),
			"还没有哪一世走完过。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
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
			"%d / %d 世（↑↓ 移动）" % [cursor + 1, rows.size()],
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2, selected: bool
) -> void:
	var alive: bool = str(row.get("kind", "")) == LifeViewModel.ROW_KIND_ALIVE
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 8.0, rect.position.y + 19.0),
		"[%s]" % ("在世" if alive else "已故"),
		UiTheme.COLOR_UP if alive else UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 19.0),
		str(row.get("title", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 19.0),
		str(row.get("meta", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	if selected:
		UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 33.0),
			str(row.get("detail", "")), UiTheme.COLOR_ACCENT, UiTheme.SIZE_SMALL)


# --- 绘制：右列功绩 ---

static func _draw_detail(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var column: Rect2 = column_rect(rect)
	canvas.draw_rect(column, UiTheme.COLOR_LIST_BG)
	var placed: Array = _detail_layout(view, rect)
	if placed.is_empty():
		UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
			"左边选一世，这里写他这一生留下了什么。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return
	var bottom: float = column.position.y + column.size.y
	for entry in placed:
		var section: Dictionary = entry["section"]
		var position: Vector2 = entry["position"]
		UiTheme.draw_section_title(canvas, font, position + Vector2(0.0, 16.0),
			str(section.get("title", "")), float(entry["width"]))
		var lines: Array = section.get("lines", [])
		for i in range(lines.size()):
			var y: float = position.y + SECTION_TITLE_HEIGHT + float(i) * DETAIL_LINE_HEIGHT + 12.0
			# 栏底之下的行直接不画：那一段放不下时，多画出去只会压到下一段或出界
			if y > bottom:
				break
			UiTheme.draw_text(canvas, font, Vector2(position.x, y),
				str(lines[i]), UiTheme.COLOR_TEXT, UiTheme.SIZE_SMALL)


# --- 绘制：页脚 ---

static func _draw_footer(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y + rect.size.y - FOOTER_HEIGHT
	var width: float = rect.size.x - MARGIN * 2.0
	canvas.draw_line(Vector2(left, top), Vector2(left + width, top),
		UiTheme.COLOR_BORDER, 1.0)
	UiTheme.draw_text(canvas, font, Vector2(left, top + 28.0),
		str(view.get("hint", "")),
		UiTheme.COLOR_WARN if bool(view.get("retireArmed", false)) else UiTheme.COLOR_DIM,
		UiTheme.SIZE_NORMAL)
