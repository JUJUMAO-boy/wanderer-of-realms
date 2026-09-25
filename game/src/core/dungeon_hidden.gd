class_name DungeonHidden
extends RefCounted

## 副本隐藏暗室与密道路规则层（M32 副本纵深·A / D-144）。
##
## 背景：M29 之前的副本几何只有"外圈墙 + 单格岩屑"，除宝箱/敌人外没有任何
## 藏起来的东西。本层给楼层随机砌一间被封死的暗室：走近按回车推开暗门，里面
## 要么锁着一件副本专属遗物（treasure，见 DungeonRelics），要么是一条直通出口
## 的密道捷径（passage 密道口），要么埋着一段层内叙事碎片（fragment，见
## DungeonStory）。
##
## 口径与 DungeonModifiers / DungeonBoss 一致：**纯规则、不落盘、可无头钉测**。
## 与 Dungeon 的分工（D-144）：`Dungeon.layout` 只回答"哪个格是墙/宝箱/敌人/
## 出口"，暗室是"藏起来的收益与捷径"，本层独立做 `place`/`reveal`，不碰
## Dungeon 既有语义。开出的暗室是**一次性会话现象**，读档重派生（沿用 M21
## 遭遇的口径）。

## 缺省暗室出现概率（基点）：有 `chanceBp` 时用配置，否则按它。
const DEFAULT_CHANCE_BP: int = 2500
## 缺省最低出现层深：太浅的楼层不值得藏东西。
const DEFAULT_MIN_DEPTH: int = 2

## 房型池（缺省）：宝藏（必掉遗物）/ 密道（直通出口）/ 刻痕（一段叙事碎片）。
const DEFAULT_KINDS: Array = ["treasure", "passage", "fragment"]

## 暗室可能砌到的四个墙角线角标。仅用于给房间找锚点象限，无状态。
const _SALTS: Array = [0x9E3779B9, 0x85EBCA6B, 0xC2B2AE35, 0x27D4EB2F]


## 在一层已 `Dungeon.layout` 的楼层上，确定性砌一间隐藏暗室。
##   layout   —— Dungeon.layout 产出（含 blocked/treasures/enemies/exit/spawn）。
##   seed_key —— 派生随机用的种子键（通常是世界种子 ⊕ 副本序号）。
##   depth    —— 当前层深。
##   opts     —— balance.dungeon.hidden 子段（minDepth/chanceBp/kinds）。
##
## 就地往 layout 追加 `hiddenRooms: []`（无房时为空数组）；内室与暗门各格塞进
## `blocked`（封死成墙，开前绝走不进）。返回同一份 layout，便于 main 直接续用。
static func place(layout: Dictionary, seed_key: String, depth: int, opts: Dictionary) -> Dictionary:
	if layout.is_empty() or not layout.has("blocked"):
		return layout
	# 先保证键存在、再取引用：若先 get 再建键，取到的是临时数组，
	# append 不会写回 layout（D-144 的落盘口径因此得以保持）。
	seed_rooms(layout)
	var rooms: Array = layout.get("hiddenRooms", [])
	var min_depth: int = maxi(0, int(opts.get("minDepth", DEFAULT_MIN_DEPTH)))
	if depth < min_depth:
		return layout
	var chance_bp: int = maxi(0, int(opts.get("chanceBp", DEFAULT_CHANCE_BP)))
	var kinds: Array = opts.get("kinds", DEFAULT_KINDS)
	if kinds.is_empty():
		kinds = DEFAULT_KINDS
	var rng: DeterministicRNG = DeterministicRNG.new(
		(str(seed_key).hash() ^ (depth * 1374321241)) & 0xFFFFFFFF
	)
	if rng.next_int(10000) >= chance_bp:
		return layout

	var room: Dictionary = _carve(layout, rng, kinds, depth)
	if room.is_empty():
		return layout
	rooms.append(room)
	return layout


## 保证 `hiddenRooms` 键存在（不覆盖调用方已挂的内容）。
static func seed_rooms(layout: Dictionary) -> void:
	if not layout.has("hiddenRooms"):
		layout["hiddenRooms"] = []


## 列出当前楼层未打开的暗室（供视图/交互使用）。
static func rooms(layout: Dictionary) -> Array:
	if not layout.has("hiddenRooms"):
		return []
	return layout.get("hiddenRooms", [])


## 翻开某间暗室：解锁暗门与内室（从 blocked 移除，于是可走），置 opened。
##   roomKey —— 该房的 key（place 时派生的 `hidden-<depth>-<n>`）。
## 返回 { opened:bool, kind:String } ；已开/无此房返回 { opened:false, kind:"" }。
## 纯规则、幂等：两次 reveal 结果一致，不落盘。
static func reveal(layout: Dictionary, roomKey: String) -> Dictionary:
	var rooms: Array = layout.get("hiddenRooms", [])
	for room in rooms:
		if not (room is Dictionary):
			continue
		var r: Dictionary = room as Dictionary
		if str(r.get("key", "")) != roomKey:
			continue
		if bool(r.get("opened", false)):
			return {"opened": false, "kind": str(r.get("kind", ""))}
		var blocked: Dictionary = layout.get("blocked", {})
		for cell in r.get("interior", []):
			_blocked_erase(blocked, cell)
		var hatch: Dictionary = r.get("hatch", {})
		_blocked_erase(blocked, hatch)
		r["opened"] = true
		return {"opened": true, "kind": str(r.get("kind", ""))}
	return {"opened": false, "kind": ""}


## 该层是否有某类暗室（供绘制判断）。kind 空 = 任意。
static func has_room_kind(layout: Dictionary, kind: String, opened_only: bool = true) -> bool:
	for r in layout.get("hiddenRooms", []):
		if not (r is Dictionary):
			continue
		if opened_only and not bool((r as Dictionary).get("opened", false)):
			continue
		if kind.is_empty() or str((r as Dictionary).get("kind", "")) == kind:
			return true
	return false


## 找到密道房里那个"密道口"格子（passage 房）。返回 {x,y} 或 {}。
static func passage_hatch(layout: Dictionary) -> Dictionary:
	for r in layout.get("hiddenRooms", []):
		if not (r is Dictionary):
			continue
		var rr: Dictionary = r as Dictionary
		if str(rr.get("kind", "")) == "passage" and bool(rr.get("opened", false)):
			var p: Dictionary = rr.get("passageExit", {})
			if not p.is_empty():
				return p
	return {}


## 刻痕碎片房返回它藏着的那段叙事碎片的 id（无则空串）。
static func fragment_id(layout: Dictionary) -> String:
	for r in layout.get("hiddenRooms", []):
		if not (r is Dictionary):
			continue
		var rr: Dictionary = r as Dictionary
		if str(rr.get("kind", "")) == "fragment" and bool(rr.get("opened", false)):
			return str(rr.get("fragmentId", ""))
	return ""


## 在楼层一角确定性砌一间 w×h 的暗室，返回房间结构；砌不出返回 {}。
static func _carve(layout: Dictionary, rng: DeterministicRNG, kinds: Array, depth: int) -> Dictionary:
	var blocked: Dictionary = layout.get("blocked", {})
	for _attempt in range(64):
		var w: int = rng.range_int(3, 5)
		var h: int = rng.range_int(2, 4)
		# 内室锚点只派在左/上可行域：保证 xr≤WIDTH-3、yr≤HEIGHT-3，且不碰中央
		# 下落走廊与出口列（EXIT.x），于是不会把暗室砌到出口/出生通道上（D-144）。
		var max_rx: int = Dungeon.EXIT.x - 1 - w
		var max_ry: int = Dungeon.HEIGHT - 3 - h
		if max_rx < 2 or max_ry < 2:
			continue
		var xs: int = rng.range_int(2, max_rx)
		var ys: int = rng.range_int(2, max_ry)
		var xr: int = xs + w   # 独占上界
		var yr: int = ys + h
		if xr > Dungeon.WIDTH - 3 or yr > Dungeon.HEIGHT - 3:
			continue

		# 内室各格必须都是当前空地，且不与既有物什重叠。
		var interior: Array = []
		var ok: bool = true
		for gy in range(ys, yr):
			for gx in range(xs, xr):
				if gx == Dungeon.EXIT.x:
					ok = false
					break
				var key: String = "%d,%d" % [gx, gy]
				if blocked.has(key) or _on_obj(layout, gx, gy):
					ok = false
					break
				interior.append({"x": gx, "y": gy})
			if not ok:
				break
		if not ok or interior.is_empty():
			continue

		# 暗门：内室靠"主厅"一侧的墙上取一格。选朝向开阔的一侧。
		var hatch: Dictionary = _hatch_cell(layout, xs, ys, w, h, rng, blocked)
		if hatch.is_empty():
			continue

		var kind: String = str(kinds[rng.next_int(kinds.size())])
		var room: Dictionary = {
			"key": "hidden-%d-%d" % [depth, rng.next_int(1 << 24)],
			"kind": kind,
			"hatch": hatch,
			"interior": interior,
			"opened": false,
		}
		if kind == "treasure":
			# 内室放一枚宝箱格（离暗门较远格更好找）
			room["treasureCell"] = interior[interior.size() - 1]
		elif kind == "passage":
			room["passageExit"] = interior[0]
		elif kind == "fragment":
			room["fragmentId"] = "frag-%d-%d" % [depth, interior[0]["y"]]

		# 封死：内室 + 暗门全塞进 blocked。
		for cell in interior:
			blocked["%d,%d" % [int(cell["x"]), int(cell["y"])]] = true
		blocked["%d,%d" % [int(hatch["x"]), int(hatch["y"])]] = true
		return room
	return {}


## 找暗门格：内室四周的墙里挑一格朝主厅（空地）的。返回 {x,y} 或 {}。
static func _hatch_cell(
	layout: Dictionary, xs: int, ys: int, w: int, h: int, rng: DeterministicRNG, blocked: Dictionary
) -> Dictionary:
	var candidates: Array = []
	# 四周各一格（在 2..W-3 范围内），选其朝向是空地的。
	var edges: Array = []
	for gx in range(xs - 1, xs + w + 1):
		edges.append({"x": gx, "y": ys - 1})
		edges.append({"x": gx, "y": ys + h})
	for gy in range(ys - 1, ys + h + 1):
		edges.append({"x": xs - 1, "y": gy})
		edges.append({"x": xs + w, "y": gy})
	for e in edges:
		var ex: int = int(e["x"])
		var ey: int = int(e["y"])
		if ex < 2 or ey < 2 or ex >= Dungeon.WIDTH - 2 or ey >= Dungeon.HEIGHT - 2:
			continue
		if blocked.has("%d,%d" % [ex, ey]):
			continue
		if ex == Dungeon.EXIT.x:
			continue
		candidates.append({"x": ex, "y": ey})
	if candidates.is_empty():
		return {}
	return candidates[rng.next_int(candidates.size())]


## 该格是不是已有宝箱/敌人（暗室内室不能抢它们）。
static func _on_obj(layout: Dictionary, gx: int, gy: int) -> bool:
	for t in layout.get("treasures", []):
		if int(t["x"]) == gx and int(t["y"]) == gy:
			return true
	for e in layout.get("enemies", []):
		if int(e["x"]) == gx and int(e["y"]) == gy:
			return true
	var spawn: Vector2i = layout.get("spawn", Vector2i.ZERO)
	if int(spawn.x) == gx and int(spawn.y) == gy:
		return true
	return false


static func _blocked_erase(blocked: Dictionary, cell: Dictionary) -> void:
	if cell.is_empty():
		return
	var key: String = "%d,%d" % [int(cell.get("x", -1)), int(cell.get("y", -1))]
	if blocked.has(key):
		blocked.erase(key)