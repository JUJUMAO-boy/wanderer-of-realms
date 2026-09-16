class_name CitySpacePanel
extends RefCounted

## 城内空间的绘制（M19）。全部是静态函数，不继承 Node：主场景在 _draw 里调
## CitySpacePanel.draw(self, view, PANEL_RECT, hover) 就行。
##
## 画的是 CitySpaceViewModel 产出的结构，本类不做任何数值加工——"画什么"由视图
## 模型算好（含几何），这里只负责"怎么画"。命中测试与绘制共用视图模型提供的
## origin / cell_rect，点哪格就是哪格。

const COLOR_BG: Color = Color(0.10, 0.11, 0.14)
const COLOR_GRID: Color = Color(0.16, 0.18, 0.22)
const COLOR_PLAYER: Color = Color(0.35, 0.85, 0.95)
const COLOR_GATE: Color = Color(0.85, 0.62, 0.30)
const COLOR_NPC: Color = Color(0.55, 0.70, 0.92)
const COLOR_LABEL: Color = Color(0.92, 0.94, 0.97)
const COLOR_NEAR: Color = Color(0.98, 0.92, 0.55)

## 每类建筑一个主色，一眼能分出"这是城里的哪类功能"。投资/地标用偏金的颜色。
const KIND_COLOR: Dictionary = {
	CitySpace.KIND_SHOP: Color(0.82, 0.60, 0.35),
	CitySpace.KIND_EVENT: Color(0.70, 0.45, 0.72),
	CitySpace.KIND_QUEST: Color(0.38, 0.62, 0.80),
	CitySpace.KIND_RESIDENTS: Color(0.45, 0.72, 0.52),
	CitySpace.KIND_SMUGGLING: Color(0.80, 0.44, 0.62),
	CitySpace.KIND_INVEST: Color(0.85, 0.72, 0.35),
}

const SIZE_LABEL: int = 10


static func _kind_color(font: Font, view: Dictionary, index: int) -> Color:
	var buildings: Array = view.get("buildings", [])
	if index < 0 or index >= buildings.size():
		return KIND_COLOR[CitySpace.KIND_INVEST]
	return KIND_COLOR.get(str(buildings[index].get("kind", "")), KIND_COLOR[CitySpace.KIND_INVEST])


static func draw(canvas: CanvasItem, view: Dictionary, rect: Rect2, hover: Dictionary = {}) -> void:
	var font: Font = UiTheme.draw_font()
	if font == null:
		return
	var origin: Vector2 = view.get("origin", Vector2())
	var grid_px: Vector2 = Vector2(CitySpaceViewModel.CITY_TILE * CitySpace.WIDTH,
		CitySpaceViewModel.CITY_TILE * CitySpace.HEIGHT)
	var grid_rect := Rect2(origin, grid_px)

	# 街道底 + 网格
	canvas.draw_rect(grid_rect, COLOR_BG)
	for x in range(CitySpace.WIDTH + 1):
		var px: float = origin.x + x * CitySpaceViewModel.CITY_TILE
		canvas.draw_line(Vector2(px, origin.y), Vector2(px, origin.y + grid_px.y), COLOR_GRID, 1.0)
	for y in range(CitySpace.HEIGHT + 1):
		var py: float = origin.y + y * CitySpaceViewModel.CITY_TILE
		canvas.draw_line(Vector2(origin.x, py), Vector2(origin.x + grid_px.x, py), COLOR_GRID, 1.0)

	# 城门
	var gate: Dictionary = view.get("gate", {})
	if not gate.is_empty():
		canvas.draw_rect(gate.get("rect", Rect2()), COLOR_GATE)
		_text_center(canvas, font, Vector2(gate["center"].x, gate["center"].y + 4.0),
			"城门", Color(0.15, 0.10, 0.04), SIZE_LABEL)

	# 建筑（每个都是色块 + 名称）
	var buildings: Array = view.get("buildings", [])
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		var hovered: bool = str(hover.get("kind", "")) == "building" \
			and int(hover.get("index", -1)) == i
		var color: Color = _kind_color(font, view, i)
		canvas.draw_rect(b["rect"], color, false, 2.0 if hovered else 1.0)
		_text_center(canvas, font, rect_center(b["rect"]), str(b["label"]), COLOR_LABEL, SIZE_LABEL)

	# NPC
	var npcs: Array = view.get("npcs", [])
	for i in range(npcs.size()):
		var npc: Dictionary = npcs[i]
		var c: Vector2 = npc["center"]
		canvas.draw_circle(c, 3.0, COLOR_NPC)
		_text(canvas, font, c + Vector2(4.0, 3.0), str(npc["label"]), COLOR_NPC, SIZE_LABEL)

	# 玩家
	var player: Rect2 = view.get("playerRect", Rect2())
	canvas.draw_rect(player, COLOR_PLAYER)

	# 相邻交互高亮：站在建筑旁给那栋描金边、NPC 放大、到城门时提示出去
	var near: Dictionary = view.get("near", {})
	if not near.get("building", {}).is_empty():
		var bid: String = str(near["building"]["building_id"])
		for b in buildings:
			if str(b["id"]) == bid:
				canvas.draw_rect(b["rect"], COLOR_NEAR, false, 3.0)
				break


static func rect_center(r: Rect2) -> Vector2:
	return r.position + r.size * 0.5


## 命中测试：返回 { kind: building/npc/gate/cell, index/grid }。点偏差返回 {}。
static func hit_test(view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	if view.is_empty():
		return {}
	var origin: Vector2 = view.get("origin", Vector2())
	var local: Vector2 = (point - origin) / CitySpaceViewModel.CITY_TILE
	if local.x < 0.0 or local.y < 0.0:
		return {}
	var gx: int = int(local.x)
	var gy: int = int(local.y)
	if gx >= CitySpace.WIDTH or gy >= CitySpace.HEIGHT:
		return {}

	var gate: Dictionary = view.get("gate", {})
	if not gate.is_empty() and gate.get("rect", Rect2()).has_point(point):
		return {"kind": "gate", "grid": Vector2i(gx, gy)}

	var buildings: Array = view.get("buildings", [])
	for i in range(buildings.size()):
		if buildings[i]["rect"].has_point(point):
			return {"kind": "building", "index": i, "grid": Vector2i(gx, gy)}

	return {"kind": "cell", "grid": Vector2i(gx, gy)}


static func _text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, color: Color, size: int) -> void:
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func _text_center(canvas: CanvasItem, font: Font, center: Vector2, text: String, color: Color, size: int) -> void:
	var f_size: int = size
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size).x
	canvas.draw_string(font, center - Vector2(w * 0.5, f_size * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, color)