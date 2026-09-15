class_name SmugglingPanel
extends RefCounted

## 走私航线界面的绘制与命中测试。
##
## 与其它面板同构：只消费 SmugglingViewModel 产出的行，不做数值加工；所有可点
## 元素的位置由 _row_rect / buttons 产出，draw 与 hit_test 都调它们，于是
## "画在这里、点在那里"不会发生。
##
## 一行就是一件事：己方航线（回车撤销）与候选城市（回车建立）同列，不可建的
## 也列出来并写明原因——只列能建的话，玩家就得靠试错去猜哪条不行。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const ROW_HEIGHT: float = 30.0
const FOOTER_HEIGHT: float = 58.0
const ROW_TOP_PAD: float = 4.0
## 行内各段的横向位置。标签与详情分列左右，中间留白给长城市名。
const BADGE_X: float = 8.0
const LABEL_X: float = 44.0
const BACK_BUTTON_TOP: float = 12.0
const BACK_BUTTON_RESERVE: float = 16.0


static func draw(
	canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}
) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	canvas.draw_rect(rect, UiTheme.COLOR_BG)
	canvas.draw_rect(rect, UiTheme.COLOR_BORDER, false, 1.0)

	_draw_header(canvas, font, view, rect)
	_draw_buttons(canvas, font, rect, hover)
	_draw_rows(canvas, font, view, rect, hover)
	_draw_footer(canvas, font, view, rect)


# --- 布局（draw 与 hit_test 共用）---

static func _rows_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + MARGIN, rect.position.y + HEADER_HEIGHT),
		Vector2(rect.size.x - MARGIN * 2.0, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


static func _visible_window(view: Dictionary, rows_rect: Rect2) -> Dictionary:
	var rows: Array = view.get("rows", [])
	var cursor: int = int(view.get("cursor", 0))
	var visible: int = maxi(1, int(rows_rect.size.y / ROW_HEIGHT))
	var start: int = 0
	if rows.size() > visible:
		start = clampi(cursor - visible + 1, 0, rows.size() - visible)
	return {"start": start, "visible": visible, "count": rows.size()}


static func _row_rect(rect: Rect2, view: Dictionary, index: int) -> Rect2:
	var rows_rect: Rect2 = _rows_rect(rect)
	var window: Dictionary = _visible_window(view, rows_rect)
	var offset: int = index - int(window["start"])
	return Rect2(
		Vector2(rows_rect.position.x, rows_rect.position.y + ROW_TOP_PAD + float(offset) * ROW_HEIGHT),
		Vector2(rows_rect.size.x, ROW_HEIGHT - 4.0)
	)


static func buttons(rect: Rect2) -> Array:
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + BACK_BUTTON_TOP,
		[{"id": "back", "label": "返回地图"}]
	)


static func _button_left(rect: Rect2) -> float:
	var list: Array = buttons(rect)
	if list.is_empty():
		return rect.position.x + rect.size.x - MARGIN
	return (list[0]["rect"] as Rect2).position.x


# --- 命中测试 ---

## 返回的 kind：button / row（index，行号）。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(rect), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": true}
	var index: int = row_at(view, rect, point)
	if index >= 0:
		return {"kind": "row", "index": index, "enabled": _row_enabled(view, index)}
	return {}


## 面板外的调用方也要能算"点到第几行"（主场景按行执行动作）。
static func row_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var rows_rect: Rect2 = _rows_rect(rect)
	var window: Dictionary = _visible_window(view, rows_rect)
	var last: int = mini(int(window["count"]), int(window["start"]) + int(window["visible"]))
	for index in range(int(window["start"]), last):
		if _row_rect(rect, view, index).has_point(point):
			return index
	return -1


static func _row_enabled(view: Dictionary, index: int) -> bool:
	var rows: Array = view.get("rows", [])
	if index < 0 or index >= rows.size():
		return false
	return bool(rows[index].get("enabled", true))


# --- 绘制 ---

static func _draw_header(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	var width: float = rect.size.x - MARGIN * 2.0
	UiTheme.draw_text(canvas, font, Vector2(left, top + 30.0),
		"走私航线", UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, Vector2(left + 118.0, top + 30.0),
		str(view.get("cityLabel", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_TITLE)

	var market: String = "有黑市渠道" if bool(view.get("hasBlackMarket", false)) else "无黑市渠道"
	UiTheme.draw_text(canvas, font, Vector2(left, top + 56.0),
		"治安 %d · %s · 本地查抄 %d%%/月" % [
			int(view.get("citySecurity", 0)), market,
			int(view.get("cityConfiscationPercent", 0)),
		], UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(_button_left(rect) - BACK_BUTTON_RESERVE, top + 56.0),
		"←→ 换城市    ↑↓ 选条目    回车 执行", UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	canvas.draw_line(
		Vector2(left, top + HEADER_HEIGHT - 8.0),
		Vector2(left + width, top + HEADER_HEIGHT - 8.0),
		UiTheme.COLOR_BORDER, 1.0
	)


static func _draw_buttons(
	canvas: CanvasItem, font: Font, rect: Rect2, hover: Dictionary
) -> void:
	for button in buttons(rect):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]), true, hovered)


static func _draw_rows(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var rows: Array = view.get("rows", [])
	var rows_rect: Rect2 = _rows_rect(rect)
	if rows.is_empty():
		UiTheme.draw_text(canvas, font, rows_rect.position + Vector2(8.0, 24.0),
			"这片大陆上没有可开通走私航线的城市。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return
	var cursor: int = int(view.get("cursor", 0))
	var window: Dictionary = _visible_window(view, rows_rect)
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
			Vector2(rows_rect.position.x + rows_rect.size.x - 6.0,
				rows_rect.position.y + rows_rect.size.y + 14.0),
			"%d / %d 条（↑↓ 移动）" % [cursor + 1, rows.size()],
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2, selected: bool
) -> void:
	var kind: String = str(row.get("kind", ""))
	var enabled: bool = bool(row.get("enabled", true))
	var badge_color: Color = UiTheme.COLOR_DIM
	if not enabled:
		badge_color = UiTheme.COLOR_DIM
	elif kind == SmugglingViewModel.ROW_KIND_CANCEL:
		badge_color = UiTheme.COLOR_ACCENT
	else:
		badge_color = UiTheme.COLOR_UP

	var y: float = rect.position.y + 18.0
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + BADGE_X, y),
		"[%s]" % str(row.get("actionLabel", "")), badge_color, UiTheme.SIZE_SMALL)

	var label: String = str(row.get("label", ""))
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + LABEL_X, y),
		label, UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)

	var detail: String = str(row.get("detail", ""))
	var detail_color: Color = UiTheme.COLOR_DIM
	if not enabled:
		detail_color = UiTheme.COLOR_WARN
	elif selected:
		detail_color = UiTheme.COLOR_TEXT
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - 10.0, y), detail, detail_color, UiTheme.SIZE_SMALL)


static func _draw_footer(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y + rect.size.y - FOOTER_HEIGHT
	var width: float = rect.size.x - MARGIN * 2.0
	canvas.draw_line(Vector2(left, top), Vector2(left + width, top),
		UiTheme.COLOR_BORDER, 1.0)

	var owned: int = int(view.get("ownedCount", 0))
	UiTheme.draw_text(canvas, font, Vector2(left, top + 22.0),
		"你建的走私航线 %d 条，月入合计 %s" % [
			owned, AvatarViewModel.money_label(int(view.get("ownedIncome", 0)))
		],
		UiTheme.COLOR_ACCENT if owned > 0 else UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text(canvas, font, Vector2(left, top + 42.0),
		"航线被查抄则当月不进账，并扣该城声誉 %d、善恶 %d——只有你自己的航线会算在你头上" % [
			int(view.get("reputationLoss", 0)), int(view.get("karmaLoss", 0))
		], UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	UiTheme.draw_text_right(canvas, font, Vector2(left + width, top + 22.0),
		"每城最多 %d 条" % int(view.get("maxPerCity", 0)),
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
