class_name DungeonStory
extends RefCounted

## 层内叙事碎片规则层（M32 副本纵深·D / D-146）。
##
## 背景：副本层与层之间此前没有故事勾连。本层给楼层确定性派生出一段"刻痕石"
## 碎片——读一块记一段，集齐整座遗构的身世拼成一句结局。细节由种子派生、
## 不落盘；读到了几块的进度是**会话态**（D-146：读档重派生，沿用 M21 遭遇的
## 一次性现象口径），不是世界存档字段。

## 缺省散落概率（基点）：每层多大概率有一块刻痕石。
const DEFAULT_SCATTER_BP: int = 2200


## 取叙事碎片池（balance.dungeon.story.fragments）。
static func fragment_pool(rules: Dictionary) -> Array:
	if rules is Dictionary:
		var s: Dictionary = rules.get("story", {})
		if s is Dictionary:
			return s.get("fragments", [])
	return []


## 本层碎片总数（池的大小）。
static func total(rules: Dictionary) -> int:
	return fragment_pool(rules).size()


## 某一层的刻痕碎片段：有则回 {id, idx, total, text}，无则 {}。
## 确定性：`idx = depth % total` 让不同层读到不同的段（2..19 层里能把整段补完）。
static func fragment_for(seed_key: String, depth: int, rules: Dictionary) -> Dictionary:
	var pool: Array = fragment_pool(rules)
	if pool.is_empty():
		return {}
	var scatter_bp: int = DEFAULT_SCATTER_BP
	if rules is Dictionary:
		var s: Dictionary = rules.get("story", {})
		if s is Dictionary:
			scatter_bp = maxi(0, int(s.get("scatterChanceBp", DEFAULT_SCATTER_BP)))
	var rng: DeterministicRNG = DeterministicRNG.new(
		(str(seed_key).hash() ^ (maxi(0, depth) * 1865904973)) & 0xFFFFFFFF
	)
	if rng.next_int(10000) >= scatter_bp:
		return {}
	var idx: int = maxi(0, depth) % pool.size()
	var entry: Dictionary = pool[idx] if (pool[idx] is Dictionary) else {}
	return {
		"id": "frag-%d" % idx,
		"idx": idx,
		"total": pool.size(),
		"text": str(entry.get("text", "")),
		"leftBP": scatter_bp,
	}


## 拼出全段叙事（按池序）。返回 [ {idx, text}, ... ]，供集齐时展示。
static func assemble(rules: Dictionary) -> Array:
	var out: Array = []
	var pool: Array = fragment_pool(rules)
	for i in range(pool.size()):
		var e: Dictionary = pool[i] if (pool[i] is Dictionary) else {}
		out.append({"idx": i, "text": str(e.get("text", ""))})
	return out