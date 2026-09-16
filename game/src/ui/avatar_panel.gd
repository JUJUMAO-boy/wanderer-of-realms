class_name AvatarPanel
extends RefCounted

## 角色面板的绘制（M6.2「含角色面板、背包、任务列表、对话」里的角色与背包两项，
## 以及其后补上的装备槽与穿脱）。
##
## 只消费 AvatarViewModel 产出的结构。分左右两栏：左栏是"这个人是谁"
## （属性、装备、天赋缺陷、声誉、宿主遗留），右栏是"他现在能做什么"
## （派生值、技能、背包）。这个分法的理由是把随世代变化的东西放左边、
## 随当前状态变化的东西放右边，转生之后扫一眼就知道哪些归零了。
##
## 装备与背包是这一屏**唯一能动手**的两段：装备槽在左栏最后一段（紧挨属性，
## 将来若加力量门槛，门槛与后果就在同一屏的上下两行），背包在右栏最末。
## 光标是一个整数走完两段（0–4 是槽、5 起是背包），见 AvatarViewModel.cursor_kind。
##
## 每一段都是"画得下多少画多少"：超出下沿的条目折成一行"N 项未显示"。
## 条目数由配置决定（技能 35 条、物品 40 件都可能全进背包），
## 手算固定高度迟早会溢出。背包因此还要滚动——光标移出可视范围时窗口跟着走。

const MARGIN: float = 16.0
const HEADER_HEIGHT: float = 76.0
const COLUMN_WIDTH: float = 596.0
const COLUMN_GAP: float = 24.0
const ROW_HEIGHT: float = 24.0
const SECTION_GAP: float = 12.0
const SECTION_TITLE_HEIGHT: float = 22.0
## 背包至少保留几行。技能条数会随内容长，背包却是可操作的那一段——
## 被信息段挤掉就等于功能没了，所以先给背包留出行数，剩下的高度才轮到技能。
const MIN_BAG_ROWS: int = 4
## 返回按钮占住标题行右侧，金额排在它左边。放底部会白白吃掉一行高度——
## 角色面板的段落是"装不下就截断"的，少一行就意味着声誉或前世遗留被截掉。
const BACK_BUTTON_TOP: float = 12.0
const BACK_BUTTON_RESERVE: float = 16.0

## 装备那两段一行里要写四项（名字、稀有度、数值、词缀），而每一段的宽度是固定的，
## 所以每一项都要自己收住长度——让它画出去会压到右边那一项，看起来像两段文字叠在一起。
## 12 号字下中文约 12px 宽，这几个数字就是"这一列有多少像素 ÷ 12"。
const EQUIP_LABEL_X: float = 60.0
const EQUIP_RARITY_X: float = 185.0
const EQUIP_DETAIL_X: float = 235.0
const EQUIP_AFFIX_X: float = 400.0
const EQUIP_DETAIL_CHARS: int = 13
const EQUIP_AFFIX_CHARS: int = 16
const BAG_RARITY_X: float = 165.0
const BAG_DETAIL_X: float = 225.0
const BAG_AFFIX_X: float = 340.0
const BAG_DETAIL_CHARS: int = 9
const BAG_AFFIX_CHARS: int = 21


static func draw(
	canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}
) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null or view.is_empty():
		return
	canvas.draw_rect(rect, UiTheme.COLOR_BG)
	canvas.draw_rect(rect, UiTheme.COLOR_BORDER, false, 1.0)

	var left: float = rect.position.x + MARGIN
	var right_edge: float = rect.position.x + rect.size.x - MARGIN
	var info_right: float = _button_left(rect) - BACK_BUTTON_RESERVE
	_draw_header(canvas, font, view, left, rect.position.y, info_right, right_edge - left)
	_draw_buttons(canvas, font, rect, hover)

	var bottom: float = rect.position.y + rect.size.y - 10.0
	var top: float = rect.position.y + HEADER_HEIGHT
	var right_x: float = left + COLUMN_WIDTH + COLUMN_GAP
	var right_width: float = right_edge - right_x

	var y_left: float = top
	y_left = _draw_attribute_section(canvas, font, view.get("attributeRows", []),
		left, y_left, COLUMN_WIDTH, bottom)
	y_left = _draw_equipment_section(canvas, font, view, left, y_left, COLUMN_WIDTH, bottom, hover)
	y_left = _draw_entry_section(canvas, font, "天赋 / 缺陷", view.get("talentRows", []),
		left, y_left, COLUMN_WIDTH, bottom)
	y_left = _draw_reputation_section(canvas, font, view.get("reputationRows", []),
		left, y_left, COLUMN_WIDTH, bottom)
	_draw_legacy_section(canvas, font, view.get("legacyRows", []),
		left, y_left, COLUMN_WIDTH, bottom)

	var layout: Dictionary = right_layout(view, top, bottom)
	_draw_derived_section(canvas, font, view.get("derivedRows", []),
		right_x, float(layout["derivedTop"]), right_width, bottom, int(layout["derivedVisible"]))
	_draw_skill_section(canvas, font, view.get("skillRows", []),
		right_x, float(layout["skillTop"]), right_width, bottom, int(layout["skillVisible"]))
	_draw_bag_section(canvas, font, view, right_x, float(layout["bagTop"]), right_width, bottom,
		int(layout["bagVisible"]), hover)


# --- 布局（draw 与 hit_test 共用）---

## 右栏的纵向分工：派生值按实际条数画，技能与背包分剩下的高度——背包**先**留出
## MIN_BAG_ROWS 行，剩下的才轮到技能。两段的可视行数都由这里算出来，
## 绘制与命中测试共用，于是"背包行画在这里、点在那里"不可能发生。
static func right_layout(view: Dictionary, top: float, bottom: float) -> Dictionary:
	var derived_rows: Array = view.get("derivedRows", [])
	var skill_rows: Array = view.get("skillRows", [])
	var bag_rows: Array = view.get("inventoryRows", [])

	var derived_visible: int = _visible_rows(bottom - top, derived_rows.size())
	var derived_top: float = top
	var after_derived: float = top + _block_height(derived_visible)

	var skill_top: float = after_derived
	# 背包要留出的高度：行数不够 MIN_BAG_ROWS 时按实际条数留；一件都没有时
	# 也要留一行给"空无一物"
	var bag_lines: int = maxi(1, mini(bag_rows.size(), MIN_BAG_ROWS))
	var skill_capacity: int = int(maxf(0.0,
		bottom - skill_top - _block_height(bag_lines) - SECTION_TITLE_HEIGHT) / ROW_HEIGHT)
	var skill_visible: int = mini(skill_rows.size(), maxi(0, skill_capacity))
	var skill_block: float = SECTION_TITLE_HEIGHT \
		+ ROW_HEIGHT * float(maxi(1, skill_visible)) + SECTION_GAP
	var bag_top: float = skill_top + skill_block
	var bag_visible: int = _visible_rows(bottom - bag_top, bag_rows.size())
	return {
		"derivedTop": derived_top, "derivedVisible": derived_visible,
		"skillTop": skill_top, "skillVisible": skill_visible,
		"bagTop": bag_top, "bagVisible": bag_visible,
	}


## 左栏「装备」段的起点。它前面只有属性一段，而属性段本身也会截断——
## 所以起点按属性**实际画了几行**算，不按属性行数算。
static func left_layout(view: Dictionary, rect: Rect2) -> Dictionary:
	var top: float = rect.position.y + HEADER_HEIGHT
	var bottom: float = rect.position.y + rect.size.y - 10.0
	var attribute_rows: Array = view.get("attributeRows", [])
	var attribute_visible: int = _visible_rows(bottom - top, attribute_rows.size())
	var equipment_top: float = top + _block_height(attribute_visible) + SECTION_TITLE_HEIGHT
	var equipment_rows: Array = view.get("equipmentRows", [])
	var equipment_visible: int = _visible_rows(bottom - equipment_top, equipment_rows.size())
	return {
		"attributeTop": top, "attributeVisible": attribute_visible,
		"equipmentTop": equipment_top, "equipmentVisible": equipment_visible,
	}


## 一段占的高度：抬头 + 若干行 + 段间空隙。
static func _block_height(visible: int) -> float:
	return SECTION_TITLE_HEIGHT + ROW_HEIGHT * float(visible) + SECTION_GAP


## 给定可用高度，一段能画几行。绘制与命中测试共用这一个算式。
static func _visible_rows(available: float, count: int) -> int:
	return clampi(int((available - SECTION_TITLE_HEIGHT) / ROW_HEIGHT), 0, count)


## 左栏装备槽第 index 行的矩形。
static func slot_row_rect(rect: Rect2, view: Dictionary, index: int) -> Rect2:
	var layout: Dictionary = left_layout(view, rect)
	var y: float = float(layout["equipmentTop"]) + SECTION_TITLE_HEIGHT + float(index) * ROW_HEIGHT
	return Rect2(Vector2(rect.position.x + MARGIN, y), Vector2(COLUMN_WIDTH, ROW_HEIGHT))


## 背包的滚动窗口。光标在槽位段时窗口归零——槽在上、背包在下，
## 人的注意力跟着光标走，这时背包从头显示最自然。
static func bag_window(view: Dictionary, visible: int) -> Dictionary:
	var rows: Array = view.get("inventoryRows", [])
	var count: int = rows.size()
	var cursor_bag: int = AvatarViewModel.bag_index_of(view, int(view.get("cursor", -1)))
	var start: int = 0
	if cursor_bag >= 0 and count > visible:
		start = clampi(cursor_bag - visible + 1, 0, count - visible)
	return {"start": start, "visible": visible, "count": count}


## 右栏背包第 index 行的矩形（index 是它在背包里的序号，不是光标序号）。
static func bag_row_rect(rect: Rect2, view: Dictionary, index: int) -> Rect2:
	var top: float = rect.position.y + HEADER_HEIGHT
	var bottom: float = rect.position.y + rect.size.y - 10.0
	var layout: Dictionary = right_layout(view, top, bottom)
	var window: Dictionary = bag_window(view, int(layout["bagVisible"]))
	var offset: int = index - int(window["start"])
	var x: float = rect.position.x + MARGIN + COLUMN_WIDTH + COLUMN_GAP
	var width: float = rect.size.x - COLUMN_WIDTH - COLUMN_GAP - MARGIN * 2.0
	return Rect2(
		Vector2(x, float(layout["bagTop"]) + SECTION_TITLE_HEIGHT + float(offset) * ROW_HEIGHT),
		Vector2(width, ROW_HEIGHT)
	)


static func _slot_row_highlighted(view: Dictionary, index: int, hover: Dictionary) -> int:
	var cursor: int = int(view.get("cursor", -1))
	if index == cursor:
		return 1
	if str(hover.get("kind", "")) == AvatarViewModel.CURSOR_KIND_SLOT \
			and int(hover.get("index", -1)) == index:
		return 2
	return 0


static func _bag_row_highlighted(view: Dictionary, bag_index: int, hover: Dictionary) -> int:
	var slots: Array = view.get("equipmentRows", [])
	var unified: int = slots.size() + bag_index
	if unified == int(view.get("cursor", -1)):
		return 1
	if str(hover.get("kind", "")) == AvatarViewModel.CURSOR_KIND_BAG \
			and int(hover.get("bagIndex", -1)) == bag_index:
		return 2
	return 0


static func _draw_header(
	canvas: CanvasItem, font: Font, view: Dictionary, left: float, top: float,
	info_right: float, width: float
) -> void:
	UiTheme.draw_text(canvas, font, Vector2(left, top + 30.0),
		str(view.get("displayName", "无名者")), UiTheme.COLOR_ACCENT, UiTheme.SIZE_TITLE)
	UiTheme.draw_text(canvas, font, Vector2(left + 8.0, top + 56.0),
		str(view.get("identityLine", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_SMALL)

	var location: String = str(view.get("location", ""))
	if not location.is_empty():
		UiTheme.draw_text(canvas, font, Vector2(left + 200.0, top + 56.0),
			location, UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	UiTheme.draw_text_right(canvas, font, Vector2(info_right, top + 30.0),
		str(view.get("moneyLabel", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
	var debt_label: String = str(view.get("debtLabel", ""))
	if debt_label != "0 铜":
		UiTheme.draw_text_right(canvas, font, Vector2(info_right, top + 56.0),
			"负债 " + debt_label, UiTheme.COLOR_DOWN, UiTheme.SIZE_SMALL)
	UiTheme.draw_text_right(canvas, font, Vector2(info_right - 260.0, top + 56.0),
		"幸运 %d    善恶 %d" % [int(view.get("luck", 0)), int(view.get("karma", 0))],
		UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
	UiTheme.draw_text_right(canvas, font, Vector2(info_right - 470.0, top + 56.0),
		"↑↓ 选（装备 / 背包）　回车 穿脱　R 就地修", UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)

	canvas.draw_line(Vector2(left, top + HEADER_HEIGHT - 8.0),
		Vector2(left + width, top + HEADER_HEIGHT - 8.0), UiTheme.COLOR_BORDER, 1.0)


## 顶部右侧的返回按钮。测试与命中测试都靠它拿位置。
static func buttons(rect: Rect2) -> Array:
	return UiTheme.button_row(
		UiTheme.draw_font(),
		rect.position.x + rect.size.x - MARGIN,
		rect.position.y + BACK_BUTTON_TOP,
		[{"id": "back", "label": "返回地图"}]
	)


static func _button_left(rect: Rect2) -> float:
	var buttons_list: Array = buttons(rect)
	if buttons_list.is_empty():
		return rect.position.x + rect.size.x - MARGIN
	return (buttons_list[0]["rect"] as Rect2).position.x


static func _draw_buttons(
	canvas: CanvasItem, font: Font, rect: Rect2, hover: Dictionary
) -> void:
	for button in buttons(rect):
		var hovered: bool = str(hover.get("kind", "")) == "button" \
			and str(hover.get("id", "")) == str(button["id"])
		UiTheme.draw_button(canvas, font, button["rect"], str(button["label"]), true, hovered)


## 返回的 kind：button / slot（index 是槽位行号，也是光标序号）/ bag（index 是光标
## 序号、bagIndex 是它在背包里的行号）。两段共用一个光标序号，调用方拿到 index
## 就能直接挪光标——不必知道槽位段有几行。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty() or not rect.has_point(point):
		return {}
	var button: Dictionary = UiTheme.hit_button(buttons(rect), point)
	if not button.is_empty():
		return {"kind": "button", "id": str(button["id"]), "enabled": true}

	var slots: Array = view.get("equipmentRows", [])
	var layout: Dictionary = left_layout(view, rect)
	for index in range(mini(int(layout["equipmentVisible"]), slots.size())):
		if slot_row_rect(rect, view, index).has_point(point):
			var row: Dictionary = slots[index]
			return {
				"kind": AvatarViewModel.CURSOR_KIND_SLOT,
				"index": index,
				"slot": str(row.get("slot", "")),
				"enabled": not bool(row.get("empty", false)) and not bool(row.get("blocked", false)),
			}

	var bag_index: int = bag_at(view, rect, point)
	if bag_index >= 0:
		var rows: Array = view.get("inventoryRows", [])
		return {
			"kind": AvatarViewModel.CURSOR_KIND_BAG,
			"index": slots.size() + bag_index,
			"bagIndex": bag_index,
			"instanceId": str(rows[bag_index].get("instanceId", "")),
			"enabled": bool(rows[bag_index].get("equippable", false)),
		}
	return {}


## 点在背包的哪一行（只在可视窗口里找）。面板外的调用方也要能用。
static func bag_at(view: Dictionary, rect: Rect2, point: Vector2) -> int:
	var rows: Array = view.get("inventoryRows", [])
	if rows.is_empty():
		return -1
	var top: float = rect.position.y + HEADER_HEIGHT
	var bottom: float = rect.position.y + rect.size.y - 10.0
	var layout: Dictionary = right_layout(view, top, bottom)
	var window: Dictionary = bag_window(view, int(layout["bagVisible"]))
	var last: int = mini(rows.size(), int(window["start"]) + int(window["visible"]))
	for index in range(int(window["start"]), last):
		if bag_row_rect(rect, view, index).has_point(point):
			return index
	return -1


## 段落抬头，返回第一行内容的纵坐标。空间不够时返回一个大于 bottom 的值，
## 调用方据此停止后续段落。
static func _section_title(
	canvas: CanvasItem, font: Font, y: float, x: float, width: float,
	title: String, bottom: float
) -> float:
	if y + SECTION_TITLE_HEIGHT + ROW_HEIGHT > bottom:
		return bottom + 1.0
	UiTheme.draw_section_title(canvas, font, Vector2(x, y + 14.0), title, width)
	return y + SECTION_TITLE_HEIGHT


static func _overflow(
	canvas: CanvasItem, font: Font, x: float, y: float, remaining: int
) -> void:
	if remaining <= 0:
		return
	UiTheme.draw_text(canvas, font, Vector2(x + 4.0, y + 14.0),
		"…… 另有 %d 项未显示" % remaining, UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)


# --- 左栏 ---

static func _draw_attribute_section(
	canvas: CanvasItem, font: Font, rows: Array, x: float, y: float,
	width: float, bottom: float
) -> float:
	y = _section_title(canvas, font, y, x, width, "属性", bottom)
	if y > bottom:
		return y
	for index in range(rows.size()):
		if y + ROW_HEIGHT > bottom:
			_overflow(canvas, font, x, y, rows.size() - index)
			return bottom + 1.0
		var row: Dictionary = rows[index]
		var row_y: float = y + 16.0
		UiTheme.draw_text(canvas, font, Vector2(x, row_y),
			str(row["label"]), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text(canvas, font, Vector2(x + 96.0, row_y),
			str(row["tierLabel"]), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		UiTheme.draw_bar(canvas,
			Rect2(Vector2(x + 152.0, y + 6.0), Vector2(260.0, 9.0)),
			float(row["bar"]))
		# 装备加的属性写在括号里（"12（10+2）"）：只写 12 的话，玩家看不出这
		# 一分是练出来的还是穿出来的，而"换一件装备属性会掉多少"正是要看的
		UiTheme.draw_text_right(canvas, font, Vector2(x + width - 6.0, row_y),
			str(row.get("valueLabel", str(int(row["value"])))), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
		y += ROW_HEIGHT
	return y + SECTION_GAP


## 天赋 / 缺陷段落。名称左边，右侧标注它是天赋还是缺陷。
static func _draw_entry_section(
	canvas: CanvasItem, font: Font, title: String, rows: Array, x: float, y: float,
	width: float, bottom: float
) -> float:
	if rows.is_empty():
		return y
	y = _section_title(canvas, font, y, x, width, title, bottom)
	if y > bottom:
		return y
	for index in range(rows.size()):
		if y + ROW_HEIGHT > bottom:
			_overflow(canvas, font, x, y, rows.size() - index)
			return bottom + 1.0
		var row: Dictionary = rows[index]
		var row_y: float = y + 16.0
		var is_flaw: bool = str(row.get("categoryLabel", "")) == "缺陷"
		UiTheme.draw_text(canvas, font, Vector2(x, row_y),
			str(row["label"]),
			UiTheme.COLOR_DOWN if is_flaw else UiTheme.COLOR_UP, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text_right(canvas, font, Vector2(x + width - 6.0, row_y),
			str(row.get("categoryLabel", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		y += ROW_HEIGHT
	return y + SECTION_GAP


static func _draw_reputation_section(
	canvas: CanvasItem, font: Font, rows: Array, x: float, y: float,
	width: float, bottom: float
) -> float:
	if rows.is_empty():
		return y
	y = _section_title(canvas, font, y, x, width, "声誉", bottom)
	if y > bottom:
		return y
	for index in range(rows.size()):
		if y + ROW_HEIGHT > bottom:
			_overflow(canvas, font, x, y, rows.size() - index)
			return bottom + 1.0
		var row: Dictionary = rows[index]
		var value: int = int(row["value"])
		var row_y: float = y + 16.0
		UiTheme.draw_text(canvas, font, Vector2(x, row_y),
			str(row["cityLabel"]), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text_right(canvas, font, Vector2(x + width - 6.0, row_y),
			str(row["label"]),
			UiTheme.COLOR_UP if value > 0 else UiTheme.COLOR_DOWN, UiTheme.SIZE_NORMAL)
		y += ROW_HEIGHT
	return y + SECTION_GAP


## 宿主遗留（M3.2）。只有随机转生才会有，因此空的时候整段不占版面。
static func _draw_legacy_section(
	canvas: CanvasItem, font: Font, rows: Array, x: float, y: float,
	width: float, bottom: float
) -> float:
	if rows.is_empty():
		return y
	y = _section_title(canvas, font, y, x, width, "前世遗留", bottom)
	if y > bottom:
		return y
	for index in range(rows.size()):
		if y + ROW_HEIGHT > bottom:
			_overflow(canvas, font, x, y, rows.size() - index)
			return bottom + 1.0
		var row: Dictionary = rows[index]
		var kind: String = str(row.get("kind", ""))
		var row_y: float = y + 16.0
		UiTheme.draw_text(canvas, font, Vector2(x, row_y),
			str(row["label"]), UiTheme.COLOR_WARN, UiTheme.SIZE_SMALL)
		UiTheme.draw_text(canvas, font, Vector2(x + 96.0, row_y),
			str(row["value"]),
			UiTheme.COLOR_DIM if kind == "pending" else UiTheme.COLOR_TEXT,
			UiTheme.SIZE_NORMAL)
		y += ROW_HEIGHT
	return y + SECTION_GAP


## 装备槽（本轮新增的"能动手"的一段）。空槽、被双手武器占着的槽、有货的槽
## 三种写法各不相同：同一个空槽，"你还没放东西"与"你现在放不了"是两件事。
static func _draw_equipment_section(
	canvas: CanvasItem, font: Font, view: Dictionary, x: float, y: float,
	width: float, bottom: float, hover: Dictionary
) -> float:
	var rows: Array = view.get("equipmentRows", [])
	if rows.is_empty():
		return y
	y = _section_title(canvas, font, y, x, width, "装备（↑↓ 选，回车脱下）", bottom)
	if y > bottom:
		return y
	for index in range(rows.size()):
		if y + ROW_HEIGHT > bottom:
			_overflow(canvas, font, x, y, rows.size() - index)
			return bottom + 1.0
		var row: Dictionary = rows[index]
		var row_rect := Rect2(Vector2(x, y), Vector2(width, ROW_HEIGHT))
		var mark: int = _slot_row_highlighted(view, index, hover)
		if mark == 1:
			canvas.draw_rect(row_rect, UiTheme.COLOR_SELECTED)
		elif mark == 2:
			canvas.draw_rect(row_rect, Color(UiTheme.COLOR_SELECTED.r, UiTheme.COLOR_SELECTED.g,
				UiTheme.COLOR_SELECTED.b, 0.45))
		var row_y: float = y + 16.0
		UiTheme.draw_text(canvas, font, Vector2(x, row_y),
			str(row.get("slotLabel", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		if bool(row.get("blocked", false)):
			UiTheme.draw_text(canvas, font, Vector2(x + 60.0, row_y),
				"（被%s占着）" % str(row.get("blockedBy", "双手武器")),
				UiTheme.COLOR_WARN, UiTheme.SIZE_NORMAL)
		elif bool(row.get("empty", false)):
			UiTheme.draw_text(canvas, font, Vector2(x + 60.0, row_y),
				"（空）", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		else:
			UiTheme.draw_text(canvas, font, Vector2(x + EQUIP_LABEL_X, row_y),
				str(row.get("label", "")), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
			UiTheme.draw_text(canvas, font, Vector2(x + EQUIP_RARITY_X, row_y),
				str(row.get("rarityLabel", "")), UiTheme.COLOR_ACCENT, UiTheme.SIZE_SMALL)
			UiTheme.draw_text(canvas, font, Vector2(x + EQUIP_DETAIL_X, row_y),
				_clip(str(row.get("detail", "")), EQUIP_DETAIL_CHARS),
				UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
			var affix: String = str(row.get("affixText", ""))
			if not affix.is_empty():
				UiTheme.draw_text(canvas, font, Vector2(x + EQUIP_AFFIX_X, row_y),
					_clip(affix, EQUIP_AFFIX_CHARS), UiTheme.COLOR_UP, UiTheme.SIZE_SMALL)
		y += ROW_HEIGHT
	return y + SECTION_GAP


# --- 右栏 ---

## 派生值。全部是算出来的，没有一项落盘——面板上标一句以免有人以为它们能被改。
static func _draw_derived_section(
	canvas: CanvasItem, font: Font, rows: Array, x: float, y: float,
	width: float, bottom: float, visible: int
) -> float:
	if rows.is_empty():
		return y
	y = _section_title(canvas, font, y, x, width, "派生值（由属性与装备实时算出）", bottom)
	if y > bottom:
		return y
	for index in range(mini(visible, rows.size())):
		var row: Dictionary = rows[index]
		var row_y: float = y + 16.0
		UiTheme.draw_text(canvas, font, Vector2(x, row_y),
			str(row["label"]), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text_right(canvas, font, Vector2(x + width - 6.0, row_y),
			str(row["valueLabel"]), UiTheme.COLOR_ACCENT, UiTheme.SIZE_NORMAL)
		y += ROW_HEIGHT
	if rows.size() > visible:
		_overflow(canvas, font, x, y, rows.size() - visible)
		return bottom + 1.0
	return y + SECTION_GAP


static func _draw_skill_section(
	canvas: CanvasItem, font: Font, rows: Array, x: float, y: float,
	width: float, bottom: float, visible: int
) -> float:
	if rows.is_empty():
		y = _section_title(canvas, font, y, x, width, "技能", bottom)
		if y > bottom:
			return y
		UiTheme.draw_text(canvas, font, Vector2(x, y + 16.0),
			"尚未习得任何技能。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return y + ROW_HEIGHT + SECTION_GAP

	y = _section_title(canvas, font, y, x, width, "技能", bottom)
	if y > bottom:
		return y
	for index in range(mini(visible, rows.size())):
		var row: Dictionary = rows[index]
		var row_y: float = y + 16.0
		UiTheme.draw_text(canvas, font, Vector2(x, row_y),
			str(row["label"]), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
		UiTheme.draw_bar(canvas,
			Rect2(Vector2(x + 190.0, y + 6.0), Vector2(200.0, 9.0)), float(row["bar"]))
		UiTheme.draw_text(canvas, font, Vector2(x + 398.0, row_y),
			str(row["tierLabel"]), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		UiTheme.draw_text_right(canvas, font, Vector2(x + width - 6.0, row_y),
			str(int(row["level"])), UiTheme.COLOR_ACCENT, UiTheme.SIZE_NORMAL)
		y += ROW_HEIGHT
	if rows.size() > visible:
		_overflow(canvas, font, x, y, rows.size() - visible)
		return bottom + 1.0
	return y + SECTION_GAP


## 背包。这一屏动手的第二段（回车穿上），因此带光标与滚动窗口：
## 背包能装 40 件，而画得下的不到十行。
##
## 抬头右边写着当前光标那一行会做什么（"回车穿上「普通长剑」（主手）"），
## 不然玩家得先按下去才知道会发生什么。
static func _draw_bag_section(
	canvas: CanvasItem, font: Font, view: Dictionary, x: float, y: float,
	width: float, bottom: float, visible: int, hover: Dictionary
) -> float:
	var rows: Array = view.get("inventoryRows", [])
	if y + SECTION_TITLE_HEIGHT + ROW_HEIGHT > bottom:
		return bottom + 1.0
	UiTheme.draw_section_title(canvas, font, Vector2(x, y + 14.0),
		"背包（%d 件）" % rows.size(), width)
	var selected: Dictionary = view.get("selected", {})
	var repair: Dictionary = selected.get("portableRepair", {})
	var action: String = str(view.get("actionLine", ""))
	if str(repair.get("actionLine", "")).is_empty() and action.is_empty():
		pass
	else:
		# 光标停在一件能就地修的装备上时，把"R 就地修"顶到最显眼的位置；
		# 否则照旧显示穿脱那行（词缀与耐久已由视图模型拼接进 actionLine）。
		var show: String = str(repair.get("actionLine", action))
		UiTheme.draw_text_right(canvas, font, Vector2(x + width - 6.0, y + 14.0),
			show, UiTheme.COLOR_ACCENT if bool(repair.get("canRepair", false))
				else (UiTheme.COLOR_ACCENT if bool(selected.get("canAct", false))
					else UiTheme.COLOR_DIM),
			UiTheme.SIZE_SMALL)
	y += SECTION_TITLE_HEIGHT

	if rows.is_empty():
		UiTheme.draw_text(canvas, font, Vector2(x, y + 16.0),
			"空无一物。", UiTheme.COLOR_DIM, UiTheme.SIZE_NORMAL)
		return y + ROW_HEIGHT

	var window: Dictionary = bag_window(view, visible)
	var last: int = mini(rows.size(), int(window["start"]) + visible)
	for index in range(int(window["start"]), last):
		var row: Dictionary = rows[index]
		var row_rect := Rect2(Vector2(x, y), Vector2(width, ROW_HEIGHT))
		var mark: int = _bag_row_highlighted(view, index, hover)
		if mark == 1:
			canvas.draw_rect(row_rect, UiTheme.COLOR_SELECTED)
		elif mark == 2:
			canvas.draw_rect(row_rect, Color(UiTheme.COLOR_SELECTED.r, UiTheme.COLOR_SELECTED.g,
				UiTheme.COLOR_SELECTED.b, 0.45))
		var row_y: float = y + 16.0
		UiTheme.draw_text(canvas, font, Vector2(x, row_y),
			str(row["label"]), UiTheme.COLOR_TEXT, UiTheme.SIZE_NORMAL)
		UiTheme.draw_text(canvas, font, Vector2(x + BAG_RARITY_X, row_y),
			str(row["rarityLabel"]), UiTheme.COLOR_ACCENT, UiTheme.SIZE_SMALL)
		UiTheme.draw_text(canvas, font, Vector2(x + BAG_DETAIL_X, row_y),
			_clip(str(row["detail"]), BAG_DETAIL_CHARS), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		var affix: String = str(row.get("affixText", ""))
		if not affix.is_empty():
			UiTheme.draw_text(canvas, font, Vector2(x + BAG_AFFIX_X, row_y),
				_clip(affix, BAG_AFFIX_CHARS), UiTheme.COLOR_UP, UiTheme.SIZE_SMALL)
		elif not bool(row.get("equippable", false)):
			UiTheme.draw_text(canvas, font, Vector2(x + BAG_AFFIX_X, row_y),
				"不可穿", UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		else:
			# 没有词缀的货（普通档）把这一格让给"穿到哪里"——词缀与槽位
			# 都是"这件货是什么"，但同一行的宽度只够写一样
			UiTheme.draw_text(canvas, font, Vector2(x + BAG_AFFIX_X, row_y),
				"可穿 · " + str(row.get("slotLabel", "")), UiTheme.COLOR_DIM, UiTheme.SIZE_SMALL)
		y += ROW_HEIGHT
	if rows.size() > visible:
		_overflow(canvas, font, x, y, rows.size() - visible)
	return y


## 行内文字的截断。一行里排着好几项，每一项都得自己收住长度。
static func _clip(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.substr(0, maxi(1, max_chars - 1)) + "…"
