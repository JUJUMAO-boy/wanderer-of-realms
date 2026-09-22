class_name DungeonViewModel
extends RefCounted

## 副本空间的视图模型（M21 表现层）。与其它视图模型同一个理由："面板该画什么"是
## 纯函数，能在无头环境里被验收测试钉住；"怎么画"留给面板。
##
## 把规则层 `Dungeon.layout` 出来的楼层结构 + 玩家当前位置，摊成绘制清单——
## 墙/宝箱/敌人/出口/玩家的像素矩形与落点、层数与下探提示。坐标一律由本类用
## DUNGEON_TILE 换算，面板与命中测试共用同一份几何，避免两边各算一遍而脱节。
## 与 CitySpaceViewModel 同构，只是对象换成了副本自己的"墙/宝箱/敌人"。

## 副本每格边长。与世界地图 TILE=5 无关，放大到看得清地形；
## 24×16=384px、18×16=288px，居中嵌进 PANEL_RECT。
const DUNGEON_TILE: float = 16.0


## 面板区域里，副本网格的左上角像素。居中网格：把 (宽×tile, 高×tile) 对齐到 rect 中心。
static func origin_of(rect: Rect2) -> Vector2:
	return rect.position + (rect.size - Vector2(
		DUNGEON_TILE * Dungeon.WIDTH, DUNGEON_TILE * Dungeon.HEIGHT)) * 0.5


## 把某个格子转成像素矩（供命中测试与绘制共用）。
static func cell_rect(origin: Vector2, gx: int, gy: int) -> Rect2:
	return Rect2(origin + Vector2(gx * DUNGEON_TILE, gy * DUNGEON_TILE),
		Vector2(DUNGEON_TILE, DUNGEON_TILE))


## 从楼层结构（Dungeon.layout 的产出）+ 玩家格坐标，摊成绘制清单。
## origin 由传入的面板 rect 居中得出；labels 可带 { depthHint }，缺省给兜底文字。
static func build(layout: Dictionary, player: Vector2i, rect: Rect2, labels: Dictionary = {}) -> Dictionary:
	var origin: Vector2 = origin_of(rect)

	var walls: Array = []
	for key in layout.get("blocked", {}).keys():
		var parts: PackedStringArray = String(key).split(",")
		var gx: int = int(parts[0]) if parts.size() >= 1 else 0
		var gy: int = int(parts[1]) if parts.size() >= 2 else 0
		walls.append(cell_rect(origin, gx, gy))

	var treasures: Array = []
	for t in layout.get("treasures", []):
		treasures.append({
			"index": treasures.size(),
			"rect": cell_rect(origin, int(t["x"]), int(t["y"])),
		})

	var enemies: Array = []
	for e in layout.get("enemies", []):
		enemies.append({
			"index": enemies.size(),
			"rect": cell_rect(origin, int(e["x"]), int(e["y"])),
		})

	var theme: Dictionary = layout.get("theme", {})
	return {
		"layout": layout,
		"origin": origin,
		"player": player,
		"playerRect": cell_rect(origin, player.x, player.y),
		"walls": walls,
		"treasures": treasures,
		"enemies": enemies,
		"exit": {
			"rect": cell_rect(origin, layout["exit"].x, layout["exit"].y),
			"center": origin + Vector2(layout["exit"].x * DUNGEON_TILE + DUNGEON_TILE * 0.5,
				layout["exit"].y * DUNGEON_TILE + DUNGEON_TILE * 0.5),
		},
		"depth": int(layout.get("depth", 0)),
		"depthLabel": "第 %d 层" % (int(layout.get("depth", 0)) + 1),
		"depthHint": str(labels.get("depthHint", "越深越凶，石头下藏着更怪的东西")),
		"theme": theme,
		"themeLabel": str(theme.get("label", "")),
		"themeHasSupply": bool(theme.get("hasSupply", false)),
	}