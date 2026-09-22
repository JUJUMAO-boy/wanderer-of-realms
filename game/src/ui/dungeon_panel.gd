class_name DungeonPanel
extends RefCounted

## 副本空间的绘制（M21）。全部是静态函数，不继承 Node：主场景在 _draw 里调
## DungeonPanel.draw(self, view, _content_rect()) 就行。
##
## 画的是 DungeonViewModel 产出的结构，本类不做任何数值加工——"画什么"由视图模型
## 算好（含几何），这里只负责"怎么画"。命中测试与绘制共用视图模型提供的 origin /
## cell_rect，点哪格就是哪格。
##
## 这是 M21 在美术上"打底子"的第一处落点：副本用一套低饱和、冷石色的像素地板/墙体
## 调色板，物什用高饱和点缀（金=宝箱、绯红=敌、青=出口与玩家），一眼分别是"这层
## 哪里能走、哪里危险"。后面填充美术资源时，这套调色板保持不变，只替换色块为贴图。

## 副本像素调色板（M21 美术底子）：地板/墙走冷石色阶，物什走高饱和三点。
const COLOR_BG: Color = Color(0.075, 0.08, 0.10)
const COLOR_FLOOR: Color = Color(0.14, 0.15, 0.18)
const COLOR_WALL: Color = Color(0.22, 0.23, 0.28)
const COLOR_WALL_EDGE: Color = Color(0.30, 0.32, 0.38)
const COLOR_EXIT: Color = Color(0.35, 0.85, 0.90)
const COLOR_TREASURE: Color = Color(0.92, 0.76, 0.32)
const COLOR_ENEMY: Color = Color(0.82, 0.34, 0.32)
const COLOR_PLAYER: Color = Color(0.40, 0.88, 0.55)
const COLOR_TEXT: Color = Color(0.92, 0.94, 0.97)
const COLOR_DIM: Color = Color(0.55, 0.58, 0.62)

const SIZE_LABEL: int = 10
const SIZE_LEGEND: int = 12

## 命中档位。
const HIT_EXIT: String = "exit"
const HIT_TREASURE: String = "treasure"
const HIT_ENEMY: String = "enemy"
const HIT_CELL: String = "cell"


static func draw(canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null:
		return
	# 统一外壳 + 标题带（M20 阶段二）：副本也吃全场景那套面板观感。
	UiTheme.draw_panel(canvas, rect)
	_ui_header(canvas, font, rect, view)
	var origin: Vector2 = view.get("origin", Vector2())
	var grid_rect := Rect2(origin, Vector2(
		DungeonViewModel.DUNGEON_TILE * Dungeon.WIDTH,
		DungeonViewModel.DUNGEON_TILE * Dungeon.HEIGHT))

	# 地板：整块冷石底 + 每格一圈较浅格子，给"可步行地表"以像素层次。
	canvas.draw_rect(grid_rect, COLOR_BG)
	for gy in range(Dungeon.HEIGHT):
		for gx in range(Dungeon.WIDTH):
			var cell: Rect2 = DungeonViewModel.cell_rect(origin, gx, gy)
			canvas.draw_rect(
				Rect2(cell.position + Vector2(1, 1), cell.size - Vector2(2, 2)), COLOR_FLOOR)
	# 墙体：每个不可走格画一块带顶沿高光的石。
	for wall in view.get("walls", []):
		canvas.draw_rect(wall, COLOR_WALL)
		canvas.draw_line(wall.position, wall.position + Vector2(wall.size.x, 0.0),
			COLOR_WALL_EDGE, 2.0)
	# 出口：青芒标记 + 文字。
	var exit: Dictionary = view.get("exit", {})
	if not exit.is_empty():
		canvas.draw_rect(exit.get("rect", Rect2()), COLOR_EXIT)
		_text_center(canvas, font, Vector2(exit["center"].x, exit["center"].y + 4.0),
			"出口", Color(0.04, 0.08, 0.10), SIZE_LABEL)
	# 宝箱（金）与敌人（绯红）。
	var treasures: Array = view.get("treasures", [])
	var enemies: Array = view.get("enemies", [])
	for i in range(treasures.size()):
		var hit: bool = str(hover.get("kind", "")) == HIT_TREASURE \
			and int(hover.get("index", -1)) == i
		_draw_obj(canvas, treasures[i]["rect"], COLOR_TREASURE, "宝箱", hit)
	for i in range(enemies.size()):
		var hit: bool = str(hover.get("kind", "")) == HIT_ENEMY \
			and int(hover.get("index", -1)) == i
		_draw_obj(canvas, enemies[i]["rect"], COLOR_ENEMY, "敌", hit)
	# 玩家。
	canvas.draw_rect(view.get("playerRect", Rect2()), COLOR_PLAYER)
	# 底部图例：告诉玩家这层怎么走、怎么出。
	_ui_legend(canvas, font, rect, view)


## 标题带：标题 + 层数副题 + 右上操作提示（方向键走 / ESC 离开 / 出口下探）。
static func _subtitle(view: Dictionary) -> String:
	var base: String = "%s · %s" % [str(view.get("depthLabel", "")),
		str(view.get("depthHint", ""))]
	var theme_label: String = str(view.get("themeLabel", ""))
	if theme_label.is_empty():
		return base
	return "%s · %s" % [base, theme_label]


static func _ui_header(canvas: CanvasItem, font: Font, rect: Rect2, view: Dictionary) -> void:
	UiTheme.draw_panel_header(canvas, font, rect, {
		"left": 24.0,
		"title": 30.0,
		"titleColor": UiTheme.COLOR_ACCENT,
		"subtitleY": 56.0,
		"subtitle": _subtitle(view),
		"subtitleColor": UiTheme.COLOR_DIM,
		"hintY": 30.0,
		"hintRightX": rect.end.x - 24.0,
		"hint": "方向键走 · 回车互动 · ESC 离开 · 出口可下探",
		"hintColor": UiTheme.COLOR_DIM,
		"lineY": 78.0,
		"lineWidth": rect.size.x - 48.0,
	})


## 底部图例：三枚方块 + 一句"这层的样子"。
static func _ui_legend(canvas: CanvasItem, font: Font, rect: Rect2, view: Dictionary) -> void:
	var ay: float = rect.end.y - 34.0
	_legend_item(canvas, font, rect.position.x + 24.0, ay, COLOR_TREASURE, "宝箱")
	_legend_item(canvas, font, rect.position.x + 120.0, ay, COLOR_ENEMY, "敌人")
	_legend_item(canvas, font, rect.position.x + 216.0, ay, COLOR_EXIT, "出口（可下探 / 离开）")
	var right := Vector2(rect.end.x - 24.0, ay + 10.0)
	_text(canvas, font, right, "第 %d / %d 层" % [int(view.get("depth", 0)) + 1, Dungeon.MAX_DEPTH],
		COLOR_DIM, SIZE_LEGEND, true)


static func _legend_item(
	canvas: CanvasItem, font: Font, x: float, y: float, color: Color, label: String
) -> void:
	canvas.draw_rect(Rect2(x, y, 10.0, 10.0), color)
	_text(canvas, font, Vector2(x + 16.0, y + 10.0), label, COLOR_TEXT, SIZE_LEGEND, false)


## 一枚可互动物什：色块 + 描边（悬停加粗）。
static func _draw_obj(canvas: CanvasItem, rect: Rect2, color: Color, _label: String, hovered: bool) -> void:
	canvas.draw_rect(rect, color, false, 3.0 if hovered else 1.0)
	var inset := Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8))
	canvas.draw_rect(inset, Color(color.r, color.g, color.b, 0.7))


## 命中测试：返回 { kind: exit/treasure/enemy/cell, index, grid }。点超出网格返回 {}。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty():
		return {}
	var origin: Vector2 = view.get("origin", Vector2())
	var local: Vector2 = (point - origin) / DungeonViewModel.DUNGEON_TILE
	if local.x < 0.0 or local.y < 0.0:
		return {}
	var gx: int = int(local.x)
	var gy: int = int(local.y)
	if gx >= Dungeon.WIDTH or gy >= Dungeon.HEIGHT:
		return {}

	var exit: Dictionary = view.get("exit", {})
	if not exit.is_empty() and exit.get("rect", Rect2()).has_point(point):
		return {"kind": HIT_EXIT, "index": -1, "grid": Vector2i(gx, gy)}
	var treasures: Array = view.get("treasures", [])
	for i in range(treasures.size()):
		if treasures[i]["rect"].has_point(point):
			return {"kind": HIT_TREASURE, "index": i, "grid": Vector2i(gx, gy)}
	var enemies: Array = view.get("enemies", [])
	for i in range(enemies.size()):
		if enemies[i]["rect"].has_point(point):
			return {"kind": HIT_ENEMY, "index": i, "grid": Vector2i(gx, gy)}
	return {"kind": HIT_CELL, "index": -1, "grid": Vector2i(gx, gy)}


static func _text(
	canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color,
	size: int, right: bool = false
) -> void:
	if right:
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos.x -= width
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func _text_center(
	canvas: CanvasItem, font: Font, center: Vector2, text: String, color: Color, size: int
) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, center - Vector2(width * 0.5, size * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)