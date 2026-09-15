class_name CreationPanel
extends RefCounted

## 开局创建界面的绘制与命中测试（M3.1 自由生成 + M3.2 随机转生）。
##
## 与 CityPanel 同构：只消费 CreationViewModel 产出的结构，不做任何数值加工。
## 界面上分五段（种族 / 出身 / 属性 / 天赋缺陷 / 确认），顶部一条段标签，
## 中间是当前段的条目，底部是校验结果与动作按钮。
##
## 段标签做成可点的是两层考虑：它同时是进度指示（一眼看出"还有两段就填完了"），
## 以及**回上一步的入口**。原先只有 ESC 能往回走，而界面上一个字都没提它——
## 玩家按 TAB 只会一路往前，撞到确认页才发现没有回头路。
##
## 鼠标交互要求"画在哪"与"点在哪"是同一份坐标。这个类里所有可点元素的位置
## 都由 _tab_rect / _row_rect / _stepper_rect / buttons 产出，draw 与 hit_test
## 都调它们，于是两边不可能算出不同的位置。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 88.0
const ROW_HEIGHT: float = 28.0
const TAB_WIDTH: float = 148.0
const TAB_HEIGHT: float = 28.0
const TAB_TOP: float = 46.0
const FOOTER_HEIGHT: float = 58.0
const ROW_TOP_PAD: float = 4.0

## 属性行的横向布局。加减按钮紧跟在分配条右边，而不是丢到行尾——
## 它改的就是那根条，离得越近越不容易点错行。
const ATTR_LABEL_X: float = 8.0
const ATTR_BAR_X: float = 100.0
const ATTR_BAR_WIDTH: float = 200.0
const STEPPER_SIZE: float = 22.0
const STEPPER_GAP: float = 6.0
const STEPPER_INSET: float = 14.0
const ATTR_TEXT_GAP: float = 12.0


## view 结构：CreationViewModel.build 的返回值。hover 是 hit_test 上一次的结果，
## 只用来高亮，不参与任何判断。
static func draw(
	canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}
) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	canvas.draw_rect(rect, UiTheme.COLOR_BG)
	canvas.draw_rect(rect, UiTheme.COLOR_BORDER, false, 1.0)

	_draw_header(canvas, font, view, rect, hover)
	_draw_rows(canvas, font, view, rect, hover)
	_draw_footer(canvas, font, view, rect, hover)


# --- 布局（draw 与 hit_test 共用）---

static func _rows_rect(rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(rect.position.x + MARGIN, rect.position.y + HEADER_HEIGHT),
		Vector2(rect.size.x - MARGIN * 2.0, rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT)
	)


static func _tab_rect(rect: Rect2, index: int) -> Rect2:
	return Rect2(
		Vector2(
			rect.position.x + MARGIN + float(index) * TAB_WIDTH,
			rect.position.y + TAB_TOP
		),
		Vector2(TAB_WIDTH - 6.0, TAB_HEIGHT)
	)


## 滚动窗口。光标始终留在可见区内，条目装得下时不滚。
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


## 属性行的加减按钮。plus 为真给「+」，为假给「−」。
static func _stepper_rect(row_rect: Rect2, plus: bool) -> Rect2:
	var second: float = STEPPER_SIZE + STEPPER_GAP
	var x: float = row_rect.position.x + ATTR_BAR_X + ATTR_BAR_WIDTH + STEPPER_INSET
	if plus:
		x += second
	return Rect2(Vector2(x, row_rect.position.y + 2.0), Vector2(STEPPER_SIZE, STEPPER_SIZE))


## 底部动作按钮。测试与命中测试都靠它拿位置。
static func buttons(view: Dictionary, rect: Rect2) -> Array:
	var section: int = int(view.get("section", 0))
	var free_mode: bool = int(view.get("mode", 0)) == CreationViewModel.MODE_FREE
	var specs: Array = [
		{"id": "back", "label": "← 上一步", "enabled": free_mode and section > 0},
		{"id": "reroll", "label": "重掷姓名"},
		{"id": "mode", "label": "切换开局方式"},
	]
	if section == CreationViewModel.SECTION_CONFIRM:
		specs.append({
			"id": "start", "label": "开始这一生",
			"enabled": bool(view.get("canStart", false)),
		})
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + rect.size.y - FOOTER_HEIGHT + 4.0,
		specs
	)


# --- 命中测试 ---

## point 落在什么上。返回空字典表示没落在任何可点元素上。
## 返回的 kind：tab / option / attribute_plus / attribute_minus / toggle /
## row / button。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}

	var button: Dictionary = UiTheme.hit_button(buttons(view, rect), point)
	if not button.is_empty():
		return {
			"kind": "button",
			"id": str(button["id"]),
			"enabled": bool(button["enabled"]),
		}

	var labels: Array = view.get("sectionLabels", [])
	for index in range(labels.size()):
		if _tab_rect(rect, index).has_point(point):
			return {"kind": "tab", "index": index, "enabled": _tab_enabled(view, index)}

	var index: int = _row_at(view, rect, point)
	if index < 0:
		return {}
	var row_rect: Rect2 = _row_rect(rect, view, index)
	match int(view.get("section", 0)):
		CreationViewModel.SECTION_ATTRIBUTES:
			if _stepper_rect(row_rect, false).has_point(point):
				return {"kind": "attribute_minus", "index": index}
			if _stepper_rect(row_rect, true).has_point(point):
				return {"kind": "attribute_plus", "index": index}
			return {"kind": "row", "index": index}
		CreationViewModel.SECTION_TRAITS:
			return {"kind": "toggle", "index": index}
		CreationViewModel.SECTION_RACE, CreationViewModel.SECTION_BACKGROUND:
			return {"kind": "option", "index": index}
	return {"kind": "row", "index": index}


## 转生模式没有种族/出身/属性/天赋这几段可填，标签只作进度用，点了不该跳过去。
static func _tab_enabled(view: Dictionary, index: int) -> bool:
	if int(view.get("mode", 0)) != CreationViewModel.MODE_FREE:
		return index == CreationViewModel.SECTION_CONFIRM
	return true


static func _row_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var rows_rect: Rect2 = _rows_rect(rect)
	var window: Dictionary = _visible_window(view, rows_rect)
	var last: int = mini(int(window["count"]), int(window["start"]) + int(window["visible"]))
	for index in range(int(window["start"]), last):
		if _row_rect(rect, view, index).has_point(point):
			return index
	return -1


# --- 绘制 ---

static func _draw_header(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	var width: float = rect.size.x - MARGIN * 2.0
	var mode: int = int(view.get("mode", 0))
	UiTheme.draw_text(canvas, font, Vector2(left, top + 30.0),
		"开局创建", UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, Vector2(left + 118.0, top + 30.0),
		"自由生成" if mode == CreationViewModel.MODE_FREE else "随机转生（宿主躯壳）",
		UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font, Vector2(left + width, top + 30.0),
		"点段标签可直接跳段", UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	# 段标签：当前段高亮，已填完的段用正向色标出来，让进度可扫
	var labels: Array = view.get("sectionLabels", [])
	var section: int = int(view.get("section", 0))
	for index in range(labels.size()):
		var tab: Rect2 = _tab_rect(rect, index)
		var enabled: bool = _tab_enabled(view, index)
		var hovered: bool = str(hover.get("kind", "")) == "tab" \
			and int(hover.get("index", -1)) == index and enabled
		if index == section:
			canvas.draw_rect(tab, UiTheme.COLOR_SELECTED)
		elif hovered:
			canvas.draw_rect(tab, UiTheme.COLOR_LIST_BG)
		canvas.draw_rect(tab, UiTheme.COLOR_ACCENT if hovered else UiTheme.COLOR_BORDER, false, 1.0)
		var color: Color = UiTheme.COLOR_DIM
		if not enabled:
			color = Color(UiTheme.COLOR_DIM.r, UiTheme.COLOR_DIM.g, UiTheme.COLOR_DIM.b, 0.5)
		elif index == section:
			color = UiTheme.COLOR_ACCENT
		elif _section_ready(view, index):
			color = UiTheme.COLOR_UP
		else:
			color = UiTheme.COLOR_TEXT
		UiTheme.draw_text_center(canvas, font,
			Vector2(tab.position.x + tab.size.x * 0.5, tab.position.y + 19.0),
			str(labels[index]), color, UiTheme.SIZE_SMALL)

	canvas.draw_line(
		Vector2(left, top + HEADER_HEIGHT - 8.0),
		Vector2(left + width, top + HEADER_HEIGHT - 8.0),
		UiTheme.COLOR_BORDER, 1.0
	)


## 该段是否已经填好。只做"有没有值"的粗判定，真正的合法性由 validate 说话——
## 这里错了顶多是标签颜色不准，不会让玩家开不了局。
static func _section_ready(view: Dictionary, index: int) -> bool:
	match index:
		CreationViewModel.SECTION_RACE:
			return not str(view.get("raceId", "")).is_empty()
		CreationViewModel.SECTION_BACKGROUND:
			return not str(view.get("backgroundId", "")).is_empty()
		CreationViewModel.SECTION_ATTRIBUTES:
			return int(view.get("remainingPoints", 0)) == 0
		CreationViewModel.SECTION_TRAITS:
			return int(view.get("talentCount", 0)) == int(view.get("flawCount", 0)) \
				and int(view.get("talentCount", 0)) > 0
		CreationViewModel.SECTION_CONFIRM:
			return bool(view.get("canStart", false))
	return false


static func _draw_rows(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var rows: Array = view.get("rows", [])
	var rows_rect: Rect2 = _rows_rect(rect)
	if rows.is_empty():
		UiTheme.draw_text(canvas, font, rows_rect.position + Vector2(8.0, 24.0),
			"这一段没有可选项。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return
	var section: int = int(view.get("section", 0))
	var cursor: int = int(view.get("cursor", 0))
	var window: Dictionary = _visible_window(view, rows_rect)
	var last: int = mini(rows.size(), int(window["start"]) + int(window["visible"]))
	for index in range(int(window["start"]), last):
		var row_rect: Rect2 = _row_rect(rect, view, index)
		var hovered: bool = _hover_row(hover, index)
		if index == cursor:
			canvas.draw_rect(row_rect, UiTheme.COLOR_SELECTED)
		elif hovered:
			canvas.draw_rect(row_rect, Color(UiTheme.COLOR_SELECTED.r, UiTheme.COLOR_SELECTED.g,
				UiTheme.COLOR_SELECTED.b, 0.45))
		_draw_row(canvas, font, section, rows[index], row_rect, index == cursor, hover,
			index, view)

	if rows.size() > int(window["visible"]):
		UiTheme.draw_text_right(canvas, font,
			Vector2(rows_rect.position.x + rows_rect.size.x - 6.0,
				rows_rect.position.y + rows_rect.size.y + 14.0),
			"%d / %d 条（↑↓ 移动）" % [cursor + 1, rows.size()],
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _hover_row(hover: Dictionary, index: int) -> bool:
	if int(hover.get("index", -1)) != index:
		return false
	return str(hover.get("kind", "")) in ["row", "option", "toggle",
		"attribute_plus", "attribute_minus"]


static func _draw_row(
	canvas: CanvasItem, font: Font, section: int, row: Dictionary, rect: Rect2,
	selected: bool, hover: Dictionary, index: int, view: Dictionary
) -> void:
	match section:
		CreationViewModel.SECTION_ATTRIBUTES:
			_draw_attribute_row(canvas, font, row, rect, selected, hover, index, view)
		CreationViewModel.SECTION_TRAITS:
			_draw_trait_row(canvas, font, row, rect, selected)
		CreationViewModel.SECTION_CONFIRM:
			_draw_confirm_row(canvas, font, row, rect)
		_:
			_draw_choice_row(canvas, font, row, rect)


## 种族 / 出身：一行一项，左边名称、右边说明，当前选中的打勾。
static func _draw_choice_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2
) -> void:
	var chosen: bool = bool(row.get("selected", false))
	var color: Color = UiTheme.COLOR_TEXT if chosen else UiTheme.COLOR_DIM
	var cursor_x: float = rect.position.x + 8.0
	if chosen:
		UiTheme.draw_text(canvas, font, Vector2(cursor_x, rect.position.y + 17.0),
			"●", UiTheme.COLOR_ACCENT, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text(canvas, font, Vector2(cursor_x + 16.0, rect.position.y + 17.0),
		str(row.get("label", "")), color, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - 10.0, rect.position.y + 17.0),
		str(row.get("hint", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


## 属性行：名称 · 分配点数的条 · − / + · 种族偏移 · 最终值 + 档位。
## 只显示分配点数的条（而不是最终值）是有意的——玩家能改的只有分配，
## 种族偏移与起点都是既成事实，混在一根条里会让"我还能加多少"看不出来。
static func _draw_attribute_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2, selected: bool,
	hover: Dictionary, index: int, view: Dictionary
) -> void:
	var y: float = rect.position.y + 17.0
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + ATTR_LABEL_X, y),
		str(row.get("label", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)

	var allocated: int = int(row.get("allocated", 0))
	var cap: int = maxi(1, int(view.get("perAttributeCap", 10)))
	var remaining: int = int(view.get("remainingPoints", 0))
	var bar_rect := Rect2(
		Vector2(rect.position.x + ATTR_BAR_X, rect.position.y + 7.0),
		Vector2(ATTR_BAR_WIDTH, 9.0)
	)
	UiTheme.draw_bar(canvas, bar_rect, float(allocated) / float(cap), UiTheme.COLOR_BAR, false)

	_draw_stepper(canvas, font, _stepper_rect(rect, false), "−", allocated > 0,
		_hover_kind(hover, index) == "attribute_minus")
	_draw_stepper(canvas, font, _stepper_rect(rect, true), "+",
		remaining > 0 and allocated < cap,
		_hover_kind(hover, index) == "attribute_plus")

	var text_x: float = _stepper_rect(rect, true).position.x + STEPPER_SIZE + ATTR_TEXT_GAP
	var alloc_text: String = "分配 +%d" % allocated if allocated > 0 else "未分配"
	UiTheme.draw_text(canvas, font, Vector2(text_x, y),
		alloc_text, UiTheme.COLOR_ACCENT if selected else UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	var offset: int = int(row.get("offset", 0))
	if offset != 0:
		UiTheme.draw_text(canvas, font, Vector2(text_x + 84.0, y),
			"种族 %+d" % offset,
			UiTheme.COLOR_UP if offset > 0 else UiTheme.COLOR_DOWN, UiTheme.SIZE_SMALL)

	var final_value: int = int(row.get("final", 0))
	UiTheme.draw_text_right(canvas, font,
		Vector2(rect.position.x + rect.size.x - 10.0, y),
		"最终 %d（%s）" % [final_value, AvatarViewModel.tier_label(
			final_value, AvatarViewModel.ATTRIBUTE_TIERS
		)],
		UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)


static func _hover_kind(hover: Dictionary, index: int) -> String:
	if int(hover.get("index", -1)) != index:
		return ""
	return str(hover.get("kind", ""))


## 小方块加减按钮。不可用时变灰——"减到 0 了"和"点数用完了"这两件事
## 靠按钮变灰就能看出来，不必等按下去被拦。
static func _draw_stepper(
	canvas: CanvasItem, font: Font, rect: Rect2, label: String, enabled: bool, hovered: bool
) -> void:
	canvas.draw_rect(rect, UiTheme.COLOR_SELECTED if hovered and enabled else UiTheme.COLOR_LIST_BG)
	canvas.draw_rect(rect,
		UiTheme.COLOR_ACCENT if hovered and enabled else UiTheme.COLOR_BORDER, false, 1.0)
	var color: Color = UiTheme.COLOR_DIM
	if enabled:
		color = UiTheme.COLOR_ACCENT if hovered else UiTheme.COLOR_TEXT
	UiTheme.draw_text_center(canvas, font,
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5 + 5.0),
		label, color, UiTheme.SIZE_NORMAL)


## 天赋 / 缺陷行：勾选框 + 名称 + 当量 + 效果。
static func _draw_trait_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2, selected: bool
) -> void:
	var y: float = rect.position.y + 17.0
	var chosen: bool = bool(row.get("selected", false))
	var is_talent: bool = str(row.get("categoryLabel", "")) == "天赋"

	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 8.0, y),
		"[×]" if chosen else "[ ]",
		UiTheme.COLOR_ACCENT if chosen else UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 44.0, y),
		"天赋" if is_talent else "缺陷",
		UiTheme.COLOR_UP if is_talent else UiTheme.COLOR_DOWN, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 84.0, y),
		str(row.get("label", "")), UiTheme.COLOR_TEXT if chosen else UiTheme.COLOR_DIM,
		UiTheme.SIZE_NORMAL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 188.0, y),
		str(row.get("weightLabel", "")),
		UiTheme.COLOR_ACCENT if selected else UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 222.0, y),
		str(row.get("effectText", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


static func _draw_confirm_row(
	canvas: CanvasItem, font: Font, row: Dictionary, rect: Rect2
) -> void:
	var y: float = rect.position.y + 17.0
	var kind: String = str(row.get("kind", "plain"))
	var label_color: Color = UiTheme.COLOR_DIM
	var value_color: Color = UiTheme.COLOR_TEXT
	if kind == "trait":
		label_color = UiTheme.COLOR_UP if str(row.get("label", "")).ends_with("天赋") \
			else UiTheme.COLOR_DOWN
		value_color = UiTheme.COLOR_DIM
	elif kind == "pending":
		label_color = UiTheme.COLOR_WARN
		value_color = UiTheme.COLOR_WARN
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 8.0, y),
		str(row.get("label", "")), label_color, UiTheme.SIZE_SMALL)
	UiTheme.draw_text(canvas, font, Vector2(rect.position.x + 150.0, y),
		str(row.get("value", "")), value_color, UiTheme.SIZE_NORMAL)


static func _draw_footer(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y + rect.size.y - FOOTER_HEIGHT
	var width: float = rect.size.x - MARGIN * 2.0
	canvas.draw_line(Vector2(left, top), Vector2(left + width, top),
		UiTheme.COLOR_BORDER, 1.0)

	var errors: Array = view.get("errors", [])
	var mode: int = int(view.get("mode", 0))
	if mode == CreationViewModel.MODE_FREE:
		var total: int = int(view.get("allocatablePoints", 0))
		var remaining: int = int(view.get("remainingPoints", 0))
		UiTheme.draw_text(canvas, font, Vector2(left, top + 22.0),
			"可分配点数 %d/%d" % [remaining, total],
			UiTheme.COLOR_ACCENT if remaining > 0 else UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text(canvas, font, Vector2(left + 160.0, top + 22.0),
			"天赋 %d / 缺陷 %d" % [int(view.get("talentCount", 0)), int(view.get("flawCount", 0))],
			UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	else:
		# 转生没有"分配点"这回事：属性由躯壳与前世加成决定，
		# 所以这一栏改说清它继承了什么，而不是留白。
		UiTheme.draw_text(canvas, font, Vector2(left, top + 22.0),
			"躯壳与前世决定属性，没有创建期分配点。",
			UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)

	# 校验结果最多显示两条。列表再长玩家也只会先改第一条，
	# 与其堆满屏幕不如把最新两条摆在按键提示上方。
	var error_y: float = top + 42.0
	for index in range(mini(2, errors.size())):
		UiTheme.draw_text(canvas, font, Vector2(left, error_y),
			"· " + str(errors[index]), UiTheme.COLOR_DOWN, UiTheme.SIZE_SMALL)
		error_y += 16.0
	if errors.size() > 2:
		UiTheme.draw_text(canvas, font, Vector2(left, error_y),
			"· 还有 %d 项问题" % (errors.size() - 2), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	var hint: String = str(view.get("sectionHint", ""))
	UiTheme.draw_text_right(canvas, font, Vector2(left + width, top + 42.0),
		hint, UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	for button in buttons(view, rect):
		var button_rect: Rect2 = button["rect"]
		var button_id: String = str(button["id"])
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == button_id
		UiTheme.draw_button(canvas, font, button_rect, str(button["label"]),
			bool(button["enabled"]), hovered)
