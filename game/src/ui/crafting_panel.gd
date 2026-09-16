class_name CraftingPanel
extends RefCounted

## 制作台界面的绘制与命中测试（M15）。
##
## 与其它面板同构：只消费 CraftingViewModel 产出的行与 selected，不做数值加工；
## 所有可点元素的位置由 _row_rect / buttons 产出，draw 与 hit_test 都调它们，
## 于是"画在这里、点在那里"不会发生。
##
## 版面仿商铺 / 铁匠铺（TradePanel）：左列 = 配方行 + 采集行连成一根可导航的
## 列表，右列 = 选中那行的明细（门槛 / 材料清单 / 产物与档位 / 附魔目标），
## 页脚一句说明。制造与采集的"做完会怎样"都在出现下手前先给出。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const LIST_WIDTH: float = 430.0
const ROW_HEIGHT: float = 34.0
const ROW_TOP_PAD: float = 4.0
const BACK_BUTTON_TOP: float = 12.0
const BACK_BUTTON_RESERVE: float = 16.0
const DETAIL_TOP: float = 132.0
const DETAIL_LINE_HEIGHT: float = 20.0


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


# --- 布局（draw 与 hit_test 共用）---

## 左列：配方 / 采集行。
static func list_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + MARGIN, rect.position.y + HEADER_HEIGHT),
		Vector2(LIST_WIDTH, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


## 右列：选中那行的明细。
static func detail_rect(rect: Rect2) -> Rect2:
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


## 右上角按钮：只有「返回地图」这一个锚点——制作与采集都在左列行上回车执行，
## 不再单列"制造"按钮（做不做看那一行 enable 与否）。
static func buttons(view: Dictionary, rect: Rect2) -> Array:
	var specs: Array = [{"id": "back", "label": "返回地图"}]
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

## 返回的 kind：button / row（index）。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(view, rect), point)
	if not button.is_empty():
		return {
			"kind": "button", "id": str(button["id"]),
			"enabled": bool(button.get("enabled", true)),
		}
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


static func _row_enabled(view: Dictionary, index: int) -> bool:
	var rows: Array = view.get("rows", [])
	if index < 0 or index >= rows.size():
		return false
	return bool(rows[index].get("enabled", true))


# --- 绘制：抬头与按钮 ---

static func _draw_header(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	UiTheme.draw_panel_header(canvas, font, rect, {
		"left": MARGIN,
		"title": "制作台",
		"titleY": 30.0,
		"titleColor": UiTheme.COLOR_ACCENT,
		"subtitle": "采得的材料，在这里变成用得上的货——熟练越高，做出的装备也越好。",
		"subtitleY": 56.0,
		"subtitleColor": UiTheme.COLOR_DIM,
		"hint": "↑↓ 选配方 / 采集    回车 制作 / 采集    ESC 或 T 返回地图",
		"hintY": 56.0,
		"hintRightX": _button_left(view, rect) - BACK_BUTTON_RESERVE,
		"hintColor": UiTheme.COLOR_DIM,
		"lineY": HEADER_HEIGHT - 8.0,
	})
	# 稀有度标签是标题行上的第二枚左排元素，config 只有一个标题位，保持原样单独画。
	UiTheme.draw_text(canvas, font, Vector2(left + 74.0, top + 30.0),
		str(view.get("craftRarityLabel", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_TITLE)


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
			"这个世界还没有配置任何配方。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return

	var cursor: int = int(view.get("cursor", 0))
	var window: Dictionary = _visible_rows(view, list)
	var last: int = mini(rows.size(), int(window["start"]) + int(window["visible"]))
	# 分隔线：配方与采集之间画一根，区别"做成货"与"采原料"两类活计。
	var gather_split: int = rows.size() - int((view.get("gather", []) as Array).size())
	for index in range(int(window["start"]), last):
		if index == gather_split and index > 0:
			var line_y: float = _row_rect(rect, view, index).position.y - 2.0
			canvas.draw_line(
				Vector2(list.position.x + 8.0, line_y),
				Vector2(list.position.x + list.size.x - 8.0, line_y),
				UiTheme.COLOR_BORDER, 1.0
			)
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
			Vector2(list.position.x + list.size.x - 6.0, list.position.y + list.size.y - 4.0),
			"%d / %d 行（↑↓ 移动）" % [cursor + 1, rows.size()],
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2, selected: bool
) -> void:
	var enabled: bool = bool(row.get("enabled", true))
	var name_color: Color = UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM
	var is_gather: bool = str(row.get("kind", "")) == CraftingViewModel.KIND_GATHER
	var tag: String = str(row.get("skillLabel", "")) if not is_gather else "采集"
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 8.0, rect.position.y + 19.0),
		"[%s]" % tag, UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 19.0),
		str(row.get("displayName", "")), name_color, UiTheme.SIZE_NORMAL)

	if not is_gather:
		var gate_text: String = "L%d/%d" % [int(row.get("skillLevel", 0)), int(row.get("requiredLevel", 0))]
		var gate_ok: bool = bool(row.get("gate", false))
		UiTheme.draw_text_right(canvas, font,
			Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 19.0),
			gate_text, UiTheme.COLOR_UP if gate_ok else UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)
		UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 33.0),
			str(row.get("outputText", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		if selected and not enabled:
			UiTheme.draw_text_right(canvas, font,
				Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 33.0),
				str(row.get("reason", "做不了")), UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)
	else:
		UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 33.0),
			str(row.get("outputText", "")), UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM,
			UiTheme.SIZE_SMALL)


# --- 绘制：右列 ---

static func _draw_detail(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var column: Rect2 = detail_rect(rect)
	canvas.draw_rect(column, UiTheme.COLOR_LIST_BG)
	var selected: Dictionary = view.get("selected", {})
	if selected.is_empty():
		UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
			"左边选一行，这里写它要什么、做出什么。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return

	var x: float = column.position.x + 12.0
	var y: float = column.position.y + DETAIL_TOP - 26.0
	var enabled: bool = bool(selected.get("enabled", true))
	UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
		str(selected.get("displayName", "")),
		UiTheme.COLOR_ACCENT if enabled else UiTheme.COLOR_DIM, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 50.0),
		str(selected.get("outputText", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_SMALL)

	canvas.draw_line(Vector2(x, y),
		Vector2(column.position.x + column.size.x - 12.0, y),
		UiTheme.COLOR_BORDER, 1.0)
	y += DETAIL_LINE_HEIGHT

	var is_gather: bool = str(selected.get("kind", "")) == CraftingViewModel.KIND_GATHER
	if is_gather:
		UiTheme.draw_text(canvas, font, Vector2(x, y),
			"技能：%s    在野外也能做同样的事（地图按 F）。" % str(selected.get("skillLabel", "")),
			UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		y += DETAIL_LINE_HEIGHT * 2
	else:
		UiTheme.draw_text(canvas, font, Vector2(x, y),
			"熟练 %d / 门槛 %d" % [
				int(selected.get("skillLevel", 0)), int(selected.get("requiredLevel", 0)),
			],
			UiTheme.COLOR_TEXT if bool(selected.get("gate", false)) else UiTheme.COLOR_WARN,
			UiTheme.SIZE_NORMAL)
		y += DETAIL_LINE_HEIGHT

		UiTheme.draw_text(canvas, font, Vector2(x, y),
			"材料：", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		y += DETAIL_LINE_HEIGHT
		var materials: Array = selected.get("materials", [])
		for mat in materials:
			var short: bool = bool(mat.get("short", false))
			UiTheme.draw_text(canvas, font, Vector2(x + 12.0, y),
				"%s  %d / %d" % [
					str(mat.get("displayName", "")), int(mat.get("have", 0)), int(mat.get("need", 0)),
				],
				UiTheme.COLOR_WARN if short else UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
			y += DETAIL_LINE_HEIGHT

		if str(selected.get("kind", "")) == "enchant":
			if bool(selected.get("hasTarget", false)):
				UiTheme.draw_text(canvas, font, Vector2(x, y + 4.0),
					"目标：%s（作用 %s）" % [
						str(selected.get("targetName", "")), str(selected.get("affected", "")),
					],
					UiTheme.COLOR_UP, UiTheme.SIZE_SMALL)
			else:
				UiTheme.draw_text(canvas, font, Vector2(x, y + 4.0),
					"背包里没有可附魔的目标。", UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)

		if not enabled:
			y += 12.0 if str(selected.get("kind", "")) == "enchant" else 0.0
			UiTheme.draw_text(canvas, font, Vector2(x, y),
				str(selected.get("reason", "做不了")), UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)


# --- 绘制：页脚 ---

static func _draw_footer(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y + rect.size.y - FOOTER_HEIGHT
	var width: float = rect.size.x - MARGIN * 2.0
	canvas.draw_line(Vector2(left, top), Vector2(left + width, top), UiTheme.COLOR_BORDER, 1.0)
	UiTheme.draw_text(canvas, font, Vector2(left, top + 28.0),
		"采得料、做成货。附魔需要粉尘与一件能附的装备。",
		UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)