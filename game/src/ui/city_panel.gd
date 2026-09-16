class_name CityPanel
extends RefCounted

## 城市状态面板的绘制（M6.3）。
##
## 全部是静态函数，不继承 Node：主场景在 _draw 里调 CityPanel.draw(self, ...)
## 就行。面板不需要自己的节点生命周期，拆成节点只会多一层转发。
##
## 画的是 CityViewModel 产出的结构，本类不做任何数值加工——这样"面板该显示
## 什么"与"怎么画出来"各自独立，前者能被无头测试覆盖，后者只能目视确认。

const MARGIN: float = 14.0
const LIST_WIDTH: float = 216.0
const LIST_ROW_HEIGHT: float = 56.0
## 详情栏的起始纵坐标（相对面板顶）。必须让开顶部标题带，否则详情栏的
## 城市名会压到标题带的长月历上——两者分别从 x=246 与 x=138 起笔，只差 6px 就交叠。
const HEADER_HEIGHT: float = 48.0
const DIM_ROW_HEIGHT: float = 42.0
const TREND_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 30.0
## 建筑条（D-69~D-72）：详情栏底部的一行横铺瓦片，一座建筑一格，点选后回车投资。
const BUILDING_TILE_HEIGHT: float = 24.0
const BUILDING_LABEL_WIDTH: float = 44.0
const BUILDING_TILE_GAP: float = 4.0

## 趋势维度切换器。左右各一个小方块夹住维度名，点一下换一个维度。
const TREND_STEPPER_SIZE: float = 20.0
const TREND_LABEL_X: float = 28.0
const TREND_NEXT_X: float = 200.0
const TREND_NOTE_X: float = 232.0
const BACK_BUTTON_TOP: float = 12.0
const BACK_BUTTON_RESERVE: float = 16.0

## 配色与字号统一在 UiTheme 里定义，这里只做别名：面板内的引用不用改，
## 也不会出现第二份会漂移的色板。
const COLOR_BG: Color = UiTheme.COLOR_BG
const COLOR_LIST_BG: Color = UiTheme.COLOR_LIST_BG
const COLOR_SELECTED: Color = UiTheme.COLOR_SELECTED
const COLOR_BORDER: Color = UiTheme.COLOR_BORDER
const COLOR_TEXT: Color = UiTheme.COLOR_TEXT
const COLOR_DIM: Color = UiTheme.COLOR_DIM
const COLOR_UP: Color = UiTheme.COLOR_UP
const COLOR_DOWN: Color = UiTheme.COLOR_DOWN
const COLOR_BAR_BG: Color = UiTheme.COLOR_BAR_BG
const COLOR_BAR: Color = UiTheme.COLOR_BAR
const COLOR_BAR_LOW: Color = UiTheme.COLOR_BAR_LOW
const COLOR_ACCENT: Color = UiTheme.COLOR_ACCENT
const COLOR_WARN: Color = UiTheme.COLOR_WARN
const COLOR_LINE: Color = UiTheme.COLOR_LINE

const SIZE_TITLE: int = UiTheme.SIZE_TITLE
const SIZE_NORMAL: int = UiTheme.SIZE_NORMAL
const SIZE_SMALL: int = UiTheme.SIZE_SMALL


## panel 结构：
##   { monthLabel: String, list: Array, detail: Dictionary, selectedIndex: int }
## hover 是 hit_test 上一次的结果，只用来高亮。
static func draw(
	canvas: CanvasItem, panel: Dictionary, rect: Rect2, hover: Dictionary = {}
) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null:
		return
	canvas.draw_rect(rect, COLOR_BG)
	canvas.draw_rect(rect, COLOR_BORDER, false, 1.0)

	var list_rect := Rect2(rect.position, Vector2(LIST_WIDTH, rect.size.y))
	canvas.draw_rect(list_rect, COLOR_LIST_BG)

	_draw_header(canvas, font, panel, rect, hover)
	_draw_list(canvas, font, panel, list_rect, hover)
	_draw_buttons(canvas, font, rect, hover)
	var detail: Dictionary = panel.get("detail", {})
	if detail.is_empty():
		return
	var detail_rect := Rect2(
		rect.position + Vector2(LIST_WIDTH + MARGIN, 0.0),
		Vector2(rect.size.x - LIST_WIDTH - MARGIN * 2.0, rect.size.y)
	)
	_draw_detail(canvas, font, detail, detail_rect, hover)


# --- 布局（draw 与 hit_test 共用）---

## 顶部右侧的入口按钮。城市面板上的功能入口排左边，「返回地图」留在最右——它是各
## 视图共有的锚点，位置不随本面板多出几个入口而漂移。
static func buttons(rect: Rect2) -> Array:
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + BACK_BUTTON_TOP,
		[
			{"id": "shop", "label": "商铺"},
			{"id": "event", "label": "城中大事"},
			{"id": "quest", "label": "委托板"},
			{"id": "residents", "label": "居民与人物"},
			{"id": "smuggling", "label": "走私航线"},
			{"id": "back", "label": "返回地图"},
		]
	)


static func _button_left(rect: Rect2) -> float:
	var list: Array = buttons(rect)
	if list.is_empty():
		return rect.position.x + rect.size.x - MARGIN
	return (list[0]["rect"] as Rect2).position.x


## 列表里的第 index 行城市。
static func _city_row_rect(rect: Rect2, index: int) -> Rect2:
	var row_y: float = rect.position.y + HEADER_HEIGHT + 2.0 + float(index) * LIST_ROW_HEIGHT
	return Rect2(
		Vector2(rect.position.x + 6.0, row_y),
		Vector2(LIST_WIDTH - 12.0, LIST_ROW_HEIGHT - 6.0)
	)


## 趋势标题行的左右切换器。next 为真给「▶」。坐标是详情栏的局部坐标——
## 绘制时手上就是这两个数，命中测试那边由 _detail_offsets_of 算出来。
static func _trend_stepper_rect(detail_x: float, trend_y: float, next: bool) -> Rect2:
	var x: float = detail_x + (TREND_NEXT_X if next else 0.0)
	return Rect2(Vector2(x, trend_y + 3.0), Vector2(TREND_STEPPER_SIZE, TREND_STEPPER_SIZE))


## 详情栏左侧起始的横坐标（相对面板左边）。
static func _detail_left(rect: Rect2) -> float:
	return rect.position.x + LIST_WIDTH + MARGIN


## 建筑条里第 index 块瓦片的矩形。建筑数量决定宽度：几座建筑就等宽排开，
## 左首留一小段「建筑」标签。
static func _building_tile_rect(rect: Rect2, count: int, index: int) -> Rect2:
	var at: Dictionary = _detail_offsets(rect, 0)
	var y: float = at["buildings"]
	var usable: float = rect.size.x - BUILDING_LABEL_WIDTH
	var tile_w: float = (usable - BUILDING_TILE_GAP * float(count - 1)) / float(count)
	var x: float = rect.position.x + BUILDING_LABEL_WIDTH \
		+ float(index) * (tile_w + BUILDING_TILE_GAP)
	return Rect2(Vector2(x, y), Vector2(tile_w, BUILDING_TILE_HEIGHT))


static func _draw_stepper(
	canvas: CanvasItem, font: Font, rect: Rect2, label: String, hovered: bool
) -> void:
	canvas.draw_rect(rect, COLOR_SELECTED if hovered else COLOR_LIST_BG)
	canvas.draw_rect(rect, COLOR_ACCENT if hovered else COLOR_BORDER, false, 1.0)
	_text_center(canvas, font,
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5 + 4.0),
		label, COLOR_ACCENT if hovered else COLOR_TEXT, SIZE_SMALL)


# --- 命中测试 ---

## 返回的 kind：button / city / dimension（delta 为 −1 或 +1）。
static func hit_test(panel: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if panel.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(rect), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": true}

	if point.x <= rect.position.x + LIST_WIDTH:
		var rows: Array = panel.get("list", [])
		for index in range(rows.size()):
			if _city_row_rect(rect, index).has_point(point):
				return {"kind": "city", "index": index}
		return {}

	if panel.get("detail", {}).is_empty():
		return {}
	var at: Dictionary = _detail_offsets_of(panel, rect)
	var detail_x: float = _detail_left(rect)
	if _trend_stepper_rect(detail_x, at["trend"], false).has_point(point):
		return {"kind": "dimension", "delta": -1}
	if _trend_stepper_rect(detail_x, at["trend"], true).has_point(point):
		return {"kind": "dimension", "delta": 1}
	var buildings: Array = panel.get("detail", {}).get("buildings", [])
	if not buildings.is_empty():
		var building_count: int = buildings.size()
		for index in range(building_count):
			if _building_tile_rect(rect, building_count, index).has_point(point):
				return {"kind": "building", "index": index}
	return {}


static func _draw_buttons(
	canvas: CanvasItem, font: Font, rect: Rect2, hover: Dictionary
) -> void:
	for button in buttons(rect):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]), true, hovered)


static func _draw_header(
	canvas: CanvasItem, font: Font, panel: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	_text(canvas, font, rect.position + Vector2(MARGIN, 26.0),
		"城市状态", COLOR_ACCENT, SIZE_TITLE)
	_text(canvas, font, rect.position + Vector2(MARGIN + 108.0, 26.0),
		str(panel.get("monthLabel", "")), COLOR_DIM, SIZE_NORMAL)
	_text_right(canvas, font,
		Vector2(_button_left(rect) - BACK_BUTTON_RESERVE, 26.0),
		"点城市看详情    ◀▶ 换趋势维度", COLOR_DIM, SIZE_SMALL)
	canvas.draw_line(
		rect.position + Vector2(0.0, HEADER_HEIGHT - 8.0),
		rect.position + Vector2(rect.size.x, HEADER_HEIGHT - 8.0),
		COLOR_BORDER, 1.0
	)


static func _draw_list(
	canvas: CanvasItem, font: Font, panel: Dictionary, list_rect: Rect2, hover: Dictionary
) -> void:
	var list: Array = panel.get("list", [])
	var selected: int = int(panel.get("selectedIndex", 0))
	var hovered_index: int = int(hover.get("index", -1)) \
		if str(hover.get("kind", "")) == "city" else -1
	var y: float = list_rect.position.y + HEADER_HEIGHT + 2.0
	for index in range(list.size()):
		var row: Dictionary = list[index]
		var row_rect := Rect2(
			Vector2(list_rect.position.x + 6.0, y),
			Vector2(list_rect.size.x - 12.0, LIST_ROW_HEIGHT - 6.0)
		)
		if index == selected:
			canvas.draw_rect(row_rect, COLOR_SELECTED)
		elif index == hovered_index:
			canvas.draw_rect(row_rect, Color(COLOR_SELECTED.r, COLOR_SELECTED.g,
				COLOR_SELECTED.b, 0.45))
		canvas.draw_rect(row_rect, COLOR_BORDER, false, 1.0)

		var name_color: Color = COLOR_TEXT
		_text(canvas, font, row_rect.position + Vector2(10.0, 20.0),
			str(row["displayName"]), name_color, SIZE_NORMAL)

		var tier_text: String = "%s · %d 人" % [str(row["tierLabel"]), int(row["npcCount"])]
		_text(canvas, font, row_rect.position + Vector2(10.0, 38.0), tier_text, COLOR_DIM, SIZE_SMALL)

		# 阶段进度条：让"离升阶还差多少"在列表上就能扫到
		var bar_rect := Rect2(
			row_rect.position + Vector2(10.0, 43.0),
			Vector2(row_rect.size.x - 20.0, 3.0)
		)
		canvas.draw_rect(bar_rect, COLOR_BAR_BG)
		var ratio: float = float(row["progressRatio"])
		canvas.draw_rect(
			Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)),
			COLOR_WARN if bool(row["downgradeRisk"]) else COLOR_LINE
		)

		var delta_milli: int = int(row["populationDeltaMilli"])
		if delta_milli != 0:
			var delta_color: Color = COLOR_UP if delta_milli > 0 else COLOR_DOWN
			_text_right(canvas, font,
				row_rect.position + Vector2(row_rect.size.x - 10.0, 20.0),
				"人口 " + str(row["populationDeltaText"]), delta_color, SIZE_SMALL)
		y += LIST_ROW_HEIGHT


## 详情栏各段的纵向位置。绘制与命中测试共用——趋势维度的切换器要靠它定位，
## 而手写一串 "+34 +18 +18 +22…" 的偏移迟早会和实际绘制对不上：那种错法
## 表现为"按钮画在这里、点在那里"，且只在改动版面时才浮现。
static func _detail_offsets(rect: Rect2, row_count: int) -> Dictionary:
	var top: float = rect.position.y + HEADER_HEIGHT
	var tier_y: float = top + 34.0
	var gap_y: float = tier_y + 18.0
	var downgrade_y: float = gap_y + 18.0
	var line_y: float = downgrade_y + 22.0
	var rows_y: float = line_y + 8.0
	var rows_end: float = rows_y + float(row_count) * DIM_ROW_HEIGHT
	var trend_y: float = rows_end + 8.0
	var stats_y: float = trend_y + TREND_HEIGHT
	# 建筑瓦片条：压在统计行下方、面板底之前。统计行文字画在 stats+18，
	# 这里从 stats+24 起笔，留出 6px 才不压字。
	var buildings_y: float = stats_y + 24.0
	return {
		"title": top, "tier": tier_y, "gap": gap_y, "downgrade": downgrade_y,
		"rowsLine": line_y, "rows": rows_y, "rowsEndLine": rows_end,
		"trend": trend_y, "stats": stats_y, "buildings": buildings_y,
	}


static func _detail_offsets_of(panel: Dictionary, rect: Rect2) -> Dictionary:
	var detail: Dictionary = panel.get("detail", {})
	return _detail_offsets(rect, detail.get("rows", []).size())


static func _draw_detail(
	canvas: CanvasItem, font: Font, detail: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var x: float = rect.position.x
	var width: float = rect.size.x
	var rows: Array = detail["rows"]
	var at: Dictionary = _detail_offsets(rect, rows.size())

	_text(canvas, font, Vector2(x, at["title"] + 20.0),
		str(detail["displayName"]), COLOR_TEXT, SIZE_TITLE)
	_text(canvas, font, Vector2(x + 150.0, at["title"] + 20.0),
		str(detail["tierLabel"]), COLOR_ACCENT, SIZE_TITLE)
	_text_right(canvas, font, Vector2(x + width - 6.0, at["title"] + 20.0),
		"本月逐项归因（负号代表拉低）", COLOR_DIM, SIZE_SMALL)

	_text(canvas, font, Vector2(x, at["tier"]), str(detail["tierNextText"]), COLOR_TEXT, SIZE_SMALL)
	var gap_text: String = str(detail["tierGapText"])
	if not gap_text.is_empty():
		_text(canvas, font, Vector2(x, at["gap"]), gap_text, COLOR_DIM, SIZE_SMALL)
	var downgrade: String = str(detail["downgradeText"])
	if not downgrade.is_empty():
		_text(canvas, font, Vector2(x, at["downgrade"]), downgrade, COLOR_WARN, SIZE_SMALL)

	canvas.draw_line(Vector2(x, at["rowsLine"]), Vector2(x + width, at["rowsLine"]),
		COLOR_BORDER, 1.0)

	var row_y: float = at["rows"]
	for row in rows:
		_draw_dimension_row(canvas, font, row, x, row_y, width)
		row_y += DIM_ROW_HEIGHT

	canvas.draw_line(Vector2(x, at["rowsEndLine"]), Vector2(x + width, at["rowsEndLine"]),
		COLOR_BORDER, 1.0)

	_draw_trend(canvas, font, detail, rect, at["trend"], width, TREND_HEIGHT, hover)
	_draw_stats(canvas, font, detail, x, at["stats"], width)
	_draw_buildings(canvas, font, detail, rect, at, hover)


## 建筑条：一行等宽的瓦片，一座建筑一格。绿色描边 = 这座能投资（钱够且未到上限），
## 深色填充 = 运营中，灰字 = 建筑关闭（tier 门槛未过）。点选一块回车即投资。
static func _draw_buildings(
	canvas: CanvasItem, font: Font, detail: Dictionary, rect: Rect2,
	at: Dictionary, hover: Dictionary
) -> void:
	var buildings: Array = detail.get("buildings", [])
	if buildings.is_empty():
		return
	var y: float = at["buildings"]
	_text(canvas, font, Vector2(rect.position.x, y + 7.0), "建筑", COLOR_DIM, SIZE_SMALL)
	var count: int = buildings.size()
	var hovered_index: int = int(hover.get("index", -1)) \
		if str(hover.get("kind", "")) == "building" else -1
	for i in range(count):
		var b: Dictionary = buildings[i]
		var r: Rect2 = _building_tile_rect(rect, count, i)
		var selected: bool = bool(b.get("selected", false))
		if selected or i == hovered_index:
			canvas.draw_rect(r, COLOR_SELECTED)
		else:
			canvas.draw_rect(r, COLOR_LIST_BG)
		var investable: bool = bool(b.get("investEnabled", false))
		var state: String = str(b.get("state", "operational"))
		canvas.draw_rect(
			r,
			COLOR_ACCENT if investable else COLOR_BORDER,
			false, 1.0
		)
		var name_color: Color = COLOR_TEXT if state == "operational" else COLOR_DIM
		_text(canvas, font, r.position + Vector2(4.0, 8.0),
			str(b.get("displayName", "")), name_color, SIZE_SMALL)
		var level_text: String = "L%d" % int(b.get("level", 0))
		if int(b.get("investedLevel", 0)) > 0:
			level_text = "L%d / 投%d" % [int(b.get("level", 0)), int(b.get("investedLevel", 0))]
		_text_right(canvas, font, r.position + Vector2(r.size.x - 4.0, 8.0),
			level_text, COLOR_ACCENT if int(b.get("investedLevel", 0)) > 0 else COLOR_DIM, SIZE_SMALL)


static func _draw_dimension_row(
	canvas: CanvasItem, font: Font, row: Dictionary, x: float, y: float, width: float
) -> void:
	_text(canvas, font, Vector2(x, y + 16.0), str(row["label"]), COLOR_TEXT, SIZE_NORMAL)

	var bar_rect := Rect2(Vector2(x + 66.0, y + 7.0), Vector2(150.0, 10.0))
	canvas.draw_rect(bar_rect, COLOR_BAR_BG)
	var ratio: float = float(row["bar"])
	var fill_color: Color = COLOR_BAR
	if ratio < 0.3:
		fill_color = COLOR_BAR_LOW
	elif ratio > 0.75:
		fill_color = COLOR_UP
	canvas.draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), fill_color)

	_text_right(canvas, font, Vector2(x + 262.0, y + 16.0), str(int(row["value"])), COLOR_TEXT, SIZE_NORMAL)

	var delta_milli: int = int(row["deltaMilli"])
	var delta_color: Color = COLOR_DIM
	if delta_milli > 0:
		delta_color = COLOR_UP
	elif delta_milli < 0:
		delta_color = COLOR_DOWN
	_text_right(canvas, font, Vector2(x + 340.0, y + 16.0), str(row["deltaText"]), delta_color, SIZE_NORMAL)

	var parts: Array = []
	for item in row["items"]:
		parts.append("%s %s" % [str(item["label"]), str(item["text"])])
	_text(canvas, font, Vector2(x + 356.0, y + 16.0),
		" · ".join(PackedStringArray(parts)), COLOR_DIM, SIZE_SMALL)

	var carry_text: String = str(row["carryText"])
	if not carry_text.is_empty():
		_text_right(canvas, font, Vector2(x + width - 6.0, y + 16.0), carry_text, COLOR_DIM, SIZE_SMALL)
	canvas.draw_line(
		Vector2(x, y + DIM_ROW_HEIGHT - 6.0), Vector2(x + width, y + DIM_ROW_HEIGHT - 6.0),
		Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.4), 1.0
	)


static func _draw_trend(
	canvas: CanvasItem, font: Font, detail: Dictionary, rect: Rect2, y: float,
	width: float, height: float, hover: Dictionary
) -> void:
	var x: float = rect.position.x
	var dimension: String = str(detail["trendDimension"])
	var label: String = str(City.DIMENSION_LABELS.get(dimension, dimension))
	var trend: Dictionary = detail["trends"].get(dimension, {})
	var series: Array = detail["history"].get(dimension, [])

	# 维度切换器：维度名夹在 ◀ ▶ 中间，鼠标也能换维度
	var hover_delta: int = int(hover.get("delta", 0)) \
		if str(hover.get("kind", "")) == "dimension" else 0
	_draw_stepper(canvas, font, _trend_stepper_rect(x, y, false), "◀", hover_delta == -1)
	_draw_stepper(canvas, font, _trend_stepper_rect(x, y, true), "▶", hover_delta == 1)
	_text(canvas, font, Vector2(x + TREND_LABEL_X, y + 14.0),
		"趋势 · %s（%d 个月）" % [label, int(detail["historyMonths"])], COLOR_TEXT, SIZE_NORMAL)
	_text(canvas, font, Vector2(x + TREND_NOTE_X, y + 14.0),
		str(trend.get("text", "")), COLOR_DIM, SIZE_SMALL)

	var plot := Rect2(Vector2(x, y + 24.0), Vector2(width, height - 34.0))
	canvas.draw_rect(plot, Color(0.075, 0.082, 0.098, 0.9))
	canvas.draw_rect(plot, COLOR_BORDER, false, 1.0)
	if series.size() < 2:
		_text(canvas, font, plot.position + Vector2(10.0, plot.size.y * 0.5),
			"历史不足两个月，继续推进时间即可看到走势", COLOR_DIM, SIZE_SMALL)
		return

	var low: int = int(trend["min"])
	var high: int = int(trend["max"])
	var span: float = float(maxi(1, high - low))
	var last_index: int = series.size() - 1
	for i in range(last_index):
		var p0: Vector2 = _plot_point(plot, i, last_index, int(series[i]), low, span)
		var p1: Vector2 = _plot_point(plot, i + 1, last_index, int(series[i + 1]), low, span)
		canvas.draw_line(p0, p1, COLOR_LINE, 1.5)
	var head: Vector2 = _plot_point(plot, last_index, last_index, int(series[last_index]), low, span)
	canvas.draw_circle(head, 2.5, COLOR_ACCENT)

	_text(canvas, font, plot.position + Vector2(6.0, 12.0), str(high), COLOR_DIM, SIZE_SMALL)
	_text(canvas, font, plot.position + Vector2(6.0, plot.size.y - 4.0), str(low), COLOR_DIM, SIZE_SMALL)


static func _plot_point(
	plot: Rect2, index: int, last_index: int, value: int, low: int, span: float
) -> Vector2:
	var ratio: float = float(index) / float(maxi(1, last_index))
	var normalized: float = float(value - low) / span
	return Vector2(
		plot.position.x + 24.0 + ratio * (plot.size.x - 34.0),
		plot.position.y + plot.size.y - 6.0 - normalized * (plot.size.y - 14.0)
	)


static func _draw_stats(
	canvas: CanvasItem, font: Font, detail: Dictionary, x: float, y: float, width: float
) -> void:
	var parts: Array = []
	for stat in detail["stats"]:
		parts.append("%s %s" % [str(stat["label"]), str(stat["value"])])
	_text(canvas, font, Vector2(x, y + 18.0),
		"    ".join(PackedStringArray(parts)), COLOR_DIM, SIZE_SMALL)


static func _text(
	canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color, size: int
) -> void:
	UiTheme.draw_text(canvas, font, pos, text, color, size)


static func _text_right(
	canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color, size: int
) -> void:
	UiTheme.draw_text_right(canvas, font, pos, text, color, size)


static func _text_center(
	canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color, size: int
) -> void:
	UiTheme.draw_text_center(canvas, font, pos, text, color, size)
