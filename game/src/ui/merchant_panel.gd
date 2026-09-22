class_name MerchantPanel
extends RefCounted

## 游方商人界面的绘制与命中测试（M21）。与其它面板同构：只消费
## MerchantViewModel 产出的行与详情，不做数值加工；所有可点元素的几何由
## _row_rect / buttons 产出，draw 与 hit_test 都调它们。
##
## 比商铺面板更朴素：没有城市切换、没有渠道、没有铁匠铺。左列是货（买）或
## 背包（卖），右列是选中那件的价一笔带过，页脚一句说明。行商是野外偶遇的
## 一架车，版面只要能"看货、问价、成交、走人"就够了。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const LIST_WIDTH: float = 430.0
const ROW_HEIGHT: float = 34.0
const ROW_TOP_PAD: float = 4.0


## 版面按钮：买⇄卖 与 成交。成交只有在 canTrade 时才可用。
static func buttons(view: Dictionary, rect: Rect2) -> Array:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	var mode: Dictionary = view.get("selected", {})
	var other_side: String = str(view.get("otherSide", Merchant.SIDE_BUY))
	return [
		{"id": "side", "label": "换%s" % ("买入" if other_side == Merchant.SIDE_BUY else "卖出"),
			"x": left + LIST_WIDTH + 36.0, "y": top + 90.0,
			"enabled": true},
		{"id": "deal", "label": "回车成交",
			"x": left + LIST_WIDTH + 36.0, "y": top + 126.0,
			"enabled": bool(view.get("canTrade", false)) and not mode.is_empty()},
	]


static func is_secondary() -> bool:
	return true


## 左列列表区域。
static func list_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position + Vector2(MARGIN, HEADER_HEIGHT),
		Vector2(LIST_WIDTH, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT))


## 左列某一行。列宽固定 430，所以分页只按行数滚。
static func _row_rect(rect: Rect2, view: Dictionary, index: int) -> Rect2:
	var list: Rect2 = list_rect(rect)
	var window: Dictionary = _visible_rows(view, list)
	var visible: int = int(window["visible"])
	if index < int(window["start"]) or index >= int(window["start"]) + visible:
		return Rect2()
	return Rect2(list.position + Vector2(0.0, (index - int(window["start"])) * ROW_HEIGHT),
		Vector2(LIST_WIDTH, ROW_HEIGHT - 2.0))


static func _visible_rows(view: Dictionary, list: Rect2) -> Dictionary:
	var count: int = int(view.get("rowCount", 0))
	var visible: int = maxi(0, int(list.size.y / ROW_HEIGHT))
	return {"start": 0, "count": count, "visible": maxi(1, visible)}


static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = _hit_button(buttons(view, rect), point)
	if not button.is_empty():
		return {
			"kind": "button", "id": str(button["id"]),
			"enabled": bool(button.get("enabled", true)),
		}
	var count: int = int(view.get("rowCount", 0))
	for index in range(count):
		if _row_rect(rect, view, index).has_point(point):
			var rows: Array = view.get("rows", [])
			var enabled: bool = rows[index].get("enabled", true) if index < rows.size() else true
			return {"kind": "row", "index": index, "enabled": enabled}
	return {}


static func draw(canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	UiTheme.draw_panel(canvas, rect)
	var side: String = str(view.get("side", Merchant.SIDE_BUY))
	var buy: bool = side == Merchant.SIDE_BUY
	var other_label: String = "买入" if not buy else "卖出"
	var hint_text: String = "↑↓ 选货    Tab 换买卖    回车 成交    ESC 离开"
	UiTheme.draw_panel_header(canvas, font, rect, {
		"left": MARGIN,
		"title": "游方商人",
		"titleY": 30.0,
		"titleColor": UiTheme.COLOR_ACCENT,
		"subtitle": "%s · 身上 %s" % [("看他的货车" if buy else "卖装备给他"),
			str(view.get("moneyLabel", ""))],
		"subtitleY": 56.0,
		"subtitleColor": UiTheme.COLOR_TEXT,
		"hint": hint_text,
		"hintY": 56.0,
		"hintRightX": rect.end.x - MARGIN,
		"hintColor": UiTheme.COLOR_DIM,
		"lineY": HEADER_HEIGHT - 8.0,
	})

	# 左列
	_draw_list(canvas, font, view, rect, hover)
	# 右列 + 按钮
	var mode: Dictionary = view.get("selected", {})
	if mode.is_empty():
		_draw_detail_empty(canvas, font, view, rect)
	else:
		_draw_detail(canvas, font, mode, rect)
	for b in buttons(view, rect):
		_draw_button(canvas, font, b, hover)
	# 页脚一句说明
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + MARGIN, rect.end.y - 26.0),
		str(view.get("hint", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	# 卖出侧特有的身家提示
	if not buy:
		var this_label: String = "这支车队什么都收，收价是他卖价的六成不到。"
		UiTheme.draw_text_right(canvas, font,
			Vector2(rect.end.x - MARGIN, rect.end.y - 26.0),
			"成交后身家 %s" % str(view.get("moneyAfterLabel", "")),
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_list(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var list: Rect2 = list_rect(rect)
	var rows: Array = view.get("rows", [])
	for i in range(rows.size()):
		var r: Rect2 = _row_rect(rect, view, i)
		if r.size.x <= 0.0:
			continue
		var hovered: bool = str(hover.get("kind", "")) == "row" and int(hover.get("index", -1)) == i
		var selected: bool = int(view.get("cursor", 0)) == i
		if hovered or selected:
			canvas.draw_rect(r, UiTheme.COLOR_SELECTED)
		UiTheme.draw_text(canvas, font, r.position + Vector2(6.0, -6.0),
			str(rows[i].get("label", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text(canvas, font, r.position + Vector2(6.0, 12.0),
			"%s · %s" % [str(rows[i].get("categoryLabel", "")),
				str(rows[i].get("rarityLabel", ""))],
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		UiTheme.draw_text_right(canvas, font, Vector2(r.end.x - 8.0, r.position.y),
			str(rows[i].get("priceText", "")), UiTheme.COLOR_WARN, UiTheme.SIZE_NORMAL)
	# 空列表提示
	if rows.is_empty():
		UiTheme.draw_text(canvas, font, list.position + Vector2(0.0, 20.0),
			"这里没有可列的东西。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
	# 列分隔线
	canvas.draw_line(Vector2(list.position.x + LIST_WIDTH, list.position.y),
		Vector2(list.position.x + LIST_WIDTH, list.end.y), UiTheme.COLOR_BORDER, 1.0)


static func _draw_detail_empty(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + LIST_WIDTH + 40.0
	UiTheme.draw_text(canvas, font, Vector2(left, rect.position.y + 110.0),
		"看左边：这笔买卖都写在价目里。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)


static func _draw_detail(canvas: CanvasItem, font: Font, mode: Dictionary, rect: Rect2) -> void:
	var left: float = rect.position.x + LIST_WIDTH + 40.0
	var y: float = rect.position.y + 100.0
	UiTheme.draw_text(canvas, font, Vector2(left, y), str(mode.get("label", "")),
		UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	var y2: float = y + 24.0
	UiTheme.draw_text(canvas, font, Vector2(left, y2), "%s · %s" % [
		str(mode.get("categoryLabel", "")), str(mode.get("rarityLabel", ""))
	], UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	var y3: float = y2 + 30.0
	UiTheme.draw_text(canvas, font, Vector2(left, y3), str(mode.get("detail", "")),
		UiTheme.COLOR_TEXT, UiTheme.SIZE_SMALL)
	var y4: float = y3 + 36.0
	if str(mode.get("kind", "")) == MerchantViewModel.ROW_KIND_STOCK:
		UiTheme.draw_text(canvas, font, Vector2(left, y4), "卖给你：%s" % str(mode.get("dealText", "")),
			UiTheme.COLOR_WARN, UiTheme.SIZE_NORMAL)
	else:
		UiTheme.draw_text(canvas, font, Vector2(left, y4), "回购：%s" % str(mode.get("dealText", "")),
			UiTheme.COLOR_DOWN, UiTheme.SIZE_NORMAL)


static func _draw_button(canvas: CanvasItem, font: Font, b: Dictionary, hover: Dictionary) -> void:
	var rect := Rect2(float(b["x"]), float(b["y"]), 110.0, 28.0)
	var hovered: bool = str(hover.get("kind", "")) == "button" and str(hover.get("id", "")) == str(b["id"])
	var enabled: bool = bool(b.get("enabled", true))
	var bg: Color = UiTheme.COLOR_BAR if enabled else UiTheme.COLOR_BAR_BG
	if hovered and enabled:
		bg = UiTheme.COLOR_SELECTED
	canvas.draw_rect(rect, bg)
	canvas.draw_rect(rect, UiTheme.COLOR_BORDER, false, 1.0)
	var fg: Color = UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM
	UiTheme.draw_text_center(canvas, font, Vector2(rect.position.x + rect.size.x * 0.5,
		rect.position.y + rect.size.y * 0.5 - 6.0), str(b["label"]), fg, UiTheme.SIZE_NORMAL)


## 本面板按钮自带 x/y（固定 110×28），不走 UiTheme 的 rect 契约；命中用同一几何。
static func _hit_button(buttons: Array, point: Vector2) -> Dictionary:
	for b in buttons:
		if Rect2(float(b["x"]), float(b["y"]), 110.0, 28.0).has_point(point):
			return b
	return {}