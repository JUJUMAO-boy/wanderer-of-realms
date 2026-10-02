class_name MainlinePanel
extends RefCounted

## 主线面板的绘制与命中测试（第四阶段 D1）。只读：把 MainlineViewModel 摊成
## 「幕次 + 七片碎片 + 线索 + 下一道门槛」几段，绝不加工数值。唯一可点的是返回，
## 归位仍交给侧栏与 ESC/T。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const BACK_BUTTON_TOP: float = 12.0
const BODY_TOP: float = 116.0
const LINE_HEIGHT: float = 22.0
const SHARD_ROW_HEIGHT: float = 22.0

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
		"title": "主线 · 永恒者灵魂碎片",
		"titleY": 34.0,
		"subtitle": str(view.get("actLabel", "")),
		"subtitleY": 58.0,
		"titleColor": COLOR_TEXT,
	})
	for button in buttons(rect, view):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]), true, hovered)
	_draw_body(canvas, font, view, rect)


## 按钮行。返回按钮恒在首位（index 0），门槛过了（view.battle.available）再追加「发起总攻」，
## 终局门槛到了（view.ending.ready）再逐个追加可选去向；已抉择后改为一个「重温终局」。
static func buttons(rect: Rect2, view: Dictionary = {}) -> Array:
	var list: Array = [{"id": "back", "label": "返回地图"}]
	var battle: Dictionary = view.get("battle", {})
	if bool(battle.get("available", false)):
		list.append({"id": "final", "label": "发起总攻"})
	var ending: Dictionary = view.get("ending", {})
	var chosen: Dictionary = ending.get("chosen", {}) if ending.get("chosen", null) is Dictionary else {}
	if not str(chosen.get("endingId", "")).is_empty():
		list.append({"id": "ending_recall", "label": "重温终局"})
	elif bool(ending.get("ready", false)):
		for option in ending.get("options", []):
			if bool((option as Dictionary).get("available", false)):
				list.append({
					"id": "ending:%s" % str((option as Dictionary).get("endingId", "")),
					"label": str((option as Dictionary).get("label", "")),
				})
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + BACK_BUTTON_TOP,
		list
	)


static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(rect, view), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": bool(button.get("enabled", true))}
	return {}


static func _draw_body(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2) -> void:
	var x: float = rect.position.x + MARGIN
	var y: float = rect.position.y + BODY_TOP

	# 幕次进度：已到的幕亮、当前幕带标记。
	var act_parts: Array = []
	for act in view.get("acts", []):
		var label: String = str(act.get("label", ""))
		if bool(act.get("current", false)):
			act_parts.append("【%s】" % label)
		elif bool(act.get("reached", false)):
			act_parts.append("·%s" % label)
		else:
			act_parts.append("　%s" % label)
	_text(canvas, font, Vector2(x, y), "　".join(PackedStringArray(act_parts)), COLOR_ACCENT, 15.0)
	y += LINE_HEIGHT * 1.6

	# 七片碎片格。
	_text(canvas, font, Vector2(x, y),
		"碎片 %d / %d" % [int(view.get("collected", 0)), int(view.get("shardTotal", 0))],
		COLOR_TEXT, 15.0)
	y += LINE_HEIGHT
	for shard in view.get("shards", []):
		var got: bool = bool(shard.get("collected", false))
		var mark: String = "◆" if got else "◇"
		var color: Color = COLOR_ACCENT if got else COLOR_DIM
		var place: String = str(shard.get("place", ""))
		var line: String = "%s %s（%s）" % [mark, str(shard.get("name", "")), str(shard.get("aspect", ""))]
		if got:
			line += "　—　取自 %s" % place
		_text(canvas, font, Vector2(x, y), line, color, 14.0)
		y += SHARD_ROW_HEIGHT
	y += LINE_HEIGHT * 0.5

	# 线索与下一道门槛。
	_text(canvas, font, Vector2(x, y),
		"线索 %d / %d" % [int(view.get("clueRevealed", 0)), int(view.get("clueTotal", 0))],
		COLOR_TEXT, 15.0)
	y += LINE_HEIGHT
	var next: Dictionary = view.get("next", {})
	if bool(next.get("done", false)) or bool(view.get("complete", false)):
		_text(canvas, font, Vector2(x, y),
			"七片归位，轮子在你面前停了一瞬——该你选了。", COLOR_ACCENT, 14.0)
		y += LINE_HEIGHT
		var ending_parts: Array = []
		for ending in view.get("endings", []):
			ending_parts.append(str(ending.get("label", "")))
		if not ending_parts.is_empty():
			_text(canvas, font, Vector2(x, y),
				"可能的去向：" + "、".join(PackedStringArray(ending_parts)), COLOR_DIM, 14.0)
	else:
		var need: String = "下一幕【%s】还需：碎片 %d/%d" % [
			str(next.get("actLabel", "")),
			int(next.get("haveShards", 0)), int(next.get("needShards", 0)),
		]
		for clue in next.get("needClues", []):
			need += "，%s %s" % [
				"已知" if bool(clue.get("have", false)) else "未明",
				str(clue.get("label", "")),
			]
		_text(canvas, font, Vector2(x, y), need, COLOR_DIM, 14.0)
		y += LINE_HEIGHT * 1.5

	_draw_ending(canvas, font, view, rect, Vector2(x, _draw_battle(canvas, font, view, Vector2(x, y))))


## 总攻段（第四阶段 D5）：门槛未到时写一句「还差什么」；到了就把阶段链、动摇、助阵摊开。
## 返回下一段该从哪一行往下画。
static func _draw_battle(canvas: CanvasItem, font: Font, view: Dictionary, pos: Vector2) -> float:
	var battle: Dictionary = view.get("battle", {})
	var y: float = pos.y
	if battle.is_empty() or bool(battle.get("won", false)):
		return y
	if not bool(battle.get("available", false)):
		var reason: String = str(battle.get("reason", ""))
		if not reason.is_empty():
			_text(canvas, font, Vector2(pos.x, y), "总攻轮核：" + reason, COLOR_DIM, 14.0)
		return y
	_text(canvas, font, Vector2(pos.x, y), "总攻轮核·可发起", COLOR_ACCENT, 15.0)
	y += LINE_HEIGHT
	var parts: Array = []
	for stage in battle.get("stages", []):
		parts.append(str((stage as Dictionary).get("label", "")))
	if not parts.is_empty():
		_text(canvas, font, Vector2(pos.x, y), "阶段：" + " → ".join(PackedStringArray(parts)), COLOR_DIM, 14.0)
		y += LINE_HEIGHT
	var wavering: Dictionary = battle.get("wavering", {})
	if bool(wavering.get("ok", false)):
		_text(canvas, font, Vector2(pos.x, y), "灰袍者已动摇：攻 -30%、防 -20%，二阶段不再狂暴。", COLOR_ACCENT, 14.0)
		y += LINE_HEIGHT
	var allies: Array = battle.get("allies", [])
	if not allies.is_empty():
		var names: Array = []
		for ally in allies:
			names.append(str((ally as Dictionary).get("label", "")))
		_text(canvas, font, Vector2(pos.x, y), "助阵：" + "、".join(PackedStringArray(names)), COLOR_ACCENT, 14.0)
		y += LINE_HEIGHT
	return y


## 终局段（第四阶段 D6）：尚未抉择时摊开四个去向与推荐；已抉择只留一行摘要——
## 后日谈正文与关系分支字多，改由独立的结局演出页（EndingPanel）翻页承担，
## 免得把正文铺出面板底沿、读不全。
static func _draw_ending(canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, pos: Vector2) -> void:
	var ending: Dictionary = view.get("ending", {})
	if ending.is_empty() or not bool(ending.get("ready", false)):
		return
	var x: float = pos.x
	var y: float = pos.y
	var wrap: float = maxf(240.0, rect.size.x - MARGIN * 2.0 - 16.0)
	var chosen: Dictionary = ending.get("chosen", {}) if ending.get("chosen", null) is Dictionary else {}
	if not chosen.is_empty():
		_text(canvas, font, Vector2(x, y), "终局·%s" % str(chosen.get("label", "")), COLOR_ACCENT, 15.0)
		y += LINE_HEIGHT
		y += _wrap(canvas, font, Vector2(x, y), str(chosen.get("note", "")), wrap, COLOR_TEXT, 14.0) + 4.0
		_text(canvas, font, Vector2(x, y), "后日谈与关系分支留在「重温终局」里。", COLOR_DIM, 13.0)
		return
	_text(canvas, font, Vector2(x, y), "终局·轮核之前，该你选了。", COLOR_ACCENT, 15.0)
	y += LINE_HEIGHT * 1.2
	for option in ending.get("options", []):
		var row: Dictionary = option
		var available: bool = bool(row.get("available", false))
		var mark: String = "◆" if bool(row.get("suggested", false)) else ("·" if available else "×")
		var color: Color = COLOR_ACCENT if available else COLOR_DIM
		var line: String = "%s %s　—　%s" % [mark, str(row.get("label", "")), str(row.get("note", ""))]
		if not available:
			line += "（%s）" % str(row.get("reason", ""))
		y += _wrap(canvas, font, Vector2(x, y), line, wrap, color, 14.0) + 3.0


## 画一段会自动折行的正文，返回它占的高度（供面板往下排版）。
static func _wrap(canvas: CanvasItem, font: Font, pos: Vector2, text: String,
		width: float, color: Color, size: float) -> float:
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_ADAPTIVE
	canvas.draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, color, flags)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, flags).y


static func _text(canvas: CanvasItem, font: Font, pos: Vector2, text: String,
		color: Color, size: float) -> void:
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)