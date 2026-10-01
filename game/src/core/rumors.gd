class_name Rumors
extends RefCounted

## 传闻抽取（第三阶段 A1 / D-160）。
##
## 传闻表里真/假并存、互相矛盾、一律不标真假——玩家听到的是真假难辨的口风，
## 这正是 Elona 式"传闻不保证可靠"的味道（《整合Elona设定与更新路线图》P1.E）。
## category 是数据内的真假口径，**只供测试断言与内部统计**，抽取给 UI 的字面绝不
## 外露；reliability（0..2）是这条口风在人群里的可信厚薄，抽取按它加权，越可信的
## 越容易被听到。
##
## 铁的派生口径跟世界其他东西一致：抽哪条由「世界种子 ⊕ 主题 ⊕ 序号」确定性推出，
## 不落盘、同种子可复现——读档回到同一座城，听的是同一批流言。

## 主题槽位：用于按 context 分成不同流言池（进城/城市场景/旅途），避免同一画面上
## 反复抽同一条。现役只用一个通用池，槽位预留扩展。
const TOPIC_COMMON: String = "common"


## 全部传闻，按 id 排序（保证同一种子下顺序稳定）。
static func pool() -> Array:
	var all: Array = ContentLoader.get_rumors()
	var copy: Array = []
	for entry in all:
		if entry is Dictionary and (not str((entry as Dictionary).get("id", "")).is_empty()):
			copy.append((entry as Dictionary).duplicate(true))
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", "")))
	return copy


## 是否至少有 false_count 条"假"传闻。数据口径，测试用。
static func has_false_at_least(total: int) -> bool:
	var false_count: int = 0
	for entry in pool():
		if str(entry.get("category", "")) == "false":
			false_count += 1
	return false_count >= total


## 抽取：按可靠性加权（reliability+1），确定性选一条。seed 是同主题下的派生种子；
## 若主题里没有匹配的传闻则回退通用池。查不到任何一条给空字典，绝不空指针。
static func pick(seed: int, topic: String = TOPIC_COMMON) -> Dictionary:
	var matched: Array = []
	for entry in pool():
		if topic == TOPIC_COMMON or str(entry.get("subject", "")) == topic:
			matched.append(entry)
	if matched.is_empty():
		matched = pool()
	if matched.is_empty():
		return {}
	var weights: Array = []
	var total: int = 0
	for entry in matched:
		var w: int = 1 + clampi(int(entry.get("reliability", 1)), 0, 2)
		total += w
		weights.append(total)
	var rng := DeterministicRNG.new(seed)
	var roll: int = rng.next_int(total)
	for i in range(weights.size()):
		if roll < int(weights[i]):
			return matched[i]
	return matched[matched.size() - 1]


## 该条传闻的字面口风（只给正文与出处缀，绝不带真假）。
static func line(rumor: Dictionary) -> String:
	if rumor.is_empty():
		return ""
	var phrase: String = str(rumor.get("text", ""))
	var origin: String = str(rumor.get("origin", ""))
	if origin.is_empty():
		return phrase
	return "%s（%s说）" % [phrase, origin]