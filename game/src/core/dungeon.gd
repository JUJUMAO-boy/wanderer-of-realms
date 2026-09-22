class_name Dungeon
extends RefCounted

## 临时副本空间（M21）。把"野外路上偶尔撞见的一个洞穴/遗迹入口"变成可以走进去
## 探索的独立网格空间：玩家在一个确定性生成的副本楼层里走格，能遇敌、能捡宝、
## 能下到更深一层，走到出口随时离开，回到世界地图。
##
## 与 CitySpace（M19）同一套思路与口径：
##   1. **确定性、可复现、不落盘**。给定 `种子键 + 层数` 派生同一张楼层结构，
##      测试能断言，也不用写进存档（"能派生就不落盘"）。它是一次性的奇遇，读档回来
##      那一层早就没了——这与遭遇/战斗是同一种处境（会话态，留在主场景里）。
##   2. **不碰 WorldState / ContentLoader**。楼层只回答"哪个格是墙、哪格有宝箱、
##      哪格是敌人、出口在哪"，不决定这层里掉什么、遇上谁——货与敌由调用方喂进来 /
##      现抽，本类保持纯几何。
##
## 生成安全性的关键约束：**任何格子都必须是可达的**。实现上只铺两类障碍——外圈墙
## 与散布的单格岩屑；单格岩屑不临外圈墙（取值只落在 2..W-3 / 2..H-3），永远封不死
## 任何一个开放格的四邻，同时正中一列（spawn↔exit）始终开路，于是 spawn 到 exit 必然可走，
## 每一个宝箱/敌人都踩得到。

const WIDTH: int = 24
const HEIGHT: int = 18

## 出口：上边界正中。
const EXIT: Vector2i = Vector2i(WIDTH / 2, 1)
## 出生点：下边界正中，出口正对（同一列，保证首尾连通）。
const SPAWN: Vector2i = Vector2i(WIDTH / 2, HEIGHT - 2)

## 默认的层深浅档：每层的宝箱与敌人数量都落在这个区间里，随层数加深而变多。
const TREASURE_MIN: int = 2
const TREASURE_MAX: int = 4
const ENEMY_MIN: int = 2
const ENEMY_MAX: int = 4

## 最大可下探的层数（技术实现上的钳制；设计上"越深越凶"由调用方据此加深敌群）。
const MAX_DEPTH: int = 20


## 生成一层副本结构。输入：
##   seed_key  派生随机用的种子键（通常是"世界种子 ^ 奇遇序号"的字符串）
##   depth     层数（0 起）。决定宝箱/敌人数量，也作为随机派生的一部分
##   opts      可选配置 { fieldMin, fieldMax, treasureMin, treasureMax,
##                       enemyMin, enemyMax, rng }；缺省吃上面的常量。
## 返回：
##   { w, h, spawn, exit, depth,
##     blocked: {"x,y": true, ...},      墙（外圈 + 岩屑）
##     treasures: [ {x, y}, ... ],       宝箱格
##     enemies:   [ {x, y}, ... ] }      敌人格
static func layout(seed_key: String, depth: int, opts: Dictionary = {}) -> Dictionary:
	var d: int = maxi(0, depth)
	var source: DeterministicRNG = opts.get("rng", null) \
		if opts.get("rng", null) != null \
		else DeterministicRNG.new((str(seed_key).hash() ^ (d * 2654435761)) & 0xFFFFFFFF)
	var treasure_min: int = maxi(0, int(opts.get("treasureMin", TREASURE_MIN)))
	var treasure_max: int = maxi(treasure_min, int(opts.get("treasureMax", TREASURE_MAX)))
	var enemy_min: int = maxi(0, int(opts.get("enemyMin", ENEMY_MIN)))
	var enemy_max: int = maxi(enemy_min, int(opts.get("enemyMax", ENEMY_MAX)))

	var out: Dictionary = {
		"w": WIDTH, "h": HEIGHT,
		"spawn": SPAWN, "exit": EXIT, "depth": d,
		"blocked": {}, "treasures": [], "enemies": [],
	}
	# 外圈墙：整幅地图四周一圈。
	for x in range(WIDTH):
		out["blocked"]["%d,%d" % [x, 0]] = true
		out["blocked"]["%d,%d" % [x, HEIGHT - 1]] = true
	for y in range(HEIGHT):
		out["blocked"]["%d,%d" % [0, y]] = true
		out["blocked"]["%d,%d" % [WIDTH - 1, y]] = true

	# 单格岩屑（不临外圈墙）：让楼面有"碎石/残柱"的层次，而不只是空地板。
	var rubble: int = maxi(0, 1 + d / 3)
	for i in range(rubble):
		_place_rubble(out["blocked"], source)

	# 宝箱与敌人：只落在可站的空地上，绝不落在墙/出口/出生点上。
	var treasure_count: int = source.range_int(treasure_min, treasure_max)
	for i in range(treasure_count):
		var cell: Vector2i = _free_open_cell(out["blocked"], source)
		out["treasures"].append({"x": cell.x, "y": cell.y})

	var enemy_count: int = source.range_int(enemy_min, enemy_max)
	for i in range(enemy_count):
		var cell: Vector2i = _free_open_cell(out["blocked"], source, out)
		out["enemies"].append({"x": cell.x, "y": cell.y})
	return out


## 放在哪一格能不能站：出界不可、墙不可。
static func walkable(cells: Dictionary, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return false
	return not bool(cells.get("blocked", {}).get("%d,%d" % [x, y], false))


## 走一步。返回 { ok, next, atExit }。撞墙/出界返回 { ok:false, next:from }。
static func step(cells: Dictionary, from: Vector2i, dx: int, dy: int) -> Dictionary:
	var nx: int = from.x + dx
	var ny: int = from.y + dy
	if not walkable(cells, nx, ny):
		return {"ok": false, "next": from, "atExit": false}
	return {"ok": true, "next": Vector2i(nx, ny), "atExit": (nx == EXIT.x and ny == EXIT.y)}


## 这一格上有没有宝箱。返回索引或 -1。
static func treasure_index(cells: Dictionary, pos: Vector2i) -> int:
	var treasures: Array = cells.get("treasures", [])
	for i in range(treasures.size()):
		var t: Dictionary = treasures[i]
		if int(t["x"]) == pos.x and int(t["y"]) == pos.y:
			return i
	return -1


## 这一格上有没有敌人。返回索引或 -1。
static func enemy_index(cells: Dictionary, pos: Vector2i) -> int:
	var enemies: Array = cells.get("enemies", [])
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		if int(e["x"]) == pos.x and int(e["y"]) == pos.y:
			return i
	return -1


## 铺一块单格岩屑：取值落在 2..W-3 / 2..H-3，永远不临外圈墙，也不会封死任何格子。
static func _place_rubble(blocked: Dictionary, source: DeterministicRNG) -> void:
	var x: int = source.range_int(2, WIDTH - 3)
	var y: int = source.range_int(2, HEIGHT - 3)
	blocked["%d,%d" % [x, y]] = true


## 抽一个可站、且不与已有宝箱/敌人重叠的空格。优先避开空地边缘，让物什往中间落。
static func _free_open_cell(
	blocked: Dictionary, source: DeterministicRNG, exclude: Dictionary = {}
) -> Vector2i:
	var xs: Array = []
	for x in range(2, WIDTH - 1):
		if x == EXIT.x and x == SPAWN.x:
			continue
		xs.append(x)
	var ys: Array = []
	for y in range(2, HEIGHT - 1):
		if y == EXIT.y or y == SPAWN.y:
			continue
		ys.append(y)
	for _attempt in range(64):
		var x: int = int(xs[source.next_int(xs.size())])
		var y: int = int(ys[source.next_int(ys.size())])
		var key: String = "%d,%d" % [x, y]
		if blocked.has(key):
			continue
		if _occupied(exclude, x, y):
			continue
		return Vector2i(x, y)
	return Vector2i(SPAWN.x + 1, SPAWN.y)


static func _occupied(cells: Dictionary, x: int, y: int) -> bool:
	if cells.is_empty() or not cells.has("treasures"):
		return false
	for t in cells.get("treasures", []):
		if int(t["x"]) == x and int(t["y"]) == y:
			return true
	for e in cells.get("enemies", []):
		if int(e["x"]) == x and int(e["y"]) == y:
			return true
	return false