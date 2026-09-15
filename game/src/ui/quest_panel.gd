class_name QuestPanel
extends RefCounted

## 委托界面的绘制与命中测试。
##
## 与其它面板同构：只消费 QuestViewModel 产出的行与详情，不做数值加工；所有可点
## 元素的位置由 _row_rect / _branch_rect / buttons 产出，draw 与 hit_test 都调它们，
## "画在这里、点在那里"因此不会发生。
##
## 左列一单一行（可接的、手上没办完的），右列是选中那张的详情：谁贴的、为什么贴、
## 剧本里的关键对白、办成了会怎样。抉择（MODE_BRANCH）换掉右列，把选项与各自后果
## 摊开——一行一个选择，后果直接写在那一行上。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const LIST_WIDTH: float = 430.0
const ROW_HEIGHT: float = 34.0
const BRANCH_HEIGHT: float = 62.0
const ROW_TOP_PAD: float = 4.0
const BACK_BUTTON_TOP: float = 12.0
const BACK_BUTTON_RESERVE: float = 16.0
const DIALOGUE_TOP: float = 216.0
const DIALOGUE_LINE_HEIGHT: float = 20.0


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
	if int(view.get("mode", QuestViewModel.MODE_BOARD)) == QuestViewModel.MODE_BRANCH:
		_draw_branches(canvas, font, view, rect, hover)
	else:
		_draw_detail(canvas, font, view, rect)
	_draw_footer(canvas, font, view, rect)


# --- 布局（draw 与 hit_test 共用）---

## 左列：委托列表。
static func list_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + MARGIN, rect.position.y + HEADER_HEIGHT),
		Vector2(LIST_WIDTH, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


## 右列：详情或抉择，两者占同一块位置。
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


## 抉择行的矩形。抉择占满右列，所以它不需要滚动窗口：选项最多 5 个，
## 5 × 62 = 310 < 右列高度。
static func _branch_rect(rect: Rect2, index: int) -> Rect2:
	var column: Rect2 = column_rect(rect)
	return Rect2(
		Vector2(column.position.x, column.position.y + 34.0 + float(index) * BRANCH_HEIGHT),
		Vector2(column.size.x, BRANCH_HEIGHT - 8.0)
	)


static func buttons(view: Dictionary, rect: Rect2) -> Array:
	var specs: Array = [{"id": "back", "label": "返回地图"}]
	if int(view.get("mode", QuestViewModel.MODE_BOARD)) == QuestViewModel.MODE_BRANCH:
		specs = [{"id": "cancel", "label": "再想想"}, {"id": "back", "label": "返回地图"}]
	elif bool(view.get("selectedIsActive", false)):
		# 手上这张不想要了。接单上限是硬的，没有这条出口，"先办掉几张"就是一句
		# 玩家做不到的话——放弃不扣声誉（账是交付时才结的），只是把名额腾出来。
		specs = [{"id": "abandon", "label": "放弃这张"}, {"id": "back", "label": "返回地图"}]
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


# --- 命中测试 ---

## 返回的 kind：button / row（index）/ branch（index）。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(view, rect), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": true}
	if int(view.get("mode", QuestViewModel.MODE_BOARD)) == QuestViewModel.MODE_BRANCH:
		var branch_index: int = branch_at(view, rect, point)
		if branch_index >= 0:
			return {"kind": "branch", "index": branch_index, "enabled": true}
		return {}
	var index: int = row_at(view, rect, point)
	if index >= 0:
		return {"kind": "row", "index": index, "enabled": _row_enabled(view, index)}
	return {}


static func row_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var list: Rect2 = list_rect(rect)
	var window: Dictionary = _visible_rows(view, list)
	var last: int = mini(int(window["count"]), int(window["start"]) + int(window["visible"]))
	for index in range(int(window["start"]), last):
		if _row_rect(rect, view, index).has_point(point):
			return index
	return -1


## 抉择模式下点到了第几个选项。面板外的调用方也要能用（主场景按序号执行），
## 所以它不只服务于 hit_test。
static func branch_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var branches: Array = view.get("branches", [])
	for index in range(branches.size()):
		if _branch_rect(rect, index).has_point(point):
			return index
	return -1


static func _row_enabled(view: Dictionary, index: int) -> bool:
	var rows: Array = view.get("rows", [])
	if index < 0 or index >= rows.size():
		return false
	return bool(rows[index].get("enabled", true))


# --- 绘制：表头与按钮 ---

static func _draw_header(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	var width: float = rect.size.x - MARGIN * 2.0
	UiTheme.draw_text(canvas, font, Vector2(left, top + 30.0),
		"委托", UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, Vector2(left + 62.0, top + 30.0),
		str(view.get("cityLabel", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_TITLE)

	var here: bool = bool(view.get("atCity", false))
	var position_text: String = "你就站在这座城" if here else "你不在这座城"
	UiTheme.draw_text(canvas, font, Vector2(left, top + 56.0),
		"%s · 手上有 %d / %d 张" % [
			position_text, int(view.get("activeCount", 0)), int(view.get("maxAccepted", 0))
		],
		UiTheme.COLOR_TEXT if here else UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(_button_left(view, rect) - BACK_BUTTON_RESERVE, top + 56.0),
		"←→ 换城市    ↑↓ 选单子    回车 接受 / 办理    Del 放弃", UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

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
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]), true, hovered)


# --- 绘制：左列 ---

static func _draw_list(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var list: Rect2 = list_rect(rect)
	canvas.draw_rect(list, UiTheme.COLOR_LIST_BG)
	var rows: Array = view.get("rows", [])
	if rows.is_empty():
		UiTheme.draw_text(canvas, font, list.position + Vector2(10.0, 26.0),
			"这座城的告示板上空着——城里的各项都还过得去。",
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
			"%d / %d 条（↑↓ 移动）" % [cursor + 1, rows.size()],
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2, selected: bool
) -> void:
	var active: bool = str(row.get("kind", "")) == QuestViewModel.ROW_KIND_ACTIVE
	var enabled: bool = bool(row.get("enabled", true))
	var badge_color: Color = UiTheme.COLOR_ACCENT if active else UiTheme.COLOR_UP
	if not enabled:
		badge_color = UiTheme.COLOR_WARN

	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 8.0, rect.position.y + 19.0),
		"[%s]" % ("已接" if active else "可接"), badge_color, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 19.0),
		str(row.get("title", "")), UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM,
		UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 19.0),
		str(row.get("cityLabel", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 33.0),
		str(row.get("giverLabel", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	if selected:
		UiTheme.draw_text_right(canvas, font,
			Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 33.0),
			str(row.get("deadlineLabel", "")), UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)


# --- 绘制：右列详情 ---

static func _draw_detail(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var column: Rect2 = column_rect(rect)
	canvas.draw_rect(column, UiTheme.COLOR_LIST_BG)
	var selected: Dictionary = view.get("selected", {})
	if selected.is_empty():
		UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
			"左边选一张单子，这里写它的来龙去脉。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return

	var x: float = column.position.x + 12.0
	var y: float = column.position.y + 26.0
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		"%s（%s）" % [str(selected.get("title", "")), str(selected.get("scriptRef", ""))],
		UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	y += 26.0
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		"%s 委托 · %s" % [str(selected.get("giverLabel", "")), str(selected.get("reason", ""))],
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	y += 22.0
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		str(selected.get("summary", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	y += 24.0
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		"%s · %s" % [str(selected.get("deadlineLabel", "")), str(selected.get("detail", ""))],
		UiTheme.COLOR_TEXT, UiTheme.SIZE_SMALL)
	y += 22.0
	var blocked: String = str(selected.get("blockedReason", ""))
	if not blocked.is_empty():
		UiTheme.draw_text(canvas, font, Vector2(x, y), blocked,
			UiTheme.COLOR_WARN, UiTheme.SIZE_NORMAL)

	var dialogue: Array = selected.get("dialogue", [])
	if dialogue.is_empty():
		return
	canvas.draw_line(Vector2(x, column.position.y + DIALOGUE_TOP - 16.0),
		Vector2(column.position.x + column.size.x - 12.0, column.position.y + DIALOGUE_TOP - 16.0),
		UiTheme.COLOR_BORDER, 1.0)
	for i in range(dialogue.size()):
		UiTheme.draw_text(canvas, font,
			Vector2(x, column.position.y + DIALOGUE_TOP + float(i) * DIALOGUE_LINE_HEIGHT),
			str(dialogue[i]), UiTheme.COLOR_TEXT if i % 2 == 0 else UiTheme.COLOR_DIM,
			UiTheme.SIZE_NORMAL)


# --- 绘制：右列抉择 ---

static func _draw_branches(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var column: Rect2 = column_rect(rect)
	canvas.draw_rect(column, UiTheme.COLOR_LIST_BG)
	var branches: Array = view.get("branches", [])
	var selected: Dictionary = view.get("selected", {})
	UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 24.0),
		"「%s」怎么办？" % str(selected.get("title", "")),
		UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	if branches.is_empty():
		UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 54.0),
			"要回到委托所在的城市才能办理。", UiTheme.COLOR_WARN, UiTheme.SIZE_NORMAL)
		return

	for index in range(branches.size()):
		var branch_rect: Rect2 = _branch_rect(rect, index)
		var hovered: bool = str(hover.get("kind", "")) == "branch" \
			and int(hover.get("index", -1)) == index
		canvas.draw_rect(branch_rect, UiTheme.COLOR_SELECTED if hovered else Color(0, 0, 0, 0.25))
		canvas.draw_rect(branch_rect, UiTheme.COLOR_BORDER, false, 1.0)
		var branch: Dictionary = branches[index]
		UiTheme.draw_text(canvas, font,
			Vector2(branch_rect.position.x + 10.0, branch_rect.position.y + 20.0),
			str(branch.get("label", "")),
			UiTheme.COLOR_WARN if bool(branch.get("isCombat", false)) else UiTheme.COLOR_TEXT,
			UiTheme.SIZE_NORMAL)
		UiTheme.draw_text_right(canvas, font,
			Vector2(branch_rect.position.x + branch_rect.size.x - 10.0,
				branch_rect.position.y + 20.0),
			str(branch.get("effectLabel", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_SMALL)
		UiTheme.draw_text(canvas, font,
			Vector2(branch_rect.position.x + 10.0, branch_rect.position.y + 40.0),
			str(branch.get("detail", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


# --- 绘制：页脚 ---

static func _draw_footer(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y + rect.size.y - FOOTER_HEIGHT
	var width: float = rect.size.x - MARGIN * 2.0
	canvas.draw_line(Vector2(left, top), Vector2(left + width, top),
		UiTheme.COLOR_BORDER, 1.0)
	var selected: Dictionary = view.get("selected", {})
	var text: String = "↑↓ 选一张单子，回车接受或办理；办完的后果在月末结算时落到城市上。"
	if int(view.get("mode", QuestViewModel.MODE_BOARD)) == QuestViewModel.MODE_BRANCH:
		text = "↑↓ 选一个做法，回车执行。灰色选项钱更多，代价记在声誉与善恶上。"
	elif bool(selected.get("canAccept", false)):
		text = "回车接受这张委托——接下之后要回到%s办理。" % str(view.get("cityLabel", ""))
	elif bool(view.get("selectedIsActive", false)):
		text = "回车选一个做法交付；Del 放弃这张（不扣声誉，但名额腾给别人）。"
	UiTheme.draw_text(canvas, font, Vector2(left, top + 28.0),
		text, UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
