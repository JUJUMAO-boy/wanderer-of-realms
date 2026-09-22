class_name WorldSeen
extends RefCounted

## 大地图可见实体（M-C：废墟/遗构 + 游荡怪物窝点）。
##
## 背景：在 M-C 之前，副本与怪都是以"随机事件"从玩家脚下突然冒出来的——野外每走
## stepInterval 格掷一次概率。玩家看不到它们，只能被动等待。本层把"大地图上有哪些
## 看得见的坑与看得见的怪"抽成一套**由世界种子派生、不落盘**的图纸：
##
##   - 遗构（副本入口）：大地图上独立可寻的可见点，走上即进 `_enter_dungeon`。
##     自带危险度（→ v2 §一.3 的五档前缀）与 0–2 条修正词条。
##   - 怪物窝点：大地图上的绯红点。窝点内怪物在 lairRadius 内小范围游荡，
##     玩家走上它当前所在的一格即触发遭遇战。击杀/绕开那个窝点后本会话不再复活。
##
## 铁则（守住"能派生就不落盘"）：
##   1. **确定性、可复现**。所有位置与内容都由 world_seed 派生，同种子两次会话一致。
##   2. **不落盘**。读档回来重新派生 → 已清怪物/已进入的遗构重生成。命运由种子，
##      不由存档（v2 §一.4）。

## 危险度五档前缀（v2 §一.3），index = clampi(威胁层, 0..4)。威胁层由地理距离派生
## （近郊无害、越远越凶），危险度越高越"不遮拦地吓你"。
const DANGER_PREFIXES: Array = [
	"沉眠的", "吱呀作响的", "淌血的", "无名的", "夹缝间的",
]

## 每个遗构至多带多少条修正词条（v2 §一.3：0–2 条，随层数叠深）；危险度越高越多。
const MAX_WORDS: int = 2

## 修正词条池（承接 v2 §一.3 与 P5）。每条=一个可观察现象 + 一个说不清的由头。
const WORD_POOL: Array = [
	{ "id": "locked",
	  "label": "加了锁的",
	  "desc": "低处少了几分收益，却把好物锁得更深。" },
	{ "id": "stirred",
	  "label": "吵醒过的东西",
	  "desc": "里面的东西被吵醒过，更凶，掉得更肥。" },
	{ "id": "misaligned",
	  "label": "塌错方向的地脉",
	  "desc": "墙与墙对不上缝，像是另一个人照自己画的图搭了一半。" },
	{ "id": "swallowed",
	  "label": "吞了别的世界的账",
	  "desc": "走到底的人回来说不清哪一层是现世的。" },
]

var world_seed: int = 0
var grid: MapGrid = null
var city_coords: Array = []
var rules: Dictionary = {}

var _dungeons: Array = []
var _lairs: Array = []


## 威胁层 → 危险度前缀（v2 §一.3）。层越高前缀越凶；越界退到"夹缝间的"。
static func prefix_of(danger: int) -> String:
	var index: int = clampi(danger, 0, DANGER_PREFIXES.size() - 1)
	return str(DANGER_PREFIXES[index])


## 派生一套可见实体图纸。opts 可取：
##   { dungeonCount, lairCount, lairRadius, dungeonMinDistance, lairMinDistance, tierAt }
## 其中 tierAt 是一枚 Callable(pos:Vector2i)->int（通常是 EncounterSystem.tier_at），
## 让危险度反映地理真实；不给则退到确定性随机。
static func build(
	p_seed: int, p_grid: MapGrid, p_cities: Array, p_opts: Dictionary = {}
) -> WorldSeen:
	var ws := WorldSeen.new()
	ws.world_seed = p_seed
	ws.grid = p_grid
	ws.city_coords = p_cities.duplicate()
	ws.rules = p_opts.duplicate()
	ws._derive()
	return ws


func dungeons() -> Array:
	return _dungeons.duplicate()


func lairs() -> Array:
	return _lairs.duplicate()


## 窝点当前所在位置：锚点 + 本"时间桶"内的确定性小偏移，落在以锚点为心的
## 曼哈顿半径 lairRadius 的菱形内。同一窝点同一桶永远同一点；桶变化窝点就挪
## 一步——游荡是看得见的移动。
static func lair_pos(node: Dictionary, bucket: int) -> Vector2i:
	var seed: int = int(node.get("seed", 0))
	var radius: int = maxi(0, int(node.get("radius", 2)))
	var rng := DeterministicRNG.new((seed ^ (bucket * 2654435761)) & 0xFFFFFFFF)
	var a := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	# 拒绝采样：dx、dy 各自落在 [−radius, radius]，但 |dx|+|dy| ≤ radius，
	# 即不越出锚点的曼哈顿菱形（radius=0 时原地）。
	var dx: int = 0
	var dy: int = 0
	if radius > 0:
		for _guard in range(8):
			dx = rng.range_int(-radius, radius)
			dy = rng.range_int(-radius, radius)
			if absi(dx) + absi(dy) <= radius:
				break
	return a + Vector2i(dx, dy)


## 节点自身的稳定序号（0..2^32），用于给随机源当种子，保证同节点恒定。
static func node_seq(node: Dictionary) -> int:
	return int(str(node.get("key", "")).hash()) & 0xFFFFFFFF


## 派生全部图纸：先铺遗构，再铺窝点；都避开城市中心与彼此重叠格。
func _derive() -> void:
	if grid == null:
		return
	var dungeon_count: int = maxi(1, int(rules.get("dungeonCount", 10)))
	var lair_count: int = maxi(1, int(rules.get("lairCount", 20)))
	var dungeon_min: int = maxi(0, int(rules.get("dungeonMinDistance", 6)))
	var lair_min: int = maxi(0, int(rules.get("lairMinDistance", 6)))
	var lair_radius: int = maxi(0, int(rules.get("lairRadius", 2)))
	var tier_at: Variant = rules.get("tierAt", null)

	# 遗构与窝点各用自己的随机支，互不污染、也各自确定。
	var d_rng := DeterministicRNG.new((world_seed ^ 0x9E3779B9) & 0xFFFFFFFF)
	var l_rng := DeterministicRNG.new((world_seed ^ 0x85EBCA6B) & 0xFFFFFFFF)

	var occupied: Dictionary = {}
	for i in range(dungeon_count):
		var cell: Vector2i = _free_cell(d_rng, dungeon_min, occupied)
		if cell.x < 0:
			continue
		occupied["%d,%d" % [cell.x, cell.y]] = true
		var key: String = "seen-dun-%03d" % i
		var danger: int = _danger_for(cell, d_rng, tier_at)
		_dungeons.append({
			"key": key,
			"x": cell.x, "y": cell.y,
			"danger": danger,
			"prefix": prefix_of(danger),
			"words": _roll_words(danger, d_rng),
		})

	# 窝点铺得密一些：它们是"看得见的怪"，稀疏了就退回"整片看不见"的老样子。
	for i in range(lair_count):
		var cell: Vector2i = _free_cell(l_rng, lair_min, occupied)
		if cell.x < 0:
			continue
		occupied["%d,%d" % [cell.x, cell.y]] = true
		var key: String = "seen-lair-%03d" % i
		var tier: int = int(_danger_for(cell, l_rng, tier_at))
		_lairs.append({
			"key": key,
			"x": cell.x, "y": cell.y,
			"radius": lair_radius,
			"tier": tier,
			"seed": int(key.hash()) & 0xFFFFFFFF,
		})


## 随机抽一个可放点：网格内、离任意城 ≥ minDist、不与已占格重叠。抽不到返回 (-1,-1)。
func _free_cell(rng: DeterministicRNG, min_dist: int, occupied: Dictionary) -> Vector2i:
	for _attempt in range(200):
		var x: int = rng.range_int(2, grid.width - 3)
		var y: int = rng.range_int(2, grid.height - 3)
		if occupied.has("%d,%d" % [x, y]):
			continue
		if min_dist > 0 and _near_city(x, y, min_dist):
			continue
		return Vector2i(x, y)
	return Vector2i(-1, -1)


func _near_city(x: int, y: int, min_dist: int) -> bool:
	for c in city_coords:
		if not (c is Vector2i):
			continue
		if MapGrid.manhattan(c, Vector2i(x, y)) < min_dist:
			return true
	return false


## 这一格的危险度：有 tierAt 就用地理真实（越远越凶），否则退到随机。
func _danger_for(cell: Vector2i, rng: DeterministicRNG, tier_at: Variant) -> int:
	if tier_at is Callable:
		return maxi(0, int(tier_at.call(cell)))
	return rng.range_int(0, DANGER_PREFIXES.size() - 1)


## 危险度 → 0–MAX_WORDS 条互不重复的修正词条。危险度越高词条越多（v2 §一.3"随层数叠深"）。
func _roll_words(danger: int, rng: DeterministicRNG) -> Array:
	var count: int = clampi(danger, 0, MAX_WORDS)
	var pool: Array = WORD_POOL.duplicate()
	var out: Array = []
	for i in range(count):
		if pool.is_empty():
			break
		var w: Dictionary = pool[rng.next_int(pool.size())]
		pool.erase(w)
		out.append({"id": str(w.get("id", "")), "label": str(w.get("label", "")),
			"desc": str(w.get("desc", ""))})
	return out