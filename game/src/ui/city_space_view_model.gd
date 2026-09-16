class_name CitySpaceViewModel
extends RefCounted

## 城内空间的视图模型（M19 表现层）。与其它视图模型同一个理由："面板该画什么"是
## 纯函数，能在无头环境里被验收测试钉住；"怎么画"留给面板。
##
## 它把规则层 `CitySpace.layout` 出来的网格结构 + 玩家当前位置，摊成绘制清单——
## 建筑/NPC/城门/玩家的像素矩形与落点、相邻可交互提示。坐标一律由本类用
## CITY_TILE 换算，面板与命中测试共用同一份几何，避免两边各算一遍而脱节。

## 城内每格边长。世界地图用 TILE=5（120×120=600px），城内想看清建筑落位就得放大，
## 24×16 = 384px、18×16 = 288px，正好嵌进 PANEL_RECT（1248×568）居中。
const CITY_TILE: float = 16.0


## 面板区域里，城内网格的左上角像素。居中网格：把 (grid宽×tile, grid高×tile)
## 对齐到 rect 中心。
static func origin_of(rect: Rect2) -> Vector2:
	var grid_px: Vector2 = Vector2(CITY_TILE * CitySpace.WIDTH, CITY_TILE * CitySpace.HEIGHT)
	return rect.position + (rect.size - grid_px) * 0.5


## 把某个城内格 = 像素矩（供命中测试与绘制共用）。
static func cell_rect(origin: Vector2, gx: int, gy: int) -> Rect2:
	return Rect2(origin + Vector2(gx * CITY_TILE, gy * CITY_TILE), Vector2(CITY_TILE, CITY_TILE))


## 从表单（城内网格结构，CitySpace.layout 的产出）、玩家格坐标、两张 ID→名称表，
## 摊成绘制清单。building_labels / npc_labels 由调用方（主场景）按当前内容补好。
static func build(
	layout: Dictionary,
	player: Vector2i,
	building_labels: Dictionary,
	npc_labels: Dictionary,
	rect: Rect2
) -> Dictionary:
	var origin: Vector2 = origin_of(rect)

	var buildings: Array = []
	for slot in layout.get("buildings", []):
		var br: Rect2 = Rect2(
			origin + Vector2(slot.x * CITY_TILE, slot.y * CITY_TILE),
			Vector2(slot.w * CITY_TILE, slot.h * CITY_TILE)
		)
		buildings.append({
			"id": str(slot["id"]),
			"kind": str(slot["kind"]),
			"label": str(building_labels.get(str(slot["id"]), str(slot["id"]))),
			"rect": br,
		})

	var npcs: Array = []
	for slot in layout.get("npcs", []):
		var gc: Vector2 = Vector2(slot.x * CITY_TILE + CITY_TILE * 0.5,
			slot.y * CITY_TILE + CITY_TILE * 0.5)
		npcs.append({
			"id": str(slot["id"]),
			"label": str(npc_labels.get(str(slot["id"]), str(slot["id"]))),
			"center": origin + gc,
		})

	# 相邻可交互项：站在建筑/NPC 旁时，面板把这笔交互标出来
	var near: Dictionary = {
		"building": CitySpace.near_building(layout, player),
		"npcId": CitySpace.near_npc(layout, player),
		"atGate": (player.x == layout["gate"].x and player.y == layout["gate"].y),
	}

	return {
		"layout": layout,
		"origin": origin,
		"player": player,
		"playerRect": cell_rect(origin, player.x, player.y),
		"buildings": buildings,
		"npcs": npcs,
		"gate": {
			"rect": cell_rect(origin, layout["gate"].x, layout["gate"].y),
			"center": origin + Vector2(layout["gate"].x * CITY_TILE + CITY_TILE * 0.5,
				layout["gate"].y * CITY_TILE + CITY_TILE * 0.5),
		},
		"near": near,
	}