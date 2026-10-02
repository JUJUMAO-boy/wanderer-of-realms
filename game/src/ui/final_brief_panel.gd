class_name FinalBriefPanel
extends RefCounted

## 总攻简报页的绘制与命中测试（第四阶段界面精修 · 下，里程碑 55）。只读：把
## `FinalBriefViewModel` 整好的条目摊成「门槛 + 阶段链 + 灰袍者两阶段 + 动摇 + 助阵 +
## 共鸣」几段，底部两个按钮「返回主线 / 发起总攻」。绝不加工数值。
##
## 与结局演出页一样，这是**会话级简报**（不进左侧导航）：整片 PANEL_RECT 都是它的台面。

const MARGIN: float = 16.0
const BODY_TOP: float = 120.0
const BUTTON_BOTTOM: float = 52.0
const LINE_HEIGHT: float = 23.0
const SECTION_GAP: float = 10.0
const HEAD_SIZE: float = 15.0
const BODY_SIZE: float = 14.0

const COLOR_TEXT: Color = UiTheme.COLOR_TEXT
const COLOR_DIM: Color = UiTheme.COLOR_DIM
const COLOR_ACCENT: Color = UiTheme.COLOR_ACCENT


static func draw(canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	UiTheme.draw_panel(canvas, rect)
	UiTheme.draw_panel_header(canvas, font, rect, {
		"left": MARGIN,
		"title": "总攻 · 轮回之轮核心",
		"titleY": 34.0,
		"subtitle": _subtitle(view),
		"subtitleY": 58.0,
		"titleColor": COLOR_TEXT,
	})
	for button in buttons(rect, view):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]),
			bool(button.get("enabled", true)), hovered)
	_draw_body(canvas, font, view, rect)


## 按钮行：返回主线 + 发起总攻（门槛没过时置灰）。返回恒在首位。
static func buttons(rect: Rect2, view: Dictionary = {}) -> Array:
	var list: Array = [{"id": "back", "label": "返回主线"}]
	list.append({"id": "start", "label": "发起总攻", "enabled": bool(view.get("available", false))})
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
	if bool(view.get("won", false)):
		return "这场总攻你已经打过了"
	if bool(view.get("available", false)):
		return "可发起"
	return "还不到时候"


static func _draw_body(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var x: float = rect.position.x + MARGIN * 2.0
	var y: float = rect.position.y + BODY_TOP
	var wrap: float = maxf(240.0, rect.size.x - MARGIN * 4.0)

	# 门槛
	_text(canvas, font, Vector2(x, y), _gate_line(view), COLOR_ACCENT if bool(view.get("available", false)) else COLOR_DIM, HEAD_SIZE)
	y += LINE_HEIGHT * 1.3

	# 阶段链
	if not bool(view.get("available", false)) and not bool(view.get("won", false)):
		return
	_text(canvas, font, Vector2(x, y), "阶段链", COLOR_TEXT, HEAD_SIZE)
	y += LINE_HEIGHT
	for stage in view.get("stages", []):
		var row: Dictionary = stage
		var head: String = "%d. [%s] %s" % [
			int(row.get("index", 0)) + 1, str(row.get("kindLabel", "")), str(row.get("label", "")),
		]
		var detail: String = str(row.get("detail", ""))
		if not detail.is_empty():
			head += "　——　" + detail
		y += _wrap(canvas, font, Vector2(x, y), head, wrap, COLOR_TEXT, BODY_SIZE) + 2.0
	y += SECTION_GAP

	# 灰袍者两阶段
	var boss: Dictionary = view.get("boss", {})
	if not boss.is_empty():
		_text(canvas, font, Vector2(x, y),
			"%s（HP %d / 攻 %d / 防 %d / TL %d）" % [
				str(boss.get("label", "")), int(boss.get("hp", 0)),
				int(boss.get("attack", 0)), int(boss.get("armor", 0)), int(boss.get("threatLevel", 0)),
			], COLOR_ACCENT, HEAD_SIZE)
		y += LINE_HEIGHT
		for phase in boss.get("phases", []):
			var p: Dictionary = phase
			var line: String = "%s：HP %d%%、攻 ×%.1f、防 ×%.1f" % [
				str(p.get("label", "")), roundi(float(p.get("hpMult", 1.0)) * 100.0),
				float(p.get("attackMult", 1.0)), float(p.get("armorMult", 1.0)),
			]
			var drain: int = int(p.get("selfDrainBp", 0))
			if drain > 0:
				line += "、每回合自损 %d%%" % roundi(float(drain) / 100.0)
			var summons: String = str(p.get("summons", ""))
			if not summons.is_empty():
				line += "；召唤 %s" % summons
			y += _wrap(canvas, font, Vector2(x, y), line, wrap, COLOR_TEXT, BODY_SIZE) + 2.0
		y += SECTION_GAP

	# 动摇
	var wavering: Dictionary = view.get("wavering", {})
	if not wavering.is_empty():
		if bool(wavering.get("ok", false)):
			_text(canvas, font, Vector2(x, y),
				"动摇已命中：攻 -30%、防 -20%，二阶段不再狂暴。", COLOR_ACCENT, BODY_SIZE)
			y += LINE_HEIGHT
			var wsummary: String = str(wavering.get("summary", ""))
			if not wsummary.is_empty():
				y += _wrap(canvas, font, Vector2(x, y), wsummary, wrap, COLOR_DIM, BODY_SIZE) + 2.0
		else:
			var reason: String = str(wavering.get("reason", ""))
			y += _wrap(canvas, font, Vector2(x, y),
				"动摇未触发：%s" % reason, wrap, COLOR_DIM, BODY_SIZE) + 2.0
		y += SECTION_GAP

	# 助阵
	var allies: Array = view.get("allies", [])
	if allies.is_empty():
		_text(canvas, font, Vector2(x, y), "助阵：无（瓦洛克要三世盟约符文，伊莉丝要锚点好感达档）", COLOR_DIM, BODY_SIZE)
		y += LINE_HEIGHT
	else:
		_text(canvas, font, Vector2(x, y), "助阵", COLOR_TEXT, HEAD_SIZE)
		y += LINE_HEIGHT
		for ally in allies:
			var a: Dictionary = ally
			y += _wrap(canvas, font, Vector2(x, y),
				"%s：%s" % [str(a.get("label", "")), str(a.get("support", ""))], wrap, COLOR_ACCENT, BODY_SIZE) + 2.0
	y += SECTION_GAP

	# 碎片共鸣
	var resonance: Dictionary = view.get("resonance", {})
	if not resonance.is_empty():
		_text(canvas, font, Vector2(x, y),
			"碎片共鸣：每 %d 回合为一方提点（%s / %s）。" % [
				int(resonance.get("everyRounds", 3)),
				str(resonance.get("playerLabel", "")), str(resonance.get("bossLabel", "")),
			], COLOR_DIM, BODY_SIZE)


static func _gate_line(view: Dictionary) -> String:
	if bool(view.get("won", false)):
		return "这场总攻你已经打过了。"
	if bool(view.get("available", false)):
		return "门槛已过——你站到了轮核之前。"
	var reason: String = str(view.get("reason", ""))
	var need: String = str(view.get("needActLabel", ""))
	if not need.is_empty():
		return "发起总攻还需：%s（当前需前进到%s）" % [reason, need]
	return "发起总攻还需：%s" % reason


## 画一段会自动折行的正文，返回它占的高度（供简报往下排版）。
static func _wrap(canvas: CanvasItem, font: Font, pos: Vector2, text: String,
		width: float, color: Color, size: float) -> float:
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_ADAPTIVE
	canvas.draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, color, flags)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, flags).y


static func _text(canvas: CanvasItem, font: Font, pos: Vector2, text: String,
		color: Color, size: float) -> void:
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)