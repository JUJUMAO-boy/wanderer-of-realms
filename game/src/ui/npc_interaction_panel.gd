class_name NpcInteractionPanel
extends RefCounted

## NPC 居民界面的绘制与命中测试（M18）。
##
## 与其它面板同构：只消费 NpcInteractionViewModel 产出的 rows/selected/actions，
## 不做数值加工。版面仿制作台——左列为居民名单，右栏为选中居民详情卡片，
## 右侧下方摆底部动作行（交谈×3 / 送礼 / 雇佣）。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const LIST_WIDTH: float = 420.0
const ROW_HEIGHT: float = 32.0
const ROW_TOP_PAD: float = 4.0
const BACK_BUTTON_TOP: float = 12.0
const DETAIL_TOP: float = 128.0
const DETAIL_LINE_HEIGHT: float = 18.0
const ACTION_TOP: float = 320.0
const ACTION_HEIGHT: float = 26.0
const ACTION_SPACING: float = 6.0


static func draw(
	canvas: CanvasItem, view: Dictionary, rect: Rect2,
	hover: Dictionary = {}, gift_items: Array = []
) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	canvas.draw_rect(rect, UiTheme.COLOR_BG)
	canvas.draw_rect(rect, UiTheme.COLOR_BORDER, false, 1.0)

	_draw_header(canvas, font, view, rect)
	_draw_buttons(canvas, font, view, rect, hover)
	_draw_list(canvas, font, view, rect, hover)
	_draw_detail(canvas, font, view, rect, hover)
	_draw_actions(canvas, font, view, rect, hover)
	_draw_gift_list(canvas, font, view, rect, gift_items)
	_draw_footer(canvas, font, view, rect)


# --- 布局（draw 与 hit_test 共用）---

static func list_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + MARGIN, rect.position.y + HEADER_HEIGHT),
		Vector2(LIST_WIDTH, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


static func detail_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + LIST_WIDTH + MARGIN * 1.5,
			rect.position.y + HEADER_HEIGHT),
		Vector2(rect.size.x - LIST_WIDTH - MARGIN * 2.5, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


static func actions_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + LIST_WIDTH + MARGIN * 1.5, rect.position.y + ACTION_TOP),
		Vector2(rect.size.x - LIST_WIDTH - MARGIN * 2.5, rect.size.y - ACTION_TOP - FOOTER_HEIGHT)
	)


static func _visible_rows(view: Dictionary, list: Rect2) -> Dictionary:
	var rows: Array = view.get("rows", [])
	var cursor: int = int(view.get("residentCursor", 0))
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
	var label: String = "返回城市" if not bool(view.get("hasSelected", false)) else "返回城市"
	var specs: Array = [{"id": "back", "label": label}]
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + BACK_BUTTON_TOP,
		specs
	)


static func _action_rect(rect: Rect2, view: Dictionary, index: int) -> Rect2:
	var area: Rect2 = actions_rect(rect)
	return Rect2(
		Vector2(area.position.x, area.position.y + float(index) * (ACTION_HEIGHT + ACTION_SPACING)),
		Vector2(area.size.x, ACTION_HEIGHT)
	)


# --- 命中测试 ---

static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(view, rect), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": bool(button.get("enabled", true))}
	var index: int = row_at(view, rect, point)
	if index >= 0:
		return {"kind": "row", "index": index, "enabled": true}
	var action_index: int = action_at(view, rect, point)
	if action_index >= 0:
		var actions: Array = view.get("actions", [])
		if action_index < actions.size():
			return {"kind": "action", "index": action_index, "id": str(actions[action_index].get("id", ""))}
	return {}


static func row_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var list: Rect2 = list_rect(rect)
	if not list.has_point(point):
		return -1
	var window: Dictionary = _visible_rows(view, list)
	var offset: int = int((point.y - list.position.y - ROW_TOP_PAD) / ROW_HEIGHT)
	var index: int = offset + int(window["start"])
	if index < 0 or index >= int(window["count"]):
		return -1
	return index


static func action_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var area: Rect2 = actions_rect(rect)
	if not area.has_point(point):
		return -1
	var actions: Array = view.get("actions", [])
	for i in range(actions.size()):
		if _action_rect(rect, view, i).has_point(point):
			return i
	return -1


# --- 绘制 ---

static func _draw_header(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var title: String = "居民与人物（%s）" % str(view.get("subject", ""))
	canvas.draw_string(font, Vector2(rect.position.x + MARGIN, rect.position.y + 34.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20.0, UiTheme.COLOR_TEXT)


static func _draw_buttons(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary) -> void:
	for button in buttons(view, rect):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]), true, hovered)


static func _draw_list(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary) -> void:
	var list: Rect2 = list_rect(rect)
	var window: Dictionary = _visible_rows(view, list)
	var rows: Array = view.get("rows", [])
	for i in range(int(window["start"]), int(window["start"]) + int(window["visible"])):
		if i >= rows.size():
			break
		var row_rect: Rect2 = _row_rect(rect, view, i)
		var row: Dictionary = rows[i]
		var row_hovered: bool = str(hover.get("kind", "")) == "row" and int(hover.get("index", -1)) == i
		canvas.draw_rect(row_rect, UiTheme.COLOR_SELECTED if bool(row.get("selected", false)) \
			else (UiTheme.COLOR_LIST_BG if row_hovered else UiTheme.COLOR_BG))
		var star: String = "*" if bool(row.get("isNamed", false)) else ""
		canvas.draw_string(font, Vector2(row_rect.position.x + 4.0, row_rect.position.y + 15.0),
			"%s%s  %s·%d岁  %s" % [
				star, str(row.get("name", "")), str(row.get("raceName", "")),
				int(row.get("age", 0)), str(row.get("professionName", "")),
			], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0, UiTheme.COLOR_TEXT)
		canvas.draw_string(font, Vector2(list.position.x + list.size.x - 4.0, row_rect.position.y + 15.0),
			str(row.get("bandLabel", "")), HORIZONTAL_ALIGNMENT_RIGHT, -1.0, 13.0,
			_band_color(str(row.get("band", ""))))


static func _draw_detail(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary) -> void:
	if not bool(view.get("hasSelected", false)):
		canvas.draw_string(font, Vector2(detail_rect(rect).position.x, detail_rect(rect).position.y + 30.0),
			"这座城没有人烟，或还没选到人。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0, UiTheme.COLOR_TEXT)
		return
	var s: Dictionary = view.get("selected", {})
	var x: float = detail_rect(rect).position.x
	var y: float = detail_rect(rect).position.y
	canvas.draw_string(font, Vector2(x, y + 22.0), str(s.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20.0, UiTheme.COLOR_TEXT)
	var lines: Array = [
		" %s · %d岁 · %s（%s）" % [str(s.get("raceName", "")), int(s.get("age", 0)), str(s.get("professionName", "")), str(s.get("category", ""))],
		" 人格：%s" % str(s.get("personalityName", "")),
		"      「%s」" % str(s.get("personalityLine", "")),
		" 好感：%s（%d）" % [str(s.get("bandLabel", "")), int(s.get("affinity", 0))],
	]
	if not str(s.get("faithName", "")).is_empty():
		lines.append(" 信仰：%s" % str(s.get("faithName", "")))
	lines.append(" 雇佣：%s%s" % ["可雇 · 需 %d 铜" % int(s.get("hireCost", 0)) if bool(s.get("hireable", false)) else "不愿受雇",
		(" · 当前随从" if not view.get("currentHire", {}).is_empty() else "")])
	for i in range(lines.size()):
		canvas.draw_string(font, Vector2(x + 4.0, y + 44.0 + float(i) * DETAIL_LINE_HEIGHT),
			str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0, UiTheme.COLOR_TEXT)


static func _draw_actions(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary) -> void:
	var actions: Array = view.get("actions", [])
	if int(view.get("actionCursor", -1)) < 0:
		return
	for i in range(actions.size()):
		var r: Rect2 = _action_rect(rect, view, i)
		var action: Dictionary = actions[i]
		var hovered: bool = str(hover.get("kind", "")) == "action" and int(hover.get("index", -1)) == i
		canvas.draw_rect(r, UiTheme.COLOR_SELECTED if bool(action.get("selected", false)) \
			else (UiTheme.COLOR_LIST_BG if hovered else UiTheme.COLOR_BG))
		var enabled: bool = bool(action.get("can", true))
		canvas.draw_string(font, Vector2(r.position.x + 4.0, r.position.y + 15.0),
			str(action.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0,
			UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM)


static func _draw_gift_list(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, gift_items: Array) -> void:
	if not bool(view.get("choosingGift", false)):
		return
	var area: Rect2 = actions_rect(rect)
	var y: float = area.position.y + 8.0
	canvas.draw_string(font, Vector2(area.position.x, y + 18.0), "送哪件？（◀▶ 换 · 回车送）",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13.0, UiTheme.COLOR_TEXT)
	for i in range(gift_items.size()):
		var item: Dictionary = gift_items[i]
		var row_y: float = y + 34.0 + float(i) * ROW_HEIGHT
		canvas.draw_rect(Rect2(Vector2(area.position.x, row_y), Vector2(area.size.x, ROW_HEIGHT - 4.0)),
			UiTheme.COLOR_SELECTED if i == int(view.get("giftCursor", 0)) else UiTheme.COLOR_BG)
		canvas.draw_string(font, Vector2(area.position.x + 4.0, row_y + 15.0),
			"%s  %s" % [str(item.get("displayName", "")), str(item.get("taste", ""))],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0, UiTheme.COLOR_TEXT)


static func _draw_footer(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var text: String = str(view.get("footer", ""))
	if text.is_empty():
		return
	canvas.draw_string(font,
		Vector2(rect.position.x + MARGIN, rect.position.y + rect.size.y - FOOTER_HEIGHT + 26.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13.0, UiTheme.COLOR_DIM)


static func _band_color(band: String) -> Color:
	match band:
		NpcInteractionSystem.BAND_HOSTILE:
			return UiTheme.COLOR_ACCENT
		NpcInteractionSystem.BAND_CLOSE, NpcInteractionSystem.BAND_FRIENDLY:
			return UiTheme.COLOR_UP
		_:
			return UiTheme.COLOR_DIM