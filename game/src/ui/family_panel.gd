class_name FamilyPanel
extends RefCounted

## 家族面板的绘制与命中测试（A3，D-181）。只读：把 FamilyViewModel 组装好的
## view 摊成「现配偶卡 + 家族史」两段，绝不加工数值。唯一可点的是一颗「返回」，
## 归位仍交给侧栏与 ESC/T。谈情那部分已经做在居民面板（求婚），这里只管回家看。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const FOOTER_HEIGHT: float = 46.0
const BACK_BUTTON_TOP: float = 12.0
const BODY_TOP: float = 120.0
const LINE_HEIGHT: float = 20.0


static func draw(canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	UiTheme.draw_panel(canvas, rect)
	UiTheme.draw_panel_header(canvas, font, rect, {
		"left": MARGIN,
		"title": str(view.get("subject", "家族与姻缘")),
		"titleY": 34.0,
		"titleColor": UiTheme.COLOR_TEXT,
	})
	for button in buttons(rect):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]), true, hovered)
	_draw_body(canvas, font, view, rect)


static func buttons(rect: Rect2) -> Array:
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + BACK_BUTTON_TOP,
		[{"id": "back", "label": "返回城市"}]
	)


static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(rect), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": bool(button.get("enabled", true))}
	return {}


static func _draw_body(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var x: float = rect.position.x + MARGIN
	var y: float = rect.position.y + BODY_TOP

	if not bool(view.get("married", false)):
		canvas.draw_string(font, Vector2(x, y),
			"尚未成家。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18.0, UiTheme.COLOR_TEXT)
		y += LINE_HEIGHT
		canvas.draw_string(font, Vector2(x, y),
			str(view.get("courting", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0, UiTheme.COLOR_DIM)
		y += LINE_HEIGHT
	else:
		canvas.draw_string(font, Vector2(x, y),
			"配偶：%s（%s）  %s成婚" % [
				str(view.get("spouseName", "")), str(view.get("spouseCity", "")),
				str(view.get("marriedAtLabel", "")),
			], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18.0, UiTheme.COLOR_TEXT)
		y += LINE_HEIGHT
		canvas.draw_string(font, Vector2(x, y),
			"在这座城买卖，店家念你一份情：便宜 %d%%。" % int(view.get("discountPct", 0)),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0, UiTheme.COLOR_UP)
		y += LINE_HEIGHT * 2

	if not str(view.get("bereaved", "")).is_empty():
		canvas.draw_string(font, Vector2(x, y),
			str(view.get("bereaved", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0, UiTheme.COLOR_ACCENT)
		y += LINE_HEIGHT * 2

	canvas.draw_string(font, Vector2(x, y), "家族史", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15.0, UiTheme.COLOR_ACCENT)
	y += LINE_HEIGHT
	var histories: Array = view.get("histories", [])
	if histories.is_empty():
		canvas.draw_string(font, Vector2(x, y),
			"簿上还空着，一页都没有。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0, UiTheme.COLOR_DIM)
	else:
		for h in histories:
			canvas.draw_string(font, Vector2(x, y),
				"%s  %s" % [str(h.get("when", "")), str(h.get("text", ""))],
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14.0, UiTheme.COLOR_TEXT)