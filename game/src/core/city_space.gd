class_name CitySpace
extends RefCounted

## 城内俯视空间（M19）。把城市从"地图上的一个点、点了开面板"升级成可自由走动的
## 局部网格：进来后玩家在一个固定尺寸的城内网格里走，能看到功能建筑的落位与城里
## 的 NPC，走到建筑旁/走近 NPC 就能互动（复用它把既有功能视图打开）；走到城门处
## 返回世界地图。
##
## 布局是**确定性、可复现、不落盘**的：给定 cityId 派生出同一张城内网格，测试能断言，
## 也不用写进存档（与 `CityBuildings.available_level`"能派生就不落盘"同一口径）。
## 布局只由「哪 5 座建筑、几个 NPC」这个输入决定，本类不碰 WorldState/ContentLoader，
## 全靠调用方把数据喂进来——这样它在无头环境里可以被验收测试直接钉住。

const WIDTH: int = 24
const HEIGHT: int = 18

## 建筑占地 3×2 格。固定排两行（上行 3 座、下行 2 座），位置是死写死的格子，
## 只把"哪座建筑放哪个槽"按城市哈希做一次轮转，因此哪怕同城重复生成也完全一致、
## 不同城排布不同，且槽位天然不重叠、不出界——不用赌随机不会撞。
const FOOTPRINT_W: int = 3
const FOOTPRINT_H: int = 2
## 五个槽位（左上角所在格）。
const SLOTS: Array = [
	Vector2i(2, 2),  Vector2i(9, 2),  Vector2i(16, 2),
	Vector2i(5, 11), Vector2i(14, 11),
]

## 城门：下边界正中。
const GATE: Vector2i = Vector2i(WIDTH / 2, HEIGHT - 1)
## 出生点：城门前一格。
const SPAWN: Vector2i = Vector2i(GATE.x, GATE.y - 1)

## 每座建筑对外承接的功能。与主场景的各个功能视图一一对应——
## shop→商铺、event→城中大事、quest→委托板、residents→居民与人物、
## smuggling→走私航线、invest→城市投资（M12 的投资就在城市总览里）。
const KIND_SHOP: String = "shop"
const KIND_EVENT: String = "event"
const KIND_QUEST: String = "quest"
const KIND_RESIDENTS: String = "residents"
const KIND_SMUGGLING: String = "smuggling"
const KIND_INVEST: String = "invest"
const KINDS: Array = [
	KIND_SHOP, KIND_EVENT, KIND_QUEST, KIND_RESIDENTS, KIND_SMUGGLING, KIND_INVEST,
]

## 城外（NPC 摆点）的空位候选。上行建筑（y2..3）与下行建筑（y11..12）之间
## 是 y4..10 的空地，NPC 摆在这些固定点上，绝不压到建筑。
const NPC_SLOTS: Array = [
	Vector2i(1, 6), Vector2i(6, 6), Vector2i(11, 6), Vector2i(17, 6), Vector2i(21, 6),
	Vector2i(3, 9), Vector2i(8, 9), Vector2i(15, 9), Vector2i(20, 9),
]

## 进城歇脚冒险者（M33 A / D-147）的摆点候选。同在 y4..10 空地带上，但与 NPC_SLOTS
## 错开，且绝不压到建筑/居民——访客是有自己位置的另一种人，不是居民。缺省最多访客数。
const VISITOR_SLOTS: Array = [
	Vector2i(2, 5), Vector2i(12, 5), Vector2i(19, 5),
	Vector2i(5, 8), Vector2i(13, 8), Vector2i(22, 8),
	Vector2i(7, 10), Vector2i(18, 10),
]


## 生成一座城的城内网格结构。输入：
##   city_id   用于做槽位轮转的种子键
##   building_ids  这座城的建筑 id（顺序任意，内部会排序）
##   npc_ids       这座城的 npc id（顺序任意，内部会排序）
##   visitors      进城歇脚的冒险者名额（slot 数组，M33 A；顺序任意）。摆多少看
##                   `VISITOR_SLOTS` 够不够，**只影响这把 layout 的访客层**，不落盘——
##                   `WandererPool.city_visitors` 由世界种子派生谁在城（D-147）。
## 返回：
##   { w, h, gate, spawn,
##     blocked: {"x,y": true, ...},                建筑占用的格
##     buildings: [{ id, kind, x, y, w:h 占地 }], 每座建筑及其落位与功能
##     building_cell: {"x,y": building_index},     每格属于哪座建筑
##     npcs: [{ id, x, y }],
##     npc_cell: {"x,y": npc_id},
##     visitors: [{ slot, x, y }],
##     visitor_cell: {"x,y": slot} }
static func layout(
	city_id: String, building_ids: Array, npc_ids: Array, visitors: Array = []
) -> Dictionary:
	var ids: Array = building_ids.duplicate()
	ids.sort()
	var city_npcs: Array = npc_ids.duplicate()
	city_npcs.sort()
	# 访客名额去重（名册永远满员不会给重复，但喂进来的可能带重复，按序取即可）。
	var slots_in: Array = []
	var seen_s: Dictionary = {}
	for s in visitors:
		var sl: int = int(s)
		if not seen_s.has(sl):
			seen_s[sl] = true
			slots_in.append(sl)

	# 槽位轮转：同一城恒定，不同城错开。城市哈希只决定"哪个槽装哪座建筑，不决定
	# 每个槽是什么形状/在哪"——形状与位置都是固定死的，所以零碰撞。
	var rng := DeterministicRNG.new(str(city_id).hash())
	var offset: int = rng.next_int(SLOTS.size())

	var out: Dictionary = {
		"w": WIDTH, "h": HEIGHT,
		"gate": GATE, "spawn": SPAWN,
		"blocked": {}, "buildings": [], "building_cell": {},
		"npcs": [], "npc_cell": {},
		"visitors": [], "visitor_cell": {},
	}
	for i in range(ids.size()):
		var slot: Vector2i = SLOTS[(i + offset) % SLOTS.size()]
		var kind: String = str(KINDS[(i + offset) % KINDS.size()])
		var building_id: String = str(ids[i])
		out["buildings"].append({
			"id": building_id, "kind": kind,
			"x": slot.x, "y": slot.y, "w": FOOTPRINT_W, "h": FOOTPRINT_H,
		})
		var idx: int = out["buildings"].size() - 1
		for fx in range(FOOTPRINT_W):
			for fy in range(FOOTPRINT_H):
				var key: String = "%d,%d" % [slot.x + fx, slot.y + fy]
				out["blocked"][key] = true
				out["building_cell"][key] = idx

	for i in range(mini(city_npcs.size(), NPC_SLOTS.size())):
		var slot: Vector2i = NPC_SLOTS[i]
		var npc_id: String = str(city_npcs[i])
		out["npcs"].append({"id": npc_id, "x": slot.x, "y": slot.y})
		out["npc_cell"]["%d,%d" % [slot.x, slot.y]] = npc_id

	# 访客摆点：名额挨个落固定访客位，没有 slot 就不摆。落地格不写进 blocked（访客在
	# 空地站着，不是墙），只记一张 `visitor_cell` 表供命中/近邻判定。
	for i in range(mini(slots_in.size(), VISITOR_SLOTS.size())):
		var slot: Vector2i = VISITOR_SLOTS[i]
		var wp_slot: int = slots_in[i]
		out["visitors"].append({"slot": wp_slot, "x": slot.x, "y": slot.y})
		out["visitor_cell"]["%d,%d" % [slot.x, slot.y]] = wp_slot
	return out


## 某格能不能站：出界不可、建筑占用不可。城门与出生点是空地，走得上去。
static func walkable(cells: Dictionary, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return false
	return not bool(cells.get("blocked", {}).get("%d,%d" % [x, y], false))


## 走一步。返回 { ok, next, at_gate }。撞建筑/出界返回 { ok:false, next:from }。
static func step(cells: Dictionary, from: Vector2i, dx: int, dy: int) -> Dictionary:
	var nx: int = from.x + dx
	var ny: int = from.y + dy
	if not walkable(cells, nx, ny):
		return {"ok": false, "next": from, "at_gate": false}
	return {"ok": true, "next": Vector2i(nx, ny), "at_gate": (nx == GATE.x and ny == GATE.y)}


## 四邻是否有建筑。返回 { building_id, kind } 或空 {}。
static func near_building(cells: Dictionary, pos: Vector2i) -> Dictionary:
	for dir in _ORTHO:
		var key: String = "%d,%d" % [pos.x + dir.x, pos.y + dir.y]
		var idx: int = int(cells.get("building_cell", {}).get(key, -1))
		if idx >= 0 and idx < cells["buildings"].size():
			var b: Dictionary = cells["buildings"][idx]
			return {"building_id": str(b["id"]), "kind": str(b["kind"])}
	return {}


## 四邻是否有 NPC。返回 npc_id 或 ""。
static func near_npc(cells: Dictionary, pos: Vector2i) -> String:
	for dir in _ORTHO:
		var key: String = "%d,%d" % [pos.x + dir.x, pos.y + dir.y]
		if cells.get("npc_cell", {}).has(key):
			return str(cells["npc_cell"][key])
	return ""


## 四邻是否有进城歇脚的冒险者（M33 A）。返回名额 slot，否则 -1。
static func near_visitor(cells: Dictionary, pos: Vector2i) -> int:
	for dir in _ORTHO:
		var key: String = "%d,%d" % [pos.x + dir.x, pos.y + dir.y]
		if cells.get("visitor_cell", {}).has(key):
			return int(cells["visitor_cell"][key])
	return -1


const _ORTHO: Array = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]