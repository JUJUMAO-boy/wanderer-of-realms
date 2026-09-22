class_name CombatPanel
extends RefCounted

## 战斗界面的绘制与命中测试（M5 的呈现层，M6.2 的一部分）。
##
## 只消费 CombatViewModel 产出的结构。画面上四块：
##   左上 战场网格（14×9）——单位、障碍、移动光标
##   右上 单位列表——血量、AP、状态；当前该动的那一行高亮
##   右下 战斗日志——只留末尾若干条
##   下方 行动菜单——主菜单 / 选目标 / 选落点 / 处理倒地者四层共用这一块
##
## 菜单项里带着完整动作字典，本类不解读它、只负责把 label 画出来，
## 因此菜单从一层换到另一层时这里一行都不用改。
##
## 鼠标交互要求"画在哪"与"点在哪"是同一份坐标，所以战场原点、单位行、
## 菜单项这三处位置都由 _field_origin / _unit_row_rect / _menu_layout 产出，
## draw 与 hit_test 都调它们。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 48.0
const TILE: float = 30.0
const FIELD_TOP: float = 56.0
const SIDE_X_OFFSET: float = 440.0
const UNIT_ROW_HEIGHT: float = 24.0
const MAX_UNIT_ROWS: int = 6
const LOG_LINE_HEIGHT: float = 21.0
const MENU_ROW_HEIGHT: float = 24.0
const MENU_MAX_ROWS: int = 4
const MENU_COLUMNS: int = 2
const FOOTER_HEIGHT: float = 62.0
const BACK_BUTTON_TOP: float = 10.0
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

	var footer_top: float = _footer_top(rect)
	_draw_battlefield(canvas, font, view, rect, hover)
	_draw_side_panel(canvas, font, view, rect, footer_top)

	canvas.draw_line(Vector2(rect.position.x + MARGIN, footer_top),
		Vector2(rect.position.x + rect.size.x - MARGIN, footer_top),
		UiTheme.COLOR_BORDER, 1.0)
	if bool(view.get("finished", false)):
		_draw_outcome(canvas, font, view, rect, footer_top)
	else:
		_draw_menu(canvas, font, view, rect, footer_top, hover)


# --- 布局（draw 与 hit_test 共用）---

static func _field_origin(rect: Rect2) -> Vector2:
	return Vector2(rect.position.x + MARGIN, rect.position.y + FIELD_TOP)


static func _side_x(rect: Rect2) -> float:
	return rect.position.x + MARGIN + SIDE_X_OFFSET


static func _footer_top(rect: Rect2) -> float:
	return rect.position.y + rect.size.y - FOOTER_HEIGHT


## 顶部右侧的返回按钮。
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


static func _unit_row_rect(rect: Rect2, index: int) -> Rect2:
	var width: float = rect.size.x - MARGIN * 2.0 - SIDE_X_OFFSET
	return Rect2(
		Vector2(_side_x(rect) - 4.0, rect.position.y + FIELD_TOP + float(index) * UNIT_ROW_HEIGHT),
		Vector2(width + 8.0, UNIT_ROW_HEIGHT - 2.0)
	)


## 战场格子的矩形。越出网格范围时返回一个空矩形。
static func _tile_rect(rect: Rect2, tile: Vector2i) -> Rect2:
	var field: Vector2i = Vector2i(CombatViewModel.BATTLE_WIDTH, CombatViewModel.BATTLE_HEIGHT)
	if tile.x < 0 or tile.y < 0 or tile.x >= field.x or tile.y >= field.y:
		return Rect2()
	return Rect2(_field_origin(rect) + Vector2(tile.x * TILE, tile.y * TILE),
		Vector2(TILE, TILE))


static func _tile_at(rect: Rect2, point: Vector2) -> Vector2i:
	var local: Vector2 = point - _field_origin(rect)
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	return Vector2i(int(local.x / TILE), int(local.y / TILE))


## 菜单项的排布。返回 {left, top, columnWidth, visible: [{index, rect}]}。
## 菜单会滚动（超过 8 项时只显示光标附近的一屏），所以可见区间要算得和绘制一致。
static func _menu_layout(rect: Rect2, view: Dictionary, top: float) -> Dictionary:
	var menu: Array = view.get("menu", [])
	var left: float = rect.position.x + MARGIN
	var width: float = rect.size.x - MARGIN * 2.0
	var column_width: float = (width - 12.0) * 0.5
	var capacity: int = MENU_MAX_ROWS * MENU_COLUMNS
	var cursor: int = int(view.get("cursor", 0))
	var start: int = 0
	if menu.size() > capacity:
		start = clampi(cursor - capacity + 1, 0, menu.size() - capacity)
	var rows: Array = []
	for index in range(start, mini(menu.size(), start + capacity)):
		var slot: int = index - start
		@warning_ignore("integer_division")
		var column: int = slot / MENU_MAX_ROWS
		var row: int = slot % MENU_MAX_ROWS
		rows.append({
			"index": index,
			"rect": Rect2(
				Vector2(left + float(column) * (column_width + 12.0),
					top + 34.0 + float(row) * MENU_ROW_HEIGHT),
				Vector2(column_width, MENU_ROW_HEIGHT - 2.0)
			),
		})
	return {
		"left": left, "top": top, "width": width, "columnWidth": column_width,
		"start": start, "capacity": capacity, "visible": rows,
	}


# --- 命中测试 ---

## 返回的 kind：button / menu（index）/ tile（x, y, unitId）/ unit（index）。
##
## 战场格子上带着站在那里的单位 ID：点空格是"走过去"，点敌人是"打它"，
## 这个区分交给主场景按当前菜单层决定，面板只管报告"点到了哪儿"。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(rect), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": true}

	if not bool(view.get("finished", false)):
		var layout: Dictionary = _menu_layout(rect, view, _footer_top(rect))
		for entry in layout["visible"]:
			if (entry["rect"] as Rect2).has_point(point):
				return {"kind": "menu", "index": int(entry["index"])}

	var tile: Vector2i = _tile_at(rect, point)
	var tile_rect: Rect2 = _tile_rect(rect, tile)
	if tile_rect.has_area() and tile_rect.has_point(point):
		return {
			"kind": "tile", "x": tile.x, "y": tile.y,
			"unitId": _unit_at(view, tile),
		}

	for index in range(int(view.get("unitRows", []).size())):
		if index >= MAX_UNIT_ROWS:
			break
		if _unit_row_rect(rect, index).has_point(point):
			return {"kind": "unit", "index": index}
	return {}


static func _unit_at(view: Dictionary, tile: Vector2i) -> String:
	for unit in view.get("battlefield", {}).get("units", []):
		if int(unit["x"]) == tile.x and int(unit["y"]) == tile.y:
			return str(unit["unitId"])
	return ""


# --- 绘制 ---

static func _draw_buttons(
	canvas: CanvasItem, font: Font, rect: Rect2, hover: Dictionary
) -> void:
	for button in buttons(rect):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]), true, hovered)


static func _draw_header(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2
) -> void:
	var left: float = rect.position.x + MARGIN
	var top: float = rect.position.y
	var width: float = rect.size.x - MARGIN * 2.0
	UiTheme.draw_text(canvas, font, Vector2(left, top + 28.0),
		"战斗 · 第 %d 轮" % int(view.get("round", 0)),
		UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)

	var current_id: String = str(view.get("currentUnitId", ""))
	var current: String = "—"
	for row in view.get("unitRows", []):
		if str(row["unitId"]) == current_id:
			current = "%s（%d AP · TU %d）" % [str(row["name"]), int(row["ap"]), int(row["tu"])]
			break
	UiTheme.draw_text(canvas, font, Vector2(left + 168.0, top + 28.0),
		"行动中：%s" % current, UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	UiTheme.draw_text_right(canvas, font,
		Vector2(_button_left(rect) - BACK_BUTTON_RESERVE, top + 28.0),
		str(view.get("menuHint", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	canvas.draw_line(Vector2(left, top + HEADER_HEIGHT - 8.0),
		Vector2(left + width, top + HEADER_HEIGHT - 8.0), UiTheme.COLOR_BORDER, 1.0)


static func _draw_battlefield(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, hover: Dictionary
) -> void:
	var field: Dictionary = view.get("battlefield", {})
	var cols: int = int(field.get("width", CombatViewModel.BATTLE_WIDTH))
	var rows: int = int(field.get("height", CombatViewModel.BATTLE_HEIGHT))
	var origin: Vector2 = _field_origin(rect)
	var size := Vector2(cols * TILE, rows * TILE)

	canvas.draw_rect(Rect2(origin, size), Color(0.075, 0.082, 0.098, 0.9))
	var line_color: Color = Color(0.15, 0.17, 0.21)
	for x in range(cols + 1):
		canvas.draw_line(Vector2(origin.x + x * TILE, origin.y),
			Vector2(origin.x + x * TILE, origin.y + size.y), line_color, 1.0)
	for x in range(rows + 1):
		canvas.draw_line(Vector2(origin.x, origin.y + x * TILE),
			Vector2(origin.x + size.x, origin.y + x * TILE), line_color, 1.0)
	canvas.draw_rect(Rect2(origin, size), UiTheme.COLOR_BORDER, false, 1.0)

	for blocked in field.get("obstacles", []):
		canvas.draw_rect(_tile_rect(rect, Vector2i(int(blocked["x"]), int(blocked["y"]))),
			Color(0.22, 0.20, 0.18))

	# 鼠标悬停的格子：让"点这里会发生什么"有一个看得见的落点
	var hover_tile := Vector2i(-1, -1)
	if str(hover.get("kind", "")) in ["tile", "menu"]:
		hover_tile = Vector2i(int(hover.get("x", -1)), int(hover.get("y", -1)))
	if hover_tile.x < 0 and str(hover.get("kind", "")) == "menu":
		hover_tile = view.get("cursorTile", Vector2i(-1, -1))
	if hover_tile.x >= 0:
		canvas.draw_rect(_tile_rect(rect, hover_tile),
			Color(UiTheme.COLOR_LINE.r, UiTheme.COLOR_LINE.g, UiTheme.COLOR_LINE.b, 0.18))

	# 移动光标：只在选落点那一层画，否则会让人以为随时能点
	if int(view.get("menuMode", -1)) == CombatViewModel.MENU_TARGET_TILE:
		canvas.draw_rect(_tile_rect(rect, view.get("cursorTile", Vector2i.ZERO)),
			UiTheme.COLOR_LINE, false, 2.0)

	for unit in field.get("units", []):
		_draw_unit_token(canvas, font, origin, unit)

	# 坐标为 0 的行列用淡字标出来，方便对照"移动到 (x, y)"这类菜单文案
	for x in range(cols):
		UiTheme.draw_text(canvas, font,
			origin + Vector2(x * TILE + TILE * 0.5 - 4.0, -6.0), str(x),
			Color(0.28, 0.30, 0.34), 10)
	for y in range(rows):
		UiTheme.draw_text(canvas, font,
			origin + Vector2(-16.0, y * TILE + TILE * 0.5 + 4.0), str(y),
			Color(0.28, 0.30, 0.34), 10)


static func _draw_unit_token(
	canvas: CanvasItem, font: Font, origin: Vector2, unit: Dictionary
) -> void:
	var is_player: bool = str(unit.get("side", "")) == Combat.SIDE_PLAYER
	var color: Color = Color(0.30, 0.62, 0.86) if is_player else Color(0.82, 0.38, 0.34)
	if bool(unit.get("dead", false)):
		color = Color(0.34, 0.30, 0.30)
	elif bool(unit.get("downed", false)):
		color = color.darkened(0.45)
	var center := origin + Vector2(int(unit["x"]) * TILE + TILE * 0.5,
		int(unit["y"]) * TILE + TILE * 0.5)
	canvas.draw_rect(Rect2(center - Vector2(TILE * 0.36, TILE * 0.36),
		Vector2(TILE * 0.72, TILE * 0.72)), color)
	if bool(unit.get("isCurrent", false)):
		canvas.draw_rect(Rect2(center - Vector2(TILE * 0.46, TILE * 0.46),
			Vector2(TILE * 0.92, TILE * 0.92)), UiTheme.COLOR_ACCENT, false, 2.0)
	UiTheme.draw_text_center(canvas, font, center + Vector2(0.0, 5.0),
		str(unit.get("initial", "?")), Color(0.06, 0.07, 0.09), UiTheme.SIZE_SMALL)
	# M22：token 下方一行名字小牌，看清"这格是谁"。名字取短名 displayName（敌人 /
	# NPC 由 encounter_system 带，英雄 / 随从退化为 name），字段空则不画省得叠字。
	var tag: String = str(unit.get("displayName", ""))
	if tag.is_empty():
		tag = str(unit.get("name", ""))
	if not tag.is_empty():
		UiTheme.draw_text_center(canvas, font, center + Vector2(0.0, 24.0),
			tag, Color(0.92, 0.94, 0.97), UiTheme.SIZE_SMALL)


## 右上：单位列表 + 战斗日志。
static func _draw_side_panel(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, bottom: float
) -> void:
	var x: float = _side_x(rect)
	var width: float = rect.size.x - MARGIN * 2.0 - SIDE_X_OFFSET
	var units: Array = view.get("unitRows", [])
	for index in range(mini(MAX_UNIT_ROWS, units.size())):
		var unit: Dictionary = units[index]
		var row_rect: Rect2 = _unit_row_rect(rect, index)
		var row_y: float = row_rect.position.y + 16.0
		if bool(unit.get("isCurrent", false)):
			canvas.draw_rect(row_rect, UiTheme.COLOR_SELECTED)
		# M22：用 identity（本名 · 类别）当名字，侧栏一眼看清身份
		UiTheme.draw_text(canvas, font, Vector2(x, row_y), str(unit["identity"]),
			UiTheme.COLOR_TEXT if str(unit.get("side", "")) == Combat.SIDE_PLAYER \
				else UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		UiTheme.draw_bar(canvas,
			Rect2(Vector2(x + 128.0, row_rect.position.y + 6.0), Vector2(180.0, 9.0)),
			float(unit["hpRatio"]))
		UiTheme.draw_text(canvas, font, Vector2(x + 316.0, row_y),
			"%d/%d" % [int(unit["hp"]), int(unit["maxHp"])],
			UiTheme.COLOR_TEXT, UiTheme.SIZE_SMALL)
		UiTheme.draw_text(canvas, font, Vector2(x + 400.0, row_y),
			"%d AP" % int(unit["ap"]), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		var chain_stacks: int = int(unit.get("chain", 0))
		if chain_stacks > 0:
			UiTheme.draw_text(canvas, font, Vector2(x + 452.0, row_y),
				"连携 %d" % chain_stacks, UiTheme.COLOR_ACCENT, UiTheme.SIZE_SMALL)
		UiTheme.draw_text_right(canvas, font, Vector2(x + width - 4.0, row_y),
			str(unit["statusLabel"]), UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)

	var y: float = rect.position.y + FIELD_TOP \
		+ float(mini(MAX_UNIT_ROWS, units.size())) * UNIT_ROW_HEIGHT
	if units.size() > MAX_UNIT_ROWS:
		UiTheme.draw_text(canvas, font, Vector2(x, y + 14.0),
			"…… 另有 %d 名参战者" % (units.size() - MAX_UNIT_ROWS),
			UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		y += UNIT_ROW_HEIGHT

	y += 12.0
	UiTheme.draw_section_title(canvas, font, Vector2(x, y + 14.0), "战斗日志", width)
	y += 22.0

	var lines: Array = view.get("logTail", [])
	if lines.is_empty():
		UiTheme.draw_text(canvas, font, Vector2(x, y + 16.0),
			"尚未交手。", UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		return
	var available: int = maxi(0, int((bottom - y) / LOG_LINE_HEIGHT))
	var start: int = maxi(0, lines.size() - available)
	if start > 0:
		UiTheme.draw_text(canvas, font, Vector2(x, y + 14.0),
			"…… 之前还有 %d 条" % start, UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		y += LOG_LINE_HEIGHT
		available -= 1
	for index in range(start, mini(lines.size(), start + available)):
		UiTheme.draw_text(canvas, font, Vector2(x, y + 14.0),
			str(lines[index]), UiTheme.COLOR_TEXT, UiTheme.SIZE_SMALL)
		y += LOG_LINE_HEIGHT


## 下方：行动菜单。列为两栏，避免技能多起来时一栏列到屏幕外。
static func _draw_menu(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, top: float,
	hover: Dictionary
) -> void:
	var layout: Dictionary = _menu_layout(rect, view, top)
	var left: float = layout["left"]
	var width: float = layout["width"]
	var menu: Array = view.get("menu", [])
	UiTheme.draw_text(canvas, font, Vector2(left, top + 22.0),
		str(view.get("menuLabel", "")), UiTheme.COLOR_ACCENT, UiTheme.SIZE_NORMAL)
	if menu.is_empty():
		UiTheme.draw_text(canvas, font, Vector2(left, top + 46.0),
			"现在没有可执行的动作（可能 AP 已用尽）。",
			UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return

	var cursor: int = int(view.get("cursor", 0))
	var hovered_index: int = int(hover.get("index", -1)) \
		if str(hover.get("kind", "")) == "menu" else -1
	for entry in layout["visible"]:
		var index: int = int(entry["index"])
		var item_rect: Rect2 = entry["rect"]
		var enabled: bool = bool(menu[index].get("enabled", true))
		if index == cursor:
			canvas.draw_rect(item_rect, UiTheme.COLOR_SELECTED)
			canvas.draw_rect(item_rect, UiTheme.COLOR_ACCENT, false, 1.0)
		elif index == hovered_index and enabled:
			canvas.draw_rect(item_rect, Color(UiTheme.COLOR_SELECTED.r, UiTheme.COLOR_SELECTED.g,
				UiTheme.COLOR_SELECTED.b, 0.45))
		var color: Color = UiTheme.COLOR_TEXT if enabled else UiTheme.COLOR_DIM
		if index == cursor:
			color = UiTheme.COLOR_ACCENT
		UiTheme.draw_text(canvas, font, Vector2(item_rect.position.x + 8.0,
			item_rect.position.y + 16.0), str(menu[index].get("label", "")),
			color, UiTheme.SIZE_SMALL)

	if menu.size() > int(layout["capacity"]):
		UiTheme.draw_text_right(canvas, font, Vector2(left + width, top + 22.0),
			"%d / %d 项" % [cursor + 1, menu.size()], UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


## 战斗结束后的结算块：胜负、掉落、以及留给世界的标记。
static func _draw_outcome(
	canvas: CanvasItem, font: Font, view: Dictionary, rect: Rect2, top: float
) -> void:
	var left: float = rect.position.x + MARGIN
	var width: float = rect.size.x - MARGIN * 2.0
	var won: bool = str(view.get("winner", "")) == Combat.RESULT_PLAYER
	UiTheme.draw_text(canvas, font, Vector2(left, top + 24.0),
		"战斗结束 · %s" % ("你赢了" if won else "你输了"),
		UiTheme.COLOR_UP if won else UiTheme.COLOR_DOWN, UiTheme.SIZE_TITLE)

	var loot: Array = view.get("loot", [])
	var loot_text: String = "无"
	if not loot.is_empty():
		var parts: Array = []
		for entry in loot:
			parts.append(str(entry.get("displayName", entry.get("templateId", "?"))))
		loot_text = "、".join(PackedStringArray(parts))
	UiTheme.draw_text(canvas, font, Vector2(left + 240.0, top + 24.0),
		"战利品：%s" % loot_text, UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)

	var flags: Dictionary = view.get("worldFlags", {})
	if not flags.is_empty():
		var parts: Array = []
		for key in flags:
			parts.append("%s=%s" % [str(key), str(flags[key])])
		UiTheme.draw_text(canvas, font, Vector2(left, top + 50.0),
			"世界标记：" + "  ".join(PackedStringArray(parts)),
			UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)

	UiTheme.draw_text_right(canvas, font, Vector2(left + width, top + 50.0),
		"回车 / ESC 返回地图", UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
