class_name TradePanel
extends RefCounted

## 商铺 / 黑市界面的绘制与命中测试。
##
## 与其它面板同构：只消费 TradeViewModel 产出的行与详情，不做数值加工；所有可点
## 元素的位置由 _row_rect / buttons 产出，draw 与 hit_test 都调它们，于是
## "画在这里、点在那里"不会发生。
##
## 左列是货架（买）或背包（卖），右列是选中那件的价目——五个因子逐个摊开，
## 玩家才答得出"贵在哪、该不该换个城"。两条渠道（商铺 / 黑市）共用这块版面，
## 只有抬头、价目系数与"做不做你生意"三处不同。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const LIST_WIDTH: float = 430.0
const ROW_HEIGHT: float = 34.0
const ROW_TOP_PAD: float = 4.0
const BACK_BUTTON_TOP: float = 12.0
const BACK_BUTTON_RESERVE: float = 16.0
const FACTOR_TOP: float = 132.0
const FACTOR_LINE_HEIGHT: float = 20.0


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
	if is_repair(view):
		_draw_repair_detail(canvas, font, view, rect)
	elif is_forge(view):
		_draw_forge_detail(canvas, font, view, rect)
	else:
		_draw_detail(canvas, font, view, rect)
	_draw_footer(canvas, font, view, rect)


## 这一页是铁匠铺还是买卖。两种页共用版面的骨架（左列列表、右列明细、页脚一句
## 说明），只有"明细写什么"与"回车做什么"不同。
static func is_forge(view: Dictionary) -> bool:
	return str(view.get("pane", TradeViewModel.PANE_TRADE)) == TradeViewModel.PANE_FORGE


## 这一页是修理（铁匠铺里切进来的第二档活计，D-64）。与强化共用"看着一件货决定
## 花钱"的骨架，右边写耐久的现在与两档修完的样子。
static func is_repair(view: Dictionary) -> bool:
	return str(view.get("pane", TradeViewModel.PANE_TRADE)) == TradeViewModel.PANE_REPAIR


# --- 布局（draw 与 hit_test 共用）---

## 左列：货架或背包。
static func list_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + MARGIN, rect.position.y + HEADER_HEIGHT),
		Vector2(LIST_WIDTH, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


## 右列：价目。
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


## 右上角那一排按钮。「拿去成交」放最左（它是这块版面的主要动作），
## 「返回地图」留在最右——它是各视图共有的锚点，位置不随本面板多出几个按钮而漂移。
static func buttons(view: Dictionary, rect: Rect2) -> Array:
	var specs: Array = []
	if is_repair(view):
		specs = [
			{
				"id": "deal",
				"label": "修理",
				"enabled": bool(view.get("canTrade", false)),
			},
			{"id": "forge", "label": "回铁匠铺"},
		]
	elif is_forge(view):
		specs = [
			{
				"id": "deal",
				"label": "敲一炉",
				"enabled": bool(view.get("canTrade", false)),
			},
			{"id": "leaveForge", "label": "回商铺"},
		]
	else:
		var side: String = str(view.get("side", TradeViewModel.SIDE_BUY))
		specs = [
			{
				"id": "deal",
				"label": "买入" if side == TradeViewModel.SIDE_BUY else "卖出",
				"enabled": bool(view.get("canTrade", false)),
			},
			{
				"id": "side",
				"label": "切到卖出" if side == TradeViewModel.SIDE_BUY else "切到买入",
			},
		]
		# 没有黑市的城不给这个按钮：按不动的东西不该占版面
		if bool(view.get("hasBlackMarket", false)):
			var black: bool = str(view.get("channel", "")) == Economy.CHANNEL_BLACK_MARKET
			specs.append({"id": "channel", "label": "回商铺" if black else "去黑市"})
		specs.append({"id": "forge", "label": "铁匠铺"})
	specs.append({"id": "back", "label": "返回地图"})
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
	var black: bool = str(view.get("channel", "")) == Economy.CHANNEL_BLACK_MARKET
	var here: bool = bool(view.get("atCity", false))
	var position_text: String = "你就站在这座城" if here else "你不在这座城（只看得到价）"
	var hint_text: String = "↑↓ 选货　回车 修理　F 回铁匠铺　G 切档位" if is_repair(view) \
		else ("↑↓ 选货　←→ 换城市　回车 敲一炉　F 回商铺" if is_forge(view) \
			else "↑↓ 选货    ←→ 换城市看价    回车 成交    Tab 换买卖")
	UiTheme.draw_panel_header(canvas, font, rect, {
		"left": MARGIN,
		"title": str(view.get("channelLabel", "")),
		"titleY": 30.0,
		"titleColor": UiTheme.COLOR_WARN if black else UiTheme.COLOR_ACCENT,
		"subtitle": "%s · %s · 身上 %s" % [
			position_text, str(view.get("sideLabel", "")), str(view.get("moneyLabel", "")),
		],
		"subtitleY": 56.0,
		"subtitleColor": UiTheme.COLOR_TEXT if here else UiTheme.COLOR_WARN,
		"hint": hint_text,
		"hintY": 56.0,
		"hintRightX": _button_left(view, rect) - BACK_BUTTON_RESERVE,
		"hintColor": UiTheme.COLOR_DIM,
		"lineY": HEADER_HEIGHT - 8.0,
	})
	# 城市标签是标题行上的第二枚左排元素，config 只有一个标题位，保持原样单独画。
	UiTheme.draw_text(canvas, font, Vector2(left + 62.0, top + 30.0),
		str(view.get("cityLabel", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_TITLE)


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
		var empty_text: String = "货架上空着——这座城的发展度还不够，好货还没上架。" \
			if str(view.get("side", "")) == TradeViewModel.SIDE_BUY else "你身上没什么可卖的。"
		if is_forge(view):
			empty_text = "背包里没有能进炉子的东西——炉子只收武器与防具。"
		elif is_repair(view):
			empty_text = "背包里没有会损坏的装备。"
		UiTheme.draw_text(canvas, font, list.position + Vector2(10.0, 26.0),
			empty_text, UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
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
			Vector2(list.position.x + list.size.x - 6.0, list.position.y + list.size.y - 4.0),
			"%d / %d 件（↑↓ 移动）" % [cursor + 1, rows.size()],
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2, selected: bool
) -> void:
	var enabled: bool = bool(row.get("enabled", true))
	var name_color: Color = UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM
	var kind: String = str(row.get("kind", ""))
	var kind_label: String = "货架" if kind == TradeViewModel.ROW_KIND_STOCK else "身上"
	if kind == TradeViewModel.ROW_KIND_FORGE:
		kind_label = "背包"
	elif kind == TradeViewModel.ROW_KIND_REPAIR:
		kind_label = "装备"

	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 8.0, rect.position.y + 19.0),
		"[%s]" % kind_label, UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 19.0),
		str(row.get("label", "")), name_color, UiTheme.SIZE_NORMAL)
	var price_text: String = str(row.get("priceText", ""))
	if price_text.is_empty() and kind == TradeViewModel.ROW_KIND_REPAIR:
		# 修理行没有常规"价"——看的是修到最省那档要花多少；视图模型把最省的
		# 档位金额放在 price，这里铸成文本，免得右列空着
		price_text = AvatarViewModel.money_label(int(row.get("price", 0)))
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 19.0),
		price_text,
		UiTheme.COLOR_ACCENT if enabled else UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)

	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 52.0, rect.position.y + 33.0),
		"%s · %s · %s" % [
			str(row.get("rarityLabel", "")),
			str(row.get("categoryLabel", "")) if kind != TradeViewModel.ROW_KIND_REPAIR \
				else str(row.get("durabilityText", "")),
			str(row.get("detail", "")),
		],
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	# 词缀写在第二行的右侧。铁匠铺与卖出列表里最要紧的就是这一行——
	# "为什么这件贵、为什么值得敲"的答案都在这几个字上。
	var affix: String = str(row.get("affixText", ""))
	if not affix.is_empty():
		UiTheme.draw_text_right(canvas, font,
			Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 33.0),
			affix, UiTheme.COLOR_UP, UiTheme.SIZE_SMALL)
	elif kind == TradeViewModel.ROW_KIND_FORGE:
		UiTheme.draw_text_right(canvas, font,
			Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 33.0),
			str(row.get("levelLabel", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	if selected and not enabled:
		var reason: String = "现在动不了" if kind == TradeViewModel.ROW_KIND_FORGE \
			else ("修不起" if kind == TradeViewModel.ROW_KIND_REPAIR else "买不起")
		UiTheme.draw_text_right(canvas, font,
			Vector2(rect.position.x + rect.size.x - 8.0, rect.position.y + 33.0),
			reason, UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)


# --- 绘制：右列价目 ---

static func _draw_detail(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var column: Rect2 = column_rect(rect)
	canvas.draw_rect(column, UiTheme.COLOR_LIST_BG)
	var selected: Dictionary = view.get("selected", {})
	if selected.is_empty():
		UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
			"左边选一件货，这里写它的价是怎么来的。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return

	var x: float = column.position.x + 12.0
	UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
		"%s（%s）" % [str(selected.get("label", "")), str(selected.get("rarityLabel", ""))],
		UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 50.0),
		"%s · %s · %s" % [
			str(selected.get("categoryLabel", "")), str(selected.get("detail", "")),
			str(selected.get("effectText", "")),
		],
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	canvas.draw_line(Vector2(x, column.position.y + FACTOR_TOP - 26.0),
		Vector2(column.position.x + column.size.x - 12.0, column.position.y + FACTOR_TOP - 26.0),
		UiTheme.COLOR_BORDER, 1.0)

	var y: float = column.position.y + FACTOR_TOP
	y = _draw_factor_rows(canvas, font, selected.get("factorRows", []), x, y)

	y += 12.0
	canvas.draw_line(Vector2(x, y - 18.0),
		Vector2(column.position.x + column.size.x - 12.0, y - 18.0),
		UiTheme.COLOR_BORDER, 1.0)
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		"买价 %s" % str(selected.get("unitPriceText", "")),
		UiTheme.COLOR_TEXT, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, Vector2(x + 200.0, y),
		"收价 %s" % str(selected.get("sellPriceText", "")),
		UiTheme.COLOR_DIM, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, Vector2(x, y + 22.0),
		"同一座城里买贵卖贱，差价要靠换一座城才赚得出来。",
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


## 右列：铁匠铺的明细。抬头与因子的排法和价目那一页一模一样（同一个版面、
## 同一套读法），底下换成词缀——铁匠铺最该回答的是"这一炉买到了什么、
## 这件货为什么值这个价"。
static func _draw_forge_detail(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var column: Rect2 = column_rect(rect)
	canvas.draw_rect(column, UiTheme.COLOR_LIST_BG)
	var selected: Dictionary = view.get("selected", {})
	if selected.is_empty():
		UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
			"左边选一件货，这里写它现在几级、下一级什么样。",
			UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return

	var x: float = column.position.x + 12.0
	UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
		"%s（%s）" % [str(selected.get("label", "")), str(selected.get("rarityLabel", ""))],
		UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 50.0),
		"%s · %s · %s" % [
			str(selected.get("categoryLabel", "")), str(selected.get("detail", "")),
			str(selected.get("durabilityText", "")),
		],
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	canvas.draw_line(Vector2(x, column.position.y + FACTOR_TOP - 26.0),
		Vector2(column.position.x + column.size.x - 12.0, column.position.y + FACTOR_TOP - 26.0),
		UiTheme.COLOR_BORDER, 1.0)

	var y: float = column.position.y + FACTOR_TOP
	y = _draw_factor_rows(canvas, font, selected.get("factorRows", []), x, y)

	y += 12.0
	canvas.draw_line(Vector2(x, y - 18.0),
		Vector2(column.position.x + column.size.x - 12.0, y - 18.0),
		UiTheme.COLOR_BORDER, 1.0)
	var affix_rows: Array = selected.get("affixRows", [])
	if affix_rows.is_empty():
		UiTheme.draw_text(canvas, font, Vector2(x, y),
			"这一件没有词缀。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		"词缀（%d 条，卖出时算得进价里）" % affix_rows.size(),
		UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	y += 20.0
	for affix in affix_rows:
		UiTheme.draw_text(canvas, font, Vector2(x, y), str(affix.get("text", "")),
			UiTheme.COLOR_UP, UiTheme.SIZE_NORMAL)
		y += FACTOR_LINE_HEIGHT


## 右列：修理的明细。抬头、因子的排法与强化一模一样（同一个版面），底下补一句
## 便携工具的提醒——背包里那个修补工具不进这里，是野外就地用的（D-64）。
static func _draw_repair_detail(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var column: Rect2 = column_rect(rect)
	canvas.draw_rect(column, UiTheme.COLOR_LIST_BG)
	var selected: Dictionary = view.get("selected", {})
	if selected.is_empty():
		UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
			"左边选一件装备，这里写它现在的耐久与两档修理的工钱。",
			UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return

	var x: float = column.position.x + 12.0
	UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 26.0),
		"%s（%s）" % [str(selected.get("label", "")), str(selected.get("rarityLabel", ""))],
		UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, column.position + Vector2(12.0, 50.0),
		"%s · %s · %s" % [
			str(selected.get("categoryLabel", "")),
			str(selected.get("detail", "")),
			str(selected.get("durabilityText", "")),
		],
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	canvas.draw_line(Vector2(x, column.position.y + FACTOR_TOP - 26.0),
		Vector2(column.position.x + column.size.x - 12.0, column.position.y + FACTOR_TOP - 26.0),
		UiTheme.COLOR_BORDER, 1.0)

	var y: float = column.position.y + FACTOR_TOP
	y = _draw_factor_rows(canvas, font, selected.get("factorRows", []), x, y)

	y += 12.0
	canvas.draw_line(Vector2(x, y - 18.0),
		Vector2(column.position.x + column.size.x - 12.0, y - 18.0),
		UiTheme.COLOR_BORDER, 1.0)
	UiTheme.draw_text(canvas, font, Vector2(x, y),
		"工匠修回九成、满修修到满（按强化加价）。",
		UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text(canvas, font, Vector2(x, y + 22.0),
		"背包里的「修补工具」走另一条路：野外就地用，不进这口炉子。",
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


## 逐因子的价目行。买卖与铁匠铺共用，两页的读法因此一致。
static func _draw_factor_rows(
	canvas: CanvasItem, font: Font, rows: Array, x: float, y: float
) -> float:
	for factor in rows:
		UiTheme.draw_text(canvas, font, Vector2(x, y), str(factor.get("label", "")),
			UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text_right(canvas, font,
			Vector2(x + 150.0, y), str(factor.get("value", "")),
			UiTheme.COLOR_WARN, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text(canvas, font, Vector2(x + 180.0, y), str(factor.get("hint", "")),
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		y += FACTOR_LINE_HEIGHT
	return y


# --- 绘制：页脚 ---

static func _draw_footer(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y + rect.size.y - FOOTER_HEIGHT
	var width: float = rect.size.x - MARGIN * 2.0
	canvas.draw_line(Vector2(left, top), Vector2(left + width, top), UiTheme.COLOR_BORDER, 1.0)

	var blocked: String = str(view.get("blockedReason", ""))
	var text: String = str(view.get("dealSummary", ""))
	var color: Color = UiTheme.COLOR_TEXT
	if not bool(view.get("canTrade", false)):
		text = blocked if not blocked.is_empty() else "这件货现在拿不下。"
		color = UiTheme.COLOR_WARN
	UiTheme.draw_text(canvas, font, Vector2(left, top + 28.0), text, color, UiTheme.SIZE_NORMAL)
