class_name EndingPanel
extends RefCounted

## 结局演出页的绘制与命中测试（第四阶段界面精修 · 上，里程碑 54）。只读：把
## `EndingViewModel` 排出的一页摊成「标题 + 正文」几段，底部三个按钮翻页/返回，
## 绝不加工数值。翻页本身由 main.gd 改 page 后重算视图模型。
##
## 与主线面板不同，这是**会话级演出**（不进左侧导航）：整个 PANEL_RECT 都是它的台面。

const MARGIN: float = 16.0
const BODY_TOP: float = 128.0
const BUTTON_BOTTOM: float = 56.0
const LINE_HEIGHT: float = 26.0
const TITLE_SIZE: float = 30.0
const BODY_SIZE: float = 17.0
const HEAD_SIZE: float = 16.0

const COLOR_TEXT: Color = UiTheme.COLOR_TEXT
const COLOR_DIM: Color = UiTheme.COLOR_DIM
const COLOR_ACCENT: Color = UiTheme.COLOR_ACCENT


static func draw(canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null:
		return
	UiTheme.draw_panel(canvas, rect)
	var subtitle: String = _subtitle(view)
	UiTheme.draw_panel_header(canvas, font, rect, {
		"left": MARGIN,
		"title": "终局 · 后日谈",
		"titleY": 34.0,
		"subtitle": subtitle,
		"subtitleY": 58.0,
		"titleColor": COLOR_TEXT,
	})
	for button in buttons(rect, view):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]),
			bool(button.get("enabled", true)), hovered)
	_draw_page(canvas, font, view, rect)


## 按钮行：返回 + 上一页 + 下一页（贴底右对齐）。无内容时只留返回。
static func buttons(rect: Rect2, view: Dictionary = {}) -> Array:
	var list: Array = [{"id": "back", "label": "返回主线"}]
	if int(view.get("pageCount", 0)) > 0:
		list.append({"id": "prev", "label": "← 上一页", "enabled": bool(view.get("canPrev", false))})
		list.append({"id": "next", "label": "下一页 →", "enabled": bool(view.get("canNext", false))})
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + rect.size.y - BUTTON_BOTTOM,
		list
	)


static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(rect, view), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": bool(button.get("enabled", true))}
	return {}


static func _subtitle(view: Dictionary) -> String:
	if int(view.get("pageCount", 0)) <= 0:
		return ""
	var kind: String = str(view.get("kindLabel", ""))
	var parts: Array = []
	if not kind.is_empty():
		parts.append(kind)
	parts.append("第 %d / %d 页" % [int(view.get("page", 0)) + 1, int(view.get("pageCount", 0))])
	return "　".join(PackedStringArray(parts))


static func _draw_page(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var x: float = rect.position.x + MARGIN * 2.0
	var y: float = rect.position.y + BODY_TOP
	var wrap: float = maxf(240.0, rect.size.x - MARGIN * 4.0)
	var pages: Array = view.get("pages", [])
	if pages.is_empty():
		_text(canvas, font, Vector2(x, y), "还没有结局。回主线面板做出你的抉择。", COLOR_DIM, BODY_SIZE)
		return
	var index: int = clampi(int(view.get("page", 0)), 0, pages.size() - 1)
	var entry: Dictionary = pages[index]
	match str(entry.get("kind", "")):
		"title":
			_text(canvas, font, Vector2(x, y), str(entry.get("head", "")), COLOR_ACCENT, TITLE_SIZE)
			y += TITLE_SIZE + 18.0
			_wrap(canvas, font, Vector2(x, y), str(entry.get("text", "")), wrap, COLOR_TEXT, BODY_SIZE)
		"relations":
			_text(canvas, font, Vector2(x, y), str(entry.get("head", "")), COLOR_ACCENT, HEAD_SIZE + 2.0)
			y += LINE_HEIGHT
			for raw in entry.get("relations", []):
				var rel: Dictionary = raw
				_text(canvas, font, Vector2(x, y), str(rel.get("label", "")), COLOR_ACCENT, HEAD_SIZE)
				y += LINE_HEIGHT
				for line in rel.get("lines", []):
					y += _wrap(canvas, font, Vector2(x, y), str(line), wrap, COLOR_TEXT, BODY_SIZE) + 6.0
				y += 4.0
		"after":
			_text(canvas, font, Vector2(x, y), str(entry.get("head", "")), COLOR_DIM, HEAD_SIZE)
			y += LINE_HEIGHT
			_wrap(canvas, font, Vector2(x, y), str(entry.get("text", "")), wrap, COLOR_TEXT, BODY_SIZE)
		_:
			_wrap(canvas, font, Vector2(x, y), str(entry.get("text", "")), wrap, COLOR_TEXT, BODY_SIZE)


## 画一段会自动折行的正文，返回它占的高度（供演出页往下排版）。
static func _wrap(canvas: CanvasItem, font: Font, pos: Vector2, text: String,
		width: float, color: Color, size: float) -> float:
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_ADAPTIVE
	canvas.draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, color, flags)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, flags).y


static func _text(canvas: CanvasItem, font: Font, pos: Vector2, text: String,
		color: Color, size: float) -> void:
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)